const { conflict, badRequest } = require('../lib/errors');
const { ADMIN_PERMISSIONS } = require('../constants/domain');
const { decode, sameValue, display } = require('./audit');
const { changeBalance } = require('./wallet');

// 白名單限制還原可碰的欄位，紀錄被竄改也改不到密碼或餘額。
const MODELS = {
  users: { pk: 'user_id', fields: ['is_active', 'is_blacklisted', 'role', 'bonus_points', 'deletion_requested_at'] },
  admin_permissions: { pk: 'user_id', fields: Object.values(ADMIN_PERMISSIONS), creatable: true },
  books: {
    pk: 'book_id',
    fields: ['title', 'author', 'publisher', 'publish_date', 'isbn', 'category_id', 'condition_level',
      'condition_note', 'price', 'description', 'status', 'is_approved']
  },
  book_categories: { pk: 'category_id', fields: ['category_name', 'sort_order', 'parent_id'], creatable: true },
  member_levels: { pk: 'level_id', fields: ['level_name', 'min_points', 'max_points', 'benefits'], creatable: true },
  faqs: { pk: 'faq_id', fields: ['category', 'question', 'answer', 'sort_order', 'is_visible'], creatable: true },
  system_announcements: {
    pk: 'announcement_id',
    fields: ['title', 'content', 'type', 'is_published', 'published_at', 'expires_at'],
    creatable: true
  },
  legal_documents: { pk: 'doc_key', fields: ['title', 'content'] },
  smart_cabinets: {
    pk: 'cabinet_id',
    fields: ['cabinet_name', 'address', 'latitude', 'longitude', 'is_active', 'open_time', 'close_time'],
    creatable: true
  },
  cabinet_slots: { pk: 'slot_id', fields: ['status'] },
  support_tickets: { pk: 'ticket_id', fields: ['status', 'closed_at'] },
  reports: { pk: 'report_id', fields: ['status', 'admin_id', 'admin_note', 'resolved_at'] }
};

const PERMISSION_BY_TARGET = {
  user: 'members',
  book: 'content',
  category: 'content',
  level: 'levels',
  faq: 'announcements',
  legal: 'announcements',
  announcement: 'announcements',
  cabinet: 'cabinets',
  cabinet_slot: 'cabinets',
  wallet: 'wallets',
  ticket: 'support',
  report: 'reports'
};

const modelOf = (name) => {
  const spec = MODELS[name];
  if (!spec) throw badRequest('此紀錄的還原資料不正確');
  return spec;
};

const assertFields = (spec, obj) => {
  for (const field of Object.keys(obj)) {
    if (!spec.fields.includes(field)) throw badRequest('此紀錄的還原資料不正確');
  }
};

const decodeAll = (obj) => Object.fromEntries(Object.entries(obj).map(([k, v]) => [k, decode(v)]));

const checkStep = async (tx, step) => {
  if (step.op === 'wallet') return null;
  const spec = modelOf(step.model);

  if (step.op === 'update') {
    assertFields(spec, step.after);
    const current = await tx[step.model].findUnique({ where: { [spec.pk]: step.id } });
    if (!current) {
      return Object.keys(step.before).length === 0 && spec.creatable ? null : '資料已不存在';
    }
    const changed = Object.keys(step.after).filter((f) => !sameValue(current[f], step.after[f]));
    if (changed.length) {
      return `之後曾再次修改（${changed.map((f) => `${step.labels?.[f] ?? f}目前是 ${display(current[f])}`).join('、')}）`;
    }
    if (step.model === 'books' && step.before.status === 'on_sale' && current.is_approved === false
      && step.before.is_approved !== true) {
      return '已因違規下架';
    }
    return null;
  }

  if (step.op === 'delete') {
    if (!spec.creatable) throw badRequest('此紀錄的還原資料不正確');
    const current = await tx[step.model].findUnique({ where: { [spec.pk]: step.id } });
    return current ? null : '資料已被刪除';
  }

  if (step.op === 'create') {
    if (!spec.creatable) throw badRequest('此紀錄的還原資料不正確');
    const id = decode(step.row[spec.pk]);
    const current = await tx[step.model].findUnique({ where: { [spec.pk]: id } });
    return current ? '相同資料已存在' : null;
  }

  if (step.op === 'reorder') {
    for (const item of step.items) {
      const current = await tx[step.model].findUnique({ where: { [spec.pk]: item.id } });
      if (!current) return '排序中有資料已被刪除';
      if (current.sort_order !== item.after) return '排序之後曾再次調整';
    }
    return null;
  }

  throw badRequest('此紀錄的還原資料不正確');
};

const applyStep = async (tx, step, { adminId, label }) => {
  if (step.op === 'wallet') {
    const amount = -Number(step.amount);
    await changeBalance(tx, step.userId, {
      amount,
      type: 'admin_adjust',
      description: `撤銷管理員調整：${label}`,
      counters: amount > 0 ? { total_income: { increment: amount } } : { total_expense: { increment: -amount } },
      insufficientMessage: '會員餘額不足，無法撤銷此筆加值'
    });
    return;
  }

  const spec = modelOf(step.model);

  if (step.op === 'update') {
    const exists = await tx[step.model].findUnique({ where: { [spec.pk]: step.id } });
    if (exists && Object.keys(step.before).length === 0 && spec.creatable) {
      await tx[step.model].delete({ where: { [spec.pk]: step.id } });
      return;
    }
    assertFields(spec, step.before);
    await tx[step.model].update({ where: { [spec.pk]: step.id }, data: decodeAll(step.before) });
    return;
  }

  if (step.op === 'delete') {
    await tx[step.model].delete({ where: { [spec.pk]: step.id } });
    return;
  }

  if (step.op === 'create') {
    await tx[step.model].create({ data: decodeAll(step.row) });
    return;
  }

  if (step.op === 'reorder') {
    for (const item of step.items) {
      await tx[step.model].update({ where: { [spec.pk]: item.id }, data: { sort_order: item.before } });
    }
  }
};

const run = async (tx, steps, context) => {
  const problems = [];
  for (const step of steps) {
    const problem = await checkStep(tx, step);
    if (problem) problems.push(problem);
  }
  if (problems.length) {
    throw conflict(`無法還原：資料${problems[0]}。請至對應的管理頁面手動調整。`, 'UNDO_CONFLICT');
  }

  // 刪除須先做，否則還原刪除與還原新增可能撞到同一個主鍵。
  const ordered = [...steps.filter((s) => s.op === 'delete'), ...steps.filter((s) => s.op !== 'delete')];
  for (const step of ordered) await applyStep(tx, step, context);
};

module.exports = { PERMISSION_BY_TARGET, run };
