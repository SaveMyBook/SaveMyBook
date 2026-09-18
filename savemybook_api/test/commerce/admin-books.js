const assert = require('assert');
const {
  request, addUser, addAdmin, addBook, addImage, addOrder, addReservation, addCartItem,
  tokenFor, bookOf, notificationsOf, logs, reviewOf, prisma
} = require('./harness');

const scene = () => {
  const seller = addUser({ nickname: '賣家' });
  const admin = addAdmin();
  const book = addBook({ sellerId: seller.user_id, title: '小王子' });
  return { seller, admin, book, token: tokenFor(admin) };
};

const summaryOf = (log) => JSON.parse(log.detail).summary;

const tests = [
  ['管理端書籍列表附上待處理檢舉數與賣家資訊', async () => {
    const { seller, book, token } = scene();
    addImage(book.book_id, { url: '/uploads/books/cover.jpg' });
    prisma.rows('reports').push(
      { report_id: 1, reporter_id: addUser().user_id, target_type: 'book', target_id: book.book_id, status: 'pending', reason: 'a' },
      { report_id: 2, reporter_id: addUser().user_id, target_type: 'book', target_id: book.book_id, status: 'pending', reason: 'b' },
      { report_id: 3, reporter_id: addUser().user_id, target_type: 'book', target_id: book.book_id, status: 'dismissed', reason: 'c' }
    );

    const res = await request('GET', '/api/admin/books', { token });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.data.length, 1);
    assert.strictEqual(res.body.data[0].pending_report_count, 2);
    assert.strictEqual(res.body.data[0].seller.user_id, seller.user_id);
    assert.strictEqual(res.body.data[0].image_url, '/uploads/books/cover.jpg');
  }],

  ['沒有內容管理權限的管理員不可管理書籍', async () => {
    const seller = addUser();
    const book = addBook({ sellerId: seller.user_id });
    const admin = addAdmin({ can_manage_content: false });

    const res = await request('PATCH', `/api/admin/books/${book.book_id}`, {
      token: tokenFor(admin), body: { status: 'removed' }
    });
    assert.strictEqual(res.status, 403);
    assert.strictEqual(res.body.code, 'ADMIN_PERMISSION_REQUIRED');
    assert.strictEqual(res.body.message, '您沒有「內容管理」的權限');
  }],

  ['強制下架書籍並通知賣家、寫入操作紀錄', async () => {
    const { seller, book, token } = scene();

    const res = await request('PATCH', `/api/admin/books/${book.book_id}`, {
      token, body: { status: 'removed', reason: '疑似盜版' }
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.message, '已下架');
    assert.strictEqual(bookOf(book.book_id).status, 'removed');

    const notice = notificationsOf(seller.user_id)[0];
    assert.strictEqual(notice.title, '您的書籍已被下架');
    assert.strictEqual(notice.content, '《小王子》已由管理員下架。原因：疑似盜版');

    const log = logs()[0];
    assert.strictEqual(log.action, '強制下架書籍');
    assert.strictEqual(log.target_type, 'book');
    assert.strictEqual(log.target_id, book.book_id);
    assert.strictEqual(summaryOf(log), '下架《小王子》，原因：疑似盜版');
  }],

  ['恢復上架會一併解除違規標記並結案 AI 審核', async () => {
    const { seller, token } = scene();
    const book = addBook({ sellerId: seller.user_id, title: '違規的書', status: 'removed', is_approved: false });
    prisma.rows('ai_book_reviews').push({ book_id: book.book_id, status: 'rejected', verdict: 'reject' });

    const res = await request('PATCH', `/api/admin/books/${book.book_id}`, { token, body: { status: 'on_sale' } });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.message, '已恢復上架');
    assert.strictEqual(bookOf(book.book_id).status, 'on_sale');
    assert.strictEqual(bookOf(book.book_id).is_approved, true);
    assert.strictEqual(reviewOf(book.book_id).status, 'approved');

    const notice = notificationsOf(seller.user_id)[0];
    assert.strictEqual(notice.title, '您的書籍已恢復上架');
    assert.strictEqual(logs()[0].action, '恢復書籍上架');
  }],

  ['交易中或已售出的書籍不可恢復上架', async () => {
    const { seller, token } = scene();
    const reserved = addBook({ sellerId: seller.user_id, status: 'reserved' });
    const sold = addBook({ sellerId: seller.user_id, status: 'sold' });

    const one = await request('PATCH', `/api/admin/books/${reserved.book_id}`, { token, body: { status: 'on_sale' } });
    assert.strictEqual(one.status, 409);
    assert.strictEqual(one.body.message, '此書籍交易中，無法恢復上架');

    const two = await request('PATCH', `/api/admin/books/${sold.book_id}`, { token, body: { status: 'on_sale' } });
    assert.strictEqual(two.status, 409);
    assert.strictEqual(two.body.message, '此書籍已售出，無法恢復上架');
  }],

  ['管理員修改書籍資料會通知賣家並記錄變更', async () => {
    const { seller, book, token } = scene();

    const res = await request('PUT', `/api/admin/books/${book.book_id}`, {
      token, body: { title: '小王子（修訂版）', price: 180 }
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.message, '已更新');
    assert.strictEqual(bookOf(book.book_id).title, '小王子（修訂版）');
    assert.strictEqual(Number(bookOf(book.book_id).price), 180);

    const notice = notificationsOf(seller.user_id)[0];
    assert.strictEqual(notice.title, '書籍資料已由客服更新');
    assert.ok(notice.content.includes('書名改為《小王子（修訂版）》'));
    assert.ok(notice.content.includes('售價改為 180 代幣'));

    const log = logs()[0];
    assert.strictEqual(log.action, '修改書籍資料');
    const detail = JSON.parse(log.detail);
    assert.deepStrictEqual(detail.changes.map((c) => c.label), ['書名', '售價']);
    assert.ok(detail.undo, '修改資料應可還原');
  }],

  ['管理端修改書籍的欄位驗證', async () => {
    const { book, token } = scene();

    const noFields = await request('PUT', `/api/admin/books/${book.book_id}`, { token, body: {} });
    assert.strictEqual(noFields.status, 400);
    assert.strictEqual(noFields.body.message, '沒有需要修改的欄位');

    const emptyTitle = await request('PUT', `/api/admin/books/${book.book_id}`, { token, body: { title: '' } });
    assert.strictEqual(emptyTitle.status, 400);
    assert.strictEqual(emptyTitle.body.message, '書名為必填，且不可超過 255 個字元');

    const badIsbn = await request('PUT', `/api/admin/books/${book.book_id}`, { token, body: { isbn: '12345' } });
    assert.strictEqual(badIsbn.status, 400);
    assert.strictEqual(badIsbn.body.message, 'ISBN 必須是 10 或 13 位數字');

    const badPrice = await request('PUT', `/api/admin/books/${book.book_id}`, { token, body: { price: -1 } });
    assert.strictEqual(badPrice.status, 400);
    assert.strictEqual(badPrice.body.message, '售價必須介於 0 ~ 999999');

    const badCategory = await request('PUT', `/api/admin/books/${book.book_id}`, { token, body: { category_id: 999 } });
    assert.strictEqual(badCategory.status, 400);
    assert.strictEqual(badCategory.body.message, '找不到此分類');
  }],

  ['交易中或有進行中預約的書籍不可永久刪除', async () => {
    const { seller, token } = scene();
    const reserved = addBook({ sellerId: seller.user_id, status: 'reserved' });
    const held = addBook({ sellerId: seller.user_id });
    addReservation({ bookId: held.book_id, buyerId: addUser().user_id, sellerId: seller.user_id, status: 'pending' });

    const one = await request('DELETE', `/api/admin/books/${reserved.book_id}`, { token, body: {} });
    assert.strictEqual(one.status, 409);
    assert.strictEqual(one.body.code, 'BOOK_IN_TRANSACTION');
    assert.strictEqual(one.body.message, '此書籍交易或預約進行中，請先處理後再刪除');

    const two = await request('DELETE', `/api/admin/books/${held.book_id}`, { token, body: {} });
    assert.strictEqual(two.status, 409);
    assert.strictEqual(two.body.code, 'BOOK_IN_TRANSACTION');
    assert.strictEqual(prisma.rows('books').length, 3);
  }],

  ['已有訂單紀錄的書籍不可永久刪除', async () => {
    const { seller, book, token } = scene();
    const buyer = addUser();
    addOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, status: 'completed' });

    const res = await request('DELETE', `/api/admin/books/${book.book_id}`, { token, body: {} });
    assert.strictEqual(res.status, 409);
    assert.strictEqual(res.body.code, 'BOOK_HAS_ORDERS');
    assert.strictEqual(
      res.body.message,
      '此書籍已有訂單紀錄，為保留交易資料無法刪除，如需停止販售請使用強制下架'
    );
    assert.ok(bookOf(book.book_id), '書籍必須保留');
  }],

  ['永久刪除書籍會清掉關聯資料、通知賣家並記錄操作', async () => {
    const { seller, book, token } = scene();
    const fan = addUser();
    addCartItem(fan.user_id, book.book_id);
    prisma.rows('favorites').push({ favorite_id: 1, user_id: fan.user_id, book_id: book.book_id, created_at: new Date() });
    addReservation({ bookId: book.book_id, buyerId: fan.user_id, sellerId: seller.user_id, status: 'cancelled' });
    prisma.rows('recommendation_logs').push({ log_id: 1, book_id: book.book_id, user_id: fan.user_id });
    prisma.rows('chat_rooms').push({
      room_id: 1, user_a_id: fan.user_id, user_b_id: seller.user_id, book_id: book.book_id, room_type: 'direct'
    });

    const res = await request('DELETE', `/api/admin/books/${book.book_id}`, { token, body: { reason: '重複上架' } });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.message, '已刪除書籍');

    assert.strictEqual(bookOf(book.book_id), undefined);
    assert.strictEqual(prisma.rows('shopping_cart').length, 0);
    assert.strictEqual(prisma.rows('favorites').length, 0);
    assert.strictEqual(prisma.rows('reservations').length, 0);
    assert.strictEqual(prisma.rows('recommendation_logs').length, 0);
    assert.strictEqual(prisma.rows('chat_rooms')[0].book_id, null);

    const notice = notificationsOf(seller.user_id)[0];
    assert.strictEqual(notice.title, '您的書籍已被刪除');
    assert.strictEqual(notice.related_type, 'book', '刪除通知須歸入交易分類');
    assert.strictEqual(notice.related_id ?? null, null, '書籍已不存在，通知不可導向');
    assert.strictEqual(notice.content, '您的書籍《小王子》已由管理員刪除。原因：重複上架');

    const log = logs()[0];
    assert.strictEqual(log.action, '刪除書籍');
    // 書籍編號對外一律使用加密編號。
    assert.match(summaryOf(log), /^刪除書籍 BK[0-9A-Z]{7}《小王子》，並通知賣家，原因：重複上架$/);
  }],

  ['AI 審核佇列列出待審書籍', async () => {
    const { seller, book, token } = scene();
    prisma.rows('books')[0].is_approved = false;
    prisma.rows('ai_book_reviews').push({
      book_id: book.book_id,
      verdict: 'review',
      reasons: JSON.stringify(['疑似非書籍']),
      categories: JSON.stringify(['not_book']),
      status: 'pending',
      provider: 'deepseek',
      model: 'deepseek-flash',
      created_at: new Date()
    });

    const res = await request('GET', '/api/admin/ai/reviews', { token });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.data.length, 1);
    assert.strictEqual(res.body.data[0].book_id, book.book_id);
    assert.deepStrictEqual(res.body.data[0].reasons, ['疑似非書籍']);
    assert.strictEqual(res.body.data[0].seller.user_id, seller.user_id);
    assert.strictEqual(res.body.data[0].status, 'pending');
  }],

  ['核准 AI 審核：書籍公開並通知賣家', async () => {
    const { seller, book, token } = scene();
    prisma.rows('books')[0].is_approved = false;
    prisma.rows('ai_book_reviews').push({ book_id: book.book_id, status: 'pending', verdict: 'review' });

    const res = await request('PATCH', `/api/admin/ai/reviews/${book.book_id}`, {
      token, body: { decision: 'approve' }
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.message, '已核准上架');
    assert.deepStrictEqual(res.body.data, { book_id: book.book_id, status: 'approved' });
    assert.strictEqual(bookOf(book.book_id).is_approved, true);
    assert.strictEqual(reviewOf(book.book_id).status, 'approved');

    const notice = notificationsOf(seller.user_id)[0];
    assert.strictEqual(notice.title, '書籍已通過審核');
    assert.strictEqual(notice.content, '您的書籍《小王子》已通過審核，現已公開販售。');
    assert.strictEqual(logs()[0].action, '核准 AI 審核書籍');
  }],

  ['駁回 AI 審核：書籍下架並標記違規', async () => {
    const { seller, book, token } = scene();
    prisma.rows('books')[0].is_approved = false;
    prisma.rows('ai_book_reviews').push({ book_id: book.book_id, status: 'pending', verdict: 'review' });

    const res = await request('PATCH', `/api/admin/ai/reviews/${book.book_id}`, {
      token, body: { decision: 'reject', note: '販售盜版' }
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.message, '已駁回並下架');
    assert.strictEqual(bookOf(book.book_id).status, 'removed');
    assert.strictEqual(bookOf(book.book_id).is_approved, false);
    assert.strictEqual(reviewOf(book.book_id).status, 'rejected');

    const notice = notificationsOf(seller.user_id)[0];
    assert.strictEqual(notice.title, '書籍未通過審核');
    assert.ok(notice.content.includes('原因：販售盜版'));

    // 被駁回後即成為違規鎖定，賣家不可自行重新上架。
    const relist = await request('PUT', `/api/books/${book.book_id}`, {
      token: tokenFor(seller), body: { status: 'on_sale' }
    });
    assert.strictEqual(relist.status, 403);
    assert.strictEqual(relist.body.code, 'BOOK_NOT_APPROVED');
  }],

  ['重複裁決同一筆審核會被擋下', async () => {
    const { book, token } = scene();
    prisma.rows('ai_book_reviews').push({ book_id: book.book_id, status: 'approved', verdict: 'review' });

    const res = await request('PATCH', `/api/admin/ai/reviews/${book.book_id}`, {
      token, body: { decision: 'approve' }
    });
    assert.strictEqual(res.status, 409);
    assert.strictEqual(res.body.message, '此書籍已通過審核');
  }],

  ['找不到審核紀錄或裁決值不合法時回錯誤', async () => {
    const { book, token } = scene();

    const missing = await request('PATCH', `/api/admin/ai/reviews/${book.book_id}`, {
      token, body: { decision: 'approve' }
    });
    assert.strictEqual(missing.status, 404);
    assert.strictEqual(missing.body.message, '找不到此審核紀錄');

    const bad = await request('PATCH', `/api/admin/ai/reviews/${book.book_id}`, {
      token, body: { decision: 'maybe' }
    });
    assert.strictEqual(bad.status, 400);
    assert.strictEqual(bad.body.message, 'decision 僅接受：approve, reject');
  }],

  ['駁回後再核准會讓已下架的書籍重新上架', async () => {
    const { book, token } = scene();
    prisma.rows('books')[0].status = 'removed';
    prisma.rows('books')[0].is_approved = false;
    prisma.rows('ai_book_reviews').push({ book_id: book.book_id, status: 'rejected', verdict: 'reject' });

    const res = await request('PATCH', `/api/admin/ai/reviews/${book.book_id}`, {
      token, body: { decision: 'approve' }
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(bookOf(book.book_id).status, 'on_sale');
    assert.strictEqual(bookOf(book.book_id).is_approved, true);
  }]
];

module.exports = { name: '管理端書籍與 AI 審核', tests };
