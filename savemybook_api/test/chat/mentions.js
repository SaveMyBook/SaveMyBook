const assert = require('assert');
const {
  request, prisma, reset, SCHEMA, ok, addUser, openRoom, createGroup, notificationsFor
} = require('./harness');

const mentionRows = (roomId) => prisma.rows('chat_mentions').filter((m) => m.room_id === roomId);

const post = (user, roomId, body) => request('POST', `/api/chat/rooms/${roomId}/messages`, { token: user.token, body });

const tests = [
  ['提及群組成員會寫入提及紀錄並在清單顯示提及未讀', async () => {
    const owner = addUser({ nickname: '團主' });
    const target = addUser({ nickname: '甲' });
    const other = addUser({ nickname: '乙' });
    const roomId = await createGroup(owner, [target.user_id, other.user_id], { name: '讀書會' });

    const res = await post(owner, roomId, {
      content: '@甲 早安', mentions: [{ user_id: target.user_id, start: 0, length: 2 }]
    });
    assert.strictEqual(res.status, 201);
    assert.deepStrictEqual(res.body.data.mentions, [{ user_id: target.user_id, start: 0, length: 2 }]);

    const rows = mentionRows(roomId);
    assert.strictEqual(rows.length, 1);
    assert.strictEqual(rows[0].user_id, target.user_id);
    assert.strictEqual(rows[0].message_id, res.body.data.message_id);
    assert.strictEqual(
      JSON.parse(prisma.rows('chat_messages').find((m) => m.message_id === res.body.data.message_id).mentions).length, 1
    );

    const mine = ok(await request('GET', '/api/chat/rooms', { token: target.token }));
    assert.strictEqual(mine.data[0].mention_unread, true);
    const theirs = ok(await request('GET', '/api/chat/rooms', { token: other.token }));
    assert.strictEqual(theirs.data[0].mention_unread, false);

    assert.strictEqual(notificationsFor(target.user_id).at(-1).content, '團主 提及了您：@甲 早安');
    assert.strictEqual(notificationsFor(other.user_id).at(-1).content, '團主：@甲 早安');
  }],

  ['讀過訊息後提及未讀會消失', async () => {
    const owner = addUser({ nickname: '團主' });
    const target = addUser({ nickname: '甲' });
    const roomId = await createGroup(owner, [target.user_id]);
    ok(await post(owner, roomId, { content: '@甲 在嗎', mentions: [{ user_id: target.user_id, start: 0, length: 2 }] }));

    ok(await request('GET', `/api/chat/rooms/${roomId}/messages`, { token: target.token }));
    const list = ok(await request('GET', '/api/chat/rooms', { token: target.token }));
    assert.strictEqual(list.data[0].mention_unread, false);
  }],

  ['提及全體會把所有其他成員列為對象', async () => {
    const owner = addUser({ nickname: '團主' });
    const a = addUser();
    const b = addUser();
    const roomId = await createGroup(owner, [a.user_id, b.user_id]);

    const res = await post(owner, roomId, { content: '@所有人 記得帶書', mentions: [{ user_id: 0, start: 0, length: 4 }] });
    assert.strictEqual(res.status, 201);
    assert.deepStrictEqual(mentionRows(roomId).map((m) => m.user_id).sort(), [a.user_id, b.user_id].sort());
    assert.strictEqual(notificationsFor(a.user_id).at(-1).content, '團主 提及了您：@所有人 記得帶書');
    assert.strictEqual(notificationsFor(b.user_id).at(-1).content, '團主 提及了您：@所有人 記得帶書');
  }],

  ['提及資料格式不正確時會被拒絕', async () => {
    const owner = addUser({ nickname: '團主' });
    const target = addUser({ nickname: '甲' });
    const outsider = addUser();
    const roomId = await createGroup(owner, [target.user_id]);

    const cases = [
      // 起點不是 @
      ['早安 @甲', [{ user_id: target.user_id, start: 0, length: 2 }]],
      // 超出訊息長度
      ['@甲', [{ user_id: target.user_id, start: 0, length: 5 }]],
      // 長度為 0
      ['@甲 早安', [{ user_id: target.user_id, start: 0, length: 0 }]],
      // 標記區間重疊
      ['@甲@甲 早安', [{ user_id: target.user_id, start: 0, length: 3 }, { user_id: target.user_id, start: 2, length: 2 }]],
      // 非整數
      ['@甲 早安', [{ user_id: target.user_id, start: 0.5, length: 2 }]],
      // 不是物件
      ['@甲 早安', ['甲']],
      // 超過 20 個
      ['@'.repeat(40), Array.from({ length: 21 }, (_, i) => ({ user_id: target.user_id, start: i * 2, length: 1 }))],
      // 不是群組成員
      ['@路人 早安', [{ user_id: outsider.user_id, start: 0, length: 3 }]]
    ];

    for (const [content, mentions] of cases) {
      const res = await post(owner, roomId, { content, mentions });
      assert.strictEqual(res.status, 400, `${content} 應回 400，實際 ${res.status}`);
      assert.strictEqual(res.body.message, '提及的成員資料不正確');
    }
    assert.strictEqual(mentionRows(roomId).length, 0);
  }],

  ['提及位置以送出的原始字串計算，前導空白會被扣除', async () => {
    const owner = addUser({ nickname: '團主' });
    const target = addUser({ nickname: '甲' });
    const roomId = await createGroup(owner, [target.user_id]);

    const res = await post(owner, roomId, {
      content: '   @甲 早安', mentions: [{ user_id: target.user_id, start: 3, length: 2 }]
    });
    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.data.content, '@甲 早安');
    assert.deepStrictEqual(res.body.data.mentions, [{ user_id: target.user_id, start: 0, length: 2 }]);
  }],

  ['一對一聊天室不可提及成員', async () => {
    const me = addUser();
    const partner = addUser({ nickname: '對方' });
    const roomId = await openRoom(me, partner.user_id);

    const res = await post(me, roomId, {
      content: '@對方 你好', mentions: [{ user_id: partner.user_id, start: 0, length: 3 }]
    });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.message, '僅群組聊天室可提及成員');
  }],

  ['收回訊息會一併清掉提及', async () => {
    const owner = addUser({ nickname: '團主' });
    const target = addUser({ nickname: '甲' });
    const roomId = await createGroup(owner, [target.user_id]);
    const message = ok(await post(owner, roomId, {
      content: '@甲 幫我看一下', mentions: [{ user_id: target.user_id, start: 0, length: 2 }]
    })).data;

    const recalled = ok(await request('POST', `/api/chat/rooms/${roomId}/messages/${message.message_id}/recall`, {
      token: owner.token
    }));
    assert.strictEqual(recalled.data.kind, 'recalled');
    assert.deepStrictEqual(recalled.data.mentions, []);
    assert.strictEqual(mentionRows(roomId).length, 0);
    assert.strictEqual(prisma.rows('chat_messages').find((m) => m.message_id === message.message_id).mentions, null);

    const list = ok(await request('GET', '/api/chat/rooms', { token: target.token }));
    assert.strictEqual(list.data[0].mention_unread, false);
  }],

  ['編輯訊息會重新指定提及對象', async () => {
    const owner = addUser({ nickname: '團主' });
    const first = addUser({ nickname: '甲' });
    const second = addUser({ nickname: '乙' });
    const roomId = await createGroup(owner, [first.user_id, second.user_id]);
    const message = ok(await post(owner, roomId, {
      content: '@甲 早安', mentions: [{ user_id: first.user_id, start: 0, length: 2 }]
    })).data;

    const edited = ok(await request('PATCH', `/api/chat/rooms/${roomId}/messages/${message.message_id}`, {
      token: owner.token, body: { content: '@乙 早安', mentions: [{ user_id: second.user_id, start: 0, length: 2 }] }
    }));
    assert.deepStrictEqual(edited.data.mentions, [{ user_id: second.user_id, start: 0, length: 2 }]);
    assert.deepStrictEqual(mentionRows(roomId).map((m) => m.user_id), [second.user_id]);

    const cleared = ok(await request('PATCH', `/api/chat/rooms/${roomId}/messages/${message.message_id}`, {
      token: owner.token, body: { content: '大家早安' }
    }));
    assert.deepStrictEqual(cleared.data.mentions, []);
    assert.strictEqual(mentionRows(roomId).length, 0);
  }],

  ['增量抓取會帶出提及資料', async () => {
    const owner = addUser({ nickname: '團主' });
    const target = addUser({ nickname: '甲' });
    const roomId = await createGroup(owner, [target.user_id]);
    const base = ok(await request('GET', `/api/chat/rooms/${roomId}/messages`, { token: target.token }));
    const afterId = base.data.at(-1).message_id;
    await post(owner, roomId, { content: '@甲 看這裡', mentions: [{ user_id: target.user_id, start: 0, length: 2 }] });

    const res = ok(await request('GET', `/api/chat/rooms/${roomId}/messages?after_id=${afterId}`, { token: target.token }));
    assert.strictEqual(res.data.length, 1);
    assert.deepStrictEqual(res.data[0].mentions, [{ user_id: target.user_id, start: 0, length: 2 }]);
  }],

  ['尚未執行 010 時提及功能回報資料庫未更新', async () => {
    reset({ schema: SCHEMA.v2 });
    const owner = addUser({ nickname: '團主' });
    const target = addUser({ nickname: '甲' });
    const roomId = await createGroup(owner, [target.user_id]);

    const res = await post(owner, roomId, {
      content: '@甲 早安', mentions: [{ user_id: target.user_id, start: 0, length: 2 }]
    });
    assert.strictEqual(res.status, 503);
    assert.strictEqual(res.body.code, 'CHAT_V3_UNAVAILABLE');
    assert.strictEqual(res.body.message, '伺服器尚未完成資料庫更新，請聯絡管理員');
    assert.strictEqual(prisma.rows('chat_messages').filter((m) => m.message_type === 'text').length, 0);
  }]
];

module.exports = { name: '提及成員', tests };
