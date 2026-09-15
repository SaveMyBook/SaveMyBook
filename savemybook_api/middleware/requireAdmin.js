const { ADMIN_PERMISSIONS, ADMIN_PERMISSION_LABELS } = require('../constants/domain');
const { hasPermission } = require('../services/admin-permissions');

const requireAdmin = (permission) => {
  if (permission && !ADMIN_PERMISSIONS[permission]) throw new Error(`未知的管理員權限：${permission}`);

  return async (req, res, next) => {
    if (!req.user || req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: '權限不足，僅限管理員執行此操作' });
    }
    if (await hasPermission(req.user, permission)) return next();
    res.status(403).json({
      success: false,
      code: 'ADMIN_PERMISSION_REQUIRED',
      message: permission === 'system'
        ? '需要「系統維運」權限。此權限預設關閉，請由具備此權限的管理員為您開啟。'
        : `您沒有「${ADMIN_PERMISSION_LABELS[permission]}」的權限`
    });
  };
};

module.exports = requireAdmin;
