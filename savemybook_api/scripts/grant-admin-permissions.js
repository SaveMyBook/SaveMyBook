#!/usr/bin/env node
// 用法：node scripts/grant-admin-permissions.js <email> [--all]
const prisma = require('../lib/prisma');
const { PERMISSIONS, effectivePermissions } = require('../middleware/requireAdmin');
const audit = require('../services/audit');

const main = async () => {
  const [email, flag] = process.argv.slice(2);
  if (!email) {
    console.log('用法：node scripts/grant-admin-permissions.js <管理員 Email> [--all]');
    return 1;
  }

  const user = await prisma.users.findUnique({
    where: { email: email.trim().toLowerCase() },
    select: { user_id: true, nickname: true, role: true, admin_permissions: true }
  }) ?? await prisma.users.findUnique({
    where: { email: email.trim() },
    select: { user_id: true, nickname: true, role: true, admin_permissions: true }
  });

  if (!user) {
    console.log(`❌ 找不到 ${email}`);
    return 1;
  }
  if (user.role !== 'admin') {
    console.log(`❌ ${user.nickname}（${email}）不是管理員，請先在後台把身分改成管理員`);
    return 1;
  }

  if (flag === '--all') {
    const all = Object.fromEntries(Object.values(PERMISSIONS).map((column) => [column, true]));
    await prisma.admin_permissions.upsert({
      where: { user_id: user.user_id },
      update: all,
      create: { user_id: user.user_id, ...all }
    });
    await audit.record(null, {
      adminId: user.user_id,
      action: '伺服器端開啟全部管理員權限',
      targetType: 'user',
      targetId: user.user_id,
      summary: `在伺服器上執行 scripts/grant-admin-permissions.js，替 ${user.nickname} 開啟了全部後台權限`
    });
    console.log(`✅ 已替 ${user.nickname} 開啟全部權限`);
  }

  const current = await prisma.admin_permissions.findUnique({ where: { user_id: user.user_id } });
  const effective = effectivePermissions(current);
  console.log(`\n${user.nickname}（user_id=${user.user_id}）目前的權限：`);
  for (const [name, column] of Object.entries(PERMISSIONS)) {
    console.log(`  ${effective[column] ? '✅' : '⬜'} ${name.padEnd(14)} ${column}`);
  }
  return 0;
};

main()
  .then((code) => prisma.$disconnect().then(() => process.exit(code)))
  .catch(async (err) => {
    console.error(err);
    await prisma.$disconnect();
    process.exit(1);
  });
