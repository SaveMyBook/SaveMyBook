const { AiProviderError } = require('../../lib/ai');

const FAILURE_LIMIT = 3;
const OPEN_MS = 60 * 1000;
const OUTAGE_REASONS = new Set(['SERVER', 'TIMEOUT', 'NETWORK', 'RATE_LIMITED', 'AUTH', 'QUOTA']);
// 互動功能依剩餘時間縮短逾時，幾秒內沒回應不代表服務商故障。
const MIN_COUNTED_TIMEOUT_MS = 8000;

const state = new Map();

const isOpen = (provider) => (state.get(provider)?.openUntil ?? 0) > Date.now();

// 暫停期滿後只放行一個探測請求：放行時先把暫停延長，同時進來的其他請求照舊視為暫停（改用備援或降級）；
// 探測成功才恢復，失敗就重新暫停。探測沒有結果（例如逾時太短不計）時，延長的暫停期滿後再放行下一個。
const admit = (provider) => {
  const entry = state.get(provider);
  if (!entry || entry.failures < FAILURE_LIMIT) return true;
  if (entry.openUntil > Date.now()) return false;
  entry.openUntil = Date.now() + OPEN_MS;
  return true;
};

const succeeded = (provider) => {
  state.delete(provider);
};

const failed = (provider, err, { timeoutMs = null } = {}) => {
  if (!(err instanceof AiProviderError) || !OUTAGE_REASONS.has(err.reason)) return;
  if (err.reason === 'TIMEOUT' && timeoutMs != null && timeoutMs < MIN_COUNTED_TIMEOUT_MS) return;
  const entry = state.get(provider) ?? { failures: 0, openUntil: 0 };
  entry.failures += 1;
  if (entry.failures >= FAILURE_LIMIT) entry.openUntil = Date.now() + OPEN_MS;
  state.set(provider, entry);
};

const reset = () => state.clear();

module.exports = { FAILURE_LIMIT, OPEN_MS, OUTAGE_REASONS, isOpen, admit, succeeded, failed, reset };
