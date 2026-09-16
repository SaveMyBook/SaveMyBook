const assert = require('assert');
const {
  request, addUser, addBook, addRoom, addReservation, tokenFor, notificationsOf, prisma
} = require('./harness');

// 預約在買賣雙方的聊天室中提出，因此每個情境都需要一間聊天室。
const scene = ({ status = 'on_sale', isApproved = true } = {}) => {
  const buyer = addUser({ nickname: '買家' });
  const seller = addUser({ nickname: '賣家' });
  const book = addBook({ sellerId: seller.user_id, title: '小王子', status, is_approved: isApproved });
  const room = addRoom(buyer.user_id, seller.user_id, book.book_id);
  return { buyer, seller, book, room, buyerToken: tokenFor(buyer), sellerToken: tokenFor(seller) };
};

const reserve = (token, roomId, body) =>
  request('POST', `/api/chat/rooms/${roomId}/reservations`, { token, body });

const respond = (token, reservationId, action) =>
  request('PATCH', `/api/chat/reservations/${reservationId}`, { token, body: { action } });

const tests = [
  ['保留時數僅接受 24、48、72 小時', async () => {
    const { buyerToken, room, book } = scene();
    const res = await reserve(buyerToken, room.room_id, { book_id: book.book_id, hours: 12 });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.message, '保留時間僅接受：24、48、72 小時');
  }],

  ['無法預約自己上架的書籍', async () => {
    const { sellerToken, room, book } = scene();
    const res = await reserve(sellerToken, room.room_id, { book_id: book.book_id, hours: 24 });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.message, '無法預約自己上架的書籍');
  }],

  ['僅能在與賣家的聊天室中預約', async () => {
    const { buyer, buyerToken, book } = scene();
    const someone = addUser();
    const otherRoom = addRoom(buyer.user_id, someone.user_id);

    const res = await reserve(buyerToken, otherRoom.room_id, { book_id: book.book_id, hours: 24 });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.message, '僅能於與該書賣家的聊天室中預約');
  }],

  ['已下架的書籍無法預約', async () => {
    const { buyerToken, room, book } = scene({ status: 'removed' });
    const res = await reserve(buyerToken, room.room_id, { book_id: book.book_id, hours: 24 });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.message, '此書籍目前無法預約');
  }],

  ['送出預約後為待回覆，並通知賣家與在聊天室留下卡片', async () => {
    const { seller, buyerToken, room, book } = scene();

    const res = await reserve(buyerToken, room.room_id, { book_id: book.book_id, hours: 48, message: '週五取書' });
    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.message, '已送出預約，等待賣家回覆');
    assert.strictEqual(res.body.data.status, 'pending');
    assert.strictEqual(res.body.data.hours, 48);
    assert.strictEqual(res.body.data.message, '週五取書');
    assert.strictEqual(res.body.data.pickup_deadline, null);
    assert.strictEqual(res.body.data.is_holding, false);

    const card = prisma.rows('chat_messages')[0];
    assert.strictEqual(card.room_id, room.room_id);
    assert.strictEqual(card.message_type, 'system');

    const notice = notificationsOf(seller.user_id)[0];
    assert.strictEqual(notice.type, 'reservation');
    assert.strictEqual(notice.title, '您的書籍收到預約申請');
    assert.strictEqual(notice.content, '對方申請預約《小王子》，保留 48 小時。請至聊天室回覆。');
  }],

  ['重複送出預約會被擋下', async () => {
    const { buyer, seller, buyerToken, room, book } = scene();
    addReservation({ bookId: book.book_id, buyerId: buyer.user_id, sellerId: seller.user_id, status: 'pending' });

    const res = await reserve(buyerToken, room.room_id, { book_id: book.book_id, hours: 24 });
    assert.strictEqual(res.status, 409);
    assert.strictEqual(res.body.message, '您已送出預約，正在等待賣家回覆');
  }],

  ['書籍已被其他買家保留時無法再預約', async () => {
    const { seller, buyerToken, room, book } = scene();
    const other = addUser();
    addReservation({ bookId: book.book_id, buyerId: other.user_id, sellerId: seller.user_id, status: 'confirmed' });

    const res = await reserve(buyerToken, room.room_id, { book_id: book.book_id, hours: 24 });
    assert.strictEqual(res.status, 409);
    assert.strictEqual(res.body.code, 'BOOK_RESERVED');
  }],

  ['同時進行中的預約最多 5 筆', async () => {
    const { buyer, seller, buyerToken, room, book } = scene();
    for (let i = 0; i < 5; i += 1) {
      const extra = addBook({ sellerId: seller.user_id });
      addReservation({ bookId: extra.book_id, buyerId: buyer.user_id, sellerId: seller.user_id, status: 'pending' });
    }

    const res = await reserve(buyerToken, room.room_id, { book_id: book.book_id, hours: 24 });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.message, '同時最多僅能有 5 筆進行中的預約');
  }],

  ['買家不可代替賣家接受預約', async () => {
    const { buyer, seller, buyerToken, book } = scene();
    const row = addReservation({ bookId: book.book_id, buyerId: buyer.user_id, sellerId: seller.user_id });

    const res = await respond(buyerToken, row.reservation_id, 'accept');
    assert.strictEqual(res.status, 403);
    assert.strictEqual(res.body.message, '僅賣家可回覆預約');
  }],

  ['非當事人不可操作預約', async () => {
    const { buyer, seller, book } = scene();
    const stranger = addUser();
    const row = addReservation({ bookId: book.book_id, buyerId: buyer.user_id, sellerId: seller.user_id });

    const res = await respond(tokenFor(stranger), row.reservation_id, 'cancel');
    assert.strictEqual(res.status, 403);
    assert.strictEqual(res.body.message, '此預約不屬於您');
  }],

  ['賣家接受預約後為書籍設定保留期限並通知買家', async () => {
    const { buyer, seller, sellerToken, book } = scene();
    const row = addReservation({ bookId: book.book_id, buyerId: buyer.user_id, sellerId: seller.user_id, hours: 24 });

    const res = await respond(sellerToken, row.reservation_id, 'accept');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.message, '已接受預約');
    assert.strictEqual(res.body.data.status, 'confirmed');
    assert.strictEqual(res.body.data.is_holding, true);

    const deadline = new Date(res.body.data.pickup_deadline).getTime();
    const expected = Date.now() + 24 * 60 * 60 * 1000;
    assert.ok(Math.abs(deadline - expected) < 10000, '保留期限應為 24 小時後');

    const notice = notificationsOf(buyer.user_id)[0];
    assert.strictEqual(notice.title, '賣家已接受您的預約');
    assert.ok(notice.content.startsWith('《小王子》已為您保留至 '));
    assert.ok(notice.content.endsWith('，請於期限內完成購買。'));
  }],

  ['接受預約會自動取消同一本書的其他預約並通知', async () => {
    const { buyer, seller, sellerToken, book } = scene();
    const other = addUser();
    const mine = addReservation({ bookId: book.book_id, buyerId: buyer.user_id, sellerId: seller.user_id });
    const theirs = addReservation({ bookId: book.book_id, buyerId: other.user_id, sellerId: seller.user_id });

    const res = await respond(sellerToken, mine.reservation_id, 'accept');
    assert.strictEqual(res.status, 200);

    const cancelled = prisma.rows('reservations').find((r) => r.reservation_id === theirs.reservation_id);
    assert.strictEqual(cancelled.status, 'cancelled');

    const notice = notificationsOf(other.user_id)[0];
    assert.strictEqual(notice.title, '預約未成立');
    assert.strictEqual(notice.content, '《小王子》已保留給其他買家。');
  }],

  ['書籍已下架時無法接受預約', async () => {
    const { buyer, seller, sellerToken, book } = scene({ status: 'removed' });
    const row = addReservation({ bookId: book.book_id, buyerId: buyer.user_id, sellerId: seller.user_id });

    const res = await respond(sellerToken, row.reservation_id, 'accept');
    assert.strictEqual(res.status, 409);
    assert.strictEqual(res.body.message, '此書籍已下架，無法接受預約');
  }],

  ['賣家婉拒預約：通知買家且不因沒有保留期限而失敗', async () => {
    const { buyer, seller, sellerToken, book } = scene();
    const row = addReservation({ bookId: book.book_id, buyerId: buyer.user_id, sellerId: seller.user_id });

    const res = await respond(sellerToken, row.reservation_id, 'decline');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.message, '已婉拒預約');
    assert.strictEqual(res.body.data.status, 'cancelled');
    assert.strictEqual(res.body.data.closed_by, 'seller');
    assert.strictEqual(res.body.data.closed_action, 'decline');

    const notice = notificationsOf(buyer.user_id)[0];
    assert.strictEqual(notice.title, '賣家已婉拒預約');
    assert.strictEqual(notice.content, '賣家目前無法保留《小王子》。');
  }],

  ['買家取消預約：通知賣家', async () => {
    const { buyer, seller, buyerToken, book } = scene();
    const row = addReservation({ bookId: book.book_id, buyerId: buyer.user_id, sellerId: seller.user_id });

    const res = await respond(buyerToken, row.reservation_id, 'cancel');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.message, '已取消預約');
    assert.strictEqual(res.body.data.closed_by, 'buyer');

    const notice = notificationsOf(seller.user_id)[0];
    assert.strictEqual(notice.title, '預約已取消');
    assert.strictEqual(notice.content, '《小王子》的預約已被買家取消。');
  }],

  ['賣家取消已成立的預約：通知買家', async () => {
    const { buyer, seller, sellerToken, book } = scene();
    const row = addReservation({
      bookId: book.book_id, buyerId: buyer.user_id, sellerId: seller.user_id, status: 'confirmed'
    });

    const res = await respond(sellerToken, row.reservation_id, 'cancel');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.data.status, 'cancelled');

    const notice = notificationsOf(buyer.user_id)[0];
    assert.strictEqual(notice.title, '預約已取消');
    assert.strictEqual(notice.content, '《小王子》的預約已被賣家取消。');
  }],

  ['已結束或已過期的預約無法再回覆', async () => {
    const { buyer, seller, sellerToken, book } = scene();
    const closed = addReservation({
      bookId: book.book_id, buyerId: buyer.user_id, sellerId: seller.user_id, status: 'cancelled'
    });
    const expired = addReservation({
      bookId: book.book_id,
      buyerId: buyer.user_id,
      sellerId: seller.user_id,
      status: 'confirmed',
      deadline: new Date(Date.now() - 1000)
    });

    const one = await respond(sellerToken, closed.reservation_id, 'cancel');
    assert.strictEqual(one.status, 409);
    assert.strictEqual(one.body.message, '此預約狀態已變更，請重新整理');

    const two = await respond(sellerToken, expired.reservation_id, 'cancel');
    assert.strictEqual(two.status, 409);
  }],

  ['找不到預約時回 404，動作不支援時回 400', async () => {
    const { buyer, seller, book, sellerToken } = scene();
    const row = addReservation({ bookId: book.book_id, buyerId: buyer.user_id, sellerId: seller.user_id });

    const missing = await respond(sellerToken, 9999, 'accept');
    assert.strictEqual(missing.status, 404);
    assert.strictEqual(missing.body.message, '找不到此預約');

    const bad = await request('PATCH', `/api/chat/reservations/${row.reservation_id}`, {
      token: sellerToken, body: { action: 'approve' }
    });
    assert.strictEqual(bad.status, 400);
    assert.strictEqual(bad.body.message, '操作類型不正確');
  }],

  ['保留中的書籍其他買家不可加入購物車', async () => {
    const { buyer, seller, book } = scene();
    const other = addUser();
    addReservation({
      bookId: book.book_id, buyerId: buyer.user_id, sellerId: seller.user_id, status: 'confirmed'
    });

    const res = await request('POST', '/api/cart', { token: tokenFor(other), body: { book_id: book.book_id } });
    assert.strictEqual(res.status, 409);
    assert.strictEqual(res.body.code, 'BOOK_RESERVED');
    assert.strictEqual(prisma.rows('shopping_cart').length, 0);
  }],

  ['保留期限屆滿後其他買家即可加入購物車', async () => {
    const { buyer, seller, book } = scene();
    const other = addUser();
    addReservation({
      bookId: book.book_id,
      buyerId: buyer.user_id,
      sellerId: seller.user_id,
      status: 'confirmed',
      deadline: new Date(Date.now() - 60 * 1000)
    });

    const res = await request('POST', '/api/cart', { token: tokenFor(other), body: { book_id: book.book_id } });
    assert.strictEqual(res.status, 201);
    assert.strictEqual(prisma.rows('shopping_cart').length, 1);
  }],

  ['書籍詳情會附上保留狀態', async () => {
    const { buyer, seller, book, buyerToken } = scene();
    const other = addUser();
    addReservation({
      bookId: book.book_id, buyerId: buyer.user_id, sellerId: seller.user_id, status: 'confirmed'
    });

    const mine = await request('GET', `/api/books/${book.book_id}`, { token: buyerToken });
    assert.strictEqual(mine.body.data.reservation.reserved_for_me, true);

    const theirs = await request('GET', `/api/books/${book.book_id}`, { token: tokenFor(other) });
    assert.strictEqual(theirs.body.data.reservation.reserved_for_me, false);
    assert.ok(theirs.body.data.reservation.reserved_until);
  }],

  ['過期的預約會被排程標記並通知買家', async () => {
    const { buyer, seller, book } = scene();
    const reservations = require('../../services/reservations');
    addReservation({
      bookId: book.book_id,
      buyerId: buyer.user_id,
      sellerId: seller.user_id,
      status: 'confirmed',
      deadline: new Date(Date.now() - 60 * 1000)
    });
    addReservation({
      bookId: book.book_id,
      buyerId: buyer.user_id,
      sellerId: seller.user_id,
      status: 'pending'
    });
    prisma.rows('reservations')[1].created_at = new Date(Date.now() - 25 * 60 * 60 * 1000);

    const count = await reservations.expireDue();
    assert.strictEqual(count, 2);
    assert.ok(prisma.rows('reservations').every((r) => r.status === 'expired'));

    const titles = notificationsOf(buyer.user_id).map((n) => n.title);
    assert.ok(titles.includes('預約已到期'));
    assert.ok(titles.includes('預約未獲回覆'));
    const overdue = notificationsOf(buyer.user_id).find((n) => n.title === '預約已到期');
    assert.strictEqual(overdue.content, '《小王子》的保留期限已屆滿，其他買家現已可購買。');
  }]
];

module.exports = { name: '書籍預約', tests };
