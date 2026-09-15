const { HttpError } = require('../errors');

const REASON_DETAILS = {
  AUTH: '金鑰無效或權限不足',
  MODEL_NOT_FOUND: '模型名稱不存在',
  QUOTA: '額度不足或方案未開通此功能，請確認服務商帳戶已啟用付費方案',
  RATE_LIMITED: '請求過於頻繁',
  INCOMPLETE: '回應超過輸出長度上限',
  BAD_REQUEST: '請求參數不正確',
  SERVER: '服務暫時無法使用',
  TIMEOUT: '連線逾時',
  NETWORK: '無法連線至服務',
  INVALID_OUTPUT: '回應格式不正確',
  BLOCKED: '內容遭服務安全機制拒絕',
  NOT_CONFIGURED: '尚未設定 API 金鑰'
};

// 服務商錯誤訊息可能夾帶金鑰片段或請求內容，只保留遮蔽後的前 300 字供管理員排查。
const redact = (text) => String(text ?? '')
  .replace(/(sk|AIza)[-_A-Za-z0-9]{8,}/g, '[redacted]')
  .replace(/key=[^&\s]+/gi, 'key=[redacted]')
  .replace(/\s+/g, ' ')
  .trim()
  .slice(0, 300);

class AiProviderError extends HttpError {
  constructor(reason, { status = null, provider = null, providerMessage = '' } = {}) {
    super(502, 'AI 服務暫時無法使用，請稍後再試', 'AI_PROVIDER_ERROR');
    this.reason = REASON_DETAILS[reason] ? reason : 'SERVER';
    this.detail = REASON_DETAILS[this.reason];
    this.httpStatus = status;
    this.provider = provider;
    this.providerMessage = redact(providerMessage);
  }

  get fullDetail() {
    return this.providerMessage ? `${this.detail}（${this.providerMessage}）` : this.detail;
  }
}

const providerMessageOf = (data) => {
  const e = data?.error;
  if (typeof e === 'string') return e;
  if (e && typeof e.message === 'string') return e.message;
  if (typeof data?.raw === 'string') return data.raw;
  return '';
};

const options = { backoffMs: 800, maxRetryAfterMs: 3000 };

const sleep = (ms, signal) => new Promise((resolve, reject) => {
  const timer = setTimeout(resolve, ms);
  signal?.addEventListener('abort', () => {
    clearTimeout(timer);
    reject(signal.reason ?? new Error('aborted'));
  }, { once: true });
});

const readBody = async (response) => {
  const text = await response.text();
  try {
    return text ? JSON.parse(text) : null;
  } catch {
    return { raw: text.slice(0, 500) };
  }
};

// Gemini 以 error.details[].retryDelay（如 "37s"）告知等待時間，OpenAI 與 DeepSeek 使用 Retry-After 標頭。
const requestedDelayMs = (response, data) => {
  const header = Number(response?.headers?.get?.('retry-after'));
  if (Number.isFinite(header) && header > 0) return header * 1000;
  const details = Array.isArray(data?.error?.details) ? data.error.details : [];
  for (const d of details) {
    const match = /^(\d+(?:\.\d+)?)s$/.exec(String(d?.retryDelay ?? ''));
    if (match) return Number(match[1]) * 1000;
  }
  return null;
};

// 逾時以單一 deadline 涵蓋重試，否則重試會讓等待時間倍增。
const postJson = async (url, { headers, body, timeoutMs, classify, provider }) => {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(new Error('timeout')), timeoutMs);
  try {
    for (let attempt = 1; ; attempt += 1) {
      let response;
      try {
        response = await fetch(url, {
          method: 'POST',
          headers: { 'content-type': 'application/json', ...headers },
          body: JSON.stringify(body),
          signal: controller.signal
        });
      } catch {
        if (controller.signal.aborted) throw new AiProviderError('TIMEOUT', { provider });
        if (attempt >= 2) throw new AiProviderError('NETWORK', { provider });
        await sleep(options.backoffMs * attempt, controller.signal).catch(() => {});
        if (controller.signal.aborted) throw new AiProviderError('TIMEOUT', { provider });
        continue;
      }

      let data;
      try {
        data = await readBody(response);
      } catch {
        if (controller.signal.aborted) throw new AiProviderError('TIMEOUT', { provider });
        throw new AiProviderError('NETWORK', { provider });
      }
      if (response.ok) return data;

      const reason = classify(response.status, data);
      const requested = requestedDelayMs(response, data);
      const retryable = (response.status === 429 || response.status >= 500)
        && reason !== 'QUOTA'
        && (requested == null || requested <= options.maxRetryAfterMs);
      if (retryable && attempt < 2) {
        await sleep(requested ?? options.backoffMs * attempt, controller.signal).catch(() => {});
        if (controller.signal.aborted) throw new AiProviderError('TIMEOUT', { provider });
        continue;
      }
      throw new AiProviderError(reason, { status: response.status, provider, providerMessage: providerMessageOf(data) });
    }
  } finally {
    clearTimeout(timer);
  }
};

const baseClassify = (status) => {
  if (status === 401 || status === 403) return 'AUTH';
  if (status === 402) return 'QUOTA';
  if (status === 404) return 'MODEL_NOT_FOUND';
  if (status === 429) return 'RATE_LIMITED';
  if (status >= 500) return 'SERVER';
  return 'BAD_REQUEST';
};

const errorText = (data) => {
  const e = data?.error;
  if (!e) return '';
  if (typeof e === 'string') return e.toLowerCase();
  return [e.message, e.code, e.status, e.type, e.param].filter((x) => typeof x === 'string').join(' ').toLowerCase();
};

// 429 同時用於短時間限流與額度用盡；後者重試無效，須提示管理員檢查方案。
const quotaExhausted = (text) => /limit: ?0\b|free[_ ]tier|billing|exceeded your current quota|insufficient_quota|quota exceeded|per ?day|perday/.test(text);

module.exports = { AiProviderError, REASON_DETAILS, options, postJson, baseClassify, errorText, quotaExhausted, redact };
