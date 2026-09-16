const assert = require('assert');
const { request, prisma, ok, addUser, openRoom, say } = require('./harness');

const pair = async () => {
  const me = addUser({ nickname: '我' });
  const partner = addUser({ nickname: '對方' });
  return { me, partner, roomId: await openRoom(me, partner.user_id) };
};

const tests = [
  ['靜音與取消靜音只影響自己', async () => {
    const { me, partner, roomId } = await pair();

    const muted = ok(await request('PUT', `/api/chat/rooms/${roomId}/mute`, { token: me.token, body: { muted: true } }));
    assert.strictEqual(muted.message, '已將此聊天室設為靜音');
    assert.deepStrictEqual(muted.data, { room_id: roomId, muted: true });

    const mine = ok(await request('GET', '/api/chat/rooms', { token: me.token }));
    assert.strictEqual(mine.data[0].muted, true);
    const hers = ok(await request('GET', '/api/chat/rooms', { token: partner.token }));
    assert.strictEqual(hers.data[0].muted, false);

    const messages = ok(await request('GET', `/api/chat/rooms/${roomId}/messages`, { token: me.token }));
    assert.strictEqual(messages.meta.muted, true);
    const detail = ok(await request('GET', `/api/chat/rooms/${roomId}`, { token: me.token }));
    assert.strictEqual(detail.data.muted, true);

    // 重複靜音不會產生第二筆紀錄。
    ok(await request('PUT', `/api/chat/rooms/${roomId}/mute`, { token: me.token, body: { muted: true } }));
    assert.strictEqual(prisma.rows('chat_room_mutes').length, 1);

    const off = ok(await request('PUT', `/api/chat/rooms/${roomId}/mute`, { token: me.token, body: { muted: false } }));
    assert.strictEqual(off.message, '已取消靜音');
    assert.strictEqual(prisma.rows('chat_room_mutes').length, 0);
  }],

  ['靜音參數與權限檢查', async () => {
    const { me, roomId } = await pair();
    const outsider = addUser();

    const bad = await request('PUT', `/api/chat/rooms/${roomId}/mute`, { token: me.token, body: { muted: 'yes' } });
    assert.strictEqual(bad.status, 400);
    assert.strictEqual(bad.body.message, 'muted 必須為布林值');

    const denied = await request('PUT', `/api/chat/rooms/${roomId}/mute`, { token: outsider.token, body: { muted: true } });
    assert.strictEqual(denied.status, 403);
    assert.strictEqual(denied.body.message, '存取被拒');
  }],

  ['封鎖後自己無法傳訊息，對方則收到帳號無法接收的訊息', async () => {
    const { me, partner, roomId } = await pair();

    const blocked = ok(await request('PUT', `/api/chat/blocks/${partner.user_id}`, { token: me.token }));
    assert.strictEqual(blocked.message, '已封鎖此使用者');
    assert.deepStrictEqual(blocked.data, { user_id: partner.user_id, blocked: true });

    const mine = await request('POST', `/api/chat/rooms/${roomId}/messages`, { token: me.token, body: { content: '嗨' } });
    assert.strictEqual(mine.status, 403);
    assert.strictEqual(mine.body.code, 'CHAT_BLOCKED');
    assert.strictEqual(mine.body.message, '您已封鎖此使用者，解除封鎖後才能傳送訊息');

    const hers = await request('POST', `/api/chat/rooms/${roomId}/messages`, { token: partner.token, body: { content: '嗨' } });
    assert.strictEqual(hers.status, 400);
    assert.strictEqual(hers.body.code, 'RECIPIENT_UNAVAILABLE');
    assert.strictEqual(hers.body.message, '對方帳號目前無法接收訊息');

    const list = ok(await request('GET', '/api/chat/rooms', { token: me.token }));
    assert.strictEqual(list.data[0].blocked, true);
    const detail = ok(await request('GET', `/api/chat/rooms/${roomId}`, { token: partner.token }));
    assert.strictEqual(detail.data.blocked, false);
    const view = ok(await request('GET', `/api/chat/rooms/${roomId}/messages`, { token: partner.token }));
    assert.strictEqual(view.meta.can_send, false);
  }],

  ['解除封鎖後即可恢復傳訊息', async () => {
    const { me, partner, roomId } = await pair();
    ok(await request('PUT', `/api/chat/blocks/${partner.user_id}`, { token: me.token }));

    const removed = ok(await request('DELETE', `/api/chat/blocks/${partner.user_id}`, { token: me.token }));
    assert.strictEqual(removed.message, '已解除封鎖');
    assert.deepStrictEqual(removed.data, { user_id: partner.user_id, blocked: false });
    assert.strictEqual(prisma.rows('user_blocks').length, 0);

    const res = await request('POST', `/api/chat/rooms/${roomId}/messages`, { token: me.token, body: { content: '重新開始' } });
    assert.strictEqual(res.status, 201);
  }],

  ['封鎖名單依封鎖時間由新到舊排列', async () => {
    const me = addUser();
    const first = addUser({ nickname: '先封鎖的' });
    const second = addUser({ nickname: '後封鎖的' });
    ok(await request('PUT', `/api/chat/blocks/${first.user_id}`, { token: me.token }));
    ok(await request('PUT', `/api/chat/blocks/${second.user_id}`, { token: me.token }));
    prisma.rows('user_blocks').find((b) => b.blocked_id === first.user_id).created_at = new Date('2026-01-01T00:00:00Z');

    const { data } = ok(await request('GET', '/api/chat/blocks', { token: me.token }));
    assert.deepStrictEqual(data.map((b) => b.nickname), ['後封鎖的', '先封鎖的']);
    assert.strictEqual(data[0].user_id, second.user_id);
  }],

  ['重複封鎖與解除未封鎖的對象都不會出錯', async () => {
    const me = addUser();
    const partner = addUser();

    ok(await request('PUT', `/api/chat/blocks/${partner.user_id}`, { token: me.token }));
    ok(await request('PUT', `/api/chat/blocks/${partner.user_id}`, { token: me.token }));
    assert.strictEqual(prisma.rows('user_blocks').length, 1);

    const stranger = addUser();
    const res = await request('DELETE', `/api/chat/blocks/${stranger.user_id}`, { token: me.token });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.message, '已解除封鎖');
    assert.strictEqual(prisma.rows('user_blocks').length, 1);
  }],

  ['封鎖的參數檢查', async () => {
    const me = addUser();

    const self = await request('PUT', `/api/chat/blocks/${me.user_id}`, { token: me.token });
    assert.strictEqual(self.status, 400);
    assert.strictEqual(self.body.message, '無法封鎖自己');

    const unknown = await request('PUT', '/api/chat/blocks/999999', { token: me.token });
    assert.strictEqual(unknown.status, 404);
    assert.strictEqual(unknown.body.message, '找不到該使用者');
  }],

  ['被對方封鎖時無法開啟新的聊天室，既有聊天室仍看得到', async () => {
    const me = addUser();
    const partner = addUser();
    ok(await request('PUT', `/api/chat/blocks/${me.user_id}`, { token: partner.token }));

    const res = await request('POST', '/api/chat/rooms', { token: me.token, body: { user_id: partner.user_id } });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.code, 'RECIPIENT_UNAVAILABLE');
    assert.strictEqual(prisma.rows('chat_rooms').length, 0);
  }],

  ['封鎖後仍可開啟既有聊天室但不會再貼商品卡片', async () => {
    const me = addUser();
    const partner = addUser();
    const roomId = await openRoom(me, partner.user_id);
    ok(await request('PUT', `/api/chat/blocks/${partner.user_id}`, { token: me.token }));

    const again = await openRoom(me, partner.user_id);
    assert.strictEqual(again, roomId);
    assert.strictEqual(prisma.rows('chat_messages').length, 0);
  }],

  ['設定與移除自訂暱稱', async () => {
    const { me, partner, roomId } = await pair();
    await say(partner, roomId, '午安');

    const saved = ok(await request('PUT', `/api/chat/aliases/${partner.user_id}`, { token: me.token, body: { alias: '書店老闆' } }));
    assert.strictEqual(saved.message, '已設定暱稱');
    assert.deepStrictEqual(saved.data, { user_id: partner.user_id, alias: '書店老闆' });

    const list = ok(await request('GET', '/api/chat/rooms', { token: me.token }));
    assert.strictEqual(list.data[0].title, '書店老闆');
    assert.strictEqual(list.data[0].partner.alias, '書店老闆');
    assert.strictEqual(list.data[0].partner.nickname, '對方');
    assert.strictEqual(list.data[0].last_message.sender_name, '書店老闆');

    const messages = ok(await request('GET', `/api/chat/rooms/${roomId}/messages`, { token: me.token }));
    assert.strictEqual(messages.meta.room.title, '書店老闆');
    assert.deepStrictEqual(messages.meta.aliases, { [String(partner.user_id)]: '書店老闆' });

    // 暱稱只對設定者生效。
    const hers = ok(await request('GET', '/api/chat/rooms', { token: partner.token }));
    assert.strictEqual(hers.data[0].title, '我');

    const cleared = ok(await request('PUT', `/api/chat/aliases/${partner.user_id}`, { token: me.token, body: { alias: null } }));
    assert.strictEqual(cleared.message, '已移除暱稱');
    assert.strictEqual(cleared.data.alias, null);
    assert.strictEqual(prisma.rows('chat_aliases').length, 0);
  }],

  ['更新既有暱稱不會新增第二筆', async () => {
    const me = addUser();
    const partner = addUser();
    ok(await request('PUT', `/api/chat/aliases/${partner.user_id}`, { token: me.token, body: { alias: '舊稱呼' } }));
    ok(await request('PUT', `/api/chat/aliases/${partner.user_id}`, { token: me.token, body: { alias: '新稱呼' } }));

    assert.strictEqual(prisma.rows('chat_aliases').length, 1);
    assert.strictEqual(prisma.rows('chat_aliases')[0].alias, '新稱呼');
  }],

  ['暱稱的參數檢查', async () => {
    const me = addUser();
    const partner = addUser();

    const missing = await request('PUT', `/api/chat/aliases/${partner.user_id}`, { token: me.token, body: {} });
    assert.strictEqual(missing.status, 400);
    assert.strictEqual(missing.body.message, '請提供 alias');

    const wrongType = await request('PUT', `/api/chat/aliases/${partner.user_id}`, { token: me.token, body: { alias: 12 } });
    assert.strictEqual(wrongType.status, 400);
    assert.strictEqual(wrongType.body.message, 'alias 必須為字串');

    const tooLong = await request('PUT', `/api/chat/aliases/${partner.user_id}`, {
      token: me.token, body: { alias: 'a'.repeat(31) }
    });
    assert.strictEqual(tooLong.status, 400);
    assert.strictEqual(tooLong.body.message, '暱稱不可超過 30 個字');

    const self = await request('PUT', `/api/chat/aliases/${me.user_id}`, { token: me.token, body: { alias: '我自己' } });
    assert.strictEqual(self.status, 400);
    assert.strictEqual(self.body.message, '無法為自己設定暱稱');

    const unknown = await request('PUT', '/api/chat/aliases/999999', { token: me.token, body: { alias: '路人' } });
    assert.strictEqual(unknown.status, 404);
    assert.strictEqual(unknown.body.message, '找不到該使用者');
  }]
];

module.exports = { name: '靜音、封鎖與暱稱', tests };
