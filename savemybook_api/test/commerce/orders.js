const assert = require('assert');
const {
  request, addUser, addAdmin, addBook, addCabinet, addCartItem, addOrder, addPaidOrder, addReservation,
  tokenFor, bookOf, orderOf, balanceOf, transactionsOf, notificationsOf, logs, prisma
} = require('./harness');

// 買家、賣家與一本上架中的書：多數訂單測試的共同起點。
const scene = ({ balance = 500, price = 100, cabinet = null } = {}) => {
  const buyer = addUser({ nickname: '買家', balance });
  const seller = addUser({ nickname: '賣家', balance: 0 });
  const book = addBook({ sellerId: seller.user_id, price, title: '小王子', cabinet_id: cabinet });
  return { buyer, seller, book, buyerToken: tokenFor(buyer), sellerToken: tokenFor(seller) };
};

const checkout = (token, body = {}) => request('POST', '/api/orders/checkout', { token, body });
const setStatus = (token, orderId, status) =>
  request('PATCH', `/api/orders/${orderId}/status`, { token, body: { status } });

const tests = [
  ['購物車沒有項目時無法結帳', async () => {
    const { buyerToken } = scene();
    const res = await checkout(buyerToken);
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.message, '購物車沒有可結帳的項目');
  }],

  ['無法購買自己上架的書籍', async () => {
    const { seller, sellerToken, book } = scene();
    addCartItem(seller.user_id, book.book_id);

    const res = await checkout(sellerToken);
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.message, '《小王子》為您上架的書籍，無法購買');
  }],

  ['已下架的書籍無法結帳', async () => {
    const { buyer, buyerToken, book } = scene();
    prisma.rows('books')[0].status = 'removed';
    addCartItem(buyer.user_id, book.book_id);

    const res = await checkout(buyerToken);
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.message, '《小王子》已無法購買，請先移除');
  }],

  ['存放書櫃維修中的書籍無法結帳，也不會扣款', async () => {
    const cabinet = addCabinet({ isMaintenance: true });
    const { buyer, buyerToken, book } = scene({ cabinet: cabinet.cabinet_id });
    addCartItem(buyer.user_id, book.book_id);

    const res = await checkout(buyerToken);
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.code, 'CABINET_MAINTENANCE');
    assert.strictEqual(res.body.message, '《小王子》存放的書櫃維修中，暫時無法購買，請先移除或稍後再試');
    assert.strictEqual(bookOf(book.book_id).status, 'on_sale');
    assert.strictEqual(balanceOf(buyer.user_id), 500);
  }],

  ['代幣不足時回 INSUFFICIENT_BALANCE 並附上金額', async () => {
    const { buyer, buyerToken, book } = scene({ balance: 50, price: 100 });
    addCartItem(buyer.user_id, book.book_id);

    const res = await checkout(buyerToken);
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.code, 'INSUFFICIENT_BALANCE');
    assert.strictEqual(res.body.message, '代幣不足，此訂單需 100 代幣，目前餘額 50');
    assert.strictEqual(prisma.rows('orders').length, 0);
    assert.strictEqual(bookOf(book.book_id).status, 'on_sale');
  }],

  ['被其他買家保留的書籍無法結帳', async () => {
    const { buyer, buyerToken, seller, book } = scene();
    const other = addUser();
    addReservation({ bookId: book.book_id, buyerId: other.user_id, sellerId: seller.user_id, status: 'confirmed' });
    addCartItem(buyer.user_id, book.book_id);

    const res = await checkout(buyerToken);
    assert.strictEqual(res.status, 409);
    assert.strictEqual(res.body.code, 'BOOK_RESERVED');
    assert.ok(res.body.message.startsWith('《小王子》已由其他買家預約，保留至 '));
  }],

  ['保留給自己的書籍可以結帳', async () => {
    const { buyer, buyerToken, seller, book } = scene();
    addReservation({ bookId: book.book_id, buyerId: buyer.user_id, sellerId: seller.user_id, status: 'confirmed' });
    addCartItem(buyer.user_id, book.book_id);

    const res = await checkout(buyerToken);
    assert.strictEqual(res.status, 201);
  }],

  ['結帳成功：扣款、鎖定書籍、清空購物車並通知賣家', async () => {
    const { buyer, buyerToken, seller, book } = scene({ balance: 500, price: 120 });
    addCartItem(buyer.user_id, book.book_id);

    const res = await checkout(buyerToken);
    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.message, '結帳成功');
    assert.strictEqual(res.body.data.length, 1);

    const order = res.body.data[0];
    assert.strictEqual(order.status, 'pending_deposit');
    assert.strictEqual(order.buyer_id, buyer.user_id);
    assert.strictEqual(order.seller_id, seller.user_id);
    assert.strictEqual(Number(order.total_amount), 120);
    assert.strictEqual(order.order_items.length, 1);
    assert.strictEqual(Number(order.order_items[0].subtotal), 120);

    assert.strictEqual(balanceOf(buyer.user_id), 380);
    assert.strictEqual(bookOf(book.book_id).status, 'reserved');
    assert.strictEqual(prisma.rows('shopping_cart').length, 0);

    const txn = transactionsOf(buyer.user_id)[0];
    assert.strictEqual(txn.type, 'purchase');
    assert.strictEqual(Number(txn.amount), -120);
    assert.strictEqual(Number(txn.balance_after), 380);
    assert.strictEqual(txn.related_order_id, order.order_id);
    assert.strictEqual(Number(walletCounter(buyer.user_id, 'total_expense')), 120);

    const notice = notificationsOf(seller.user_id)[0];
    assert.strictEqual(notice.title, '您的書已售出');
    assert.strictEqual(notice.content, `訂單 ${order.order_no} 已成立，請於七天內至書櫃存書。`);
  }],

  ['不同賣家的書籍會拆成多張訂單', async () => {
    const buyer = addUser({ balance: 1000 });
    const sellerA = addUser();
    const sellerB = addUser();
    const bookA = addBook({ sellerId: sellerA.user_id, price: 100 });
    const bookB = addBook({ sellerId: sellerB.user_id, price: 200 });
    addCartItem(buyer.user_id, bookA.book_id);
    addCartItem(buyer.user_id, bookB.book_id);

    const res = await checkout(tokenFor(buyer));
    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.data.length, 2);
    assert.strictEqual(balanceOf(buyer.user_id), 700);
    assert.strictEqual(transactionsOf(buyer.user_id).length, 2);
  }],

  ['只結帳指定的購物車項目', async () => {
    const buyer = addUser({ balance: 1000 });
    const seller = addUser();
    const bookA = addBook({ sellerId: seller.user_id, price: 100 });
    const bookB = addBook({ sellerId: seller.user_id, price: 200 });
    const cartA = addCartItem(buyer.user_id, bookA.book_id);
    addCartItem(buyer.user_id, bookB.book_id);

    const res = await checkout(tokenFor(buyer), { cart_ids: [cartA.cart_id] });
    assert.strictEqual(res.status, 201);
    assert.strictEqual(Number(res.body.data[0].total_amount), 100);
    assert.strictEqual(prisma.rows('shopping_cart').length, 1);
    assert.strictEqual(bookOf(bookB.book_id).status, 'on_sale');
  }],

  ['訂單列表可依身分與分頁籤過濾', async () => {
    const { buyer, seller, book, buyerToken, sellerToken } = scene();
    addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id });
    addOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, status: 'completed' });

    const buying = await request('GET', '/api/orders?tab=pending_pickup', { token: buyerToken });
    assert.strictEqual(buying.status, 200);
    assert.strictEqual(buying.body.data.length, 1);
    assert.strictEqual(buying.body.data[0].status, 'pending_deposit');

    const selling = await request('GET', '/api/orders?role=seller&tab=completed', { token: sellerToken });
    assert.strictEqual(selling.body.data.length, 1);
    assert.strictEqual(selling.body.data[0].status, 'completed');
    assert.strictEqual(selling.body.pagination.total, 1);

    const bad = await request('GET', '/api/orders?tab=unknown', { token: buyerToken });
    assert.strictEqual(bad.status, 400);
    assert.strictEqual(bad.body.message, '不支援的 tab：unknown');
  }],

  ['訂單詳情僅限買賣雙方與管理員', async () => {
    const { buyer, seller, book, buyerToken } = scene();
    const stranger = addUser();
    const admin = addAdmin();
    const order = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id });

    const mine = await request('GET', `/api/orders/${order.order_id}`, { token: buyerToken });
    assert.strictEqual(mine.status, 200);
    assert.strictEqual(mine.body.data.order_id, order.order_id);

    const denied = await request('GET', `/api/orders/${order.order_id}`, { token: tokenFor(stranger) });
    assert.strictEqual(denied.status, 403);
    assert.strictEqual(denied.body.message, '存取被拒');

    const byAdmin = await request('GET', `/api/orders/${order.order_id}`, { token: tokenFor(admin) });
    assert.strictEqual(byAdmin.status, 200);

    const missing = await request('GET', '/api/orders/9999', { token: buyerToken });
    assert.strictEqual(missing.status, 404);
    assert.strictEqual(missing.body.message, '找不到該訂單');
  }],

  ['只有賣家可以標記存書，並通知買家至書櫃掃描 QR Code 取書', async () => {
    const cabinet = addCabinet({ name: '中正書櫃' });
    const { buyer, seller, book, buyerToken, sellerToken } = scene({ cabinet: cabinet.cabinet_id });
    const order = addPaidOrder({
      buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, cabinetId: cabinet.cabinet_id
    });

    const denied = await setStatus(buyerToken, order.order_id, 'deposited');
    assert.strictEqual(denied.status, 403);
    assert.strictEqual(denied.body.message, '僅賣家可執行此操作');

    const res = await setStatus(sellerToken, order.order_id, 'deposited');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.data.status, 'deposited');
    assert.ok(orderOf(order.order_id).deposited_at instanceof Date);

    const notice = notificationsOf(buyer.user_id)[0];
    assert.strictEqual(notice.title, '書籍已存入書櫃');
    assert.strictEqual(
      notice.content,
      `訂單 ${order.order_no} 的書籍已存入「中正書櫃」書櫃，請前往書櫃掃描機台上的 QR Code 取書。`
    );

    const again = await setStatus(sellerToken, order.order_id, 'deposited');
    assert.strictEqual(again.status, 409);
    assert.strictEqual(again.body.message, '訂單已是此狀態');
  }],

  ['賣家尚未存書時不可改為待取書', async () => {
    const { buyer, seller, book, sellerToken } = scene();
    const order = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id });

    const res = await setStatus(sellerToken, order.order_id, 'pending_pickup');
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.message, '賣家尚未存書，無法改為待取書');
  }],

  ['買家取書後不撥款，完成訂單才撥款給賣家並將書標為已售出', async () => {
    const { buyer, seller, book, buyerToken, sellerToken } = scene({ price: 150 });
    prisma.rows('books')[0].status = 'reserved';
    const order = addPaidOrder({
      buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, amount: 150
    });

    await setStatus(sellerToken, order.order_id, 'deposited');
    const denied = await setStatus(sellerToken, order.order_id, 'picked_up');
    assert.strictEqual(denied.status, 403);
    assert.strictEqual(denied.body.message, '僅買家可確認取書或完成訂單');

    const picked = await setStatus(buyerToken, order.order_id, 'picked_up');
    assert.strictEqual(picked.status, 200);
    assert.strictEqual(picked.body.data.status, 'deposited');
    assert.ok(orderOf(order.order_id).picked_up_at instanceof Date);
    assert.strictEqual(balanceOf(seller.user_id), 0, '取書時不撥款');
    assert.strictEqual(bookOf(book.book_id).status, 'reserved');
    const pickedNotice = notificationsOf(seller.user_id).find((n) => n.title === '買家已取書');
    assert.strictEqual(pickedNotice.content, `訂單 ${order.order_no} 的書籍已由買家取走，買家完成訂單或取書滿 24 小時後，款項將撥入您的錢包。`);
    assert.strictEqual((await setStatus(buyerToken, order.order_id, 'picked_up')).status, 409);

    const res = await setStatus(buyerToken, order.order_id, 'completed');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.data.status, 'completed');
    assert.strictEqual(balanceOf(seller.user_id), 150);
    assert.strictEqual(bookOf(book.book_id).status, 'sold');
    assert.ok(orderOf(order.order_id).completed_at instanceof Date);

    const income = transactionsOf(seller.user_id).find((t) => t.type === 'sale_income');
    assert.strictEqual(Number(income.amount), 150);
    assert.strictEqual(income.description, '賣出');
    assert.strictEqual(Number(walletCounter(seller.user_id, 'total_income')), 150);

    const notice = notificationsOf(seller.user_id).find((n) => n.title === '訂單已完成');
    assert.strictEqual(notice.content, `訂單 ${order.order_no} 已完成，150 代幣已撥入您的錢包。`);
  }],

  ['舊版 App 在取書時送出 completed，只記錄取書、不撥款', async () => {
    const { buyer, seller, book, buyerToken, sellerToken } = scene({ price: 150 });
    prisma.rows('books')[0].status = 'reserved';
    const order = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, amount: 150 });
    await setStatus(sellerToken, order.order_id, 'deposited');

    const res = await setStatus(buyerToken, order.order_id, 'completed');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.data.status, 'deposited');
    assert.ok(orderOf(order.order_id).picked_up_at instanceof Date);
    assert.strictEqual(balanceOf(seller.user_id), 0);
  }],

  ['賣家存書後買賣雙方都不能自行取消', async () => {
    const { buyer, seller, book, buyerToken, sellerToken } = scene();
    prisma.rows('books')[0].status = 'reserved';
    const order = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id });
    await setStatus(sellerToken, order.order_id, 'deposited');

    for (const token of [buyerToken, sellerToken]) {
      const res = await request('PATCH', `/api/orders/${order.order_id}/cancel`, { token, body: {} });
      assert.strictEqual(res.status, 400);
      assert.strictEqual(res.body.code, 'ORDER_NOT_CANCELLABLE');
    }
    assert.strictEqual(orderOf(order.order_id).status, 'deposited');
  }],

  ['取消訂單會退款買家、釋放書籍並通知雙方', async () => {
    const { buyer, seller, book, buyerToken } = scene();
    prisma.rows('books')[0].status = 'reserved';
    const order = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id });
    const before = balanceOf(buyer.user_id);

    const res = await request('PATCH', `/api/orders/${order.order_id}/cancel`, {
      token: buyerToken, body: { reason: '不想買了' }
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.message, '訂單已取消');
    assert.strictEqual(res.body.data.status, 'cancelled');
    assert.strictEqual(orderOf(order.order_id).cancel_reason, '不想買了');
    assert.strictEqual(balanceOf(buyer.user_id), before + 100);
    assert.strictEqual(bookOf(book.book_id).status, 'on_sale');

    const refund = transactionsOf(buyer.user_id).find((t) => t.type === 'refund');
    assert.strictEqual(Number(refund.amount), 100);

    const buyerNotice = notificationsOf(buyer.user_id).find((n) => n.title === '訂單已退款');
    assert.strictEqual(buyerNotice.content, `訂單 ${order.order_no} 已取消，100 代幣已退回您的帳戶。`);
    const sellerNotice = notificationsOf(seller.user_id).find((n) => n.title === '訂單已取消');
    assert.strictEqual(sellerNotice.content, `訂單 ${order.order_no} 已取消。原因：不想買了`);
  }],

  ['已完成的訂單無法取消，爭議中的訂單當事人也不能自行取消', async () => {
    const { buyer, seller, book, buyerToken } = scene();
    const done = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, status: 'completed' });
    const disputing = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, status: 'refunding' });

    const one = await request('PATCH', `/api/orders/${done.order_id}/cancel`, { token: buyerToken, body: {} });
    assert.strictEqual(one.status, 400);
    assert.strictEqual(one.body.message, '此訂單狀態無法取消');

    const two = await request('PATCH', `/api/orders/${disputing.order_id}/cancel`, { token: buyerToken, body: {} });
    assert.strictEqual(two.status, 400);
    assert.strictEqual(two.body.message, '此訂單爭議處理中，無法自行取消，請等候客服裁決');
  }],

  ['客服將已完成的訂單改為已退款時，向賣家收回並退還買家', async () => {
    const { buyer, seller, book, buyerToken, sellerToken } = scene({ price: 200 });
    prisma.rows('books')[0].status = 'reserved';
    const admin = addAdmin();
    const order = addPaidOrder({
      buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, amount: 200
    });
    await setStatus(sellerToken, order.order_id, 'deposited');
    await setStatus(buyerToken, order.order_id, 'picked_up');
    await setStatus(buyerToken, order.order_id, 'completed');
    assert.strictEqual(balanceOf(seller.user_id), 200);

    const res = await request('PATCH', `/api/admin/orders/${order.order_id}`, {
      token: tokenFor(admin), body: { status: 'refunded', note: '書況不符' }
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.message, '訂單狀態已更新，向賣家收回 200 代幣，退還買家 200 代幣');
    assert.strictEqual(res.body.data.clawed_back, 200);
    assert.strictEqual(res.body.data.refunded, 200);
    assert.strictEqual(balanceOf(seller.user_id), 0);
    assert.strictEqual(balanceOf(buyer.user_id), 500);

    const log = logs()[0];
    assert.strictEqual(log.action, '調整訂單狀態');
    assert.strictEqual(log.target_type, 'order');
    assert.ok(JSON.parse(log.detail).summary.includes('從「已完成」改為「已退款」'));

    for (const userId of [buyer.user_id, seller.user_id]) {
      const notice = notificationsOf(userId).find((n) => n.title === '訂單狀態已更新');
      assert.ok(notice.content.includes('說明：書況不符'), '雙方都應收到含說明的通知');
    }
  }],

  ['重複結算不會重複撥款或重複退款', async () => {
    const { buyer, seller, book, buyerToken, sellerToken } = scene({ price: 200 });
    const admin = addAdmin();
    const order = addPaidOrder({
      buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, amount: 200
    });
    await setStatus(sellerToken, order.order_id, 'deposited');
    await setStatus(buyerToken, order.order_id, 'picked_up');
    await setStatus(buyerToken, order.order_id, 'completed');

    // 已撥款後再改回進行中，不應再撥一次款。
    const back = await request('PATCH', `/api/admin/orders/${order.order_id}`, {
      token: tokenFor(admin), body: { status: 'refunding' }
    });
    assert.strictEqual(back.status, 200);
    const again = await request('PATCH', `/api/admin/orders/${order.order_id}`, {
      token: tokenFor(admin), body: { status: 'completed' }
    });
    assert.strictEqual(again.status, 200);
    assert.strictEqual(again.body.data.paid_out, 0);
    assert.strictEqual(balanceOf(seller.user_id), 200);
    assert.strictEqual(transactionsOf(seller.user_id).filter((t) => t.type === 'sale_income').length, 1);
  }],

  ['客服調整訂單狀態的限制', async () => {
    const { buyer, seller, book } = scene();
    const admin = addAdmin();
    const done = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, status: 'completed' });
    const cancelled = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, status: 'cancelled' });
    const token = tokenFor(admin);

    const same = await request('PATCH', `/api/admin/orders/${done.order_id}`, { token, body: { status: 'completed' } });
    assert.strictEqual(same.status, 400);
    assert.strictEqual(same.body.message, '訂單已是此狀態');

    const forward = await request('PATCH', `/api/admin/orders/${done.order_id}`, { token, body: { status: 'deposited' } });
    assert.strictEqual(forward.status, 400);
    assert.strictEqual(forward.body.message, '已完成的訂單只能改為「退款處理中」或「已退款」');

    const restore = await request('PATCH', `/api/admin/orders/${cancelled.order_id}`, { token, body: { status: 'deposited' } });
    assert.strictEqual(restore.status, 400);
    assert.strictEqual(restore.body.message, '此訂單款項已退回買家，無法改回進行中或已完成');
  }],

  ['一般會員不可使用管理端訂單功能', async () => {
    const { buyer, seller, book, buyerToken } = scene();
    const order = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id });

    const list = await request('GET', '/api/admin/orders', { token: buyerToken });
    assert.strictEqual(list.status, 403);
    assert.strictEqual(list.body.message, '權限不足，僅限管理員執行此操作');

    const patch = await request('PATCH', `/api/admin/orders/${order.order_id}`, {
      token: buyerToken, body: { status: 'cancelled' }
    });
    assert.strictEqual(patch.status, 403);
  }],

  ['管理端訂單列表可依狀態與關鍵字查詢', async () => {
    const { buyer, seller, book } = scene();
    const admin = addAdmin();
    const open = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id });
    addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, status: 'completed' });
    const token = tokenFor(admin);

    const all = await request('GET', '/api/admin/orders', { token });
    assert.strictEqual(all.status, 200);
    assert.strictEqual(all.body.data.length, 2);

    const filtered = await request('GET', '/api/admin/orders?status=completed', { token });
    assert.strictEqual(filtered.body.data.length, 1);
    assert.strictEqual(filtered.body.data[0].status, 'completed');

    const byNickname = await request('GET', '/api/admin/orders?keyword=買家', { token });
    assert.strictEqual(byNickname.body.data.length, 2);

    const detail = await request('GET', `/api/admin/orders/${open.order_id}`, { token });
    assert.strictEqual(detail.status, 200);
    assert.strictEqual(detail.body.data.order_no, open.order_no);
    assert.strictEqual(detail.body.data.wallet_transactions.length, 1);
    // 帳務紀錄對外只給加密編號。
    assert.match(detail.body.data.wallet_transactions[0].txn_no, /^TX[0-9A-Z]{7}$/);
  }],

  ['狀態不在允許清單時回 400', async () => {
    const { buyer, seller, book, sellerToken } = scene();
    const order = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id });

    const res = await setStatus(sellerToken, order.order_id, 'refunded');
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.message, '訂單狀態不正確');
  }],

  ['訂單不再產生或回傳取書碼', async () => {
    const { buyer, buyerToken, book } = scene();
    addCartItem(buyer.user_id, book.book_id);

    const res = await checkout(buyerToken);
    assert.strictEqual(res.status, 201);
    assert.ok(!('pickup_code' in res.body.data[0]), '結帳回應不應包含取書碼');
    assert.strictEqual(orderOf(res.body.data[0].order_id).pickup_code ?? null, null, '資料庫不應寫入取書碼');

    const detail = await request('GET', `/api/orders/${res.body.data[0].order_id}`, { token: buyerToken });
    assert.ok(!('pickup_code' in detail.body.data), '訂單明細不應包含取書碼');
  }],

  ['指定 bank_transfer 仍以代幣結帳並記為 wallet', async () => {
    const { buyer, buyerToken, book } = scene({ balance: 500, price: 100 });
    addCartItem(buyer.user_id, book.book_id);

    const res = await checkout(buyerToken, { payment_method: 'bank_transfer' });
    assert.strictEqual(res.status, 201);
    assert.strictEqual(orderOf(res.body.data[0].order_id).payment_method, 'wallet');
    assert.strictEqual(balanceOf(buyer.user_id), 400, '實際扣的是代幣，付款方式不得標成匯款');
  }],

  ['完成訂單不會覆蓋已被管理員下架的書籍狀態', async () => {
    const { buyer, seller, book } = scene();
    const order = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, status: 'pending_pickup' });
    prisma.rows('books')[0].status = 'removed';

    const res = await setStatus(tokenFor(buyer), order.order_id, 'completed');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(bookOf(book.book_id).status, 'removed');
  }]
];

// 錢包統計欄位（累計收入／支出）與餘額分開驗證。
function walletCounter(userId, field) {
  const wallet = prisma.rows('wallets').find((w) => w.user_id === userId);
  return wallet?.[field] ?? 0;
}

module.exports = { name: '訂單流程與結算', tests };
