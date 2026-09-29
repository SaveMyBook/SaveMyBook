const assert = require('assert');
const { request, api, addUser, addAdmin, addBook, addPaidOrder, addRoom, tokenFor, prisma } = require('./harness');

const publicId = api('lib/public-id');

const addMessage = (roomId, senderId, { content = '您好', type = 'text' } = {}) => {
  const row = {
    message_id: prisma.nextId('chat_messages'),
    room_id: roomId,
    sender_id: senderId,
    content,
    message_type: type,
    is_read: false,
    created_at: new Date(),
    reply_to_id: null,
    edited_at: null,
    mentions: null
  };
  prisma.rows('chat_messages').push(row);
  return row;
};

const addReport = (reporterId, targetType, targetId) => {
  const row = {
    report_id: prisma.nextId('reports'),
    reporter_id: reporterId,
    target_type: targetType,
    target_id: targetId,
    reason: '訊息內容不當',
    evidence_urls: null,
    status: 'pending',
    admin_id: null,
    admin_note: null,
    resolved_at: null,
    created_at: new Date()
  };
  prisma.rows('reports').push(row);
  return row;
};

const reportsAdmin = () => addAdmin({ can_manage_reports: true });
const transactionsAdmin = () => addAdmin({ can_manage_transactions: true });

