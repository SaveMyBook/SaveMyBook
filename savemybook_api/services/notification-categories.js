const CATEGORIES = ['trade', 'chat', 'account', 'service', 'promotion'];

const CATEGORY_LABELS = { trade: '交易', chat: '聊天', account: '帳號', service: '客服', promotion: '優惠' };

const BY_TYPE = {
  trade: ['order', 'reservation'],
  chat: ['message'],
  promotion: ['promotion']
};

// 只有 type 為 system（或未列於 BY_TYPE）時才依 related_type 判斷，例如降價通知 (promotion, book) 歸優惠而非交易。
const BY_RELATED_TYPE = {
  trade: ['order', 'wallet', 'book', 'reservation'],
  chat: ['chat_room'],
  account: ['security', 'password', 'legal', 'member_level', 'user', 'push_test'],
  service: ['ticket', 'report', 'admin_ticket', 'book_review', 'risk_alert'],
  promotion: ['announcement']
};

const FALLBACK = 'account';

const TYPED = Object.values(BY_TYPE).flat();
const RELATED = Object.values(BY_RELATED_TYPE).flat();

const categoryOf = (type, relatedType) => {
  for (const [category, types] of Object.entries(BY_TYPE)) if (types.includes(type)) return category;
  for (const [category, related] of Object.entries(BY_RELATED_TYPE)) if (related.includes(relatedType)) return category;
  return FALLBACK;
};

const whereOf = (category) => {
  const OR = [];
  if (BY_TYPE[category]) OR.push({ type: { in: BY_TYPE[category] } });
  if (BY_RELATED_TYPE[category]) OR.push({ type: { notIn: TYPED }, related_type: { in: BY_RELATED_TYPE[category] } });
  if (category === FALLBACK) {
    OR.push({ type: { notIn: TYPED }, related_type: null });
    OR.push({ type: { notIn: TYPED }, related_type: { notIn: RELATED } });
  }
  return { OR };
};

const quote = (values) => values.map((v) => `'${v}'`).join(', ');

const caseSql = (typeColumn = 'type', relatedColumn = 'related_type') => [
  'CASE',
  ...Object.entries(BY_TYPE).map(([c, types]) => `WHEN ${typeColumn} IN (${quote(types)}) THEN '${c}'`),
  ...Object.entries(BY_RELATED_TYPE).map(([c, related]) => `WHEN ${relatedColumn} IN (${quote(related)}) THEN '${c}'`),
  `ELSE '${FALLBACK}' END`
].join(' ');

module.exports = { CATEGORIES, CATEGORY_LABELS, BY_TYPE, BY_RELATED_TYPE, FALLBACK, categoryOf, whereOf, caseSql };
