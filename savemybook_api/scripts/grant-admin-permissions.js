#!/usr/bin/env node
/**
 * 在伺服器上直接替管理員開啟全部後台權限，含預設關閉的「系統維運」。
 *
 * App 裡不能改自己的權限，「系統維運」也只能由已有這項權限的人開啟，
 * 所以第一位擁有者只能從伺服器這邊設定。之後就能在 App 裡替其他管理員開關。
 *
 *   node scripts/grant-admin-permissions.js you@example.com          查看目前權限
 *   node scripts/grant-admin-permissions.js you@example.com --all    開啟全部權限
 */
const prisma = require('../lib/prisma');
const { PERMISSIONS, effectivePermissions } = require('../middleware/requireAdmin');

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
    await prisma.admin_operation_logs.create({
      data: {
        admin_id: user.user_id,
        action: '伺服器端開啟全部管理員權限',
        target_type: 'user',
        target_id: user.user_id,
        detail: 'scripts/grant-admin-permissions.js'
      }
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
