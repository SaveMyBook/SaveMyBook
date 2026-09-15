const prisma = require('../lib/prisma');
const publicId = require('../lib/public-id');
const { conflict, forbidden, notFound } = require('../lib/errors');
const { userBrief, userName } = require('../lib/selects');
const audit = require('./audit');
const undo = require('./undo');
const { hasPermission } = require('./admin-permissions');

const TARGET_TYPES = [
  'user', 'book', 'category', 'level', 'faq', 'legal', 'announcement', 'cabinet', 'cabinet_slot',
  'wallet', 'ticket', 'report', 'dispute', 'order', 'backup'
];

const keywordFilters = (keyword) => {
  const filters = [{ action: { contains: keyword } }, { detail: { contains: keyword } }];
  const code = publicId.decodeAny(keyword);
  if (code?.prefix === publicId.prefixOf('log')) {
    filters.push({ log_id: code.id });
  } else if (code) {
    const types = TARGET_TYPES.filter((t) => publicId.prefixOf(t) === code.prefix);
    if (types.length > 0) filters.push({ target_id: code.id, target_type: { in: types } });
  }
  return filters;
};

const shapeLog = (l) => {
  const detail = audit.parseDetail(l.detail);
  return {
    log_id: l.log_id,
    log_no: publicId.encode('log', l.log_id),
    action: l.action,
    target_type: l.target_type,
    target_id: l.target_id,
    target_no: l.target_id == null ? null : publicId.encode(l.target_type, l.target_id),
    summary: detail.summary,
    changes: detail.changes ?? [],
    can_undo: Boolean(detail.undo) && !detail.reverted,
    reverted: detail.reverted ?? null,
    // 舊版 App 讀的是 detail。
    detail: detail.summary,
    ip_address: l.ip_address,
    created_at: l.created_at,
    admin: l.users
  };
};

const pageOfLogs = async (where, { skip, limit }, userSelect) => {
  const [logs, total] = await Promise.all([
    prisma.admin_operation_logs.findMany({
      where,
      skip,
      take: limit,
      orderBy: { created_at: 'desc' },
      include: { users: { select: userSelect } }
    }),
    prisma.admin_operation_logs.count({ where })
  ]);
  return { rows: logs.map(shapeLog), total };
};

const operationLogs = ({ targetType, adminId, keyword, skip, limit }) => pageOfLogs({
  ...(targetType && { target_type: targetType }),
  ...(adminId && { admin_id: adminId }),
  ...(keyword && { OR: keywordFilters(keyword) })
}, { skip, limit }, userBrief);

const maintenanceLogs = ({ skip, limit }) =>
  pageOfLogs({ target_type: { in: ['cabinet', 'cabinet_slot'] } }, { skip, limit }, userName);

const revert = async (logId, { user, req }) => {
  const log = await prisma.admin_operation_logs.findUnique({ where: { log_id: logId } });
  if (!log) throw notFound('找不到此操作紀錄');

  const detail = audit.parseDetail(log.detail);
  if (!detail.undo) throw conflict('此操作無法自動還原（例如涉及金流、密碼或已刪除的檔案），請至對應頁面手動處理');
  if (detail.reverted) throw conflict('此操作已還原');

  const permission = undo.PERMISSION_BY_TARGET[log.target_type];
  if (!permission || !(await hasPermission(user, permission))) {
    throw forbidden('您沒有此功能的權限，無法還原此操作');
  }

  return prisma.$transaction(async (tx) => {
    // 以原紀錄內容為條件更新，避免兩人同時還原。
    const reverted = { at: new Date().toISOString(), by: user.userId };
    const claimed = await tx.admin_operation_logs.updateMany({
      where: { log_id: logId, detail: log.detail },
      data: { detail: JSON.stringify({ ...detail, reverted }) }
    });
    if (claimed.count === 0) throw conflict('此操作已被其他人還原');

    await undo.run(tx, detail.undo, { adminId: user.userId, label: detail.summary });

    const entry = await audit.record(tx, {
      adminId: user.userId,
      action: `還原：${log.action}`,
      targetType: log.target_type,
      targetId: log.target_id,
      summary: `還原 ${publicId.encode('log', logId)}「${detail.summary}」`,
      changes: (detail.changes ?? []).map((c) => ({ ...c, from: c.to, to: c.from })),
      req
    });

    await tx.admin_operation_logs.update({
      where: { log_id: logId },
      data: { detail: JSON.stringify({ ...detail, reverted: { ...reverted, log_id: entry.log_id } }) }
    });
    return entry;
  });
};

module.exports = { TARGET_TYPES, operationLogs, maintenanceLogs, revert };
