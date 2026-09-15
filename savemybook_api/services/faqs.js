const prisma = require('../lib/prisma');
const { badRequest, notFound } = require('../lib/errors');
const { clip } = require('../lib/text');
const audit = require('./audit');

const FIELDS = {
  category: '分類',
  question: '問題',
  answer: '答案',
  sort_order: '排序',
  is_visible: { label: '顯示', format: (v) => (v ? '顯示' : '隱藏') }
};

const ORDER = [{ category: 'asc' }, { sort_order: 'asc' }, { faq_id: 'asc' }];

const listVisible = () => prisma.faqs.findMany({ where: { is_visible: true }, orderBy: ORDER });

const listAll = () => prisma.faqs.findMany({ orderBy: ORDER });

const findOrThrow = async (faqId) => {
  const faq = await prisma.faqs.findUnique({ where: { faq_id: faqId } });
  if (!faq) throw notFound('找不到此問題');
  return faq;
};

const create = async (data, { adminId, req }) => {
  const created = await prisma.faqs.create({ data });
  await audit.record(null, {
    adminId,
    action: '新增常見問題',
    targetType: 'faq',
    targetId: created.faq_id,
    summary: `新增常見問題「${data.question}」`,
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

module.exports = { listVisible, listAll, create, reorder, update, remove };
