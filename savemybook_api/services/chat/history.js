// 群組成員僅能看到 history_from_id（加入時的系統訊息）之後的訊息。
const floorOf = (row) => ({ fromId: Number(row.history_from_id ?? 0) });

const isVisible = (floor, message) => {
  if (!floor || !message) return true;
  return Number(message.message_id) >= floor.fromId;
};

const atLeast = (cond, value) => {
  const current = cond?.gte;
  return { ...cond, gte: current != null && current > value ? current : value };
};

const applyToWhere = (where, floor) => {
  if (floor?.fromId) return { ...where, message_id: atLeast(where.message_id, floor.fromId) };
  return where;
};

module.exports = { floorOf, isVisible, applyToWhere };
