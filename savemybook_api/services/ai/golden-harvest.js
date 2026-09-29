const prisma = require('../../lib/prisma');
const { CONDITION_LABELS } = require('../../constants/domain');
const { deidentify } = require('./deidentify');

// 每月把管理員推翻的上架審核整理成評測集候選，只輸出去識別化的上架內容與判定，不含照片、使用者或賣家識別資料；
// 候選須人工改寫並標註 expect 後才加入 test/ai/golden。
// 客服與書籍顧問的負評只輸出原因統計：使用者的提問屬於 AI 對話，保存期限與撤回同意時的刪除都不涵蓋評測集，不可取出。
const MAX_CASES = 200;

const monthRange = (month) => {
  const m = /^(\d{4})-(\d{2})$/.exec(String(month ?? ''));
  if (!m) throw new Error('month 格式須為 YYYY-MM');
  const from = new Date(Number(m[1]), Number(m[2]) - 1, 1);
  return { from, to: new Date(from.getFullYear(), from.getMonth() + 1, 1) };
};

const previousMonth = (now = new Date()) => {
  const d = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
};

const parseList = (value) => {
  try {
    const list = JSON.parse(String(value ?? '[]'));
    return Array.isArray(list) ? list.filter((x) => typeof x === 'string') : [];
  } catch {
    return [];
  }
};

const moderationCases = async ({ from, to }) => {
  const events = await prisma.ai_review_events.findMany({
    where: { actor: { in: ['admin', 'relist'] }, misjudged: true, created_at: { gte: from, lt: to } },
    orderBy: { created_at: 'asc' },
    take: MAX_CASES
  });
  const books = events.length
    ? await prisma.books.findMany({ where: { book_id: { in: [...new Set(events.map((e) => e.book_id))] } } })
    : [];
  const byId = new Map(books.map((b) => [b.book_id, b]));
  return events.filter((e) => byId.has(e.book_id)).map((e) => {
    const b = byId.get(e.book_id);
    return {
      listing: {
        title: deidentify(b.title, 255),
        author: deidentify(b.author, 255),
        publisher: deidentify(b.publisher, 255),
        isbn: b.isbn ?? '',
        condition: CONDITION_LABELS[b.condition_level] ?? '',
        condition_note: deidentify(b.condition_note, 1000),
        price: Number(b.price),
        description: deidentify(b.description, 3000)
      },
      flagged: {
        verdict: e.verdict,
        origin: e.origin,
        categories: parseList(e.categories),
        confidence: e.confidence == null ? null : Number(e.confidence)
      },
      admin: { decision: e.status, prior: e.prior }
    };
  });
};

const feedbackReasons = async ({ from, to }, table) => {
  const rated = await prisma[table].findMany({
    where: { feedback: 'unhelpful', feedback_at: { gte: from, lt: to } },
    select: { feedback_reason: true }
  });
  const reasons = {};
  for (const r of rated) reasons[r.feedback_reason ?? 'unspecified'] = (reasons[r.feedback_reason ?? 'unspecified'] ?? 0) + 1;
  return { unhelpful: rated.length, reasons };
};

const collect = async (month = previousMonth()) => {
  const range = monthRange(month);
  const [moderation, support, bookChat] = await Promise.all([
    moderationCases(range),
    feedbackReasons(range, 'ai_support_messages'),
    feedbackReasons(range, 'ai_chat_messages')
  ]);
  return {
    month,
    generated_at: new Date().toISOString(),
    note: '上架審核候選已去識別化，仍可能含有人名等無法自動辨識的資料。請人工改寫、確認內容並標註 expect 後，再依 test/ai/golden 的格式加入；不可直接複製。客服與書籍顧問只提供負評原因統計，題目請依原因自行撰寫。',
    moderation,
    support_feedback: support,
    book_chat_feedback: bookChat
  };
};

module.exports = { collect, monthRange, previousMonth };
