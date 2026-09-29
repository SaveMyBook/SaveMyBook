#!/usr/bin/env node
const prisma = require('../lib/prisma');
const devices = require('../services/cabinet-devices');
const access = require('../services/cabinet-access');

const USAGE = [
  '用法：',
  '  node scripts/cabinet-device.js pair <書櫃編號> <書櫃螢幕顯示的配對碼>',
  '  node scripts/cabinet-device.js list',
  '  node scripts/cabinet-device.js revoke <書櫃編號> --yes'
].join('\n');

const STATUS_LABELS = { active: '使用中', pending: '待配對', revoked: '已撤銷' };

const cabinetIdOf = (value) => {
  const id = Number(value);
  return Number.isInteger(id) && id > 0 ? id : null;
};

const pair = async (args) => {
  const cabinetId = cabinetIdOf(args[0]);
  if (!cabinetId || !devices.normalizePairingCode(args[1])) {
    console.log(USAGE);
    return 1;
  }
  const { cabinet, device } = await devices.claimPairing({ cabinetId, code: args[1] });
  console.log(`✅ 已為「${cabinet.cabinet_name}」配對${devices.KIND_LABELS[device.kind]}（${device.door_count} 扇櫃門，韌體 ${device.firmware}）`);
  console.log('   裝置連線後即完成配對。');
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
    await tx.cabinet_pair_requests.deleteMany({ where: { cabinet_id: cabinetId, delivered_at: null } });
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
