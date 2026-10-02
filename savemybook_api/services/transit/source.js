// data.taipei 各資料來源的記憶體快取：過期才重新抓取、同時間的請求合併成一次，
// 抓取失敗時沿用上一份成功的資料，並在 retryMs 內不再重試，避免來源故障時每個請求都卡在逾時。
const sources = [];

const createSource = ({ name, ttlMs, retryMs = 60 * 1000, load }) => {
  let value = null;
  let updatedAt = null;
  let fetchedAt = 0;
  let failedAt = 0;
  let pending = null;

  const snapshot = () => ({ data: value, updatedAt, stale: value !== null && Date.now() - fetchedAt >= ttlMs });

  const refresh = () => {
    pending ??= (async () => {
      try {
        const result = await load();
        value = result.data;
        updatedAt = result.updatedAt ?? new Date();
        fetchedAt = Date.now();
        failedAt = 0;
      } catch (err) {
        failedAt = Date.now();
        console.error(`[交通開放資料] ${name} 抓取失敗：${err.message}`);
      } finally {
        pending = null;
      }
    })();
    return pending;
  };

  const get = async () => {
    const now = Date.now();
    if (value !== null && now - fetchedAt < ttlMs) return snapshot();
    if (failedAt && now - failedAt < retryMs) return snapshot();
    await refresh();
    return snapshot();
  };

  const reset = () => {
    value = null;
    updatedAt = null;
    fetchedAt = 0;
    failedAt = 0;
    pending = null;
  };

  const source = { name, get, refresh, reset, peek: snapshot };
  sources.push(source);
  return source;
};

const resetAll = () => sources.forEach((s) => s.reset());

module.exports = { createSource, resetAll };