const tests = [
  ['爭議列表附上申請方上傳的佐證照片，僅限具交易爭議權限的管理員', async () => {
    const buyer = addUser({ balance: 500 });
    const seller = addUser({ balance: 0 });
    const book = addBook({ sellerId: seller.user_id });
    const withPhotos = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, status: 'deposited' });
    const withoutPhotos = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, status: 'deposited' });

    const filed = await request('POST', '/api/disputes', {
      token: tokenFor(buyer),
      body: {
        order_no: withPhotos.order_no,
        reason: '書況與描述不符',
        evidence_urls: ['/uploads/evidence/1700000000000-a1.jpg', 'https://example.com/outside.jpg', '/uploads/evidence/1700000000001-b2.png']
      }
    });
    assert.strictEqual(filed.status, 201);
    const plain = await request('POST', '/api/disputes', {
      token: tokenFor(buyer), body: { order_no: withoutPhotos.order_no, reason: '賣家尚未放書' }
    });
    assert.strictEqual(plain.status, 201);

    const res = await request('GET', '/api/admin/disputes', { token: tokenFor(transactionsAdmin()) });
    assert.strictEqual(res.status, 200);
    const byOrder = new Map(res.body.data.map((d) => [d.order_id, d]));
    assert.deepStrictEqual(byOrder.get(withPhotos.order_id).evidence_images, [
      '/uploads/evidence/1700000000000-a1.jpg',
      '/uploads/evidence/1700000000001-b2.png'
    ], '只列出站內上傳的佐證照片');
    assert.deepStrictEqual(byOrder.get(withoutPhotos.order_id).evidence_images, []);

    const denied = await request('GET', '/api/admin/disputes', { token: tokenFor(reportsAdmin()) });
    assert.strictEqual(denied.status, 403);
    assert.strictEqual(denied.body.code, 'ADMIN_PERMISSION_REQUIRED');
  }],

  ['檢舉訊息的列表附上被檢舉的訊息內容，收回與刪除的訊息不露出原文', async () => {
    const reporter = addUser({ nickname: '檢舉人' });
    const sender = addUser({ nickname: '傳送者' });
    const room = addRoom(reporter.user_id, sender.user_id);
    const text = addMessage(room.room_id, sender.user_id, { content: '請改用站外匯款' });
    const image = addMessage(room.room_id, sender.user_id, { content: '/uploads/chat/1700000000000-c3.jpg', type: 'image' });
    const recalled = addMessage(room.room_id, sender.user_id, { content: '[recalled]', type: 'system' });
    for (const target of [text, image, recalled]) addReport(reporter.user_id, 'message', target.message_id);
    addReport(reporter.user_id, 'message', 999);

    const res = await request('GET', '/api/admin/reports', { token: tokenFor(reportsAdmin()) });
    assert.strictEqual(res.status, 200);
    const targetOf = (id) => res.body.data.find((r) => r.target_id === id).target;

    const textTarget = targetOf(text.message_id);
    assert.strictEqual(textTarget.kind, 'text');
    assert.strictEqual(textTarget.body, '請改用站外匯款');
    assert.strictEqual(textTarget.users.nickname, '傳送者');
    assert.strictEqual(textTarget.sender_no, publicId.encode('user', sender.user_id));

    const imageTarget = targetOf(image.message_id);
    assert.strictEqual(imageTarget.kind, 'image');
    assert.strictEqual(imageTarget.body, '/uploads/chat/1700000000000-c3.jpg');

    const recalledTarget = targetOf(recalled.message_id);
    assert.strictEqual(recalledTarget.kind, 'recalled');
    assert.strictEqual(recalledTarget.body, null);

    assert.strictEqual(targetOf(999), null, '已刪除的訊息不附對象');

    const denied = await request('GET', '/api/admin/reports', { token: tokenFor(transactionsAdmin()) });
    assert.strictEqual(denied.status, 403);
  }],

  ['被檢舉訊息的前後文只取同一聊天室前後各 3 則', async () => {
    const reporter = addUser();
    const sender = addUser();
    const outsider = addUser();
    const room = addRoom(reporter.user_id, sender.user_id);
    const otherRoom = addRoom(sender.user_id, outsider.user_id);

    const messages = [];
    for (let i = 1; i <= 8; i += 1) {
      messages.push(addMessage(room.room_id, i % 2 ? sender.user_id : reporter.user_id, { content: `第 ${i} 則` }));
      addMessage(otherRoom.room_id, outsider.user_id, { content: `其他聊天室 ${i}` });
    }
    const target = messages[4];
    const report = addReport(reporter.user_id, 'message', target.message_id);

    const res = await request('GET', `/api/admin/reports/${report.report_id}/message-context`, { token: tokenFor(reportsAdmin()) });
    assert.strictEqual(res.status, 200);
    assert.deepStrictEqual(res.body.data.before.map((m) => m.body), ['第 2 則', '第 3 則', '第 4 則']);
    assert.deepStrictEqual(res.body.data.after.map((m) => m.body), ['第 6 則', '第 7 則', '第 8 則']);
    assert.ok(res.body.data.before.every((m) => m.sender_no && m.users?.nickname));

    const denied = await request('GET', `/api/admin/reports/${report.report_id}/message-context`, { token: tokenFor(transactionsAdmin()) });
    assert.strictEqual(denied.status, 403);
  }],

  ['前後文僅適用於訊息檢舉，訊息已刪除時回傳空清單', async () => {
    const reporter = addUser();
    const seller = addUser();
    const book = addBook({ sellerId: seller.user_id });
    const bookReport = addReport(reporter.user_id, 'book', book.book_id);
    const goneReport = addReport(reporter.user_id, 'message', 999);
    const token = tokenFor(reportsAdmin());

    const wrongType = await request('GET', `/api/admin/reports/${bookReport.report_id}/message-context`, { token });
    assert.strictEqual(wrongType.status, 400);
    assert.strictEqual(wrongType.body.message, '此檢舉的對象不是聊天訊息');

    const missing = await request('GET', '/api/admin/reports/9999/message-context', { token });
    assert.strictEqual(missing.status, 404);
    assert.strictEqual(missing.body.message, '找不到該檢舉');

    const gone = await request('GET', `/api/admin/reports/${goneReport.report_id}/message-context`, { token });
    assert.strictEqual(gone.status, 200);
    assert.deepStrictEqual(gone.body.data, { before: [], after: [] });
  }]
];

module.exports = { name: '後台檢舉訊息內容與爭議佐證照片', tests };
