const assert = require('assert');
const {
  request, addUser, addAdmin, addBook, addCartItem, addOrder, addPaidOrder, addReservation,
  tokenFor, balanceOf, notificationsOf, transactionsOf, logs, prisma
} = require('./harness');

const shopper = () => {
  const buyer = addUser({ nickname: '買家' });
  const seller = addUser({ nickname: '賣家' });
  const book = addBook({ sellerId: seller.user_id, title: '小王子', price: 150 });
  return { buyer, seller, book, token: tokenFor(buyer) };
};

const tests = [
  // ---------- 購物車 ----------
  ['加入購物車需提供書籍編號且書籍必須存在', async () => {
    const { token } = shopper();

    const missing = await request('POST', '/api/cart', { token, body: {} });
    assert.strictEqual(missing.status, 400);
    assert.strictEqual(missing.body.message, '請指定書籍');

    const notFound = await request('POST', '/api/cart', { token, body: { book_id: 9999 } });
    assert.strictEqual(notFound.status, 404);
    assert.strictEqual(notFound.body.message, '找不到該書籍');
  }],

  ['不可將自己的書或無法販售的書加入購物車', async () => {
    const { seller, book } = shopper();
    const removed = addBook({ sellerId: seller.user_id, status: 'removed' });
    const unapproved = addBook({ sellerId: seller.user_id, is_approved: false });
    const other = addUser();

    const own = await request('POST', '/api/cart', { token: tokenFor(seller), body: { book_id: book.book_id } });
    assert.strictEqual(own.status, 400);
    assert.strictEqual(own.body.message, '無法將自己上架的書籍加入購物車');

    for (const target of [removed, unapproved]) {
      const res = await request('POST', '/api/cart', { token: tokenFor(other), body: { book_id: target.book_id } });
      assert.strictEqual(res.status, 400);
      assert.strictEqual(res.body.message, '此書籍目前無法購買');
    }
  }],

  ['加入購物車成功，重複加入不會累加數量', async () => {
    const { book, token } = shopper();

    const first = await request('POST', '/api/cart', { token, body: { book_id: book.book_id } });
    assert.strictEqual(first.status, 201);
    assert.strictEqual(first.body.message, '已加入購物車');
    assert.strictEqual(first.body.already_in_cart, false);

    const second = await request('POST', '/api/cart', { token, body: { book_id: book.book_id, quantity: 3 } });
    assert.strictEqual(second.status, 200);
    assert.strictEqual(second.body.already_in_cart, true);
    assert.strictEqual(second.body.message, '此書籍已在購物車中');
    assert.strictEqual(prisma.rows('shopping_cart').length, 1);
    assert.strictEqual(prisma.rows('shopping_cart')[0].quantity, 1);
  }],

  ['購物車最多 100 項商品', async () => {
    const { buyer, seller, token } = shopper();
    for (let i = 0; i < 100; i += 1) {
      const extra = addBook({ sellerId: seller.user_id });
      addCartItem(buyer.user_id, extra.book_id);
    }
    const target = addBook({ sellerId: seller.user_id });

    const res = await request('POST', '/api/cart', { token, body: { book_id: target.book_id } });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.message, '購物車最多可放入 100 項商品');
  }],

  ['購物車列出金額合計與保留狀態', async () => {
    const { buyer, seller, book, token } = shopper();
    addCartItem(buyer.user_id, book.book_id);
    addReservation({ bookId: book.book_id, buyerId: buyer.user_id, sellerId: seller.user_id, status: 'confirmed' });

    const res = await request('GET', '/api/cart', { token });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.total_amount, 150);
    assert.strictEqual(res.body.data.length, 1);
    assert.strictEqual(res.body.data[0].books.title, '小王子');
    assert.strictEqual(res.body.data[0].books.reservation.reserved_for_me, true);

    const ids = await request('GET', '/api/cart/book-ids', { token });
    assert.deepStrictEqual(ids.body.data, [book.book_id]);
  }],

  ['調整購物車數量的限制', async () => {
    const { buyer, book, token } = shopper();
    const other = addUser();
    const item = addCartItem(buyer.user_id, book.book_id);

    const zero = await request('PATCH', `/api/cart/${item.cart_id}`, { token, body: { quantity: 0 } });
    assert.strictEqual(zero.status, 400);
    assert.strictEqual(zero.body.message, 'quantity 必須大於 0');

    const tooMany = await request('PATCH', `/api/cart/${item.cart_id}`, { token, body: { quantity: 2 } });
    assert.strictEqual(tooMany.status, 400);
    assert.strictEqual(tooMany.body.message, '此書籍數量僅 1 本');

    const denied = await request('PATCH', `/api/cart/${item.cart_id}`, {
      token: tokenFor(other), body: { quantity: 1 }
    });
    assert.strictEqual(denied.status, 403);
    assert.strictEqual(denied.body.message, '存取被拒');

    const ok = await request('PATCH', `/api/cart/${item.cart_id}`, { token, body: { quantity: 1 } });
    assert.strictEqual(ok.status, 200);
    assert.strictEqual(ok.body.message, '已更新數量');
  }],

  ['移除購物車項目', async () => {
    const { buyer, book, token } = shopper();
    const item = addCartItem(buyer.user_id, book.book_id);

    const missing = await request('DELETE', '/api/cart/9999', { token });
    assert.strictEqual(missing.status, 404);
    assert.strictEqual(missing.body.message, '找不到該購物車項目');

    const res = await request('DELETE', `/api/cart/${item.cart_id}`, { token });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.message, '已從購物車移除');
    assert.strictEqual(prisma.rows('shopping_cart').length, 0);
  }],

  // ---------- 收藏 ----------
  ['收藏書籍：不存在回 404，重複收藏不會產生第二筆', async () => {
    const { book, token } = shopper();

    const missing = await request('POST', '/api/favorites', { token, body: { book_id: 9999 } });
    assert.strictEqual(missing.status, 404);
    assert.strictEqual(missing.body.message, '找不到該書籍');

    const first = await request('POST', '/api/favorites', { token, body: { book_id: book.book_id } });
    assert.strictEqual(first.status, 201);
    assert.strictEqual(first.body.message, '已加入收藏');

    const again = await request('POST', '/api/favorites', { token, body: { book_id: book.book_id } });
    assert.strictEqual(again.status, 201);
    assert.strictEqual(prisma.rows('favorites').length, 1);
  }],

  ['收藏列表不顯示未審核的書籍，編號清單則完整', async () => {
    const { buyer, seller, book, token } = shopper();
    const hidden = addBook({ sellerId: seller.user_id, is_approved: false });
    prisma.rows('favorites').push(
      { favorite_id: 1, user_id: buyer.user_id, book_id: book.book_id, created_at: new Date() },
      { favorite_id: 2, user_id: buyer.user_id, book_id: hidden.book_id, created_at: new Date() }
    );

    const list = await request('GET', '/api/favorites', { token });
    assert.strictEqual(list.status, 200);
    assert.strictEqual(list.body.data.length, 1);
    assert.strictEqual(list.body.data[0].book_id, book.book_id);

    const ids = await request('GET', '/api/favorites/ids', { token });
    assert.deepStrictEqual(ids.body.data, [book.book_id, hidden.book_id]);

    const removed = await request('DELETE', `/api/favorites/${book.book_id}`, { token });
    assert.strictEqual(removed.status, 200);
    assert.strictEqual(removed.body.message, '已取消收藏');
    assert.strictEqual(prisma.rows('favorites').length, 1);
  }],

  // ---------- 錢包 ----------
  ['查詢錢包時自動建立帳戶並統計待入帳金額', async () => {
    const { buyer, seller, book } = shopper();
    const sellerToken = tokenFor(seller);
    addOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, amount: 150 });
    addOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, amount: 90, status: 'deposited' });
    addOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, amount: 70, status: 'completed' });

    const res = await request('GET', '/api/wallet', { token: sellerToken });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(Number(res.body.data.balance), 0);
    // 已完成的訂單不算待入帳。
    assert.strictEqual(Number(res.body.data.pending_income), 240);
    assert.strictEqual(prisma.rows('wallets').length, 1);

    const pending = await request('GET', '/api/wallet/pending', { token: sellerToken });
    assert.strictEqual(pending.body.data.length, 2);
    assert.strictEqual(pending.body.total_amount, 240);
  }],

  ['帳務紀錄分頁並以加密編號呈現', async () => {
    const { buyer, seller, book, token } = shopper();
    for (let i = 0; i < 3; i += 1) {
      addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, amount: 10 });
    }

    const res = await request('GET', '/api/wallet/transactions?limit=2', { token });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.data.length, 2);
    assert.strictEqual(res.body.pagination.total, 3);
    assert.strictEqual(res.body.pagination.total_pages, 2);
    for (const row of res.body.data) {
      assert.match(row.txn_no, /^TX[0-9A-Z]{7}$/);
      assert.strictEqual(row.type, 'purchase');
    }

    const page2 = await request('GET', '/api/wallet/transactions?limit=2&page=2', { token });
    assert.strictEqual(page2.body.data.length, 1);
  }],

  ['錢包相關端點都需要登入', async () => {
    for (const path of ['/api/wallet', '/api/wallet/transactions', '/api/wallet/pending', '/api/cart', '/api/favorites']) {
      const res = await request('GET', path);
      assert.strictEqual(res.status, 401, `${path} 應要求登入`);
    }
  }],

  ['客服調整餘額的金額驗證', async () => {
    const buyer = addUser({ balance: 100 });
    const token = tokenFor(addAdmin());
    const url = `/api/admin/wallets/${buyer.user_id}/adjust`;

    const zero = await request('POST', url, { token, body: { amount: 0, description: '測試' } });
    assert.strictEqual(zero.status, 400);
    assert.strictEqual(zero.body.message, '請輸入非零的調整金額');

    const tooMuch = await request('POST', url, { token, body: { amount: 1000001, description: '測試' } });
    assert.strictEqual(tooMuch.status, 400);
    assert.strictEqual(tooMuch.body.message, '單次調整不可超過 1,000,000');

    const fraction = await request('POST', url, { token, body: { amount: 1.234, description: '測試' } });
    assert.strictEqual(fraction.status, 400);
    assert.strictEqual(fraction.body.message, '金額最多可至小數點後兩位');

    const noReason = await request('POST', url, { token, body: { amount: 10, description: '  ' } });
    assert.strictEqual(noReason.status, 400);
    assert.strictEqual(noReason.body.message, '請填寫調整原因，此原因將記錄於帳務紀錄');
  }],

  ['客服加值會寫入帳務紀錄、通知會員並可還原', async () => {
    const buyer = addUser({ nickname: '買家', balance: 100 });
    const admin = addAdmin();

    const res = await request('POST', `/api/admin/wallets/${buyer.user_id}/adjust`, {
      token: tokenFor(admin), body: { amount: 50, description: '活動獎勵' }
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.message, '已調整餘額');
    assert.strictEqual(Number(res.body.data.balance), 150);
    assert.strictEqual(balanceOf(buyer.user_id), 150);

    const txn = transactionsOf(buyer.user_id)[0];
    assert.strictEqual(txn.type, 'admin_adjust');
    assert.strictEqual(txn.description, '管理員調整：活動獎勵');
    assert.strictEqual(Number(txn.balance_after), 150);

    const notice = notificationsOf(buyer.user_id)[0];
    assert.strictEqual(notice.title, '代幣已入帳');
    assert.strictEqual(notice.content, '客服已調整您的代幣 +50，餘額 150。原因：活動獎勵');

    const log = logs()[0];
    assert.strictEqual(log.action, '調整會員錢包');
    const detail = JSON.parse(log.detail);
    assert.strictEqual(detail.summary, '替 買家 的錢包加入 50 代幣，原因：活動獎勵');
    assert.deepStrictEqual(detail.undo, [{ op: 'wallet', userId: buyer.user_id, amount: 50 }]);
  }],

  ['扣款不可讓餘額變成負數', async () => {
    const buyer = addUser({ balance: 30 });
    const admin = addAdmin();

    const res = await request('POST', `/api/admin/wallets/${buyer.user_id}/adjust`, {
      token: tokenFor(admin), body: { amount: -100, description: '誤入帳回收' }
    });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.code, 'INSUFFICIENT_BALANCE');
    assert.strictEqual(res.body.message, '調整後餘額將為負數，請確認金額');
    assert.strictEqual(balanceOf(buyer.user_id), 30);
    assert.strictEqual(transactionsOf(buyer.user_id).length, 0);
  }],

  ['管理端錢包列表與明細', async () => {
    const buyer = addUser({ nickname: '買家', balance: 80 });
    const admin = addAdmin();
    const token = tokenFor(admin);

    const list = await request('GET', '/api/admin/wallets?keyword=買家', { token });
    assert.strictEqual(list.status, 200);
    assert.strictEqual(list.body.data.length, 1);
    assert.strictEqual(Number(list.body.data[0].balance), 80);

    const detail = await request('GET', `/api/admin/wallets/${buyer.user_id}`, { token });
    assert.strictEqual(detail.status, 200);
    assert.strictEqual(Number(detail.body.data.balance), 80);
    assert.deepStrictEqual(detail.body.data.transactions, []);

    const missing = await request('GET', '/api/admin/wallets/9999', { token });
    assert.strictEqual(missing.status, 404);
    assert.strictEqual(missing.body.message, '找不到此會員');
  }]
];

module.exports = { name: '購物車、收藏與錢包', tests };
