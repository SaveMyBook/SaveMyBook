const assert = require('assert');
const {
  request, prisma, ok, addUser, addDevice, openRoom, createGroup, say, enablePush, sentPushes, push
} = require('./harness');

const pushesFor = (device) => sentPushes.filter((m) => m.token === device.token);

const bodyOf = (message) => message.notification?.body ?? message.data.body;

const tests = [
  ['一對一訊息會推播給對方，標題為發送者暱稱', async () => {
    await enablePush();
    const me = addUser({ nickname: '賣家', avatarUrl: '/uploads/avatars/a.png' });
    const partner = addUser({ nickname: '買家' });
    const device = addDevice(partner.user_id);
    const roomId = await openRoom(me, partner.user_id);
    await say(me, roomId, '書還在喔');

    assert.strictEqual(await push.dispatchOnce(), 1);
    const [message] = pushesFor(device);
    assert.strictEqual(message.notification.title, '賣家');
    assert.strictEqual(message.notification.body, '書還在喔');
    assert.strictEqual(message.data.type, 'message');
    assert.strictEqual(message.data.related_type, 'chat_room');
    assert.strictEqual(message.data.related_id, String(roomId));
    assert.strictEqual(message.data.sender_id, String(me.user_id));
    assert.strictEqual(message.data.sender_name, '賣家');
    assert.strictEqual(message.data.sender_avatar, 'https://example.test/uploads/avatars/a.png');
    assert.strictEqual(message.data.room_type, 'direct');
    assert.strictEqual(message.data.thread_id, `chat_room-${roomId}`);
    assert.strictEqual(message.data.mentioned, '');
    assert.strictEqual(message.apns.payload.aps.category, 'CHAT_MESSAGE');

    // 已推播過的通知不會再送第二次。
    assert.strictEqual(await push.dispatchOnce(), 0);
    assert.strictEqual(pushesFor(device).length, 1);
  }],

  ['推播的發送者名稱會換成收件者設定的自訂暱稱', async () => {
    await enablePush();
    const me = addUser({ nickname: '賣家' });
    const partner = addUser({ nickname: '買家' });
    const device = addDevice(partner.user_id);
    const roomId = await openRoom(me, partner.user_id);
    ok(await request('PUT', `/api/chat/aliases/${me.user_id}`, { token: partner.token, body: { alias: '二手書店' } }));
    await say(me, roomId, '今天到貨');

    await push.dispatchOnce();
    const [message] = pushesFor(device);
    assert.strictEqual(message.notification.title, '二手書店');
    assert.strictEqual(message.data.sender_name, '二手書店');
    assert.strictEqual(message.data.room_title, '二手書店');
  }],

  ['群組訊息的推播標題為群組名稱，內文帶發送者名稱', async () => {
    await enablePush();
    const owner = addUser({ nickname: '團主' });
    const member = addUser({ nickname: '甲' });
    const device = addDevice(member.user_id);
    const roomId = await createGroup(owner, [member.user_id], { name: '週五讀書會' });
    ok(await request('PUT', `/api/chat/aliases/${owner.user_id}`, { token: member.token, body: { alias: '老王' } }));
    await say(owner, roomId, '記得帶書');

    await push.dispatchOnce();
    const messages = pushesFor(device);
    const latest = messages.find((m) => bodyOf(m).includes('記得帶書'));
    assert.strictEqual(latest.notification.title, '週五讀書會');
    assert.strictEqual(latest.notification.body, '老王：記得帶書');
    assert.strictEqual(latest.data.room_type, 'group');
    assert.strictEqual(latest.data.room_title, '週五讀書會');
    assert.strictEqual(latest.data.mentioned, '');
  }],

  ['靜音的聊天室不會推播', async () => {
    await enablePush();
    const me = addUser({ nickname: '賣家' });
    const partner = addUser({ nickname: '買家' });
    const device = addDevice(partner.user_id);
    const roomId = await openRoom(me, partner.user_id);
    ok(await request('PUT', `/api/chat/rooms/${roomId}/mute`, { token: partner.token, body: { muted: true } }));
    await say(me, roomId, '在嗎');

    assert.strictEqual(await push.dispatchOnce(), 1);
    assert.strictEqual(pushesFor(device).length, 0);
    assert.strictEqual(prisma.rows('notifications').filter((n) => n.user_id === partner.user_id).length, 1);
  }],

  ['被提及時即使靜音也會推播', async () => {
    await enablePush();
    const owner = addUser({ nickname: '團主' });
    const member = addUser({ nickname: '甲' });
    const other = addUser({ nickname: '乙' });
    const device = addDevice(member.user_id);
    const otherDevice = addDevice(other.user_id);
    const roomId = await createGroup(owner, [member.user_id, other.user_id], { name: '讀書會' });
    for (const user of [member, other]) {
      ok(await request('PUT', `/api/chat/rooms/${roomId}/mute`, { token: user.token, body: { muted: true } }));
    }
    await push.dispatchOnce();
    sentPushes.length = 0;

    ok(await request('POST', `/api/chat/rooms/${roomId}/messages`, {
      token: owner.token, body: { content: '@甲 換你報告', mentions: [{ user_id: member.user_id, start: 0, length: 2 }] }
    }));
    await push.dispatchOnce();

    const [message] = pushesFor(device);
    assert.strictEqual(message.notification.title, '讀書會');
    assert.strictEqual(message.notification.body, '團主 提及了您：@甲 換你報告');
    assert.strictEqual(message.data.mentioned, '1');
    assert.strictEqual(pushesFor(otherDevice).length, 0);
  }],

  ['關閉訊息通知的使用者不會收到推播', async () => {
    await enablePush();
    const me = addUser({ nickname: '賣家' });
    const partner = addUser({ nickname: '買家' });
    const device = addDevice(partner.user_id);
    prisma.rows('user_settings').push({
      setting_id: prisma.nextId('user_settings'),
      user_id: partner.user_id,
      notification_order: true,
      notification_message: false,
      notification_promo: true
    });
    const roomId = await openRoom(me, partner.user_id);
    await say(me, roomId, '在嗎');

    await push.dispatchOnce();
    assert.strictEqual(pushesFor(device).length, 0);
  }],

  ['Android 的聊天訊息改送純 data 訊息', async () => {
    await enablePush();
    const me = addUser({ nickname: '賣家' });
    const partner = addUser({ nickname: '買家' });
    const device = addDevice(partner.user_id, { platform: 'android' });
    const roomId = await openRoom(me, partner.user_id);
    await say(me, roomId, '已出貨');

    await push.dispatchOnce();
    const [message] = pushesFor(device);
    assert.strictEqual(message.notification, undefined);
    assert.strictEqual(message.data.title, '賣家');
    assert.strictEqual(message.data.body, '已出貨');
    assert.strictEqual(message.android.priority, 'HIGH');
  }],

  ['停用或被列入黑名單的帳號不會收到推播', async () => {
    await enablePush();
    const me = addUser({ nickname: '賣家' });
    const partner = addUser({ nickname: '買家' });
    const device = addDevice(partner.user_id);
    const roomId = await openRoom(me, partner.user_id);
    await say(me, roomId, '在嗎');
    prisma.rows('users').find((u) => u.user_id === partner.user_id).is_blacklisted = true;

    await push.dispatchOnce();
    assert.strictEqual(pushesFor(device).length, 0);
  }]
];

module.exports = { name: '聊天推播', tests };
