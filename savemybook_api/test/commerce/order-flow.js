const assert = require('assert');
const {
  request, api, addUser, addBook, addRoom, addReservation, addPaidOrder, tokenFor,
  bookOf, orderOf, balanceOf, notificationsOf, prisma
} = require('./harness');

const orders = api('services/orders');
const reservations = api('services/reservations');

const hoursAgo = (h) => new Date(Date.now() - h * 60 * 60 * 1000);

const scene = ({ price = 100 } = {}) => {
  const buyer = addUser({ nickname: '買家', balance: 500 });
  const seller = addUser({ nickname: '賣家', balance: 0 });
  const book = addBook({ sellerId: seller.user_id, price, title: '小王子', status: 'reserved' });
  return { buyer, seller, book, buyerToken: tokenFor(buyer), sellerToken: tokenFor(seller) };
};

const tabIds = async (token, role, tab) => {
  const res = await request('GET', `/api/orders?role=${role}&tab=${tab}`, { token });
  assert.strictEqual(res.status, 200, `${role}/${tab}：${res.text}`);
  return res.body.data.map((o) => o.order_id);
};

const tests = [
  ['分頁：取書後買家列在已完成、賣家留在已存書，完成訂單後賣家才移到已完成', async () => {
    const { buyer, seller, book, buyerToken, sellerToken } = scene();
    const order = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, status: 'deposited' });
    Object.assign(order, { deposited_at: new Date() });

    assert.deepStrictEqual(await tabIds(buyerToken, 'buyer', 'pending_pickup'), [order.order_id]);
    assert.deepStrictEqual(await tabIds(sellerToken, 'seller', 'deposited'), [order.order_id]);

    order.picked_up_at = new Date();
    assert.deepStrictEqual(await tabIds(buyerToken, 'buyer', 'pending_pickup'), []);
    assert.deepStrictEqual(await tabIds(buyerToken, 'buyer', 'completed'), [order.order_id]);
    assert.deepStrictEqual(await tabIds(sellerToken, 'seller', 'deposited'), [order.order_id]);
    assert.deepStrictEqual(await tabIds(sellerToken, 'seller', 'completed'), []);

    const done = await request('PATCH', `/api/orders/${order.order_id}/status`, { token: buyerToken, body: { status: 'completed' } });
    assert.strictEqual(done.status, 200);
    assert.deepStrictEqual(await tabIds(sellerToken, 'seller', 'completed'), [order.order_id]);
    assert.deepStrictEqual(await tabIds(sellerToken, 'seller', 'deposited'), []);
  }],

  ['排程：取書滿 24 小時且未申訴自動完成並撥款，申訴中的訂單不處理', async () => {
    const { buyer, seller, book } = scene({ price: 150 });
    const due = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, status: 'deposited', amount: 150 });
    Object.assign(due, { deposited_at: hoursAgo(30), picked_up_at: hoursAgo(25) });
    const fresh = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, status: 'deposited', amount: 150 });
    Object.assign(fresh, { deposited_at: hoursAgo(5), picked_up_at: hoursAgo(2) });
    const disputed = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, status: 'refunding', amount: 150 });
    Object.assign(disputed, { deposited_at: hoursAgo(30), picked_up_at: hoursAgo(25) });

    const result = await orders.runAutomation();
    assert.strictEqual(result.completed, 1);
    assert.strictEqual(orderOf(due.order_id).status, 'completed');
    assert.strictEqual(orderOf(fresh.order_id).status, 'deposited');
    assert.strictEqual(orderOf(disputed.order_id).status, 'refunding');
    assert.strictEqual(balanceOf(seller.user_id), 150);
    assert.ok(notificationsOf(buyer.user_id).some((n) => n.title === '訂單已自動完成'));
  }],

  ['排程：賣家逾 7 天未存書自動取消並退款，書改為下架', async () => {
    const { buyer, seller, book } = scene({ price: 120 });
    const order = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, amount: 120 });
    order.created_at = hoursAgo(7 * 24 + 1);
    const before = balanceOf(buyer.user_id);

    const result = await orders.runAutomation();
    assert.strictEqual(result.undeposited, 1);
    assert.strictEqual(orderOf(order.order_id).status, 'cancelled');
    assert.strictEqual(orderOf(order.order_id).cancel_reason, '賣家逾 7 天未存書');
    assert.strictEqual(balanceOf(buyer.user_id), before + 120);
    assert.strictEqual(bookOf(book.book_id).status, 'removed');
    assert.ok(notificationsOf(seller.user_id).some((n) => n.content.includes('已自動取消，書籍已改為下架')));
  }],

  ['排程：存書後買家逾 7 天未取書自動取消，通知賣家取回書籍', async () => {
    const { buyer, seller, book } = scene({ price: 80 });
    const order = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, status: 'deposited', amount: 80 });
    Object.assign(order, { deposited_at: hoursAgo(7 * 24 + 1) });
    const recent = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, status: 'deposited', amount: 80 });
    Object.assign(recent, { deposited_at: hoursAgo(24) });

    const result = await orders.runAutomation();
    assert.strictEqual(result.uncollected, 1);
    assert.strictEqual(orderOf(order.order_id).status, 'cancelled');
    assert.strictEqual(orderOf(recent.order_id).status, 'deposited');
    assert.ok(notificationsOf(seller.user_id).some((n) => n.content.includes('請至書櫃取回書籍')));
  }],

  ['預約保留中的書賣家不可編輯或下架', async () => {
    const buyer = addUser();
    const seller = addUser();
    const book = addBook({ sellerId: seller.user_id, title: '小王子' });
    addReservation({ bookId: book.book_id, buyerId: buyer.user_id, sellerId: seller.user_id, status: 'confirmed' });
    const token = tokenFor(seller);

    const edit = await request('PUT', `/api/books/${book.book_id}`, { token, body: { price: 90 } });
    assert.strictEqual(edit.status, 409);
    assert.strictEqual(edit.body.code, 'BOOK_HELD');
    const remove = await request('DELETE', `/api/books/${book.book_id}`, { token });
    assert.strictEqual(remove.status, 409);
    assert.strictEqual(bookOf(book.book_id).status, 'on_sale');

    const mine = await request('GET', `/api/books?seller_id=${seller.user_id}&status=all`, { token });
    assert.ok(mine.body.data.find((b) => b.book_id === book.book_id).reservation.reserved_until);
  }],

  ['預約保留到期或取消時通知收藏的人（不含預約的買家與賣家）', async () => {
    const buyer = addUser();
    const seller = addUser();
    const fan = addUser();
    const book = addBook({ sellerId: seller.user_id, title: '小王子' });
    for (const userId of [fan.user_id, buyer.user_id]) {
      prisma.rows('favorites').push({ favorite_id: prisma.nextId('favorites'), user_id: userId, book_id: book.book_id, created_at: new Date() });
    }
    addReservation({ bookId: book.book_id, buyerId: buyer.user_id, sellerId: seller.user_id, status: 'confirmed', deadline: hoursAgo(1) });

    await reservations.expireDue();
    const notice = notificationsOf(fan.user_id).find((n) => n.title === '收藏的書籍已可購買');
    assert.strictEqual(notice.content, '《小王子》的預約保留已結束，現在可以購買。');
    assert.strictEqual(notice.related_type, 'book');
    assert.ok(!notificationsOf(buyer.user_id).some((n) => n.title === '收藏的書籍已可購買'));

    const other = addBook({ sellerId: seller.user_id, title: '夜間飛行' });
    prisma.rows('favorites').push({ favorite_id: prisma.nextId('favorites'), user_id: fan.user_id, book_id: other.book_id, created_at: new Date() });
    addRoom(buyer.user_id, seller.user_id, other.book_id);
    const held = addReservation({ bookId: other.book_id, buyerId: buyer.user_id, sellerId: seller.user_id, status: 'confirmed' });
    const res = await request('PATCH', `/api/chat/reservations/${held.reservation_id}`, { token: tokenFor(buyer), body: { action: 'cancel' } });
    assert.strictEqual(res.status, 200);
    assert.ok(notificationsOf(fan.user_id).some((n) => n.content === '《夜間飛行》的預約保留已結束，現在可以購買。'));
  }],

  ['購買紀錄已預訂：列出等待回覆與保留中的預約，不含已到期或已取消', async () => {
    const buyer = addUser();
    const seller = addUser();
    const books = [0, 1, 2, 3].map((i) => addBook({ sellerId: seller.user_id, title: `書 ${i}` }));
    const pending = addReservation({ bookId: books[0].book_id, buyerId: buyer.user_id, sellerId: seller.user_id });
    const holding = addReservation({ bookId: books[1].book_id, buyerId: buyer.user_id, sellerId: seller.user_id, status: 'confirmed' });
    addReservation({ bookId: books[2].book_id, buyerId: buyer.user_id, sellerId: seller.user_id, status: 'confirmed', deadline: hoursAgo(1) });
    addReservation({ bookId: books[3].book_id, buyerId: buyer.user_id, sellerId: seller.user_id, status: 'cancelled' });

    const res = await request('GET', '/api/chat/reservations/mine', { token: tokenFor(buyer) });
    assert.strictEqual(res.status, 200);
    const ids = res.body.data.map((r) => r.reservation_id).sort();
    assert.deepStrictEqual(ids, [pending.reservation_id, holding.reservation_id].sort());
    assert.strictEqual(res.body.data.find((r) => r.reservation_id === holding.reservation_id).is_holding, true);
  }]
];

module.exports = { name: '訂單流程與預約保留', tests };
