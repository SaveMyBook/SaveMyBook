const assert = require('assert');
const {
  request, prisma, ok, addUser, openRoom, say, messagesIn, reset
} = require('./harness');
const { registerModels } = require('../lib/fake-prisma');

registerModels({ autoKeys: { chat_risk_alerts: 'alert_id' } });

const withRiskTables = () => reset({ tables: { chat_message_risks: [], chat_risk_alerts: [], orders: [] } });

const pair = async () => {
  const me = addUser({ nickname: '賣家' });
  const partner = addUser({ nickname: '買家' });
  return { me, partner, roomId: await openRoom(me, partner.user_id) };
};

const send = (user, roomId, body) => request('POST', `/api/chat/rooms/${roomId}/messages`, { token: user.token, body });

const read = async (user, roomId) => ok(await request('GET', `/api/chat/rooms/${roomId}/messages`, { token: user.token }));

const riskOf = (page, content) => page.data.find((m) => m.content === content)?.risk;

const makeVeteran = (user) => {
  user.created_at = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);
  prisma.rows('orders').push({ order_id: prisma.nextId('orders'), buyer_id: user.user_id, seller_id: 1, status: 'completed' });
};

const tests = [
  ['含聯絡方式的訊息須由傳送者確認後才送出', async () => {
    const { me, roomId } = await pair();

    const first = await send(me, roomId, { content: '加我line abc123' });
    assert.strictEqual(first.status, 409);
    assert.strictEqual(first.body.code, 'RISK_CONFIRM_REQUIRED');
    assert.deepStrictEqual(first.body.categories, ['contact']);
    assert.strictEqual(messagesIn(roomId).length, 0);

    const confirmed = await send(me, roomId, { content: '加我line abc123', confirm_risk: true });
    assert.strictEqual(confirmed.status, 201);
  }],

  ['拆成多則傳送的聯絡方式也會被偵測', async () => {
    const { me, roomId } = await pair();
    await say(me, roomId, '要不要加我');
    const second = await send(me, roomId, { content: 'line 搜 abc123' });
    assert.strictEqual(second.status, 409);
    assert.deepStrictEqual(second.body.categories, ['contact']);
  }],

  ['常見的一般對話不會誤判', async () => {
    const { me, partner, roomId } = await pair();
    for (const text of ['這本 linear algebra 可以放書櫃嗎', '轉帳給你了', 'ISBN 9789570912345', '要輸入密碼才能取書嗎', '我是賴老師的學生']) {
      const res = await send(me, roomId, { content: text });
      assert.strictEqual(res.status, 201, text);
    }
    const page = await read(partner, roomId);
    assert.ok(page.data.every((m) => m.risk === null));
    assert.strictEqual(page.meta.risk_banner, null);
  }],

  ['只有收訊方看得到風險標記', async () => {
    const { me, partner, roomId } = await pair();
    await say(me, roomId, '我的電話 0912-345-678', { confirm_risk: true });

    const theirs = await read(partner, roomId);
    assert.deepStrictEqual(riskOf(theirs, '我的電話 0912-345-678'), { level: 'notice', categories: ['contact'] });
    assert.strictEqual(theirs.meta.risk_banner, null);

    const mine = await read(me, roomId);
    assert.strictEqual(riskOf(mine, '我的電話 0912-345-678'), null);
  }],

  ['索取驗證碼不需確認即可送出，但對方會看到高風險提醒', async () => {
    const { me, partner, roomId } = await pair();
    await say(me, roomId, '請把手機簡訊驗證碼傳給我');
    const page = await read(partner, roomId);
    assert.deepStrictEqual(riskOf(page, '請把手機簡訊驗證碼傳給我'), { level: 'high', categories: ['credential'] });
    assert.deepStrictEqual(page.meta.risk_banner, { level: 'high', categories: ['credential'] });
  }],

  ['新帳號傳送詐騙話術會提高風險等級', async () => {
    withRiskTables();
    const { me, partner, roomId } = await pair();
    await say(me, roomId, '您的帳戶被凍結，需要解除分期');
    const page = await read(partner, roomId);
    assert.strictEqual(riskOf(page, '您的帳戶被凍結，需要解除分期').level, 'high');
    assert.strictEqual(prisma.rows('chat_message_risks')[0].score, 6);
  }],

  ['有交易紀錄的舊帳號維持一般提醒', async () => {
    withRiskTables();
    const { me, partner, roomId } = await pair();
    makeVeteran(me);
    await say(me, roomId, '您的帳戶被凍結，需要解除分期');
    const page = await read(partner, roomId);
    assert.strictEqual(riskOf(page, '您的帳戶被凍結，需要解除分期').level, 'notice');
  }],

  ['24 小時內 3 則高風險訊息會建立警示並通知管理員', async () => {
    withRiskTables();
    const admin = addUser({ nickname: '管理員' });
    admin.role = 'admin';
    const { me, roomId } = await pair();

    await say(me, roomId, '請把簡訊驗證碼傳給我');
    await say(me, roomId, '驗證碼給我就好');
    assert.strictEqual(prisma.rows('chat_risk_alerts').length, 0);
    await say(me, roomId, '把信用卡背面末三碼拍給我');

    const [alert] = prisma.rows('chat_risk_alerts');
    assert.strictEqual(alert.user_id, me.user_id);
    assert.strictEqual(alert.status, 'open');
    assert.strictEqual(alert.hit_count, 3);
    const notice = prisma.rows('notifications').find((n) => n.user_id === admin.user_id);
    assert.strictEqual(notice.related_type, 'risk_alert');
    assert.strictEqual(notice.related_id, me.user_id);

    await say(me, roomId, '驗證碼是多少');
    assert.strictEqual(prisma.rows('chat_risk_alerts').length, 1);
    assert.strictEqual(prisma.rows('chat_risk_alerts')[0].hit_count, 4);
  }],

  ['管理員查看並處理防詐警示', async () => {
    withRiskTables();
    const admin = addUser({ nickname: '管理員' });
    admin.role = 'admin';
    const { me, partner, roomId } = await pair();
    for (const text of ['請把簡訊驗證碼傳給我', '驗證碼給我就好', '把信用卡背面末三碼拍給我']) await say(me, roomId, text);

    const denied = await request('GET', '/api/admin/chat-risk-alerts', { token: partner.token });
    assert.strictEqual(denied.status, 403);

    const list = ok(await request('GET', '/api/admin/chat-risk-alerts?status=open', { token: admin.token })).data;
    assert.strictEqual(list.length, 1);
    assert.strictEqual(list[0].user.user_id, me.user_id);
    assert.match(list[0].user.user_no, /^MB/);
    assert.strictEqual(list[0].samples.length, 3);
    assert.ok(list[0].samples.every((s) => s.categories.includes('credential')));

    const overview = ok(await request('GET', '/api/admin/overview', { token: admin.token }));
    assert.strictEqual(overview.data.open_risk_alert_count, 1);

    const handled = await request('PATCH', `/api/admin/chat-risk-alerts/${list[0].alert_id}`, { token: admin.token, body: { action: 'resolve' } });
    assert.strictEqual(handled.status, 200);
    assert.strictEqual(handled.body.data.status, 'resolved');

    const again = await request('PATCH', `/api/admin/chat-risk-alerts/${list[0].alert_id}`, { token: admin.token, body: { action: 'dismiss' } });
    assert.strictEqual(again.status, 409);
    assert.strictEqual(again.body.code, 'ALERT_HANDLED');

    const open = ok(await request('GET', '/api/admin/chat-risk-alerts?status=open', { token: admin.token })).data;
    assert.strictEqual(open.length, 0);
  }],

  ['編輯後才加入聯絡方式同樣需要確認', async () => {
    withRiskTables();
    const { me, partner, roomId } = await pair();
    const message = await say(me, roomId, '你好');
    const path = `/api/chat/rooms/${roomId}/messages/${message.message_id}`;

    const blocked = await request('PATCH', path, { token: me.token, body: { content: '我的電話 0912345678' } });
    assert.strictEqual(blocked.status, 409);
    assert.strictEqual(blocked.body.code, 'RISK_CONFIRM_REQUIRED');

    const edited = await request('PATCH', path, { token: me.token, body: { content: '我的電話 0912345678', confirm_risk: true } });
    assert.strictEqual(edited.status, 200);
    assert.strictEqual(prisma.rows('chat_message_risks').length, 1);

    const page = await read(partner, roomId);
    assert.deepStrictEqual(riskOf(page, '我的電話 0912345678').categories, ['contact']);
  }]
];

module.exports = { name: '聊天防詐', tests };
