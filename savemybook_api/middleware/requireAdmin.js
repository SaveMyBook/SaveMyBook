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

/// 其餘權限：沒有設定過細部權限的管理員視為全開，既有帳號才不會突然被鎖住。
/// 系統維運牽涉全站資料，必須明確開啟，不套用「沒設定就全開」。
const hasPermission = async (user, permission) => {
  if (!user || user.role !== 'admin') return false;
  if (!permission) return true;

  const column = PERMISSIONS[permission];
  // 打錯權限名稱要擋下來，不能變成對所有管理員開放。
  if (!column) throw new Error(`未知的管理員權限：${permission}`);

  const perms = await prisma.admin_permissions.findUnique({ where: { user_id: user.userId } });
  if (permission === 'system') return !!perms?.can_manage_system;
  return !perms || !!perms[column];
};

/// requireAdmin() 只擋身分；requireAdmin('members') 會再檢查細部權限。
const requireAdmin = (permission) => {
  if (permission && !PERMISSIONS[permission]) throw new Error(`未知的管理員權限：${permission}`);

  return async (req, res, next) => {
    if (!req.user || req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: '權限不足，僅限管理員執行此操作' });
    }
    if (await hasPermission(req.user, permission)) return next();
    res.status(403).json({ success: false, message: '您沒有這項功能的權限' });
  };
};

requireAdmin.PERMISSIONS = PERMISSIONS;
requireAdmin.hasPermission = hasPermission;

module.exports = requireAdmin;
