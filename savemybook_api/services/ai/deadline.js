// 互動功能的整體時限。App 的一般請求 30 秒逾時，伺服器必須先回應；
// 否則 App 顯示失敗，伺服器仍完成、寫入並計費，使用者重送就重複扣費。
const INTERACTIVE_MS = 25000;
const RESPONSE_RESERVE_MS = 1500;
const MIN_CALL_MS = 3000;

// budget() 為下一次模型呼叫可用的逾時：剩餘時間扣掉 reserve（呼叫後還要做的事），不超過 cap；
// 不足 min 時回傳 0，呼叫端應直接走降級路徑，而不是送出注定逾時的請求。
const start = (totalMs = INTERACTIVE_MS) => {
  const endsAt = Date.now() + totalMs;
  const remaining = () => Math.max(0, endsAt - Date.now());
  const budget = ({ reserve = RESPONSE_RESERVE_MS, cap = Infinity, min = MIN_CALL_MS } = {}) => {
    const ms = Math.floor(Math.min(cap, remaining() - reserve));
    return ms >= min ? ms : 0;
  };
  return { endsAt, remaining, budget };
};

module.exports = { INTERACTIVE_MS, RESPONSE_RESERVE_MS, MIN_CALL_MS, start };
