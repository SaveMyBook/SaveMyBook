const assert = require('assert');
const {
  request, prisma, ok, addUser, addBook, openRoom, say, ageMessage, messagesIn
} = require('./harness');

const IMAGE = '/uploads/chat/photo-1.jpg';
const VOICE = '/uploads/voice/clip-1.m4a';

const pair = async () => {
  const me = addUser({ nickname: '我' });
  const partner = addUser({ nickname: '對方' });
  return { me, partner, roomId: await openRoom(me, partner.user_id) };
};

const send = (user, roomId, body) => request('POST', `/api/chat/rooms/${roomId}/messages`, { token: user.token, body });

const tests = [
  ['傳送文字訊息', async () => {
    const { me, partner, roomId } = await pair();
    const res = await send(me, roomId, { content: '  午安  ' });
    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.data.kind, 'text');
    assert.strictEqual(res.body.data.content, '午安');
    assert.strictEqual(res.body.data.message_type, 'text');
    assert.strictEqual(res.body.data.edited_at, null);
    assert.deepStrictEqual(res.body.data.mentions, []);

    const inbox = prisma.rows('notifications').filter((n) => n.user_id === partner.user_id);
    assert.strictEqual(inbox.length, 1);
    assert.strictEqual(inbox[0].type, 'message');
    assert.strictEqual(inbox[0].title, '我');
    assert.strictEqual(inbox[0].content, '午安');
    assert.strictEqual(inbox[0].related_type, 'chat_room');
    assert.strictEqual(inbox[0].related_id, roomId);
    assert.strictEqual(inbox[0].actor_id, me.user_id);
  }],

  ['文字訊息的長度與型別檢查', async () => {
    const { me, roomId } = await pair();

    const empty = await send(me, roomId, { content: '   ' });
    assert.strictEqual(empty.status, 400);
    assert.strictEqual(empty.body.message, '訊息內容不可為空');

    const long = await send(me, roomId, { content: 'a'.repeat(2001) });
    assert.strictEqual(long.status, 400);
    assert.strictEqual(long.body.message, '訊息不可超過 2000 個字');

    const type = await send(me, roomId, { content: '嗨', message_type: 'sticker' });
    assert.strictEqual(type.status, 400);
    assert.strictEqual(type.body.message, 'message_type 僅接受：text, image, voice, album');
  }],

  ['傳送圖片訊息', async () => {
    const { me, roomId } = await pair();

    const bad = await send(me, roomId, { content: 'https://example.com/a.jpg', message_type: 'image' });
    assert.strictEqual(bad.status, 400);
    assert.strictEqual(bad.body.message, '圖片請先透過 /api/uploads/chat-image 上傳');

    const res = await send(me, roomId, { content: IMAGE, message_type: 'image' });
    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.data.kind, 'image');
    assert.strictEqual(res.body.data.message_type, 'image');
    assert.strictEqual(res.body.data.body, IMAGE);
  }],

  ['傳送語音訊息', async () => {
    const { me, partner, roomId } = await pair();

    const badUrl = await send(me, roomId, { content: IMAGE, message_type: 'voice', duration: 5 });
    assert.strictEqual(badUrl.body.message, '語音請先透過 /api/uploads/voice 上傳');

    const noDuration = await send(me, roomId, { content: VOICE, message_type: 'voice' });
    assert.strictEqual(noDuration.body.message, '語音長度不正確');

    const tooLong = await send(me, roomId, { content: VOICE, message_type: 'voice', duration: 121 });
    assert.strictEqual(tooLong.body.message, '語音最長 120 秒');

    const res = await send(me, roomId, { content: VOICE, message_type: 'voice', duration: 12 });
    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.data.kind, 'voice');
    assert.strictEqual(res.body.data.message_type, 'system');
    assert.deepStrictEqual(res.body.data.payload, { url: VOICE, duration: 12 });
    assert.strictEqual(prisma.rows('notifications').find((n) => n.user_id === partner.user_id).content, '[語音] 12 秒');
  }],

  ['傳送相簿訊息', async () => {
    const { me, partner, roomId } = await pair();

    const tooFew = await send(me, roomId, { content: [IMAGE], message_type: 'album' });
    assert.strictEqual(tooFew.body.message, '相簿須包含 2 至 20 張圖片');

    const tooMany = await send(me, roomId, {
      content: Array.from({ length: 21 }, (_, i) => `/uploads/chat/p${i}.jpg`), message_type: 'album'
    });
    assert.strictEqual(tooMany.body.message, '相簿須包含 2 至 20 張圖片');

    const bad = await send(me, roomId, { content: [IMAGE, 'https://example.com/b.jpg'], message_type: 'album' });
    assert.strictEqual(bad.body.message, '圖片請先透過 /api/uploads/chat-image 上傳');

    const urls = [IMAGE, '/uploads/chat/photo-2.jpg'];
    const res = await send(me, roomId, { content: urls, message_type: 'album' });
    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.data.kind, 'album');
    assert.deepStrictEqual(res.body.data.payload, { urls });
    assert.strictEqual(prisma.rows('notifications').find((n) => n.user_id === partner.user_id).content, '[圖片] 2 張');
  }],

  ['非文字訊息不可帶提及', async () => {
    const { me, roomId } = await pair();
    const res = await send(me, roomId, {
      content: IMAGE, message_type: 'image', mentions: [{ user_id: 1, start: 0, length: 3 }]
    });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.message, '僅文字訊息可提及成員');
  }],

  ['回覆訊息會帶出被回覆訊息的摘要', async () => {
    const { me, partner, roomId } = await pair();
    const target = await say(partner, roomId, '這本書還在嗎');

    const res = await send(me, roomId, { content: '還在喔', reply_to_id: target.message_id });
    assert.strictEqual(res.status, 201);
    assert.deepStrictEqual(res.body.data.reply_to, {
      message_id: target.message_id,
      sender_id: partner.user_id,
      sender_nickname: '對方',
      kind: 'text',
      preview: '這本書還在嗎',
      image_url: null
    });
    assert.strictEqual(prisma.rows('chat_messages').find((m) => m.message_id === res.body.data.message_id).reply_to_id,
      target.message_id);

    const list = ok(await request('GET', `/api/chat/rooms/${roomId}/messages`, { token: me.token }));
    assert.strictEqual(list.data[1].reply_to.message_id, target.message_id);
  }],

  ['不可回覆其他聊天室的訊息', async () => {
    const { me, roomId } = await pair();
    const other = addUser();
    const otherRoom = await openRoom(me, other.user_id);
    const foreign = await say(me, otherRoom, '另一間的訊息');

    const res = await send(me, roomId, { content: '回覆', reply_to_id: foreign.message_id });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.message, '找不到要回覆的訊息');
  }],

  ['15 分鐘內可編輯自己的文字訊息', async () => {
    const { me, roomId } = await pair();
    const message = await say(me, roomId, '原本的內容');
    ageMessage(message.message_id, 14 * 60 * 1000);

    const res = await request('PATCH', `/api/chat/rooms/${roomId}/messages/${message.message_id}`, {
      token: me.token, body: { content: '修正後的內容' }
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.message, '訊息已編輯');
    assert.strictEqual(res.body.data.content, '修正後的內容');
    assert.ok(res.body.data.edited_at);
    assert.strictEqual(messagesIn(roomId)[0].content, '修正後的內容');
  }],

  ['超過 15 分鐘無法編輯', async () => {
    const { me, roomId } = await pair();
    const message = await say(me, roomId, '太久以前的訊息');
    ageMessage(message.message_id, 16 * 60 * 1000);

    const res = await request('PATCH', `/api/chat/rooms/${roomId}/messages/${message.message_id}`, {
      token: me.token, body: { content: '想改但來不及' }
    });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.code, 'EDIT_WINDOW_PASSED');
    assert.strictEqual(res.body.message, '僅能編輯 15 分鐘內傳送的訊息');
  }],

  ['只能編輯自己的文字訊息', async () => {
    const { me, partner, roomId } = await pair();
    const hers = await say(partner, roomId, '對方的訊息');
    const denied = await request('PATCH', `/api/chat/rooms/${roomId}/messages/${hers.message_id}`, {
      token: me.token, body: { content: '亂改' }
    });
    assert.strictEqual(denied.status, 403);
    assert.strictEqual(denied.body.message, '僅能編輯自己傳送的訊息');

    const image = ok(await send(me, roomId, { content: IMAGE, message_type: 'image' })).data;
    const wrongKind = await request('PATCH', `/api/chat/rooms/${roomId}/messages/${image.message_id}`, {
      token: me.token, body: { content: '改成文字' }
    });
    assert.strictEqual(wrongKind.status, 400);
    assert.strictEqual(wrongKind.body.message, '僅能編輯文字訊息');

    const empty = await request('PATCH', `/api/chat/rooms/${roomId}/messages/${image.message_id}`, {
      token: me.token, body: { content: '' }
    });
    assert.strictEqual(empty.status, 400);
    assert.strictEqual(empty.body.message, '訊息內容不可為空');
  }],

  ['1 小時內可收回自己的訊息', async () => {
    const { me, roomId } = await pair();
    const message = await say(me, roomId, '說錯話了');
    ageMessage(message.message_id, 55 * 60 * 1000);

    const res = await request('POST', `/api/chat/rooms/${roomId}/messages/${message.message_id}/recall`, { token: me.token });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.message, '訊息已收回');
    assert.strictEqual(res.body.data.kind, 'recalled');
    assert.strictEqual(res.body.data.content, '[recalled]');
    assert.strictEqual(messagesIn(roomId)[0].message_type, 'system');

    const again = await request('POST', `/api/chat/rooms/${roomId}/messages/${message.message_id}/recall`, { token: me.token });
    assert.strictEqual(again.status, 409);
    assert.strictEqual(again.body.message, '此訊息已收回');

    const edit = await request('PATCH', `/api/chat/rooms/${roomId}/messages/${message.message_id}`, {
      token: me.token, body: { content: '想救回來' }
    });
    assert.strictEqual(edit.status, 409);
    assert.strictEqual(edit.body.message, '此訊息已收回');
  }],

  ['超過 1 小時或非自己的訊息無法收回', async () => {
    const { me, partner, roomId } = await pair();
    const mine = await say(me, roomId, '很久以前');
    ageMessage(mine.message_id, 61 * 60 * 1000);
    const late = await request('POST', `/api/chat/rooms/${roomId}/messages/${mine.message_id}/recall`, { token: me.token });
    assert.strictEqual(late.status, 400);
    assert.strictEqual(late.body.code, 'RECALL_WINDOW_PASSED');
    assert.strictEqual(late.body.message, '僅能收回 1 小時內傳送的訊息');

    const hers = await say(partner, roomId, '對方的訊息');
    const denied = await request('POST', `/api/chat/rooms/${roomId}/messages/${hers.message_id}/recall`, { token: me.token });
    assert.strictEqual(denied.status, 403);
    assert.strictEqual(denied.body.message, '僅能收回自己傳送的訊息');
  }],

  ['系統通知類訊息無法收回', async () => {
    const buyer = addUser();
    const seller = addUser();
    const book = addBook({ sellerId: seller.user_id });
    const roomId = await openRoom(buyer, seller.user_id, book.book_id);
    const card = messagesIn(roomId)[0];

    const res = await request('POST', `/api/chat/rooms/${roomId}/messages/${card.message_id}/recall`, { token: buyer.token });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.message, '此類訊息無法收回');
  }],

  ['輸入中的狀態會傳給對方並在送出後清除', async () => {
    const { me, partner, roomId } = await pair();

    ok(await request('POST', `/api/chat/rooms/${roomId}/typing`, { token: me.token, body: { typing: true } }));
    const typing = ok(await request('GET', `/api/chat/rooms/${roomId}/messages`, { token: partner.token }));
    assert.strictEqual(typing.meta.partner_typing, true);
    assert.deepStrictEqual(typing.meta.typing_user_ids, [me.user_id]);

    await say(me, roomId, '打完了');
    const done = ok(await request('GET', `/api/chat/rooms/${roomId}/messages`, { token: partner.token }));
    assert.strictEqual(done.meta.partner_typing, false);
    assert.deepStrictEqual(done.meta.typing_user_ids, []);

    ok(await request('POST', `/api/chat/rooms/${roomId}/typing`, { token: me.token, body: { typing: true } }));
    ok(await request('POST', `/api/chat/rooms/${roomId}/typing`, { token: me.token, body: { typing: false } }));
    const stopped = ok(await request('GET', `/api/chat/rooms/${roomId}/messages`, { token: partner.token }));
    assert.strictEqual(stopped.meta.partner_typing, false);
  }],

  ['讀取訊息會標記已讀，mark_read=false 則不會', async () => {
    const { me, partner, roomId } = await pair();
    await say(me, roomId, '看到請回');

    const peek = ok(await request('GET', `/api/chat/rooms/${roomId}/messages?mark_read=false`, { token: partner.token }));
    assert.strictEqual(peek.data[0].is_read, false);
    assert.strictEqual(messagesIn(roomId)[0].is_read, false);

    ok(await request('GET', `/api/chat/rooms/${roomId}/messages`, { token: partner.token }));
    assert.strictEqual(messagesIn(roomId)[0].is_read, true);

    const mine = ok(await request('GET', `/api/chat/rooms/${roomId}/messages`, { token: me.token }));
    assert.strictEqual(mine.data[0].is_read, true);
    assert.strictEqual(mine.meta.read_upto, messagesIn(roomId)[0].message_id);
    assert.deepStrictEqual(mine.meta.members_read, [{ user_id: partner.user_id, last_read_message_id: messagesIn(roomId)[0].message_id }]);
  }],

  ['增量抓取只回傳 after_id 之後的訊息，並帶出期間被收回與編輯的訊息', async () => {
    const { me, partner, roomId } = await pair();
    const first = await say(partner, roomId, '第一則');
    const second = await say(partner, roomId, '第二則');
    const third = await say(partner, roomId, '第三則');

    ok(await request('POST', `/api/chat/rooms/${roomId}/messages/${second.message_id}/recall`, { token: partner.token }));
    ok(await request('PATCH', `/api/chat/rooms/${roomId}/messages/${first.message_id}`, {
      token: partner.token, body: { content: '第一則（已修正）' }
    }));

    const res = ok(await request('GET', `/api/chat/rooms/${roomId}/messages?after_id=${second.message_id}`, { token: me.token }));
    assert.deepStrictEqual(res.data.map((m) => m.message_id), [third.message_id]);
    assert.deepStrictEqual(res.meta.recalled_ids, [second.message_id]);
    assert.strictEqual(res.meta.edited.length, 1);
    assert.strictEqual(res.meta.edited[0].message_id, first.message_id);
    assert.strictEqual(res.meta.edited[0].body, '第一則（已修正）');
    assert.strictEqual(res.meta.has_more, false);
  }],

  ['分頁：limit 與 before_id', async () => {
    const { me, partner, roomId } = await pair();
    const ids = [];
    for (let i = 1; i <= 5; i += 1) ids.push((await say(partner, roomId, `第 ${i} 則`)).message_id);

    const page = ok(await request('GET', `/api/chat/rooms/${roomId}/messages?limit=2`, { token: me.token }));
    assert.deepStrictEqual(page.data.map((m) => m.message_id), ids.slice(3));
    assert.strictEqual(page.meta.has_more, true);

    const older = ok(await request('GET', `/api/chat/rooms/${roomId}/messages?limit=2&before_id=${ids[3]}`, { token: me.token }));
    assert.deepStrictEqual(older.data.map((m) => m.message_id), ids.slice(1, 3));

    const oldest = ok(await request('GET', `/api/chat/rooms/${roomId}/messages?limit=2&before_id=${ids[1]}`, { token: me.token }));
    assert.deepStrictEqual(oldest.data.map((m) => m.message_id), [ids[0]]);
    assert.strictEqual(oldest.meta.has_more, false);
  }],

  ['非成員無法傳送或讀取訊息', async () => {
    const { roomId } = await pair();
    const outsider = addUser();

    const read = await request('GET', `/api/chat/rooms/${roomId}/messages`, { token: outsider.token });
    assert.strictEqual(read.status, 403);
    const write = await send(outsider, roomId, { content: '偷偷插話' });
    assert.strictEqual(write.status, 403);
    assert.strictEqual(write.body.message, '存取被拒');
  }],

  ['對方帳號停用後無法再傳訊息', async () => {
    const { me, partner, roomId } = await pair();
    prisma.rows('users').find((u) => u.user_id === partner.user_id).is_active = false;

    const res = await send(me, roomId, { content: '還在嗎' });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.code, 'RECIPIENT_UNAVAILABLE');

    const list = ok(await request('GET', `/api/chat/rooms/${roomId}/messages`, { token: me.token }));
    assert.strictEqual(list.meta.can_send, false);
  }]
];

module.exports = { name: '訊息', tests };
