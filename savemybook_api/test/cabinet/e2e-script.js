// 端對端：以子行程執行 scripts/simulate-cabinet-flow.js，對本測試伺服器跑完 6 步劇本（實際時間，約需數十秒）。
const assert = require('assert');
const path = require('path');
const { spawn } = require('child_process');
const server = require('../lib/server');
const h = require('./session-harness');

const { api, prisma } = h;
const bcrypt = require(path.join(server.API_ROOT, 'node_modules/bcrypt'));
const devices = api('services/cabinet-devices');

const SCRIPT = path.join(server.API_ROOT, 'scripts/simulate-cabinet-flow.js');
const PIN = '135790';

const runScript = (args, env) => new Promise((resolve) => {
  const child = spawn(process.execPath, [SCRIPT, ...args], { env: { ...process.env, ...env }, stdio: ['ignore', 'pipe', 'pipe'] });
  let output = '';
  child.stdout.on('data', (chunk) => { output += chunk; });
  child.stderr.on('data', (chunk) => { output += chunk; });
  const timer = setTimeout(() => child.kill('SIGKILL'), 180000);
  child.on('exit', (code) => {
    clearTimeout(timer);
    resolve({ code, output });
  });
});

module.exports = {
  name: '端對端：simulate-cabinet-flow.js 對測試伺服器跑完劇本',
  tests: [
    ['先行存書、取回、再次存書、直接購買、取書、依訂單存書全部完成', async () => {
      const seller = h.addUser({ nickname: '賣家', balance: 0 });
      const buyer = h.addUser({ nickname: '買家', balance: 1000 });
      prisma.rows('user_security').push({
        user_id: buyer.user_id, payment_pin_hash: bcrypt.hashSync(PIN, 4), pin_failed_count: 0, pin_locked_until: null,
        pin_updated_at: new Date(), tokens_valid_after: null
      });
      const cabinet = h.addCabinet({ name: '北商大書櫃' });
      const book = h.addBook({ sellerId: seller.user_id, cabinet_id: cabinet.cabinet_id, title: '資料庫系統概論', price: 120 });
      const other = h.addBook({ sellerId: seller.user_id, cabinet_id: cabinet.cabinet_id, title: '作業系統', status: 'reserved' });
      const order = h.addPaidOrder({ buyerId: h.addUser().user_id, sellerId: seller.user_id, bookId: other.book_id, cabinetId: cabinet.cabinet_id });
      const pairing = await devices.createPairingCode({ cabinetId: cabinet.cabinet_id, kind: 'simulator', doorCount: 4 });
      h.uniqueDeviceId(prisma.rows('cabinet_devices').find((d) => d.status === 'pending'));

      const { code, output } = await runScript([
        '--base', server.baseUrl(), '--pairing-code', pairing.code, '--book', String(book.book_id), '--order', String(order.order_id),
        '--fast', '--yes'
      ], { SELLER_TOKEN: h.tokenFor(seller), BUYER_TOKEN: h.tokenFor(buyer), BUYER_PIN: PIN });

      if (process.env.CABINET_E2E_VERBOSE) console.log(output);
      assert.strictEqual(code, 0, output);
      assert.ok(output.includes('全部步驟完成。'), output);
      for (const step of [1, 2, 3, 4, 5, 6]) assert.ok(output.includes(`第 ${step} 步`), output);
      assert.ok(/state idle → create 201 → start 200 → match_selected ok → door_opened ok → session_closed ok → completed/.test(output), output);

      const bought = prisma.rows('orders').find((o) => o.buyer_id === buyer.user_id);
      assert.strictEqual(bought.status, 'deposited');
      assert.ok(bought.picked_up_at);
      assert.strictEqual(h.orderOf(order.order_id).status, 'deposited');
      const sessions = prisma.rows('cabinet_sessions');
      assert.strictEqual(sessions.length, 5);
      assert.ok(sessions.every((s) => s.status === 'completed'));
      assert.ok(prisma.rows('cabinet_devices').some((d) => d.status === 'active' && d.kind === 'simulator' && d.active_session_id === null));
    }]
  ]
};
