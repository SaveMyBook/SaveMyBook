const { badRequest } = require('../lib/errors');
const audit = require('./audit');

// 展示模式只存在記憶體並自動到期：伺服器重新啟動即回到關閉，忘記關閉也不會長期略過現場驗證。
// API 以 PM2 單一行程執行，多行程部署須改存資料庫。
const HOURS = Object.freeze([1, 4, 12]);

let state = null;

const status = (now = new Date()) => {
  if (state && state.until <= now) state = null;
  return state ? { enabled: true, until: state.until.toISOString() } : { enabled: false, until: null };
};

const isOn = (now = new Date()) => status(now).enabled;

const untilText = (until) =>
  new Date(until).toLocaleString('zh-TW', { timeZone: 'Asia/Taipei', hour12: false, month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' });

const set = async ({ enabled, hours }, { adminId, req }, now = new Date()) => {
  if (enabled && !HOURS.includes(hours)) throw badRequest(`展示時間僅可選擇 ${HOURS.join('、')} 小時`);
  const before = status(now);
  state = enabled ? { until: new Date(now.getTime() + hours * 3600000) } : null;
  const after = status(now);
  await audit.record(null, {
    adminId,
    action: enabled ? '開啟書櫃展示模式' : '關閉書櫃展示模式',
    summary: enabled
      ? `開啟書櫃展示模式 ${hours} 小時，至 ${untilText(after.until)} 自動關閉；期間不檢查開櫃距離，遠端開櫃免身分驗證與數字確認`
      : (before.enabled ? '關閉書櫃展示模式' : '關閉書櫃展示模式（原已關閉）'),
    req
  });
  return after;
};

const reset = () => {
  state = null;
};

module.exports = { HOURS, status, isOn, set, reset };
