const prisma = require('../lib/prisma');

const PERMISSIONS = {
  transactions: 'can_manage_transactions',
  members: 'can_manage_members',
  content: 'can_manage_content',
  reports: 'can_manage_reports',
  announcements: 'can_manage_announcements',
  cabinets: 'can_manage_cabinets',
  orders: 'can_manage_orders',
  wallets: 'can_manage_wallets',
  levels: 'can_manage_levels',
  stats: 'can_view_stats',
  support: 'can_manage_support',
  system: 'can_manage_system'
};

const LABELS = {
  transactions: '交易爭議',
  members: '會員管理',
  content: '內容管理',
  reports: '檢舉審核',
  announcements: '公告與文件',
  cabinets: '書櫃管理',
  orders: '訂單管理',
  wallets: '錢包管理',
  levels: '會員等級',
  stats: '營運報表',
  support: '客服工單',
  system: '系統維運'
};

// 沒有權限資料列的管理員視為全開，但系統維運必須明確開啟。
const effectivePermissions = (row) =>
  Object.fromEntries(Object.values(PERMISSIONS).map((column) => [
    column,
    column === 'can_manage_system' ? !!row?.[column] : !row || !!row[column]
  ]));

const hasPermission = async (user, permission) => {
  if (!user || user.role !== 'admin') return false;
  if (!permission) return true;

  const column = PERMISSIONS[permission];
  // 打錯權限名稱須拋錯，不能變成對所有管理員開放。
  if (!column) throw new Error(`未知的管理員權限：${permission}`);

  const row = await prisma.admin_permissions.findUnique({ where: { user_id: user.userId } });
  return effectivePermissions(row)[column];
};

const requireAdmin = (permission) => {
  if (permission && !PERMISSIONS[permission]) throw new Error(`未知的管理員權限：${permission}`);

  return async (req, res, next) => {
    if (!req.user || req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: '權限不足，僅限管理員執行此操作' });
    }
    if (await hasPermission(req.user, permission)) return next();
    res.status(403).json({
      success: false,
      code: 'ADMIN_PERMISSION_REQUIRED',
      message: permission === 'system'
        ? '需要「系統維運」權限。這項權限預設關閉，請由已有此權限的管理員替你開啟。'
        : `您沒有「${LABELS[permission]}」的權限`
    });
  };
};

requireAdmin.PERMISSIONS = PERMISSIONS;
requireAdmin.hasPermission = hasPermission;
requireAdmin.effectivePermissions = effectivePermissions;

module.exports = requireAdmin;
