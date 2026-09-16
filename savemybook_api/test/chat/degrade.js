const assert = require('assert');
const {
  request, prisma, reset, SCHEMA, ok, addUser, openRoom, say
} = require('./harness');

const UNAVAILABLE = '此功能暫時無法使用，請稍後再試';

const tests = [
  ['未登入時所有聊天端點都回 401', async () => {
    for (const [method, url] of [
      ['GET', '/api/chat/rooms'],
      ['GET', '/api/chat/unread-count'],
      ['POST', '/api/chat/rooms'],
      ['GET', '/api/chat/blocks'],
      ['POST', '/api/chat/groups']
    ]) {
      const res = await request(method, url);
      assert.strictEqual(res.status, 401, `${url} 應回 401，實際 ${res.status}`);
      assert.strictEqual(res.body.message, '請先登入');
    }
  }],

  ['尚未執行 009 時群組、釘選、暱稱、編輯與轉帳皆回報資料庫未更新', async () => {
    reset({ schema: SCHEMA.v1 });
    const me = addUser();
    const partner = addUser();
    const roomId = await openRoom(me, partner.user_id);
    const message = await say(me, roomId, '先傳一則');

    const cases = [
      ['POST', '/api/chat/groups', { name: '讀書會', member_ids: [partner.user_id] }],
      ['PUT', `/api/chat/rooms/${roomId}/pin`, { pinned: true }],
      ['PUT', `/api/chat/aliases/${partner.user_id}`, { alias: '老闆' }],
      ['PATCH', `/api/chat/rooms/${roomId}/messages/${message.message_id}`, { content: '改一下' }],
      ['POST', `/api/chat/rooms/${roomId}/transfers`, { to_user_id: partner.user_id, amount: 10 }],
      ['POST', `/api/chat/rooms/${roomId}/transfer-requests`, { from_user_id: partner.user_id, amount: 10 }],
      ['PATCH', `/api/chat/groups/${roomId}`, { name: '改名' }],
      ['POST', `/api/chat/groups/${roomId}/leave`, undefined]
    ];

    for (const [method, url, body] of cases) {
      const res = await request(method, url, { token: me.token, ...(body ? { body } : {}) });
      assert.strictEqual(res.status, 503, `${url} 應回 503，實際 ${res.status}`);
      assert.strictEqual(res.body.code, 'CHAT_V2_UNAVAILABLE');
      assert.strictEqual(res.body.message, UNAVAILABLE);
    }
  }],

  ['尚未執行 009 時一對一聊天仍可正常收發、收回與計算未讀', async () => {
    reset({ schema: SCHEMA.v1 });
    const me = addUser({ nickname: '我' });
    const partner = addUser({ nickname: '對方' });
    const roomId = await openRoom(me, partner.user_id);
    assert.strictEqual(prisma.rows('chat_room_members').length, 0);

    const message = await say(me, roomId, '哈囉');
    const list = ok(await request('GET', '/api/chat/rooms', { token: partner.token }));
    assert.strictEqual(list.data.length, 1);
    assert.strictEqual(list.data[0].type, 'direct');
    assert.strictEqual(list.data[0].title, '我');
    assert.strictEqual(list.data[0].unread_count, 1);
    assert.strictEqual(list.data[0].pinned, false);

    const total = ok(await request('GET', '/api/chat/unread-count', { token: partner.token }));
    assert.strictEqual(total.data.unread_count, 1);

    const recalled = ok(await request('POST', `/api/chat/rooms/${roomId}/messages/${message.message_id}/recall`, {
      token: me.token
    }));
    assert.strictEqual(recalled.data.kind, 'recalled');

    ok(await request('PATCH', '/api/chat/read-all', { token: partner.token }));
    const after = ok(await request('GET', '/api/chat/unread-count', { token: partner.token }));
    assert.strictEqual(after.data.unread_count, 0);
  }],

  ['尚未執行 008 時靜音與封鎖回報資料庫未更新', async () => {
    reset({ schema: SCHEMA.v0 });
    const me = addUser();
    const partner = addUser();
    const roomId = await openRoom(me, partner.user_id);

    const cases = [
      ['PUT', `/api/chat/rooms/${roomId}/mute`, { muted: true }],
      ['PUT', `/api/chat/blocks/${partner.user_id}`, undefined],
      ['DELETE', `/api/chat/blocks/${partner.user_id}`, undefined],
      ['GET', '/api/chat/blocks', undefined]
    ];
    for (const [method, url, body] of cases) {
      const res = await request(method, url, { token: me.token, ...(body ? { body } : {}) });
      assert.strictEqual(res.status, 503, `${url} 應回 503，實際 ${res.status}`);
      assert.strictEqual(res.body.code, 'CHAT_CONTROLS_UNAVAILABLE');
      assert.strictEqual(res.body.message, UNAVAILABLE);
    }
  }],

  ['尚未執行 008 時回覆訊息會被忽略而不是報錯', async () => {
    reset({ schema: SCHEMA.v0 });
    const me = addUser();
    const partner = addUser();
    const roomId = await openRoom(me, partner.user_id);
    const target = await say(partner, roomId, '原始訊息');

    const res = await request('POST', `/api/chat/rooms/${roomId}/messages`, {
      token: me.token, body: { content: '回覆', reply_to_id: target.message_id }
    });
    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.data.reply_to, null);

    const list = ok(await request('GET', `/api/chat/rooms/${roomId}/messages`, { token: me.token }));
    assert.strictEqual(list.data[1].reply_to, null);
    assert.strictEqual(list.meta.muted, false);
  }]
];

module.exports = { name: '資料庫版本降級與權限', tests };
