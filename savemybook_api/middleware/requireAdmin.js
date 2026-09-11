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
  support: 'can_manage_support'
};

/// requireAdmin() 只擋身分；requireAdmin('members') 會再檢查細部權限。
const requireAdmin = (permission) => async (req, res, next) => {
  if (!req.user || req.user.role !== 'admin') {
    return res.status(403).json({ success: false, message: '權限不足，僅限管理員執行此操作' });
  }

  if (!permission) return next();

  const column = PERMISSIONS[permission];
  if (!column) return next();

  try {
    const perms = await prisma.admin_permissions.findUnique({
      where: { user_id: req.user.userId }
    });

    // 沒有設定過細部權限的管理員視為全開，既有帳號才不會突然被鎖住。
    if (!perms || perms[column]) return next();

    res.status(403).json({ success: false, message: '您沒有這項功能的權限' });
  } catch (err) {
    console.error('[檢查管理員權限失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
};

requireAdmin.PERMISSIONS = PERMISSIONS;

module.exports = requireAdmin;
