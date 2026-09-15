const prisma = require('../lib/prisma');
const { ADMIN_PERMISSIONS } = require('../constants/domain');

const permissionRowOf = (userId) => prisma.admin_permissions.findUnique({ where: { user_id: userId } });

// 沒有權限資料列的管理員視為全開，但系統維運必須明確開啟。
const effectivePermissions = (row) =>
  Object.fromEntries(Object.values(ADMIN_PERMISSIONS).map((column) => [
    column,
    column === 'can_manage_system' ? !!row?.[column] : !row || !!row[column]
  ]));

const hasPermission = async (user, permission) => {
  if (!user || user.role !== 'admin') return false;
  if (!permission) return true;

  const column = ADMIN_PERMISSIONS[permission];
  // 打錯權限名稱須拋錯，不能變成對所有管理員開放。
  if (!column) throw new Error(`未知的管理員權限：${permission}`);

  const row = await permissionRowOf(user.userId);
  return effectivePermissions(row)[column];
};

const adminIdsWith = async (permission) => {
  const column = ADMIN_PERMISSIONS[permission];
  if (!column) throw new Error(`未知的管理員權限：${permission}`);
  const admins = await prisma.users.findMany({
    where: { role: 'admin', is_active: true, is_blacklisted: false },
    select: { user_id: true, admin_permissions: true }
  });
  return admins.filter((a) => effectivePermissions(a.admin_permissions)[column]).map((a) => a.user_id);
};

module.exports = { permissionRowOf, effectivePermissions, hasPermission, adminIdsWith };
