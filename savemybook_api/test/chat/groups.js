const assert = require('assert');
const {
  request, prisma, reset, SCHEMA, ok, addUser, addBook, openRoom, createGroup, say, messagesIn
} = require('./harness');

const IMAGE = '/uploads/chat/group-avatar.png';

const notices = (roomId) => messagesIn(roomId).filter((m) => m.message_type === 'system').map((m) => m.content);

const memberRow = (roomId, userId) => prisma.rows('chat_room_members')
  .find((m) => m.room_id === roomId && m.user_id === userId);

const tests = [
  ['建立群組會設定建立者為管理員並貼出系統訊息', async () => {
    const owner = addUser({ nickname: '團主' });
    const a = addUser({ nickname: '甲' });
    const b = addUser({ nickname: '乙' });

    const res = await request('POST', '/api/chat/groups', {
      token: owner.token, body: { name: '讀書會', member_ids: [a.user_id, b.user_id, a.user_id] }
    });
    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.message, '已建立群組');
    const roomId = res.body.data.room_id;

    assert.deepStrictEqual(notices(roomId), ['團主 建立了群組']);
    const detail = ok(await request('GET', `/api/chat/rooms/${roomId}`, { token: owner.token })).data;
    assert.strictEqual(detail.type, 'group');
    assert.strictEqual(detail.name, '讀書會');
    assert.strictEqual(detail.created_by, owner.user_id);
    assert.strictEqual(detail.my_role, 'owner');
    assert.strictEqual(detail.member_count, 3);
    assert.strictEqual(detail.members.find((m) => m.user_id === a.user_id).role, 'member');
    assert.strictEqual(detail.partner, null);

    const inbox = prisma.rows('notifications').filter((n) => n.user_id === a.user_id);
    assert.strictEqual(inbox.length, 1);
    assert.strictEqual(inbox[0].title, '讀書會');
    assert.strictEqual(inbox[0].content, '團主 建立了群組');
  }],

  ['建立群組的參數檢查', async () => {
    const owner = addUser();
    const other = addUser();
    const inactive = addUser({ isActive: false });

    const cases = [
      [{ name: '', member_ids: [other.user_id] }, '請輸入群組名稱'],
      [{ name: 'a'.repeat(51), member_ids: [other.user_id] }, '群組名稱不可超過 50 個字'],
      [{ name: '群', member_ids: [] }, '請選擇成員'],
      [{ name: '群', member_ids: Array.from({ length: 51 }, (_, i) => i + 1) }, '一次最多邀請 50 人'],
      [{ name: '群', member_ids: [owner.user_id] }, '成員名單不可包含自己'],
      [{ name: '群', member_ids: [inactive.user_id] }, '成員名單包含無法加入群組的帳號'],
      [{ name: '群', member_ids: [999999] }, '成員名單包含無法加入群組的帳號'],
      [{ name: '群', member_ids: [other.user_id], avatar_url: 'https://example.com/a.png' }, '群組頭貼請先透過 /api/uploads/chat-image 上傳']
    ];

    for (const [body, message] of cases) {
      const res = await request('POST', '/api/chat/groups', { token: owner.token, body });
      assert.strictEqual(res.status, 400, `${message} 應回 400，實際 ${res.status}`);
      assert.strictEqual(res.body.message, message);
    }
  }],

  ['邀請成員會加入群組並貼出系統訊息', async () => {
    const owner = addUser({ nickname: '團主' });
    const a = addUser({ nickname: '甲' });
    const b = addUser({ nickname: '乙' });
    const c = addUser({ nickname: '丙' });
    const roomId = await createGroup(owner, [a.user_id]);

    const res = await request('POST', `/api/chat/groups/${roomId}/members`, {
      token: owner.token, body: { user_ids: [b.user_id, c.user_id] }
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.message, '已邀請成員加入群組');
    assert.deepStrictEqual(res.body.data.added_user_ids, [b.user_id, c.user_id]);
    assert.strictEqual(notices(roomId).at(-1), '團主 邀請 乙、丙 加入群組');

    const repeat = await request('POST', `/api/chat/groups/${roomId}/members`, {
      token: owner.token, body: { user_ids: [b.user_id] }
    });
    assert.strictEqual(repeat.body.message, '所選成員皆已在群組中');
    assert.deepStrictEqual(repeat.body.data.added_user_ids, []);
    assert.strictEqual(notices(roomId).length, 2);
  }],

  ['群組成員上限為 100 人', async () => {
    const owner = addUser();
    const first = Array.from({ length: 50 }, () => addUser().user_id);
    const roomId = await createGroup(owner, first);
    const second = Array.from({ length: 49 }, () => addUser().user_id);
    ok(await request('POST', `/api/chat/groups/${roomId}/members`, { token: owner.token, body: { user_ids: second } }));

    const res = await request('POST', `/api/chat/groups/${roomId}/members`, {
      token: owner.token, body: { user_ids: [addUser().user_id] }
    });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.code, 'GROUP_MEMBER_LIMIT');
    assert.strictEqual(res.body.message, '群組成員上限為 100 人');
  }],

  ['更名與更換頭貼會留下系統訊息', async () => {
    const owner = addUser({ nickname: '團主' });
    const roomId = await createGroup(owner, [addUser().user_id], { name: '舊名字' });

    const renamed = ok(await request('PATCH', `/api/chat/groups/${roomId}`, { token: owner.token, body: { name: '新名字' } }));
    assert.strictEqual(renamed.message, '已更新群組資訊');
    assert.strictEqual(renamed.data.name, '新名字');
    assert.strictEqual(notices(roomId).at(-1), '團主 將群組名稱變更為「新名字」');

    const avatar = ok(await request('PATCH', `/api/chat/groups/${roomId}`, { token: owner.token, body: { avatar_url: IMAGE } }));
    assert.strictEqual(avatar.data.avatar_url, IMAGE);
    assert.strictEqual(notices(roomId).at(-1), '團主 變更了群組頭貼');

    // 名稱沒變時不會重複貼系統訊息。
    ok(await request('PATCH', `/api/chat/groups/${roomId}`, { token: owner.token, body: { name: '新名字' } }));
    assert.strictEqual(notices(roomId).length, 3);

    const empty = await request('PATCH', `/api/chat/groups/${roomId}`, { token: owner.token, body: {} });
    assert.strictEqual(empty.status, 400);
    assert.strictEqual(empty.body.message, '請提供群組名稱或頭貼');
  }],

  ['指派與解除管理員', async () => {
    const owner = addUser({ nickname: '團主' });
    const member = addUser({ nickname: '甲' });
    const outsider = addUser();
    const roomId = await createGroup(owner, [member.user_id]);

    const promoted = ok(await request('PATCH', `/api/chat/groups/${roomId}/members/${member.user_id}`, {
      token: owner.token, body: { role: 'owner' }
    }));
    assert.strictEqual(promoted.message, '已設為管理員');
    assert.strictEqual(memberRow(roomId, member.user_id).role, 'owner');
    assert.strictEqual(notices(roomId).at(-1), '團主 將 甲 設為管理員');

    const demoted = ok(await request('PATCH', `/api/chat/groups/${roomId}/members/${member.user_id}`, {
      token: owner.token, body: { role: 'member' }
    }));
    assert.strictEqual(demoted.message, '已解除管理員身分');
    assert.strictEqual(memberRow(roomId, member.user_id).role, 'member');
    assert.strictEqual(notices(roomId).at(-1), '團主 解除 甲 的管理員身分');

    const byMember = await request('PATCH', `/api/chat/groups/${roomId}/members/${owner.user_id}`, {
      token: member.token, body: { role: 'member' }
    });
    assert.strictEqual(byMember.status, 403);
    assert.strictEqual(byMember.body.message, '僅群組管理員可變更成員權限');

    const self = await request('PATCH', `/api/chat/groups/${roomId}/members/${owner.user_id}`, {
      token: owner.token, body: { role: 'member' }
    });
    assert.strictEqual(self.status, 400);
    assert.strictEqual(self.body.message, '無法變更自己的管理員身分');

    const notMember = await request('PATCH', `/api/chat/groups/${roomId}/members/${outsider.user_id}`, {
      token: owner.token, body: { role: 'owner' }
    });
    assert.strictEqual(notMember.status, 404);
    assert.strictEqual(notMember.body.message, '此使用者不是群組成員');

    const badRole = await request('PATCH', `/api/chat/groups/${roomId}/members/${member.user_id}`, {
      token: owner.token, body: { role: 'admin' }
    });
    assert.strictEqual(badRole.status, 400);
    assert.strictEqual(badRole.body.message, '成員角色不正確');
  }],

  ['移除成員', async () => {
    const owner = addUser({ nickname: '團主' });
    const member = addUser({ nickname: '甲' });
    const second = addUser({ nickname: '乙' });
    const roomId = await createGroup(owner, [member.user_id, second.user_id]);
    ok(await request('PUT', `/api/chat/rooms/${roomId}/pin`, { token: member.token, body: { pinned: true } }));

    const byMember = await request('DELETE', `/api/chat/groups/${roomId}/members/${second.user_id}`, { token: member.token });
    assert.strictEqual(byMember.status, 403);
    assert.strictEqual(byMember.body.message, '僅群組管理員可移除成員');

    const self = await request('DELETE', `/api/chat/groups/${roomId}/members/${owner.user_id}`, { token: owner.token });
    assert.strictEqual(self.status, 400);
    assert.strictEqual(self.body.message, '無法將自己移出群組，請改用退出群組');

    const removed = ok(await request('DELETE', `/api/chat/groups/${roomId}/members/${member.user_id}`, { token: owner.token }));
    assert.strictEqual(removed.message, '已將成員移出群組');
    assert.ok(memberRow(roomId, member.user_id).left_at);
    assert.strictEqual(prisma.rows('chat_room_pins').length, 0);
    assert.strictEqual(notices(roomId).at(-1), '團主 將 甲 移出群組');

    const denied = await request('GET', `/api/chat/rooms/${roomId}/messages`, { token: member.token });
    assert.strictEqual(denied.status, 403);
    assert.strictEqual(denied.body.message, '存取被拒');

    const list = ok(await request('GET', '/api/chat/rooms', { token: member.token }));
    assert.strictEqual(list.data.length, 0);
  }],

  ['退出或被移出群組時一併清掉靜音與釘選', async () => {
    const owner = addUser({ nickname: '團主' });
    const removedMember = addUser({ nickname: '甲' });
    const leaver = addUser({ nickname: '乙' });
    const roomId = await createGroup(owner, [removedMember.user_id, leaver.user_id]);

    for (const user of [removedMember, leaver]) {
      ok(await request('PUT', `/api/chat/rooms/${roomId}/mute`, { token: user.token, body: { muted: true } }));
      ok(await request('PUT', `/api/chat/rooms/${roomId}/pin`, { token: user.token, body: { pinned: true } }));
    }
    assert.strictEqual(prisma.rows('chat_room_mutes').length, 2);

    ok(await request('DELETE', `/api/chat/groups/${roomId}/members/${removedMember.user_id}`, { token: owner.token }));
    ok(await request('POST', `/api/chat/groups/${roomId}/leave`, { token: leaver.token }));

    // 重新加入同一群組時不該沿用舊的靜音，否則使用者會在不知情的狀況下收不到通知。
    assert.strictEqual(prisma.rows('chat_room_mutes').length, 0);
    assert.strictEqual(prisma.rows('chat_room_pins').length, 0);

    ok(await request('POST', `/api/chat/groups/${roomId}/members`, {
      token: owner.token, body: { user_ids: [removedMember.user_id] }
    }));
    const list = ok(await request('GET', '/api/chat/rooms', { token: removedMember.token }));
    assert.strictEqual(list.data[0].muted ?? false, false);
  }],

  ['無法移除其他管理員', async () => {
    const owner = addUser();
    const member = addUser();
    const roomId = await createGroup(owner, [member.user_id]);
    ok(await request('PATCH', `/api/chat/groups/${roomId}/members/${member.user_id}`, {
      token: owner.token, body: { role: 'owner' }
    }));

    const res = await request('DELETE', `/api/chat/groups/${roomId}/members/${member.user_id}`, { token: owner.token });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.message, '無法移除管理員，請先解除其管理員身分');
  }],

  ['管理員退出且沒有其他管理員時由最早加入的成員接手', async () => {
    const owner = addUser({ nickname: '團主' });
    const first = addUser({ nickname: '甲' });
    const second = addUser({ nickname: '乙' });
    const roomId = await createGroup(owner, [first.user_id, second.user_id]);

    const res = ok(await request('POST', `/api/chat/groups/${roomId}/leave`, { token: owner.token }));
    assert.strictEqual(res.message, '已退出群組');
    assert.deepStrictEqual(res.data, { room_id: roomId, deleted: false });
    assert.ok(memberRow(roomId, owner.user_id).left_at);
    assert.strictEqual(memberRow(roomId, owner.user_id).role, 'member');
    assert.strictEqual(memberRow(roomId, first.user_id).role, 'owner');
    assert.strictEqual(memberRow(roomId, second.user_id).role, 'member');
    assert.strictEqual(notices(roomId).at(-1), '團主 已退出群組');
  }],

  ['已有其他管理員時退出不會再指派', async () => {
    const owner = addUser();
    const first = addUser();
    const second = addUser();
    const roomId = await createGroup(owner, [first.user_id, second.user_id]);
    ok(await request('PATCH', `/api/chat/groups/${roomId}/members/${second.user_id}`, {
      token: owner.token, body: { role: 'owner' }
    }));

    ok(await request('POST', `/api/chat/groups/${roomId}/leave`, { token: owner.token }));
    assert.strictEqual(memberRow(roomId, first.user_id).role, 'member');
    assert.strictEqual(memberRow(roomId, second.user_id).role, 'owner');
  }],

  ['最後一位成員退出時群組會被刪除', async () => {
    const owner = addUser();
    const member = addUser();
    const roomId = await createGroup(owner, [member.user_id]);
    ok(await request('POST', `/api/chat/groups/${roomId}/leave`, { token: member.token }));

    const res = ok(await request('POST', `/api/chat/groups/${roomId}/leave`, { token: owner.token }));
    assert.deepStrictEqual(res.data, { room_id: roomId, deleted: true });
    assert.strictEqual(prisma.rows('chat_rooms').length, 0);
    assert.strictEqual(prisma.rows('chat_messages').length, 0);
  }],

  ['對群組呼叫刪除聊天室等同於退出', async () => {
    const owner = addUser();
    const member = addUser();
    const roomId = await createGroup(owner, [member.user_id]);

    const res = ok(await request('DELETE', `/api/chat/rooms/${roomId}`, { token: member.token }));
    assert.strictEqual(res.message, '已退出群組');
    assert.ok(memberRow(roomId, member.user_id).left_at);
    assert.strictEqual(prisma.rows('chat_rooms').length, 1);
  }],

  ['群組操作不適用於一對一聊天室，反之亦然', async () => {
    const me = addUser();
    const partner = addUser();
    const roomId = await openRoom(me, partner.user_id);
    const book = addBook({ sellerId: partner.user_id });
    const groupId = await createGroup(me, [partner.user_id]);

    const rename = await request('PATCH', `/api/chat/groups/${roomId}`, { token: me.token, body: { name: '改名' } });
    assert.strictEqual(rename.status, 400);
    assert.strictEqual(rename.body.message, '此操作僅適用於群組聊天室');

    const leave = await request('POST', `/api/chat/groups/${roomId}/leave`, { token: me.token });
    assert.strictEqual(leave.status, 400);
    assert.strictEqual(leave.body.message, '此操作僅適用於群組聊天室');

    const reservation = await request('POST', `/api/chat/rooms/${groupId}/reservations`, {
      token: me.token, body: { book_id: book.book_id, hours: 24 }
    });
    assert.strictEqual(reservation.status, 400);
    assert.strictEqual(reservation.body.message, '群組聊天室不支援預約');
  }],

  ['非成員無法操作群組', async () => {
    const owner = addUser();
    const outsider = addUser();
    const roomId = await createGroup(owner, [addUser().user_id]);

    for (const [method, url, body] of [
      ['PATCH', `/api/chat/groups/${roomId}`, { name: '改名' }],
      ['POST', `/api/chat/groups/${roomId}/members`, { user_ids: [outsider.user_id] }],
      ['POST', `/api/chat/groups/${roomId}/leave`, undefined]
    ]) {
      const res = await request(method, url, { token: outsider.token, ...(body ? { body } : {}) });
      assert.strictEqual(res.status, 403, `${url} 應回 403，實際 ${res.status}`);
      assert.strictEqual(res.body.message, '存取被拒');
    }
  }],

  ['後來加入的成員看不到加入前的訊息', async () => {
    const owner = addUser({ nickname: '團主' });
    const first = addUser();
    const late = addUser({ nickname: '晚到的' });
    const roomId = await createGroup(owner, [first.user_id]);
    const early = await say(owner, roomId, '加入前的悄悄話');

    ok(await request('POST', `/api/chat/groups/${roomId}/members`, { token: owner.token, body: { user_ids: [late.user_id] } }));
    await say(owner, roomId, '歡迎晚到的');

    const mine = ok(await request('GET', `/api/chat/rooms/${roomId}/messages`, { token: late.token }));
    const bodies = mine.data.map((m) => m.content);
    assert.ok(!bodies.includes('加入前的悄悄話'));
    assert.deepStrictEqual(bodies, ['團主 邀請 晚到的 加入群組', '歡迎晚到的']);
    assert.strictEqual(memberRow(roomId, late.user_id).history_from_id, mine.data[0].message_id);

    // 舊成員仍看得到完整紀錄。
    const owners = ok(await request('GET', `/api/chat/rooms/${roomId}/messages`, { token: owner.token }));
    assert.ok(owners.data.some((m) => m.message_id === early.message_id));

    // 看不到的訊息也不能被收回或回覆。
    const recall = await request('POST', `/api/chat/rooms/${roomId}/messages/${early.message_id}/recall`, { token: late.token });
    assert.strictEqual(recall.status, 404);
    assert.strictEqual(recall.body.message, '找不到此訊息');
    const reply = await request('POST', `/api/chat/rooms/${roomId}/messages`, {
      token: late.token, body: { content: '回覆看不到的訊息', reply_to_id: early.message_id }
    });
    assert.strictEqual(reply.status, 400);
    assert.strictEqual(reply.body.message, '找不到要回覆的訊息');
  }],

  ['尚未執行 010 時改以加入時間判斷可見範圍', async () => {
    reset({ schema: SCHEMA.v2 });
    const owner = addUser({ nickname: '團主' });
    const first = addUser();
    const late = addUser({ nickname: '晚到的' });
    const roomId = await createGroup(owner, [first.user_id]);
    const early = await say(owner, roomId, '加入前的悄悄話');
    // DATETIME 不含毫秒，服務保留 1 秒誤差，因此舊訊息要明顯早於邀請時間才會被擋下。
    prisma.rows('chat_messages').forEach((m) => { m.created_at = new Date(Date.now() - 10 * 60 * 1000); });

    ok(await request('POST', `/api/chat/groups/${roomId}/members`, { token: owner.token, body: { user_ids: [late.user_id] } }));
    assert.strictEqual(memberRow(roomId, late.user_id).history_from_id, undefined);

    const mine = ok(await request('GET', `/api/chat/rooms/${roomId}/messages`, { token: late.token }));
    assert.deepStrictEqual(mine.data.map((m) => m.content), ['團主 邀請 晚到的 加入群組']);
    assert.ok(!mine.data.some((m) => m.message_id === early.message_id));
  }],

  ['新成員的未讀數只算加入之後的訊息', async () => {
    const owner = addUser({ nickname: '團主' });
    const roomId = await createGroup(owner, [addUser().user_id]);
    await say(owner, roomId, '舊訊息一');
    await say(owner, roomId, '舊訊息二');

    const late = addUser();
    ok(await request('POST', `/api/chat/groups/${roomId}/members`, { token: owner.token, body: { user_ids: [late.user_id] } }));
    await say(owner, roomId, '新訊息');

    const list = ok(await request('GET', '/api/chat/rooms', { token: late.token }));
    // 邀請的系統訊息 + 之後的一則。
    assert.strictEqual(list.data[0].unread_count, 2);
    const total = ok(await request('GET', '/api/chat/unread-count', { token: late.token }));
    assert.strictEqual(total.data.unread_count, 2);
  }],

  ['群組已讀游標以成員為單位記錄', async () => {
    const owner = addUser();
    const member = addUser();
    const roomId = await createGroup(owner, [member.user_id]);
    const latest = await say(owner, roomId, '大家早');

    const before = ok(await request('GET', `/api/chat/rooms/${roomId}/messages`, { token: member.token }));
    assert.strictEqual(before.meta.my_last_read_message_id, 0);
    assert.strictEqual(memberRow(roomId, member.user_id).last_read_message_id, latest.message_id);

    const after = ok(await request('GET', `/api/chat/rooms/${roomId}/messages`, { token: member.token }));
    assert.strictEqual(after.meta.my_last_read_message_id, latest.message_id);

    const ownerView = ok(await request('GET', `/api/chat/rooms/${roomId}/messages`, { token: owner.token }));
    assert.strictEqual(ownerView.meta.read_upto, latest.message_id);
    assert.deepStrictEqual(ownerView.meta.members_read, [{ user_id: member.user_id, last_read_message_id: latest.message_id }]);
    assert.strictEqual(ownerView.meta.room.member_count, 2);
  }]
];

module.exports = { name: '群組', tests };
