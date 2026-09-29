const assert = require('assert');
const {
  request, api, addUser, addAdmin, addBook, addCabinet, addCartItem, addOrder, addReservation,
  tokenFor, verifyHeaders, bookOf, orderOf, balanceOf, notificationsOf, logs, prisma, confirmManual
} = require('./harness');

const bookDeposits = api('services/book-deposits');
const orders = api('services/orders');

const DAY = 24 * 60 * 60 * 1000;
const daysAgo = (days) => new Date(Date.now() - days * DAY);

const depositOf = (bookId) => prisma.rows('book_deposits').find((r) => r.book_id === bookId);

const addDeposit = (book, { days = 0, pausedDays = null, remindedDays = pausedDays, autoPaused = false, escalated = false } = {}) => {
  const row = {
    book_id: book.book_id,
    cabinet_id: book.cabinet_id,
    deposited_at: daysAgo(days),
    paused_at: pausedDays == null ? null : daysAgo(pausedDays),
    auto_paused: autoPaused,
    reminded_at: remindedDays == null ? null : daysAgo(remindedDays),
    escalated_at: escalated ? daysAgo(0) : null
  };
  prisma.rows('book_deposits').push(row);
  return row;
};

const scene = ({ balance = 500, price = 100 } = {}) => {
  const cabinet = addCabinet({ name: '台大書櫃' });
  const buyer = addUser({ nickname: '買家', balance });
  const seller = addUser({ nickname: '賣家', balance: 0 });
  const book = addBook({ sellerId: seller.user_id, price, title: '小王子', cabinet_id: cabinet.cabinet_id });
  return { cabinet, buyer, seller, book, buyerToken: tokenFor(buyer), sellerToken: tokenFor(seller) };
};

const depositBook = (token, bookId) => request('POST', `/api/books/${bookId}/deposit`, { token });
const retrieveBook = (token, bookId) => request('POST', `/api/books/${bookId}/retrieve`, { token });
const checkout = (token, body = {}) =>
  request('POST', '/api/orders/checkout', { token, headers: verifyHeaders(token, 'payment'), body });

const titlesOf = (userId) => notificationsOf(userId).map((n) => n.title);

const reportAndConfirm = async (send) => {
  const pending = await send();
  assert.strictEqual(pending.status, 202, pending.text);
  return confirmManual(pending);
};

const beforeNextTransaction = (mutate) => {
  prisma.$transaction = async (fn) => {
    delete prisma.$transaction;
    await mutate();
    return prisma.$transaction(fn);
  };
};

