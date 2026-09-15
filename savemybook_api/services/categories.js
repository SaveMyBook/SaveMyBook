const prisma = require('../lib/prisma');
const { badRequest, notFound } = require('../lib/errors');
const audit = require('./audit');

const FIELDS = { category_name: '名稱', parent_id: '父分類編號', sort_order: '排序' };
const ADMIN_FIELDS = { category_name: '名稱', sort_order: '排序' };

const tree = () => prisma.book_categories.findMany({
  where: { parent_id: null },
  orderBy: { sort_order: 'asc' },
  include: { other_book_categories: { orderBy: { sort_order: 'asc' } } }
});

const flat = () => prisma.book_categories.findMany({
  orderBy: [{ parent_id: 'asc' }, { sort_order: 'asc' }]
});

const detail = async (categoryId) => {
  const category = await prisma.book_categories.findUnique({
    where: { category_id: categoryId },
    include: { other_book_categories: true }
  });
  if (!category) throw notFound('找不到該分類');
  return category;
};

const findOrThrow = async (categoryId) => {
  const category = await prisma.book_categories.findUnique({ where: { category_id: categoryId } });
  if (!category) throw notFound('找不到該分類');
  return category;
};

const assertParent = async (parentId, selfId) => {
  if (parentId == null) return;
  if (parentId === selfId) throw badRequest('父分類不可設定為自身');

  const seen = new Set([selfId]);
  let cursor = parentId;
  while (cursor != null) {
    if (seen.has(cursor)) throw badRequest('父分類不可為自身的子分類');
    seen.add(cursor);
    const row = await prisma.book_categories.findUnique({
      where: { category_id: cursor },
      select: { parent_id: true }
    });
    if (!row) throw badRequest('找不到指定的父分類');
    cursor = row.parent_id;
  }
};

const recordCreated = (created, name, { adminId, req }) => audit.record(null, {
  adminId,
  action: '新增分類',
  targetType: 'category',
  targetId: created.category_id,
  summary: `新增分類「${name}」`,
  undo: [audit.undoCreate('book_categories', created.category_id)],
  req
});

const recordDeleted = (categoryId, before, { adminId, req }) => audit.record(null, {
  adminId,
  action: '刪除分類',
  targetType: 'category',
  targetId: categoryId,
  summary: `刪除分類「${before.category_name}」`,
  undo: [audit.undoDelete('book_categories', before)],
  req
});

const create = async (data, ctx) => {
  await assertParent(data.parent_id ?? null, null);
  const created = await prisma.book_categories.create({ data });
  await recordCreated(created, data.category_name, ctx);
  return created;
};

const update = async (categoryId, data, ctx) => {
  const before = await findOrThrow(categoryId);
  if (data.parent_id !== undefined) await assertParent(data.parent_id, categoryId);

  const updated = await prisma.book_categories.update({ where: { category_id: categoryId }, data });
  const changes = audit.diff(before, data, FIELDS);
  if (changes.length) {
    await audit.record(null, {
      adminId: ctx.adminId,
      action: '編輯分類',
      targetType: 'category',
      targetId: categoryId,
      summary: `編輯分類「${before.category_name}」`,
      changes,
      undo: [audit.undoUpdate('book_categories', categoryId, before, data, FIELDS)],
      req: ctx.req
    });
  }
  return updated;
};

const remove = async (categoryId, ctx) => {
  const before = await findOrThrow(categoryId);

  try {
    await prisma.book_categories.delete({ where: { category_id: categoryId } });
    await recordDeleted(categoryId, before, ctx);
  } catch (err) {
    if (err.code === 'P2003') {
      throw badRequest('無法刪除，此分類下可能仍有子分類或書籍，請先轉移或刪除關聯資料');
    }
    throw err;
  }
};

const adminList = async () => {
  const categories = await prisma.book_categories.findMany({
    orderBy: [{ sort_order: 'asc' }, { category_id: 'asc' }],
    include: { _count: { select: { books: true } } }
  });
  return categories.map((c) => ({
    category_id: c.category_id,
    category_name: c.category_name,
    sort_order: c.sort_order,
    book_count: c._count.books
  }));
};

const reorder = async (ids, { adminId, req }) => {
  const existing = await prisma.book_categories.findMany({
    where: { category_id: { in: ids } },
    select: { category_id: true, category_name: true, sort_order: true }
  });
  if (existing.length !== ids.length) throw badRequest('排序資料含有不存在的分類');

  await prisma.$transaction(
    ids.map((cid, index) => prisma.book_categories.update({ where: { category_id: cid }, data: { sort_order: index } }))
  );

  const byId = new Map(existing.map((c) => [c.category_id, c]));
  await audit.record(null, {
    adminId,
    action: '調整分類排序',
    targetType: 'category',
    summary: '調整分類的顯示順序',
    changes: [{
      label: '順序',
      from: [...existing].sort((a, b) => a.sort_order - b.sort_order).map((c) => c.category_name).join('、'),
      to: ids.map((cid) => byId.get(cid).category_name).join('、')
    }],
    undo: [audit.undoReorder('book_categories',
      ids.map((cid, index) => ({ id: cid, before: byId.get(cid).sort_order, after: index })))],
    req
  });
};

const adminUpdate = async (categoryId, before, data, { adminId, req }) => {
  await prisma.book_categories.update({ where: { category_id: categoryId }, data });

  const changes = audit.diff(before, data, ADMIN_FIELDS);
  await audit.record(null, {
    adminId,
    action: '編輯分類',
    targetType: 'category',
    targetId: categoryId,
    summary: changes.length ? `編輯分類「${before.category_name}」` : `重新儲存分類「${data.category_name}」（無實際變更）`,
    changes,
    undo: changes.length ? [audit.undoUpdate('book_categories', categoryId, before, data, ADMIN_FIELDS)] : null,
    req
  });
};

const adminRemove = async (categoryId, ctx) => {
  const [inUse, children] = await Promise.all([
    prisma.books.count({ where: { category_id: categoryId } }),
    prisma.book_categories.count({ where: { parent_id: categoryId } })
  ]);
  if (inUse > 0) throw badRequest(`此分類仍有 ${inUse} 本書籍，請先調整後再刪除`);
  if (children > 0) throw badRequest(`此分類下仍有 ${children} 個子分類，請先調整後再刪除`);

  const before = await findOrThrow(categoryId);
  await prisma.book_categories.delete({ where: { category_id: categoryId } });
  await recordDeleted(categoryId, before, ctx);
};

module.exports = {
  tree, flat, detail, findOrThrow, create, update, remove, adminList, reorder, adminUpdate, adminRemove
};
