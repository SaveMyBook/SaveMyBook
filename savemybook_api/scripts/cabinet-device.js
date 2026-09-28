#!/usr/bin/env node
// 用法：
//   node scripts/cabinet-device.js pair <cabinet_id> --kind <simulator|esp32> [--doors <n>]
//   node scripts/cabinet-device.js list
//   node scripts/cabinet-device.js revoke <cabinet_id> --yes
const prisma = require('../lib/prisma');
const devices = require('../services/cabinet-devices');
const access = require('../services/cabinet-access');

const USAGE = [
  '用法：',
  '  node scripts/cabinet-device.js pair <書櫃編號> --kind <simulator|esp32> [--doors <櫃門數，預設 4>]',
  '  node scripts/cabinet-device.js list',
  '  node scripts/cabinet-device.js revoke <書櫃編號> --yes'
].join('\n');

const STATUS_LABELS = { active: '使用中', pending: '待配對', revoked: '已撤銷' };

const option = (args, name) => {
  const index = args.indexOf(name);
  return index >= 0 ? args[index + 1] : undefined;
};

const cabinetIdOf = (value) => {
  const id = Number(value);
  return Number.isInteger(id) && id > 0 ? id : null;
};

const pair = async (args) => {
  const cabinetId = cabinetIdOf(args[0]);
  const kind = option(args, '--kind');
  const doors = option(args, '--doors') === undefined ? 4 : Number(option(args, '--doors'));
  if (!cabinetId || !devices.KINDS.includes(kind) || !Number.isInteger(doors) || doors < 1 || doors > 8) {
    console.log(USAGE);
    return 1;
  }
  const result = await devices.createPairingCode({ cabinetId, kind, doorCount: doors });
  console.log(`✅ 已為「${result.cabinet.cabinet_name}」產生${devices.KIND_LABELS[kind]}（${doors} 扇櫃門）的配對碼`);
  console.log(`   配對碼：${result.code}`);
  console.log(`   有效期限：${result.expires_at.toLocaleString('zh-TW', { timeZone: 'Asia/Taipei', hour12: false })}（僅能使用一次）`);
  return 0;
};

const list = async () => {
  const rows = await prisma.cabinet_devices.findMany({
    where: { status: { in: ['active', 'pending'] } },
    include: { smart_cabinets: { select: { cabinet_name: true } } },
    orderBy: [{ cabinet_id: 'asc' }, { device_id: 'asc' }]
  });
  if (rows.length === 0) {
    console.log('目前沒有使用中或待配對的書櫃裝置。');
    return 0;
  }
  const now = new Date();
  for (const d of rows) {
    const online = d.status === 'active' ? (access.isOnline(d, now) ? '在線' : '離線') : '－';
    const seen = d.last_seen_at ? new Date(d.last_seen_at).toLocaleString('zh-TW', { timeZone: 'Asia/Taipei', hour12: false }) : '－';
    console.log([
      `書櫃 ${d.cabinet_id}「${d.smart_cabinets?.cabinet_name ?? ''}」`,
      devices.deviceNo(d),
      devices.KIND_LABELS[d.kind],
      STATUS_LABELS[d.status],
      `${d.door_count} 扇櫃門`,
      online,
      `最後連線 ${seen}`,
      d.fault_code ? `故障：${devices.faultLabel(d.fault_code)}` : ''
    ].filter(Boolean).join('｜'));
  }
  return 0;
};

const revoke = async (args) => {
  const cabinetId = cabinetIdOf(args[0]);
  if (!cabinetId) {
    console.log(USAGE);
    return 1;
  }
  const rows = await prisma.cabinet_devices.findMany({ where: { cabinet_id: cabinetId, status: { in: ['active', 'pending'] } } });
  if (rows.length === 0) {
    console.log('❌ 此書櫃沒有使用中或待配對的裝置。');
    return 1;
  }
  if (!args.includes('--yes')) {
    console.log(`將撤銷書櫃 ${cabinetId} 的 ${rows.length} 筆裝置資料（${rows.map((d) => `${devices.deviceNo(d)} ${STATUS_LABELS[d.status]}`).join('、')}）。`);
    console.log('確認執行請加上 --yes 重新執行。');
    return 0;
  }
  const now = new Date();
  await prisma.$transaction(async (tx) => {
    for (const device of rows.filter((d) => d.status === 'active')) {
      await devices.revoke(tx, device, { reason: 'admin', note: '伺服器端執行 scripts/cabinet-device.js', now });
    }
    await tx.cabinet_devices.deleteMany({ where: { cabinet_id: cabinetId, status: 'pending' } });
  });
  console.log(`✅ 已撤銷書櫃 ${cabinetId} 的裝置，裝置須重新配對後才能使用。`);
  return 0;
};

const main = async () => {
  const [command, ...args] = process.argv.slice(2);
  if (command === 'pair') return pair(args);
  if (command === 'list') return list();
  if (command === 'revoke') return revoke(args);
  console.log(USAGE);
  return 1;
};

main()
  .then((code) => prisma.$disconnect().then(() => process.exit(code)))
  .catch(async (err) => {
    console.error(`❌ 執行失敗：${err.message}`);
    await prisma.$disconnect().catch(() => {});
    process.exit(1);
  });
