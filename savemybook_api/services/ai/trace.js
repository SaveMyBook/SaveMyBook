const crypto = require('crypto');

const OUTCOMES = ['ok', 'repaired', 'degraded', 'empty', 'refused', 'failed'];
// 只用於用量紀錄：沒有送出請求（時間不足、斷路器暫停）的呼叫，不屬於任何處理結果。
const NOT_SENT = 'not_sent';

const newRequestId = () => crypto.randomBytes(8).toString('hex');

// 提示詞版本只能由固定的規則文字計算：實際送出的系統訊息含時間與使用者資料，每次都不同。
// 放在使用者提示詞裡的固定指示句（例如是否可搜尋、比對結果的說明）也會影響模型行為，須抽成常數一併列入，
// 否則只改這些文字時版本不變，後台依版本比較改版前後會失真。
const promptVersion = (...parts) => crypto.createHash('sha256').update(parts.map(String).join('\n\u0000\n')).digest('hex').slice(0, 12);

const outcomeOfError = (err) => (err?.reason === 'BLOCKED' ? 'refused' : 'failed');

const start = (feature, { userId = null } = {}) => {
  const startedAt = Date.now();
  const timings = {};
  const step = async (name, run) => {
    const at = Date.now();
    try {
      return await run();
    } finally {
      timings[name] = (timings[name] ?? 0) + Date.now() - at;
    }
  };
  return { id: newRequestId(), feature, userId, timings, step, elapsed: () => Date.now() - startedAt };
};

const origin = (feature) => Object.freeze({ id: null, feature });

module.exports = { OUTCOMES, NOT_SENT, newRequestId, promptVersion, outcomeOfError, start, origin };
