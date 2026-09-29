const prisma = require('../lib/prisma');
const { badRequest, notFound } = require('../lib/errors');
const { clip } = require('../lib/text');
const audit = require('./audit');
const { isSubstantive } = require('./ai/support');
const { deidentify } = require('./ai/deidentify');

const FIELDS = {
  category: '分類',
  question: '問題',
  answer: '答案',
  sort_order: '排序',
  is_visible: { label: '顯示', format: (v) => (v ? '顯示' : '隱藏') }
};

const ORDER = [{ category: 'asc' }, { sort_order: 'asc' }, { faq_id: 'asc' }];

// 前台不需登入，只回傳公開欄位；來源工單編號是流水號，且會透露哪些問題來自個別使用者的客服對話。
const PUBLIC_SELECT = {
  faq_id: true, category: true, question: true, answer: true, sort_order: true, is_visible: true, created_at: true, updated_at: true
};

const listVisible = () => prisma.faqs.findMany({ where: { is_visible: true }, orderBy: ORDER, select: PUBLIC_SELECT });

const listAll = () => prisma.faqs.findMany({ orderBy: ORDER });

const findOrThrow = async (faqId) => {
  const faq = await prisma.faqs.findUnique({ where: { faq_id: faqId } });
  if (!faq) throw notFound('找不到此問題');
  return faq;
};

const ticketSource = (ticketId) => Promise.all([
  prisma.support_tickets.findUnique({ where: { ticket_id: ticketId }, select: { subject: true, category: true, from_ai_support: true } }),
  prisma.ai_support_sessions.findFirst({ where: { ticket_id: ticketId }, select: { session_id: true } })
]);

const notFromAi = () => badRequest('此工單不是由 AI 客服轉接', 'TICKET_NOT_FROM_AI');

// 品質報表以 source_ticket_id 統計由 AI 客服對話回流的常見問題，一般工單不得帶入。
const create = async (data, { adminId, req }) => {
  if (data.source_ticket_id) {
    const [ticket, session] = await ticketSource(data.source_ticket_id);
    if (!ticket) throw badRequest('找不到來源工單');
    if (!ticket.from_ai_support && !session) throw notFromAi();
  }
  const created = await prisma.faqs.create({ data });
  await audit.record(null, {
    adminId,
    action: '新增常見問題',
    targetType: 'faq',
    targetId: created.faq_id,
    summary: `新增常見問題「${data.question}」${data.source_ticket_id ? '（由客服工單建立）' : ''}`,
    undo: [audit.undoCreate('faqs', created.faq_id)],
    req
  });
  return created;
};

const reorder = async (ids, { adminId, req }) => {
  const existing = await prisma.faqs.findMany({
    where: { faq_id: { in: ids } },
    select: { faq_id: true, category: true, question: true, sort_order: true }
  });
  if (existing.length !== ids.length) throw badRequest('排序資料含有不存在的問題');

  const categories = new Set(existing.map((f) => f.category));
  if (categories.size > 1) throw badRequest('每次僅能排序同一分類');

  await prisma.$transaction(
    ids.map((fid, index) => prisma.faqs.update({ where: { faq_id: fid }, data: { sort_order: index } }))
  );

  const byId = new Map(existing.map((f) => [f.faq_id, f]));
  await audit.record(null, {
    adminId,
    action: '調整常見問題順序',
    targetType: 'faq',
    summary: `調整「${[...categories][0]}」分類的問題順序`,
    changes: [{
      label: '順序',
      from: [...existing].sort((a, b) => a.sort_order - b.sort_order).map((f) => clip(f.question, 20)).join('、'),
      to: ids.map((fid) => clip(byId.get(fid).question, 20)).join('、')
    }],
    undo: [audit.undoReorder('faqs', ids.map((fid, index) => ({ id: fid, before: byId.get(fid).sort_order, after: index })))],
    req
  });
};

const update = async (faqId, data, { adminId, req }) => {
  const before = await findOrThrow(faqId);

  await prisma.faqs.update({ where: { faq_id: faqId }, data: { ...data, updated_at: new Date() } });

  const changes = audit.diff(before, data, FIELDS);
  await audit.record(null, {
    adminId,
    action: '編輯常見問題',
    targetType: 'faq',
    targetId: faqId,
    summary: changes.length
      ? `修改常見問題「${before.question}」的${changes.map((c) => c.label).join('、')}`
      : `重新儲存常見問題「${before.question}」（無實際變更）`,
    changes,
    undo: changes.length ? [audit.undoUpdate('faqs', faqId, before, data, FIELDS)] : null,
    req
  });
};

const remove = async (faqId, { adminId, req }) => {
  const before = await findOrThrow(faqId);
  await prisma.faqs.delete({ where: { faq_id: faqId } });
  await audit.record(null, {
    adminId,
    action: '刪除常見問題',
    targetType: 'faq',
    targetId: faqId,
    summary: `刪除常見問題「${before.question}」`,
    undo: [audit.undoDelete('faqs', before)],
    req
  });
};

const FAQ_CATEGORIES = ['account', 'trade', 'wallet', 'cabinet'];
const HANDOFF_PREFIX = /^AI 客服轉接：/;
const QUESTION_MAX = 200;
const ANSWER_MAX = 2000;
const STAFF_REPLIES = 5;

// 由 AI 客服轉接的工單預填常見問題：問題取使用者最後一則實質提問（對話已過保存期限或撤回同意而刪除時改用工單主旨），
// 答案取客服人員最後一則文字回覆。常見問題會公開，預填內容先去識別化，管理員確認後才儲存。
const draftFromTicket = async (ticketId) => {
  const [ticket, session] = await ticketSource(ticketId);
  if (!ticket) throw notFound('找不到此工單');
  if (!ticket.from_ai_support && !session) throw notFromAi();
  const [asked, replies] = await Promise.all([
    session
      ? prisma.ai_support_messages.findMany({
        where: { session_id: session.session_id, role: 'user' },
        orderBy: { message_id: 'desc' },
        select: { content: true }
      })
      : [],
    prisma.support_ticket_messages.findMany({
      where: { ticket_id: ticketId, is_staff: true },
      orderBy: { created_at: 'desc' },
      take: STAFF_REPLIES,
      select: { content: true }
    })
  ]);
  const question = asked.map((m) => m.content).find(isSubstantive) ?? ticket.subject.replace(HANDOFF_PREFIX, '');
  const answer = replies.map((m) => String(m.content ?? '').trim()).find(Boolean) ?? '';
  return {
    category: FAQ_CATEGORIES.includes(ticket.category) ? ticket.category : 'general',
    question: deidentify(question, QUESTION_MAX),
    answer: deidentify(answer, ANSWER_MAX),
    source_ticket_id: ticketId
  };
};

module.exports = { listVisible, listAll, create, reorder, update, remove, draftFromTicket };
