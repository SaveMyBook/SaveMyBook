const assert = require('assert');
const {
  request, prisma, ok, addUser, addBook, openRoom, createGroup, say, messagesIn
} = require('./harness');

const setUpdatedAt = (roomId, iso) => {
  prisma.rows('chat_rooms').find((r) => r.room_id === roomId).updated_at = new Date(iso);
};

const tests = [
  ['建立一對一聊天室後再次呼叫會回到同一間', async () => {
    const me = addUser();
    const partner = addUser();
    const first = await openRoom(me, partner.user_id);
    const second = await openRoom(partner, me.user_id);
    assert.strictEqual(second, first);
    assert.strictEqual(prisma.rows('chat_rooms').length, 1);
    assert.strictEqual(prisma.rows('chat_room_members').filter((m) => m.room_id === first).length, 2);
  }],

  ['帶書籍編號開啟聊天室會貼出商品卡片，重複開啟不會重貼', async () => {
    const buyer = addUser();
    const seller = addUser();
    const book = addBook({ sellerId: seller.user_id, title: '深入淺出設計模式', price: 350 });

    const roomId = await openRoom(buyer, seller.user_id, book.book_id);
    const cards = messagesIn(roomId);
    assert.strictEqual(cards.length, 1);
    assert.strictEqual(cards[0].message_type, 'system');
    assert.deepStrictEqual(JSON.parse(cards[0].content.slice('[book]'.length)), {
      book_id: book.book_id, title: '深入淺出設計模式', price: 350, image_url: '/uploads/books/cover.jpg'
    });

    await openRoom(buyer, seller.user_id, book.book_id);
    assert.strictEqual(messagesIn(roomId).length, 1);

    const list = ok(await request('GET', '/api/chat/rooms', { token: buyer.token }));
    assert.strictEqual(list.data[0].last_message.preview, '[商品] 深入淺出設計模式');
  }],

  ['建立聊天室的參數檢查', async () => {
    const me = addUser();
    const missing = await request('POST', '/api/chat/rooms', { token: me.token, body: {} });
    assert.strictEqual(missing.status, 400);
    assert.strictEqual(missing.body.message, '請指定聊天對象');

    const self = await request('POST', '/api/chat/rooms', { token: me.token, body: { user_id: me.user_id } });
    assert.strictEqual(self.status, 400);
    assert.strictEqual(self.body.message, '無法與自己建立聊天室');

    const unknown = await request('POST', '/api/chat/rooms', { token: me.token, body: { user_id: 999999 } });
    assert.strictEqual(unknown.status, 404);
    assert.strictEqual(unknown.body.message, '找不到該使用者');
  }],

  ['對象已停權或被列入黑名單時無法建立聊天室', async () => {
    const me = addUser();
    const inactive = addUser({ isActive: false });
    const blacklisted = addUser({ isBlacklisted: true });

    for (const target of [inactive, blacklisted]) {
      const res = await request('POST', '/api/chat/rooms', { token: me.token, body: { user_id: target.user_id } });
      assert.strictEqual(res.status, 400);
      assert.strictEqual(res.body.code, 'RECIPIENT_UNAVAILABLE');
      assert.strictEqual(res.body.message, '對方帳號目前無法接收訊息');
    }
  }],

  ['未登入或非成員無法讀取聊天室', async () => {
    const me = addUser();
    const partner = addUser();
    const outsider = addUser();
    const roomId = await openRoom(me, partner.user_id);

    const anonymous = await request('GET', `/api/chat/rooms/${roomId}`);
    assert.strictEqual(anonymous.status, 401);

    const denied = await request('GET', `/api/chat/rooms/${roomId}`, { token: outsider.token });
    assert.strictEqual(denied.status, 403);
    assert.strictEqual(denied.body.message, '存取被拒');

    const missing = await request('GET', '/api/chat/rooms/999999', { token: me.token });
    assert.strictEqual(missing.status, 404);
    assert.strictEqual(missing.body.message, '找不到該聊天室');

    const bad = await request('GET', '/api/chat/rooms/abc', { token: me.token });
    assert.strictEqual(bad.status, 400);
    assert.strictEqual(bad.body.message, '聊天室編號不正確');
  }],

  ['聊天室資訊包含成員、對象與狀態', async () => {
    const me = addUser({ nickname: '我' });
    const partner = addUser({ nickname: '對方' });
    const roomId = await openRoom(me, partner.user_id);

    const { data } = ok(await request('GET', `/api/chat/rooms/${roomId}`, { token: me.token }));
    assert.strictEqual(data.type, 'direct');
    assert.strictEqual(data.title, '對方');
    assert.strictEqual(data.member_count, 2);
    assert.strictEqual(data.my_role, null);
    assert.strictEqual(data.partner.user_id, partner.user_id);
    assert.deepStrictEqual(data.members.map((m) => m.role), ['member', 'member']);
    assert.strictEqual(data.muted, false);
    assert.strictEqual(data.pinned, false);
  }],

  ['聊天室清單先依釘選再依最後更新排序', async () => {
    const me = addUser();
    const rooms = [];
    for (let i = 0; i < 3; i += 1) rooms.push(await openRoom(me, addUser().user_id));

    setUpdatedAt(rooms[0], '2026-01-01T00:00:00Z');
    setUpdatedAt(rooms[1], '2026-03-01T00:00:00Z');
    setUpdatedAt(rooms[2], '2026-02-01T00:00:00Z');

    const before = ok(await request('GET', '/api/chat/rooms', { token: me.token }));
    assert.deepStrictEqual(before.data.map((r) => r.room_id), [rooms[1], rooms[2], rooms[0]]);

    ok(await request('PUT', `/api/chat/rooms/${rooms[0]}/pin`, { token: me.token, body: { pinned: true } }));
    const after = ok(await request('GET', '/api/chat/rooms', { token: me.token }));
    assert.deepStrictEqual(after.data.map((r) => r.room_id), [rooms[0], rooms[1], rooms[2]]);
    assert.strictEqual(after.data[0].pinned, true);
    assert.ok(after.data[0].pinned_at);
  }],

  ['未讀數會依聊天室與全站分別計算，且可一次全部標為已讀', async () => {
    const me = addUser();
    const a = addUser();
    const b = addUser();
    const roomA = await openRoom(a, me.user_id);
    const roomB = await openRoom(b, me.user_id);
    await say(a, roomA, '第一則');
    await say(a, roomA, '第二則');
    await say(b, roomB, '第三則');

    const list = ok(await request('GET', '/api/chat/rooms', { token: me.token }));
    const byId = new Map(list.data.map((r) => [r.room_id, r]));
    assert.strictEqual(byId.get(roomA).unread_count, 2);
    assert.strictEqual(byId.get(roomB).unread_count, 1);

    const total = ok(await request('GET', '/api/chat/unread-count', { token: me.token }));
    assert.strictEqual(total.data.unread_count, 3);

    const cleared = ok(await request('PATCH', '/api/chat/read-all', { token: me.token }));
    assert.strictEqual(cleared.message, '已全部標為已讀');
    const after = ok(await request('GET', '/api/chat/unread-count', { token: me.token }));
    assert.strictEqual(after.data.unread_count, 0);
  }],

  ['自己傳送的訊息不會算進未讀', async () => {
    const me = addUser();
    const partner = addUser();
    const roomId = await openRoom(me, partner.user_id);
    await say(me, roomId, '我說的話');

    const total = ok(await request('GET', '/api/chat/unread-count', { token: me.token }));
    assert.strictEqual(total.data.unread_count, 0);
    const partnerTotal = ok(await request('GET', '/api/chat/unread-count', { token: partner.token }));
    assert.strictEqual(partnerTotal.data.unread_count, 1);
  }],

  ['釘選與取消釘選', async () => {
    const me = addUser();
    const roomId = await openRoom(me, addUser().user_id);

    const pinned = ok(await request('PUT', `/api/chat/rooms/${roomId}/pin`, { token: me.token, body: { pinned: true } }));
    assert.strictEqual(pinned.message, '已釘選聊天室');
    assert.strictEqual(pinned.data.pinned, true);

    // 重複釘選維持原本的釘選時間，排序不會被打亂。
    const again = ok(await request('PUT', `/api/chat/rooms/${roomId}/pin`, { token: me.token, body: { pinned: true } }));
    assert.strictEqual(new Date(again.data.pinned_at).getTime(), new Date(pinned.data.pinned_at).getTime());
    assert.strictEqual(prisma.rows('chat_room_pins').length, 1);

    const off = ok(await request('PUT', `/api/chat/rooms/${roomId}/pin`, { token: me.token, body: { pinned: false } }));
    assert.strictEqual(off.message, '已取消釘選');
    assert.strictEqual(off.data.pinned_at, null);
    assert.strictEqual(prisma.rows('chat_room_pins').length, 0);

    const bad = await request('PUT', `/api/chat/rooms/${roomId}/pin`, { token: me.token, body: { pinned: 'yes' } });
    assert.strictEqual(bad.status, 400);
    assert.strictEqual(bad.body.message, 'pinned 必須為布林值');
  }],

  ['釘選數量上限為 10', async () => {
    const me = addUser();
    for (let i = 0; i < 10; i += 1) {
      const roomId = await openRoom(me, addUser().user_id);
      ok(await request('PUT', `/api/chat/rooms/${roomId}/pin`, { token: me.token, body: { pinned: true } }));
    }
    const extra = await openRoom(me, addUser().user_id);
    const res = await request('PUT', `/api/chat/rooms/${extra}/pin`, { token: me.token, body: { pinned: true } });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.code, 'PIN_LIMIT');
    assert.strictEqual(res.body.message, '最多僅能釘選 10 個聊天室');
  }],

  ['刪除一對一聊天室會一併刪除訊息', async () => {
    const me = addUser();
    const partner = addUser();
    const outsider = addUser();
    const roomId = await openRoom(me, partner.user_id);
    await say(me, roomId, '哈囉');

    const denied = await request('DELETE', `/api/chat/rooms/${roomId}`, { token: outsider.token });
    assert.strictEqual(denied.status, 403);
    assert.strictEqual(denied.body.message, '您沒有權限刪除此聊天室');

    const removed = ok(await request('DELETE', `/api/chat/rooms/${roomId}`, { token: me.token }));
    assert.strictEqual(removed.message, '已刪除聊天室');
    assert.strictEqual(prisma.rows('chat_rooms').length, 0);
    assert.strictEqual(prisma.rows('chat_messages').length, 0);

    const missing = await request('DELETE', `/api/chat/rooms/${roomId}`, { token: me.token });
    assert.strictEqual(missing.status, 404);
    assert.strictEqual(missing.body.message, '找不到此聊天室');
  }],

  ['群組聊天室會出現在清單中並顯示名稱與人數', async () => {
    const owner = addUser({ nickname: '團主' });
    const member = addUser();
    const roomId = await createGroup(owner, [member.user_id], { name: '週五讀書會' });

    const list = ok(await request('GET', '/api/chat/rooms', { token: member.token }));
    const room = list.data.find((r) => r.room_id === roomId);
    assert.strictEqual(room.type, 'group');
    assert.strictEqual(room.title, '週五讀書會');
    assert.strictEqual(room.member_count, 2);
    assert.strictEqual(room.partner, null);
    assert.strictEqual(room.last_message.preview, '團主 建立了群組');
  }]
];

module.exports = { name: '聊天室', tests };