const tests = [
  ['存書：上架中的書不需訂單即可登記存書，賣家檢視附存書資訊，公開檢視僅標示 in_cabinet', async () => {
    const { seller, buyerToken, sellerToken, book, cabinet } = scene();

    const res = await depositBook(sellerToken, book.book_id);
    assert.strictEqual(res.status, 202, res.text);
    assert.strictEqual(res.body.message, '已送出手動回報，待客服確認後生效');
    assert.strictEqual(res.body.data.book_id, book.book_id);
    assert.strictEqual(res.body.data.in_cabinet, false);
    assert.strictEqual(res.body.data.cabinet.cabinet_name, '台大書櫃');
    assert.strictEqual(res.body.data.deposit, null);
    assert.strictEqual(res.body.data.manual_report.kind, 'deposit');
    assert.strictEqual(res.body.data.manual_report.reason, 'no_device');
    assert.strictEqual(depositOf(book.book_id), undefined, '客服確認前不登記存書');
    const pendingView = await request('GET', `/api/books/${book.book_id}`, { token: sellerToken });
    assert.strictEqual(pendingView.body.data.manual_report.status, 'pending');

    const confirmed = await confirmManual(res);
    assert.strictEqual(confirmed.status, 200, confirmed.text);
    assert.strictEqual(depositOf(book.book_id).cabinet_id, cabinet.cabinet_id);

    const mine = await request('GET', `/api/books?seller_id=${seller.user_id}&status=all`, { token: sellerToken });
    assert.strictEqual(mine.body.data[0].in_cabinet, true);
    assert.deepStrictEqual(Object.keys(mine.body.data[0].deposit).sort(), ['days_stored', 'deposited_at', 'door', 'paused']);
    assert.strictEqual(mine.body.data[0].deposit.door, null);
    assert.strictEqual(mine.body.data[0].location, null);
    assert.strictEqual(mine.body.data[0].manual_report, null);
    assert.strictEqual(mine.body.data[0].cabinet_access.mode, 'manual');

    const ownDetail = await request('GET', `/api/books/${book.book_id}`, { token: sellerToken });
    assert.strictEqual(ownDetail.body.data.deposit.paused, false);

    const store = await request('GET', '/api/books', { token: buyerToken });
    assert.strictEqual(store.body.data[0].in_cabinet, true);
    assert.ok(!('deposit' in store.body.data[0]));

    const detail = await request('GET', `/api/books/${book.book_id}`, { token: buyerToken });
    assert.strictEqual(detail.body.data.in_cabinet, true);
    assert.ok(!('deposit' in detail.body.data));

    const other = addBook({ sellerId: seller.user_id, title: '未存書', cabinet_id: cabinet.cabinet_id });
    const plain = await request('GET', `/api/books/${other.book_id}`, { token: buyerToken });
    assert.strictEqual(plain.body.data.in_cabinet, false);
  }],

  ['存書：聊天室預約保留中的書仍可存書', async () => {
    const { buyer, seller, sellerToken, book } = scene();
    addReservation({ bookId: book.book_id, buyerId: buyer.user_id, sellerId: seller.user_id, status: 'confirmed' });

    const res = await reportAndConfirm(() => depositBook(sellerToken, book.book_id));
    assert.strictEqual(res.status, 200, res.text);
    assert.ok(depositOf(book.book_id));
  }],

  ['存書：非本人、未上架、未公開、已有進行中訂單或已登記時拒絕', async () => {
    const { buyer, seller, sellerToken, buyerToken, book, cabinet } = scene();

    const notMine = await depositBook(buyerToken, book.book_id);
    assert.strictEqual(notMine.status, 403);

    const missing = await depositBook(sellerToken, 9999);
    assert.strictEqual(missing.status, 404);

    const removed = addBook({ sellerId: seller.user_id, cabinet_id: cabinet.cabinet_id, status: 'removed' });
    const delisted = await depositBook(sellerToken, removed.book_id);
    assert.strictEqual(delisted.status, 409);
    assert.strictEqual(delisted.body.code, 'DEPOSIT_NOT_ALLOWED');

    const hidden = addBook({ sellerId: seller.user_id, cabinet_id: cabinet.cabinet_id, is_approved: false });
    const unapproved = await depositBook(sellerToken, hidden.book_id);
    assert.strictEqual(unapproved.status, 409);
    assert.strictEqual(unapproved.body.code, 'DEPOSIT_NOT_ALLOWED');

    const disputed = addBook({ sellerId: seller.user_id, cabinet_id: cabinet.cabinet_id });
    addOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: disputed.book_id, status: 'refunding' });
    const inOrder = await depositBook(sellerToken, disputed.book_id);
    assert.strictEqual(inOrder.status, 409);
    assert.strictEqual(inOrder.body.code, 'DEPOSIT_NOT_ALLOWED');
    assert.strictEqual(inOrder.body.message, '此書籍已有進行中的訂單，請依訂單流程存書');

    const relisted = addBook({ sellerId: seller.user_id, cabinet_id: addCabinet({ name: '公館書櫃' }).cabinet_id });
    addOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: relisted.book_id, status: 'cancelled' });
    assert.strictEqual((await reportAndConfirm(() => depositBook(sellerToken, relisted.book_id))).status, 200);

    const first = await depositBook(sellerToken, book.book_id);
    assert.strictEqual(first.status, 202);
    const pending = await depositBook(sellerToken, book.book_id);
    assert.strictEqual(pending.status, 409);
    assert.strictEqual(pending.body.code, 'MANUAL_REPORT_PENDING');
    assert.strictEqual((await confirmManual(first)).status, 200);
    const twice = await depositBook(sellerToken, book.book_id);
    assert.strictEqual(twice.status, 409);
    assert.strictEqual(twice.body.code, 'BOOK_DEPOSITED');

    assert.deepStrictEqual(prisma.rows('book_deposits').map((r) => r.book_id).sort(), [book.book_id, relisted.book_id].sort());
  }],

  ['存書：未指定書櫃、書櫃停用或維修中時拒絕', async () => {
    const seller = addUser({ nickname: '賣家' });
    const token = tokenFor(seller);
    const inactive = addCabinet({ isActive: false });
    const repairing = addCabinet({ isMaintenance: true });

    const noCabinet = await depositBook(token, addBook({ sellerId: seller.user_id }).book_id);
    assert.strictEqual(noCabinet.status, 400);
    assert.strictEqual(noCabinet.body.code, 'CABINET_REQUIRED');

    const closed = await depositBook(token, addBook({ sellerId: seller.user_id, cabinet_id: inactive.cabinet_id }).book_id);
    assert.strictEqual(closed.status, 400);
    assert.strictEqual(closed.body.code, 'CABINET_UNAVAILABLE');

    const maintenance = await depositBook(token, addBook({ sellerId: seller.user_id, cabinet_id: repairing.cabinet_id }).book_id);
    assert.strictEqual(maintenance.status, 400);
    assert.strictEqual(maintenance.body.code, 'CABINET_MAINTENANCE');

    assert.strictEqual(prisma.rows('book_deposits').length, 0);
  }],

  ['取回：回報取回後刪除存書紀錄，上架中的書維持上架；非本人或未存書時拒絕', async () => {
    const { buyerToken, sellerToken, book } = scene();
    addDeposit(book, { days: 2 });

    const denied = await retrieveBook(buyerToken, book.book_id);
    assert.strictEqual(denied.status, 403);
    assert.ok(depositOf(book.book_id));

    const res = await retrieveBook(sellerToken, book.book_id);
    assert.strictEqual(res.status, 202, res.text);
    assert.strictEqual(res.body.message, '已送出手動回報，待客服確認後生效');
    assert.strictEqual(res.body.data.status, 'removed', '待確認期間暫停販售，避免被當成仍在書櫃而售出');
    assert.strictEqual(res.body.data.manual_report.kind, 'retrieve');
    assert.ok(depositOf(book.book_id));

    assert.strictEqual((await confirmManual(res)).status, 200);
    assert.strictEqual(depositOf(book.book_id), undefined);
    assert.strictEqual(bookOf(book.book_id).status, 'on_sale');

    const again = await retrieveBook(sellerToken, book.book_id);
    assert.strictEqual(again.status, 409);
    assert.strictEqual(again.body.code, 'NOT_DEPOSITED');
  }],

  ['取回：逾期自動暫停販售的書回報取回後恢復上架', async () => {
    const { sellerToken, book } = scene();
    book.status = 'removed';
    addDeposit(book, { days: 9, pausedDays: 2, autoPaused: true });

    const res = await reportAndConfirm(() => retrieveBook(sellerToken, book.book_id));
    assert.strictEqual(res.status, 200, res.text);
    assert.strictEqual(bookOf(book.book_id).status, 'on_sale');
    assert.strictEqual(depositOf(book.book_id), undefined);
  }],

  ['取回：違規下架、管理員下架或賣家自行下架的書取回後不恢復上架', async () => {
    const { seller, sellerToken, cabinet } = scene();
    const admin = addAdmin();
    const add = (overrides) => addBook({ sellerId: seller.user_id, cabinet_id: cabinet.cabinet_id, status: 'removed', ...overrides });

    const violation = add({ is_approved: false });
    addDeposit(violation, { days: 9, pausedDays: 2, autoPaused: true });

    const reported = add();
    addDeposit(reported, { days: 9, pausedDays: 2, autoPaused: true });
    prisma.rows('reports').push({
      report_id: 1, reporter_id: admin.user_id, target_type: 'book', target_id: reported.book_id, reason: '違規', status: 'resolved'
    });

    const forced = add();
    addDeposit(forced, { days: 9, pausedDays: 2, autoPaused: true });
    const removal = await request('PATCH', `/api/admin/books/${forced.book_id}`, {
      token: tokenFor(admin), body: { status: 'removed', reason: '內容不實' }
    });
    assert.strictEqual(removal.status, 200, removal.text);
    assert.strictEqual(depositOf(forced.book_id).auto_paused, false);

    const selfDelisted = add();
    addDeposit(selfDelisted, { days: 9, pausedDays: 2, autoPaused: false });

    for (const book of [violation, reported, forced, selfDelisted]) {
      const res = await reportAndConfirm(() => retrieveBook(sellerToken, book.book_id));
      assert.strictEqual(res.status, 200, res.text);
      assert.strictEqual(bookOf(book.book_id).status, 'removed', `《${book.title}》#${book.book_id} 不應恢復上架`);
      assert.strictEqual(depositOf(book.book_id), undefined);
    }
  }],

  ['結帳：書已存入書櫃時訂單直接成為已存書，買家可立即取書，賣家不需再存書', async () => {
    const { buyer, seller, buyerToken, book } = scene({ price: 120 });
    addDeposit(book, { days: 3 });
    addCartItem(buyer.user_id, book.book_id);

    const res = await checkout(buyerToken);
    assert.strictEqual(res.status, 201, res.text);
    const [order] = res.body.data;
    assert.strictEqual(order.status, 'deposited');
    const row = orderOf(order.order_id);
    assert.ok(row.deposited_at instanceof Date && Date.now() - row.deposited_at.getTime() < 60 * 1000, '取書期限自下單起算');
    assert.strictEqual(depositOf(book.book_id), undefined);
    assert.strictEqual(bookOf(book.book_id).status, 'reserved');
    assert.strictEqual(balanceOf(buyer.user_id), 380);

    const pickup = notificationsOf(buyer.user_id).find((n) => n.title === '書籍已存入書櫃');
    assert.strictEqual(pickup.content, `訂單 ${order.order_no} 的書籍已存放於「台大書櫃」書櫃，即日起可於營業時間內至書櫃以 App 掃描 QR Code 取書。`);
    const sold = notificationsOf(seller.user_id).find((n) => n.title === '書籍已售出');
    assert.strictEqual(sold.content, `訂單 ${order.order_no} 已成立，書籍已存放於書櫃，待買家取書。`);
    assert.ok(!sold.content.includes('七天'));

    const picked = await reportAndConfirm(() => request('PATCH', `/api/orders/${order.order_id}/status`, {
      token: buyerToken, body: { status: 'picked_up' }
    }));
    assert.strictEqual(picked.status, 200, picked.text);
    assert.ok(orderOf(order.order_id).picked_up_at);
  }],

  ['結帳：直接購買已存書的書同樣成為已存書訂單', async () => {
    const { buyerToken, book } = scene();
    addDeposit(book, { days: 1 });

    const res = await request('POST', '/api/orders/buy-now', {
      token: buyerToken, headers: verifyHeaders(buyerToken, 'payment'), body: { book_id: book.book_id }
    });
    assert.strictEqual(res.status, 201, res.text);
    assert.strictEqual(res.body.data.status, 'deposited');
    assert.strictEqual(depositOf(book.book_id), undefined);
  }],

  ['結帳：同一訂單只有部分書已存書時維持待存書，已存書紀錄一併移除', async () => {
    const { buyer, seller, buyerToken, book, cabinet } = scene();
    const second = addBook({ sellerId: seller.user_id, title: '夜間飛行', price: 80, cabinet_id: cabinet.cabinet_id });
    addDeposit(book, { days: 1 });
    addCartItem(buyer.user_id, book.book_id);
    addCartItem(buyer.user_id, second.book_id);

    const res = await checkout(buyerToken);
    assert.strictEqual(res.status, 201, res.text);
    assert.strictEqual(res.body.data.length, 1);
    const [order] = res.body.data;
    assert.strictEqual(order.status, 'pending_deposit');
    assert.strictEqual(orderOf(order.order_id).deposited_at, null);
    assert.strictEqual(prisma.rows('book_deposits').length, 0);
    assert.ok(!titlesOf(buyer.user_id).includes('書籍已存入書櫃'));
    const sold = notificationsOf(seller.user_id).find((n) => n.title === '書籍已售出');
    assert.strictEqual(sold.content, `訂單 ${order.order_no} 已成立，請於七天內至書櫃以 App 掃描 QR Code，存入其餘書籍。`);

    const confirm = await reportAndConfirm(() => request('PATCH', `/api/orders/${order.order_id}/status`, {
      token: tokenFor(seller), body: { status: 'deposited' }
    }));
    assert.strictEqual(confirm.status, 200, confirm.text);
    assert.strictEqual(orderOf(order.order_id).status, 'deposited');
  }],

  ['結帳：未存書的書維持原本的待存書流程', async () => {
    const { buyer, seller, buyerToken, book } = scene();
    addCartItem(buyer.user_id, book.book_id);

    const res = await checkout(buyerToken);
    assert.strictEqual(res.body.data[0].status, 'pending_deposit');
    const sold = notificationsOf(seller.user_id).find((n) => n.title === '書籍已售出');
    assert.strictEqual(sold.content, `訂單 ${res.body.data[0].order_no} 已成立，請於七天內至書櫃存書。`);
  }],

  ['重新上架：書仍登記存放於書櫃時須先回報取回；系統暫停販售者取回後自動上架，自行下架者取回後自行上架', async () => {
    const { seller, sellerToken, cabinet } = scene();
    const relist = (book) => request('PUT', `/api/books/${book.book_id}`, { token: sellerToken, body: { status: 'on_sale' } });

    const paused = addBook({ sellerId: seller.user_id, cabinet_id: cabinet.cabinet_id, status: 'removed' });
    addDeposit(paused, { days: 8, pausedDays: 1, autoPaused: true });
    const blocked = await relist(paused);
    assert.strictEqual(blocked.status, 409);
    assert.strictEqual(blocked.body.code, 'RETRIEVAL_REQUIRED');
    assert.strictEqual(blocked.body.message, '此書籍仍存放於書櫃，請先至書櫃以 App 掃描 QR Code 取回後再重新上架');
    assert.strictEqual(bookOf(paused.book_id).status, 'removed');

    const edit = await request('PUT', `/api/books/${paused.book_id}`, { token: sellerToken, body: { price: 90 } });
    assert.strictEqual(edit.status, 200, edit.text);

    const retrieved = await reportAndConfirm(() => retrieveBook(sellerToken, paused.book_id));
    assert.strictEqual(retrieved.status, 200, retrieved.text);
    assert.strictEqual(bookOf(paused.book_id).status, 'on_sale');

    for (const options of [{ days: 2 }, { days: 9, pausedDays: 2, autoPaused: false }]) {
      const delisted = addBook({ sellerId: seller.user_id, cabinet_id: cabinet.cabinet_id, status: 'removed' });
      addDeposit(delisted, options);
      const denied = await relist(delisted);
      assert.strictEqual(denied.status, 409, `存書 ${options.days} 天的自行下架書籍應須先取回`);
      assert.strictEqual(denied.body.code, 'RETRIEVAL_REQUIRED');

      const back = await reportAndConfirm(() => retrieveBook(sellerToken, delisted.book_id));
      assert.strictEqual(back.status, 200, back.text);
      assert.strictEqual(bookOf(delisted.book_id).status, 'removed');

      const ok = await relist(delisted);
      assert.strictEqual(ok.status, 200, ok.text);
      assert.strictEqual(ok.body.data.status, 'on_sale');
      assert.strictEqual(ok.body.data.in_cabinet, false);
      assert.strictEqual(ok.body.data.deposit, null);
    }
  }],

  ['存書期間：不可變更書櫃，管理員不可刪除書籍；賣家可自行下架且存書紀錄保留', async () => {
    const { sellerToken, book } = scene();
    const other = addCabinet({ name: '公館書櫃' });
    addDeposit(book, { days: 1 });

    const move = await request('PUT', `/api/books/${book.book_id}`, { token: sellerToken, body: { cabinet_id: other.cabinet_id } });
    assert.strictEqual(move.status, 409);
    assert.strictEqual(move.body.code, 'BOOK_DEPOSITED');
    assert.strictEqual(bookOf(book.book_id).cabinet_id, book.cabinet_id);

    const same = await request('PUT', `/api/books/${book.book_id}`, {
      token: sellerToken, body: { cabinet_id: book.cabinet_id, price: 95 }
    });
    assert.strictEqual(same.status, 200, same.text);

    const adminDelete = await request('DELETE', `/api/admin/books/${book.book_id}`, { token: tokenFor(addAdmin()), body: {} });
    assert.strictEqual(adminDelete.status, 409);
    assert.strictEqual(adminDelete.body.code, 'BOOK_DEPOSITED');
    assert.ok(bookOf(book.book_id));

    const delist = await request('DELETE', `/api/books/${book.book_id}`, { token: sellerToken });
    assert.strictEqual(delist.status, 200, delist.text);
    assert.strictEqual(bookOf(book.book_id).status, 'removed');
    assert.ok(depositOf(book.book_id));
  }],

  ['排程：存書滿 7 天仍未售出時暫停販售並通知賣家取回', async () => {
    const { seller, cabinet, book } = scene();
    addDeposit(book, { days: 7.1 });
    const delisted = addBook({ sellerId: seller.user_id, title: '夜間飛行', cabinet_id: cabinet.cabinet_id, status: 'removed' });
    addDeposit(delisted, { days: 8 });
    const fresh = addBook({ sellerId: seller.user_id, title: '風沙星辰', cabinet_id: cabinet.cabinet_id });
    addDeposit(fresh, { days: 6.9 });

    const result = await bookDeposits.runAutomation();
    assert.strictEqual(result.notified, 2);
    assert.strictEqual(result.paused, 1);

    assert.strictEqual(bookOf(book.book_id).status, 'removed');
    const row = depositOf(book.book_id);
    assert.ok(row.paused_at && row.reminded_at);
    assert.strictEqual(row.auto_paused, true);
    assert.strictEqual(depositOf(delisted.book_id).auto_paused, false);
    assert.strictEqual(depositOf(fresh.book_id).paused_at, null);
    assert.strictEqual(bookOf(fresh.book_id).status, 'on_sale');

    const notices = notificationsOf(seller.user_id).filter((n) => n.title === '請取回書櫃中的書籍');
    assert.strictEqual(notices.length, 2);
    const auto = notices.find((n) => n.related_id === book.book_id);
    assert.strictEqual(auto.type, 'order');
    assert.strictEqual(auto.related_type, 'book');
    assert.strictEqual(auto.content,
      '《小王子》存放於「台大書櫃」已滿 7 天仍未售出，已暫停販售。請至書櫃以 App 掃描 QR Code 取回書籍；取回後書籍將恢復上架。');
    assert.strictEqual(notices.find((n) => n.related_id === delisted.book_id).content,
      '《夜間飛行》存放於「台大書櫃」已滿 7 天仍未售出。請至書櫃以 App 掃描 QR Code 取回書籍。');

    const again = await bookDeposits.runAutomation();
    assert.strictEqual(again.notified, 0);
    assert.strictEqual(again.reminded, 0);
  }],

  ['排程：暫停後每 3 天再提醒一次，已刪除帳號的賣家不再提醒', async () => {
    const { seller, cabinet, book } = scene();
    book.status = 'removed';
    addDeposit(book, { days: 10, pausedDays: 3, remindedDays: 3.01, autoPaused: true });
    const recent = addBook({ sellerId: seller.user_id, title: '夜間飛行', cabinet_id: cabinet.cabinet_id, status: 'removed' });
    addDeposit(recent, { days: 9, pausedDays: 2, remindedDays: 2 });
    const gone = addUser({ nickname: '已刪除的使用者' });
    gone.anonymized_at = new Date();
    const orphan = addBook({ sellerId: gone.user_id, title: '風沙星辰', cabinet_id: cabinet.cabinet_id, status: 'removed' });
    addDeposit(orphan, { days: 10, pausedDays: 3, remindedDays: 3.01, escalated: false });

    const selfDelisted = addBook({ sellerId: seller.user_id, title: '人類大地', cabinet_id: cabinet.cabinet_id, status: 'removed' });
    addDeposit(selfDelisted, { days: 11, pausedDays: 4, remindedDays: 4, autoPaused: false });

    const result = await bookDeposits.remindDue();
    assert.strictEqual(result, 2);
    const notices = notificationsOf(seller.user_id);
    const notice = notices.find((n) => n.related_id === book.book_id);
    assert.strictEqual(notice.title, '請取回書櫃中的書籍');
    assert.strictEqual(notice.content,
      '《小王子》已存放於「台大書櫃」10 天，請儘速至書櫃以 App 掃描 QR Code 取回書籍；取回後書籍將恢復上架。');
    assert.strictEqual(notices.find((n) => n.related_id === selfDelisted.book_id).content,
      '《人類大地》已存放於「台大書櫃」11 天，請儘速至書櫃以 App 掃描 QR Code 取回書籍。');
    assert.ok(Date.now() - depositOf(book.book_id).reminded_at.getTime() < 60 * 1000);
    assert.strictEqual(notificationsOf(gone.user_id).length, 0);

    assert.strictEqual(await bookDeposits.remindDue(), 0);
  }],

  ['排程：存書滿 14 天仍未取回時通知具書櫃權限的管理員，每筆存書只通知一次', async () => {
    const { seller, cabinet, book } = scene();
    book.status = 'removed';
    addDeposit(book, { days: 14.2, pausedDays: 7.2, remindedDays: 1, autoPaused: true });
    const young = addBook({ sellerId: seller.user_id, title: '夜間飛行', cabinet_id: cabinet.cabinet_id, status: 'removed' });
    addDeposit(young, { days: 13, pausedDays: 6, remindedDays: 0 });
    const manager = addAdmin();
    const limited = addAdmin({ can_manage_cabinets: false });

    const first = await bookDeposits.runAutomation();
    assert.strictEqual(first.escalated, 1);
    const alerts = notificationsOf(manager.user_id);
    assert.strictEqual(alerts.length, 1);
    assert.strictEqual(alerts[0].title, '書櫃書籍逾期未取回');
    assert.strictEqual(alerts[0].content, '賣家「賣家」存放於「台大書櫃」的《小王子》已滿 14 天仍未取回，請安排人員處理。');
    assert.strictEqual(alerts[0].related_type, 'cabinet_deposit');
    assert.strictEqual(alerts[0].related_id, book.book_id);
    assert.strictEqual(notificationsOf(limited.user_id).length, 0);
    assert.ok(depositOf(book.book_id).escalated_at);
    assert.strictEqual(depositOf(young.book_id).escalated_at, null);

    const second = await bookDeposits.runAutomation();
    assert.strictEqual(second.escalated, 0);
    assert.strictEqual(notificationsOf(manager.user_id).length, 1);
  }],

  ['後台：列出未成立訂單的存書，可篩選逾期與書櫃，需書櫃管理權限', async () => {
    const { seller, cabinet, book } = scene();
    book.status = 'removed';
    addDeposit(book, { days: 15, pausedDays: 8, autoPaused: true, escalated: true });
    const paused = addBook({ sellerId: seller.user_id, title: '夜間飛行', cabinet_id: cabinet.cabinet_id, status: 'removed' });
    addDeposit(paused, { days: 8, pausedDays: 1, autoPaused: true });
    const elsewhere = addCabinet({ name: '公館書櫃' });
    const fresh = addBook({ sellerId: seller.user_id, title: '風沙星辰', cabinet_id: elsewhere.cabinet_id });
    addDeposit(fresh, { days: 1 });
    const token = tokenFor(addAdmin());

    const all = await request('GET', '/api/admin/cabinets/deposits', { token });
    assert.strictEqual(all.status, 200, all.text);
    assert.strictEqual(all.body.pagination.total, 3);
    assert.deepStrictEqual(all.body.data.map((d) => d.book_id), [book.book_id, paused.book_id, fresh.book_id]);
    const [oldest] = all.body.data;
    assert.strictEqual(oldest.title, '小王子');
    assert.match(oldest.book_no, /^BK[0-9A-Z]{7}$/);
    assert.strictEqual(oldest.book_status, 'removed');
    assert.strictEqual(oldest.seller.nickname, '賣家');
    assert.match(oldest.seller.user_no, /^MB[0-9A-Z]{7}$/);
    assert.strictEqual(oldest.seller.deleted, false);
    assert.strictEqual(oldest.cabinet.cabinet_name, '台大書櫃');
    assert.strictEqual(oldest.days_stored, 15);
    assert.strictEqual(oldest.paused, true);
    assert.strictEqual(oldest.escalated, true);
    assert.strictEqual(oldest.overdue, true);
    assert.strictEqual(all.body.data[1].overdue, false);

    const overdue = await request('GET', '/api/admin/cabinets/deposits?overdue=true', { token });
    assert.deepStrictEqual(overdue.body.data.map((d) => d.book_id), [book.book_id]);

    const byCabinet = await request('GET', `/api/admin/cabinets/deposits?cabinet_id=${elsewhere.cabinet_id}`, { token });
    assert.deepStrictEqual(byCabinet.body.data.map((d) => d.book_id), [fresh.book_id]);

    const denied = await request('GET', '/api/admin/cabinets/deposits', { token: tokenFor(addAdmin({ can_manage_cabinets: false })) });
    assert.strictEqual(denied.status, 403);
  }],

  ['後台：登記人員已取出書籍後移除存書紀錄、書籍下架、通知賣家並寫入操作紀錄', async () => {
    const { seller, cabinet, book } = scene();
    addDeposit(book, { days: 3 });
    const paused = addBook({ sellerId: seller.user_id, title: '夜間飛行', cabinet_id: cabinet.cabinet_id, status: 'removed' });
    addDeposit(paused, { days: 20, pausedDays: 13, autoPaused: true, escalated: true });
    const admin = addAdmin();
    const token = tokenFor(admin);

    const res = await request('POST', `/api/admin/cabinets/deposits/${book.book_id}/clear`, { token });
    assert.strictEqual(res.status, 200, res.text);
    assert.strictEqual(res.body.message, '已登記書籍取出');
    assert.deepStrictEqual(res.body.data, { book_id: book.book_id, book_status: 'removed' });
    assert.strictEqual(depositOf(book.book_id), undefined);
    assert.strictEqual(bookOf(book.book_id).status, 'removed');

    const notice = notificationsOf(seller.user_id).find((n) => n.title === '書櫃中的書籍已由客服取出');
    assert.strictEqual(notice.content, '《小王子》已由客服人員自「台大書櫃」取出，書籍已下架。如需領回書籍，請聯絡客服。');
    const [log] = logs();
    assert.strictEqual(log.action, '登記書櫃書籍取出');
    assert.strictEqual(log.target_type, 'book');
    assert.strictEqual(log.target_id, book.book_id);
    assert.match(JSON.parse(log.detail).summary, /小王子.*台大書櫃.*存放 3 天.*書籍改為下架.*通知賣家/);

    const again = await request('POST', `/api/admin/cabinets/deposits/${book.book_id}/clear`, { token });
    assert.strictEqual(again.status, 404);

    const cleared = await request('POST', `/api/admin/cabinets/deposits/${paused.book_id}/clear`, { token });
    assert.strictEqual(cleared.status, 200, cleared.text);
    assert.strictEqual(cleared.body.data.book_status, 'removed');
    assert.strictEqual(prisma.rows('book_deposits').length, 0);

    const denied = await request('POST', `/api/admin/cabinets/deposits/${paused.book_id}/clear`, {
      token: tokenFor(addAdmin({ can_manage_cabinets: false }))
    });
    assert.strictEqual(denied.status, 403);
  }],
  ['取回：待客服確認期間暫停販售，無法被購買也不被排程暫停；駁回後恢復上架，確認後維持上架', async () => {
    const { buyerToken, sellerToken, book } = scene();
    addDeposit(book, { days: 7.1 });

    const pending = await retrieveBook(sellerToken, book.book_id);
    assert.strictEqual(pending.status, 202, pending.text);
    assert.strictEqual(bookOf(book.book_id).status, 'removed');
    const bought = await request('POST', '/api/orders/buy-now', {
      token: buyerToken, headers: verifyHeaders(buyerToken, 'payment'), body: { book_id: book.book_id }
    });
    assert.strictEqual(bought.status, 400, '取回待確認的書不可被當成仍在書櫃而售出');
    assert.strictEqual((await bookDeposits.runAutomation()).paused, 0);
    assert.strictEqual(depositOf(book.book_id).paused_at, null);

    const admin = addAdmin();
    const rejected = await request('POST', `/api/admin/cabinet-manual-reports/${pending.body.data.manual_report.report_no}/reject`, {
      token: tokenFor(admin), body: { note: '書籍仍在書櫃內' }
    });
    assert.strictEqual(rejected.status, 200, rejected.text);
    assert.strictEqual(bookOf(book.book_id).status, 'on_sale');
    assert.ok(depositOf(book.book_id));

    const done = await reportAndConfirm(() => retrieveBook(sellerToken, book.book_id));
    assert.strictEqual(done.status, 200, done.text);
    assert.strictEqual(bookOf(book.book_id).status, 'on_sale');
    assert.strictEqual(depositOf(book.book_id), undefined);
  }],

  ['取回：待客服確認期間被管理員下架時，確認或駁回後都不恢復上架', async () => {
    const { seller, sellerToken, book, cabinet } = scene();
    const admin = addAdmin();
    addDeposit(book, { days: 2 });
    const other = addBook({ sellerId: seller.user_id, title: '夜間飛行', cabinet_id: cabinet.cabinet_id });
    addDeposit(other, { days: 2 });

    const pending = await retrieveBook(sellerToken, book.book_id);
    const pendingOther = await retrieveBook(sellerToken, other.book_id);
    for (const b of [book, other]) {
      const removal = await request('PATCH', `/api/admin/books/${b.book_id}`, { token: tokenFor(admin), body: { status: 'removed', reason: '內容不實' } });
      assert.strictEqual(removal.status, 200, removal.text);
    }

    assert.strictEqual((await confirmManual(pending)).status, 200);
    assert.strictEqual(bookOf(book.book_id).status, 'removed');
    assert.strictEqual(depositOf(book.book_id), undefined);

    const rejected = await request('POST', `/api/admin/cabinet-manual-reports/${pendingOther.body.data.manual_report.report_no}/reject`, {
      token: tokenFor(addAdmin()), body: { note: '書籍仍在書櫃內' }
    });
    assert.strictEqual(rejected.status, 200, rejected.text);
    assert.strictEqual(bookOf(other.book_id).status, 'removed');
  }],

  ['取回：書已轉入訂單時提醒賣家書籍已售出，不可取回', async () => {
    const { buyer, buyerToken, sellerToken, book, seller, cabinet } = scene();
    addDeposit(book, { days: 1 });
    addCartItem(buyer.user_id, book.book_id);
    const [order] = (await checkout(buyerToken)).body.data;

    const sold = await retrieveBook(sellerToken, book.book_id);
    assert.strictEqual(sold.status, 409);
    assert.strictEqual(sold.body.code, 'BOOK_SOLD_IN_CABINET');
    assert.strictEqual(sold.body.message, `此書籍已售出（訂單 ${order.order_no}），買家將至書櫃取書，請勿取回；如已取出，請儘速放回書櫃`);

    const first = addBook({ sellerId: seller.user_id, title: '夜間飛行', cabinet_id: cabinet.cabinet_id });
    const second = addBook({ sellerId: seller.user_id, title: '風沙星辰', cabinet_id: cabinet.cabinet_id });
    addDeposit(first, { days: 1 });
    addCartItem(buyer.user_id, first.book_id);
    addCartItem(buyer.user_id, second.book_id);
    const [partial] = (await checkout(buyerToken)).body.data;
    assert.strictEqual(partial.status, 'pending_deposit');

    const keep = await retrieveBook(sellerToken, first.book_id);
    assert.strictEqual(keep.body.code, 'BOOK_SOLD_IN_CABINET');
    assert.strictEqual(keep.body.message, `此書籍已售出（訂單 ${partial.order_no}），請將書籍留在書櫃，並以 App 掃描 QR Code 辦理訂單存書`);

    const never = await retrieveBook(sellerToken, second.book_id);
    assert.strictEqual(never.body.code, 'NOT_DEPOSITED');
  }],

  ['排程：聊天室預約保留中的書不暫停販售，保留結束後才暫停', async () => {
    const { buyer, seller, book } = scene();
    addDeposit(book, { days: 8 });
    const hold = addReservation({ bookId: book.book_id, buyerId: buyer.user_id, sellerId: seller.user_id, status: 'confirmed' });

    const held = await bookDeposits.runAutomation();
    assert.strictEqual(held.notified, 0);
    assert.strictEqual(bookOf(book.book_id).status, 'on_sale');
    assert.strictEqual(depositOf(book.book_id).paused_at, null);

    hold.pickup_deadline = new Date(Date.now() - 60 * 1000);
    const released = await bookDeposits.runAutomation();
    assert.strictEqual(released.paused, 1);
    assert.strictEqual(bookOf(book.book_id).status, 'removed');
  }],

  ['書櫃維修中：不標示 in_cabinet，不暫停販售也不提醒取回', async () => {
    const { seller, buyerToken, book, cabinet } = scene();
    addDeposit(book, { days: 8 });
    const paused = addBook({ sellerId: seller.user_id, title: '夜間飛行', cabinet_id: cabinet.cabinet_id, status: 'removed' });
    addDeposit(paused, { days: 12, pausedDays: 5, remindedDays: 5, autoPaused: true });
    cabinet.is_maintenance = 1;

    const detail = await request('GET', `/api/books/${book.book_id}`, { token: buyerToken });
    assert.strictEqual(detail.body.data.in_cabinet, false);

    const result = await bookDeposits.runAutomation();
    assert.strictEqual(result.notified, 0);
    assert.strictEqual(result.reminded, 0);
    assert.strictEqual(bookOf(book.book_id).status, 'on_sale');
    assert.strictEqual(notificationsOf(seller.user_id).length, 0);

    cabinet.is_maintenance = 0;
    const resumed = await bookDeposits.runAutomation();
    assert.strictEqual(resumed.paused, 1);
    assert.strictEqual(resumed.reminded, 1);
  }],

  ['排程：送審中的書暫停後回報取回可恢復上架；檢舉成立的書不承諾恢復上架', async () => {
    const { seller, sellerToken, cabinet, book } = scene();
    book.is_approved = false;
    prisma.rows('ai_book_reviews').push({ book_id: book.book_id, status: 'pending', verdict: 'review' });
    addDeposit(book, { days: 8 });

    const reported = addBook({ sellerId: seller.user_id, title: '夜間飛行', cabinet_id: cabinet.cabinet_id });
    addDeposit(reported, { days: 8 });
    prisma.rows('reports').push({
      report_id: 1, reporter_id: seller.user_id, target_type: 'book', target_id: reported.book_id, reason: '違規', status: 'resolved'
    });

    const result = await bookDeposits.runAutomation();
    assert.strictEqual(result.paused, 2);
    const noticeOf = (bookId) => notificationsOf(seller.user_id).find((n) => n.related_id === bookId).content;
    assert.match(noticeOf(book.book_id), /取回後書籍將恢復上架/);
    assert.strictEqual(noticeOf(reported.book_id),
      '《夜間飛行》存放於「台大書櫃」已滿 7 天仍未售出，已暫停販售。請至書櫃以 App 掃描 QR Code 取回書籍。');

    const pending = await reportAndConfirm(() => retrieveBook(sellerToken, book.book_id));
    assert.strictEqual(pending.status, 200, pending.text);
    assert.strictEqual(bookOf(book.book_id).status, 'on_sale');
    assert.strictEqual(bookOf(book.book_id).is_approved, false);

    const locked = await reportAndConfirm(() => retrieveBook(sellerToken, reported.book_id));
    assert.strictEqual(locked.status, 200, locked.text);
    assert.strictEqual(bookOf(reported.book_id).status, 'removed');
  }],

  ['違規或管理員下架：檢舉成立下架、書籍編輯端點下架都取消自動恢復上架', async () => {
    const { seller, sellerToken, cabinet } = scene();
    const admin = addAdmin();
    const add = (title) => {
      const book = addBook({ sellerId: seller.user_id, title, cabinet_id: cabinet.cabinet_id, status: 'removed' });
      addDeposit(book, { days: 9, pausedDays: 2, autoPaused: true });
      return book;
    };

    const reported = add('夜間飛行');
    prisma.rows('reports').push({
      report_id: 1, reporter_id: seller.user_id, target_type: 'book', target_id: reported.book_id, reason: '違規', status: 'pending'
    });
    const resolve = await request('PATCH', '/api/admin/reports/1', {
      token: tokenFor(admin), body: { status: 'resolved', remove_target: true }
    });
    assert.strictEqual(resolve.status, 200, resolve.text);
    assert.strictEqual(depositOf(reported.book_id).auto_paused, false);

    const edited = add('風沙星辰');
    const put = await request('PUT', `/api/books/${edited.book_id}`, { token: tokenFor(admin), body: { status: 'removed' } });
    assert.strictEqual(put.status, 200, put.text);
    assert.strictEqual(depositOf(edited.book_id).auto_paused, false);

    for (const book of [reported, edited]) {
      const res = await reportAndConfirm(() => retrieveBook(sellerToken, book.book_id));
      assert.strictEqual(res.status, 200, res.text);
      assert.strictEqual(bookOf(book.book_id).status, 'removed');
      assert.strictEqual(depositOf(book.book_id), undefined);
    }
  }],

  ['管理員：恢復上架已逾期的存書時重新起算存書天數，不再提醒取回', async () => {
    const { seller, cabinet } = scene();
    const admin = addAdmin();
    const viaPatch = addBook({ sellerId: seller.user_id, title: '夜間飛行', cabinet_id: cabinet.cabinet_id, status: 'removed' });
    addDeposit(viaPatch, { days: 15, pausedDays: 8, remindedDays: 4, autoPaused: true, escalated: true });
    const viaPut = addBook({ sellerId: seller.user_id, title: '風沙星辰', cabinet_id: cabinet.cabinet_id, status: 'removed' });
    addDeposit(viaPut, { days: 9, pausedDays: 2, remindedDays: 4, autoPaused: true });

    const patched = await request('PATCH', `/api/admin/books/${viaPatch.book_id}`, { token: tokenFor(admin), body: { status: 'on_sale' } });
    assert.strictEqual(patched.status, 200, patched.text);
    const put = await request('PUT', `/api/books/${viaPut.book_id}`, { token: tokenFor(admin), body: { status: 'on_sale' } });
    assert.strictEqual(put.status, 200, put.text);

    for (const book of [viaPatch, viaPut]) {
      const row = depositOf(book.book_id);
      assert.strictEqual(bookOf(book.book_id).status, 'on_sale');
      assert.ok(Date.now() - row.deposited_at.getTime() < 60 * 1000);
      assert.strictEqual(row.paused_at, null);
      assert.strictEqual(row.reminded_at, null);
      assert.strictEqual(row.escalated_at, null);
      assert.strictEqual(row.auto_paused, false);
    }

    const before = notificationsOf(seller.user_id).length;
    const result = await bookDeposits.runAutomation();
    assert.deepStrictEqual(result, { notified: 0, paused: 0, reminded: 0, escalated: 0 });
    assert.strictEqual(notificationsOf(seller.user_id).length, before);
  }],

  ['結帳：跨賣家購物車依各自的存書狀態成立訂單與通知', async () => {
    const { buyer, seller, buyerToken, book, cabinet } = scene();
    addDeposit(book, { days: 2 });
    const other = addUser({ nickname: '第二位賣家' });
    const plain = addBook({ sellerId: other.user_id, title: '夜間飛行', price: 80, cabinet_id: cabinet.cabinet_id });
    addCartItem(buyer.user_id, book.book_id);
    addCartItem(buyer.user_id, plain.book_id);

    const res = await checkout(buyerToken);
    assert.strictEqual(res.status, 201, res.text);
    const bySeller = new Map(res.body.data.map((o) => [o.seller_id, o]));
    const stored = bySeller.get(seller.user_id);
    const waiting = bySeller.get(other.user_id);
    assert.strictEqual(stored.status, 'deposited');
    assert.ok(orderOf(stored.order_id).deposited_at);
    assert.strictEqual(waiting.status, 'pending_deposit');
    assert.strictEqual(orderOf(waiting.order_id).deposited_at, null);

    const pickups = notificationsOf(buyer.user_id).filter((n) => n.title === '書籍已存入書櫃');
    assert.deepStrictEqual(pickups.map((n) => n.related_id), [stored.order_id]);
    const soldTo = (userId) => notificationsOf(userId).find((n) => n.title === '書籍已售出').content;
    assert.strictEqual(soldTo(seller.user_id), `訂單 ${stored.order_no} 已成立，書籍已存放於書櫃，待買家取書。`);
    assert.strictEqual(soldTo(other.user_id), `訂單 ${waiting.order_no} 已成立，請於七天內至書櫃存書。`);
  }],

  ['結帳：存書不在訂單書櫃時不直接成立已存書，通知賣家移至訂單書櫃', async () => {
    const { buyer, seller, buyerToken, book, cabinet } = scene();
    const other = addCabinet({ name: '公館書櫃' });
    const elsewhere = addBook({ sellerId: seller.user_id, title: '夜間飛行', price: 80, cabinet_id: other.cabinet_id });
    addDeposit(book, { days: 1 });
    addDeposit(elsewhere, { days: 1 });
    addCartItem(buyer.user_id, book.book_id);
    addCartItem(buyer.user_id, elsewhere.book_id);

    const [order] = (await checkout(buyerToken)).body.data;
    assert.strictEqual(order.status, 'pending_deposit');
    assert.strictEqual(order.cabinet_id, cabinet.cabinet_id);
    assert.strictEqual(prisma.rows('book_deposits').length, 0);
    assert.deepStrictEqual(prisma.rows('order_items').filter((i) => i.order_id === order.order_id).map((i) => i.pre_deposited), [true, true]);
    assert.ok(!titlesOf(buyer.user_id).includes('書籍已存入書櫃'));
    assert.strictEqual(notificationsOf(seller.user_id).find((n) => n.title === '書籍已售出').content,
      `訂單 ${order.order_no} 已成立，請於七天內至原存放的書櫃以 App 掃描 QR Code 取回書籍，再存入「台大書櫃」。`);

    const single = addBook({ sellerId: seller.user_id, title: '風沙星辰', cabinet_id: cabinet.cabinet_id });
    addDeposit(single, { days: 1 }).cabinet_id = other.cabinet_id;
    const res = await request('POST', '/api/orders/buy-now', {
      token: buyerToken, headers: verifyHeaders(buyerToken, 'payment'), body: { book_id: single.book_id }
    });
    assert.strictEqual(res.status, 201, res.text);
    assert.strictEqual(res.body.data.status, 'pending_deposit');
  }],

  ['結帳：預先存書的訂單成立即為已存書，買家無法自行取消', async () => {
    const { buyer, buyerToken, book } = scene();
    addDeposit(book, { days: 1 });
    addCartItem(buyer.user_id, book.book_id);
    const [order] = (await checkout(buyerToken)).body.data;

    const res = await request('PATCH', `/api/orders/${order.order_id}/cancel`, { token: buyerToken, body: {} });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.code, 'ORDER_NOT_CANCELLABLE');
    assert.strictEqual(orderOf(order.order_id).status, 'deposited');
  }],

  ['取消：部分存書的訂單由買家取消後，先前存書的書恢復存書登記並通知賣家', async () => {
    const { buyer, seller, buyerToken, book, cabinet } = scene();
    const second = addBook({ sellerId: seller.user_id, title: '夜間飛行', price: 80, cabinet_id: cabinet.cabinet_id });
    addDeposit(book, { days: 5 });
    addCartItem(buyer.user_id, book.book_id);
    addCartItem(buyer.user_id, second.book_id);
    const [order] = (await checkout(buyerToken)).body.data;
    assert.strictEqual(prisma.rows('book_deposits').length, 0);

    const res = await request('PATCH', `/api/orders/${order.order_id}/cancel`, { token: buyerToken, body: { reason: '買錯了' } });
    assert.strictEqual(res.status, 200, res.text);

    const row = depositOf(book.book_id);
    assert.strictEqual(row.cabinet_id, cabinet.cabinet_id);
    assert.strictEqual(row.paused_at, null);
    assert.ok(Date.now() - row.deposited_at.getTime() < 60 * 1000);
    assert.strictEqual(depositOf(second.book_id), undefined);
    assert.strictEqual(bookOf(book.book_id).status, 'on_sale');

    const detail = await request('GET', `/api/books/${book.book_id}`, { token: buyerToken });
    assert.strictEqual(detail.body.data.in_cabinet, true);
    const notice = notificationsOf(seller.user_id).find((n) => n.title === '訂單已取消');
    assert.strictEqual(notice.content, `訂單 ${order.order_no} 已取消。書櫃中的書籍將繼續販售。原因：買錯了`);
  }],

  ['取消：逾期未存書自動取消時恢復存書登記，要求賣家取回並回報後才能重新上架', async () => {
    const { buyer, seller, buyerToken, sellerToken, book, cabinet } = scene();
    const second = addBook({ sellerId: seller.user_id, title: '夜間飛行', price: 80, cabinet_id: cabinet.cabinet_id });
    addDeposit(book, { days: 1 });
    addCartItem(buyer.user_id, book.book_id);
    addCartItem(buyer.user_id, second.book_id);
    const [order] = (await checkout(buyerToken)).body.data;
    orderOf(order.order_id).created_at = daysAgo(8);

    assert.strictEqual(await orders.cancelUndeposited(), 1);
    assert.strictEqual(orderOf(order.order_id).status, 'cancelled');
    assert.strictEqual(bookOf(book.book_id).status, 'removed');
    assert.ok(depositOf(book.book_id));
    assert.strictEqual(depositOf(second.book_id), undefined);

    const notice = notificationsOf(seller.user_id).find((n) => n.title === '訂單已取消');
    assert.strictEqual(notice.content,
      `訂單 ${order.order_no} 逾 7 天未存書，已自動取消，書籍已改為下架。已存放於書櫃的書籍請至書櫃以 App 掃描 QR Code 取回；如需販售請重新上架。`);

    const relist = await request('PUT', `/api/books/${book.book_id}`, { token: sellerToken, body: { status: 'on_sale' } });
    assert.strictEqual(relist.body.code, 'RETRIEVAL_REQUIRED');
    assert.strictEqual((await reportAndConfirm(() => retrieveBook(sellerToken, book.book_id))).status, 200);
    assert.strictEqual(depositOf(book.book_id), undefined);
  }],

  ['取消：管理員取消預先存書的已存書訂單後，書恢復販售並列於後台存書列表', async () => {
    const { buyer, buyerToken, book, cabinet } = scene();
    addDeposit(book, { days: 3 });
    addCartItem(buyer.user_id, book.book_id);
    const [order] = (await checkout(buyerToken)).body.data;
    const token = tokenFor(addAdmin());

    const res = await request('PATCH', `/api/admin/orders/${order.order_id}`, { token, body: { status: 'cancelled', note: '賣家來電取消' } });
    assert.strictEqual(res.status, 200, res.text);
    assert.strictEqual(bookOf(book.book_id).status, 'on_sale');
    assert.strictEqual(depositOf(book.book_id).cabinet_id, cabinet.cabinet_id);

    const list = await request('GET', '/api/admin/cabinets/deposits', { token });
    assert.deepStrictEqual(list.body.data.map((d) => d.book_id), [book.book_id]);
  }],

  ['購物車與收藏：書籍附 in_cabinet', async () => {
    const { buyer, seller, buyerToken, book, cabinet } = scene();
    addDeposit(book, { days: 1 });
    const plain = addBook({ sellerId: seller.user_id, title: '夜間飛行', cabinet_id: cabinet.cabinet_id });
    addCartItem(buyer.user_id, book.book_id);
    addCartItem(buyer.user_id, plain.book_id);
    for (const b of [book, plain]) {
      prisma.rows('favorites').push({ favorite_id: prisma.nextId('favorites'), user_id: buyer.user_id, book_id: b.book_id, created_at: new Date() });
    }

    const cart = await request('GET', '/api/cart', { token: buyerToken });
    assert.strictEqual(cart.status, 200, cart.text);
    const cartFlags = Object.fromEntries(cart.body.data.map((i) => [i.book_id, i.books.in_cabinet]));
    assert.deepStrictEqual(cartFlags, { [book.book_id]: true, [plain.book_id]: false });
    assert.ok(cart.body.data.every((i) => !('deposit' in i.books)));

    const favorites = await request('GET', '/api/favorites', { token: buyerToken });
    const favoriteFlags = Object.fromEntries(favorites.body.data.map((b) => [b.book_id, b.in_cabinet]));
    assert.deepStrictEqual(favoriteFlags, { [book.book_id]: true, [plain.book_id]: false });
  }],

  ['後台：書櫃仍有訂單成立前的存書時不可停用', async () => {
    const { cabinet, book } = scene();
    addDeposit(book, { days: 1 });
    const token = tokenFor(addAdmin());

    const denied = await request('PUT', `/api/admin/cabinets/${cabinet.cabinet_id}`, { token, body: { is_active: false } });
    assert.strictEqual(denied.status, 409);
    assert.strictEqual(denied.body.code, 'CABINET_HAS_DEPOSITS');
    assert.strictEqual(denied.body.message, '此書櫃仍有 1 本訂單成立前存放的書籍，請先於存書列表登記取出後再停用');
    assert.strictEqual(cabinet.is_active, true);

    const renamed = await request('PUT', `/api/admin/cabinets/${cabinet.cabinet_id}`, { token, body: { cabinet_name: '台大總圖書櫃' } });
    assert.strictEqual(renamed.status, 200, renamed.text);

    await request('POST', `/api/admin/cabinets/deposits/${book.book_id}/clear`, { token });
    const closed = await request('PUT', `/api/admin/cabinets/${cabinet.cabinet_id}`, { token, body: { is_active: false } });
    assert.strictEqual(closed.status, 200, closed.text);
  }],

  ['後台：賣家帳號刪除而通知取出的存書列入逾期篩選，登記取出時不通知已刪除的賣家', async () => {
    const { seller, book } = scene();
    seller.anonymized_at = new Date();
    seller.nickname = '已刪除的使用者';
    book.status = 'removed';
    addDeposit(book, { days: 2, pausedDays: 0, escalated: true });
    const token = tokenFor(addAdmin());

    const overdue = await request('GET', '/api/admin/cabinets/deposits?overdue=true', { token });
    assert.deepStrictEqual(overdue.body.data.map((d) => d.book_id), [book.book_id]);
    assert.strictEqual(overdue.body.data[0].overdue, true);
    assert.strictEqual(overdue.body.data[0].seller.deleted, true);

    const res = await request('POST', `/api/admin/cabinets/deposits/${book.book_id}/clear`, { token });
    assert.strictEqual(res.status, 200, res.text);
    assert.strictEqual(notificationsOf(seller.user_id).length, 0);
    const summary = JSON.parse(logs()[0].detail).summary;
    assert.match(summary, /小王子.*台大書櫃/);
    assert.ok(!summary.includes('通知賣家'));
  }],

  ['刪除使用者：仍有書籍存放於書櫃時拒絕永久刪除', async () => {
    const { seller, book } = scene();
    addDeposit(book, { days: 1 });
    const admin = addAdmin();
    const token = tokenFor(admin);

    const res = await request('DELETE', `/api/users/${seller.user_id}`, { token, headers: verifyHeaders(token, 'sensitive') });
    assert.strictEqual(res.status, 409, res.text);
    assert.strictEqual(res.body.code, 'BOOK_DEPOSITED');
    assert.strictEqual(res.body.message, '此使用者仍有書籍存放於書櫃，請先於書櫃管理登記取出，或改用匿名化');
    assert.ok(prisma.rows('users').some((u) => u.user_id === seller.user_id));
    assert.ok(depositOf(book.book_id));
  }],

  ['AI 審核：核准先前駁回而下架的逾期存書時重新起算存書天數，不再提醒取回', async () => {
    const { seller, book } = scene();
    Object.assign(book, { status: 'removed', is_approved: false });
    prisma.rows('ai_book_reviews').push({ book_id: book.book_id, status: 'rejected', verdict: 'reject' });
    addDeposit(book, { days: 15, pausedDays: 8, remindedDays: 4, escalated: true });

    const res = await request('PATCH', `/api/admin/ai/reviews/${book.book_id}`, { token: tokenFor(addAdmin()), body: { decision: 'approve' } });
    assert.strictEqual(res.status, 200, res.text);
    assert.strictEqual(bookOf(book.book_id).status, 'on_sale');
    const row = depositOf(book.book_id);
    assert.ok(Date.now() - row.deposited_at.getTime() < 60 * 1000);
    assert.strictEqual(row.paused_at, null);
    assert.strictEqual(row.reminded_at, null);
    assert.strictEqual(row.escalated_at, null);
    assert.strictEqual(row.auto_paused, false);

    const before = notificationsOf(seller.user_id).length;
    assert.deepStrictEqual(await bookDeposits.runAutomation(), { notified: 0, paused: 0, reminded: 0, escalated: 0 });
    assert.strictEqual(notificationsOf(seller.user_id).length, before);
  }],

  ['還原：還原管理員下架與恢復上架時比照同步存書紀錄', async () => {
    const { seller, cabinet, book } = scene();
    const admin = addAdmin();
    const token = tokenFor(admin);
    const undo = (log) => request('POST', `/api/admin/operation-logs/${log.log_id}/undo`, {
      token, headers: verifyHeaders(token, 'admin'), body: {}
    });

    const row = addDeposit(book, { days: 2 });
    const delist = await request('PATCH', `/api/admin/books/${book.book_id}`, { token, body: { status: 'removed', reason: '資料待確認' } });
    assert.strictEqual(delist.status, 200, delist.text);
    Object.assign(row, { deposited_at: daysAgo(9), paused_at: daysAgo(2), reminded_at: daysAgo(3.5) });

    const relisted = await undo(logs().at(-1));
    assert.strictEqual(relisted.status, 200, relisted.text);
    assert.strictEqual(bookOf(book.book_id).status, 'on_sale');
    assert.ok(Date.now() - depositOf(book.book_id).deposited_at.getTime() < 60 * 1000);
    assert.strictEqual(depositOf(book.book_id).paused_at, null);
    assert.strictEqual(depositOf(book.book_id).reminded_at, null);
    assert.strictEqual((await bookDeposits.runAutomation()).reminded, 0);

    const paused = addBook({ sellerId: seller.user_id, title: '夜間飛行', cabinet_id: cabinet.cabinet_id, status: 'removed' });
    addDeposit(paused, { days: 9, pausedDays: 2, autoPaused: true });
    const relist = await request('PATCH', `/api/admin/books/${paused.book_id}`, { token, body: { status: 'on_sale' } });
    assert.strictEqual(relist.status, 200, relist.text);
    const reset = { ...depositOf(paused.book_id) };
    assert.strictEqual(reset.paused_at, null);
    assert.strictEqual(reset.auto_paused, false);

    const delisted = await undo(logs().at(-1));
    assert.strictEqual(delisted.status, 200, delisted.text);
    assert.strictEqual(bookOf(paused.book_id).status, 'removed');
    assert.deepStrictEqual(depositOf(paused.book_id), reset);
  }],

  ['取消：已存書的訂單在取書前取消時，訂單每本書都恢復存書登記於訂單書櫃', async () => {
    const { buyer, seller, buyerToken, sellerToken, book, cabinet } = scene();
    const other = addCabinet({ name: '公館書櫃' });
    const moved = addBook({ sellerId: seller.user_id, title: '夜間飛行', price: 80, cabinet_id: other.cabinet_id });
    addDeposit(book, { days: 2 });
    addCartItem(buyer.user_id, book.book_id);
    addCartItem(buyer.user_id, moved.book_id);
    const [order] = (await checkout(buyerToken)).body.data;
    assert.strictEqual(order.cabinet_id, cabinet.cabinet_id);
    const confirm = await reportAndConfirm(() => request('PATCH', `/api/orders/${order.order_id}/status`, {
      token: sellerToken, body: { status: 'deposited' }
    }));
    assert.strictEqual(confirm.status, 200, confirm.text);

    const res = await request('PATCH', `/api/orders/${order.order_id}/cancel`, { token: tokenFor(addAdmin()), body: { reason: '買家來電取消' } });
    assert.strictEqual(res.status, 200, res.text);
    for (const b of [book, moved]) {
      const row = depositOf(b.book_id);
      assert.ok(row, `《${b.title}》應恢復存書登記`);
      assert.strictEqual(row.cabinet_id, cabinet.cabinet_id);
      assert.strictEqual(bookOf(b.book_id).cabinet_id, cabinet.cabinet_id);
      assert.strictEqual(bookOf(b.book_id).status, 'on_sale');
    }
    const detail = await request('GET', `/api/books/${moved.book_id}`, { token: buyerToken });
    assert.strictEqual(detail.body.data.in_cabinet, true);

    const resold = await request('POST', '/api/orders/buy-now', {
      token: buyerToken, headers: verifyHeaders(buyerToken, 'payment'), body: { book_id: moved.book_id }
    });
    assert.strictEqual(resold.body.data.status, 'deposited', '恢復登記的書再次售出時應直接為已存書');

    const uncollected = addBook({ sellerId: seller.user_id, title: '人類大地', price: 70, cabinet_id: cabinet.cabinet_id });
    addCartItem(buyer.user_id, uncollected.book_id);
    const [late] = (await checkout(buyerToken)).body.data;
    await reportAndConfirm(() => request('PATCH', `/api/orders/${late.order_id}/status`, { token: sellerToken, body: { status: 'deposited' } }));
    orderOf(late.order_id).deposited_at = daysAgo(8);
    assert.strictEqual(await orders.cancelUncollected(), 1);
    assert.ok(depositOf(uncollected.book_id));
    assert.strictEqual(bookOf(uncollected.book_id).status, 'removed');
    const notice = notificationsOf(seller.user_id).filter((n) => n.title === '訂單已取消' && n.related_id === late.order_id)[0];
    assert.strictEqual(notice.content,
      `訂單 ${late.order_no} 的買家逾 7 天未取書，訂單已自動取消，請至書櫃以 App 掃描 QR Code 取回書籍；書籍已改為下架，如需販售請重新上架。`);
  }],

  ['取回：存書與訂單書櫃不同時提示移至訂單書櫃，同書櫃者維持留在書櫃的提示', async () => {
    const { buyer, buyerToken, sellerToken, seller, book } = scene();
    const other = addCabinet({ name: '公館書櫃' });
    const elsewhere = addBook({ sellerId: seller.user_id, title: '夜間飛行', price: 80, cabinet_id: other.cabinet_id });
    addDeposit(book, { days: 1 });
    addDeposit(elsewhere, { days: 1 });
    addCartItem(buyer.user_id, book.book_id);
    addCartItem(buyer.user_id, elsewhere.book_id);
    const [order] = (await checkout(buyerToken)).body.data;
    assert.strictEqual(order.status, 'pending_deposit');

    const move = await retrieveBook(sellerToken, elsewhere.book_id);
    assert.strictEqual(move.status, 409);
    assert.strictEqual(move.body.code, 'BOOK_SOLD_IN_CABINET');
    assert.strictEqual(move.body.message, `此書籍已售出（訂單 ${order.order_no}），請至書櫃以 App 掃描 QR Code 取回，再存入「台大書櫃」`);

    const keep = await retrieveBook(sellerToken, book.book_id);
    assert.strictEqual(keep.body.code, 'BOOK_SOLD_IN_CABINET');
    assert.strictEqual(keep.body.message, `此書籍已售出（訂單 ${order.order_no}），請將書籍留在書櫃，並以 App 掃描 QR Code 辦理訂單存書`);
  }],

  ['排程：書櫃維修中不通知管理員逾期存書，維修結束後仍逾期才通知', async () => {
    const { cabinet, book } = scene();
    book.status = 'removed';
    addDeposit(book, { days: 15, pausedDays: 8, remindedDays: 1, autoPaused: true });
    const manager = addAdmin();
    cabinet.is_maintenance = 1;

    assert.strictEqual(await bookDeposits.escalateDue(), 0);
    assert.strictEqual(notificationsOf(manager.user_id).length, 0);
    assert.strictEqual(depositOf(book.book_id).escalated_at, null);

    cabinet.is_maintenance = 0;
    assert.strictEqual(await bookDeposits.escalateDue(), 1);
    assert.strictEqual(notificationsOf(manager.user_id)[0].title, '書櫃書籍逾期未取回');
  }],

  ['取消：管理員取消而書恢復存書登記時通知賣家，僅上架中的書提示可繼續販售', async () => {
    const { buyer, seller, buyerToken, book, cabinet } = scene();
    const admin = addAdmin();
    const token = tokenFor(admin);
    const sellerNotice = (order) => notificationsOf(seller.user_id)
      .find((n) => n.related_type === 'order' && n.related_id === order.order_id && n.title !== '書籍已售出');

    addDeposit(book, { days: 1 });
    addCartItem(buyer.user_id, book.book_id);
    const [open] = (await checkout(buyerToken)).body.data;
    const cancelled = await request('PATCH', `/api/orders/${open.order_id}/cancel`, { token, body: { reason: '系統異常' } });
    assert.strictEqual(cancelled.status, 200, cancelled.text);
    assert.strictEqual(sellerNotice(open).content, `訂單 ${open.order_no} 已取消。書櫃中的書籍將繼續販售。原因：系統異常`);
    const buyerNotice = notificationsOf(buyer.user_id).find((n) => n.title === '訂單已取消' && n.related_id === open.order_id);
    assert.strictEqual(buyerNotice.content, `訂單 ${open.order_no} 已取消。原因：系統異常`);

    const pair = ['夜間飛行', '風沙星辰'].map((title) => addBook({ sellerId: seller.user_id, title, price: 80, cabinet_id: cabinet.cabinet_id }));
    for (const b of pair) {
      addDeposit(b, { days: 1 });
      addCartItem(buyer.user_id, b.book_id);
    }
    const [mixed] = (await checkout(buyerToken)).body.data;
    await request('PATCH', `/api/admin/books/${pair[1].book_id}`, { token, body: { status: 'removed', reason: '內容不實' } });
    await request('PATCH', `/api/orders/${mixed.order_id}/cancel`, { token, body: {} });
    assert.strictEqual(bookOf(pair[1].book_id).status, 'removed');
    assert.ok(depositOf(pair[1].book_id));
    assert.strictEqual(sellerNotice(mixed).content,
      `訂單 ${mixed.order_no} 已取消。書櫃中公開販售的書籍將繼續販售；其餘書籍請至書櫃以 App 掃描 QR Code 取回。`);

    const single = addBook({ sellerId: seller.user_id, title: '人類大地', price: 70, cabinet_id: cabinet.cabinet_id });
    addDeposit(single, { days: 1 });
    addCartItem(buyer.user_id, single.book_id);
    const [delisted] = (await checkout(buyerToken)).body.data;
    await request('PATCH', `/api/admin/books/${single.book_id}`, { token, body: { status: 'removed' } });
    const changed = await request('PATCH', `/api/admin/orders/${delisted.order_id}`, { token, body: { status: 'cancelled', note: '賣家來電取消' } });
    assert.strictEqual(changed.status, 200, changed.text);
    const notice = sellerNotice(delisted);
    assert.strictEqual(notice.title, '訂單狀態已更新');
    assert.ok(!notice.content.includes('繼續販售'), notice.content);
    assert.ok(notice.content.includes('書櫃中的書籍目前未公開販售，請至書櫃以 App 掃描 QR Code 取回。說明：賣家來電取消'),
      notice.content);
    const buyerUpdate = notificationsOf(buyer.user_id).find((n) => n.related_id === delisted.order_id && n.title === '訂單狀態已更新');
    assert.ok(!buyerUpdate.content.includes('書櫃中'));
  }],
  ['取消：已取消的訂單再改為已退款時，不為已取回的書重建存書登記', async () => {
    const { buyer, seller, buyerToken, sellerToken, book } = scene();
    addDeposit(book, { days: 1 });
    addCartItem(buyer.user_id, book.book_id);
    const [order] = (await checkout(buyerToken)).body.data;
    assert.strictEqual(order.status, 'deposited');
    const token = tokenFor(addAdmin());
    const change = (status) => request('PATCH', `/api/admin/orders/${order.order_id}`, { token, body: { status, note: '客服調整' } });

    assert.strictEqual((await change('cancelled')).status, 200);
    assert.ok(depositOf(book.book_id));
    assert.strictEqual((await reportAndConfirm(() => retrieveBook(sellerToken, book.book_id))).status, 200);

    const res = await change('refunded');
    assert.strictEqual(res.status, 200, res.text);
    assert.strictEqual(orderOf(order.order_id).status, 'refunded');
    assert.strictEqual(depositOf(book.book_id), undefined);
    assert.strictEqual(bookOf(book.book_id).status, 'on_sale');
    assert.strictEqual(balanceOf(buyer.user_id), 500);
    const detail = await request('GET', `/api/books/${book.book_id}`, { token: buyerToken });
    assert.strictEqual(detail.body.data.in_cabinet, false);
    const updates = notificationsOf(seller.user_id).filter((n) => n.title === '訂單狀態已更新');
    assert.strictEqual(updates.at(-1).content, `訂單 ${order.order_no} 已由客服調整為「已退款」。說明：客服調整`);
  }],

  ['排程：讀取後買家才取書時，逾期未取書不取消訂單也不恢復存書登記', async () => {
    const { buyer, buyerToken, book } = scene();
    addDeposit(book, { days: 1 });
    addCartItem(buyer.user_id, book.book_id);
    const [order] = (await checkout(buyerToken)).body.data;
    orderOf(order.order_id).deposited_at = daysAgo(8);

    beforeNextTransaction(async () => {
      const picked = await reportAndConfirm(() => request('PATCH', `/api/orders/${order.order_id}/status`, {
        token: buyerToken, body: { status: 'picked_up' }
      }));
      assert.strictEqual(picked.status, 200, picked.text);
    });
    assert.strictEqual(await orders.cancelUncollected(), 0);
    assert.strictEqual(orderOf(order.order_id).status, 'deposited');
    assert.ok(orderOf(order.order_id).picked_up_at);
    assert.strictEqual(depositOf(book.book_id), undefined);
    assert.strictEqual(bookOf(book.book_id).status, 'reserved');
    assert.strictEqual(balanceOf(buyer.user_id), 400);
  }],

  ['爭議：已存書未取書的訂單裁決退款後，書恢復存書登記但改為下架，通知賣家取回', async () => {
    const { buyer, seller, buyerToken, sellerToken, book, cabinet } = scene();
    addCartItem(buyer.user_id, book.book_id);
    const [order] = (await checkout(buyerToken)).body.data;
    await reportAndConfirm(() => request('PATCH', `/api/orders/${order.order_id}/status`, { token: sellerToken, body: { status: 'deposited' } }));
    const filed = await request('POST', '/api/disputes', { token: buyerToken, body: { order_id: order.order_id, reason: '書櫃中找不到書籍' } });
    assert.strictEqual(filed.status, 201, filed.text);

    const res = await request('PATCH', `/api/admin/disputes/${filed.body.data.dispute_id}`, {
      token: tokenFor(addAdmin()), body: { result: 'refund_manual', admin_note: '確認書籍不在書櫃' }
    });
    assert.strictEqual(res.status, 200, res.text);
    assert.strictEqual(orderOf(order.order_id).status, 'refunded');
    assert.strictEqual(balanceOf(buyer.user_id), 500);
    assert.strictEqual(depositOf(book.book_id).cabinet_id, cabinet.cabinet_id);
    assert.strictEqual(bookOf(book.book_id).status, 'removed');
    const detail = await request('GET', `/api/books/${book.book_id}`, { token: sellerToken });
    assert.strictEqual(detail.body.data.in_cabinet, false);
    const notice = notificationsOf(seller.user_id).find((n) => n.title === '爭議案件已裁決');
    assert.strictEqual(notice.content,
      `訂單 ${order.order_no} 裁決退款給買家，交易已取消。書櫃中的書籍目前未公開販售，請至書櫃以 App 掃描 QR Code 取回。`);

    const relist = await request('PUT', `/api/books/${book.book_id}`, { token: sellerToken, body: { status: 'on_sale' } });
    assert.strictEqual(relist.body.code, 'RETRIEVAL_REQUIRED');
    const back = await reportAndConfirm(() => retrieveBook(sellerToken, book.book_id));
    assert.strictEqual(back.status, 200, back.text);
    assert.strictEqual(bookOf(book.book_id).status, 'removed');
    assert.strictEqual(depositOf(book.book_id), undefined);
  }],

  ['取回：爭議處理中的訂單書仍在書櫃時提示請勿取回，未存書者維持未登記', async () => {
    const { buyer, seller, buyerToken, sellerToken, book } = scene();
    const other = addCabinet({ name: '公館書櫃' });
    const elsewhere = addBook({ sellerId: seller.user_id, title: '夜間飛行', price: 80, cabinet_id: other.cabinet_id });
    const plain = addBook({ sellerId: seller.user_id, title: '風沙星辰', price: 60, cabinet_id: other.cabinet_id });
    addDeposit(elsewhere, { days: 1 });
    addCartItem(buyer.user_id, book.book_id);
    addCartItem(buyer.user_id, elsewhere.book_id);
    const [stored] = (await checkout(buyerToken)).body.data;
    await reportAndConfirm(() => request('PATCH', `/api/orders/${stored.order_id}/status`, { token: sellerToken, body: { status: 'deposited' } }));
    const waiting = await request('POST', '/api/orders/buy-now', {
      token: buyerToken, headers: verifyHeaders(buyerToken, 'payment'), body: { book_id: plain.book_id }
    });
    assert.strictEqual(waiting.body.data.status, 'pending_deposit');
    for (const order of [stored, waiting.body.data]) {
      const filed = await request('POST', '/api/disputes', { token: buyerToken, body: { order_id: order.order_id, reason: '賣家未依約存書' } });
      assert.strictEqual(filed.status, 201, filed.text);
    }

    for (const b of [book, elsewhere]) {
      const res = await retrieveBook(sellerToken, b.book_id);
      assert.strictEqual(res.status, 409);
      assert.strictEqual(res.body.code, 'BOOK_SOLD_IN_CABINET');
      assert.strictEqual(res.body.message, `此書籍已售出（訂單 ${stored.order_no}），訂單爭議處理中，請勿取回；如已取出，請儘速放回書櫃`);
    }
    const none = await retrieveBook(sellerToken, plain.book_id);
    assert.strictEqual(none.body.code, 'NOT_DEPOSITED');
  }],

  ['取消：恢復存書登記的書上架中但未公開時，通知賣家書籍未公開販售', async () => {
    const { buyer, seller, buyerToken, book } = scene();
    addDeposit(book, { days: 1 });
    addCartItem(buyer.user_id, book.book_id);
    const [order] = (await checkout(buyerToken)).body.data;
    book.is_approved = false;

    const res = await request('PATCH', `/api/orders/${order.order_id}/cancel`, { token: tokenFor(addAdmin()), body: {} });
    assert.strictEqual(res.status, 200, res.text);
    assert.strictEqual(bookOf(book.book_id).status, 'on_sale');
    assert.ok(depositOf(book.book_id));
    assert.strictEqual(notificationsOf(seller.user_id).find((n) => n.title === '訂單已取消').content,
      `訂單 ${order.order_no} 已取消。書櫃中的書籍目前未公開販售，請至書櫃以 App 掃描 QR Code 取回。`);
  }]
];

module.exports = { name: '上架後存書', tests };
