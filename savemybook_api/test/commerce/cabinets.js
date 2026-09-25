const assert = require('assert');
const { request, addUser, addAdmin, addCabinet, tokenFor, logs, prisma } = require('./harness');

const cabinetRow = (id) => prisma.rows('smart_cabinets').find((c) => Number(c.cabinet_id) === Number(id));

const setMaintenance = (token, id, value) =>
  request('PATCH', `/api/admin/cabinets/${id}/maintenance`, { token, body: { is_maintenance: value } });

const tests = [
  ['設為維修中：後台列表標示、使用者端清單隱藏並寫入操作紀錄', async () => {
    const admin = addAdmin();
    const token = tokenFor(admin);
    const cabinet = addCabinet({ name: '台北車站書櫃' });
    const other = addCabinet({ name: '公館書櫃' });

    const res = await setMaintenance(token, cabinet.cabinet_id, true);
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.message, '書櫃已設為維修中');
    assert.deepStrictEqual(res.body.data, { cabinet_id: cabinet.cabinet_id, is_maintenance: true });
    assert.strictEqual(Number(cabinetRow(cabinet.cabinet_id).is_maintenance), 1);

    const list = await request('GET', '/api/admin/cabinets', { token });
    const byId = new Map(list.body.data.map((c) => [c.cabinet_id, c]));
    assert.strictEqual(byId.get(cabinet.cabinet_id).is_maintenance, true);
    assert.strictEqual(byId.get(other.cabinet_id).is_maintenance, false);

    const user = addUser();
    const publicList = await request('GET', '/api/cabinets', { token: tokenFor(user) });
    assert.deepStrictEqual(publicList.body.data.map((c) => c.cabinet_id), [other.cabinet_id]);

    const [log] = logs();
    assert.strictEqual(log.action, '書櫃設為維修中');
    assert.match(JSON.parse(log.detail).summary, /台北車站書櫃.*維修中/);
  }],

  ['結束維修後重新出現在使用者端清單', async () => {
    const token = tokenFor(addAdmin());
    const cabinet = addCabinet({ isMaintenance: true });

    const res = await setMaintenance(token, cabinet.cabinet_id, false);
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.message, '書櫃已結束維修');
    assert.strictEqual(Number(cabinetRow(cabinet.cabinet_id).is_maintenance), 0);

    const publicList = await request('GET', '/api/cabinets', { token: tokenFor(addUser()) });
    assert.deepStrictEqual(publicList.body.data.map((c) => c.cabinet_id), [cabinet.cabinet_id]);
  }],

  ['維修中的書櫃不可用於上架', async () => {
    const cabinet = addCabinet({ isMaintenance: true });
    const seller = addUser();
    const res = await request('POST', '/api/books', {
      token: tokenFor(seller), body: { title: '小王子', price: 100, cabinet_id: cabinet.cabinet_id }
    });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.message, '此書櫃維修中，請選擇其他書櫃');
  }],

  ['缺少 is_maintenance、書櫃不存在或沒有書櫃權限時拒絕', async () => {
    const token = tokenFor(addAdmin());
    const missing = await request('PATCH', '/api/admin/cabinets/1/maintenance', { token, body: {} });
    assert.strictEqual(missing.status, 400);

    const notFound = await setMaintenance(token, 999, true);
    assert.strictEqual(notFound.status, 404);

    const cabinet = addCabinet();
    const limited = addAdmin({ can_manage_cabinets: false });
    const denied = await setMaintenance(tokenFor(limited), cabinet.cabinet_id, true);
    assert.strictEqual(denied.status, 403);
    assert.strictEqual(Number(cabinetRow(cabinet.cabinet_id).is_maintenance), 0);
  }]
];

module.exports = { name: '書櫃維修狀態', tests };
