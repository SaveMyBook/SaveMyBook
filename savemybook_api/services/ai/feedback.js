const prisma = require('../../lib/prisma');
const publicId = require('../../lib/public-id');
const { notFound, badRequest } = require('../../lib/errors');

// 使用者對 AI 客服與書籍顧問回覆的評價，存在訊息上，隨對話的保存期限、撤回同意與帳號刪除一併刪除。
const RATINGS = ['helpful', 'unhelpful'];
const REASONS = {
  support: ['inaccurate', 'off_topic', 'incomplete', 'other'],
  book_chat: ['books_mismatch', 'inaccurate', 'off_topic', 'other']
};

const TABLES = {
  support: { messages: 'ai_support_messages', sessions: 'ai_support_sessions', prefix: 'ai_support_message' },
  book_chat: { messages: 'ai_chat_messages', sessions: 'ai_chat_sessions', prefix: 'ai_chat_message' }
};

const FEATURES = Object.keys(TABLES);

const messageNo = (feature, messageId) => publicId.encode(TABLES[feature].prefix, messageId);

const feedbackOf = (row) => (row?.feedback ? { rating: row.feedback, reason: row.feedback_reason ?? null } : null);

const withNo = (feature, message) => ({ ...message, message_no: messageNo(feature, message.message_id), feedback: null });

const decorate = async (feature, messages) => {
  const ids = messages.filter((m) => m.role === 'assistant').map((m) => Number(m.message_id));
  const rows = ids.length
    ? await prisma[TABLES[feature].messages].findMany({
      where: { message_id: { in: ids } },
      select: { message_id: true, feedback: true, feedback_reason: true }
    })
    : [];
  const byId = new Map(rows.map((r) => [Number(r.message_id), r]));
  return messages.map((m) => (m.role === 'assistant'
    ? { ...m, message_no: messageNo(feature, m.message_id), feedback: feedbackOf(byId.get(Number(m.message_id))) }
    : m));
};

const rate = async (userId, feature, no, { rating, reason = null }) => {
  if (rating !== null && !RATINGS.includes(rating)) throw badRequest('評價內容不正確');
  if (reason !== null && (rating !== 'unhelpful' || !REASONS[feature].includes(reason))) {
    throw badRequest('評價原因不正確');
  }
  const table = TABLES[feature];
  const messageId = publicId.decode(table.prefix, no);
  const message = messageId == null
    ? null
    : await prisma[table.messages].findUnique({ where: { message_id: messageId }, select: { message_id: true, session_id: true, role: true } });
  const session = message
    ? await prisma[table.sessions].findUnique({ where: { session_id: message.session_id }, select: { user_id: true } })
    : null;
  if (!message || message.role !== 'assistant' || session?.user_id !== userId) throw notFound('找不到此訊息');
  await prisma[table.messages].update({
    where: { message_id: messageId },
    data: { feedback: rating, feedback_reason: rating ? reason : null, feedback_at: rating ? new Date() : null }
  });
  return { message_no: no, feedback: rating ? { rating, reason } : null };
};

module.exports = { RATINGS, REASONS, FEATURES, messageNo, withNo, decorate, rate };
