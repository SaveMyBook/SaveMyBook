// 群組成員僅能看到自己加入後的訊息。已執行 010 時以 history_from_id 判斷；尚未執行時退回以加入時間判斷，
// 並保留 1 秒誤差：DATETIME 不含毫秒，四捨五入後加入時間可能晚於同一交易寫入的建立或邀請系統訊息。
const JOIN_MARGIN_MS = 1000;

const floorOf = (row, v3) => {
  if (v3) return { fromId: Number(row.history_from_id ?? 0) };
  return row.joined_at ? { since: new Date(new Date(row.joined_at).getTime() - JOIN_MARGIN_MS) } : null;
};

const isVisible = (floor, message) => {
  if (!floor || !message) return true;
  if (floor.fromId != null) return Number(message.message_id) >= floor.fromId;
  if (floor.since) return message.created_at != null && new Date(message.created_at) >= floor.since;
  return true;
};

const atLeast = (cond, value) => {
  const current = cond?.gte;
  return { ...cond, gte: current != null && current > value ? current : value };
};

const applyToWhere = (where, floor) => {
  if (floor?.fromId) return { ...where, message_id: atLeast(where.message_id, floor.fromId) };
  if (floor?.since) return { ...where, created_at: atLeast(where.created_at, floor.since) };
  return where;
};

module.exports = { floorOf, isVisible, applyToWhere };
