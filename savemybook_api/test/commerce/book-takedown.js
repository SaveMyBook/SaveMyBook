const assert = require('assert');
const {
  request, api, addUser, addAdmin, addBook, addCabinet, addPaidOrder, addReservation, addRoom,
  tokenFor, verifyHeaders, bookOf, orderOf, balanceOf, notificationsOf, logs, prisma, confirmManual,
  enableModeration, stubModeration, pauseModeration
} = require('./harness');

const orders = api('services/orders');
const screening = api('services/listing-screening');

const HOUR = 60 * 60 * 1000;
const hoursAgo = (h) => new Date(Date.now() - h * HOUR);

const scene = ({ price = 100 } = {}) => {
  const seller = addUser({ nickname: '賣家', balance: 0 });
  const buyer = addUser({ nickname: '買家', balance: 500 });
  const admin = addAdmin();
  const book = addBook({ sellerId: seller.user_id, title: '小王子', price });
  return {
    seller, buyer, admin, book, adminToken: tokenFor(admin), sellerToken: tokenFor(seller), buyerToken: tokenFor(buyer)
  };
};

const sell = (ctx, book = ctx.book, { status = 'pending_deposit', ...rest } = {}) => {
  book.status = 'reserved';
  return addPaidOrder({
    buyerId: ctx.buyer.user_id, sellerId: ctx.seller.user_id, bookId: book.book_id, amount: Number(book.price), status, ...rest
  });
};

const addItem = (order, book) => {
  book.status = 'reserved';
  prisma.rows('order_items').push({
    item_id: prisma.nextId('order_items'), order_id: order.order_id, book_id: book.book_id,
    quantity: 1, unit_price: book.price, subtotal: book.price
  });
};

const reportBook = (book) => {
  const row = {
    report_id: prisma.nextId('reports'), reporter_id: addUser({ nickname: '檢舉人' }).user_id, target_type: 'book',
    target_id: book.book_id, reason: '疑似盜版', status: 'pending', admin_id: null, admin_note: null, resolved_at: null, created_at: new Date()
  };
  prisma.rows('reports').push(row);
  return row;
};

const resolveReport = (ctx, report) => request('PATCH', `/api/admin/reports/${report.report_id}`, {
  token: ctx.adminToken, body: { status: 'resolved', remove_target: true }
});

const setStatus = (ctx, book, status, reason) => request('PATCH', `/api/admin/books/${book.book_id}`, {
  token: ctx.adminToken, body: { status, ...(reason && { reason }) }
});

const favorite = (userId, bookId) => prisma.rows('favorites').push({
  favorite_id: prisma.nextId('favorites'), user_id: userId, book_id: bookId, created_at: new Date()
});

const noticesTitled = (userId, title) => notificationsOf(userId).filter((n) => n.title === title);
const relistNotices = (userId) => noticesTitled(userId, '收藏的書籍已可購買');
const detailOf = (log) => JSON.parse(log.detail);

const tests = [
  ['檢舉成立並下架：賣家尚未存書的訂單自動取消並全額退款，通知買賣雙方，書維持下架', async () => {
    const ctx = scene();
    const order = sell(ctx);
    assert.strictEqual(balanceOf(ctx.buyer.user_id), 400);

    const res = await resolveReport(ctx, reportBook(ctx.book));
    assert.strictEqual(res.status, 200, res.text);

    const after = orderOf(order.order_id);
    assert.strictEqual(after.status, 'cancelled');
    assert.strictEqual(after.cancel_reason, '書籍經審核下架');
    assert.strictEqual(balanceOf(ctx.buyer.user_id), 500);
    assert.strictEqual(bookOf(ctx.book.book_id).status, 'removed');
    assert.strictEqual(bookOf(ctx.book.book_id).is_approved, false);

    const [buyerNotice] = noticesTitled(ctx.buyer.user_id, '訂單已取消');
    assert.strictEqual(buyerNotice.content, `訂單 ${order.order_no} 的《小王子》經審核下架，訂單已自動取消，100 代幣已全額退回您的錢包。`);
    assert.strictEqual(buyerNotice.related_type, 'order');
    const [sellerNotice] = noticesTitled(ctx.seller.user_id, '訂單已取消');
    assert.strictEqual(sellerNotice.content, `訂單 ${order.order_no} 的《小王子》經審核下架，訂單已自動取消，款項已全額退還買家。`);
    assert.strictEqual(noticesTitled(ctx.seller.user_id, '檢舉審核結果：違規成立')[0].content, '經審核違規成立，該商品已下架。如有疑問請聯絡客服。');

    const detail = detailOf(logs()[0]);
    assert.ok(detail.summary.includes(`並下架《小王子》，已取消訂單 ${order.order_no} 並全額退款`), detail.summary);
    assert.deepStrictEqual(detail.undo.map((s) => s.model), ['reports'], '訂單已取消，不可還原書籍狀態');

    const relist = await request('PUT', `/api/books/${ctx.book.book_id}`, { token: ctx.sellerToken, body: { status: 'on_sale' } });
    assert.strictEqual(relist.body.code, 'BOOK_NOT_APPROVED');
  }],

  ['管理員強制下架：訂單內其他書籍依一般取消流程恢復販售，被下架的書維持下架', async () => {
    const ctx = scene();
    const other = addBook({ sellerId: ctx.seller.user_id, title: '夜間飛行', price: 80 });
    const order = sell(ctx);
    addItem(order, other);

    const res = await setStatus(ctx, ctx.book, 'removed', '內容不實');
    assert.strictEqual(res.status, 200, res.text);
    assert.strictEqual(orderOf(order.order_id).status, 'cancelled');
    assert.strictEqual(bookOf(ctx.book.book_id).status, 'removed');
    assert.strictEqual(bookOf(other.book_id).status, 'on_sale');
    assert.strictEqual(balanceOf(ctx.buyer.user_id), 500);
    assert.strictEqual(noticesTitled(ctx.seller.user_id, '您的書籍已被下架').length, 1);
    assert.strictEqual(noticesTitled(ctx.seller.user_id, '訂單已取消')[0].content,
      `訂單 ${order.order_no} 的《小王子》經審核下架，訂單已自動取消，款項已全額退還買家。`);

    const log = logs()[0];
    assert.strictEqual(detailOf(log).summary, `下架《小王子》，原因：內容不實，已取消訂單 ${order.order_no} 並全額退款`);
    assert.ok(!detailOf(log).undo, '有訂單的書下架後不提供還原');
  }],

  ['已存書的訂單取消後書恢復存書登記但維持下架，通知賣家取回；取回後不恢復上架', async () => {
    const ctx = scene();
    const cabinet = addCabinet({ name: '台大書櫃' });
    ctx.book.cabinet_id = cabinet.cabinet_id;
    const order = sell(ctx, ctx.book, { status: 'deposited', cabinetId: cabinet.cabinet_id, deposited_at: hoursAgo(2) });
    const fan = addUser();
    favorite(fan.user_id, ctx.book.book_id);

    const res = await resolveReport(ctx, reportBook(ctx.book));
    assert.strictEqual(res.status, 200, res.text);
    assert.strictEqual(orderOf(order.order_id).status, 'cancelled');
    assert.strictEqual(balanceOf(ctx.buyer.user_id), 500);
    const row = prisma.rows('book_deposits').find((r) => r.book_id === ctx.book.book_id);
    assert.strictEqual(row.cabinet_id, cabinet.cabinet_id);
    assert.strictEqual(row.auto_paused, false);
    assert.strictEqual(bookOf(ctx.book.book_id).status, 'removed');
    assert.strictEqual(noticesTitled(ctx.seller.user_id, '訂單已取消')[0].content,
      `訂單 ${order.order_no} 的《小王子》經審核下架，訂單已自動取消，款項已全額退還買家。`
      + '書櫃中的書籍目前未公開販售，請至書櫃以 App 掃描 QR Code 取回。');

    const pending = await request('POST', `/api/books/${ctx.book.book_id}/retrieve`, { token: ctx.sellerToken });
    const confirmed = await confirmManual(pending);
    assert.strictEqual(confirmed.status, 200, confirmed.text);
    assert.strictEqual(prisma.rows('book_deposits').length, 0);
    assert.strictEqual(bookOf(ctx.book.book_id).status, 'removed');
    assert.strictEqual(relistNotices(fan.user_id).length, 0);
  }],

  ['買家已取書與爭議處理中的訂單不自動處理；已完成交易的書維持已完成，只停止公開顯示', async () => {
    const ctx = scene();
    const picked = sell(ctx, ctx.book, { status: 'deposited', deposited_at: hoursAgo(5), picked_up_at: hoursAgo(1) });
    const disputedBook = addBook({ sellerId: ctx.seller.user_id, title: '夜間飛行' });
    const disputed = sell(ctx, disputedBook, { status: 'refunding', deposited_at: hoursAgo(5) });
    const soldBook = addBook({ sellerId: ctx.seller.user_id, title: '風沙星辰', status: 'sold' });
    const completed = addPaidOrder({
      buyerId: ctx.buyer.user_id, sellerId: ctx.seller.user_id, bookId: soldBook.book_id, status: 'completed', completed_at: hoursAgo(3)
    });
    const balance = balanceOf(ctx.buyer.user_id);

    assert.strictEqual((await setStatus(ctx, ctx.book, 'removed')).status, 200);
    assert.strictEqual((await resolveReport(ctx, reportBook(disputedBook))).status, 200);
    assert.strictEqual((await resolveReport(ctx, reportBook(soldBook))).status, 200);
    await orders.runAutomation();

    assert.strictEqual(orderOf(picked.order_id).status, 'deposited');
    assert.strictEqual(orderOf(disputed.order_id).status, 'refunding');
    assert.strictEqual(orderOf(completed.order_id).status, 'completed');
    assert.strictEqual(balanceOf(ctx.buyer.user_id), balance);
    assert.strictEqual(bookOf(ctx.book.book_id).status, 'reserved');
    assert.strictEqual(bookOf(ctx.book.book_id).is_approved, false);
    assert.strictEqual(bookOf(disputedBook.book_id).status, 'removed', '尚未取書的爭議訂單維持原本的下架處理');
    assert.strictEqual(bookOf(soldBook.book_id).status, 'sold');
    assert.strictEqual(bookOf(soldBook.book_id).is_approved, false);
    assert.ok(noticesTitled(ctx.seller.user_id, '檢舉審核結果：違規成立')
      .some((n) => n.content === '經審核違規成立，該商品已停止公開顯示。如有疑問請聯絡客服。'));
    assert.strictEqual(noticesTitled(ctx.buyer.user_id, '訂單已取消').length, 0);

    const blocked = await setStatus(ctx, soldBook, 'removed');
    assert.strictEqual(blocked.status, 409);
    assert.strictEqual(blocked.body.message, '此書籍已完成交易，無法下架');
  }],

  ['待完成訂單的書被強制下架：不改狀態只停止公開顯示，訂單完成時轉為已完成', async () => {
    const ctx = scene();
    const order = sell(ctx, ctx.book, { status: 'deposited', deposited_at: hoursAgo(5), picked_up_at: hoursAgo(1) });

    const res = await setStatus(ctx, ctx.book, 'removed', '內容不實');
    assert.strictEqual(res.status, 200, res.text);
    assert.strictEqual(res.body.message, '已停止公開顯示');
    assert.deepStrictEqual([bookOf(ctx.book.book_id).status, bookOf(ctx.book.book_id).is_approved], ['reserved', false]);
    const [notice] = noticesTitled(ctx.seller.user_id, '您的書籍已停止公開顯示');
    assert.strictEqual(notice.content, '《小王子》已由管理員停止公開顯示。原因：內容不實');
    assert.strictEqual(noticesTitled(ctx.seller.user_id, '您的書籍已被下架').length, 0);
    assert.strictEqual(detailOf(logs()[0]).summary, '停止公開顯示《小王子》，原因：內容不實');

    const listed = await request('GET', '/api/books?status=all', { token: ctx.buyerToken });
    assert.ok(!listed.body.data.some((b) => b.book_id === ctx.book.book_id), '不公開顯示');

    const done = await request('PATCH', `/api/orders/${order.order_id}/status`, { token: ctx.buyerToken, body: { status: 'completed' } });
    assert.strictEqual(done.status, 200, done.text);
    assert.strictEqual(orderOf(order.order_id).status, 'completed');
    assert.deepStrictEqual([bookOf(ctx.book.book_id).status, bookOf(ctx.book.book_id).is_approved], ['sold', false]);
    assert.strictEqual(balanceOf(ctx.seller.user_id), 100);
  }],

  ['爭議處理中（已取書）的書經審核下架：只停止公開顯示；維持原交易時完成，裁決退款時維持下架', async () => {
    const ctx = scene();
    const kept = sell(ctx, ctx.book, { status: 'refunding', deposited_at: hoursAgo(5), picked_up_at: hoursAgo(2) });
    const other = addBook({ sellerId: ctx.seller.user_id, title: '夜間飛行' });
    const refunded = sell(ctx, other, { status: 'refunding', deposited_at: hoursAgo(5), picked_up_at: hoursAgo(2) });
    const dispute = (order) => {
      const row = {
        dispute_id: prisma.nextId('transaction_disputes'), order_id: order.order_id, applicant_id: ctx.buyer.user_id,
        reason: '書況不符', evidence_urls: null, status: 'pending', result: null, admin_id: null, admin_note: null,
        created_at: new Date(), resolved_at: null
      };
      prisma.rows('transaction_disputes').push(row);
      return row;
    };
    const first = dispute(kept);
    const second = dispute(refunded);

    for (const book of [ctx.book, other]) assert.strictEqual((await resolveReport(ctx, reportBook(book))).status, 200);
    for (const book of [ctx.book, other]) {
      assert.deepStrictEqual([bookOf(book.book_id).status, bookOf(book.book_id).is_approved], ['reserved', false]);
    }
    assert.ok(logs().some((l) => detailOf(l).summary.includes('並停止公開顯示《夜間飛行》')));

    const resolve = (row, result) => request('PATCH', `/api/admin/disputes/${row.dispute_id}`, {
      token: ctx.adminToken, body: { result, admin_note: '已查明' }
    });
    assert.strictEqual((await resolve(first, 'dismissed')).status, 200);
    assert.strictEqual(orderOf(kept.order_id).status, 'completed');
    assert.deepStrictEqual([bookOf(ctx.book.book_id).status, bookOf(ctx.book.book_id).is_approved], ['sold', false]);

    assert.strictEqual((await resolve(second, 'refund_manual')).status, 200);
    assert.strictEqual(orderOf(refunded.order_id).status, 'refunded');
    assert.deepStrictEqual([bookOf(other.book_id).status, bookOf(other.book_id).is_approved], ['removed', false]);
  }],

  ['管理員強制下架與檢舉成立一致：賣家不可自行重新上架，管理員恢復上架後解除', async () => {
    const ctx = scene();
    assert.strictEqual((await setStatus(ctx, ctx.book, 'removed')).status, 200);
    assert.deepStrictEqual([bookOf(ctx.book.book_id).status, bookOf(ctx.book.book_id).is_approved], ['removed', false]);

    const edit = (body) => request('PUT', `/api/books/${ctx.book.book_id}`, { token: ctx.sellerToken, body });
    const relist = await edit({ status: 'on_sale' });
    assert.strictEqual(relist.status, 403);
    assert.strictEqual(relist.body.code, 'BOOK_NOT_APPROVED');
    assert.strictEqual(relist.body.message, '此書籍因違規遭下架，無法自行重新上架，請聯絡客服');

    assert.strictEqual((await setStatus(ctx, ctx.book, 'on_sale')).status, 200);
    assert.deepStrictEqual([bookOf(ctx.book.book_id).status, bookOf(ctx.book.book_id).is_approved], ['on_sale', true]);
    assert.strictEqual((await edit({ status: 'removed' })).status, 200);
    assert.strictEqual((await edit({ status: 'on_sale' })).status, 200, '恢復上架後賣家可自行下架再上架');
  }],

  ['上架審核待審中的書被強制下架或檢舉成立下架：審核一併結案，賣家不可自行重新上架，管理員恢復上架時解除', async () => {
    const ctx = scene();
    const pendingReview = (book) => {
      book.is_approved = false;
      prisma.rows('ai_book_reviews').push({ book_id: book.book_id, status: 'pending', verdict: 'review', model: 'gpt', categories: '[]' });
    };
    const reviewOf = (book) => prisma.rows('ai_book_reviews').find((r) => r.book_id === book.book_id);
    const relist = (book) => request('PUT', `/api/books/${book.book_id}`, { token: ctx.sellerToken, body: { status: 'on_sale' } });
    pendingReview(ctx.book);

    const res = await setStatus(ctx, ctx.book, 'removed', '內容不實');
    assert.strictEqual(res.status, 200, res.text);
    assert.deepStrictEqual(res.body.data, { book_id: ctx.book.book_id, hidden: false, status: 'removed', is_approved: false });
    assert.deepStrictEqual([reviewOf(ctx.book).status, reviewOf(ctx.book).reviewed_by], ['rejected', ctx.admin.user_id]);
    const [event] = prisma.rows('ai_review_events').filter((e) => e.book_id === ctx.book.book_id);
    assert.deepStrictEqual([event.actor, event.prior, event.status, event.misjudged], ['admin', 'pending', 'rejected', null]);
    assert.ok(detailOf(logs()[0]).summary.includes('待審的上架審核一併結案'));
    const locked = await relist(ctx.book);
    assert.strictEqual(locked.status, 403);
    assert.strictEqual(locked.body.code, 'BOOK_NOT_APPROVED');

    const restored = await setStatus(ctx, ctx.book, 'on_sale');
    assert.deepStrictEqual(restored.body.data, { book_id: ctx.book.book_id, hidden: false, status: 'on_sale', is_approved: true });
    assert.strictEqual(reviewOf(ctx.book).status, 'approved');
    assert.strictEqual(bookOf(ctx.book.book_id).is_approved, true);
    assert.strictEqual((await request('PUT', `/api/books/${ctx.book.book_id}`, { token: ctx.sellerToken, body: { status: 'removed' } })).status, 200);
    assert.strictEqual((await relist(ctx.book)).status, 200, '恢復上架後賣家可自行下架再上架');

    const reported = addBook({ sellerId: ctx.seller.user_id, title: '夜間飛行' });
    pendingReview(reported);
    const report = reportBook(reported);
    assert.strictEqual((await resolveReport(ctx, report)).status, 200);
    assert.strictEqual(reviewOf(reported).status, 'rejected');
    report.status = 'dismissed';
    assert.strictEqual((await relist(reported)).body.code, 'BOOK_NOT_APPROVED', '檢舉狀態之後變更仍維持鎖定');
  }],

  ['管理員以書籍 API 下架：立即取消訂單並退款、取消預約並鎖定；已完成交易的書不可下架', async () => {
    const ctx = scene();
    const order = sell(ctx);
    const viaDelete = addBook({ sellerId: ctx.seller.user_id, title: '夜間飛行' });
    const holder = addUser({ nickname: '乙' });
    const hold = addReservation({ bookId: viaDelete.book_id, buyerId: holder.user_id, sellerId: ctx.seller.user_id, status: 'confirmed' });
    const soldBook = addBook({ sellerId: ctx.seller.user_id, title: '風沙星辰', status: 'sold' });

    const put = await request('PUT', `/api/books/${ctx.book.book_id}`, { token: ctx.adminToken, body: { status: 'removed', price: 90 } });
    assert.strictEqual(put.status, 200, put.text);
    assert.strictEqual(put.body.data.status, 'removed');
    assert.strictEqual(orderOf(order.order_id).status, 'cancelled');
    assert.strictEqual(balanceOf(ctx.buyer.user_id), 500);
    assert.deepStrictEqual([bookOf(ctx.book.book_id).status, bookOf(ctx.book.book_id).is_approved, Number(bookOf(ctx.book.book_id).price)],
      ['removed', false, 90]);
    assert.strictEqual(noticesTitled(ctx.seller.user_id, '您的書籍已被下架').length, 1);
    assert.strictEqual(logs()[0].action, '強制下架書籍');

    const del = await request('DELETE', `/api/books/${viaDelete.book_id}`, { token: ctx.adminToken });
    assert.strictEqual(del.status, 200, del.text);
    assert.strictEqual(del.body.message, '書籍已取消上架');
    assert.deepStrictEqual([bookOf(viaDelete.book_id).status, bookOf(viaDelete.book_id).is_approved], ['removed', false]);
    assert.strictEqual(hold.status, 'cancelled');
    assert.strictEqual(noticesTitled(holder.user_id, '預約已取消').length, 1);

    for (const res of [
      await request('PUT', `/api/books/${soldBook.book_id}`, { token: ctx.adminToken, body: { status: 'removed' } }),
      await request('DELETE', `/api/books/${soldBook.book_id}`, { token: ctx.adminToken })
    ]) {
      assert.strictEqual(res.status, 409, res.text);
      assert.strictEqual(res.body.message, '此書籍已完成交易，無法下架');
    }
    assert.deepStrictEqual([bookOf(soldBook.book_id).status, bookOf(soldBook.book_id).is_approved], ['sold', true]);

    const pickedBook = addBook({ sellerId: ctx.seller.user_id, title: '人類大歷史' });
    const picked = sell(ctx, pickedBook, { status: 'deposited', deposited_at: hoursAgo(5), picked_up_at: hoursAgo(1) });
    const hidden = await request('DELETE', `/api/books/${pickedBook.book_id}`, { token: ctx.adminToken });
    assert.strictEqual(hidden.status, 200, hidden.text);
    assert.strictEqual(hidden.body.message, '已停止公開顯示');
    assert.deepStrictEqual([bookOf(pickedBook.book_id).status, bookOf(pickedBook.book_id).is_approved], ['reserved', false]);
    assert.strictEqual(orderOf(picked.order_id).status, 'deposited');
  }],

  ['進行中的預約（待回覆、保留中）一律取消並通知買家，已過期的保留不處理', async () => {
    const ctx = scene();
    const [waiting, holder, lapsed] = ['甲', '乙', '丙'].map((nickname) => addUser({ nickname }));
    const room = addRoom(holder.user_id, ctx.seller.user_id);
    const reservation = (buyer, status, extra = {}) => addReservation({
      bookId: ctx.book.book_id, buyerId: buyer.user_id, sellerId: ctx.seller.user_id, status, ...extra
    });
    const pending = reservation(waiting, 'pending');
    const holding = reservation(holder, 'confirmed');
    const expired = reservation(lapsed, 'confirmed', { deadline: hoursAgo(1) });

    const res = await setStatus(ctx, ctx.book, 'removed');
    assert.strictEqual(res.status, 200, res.text);
    assert.strictEqual(pending.status, 'cancelled');
    assert.strictEqual(holding.status, 'cancelled');
    assert.strictEqual(expired.status, 'confirmed');
    assert.deepStrictEqual(
      [JSON.parse(holding.note).closed_by, JSON.parse(holding.note).action], ['system', 'delisted']
    );

    const [first] = noticesTitled(waiting.user_id, '預約已取消');
    assert.strictEqual(first.content, '《小王子》已下架，您的預約已取消。');
    assert.strictEqual(first.type, 'reservation');
    const [second] = noticesTitled(holder.user_id, '預約已取消');
    assert.strictEqual(second.related_type, 'chat_room');
    assert.strictEqual(second.related_id, room.room_id);
    assert.strictEqual(notificationsOf(lapsed.user_id).length, 0);
  }],

  ['背景審核判定拒絕：審核期間成立的訂單一併取消並退款', async () => {
    const ctx = scene();
    enableModeration({ action: 'block' });
    stubModeration({ verdict: 'reject', confidence: 0.95, reasons: ['非書籍商品'], categories: ['not_book'] });
    const release = pauseModeration();

    const created = await request('POST', '/api/books', { token: ctx.sellerToken, body: { title: '限量周邊', price: 200 } });
    assert.strictEqual(created.status, 201, created.text);
    const bookId = created.body.data.book_id;
    const bought = await request('POST', '/api/orders/buy-now', {
      token: ctx.buyerToken, headers: verifyHeaders(ctx.buyerToken, 'payment'), body: { book_id: bookId }
    });
    assert.strictEqual(bought.status, 201, bought.text);
    assert.strictEqual(balanceOf(ctx.buyer.user_id), 300);

    release();
    await screening.settled();
    assert.strictEqual(bookOf(bookId).status, 'removed');
    assert.strictEqual(bookOf(bookId).is_approved, false);
    assert.strictEqual(orderOf(bought.body.data.order_id).status, 'cancelled');
    assert.strictEqual(balanceOf(ctx.buyer.user_id), 500);
    assert.strictEqual(noticesTitled(ctx.seller.user_id, '書籍未通過上架審核').length, 1);
    assert.strictEqual(noticesTitled(ctx.buyer.user_id, '訂單已取消')[0].content,
      `訂單 ${bought.body.data.order_no} 的《限量周邊》經審核下架，訂單已自動取消，200 代幣已全額退回您的錢包。`);
  }],

  ['管理員拒絕上架審核：已售出而送審的書下架，訂單取消並退款', async () => {
    const ctx = scene();
    const order = sell(ctx);
    ctx.book.is_approved = false;
    prisma.rows('ai_book_reviews').push({ book_id: ctx.book.book_id, status: 'pending', verdict: 'review' });

    const res = await request('PATCH', `/api/admin/ai/reviews/${ctx.book.book_id}`, {
      token: ctx.adminToken, body: { decision: 'reject', note: '疑似盜版' }
    });
    assert.strictEqual(res.status, 200, res.text);
    assert.strictEqual(bookOf(ctx.book.book_id).status, 'removed');
    assert.strictEqual(orderOf(order.order_id).status, 'cancelled');
    assert.strictEqual(balanceOf(ctx.buyer.user_id), 500);
    assert.ok(detailOf(logs()[0]).summary.endsWith(`已取消訂單 ${order.order_no} 並全額退款`));
  }],

  ['排程：已下架但仍有未取書訂單的書（例如先前未處理的資料）由排程取消並退款', async () => {
    const ctx = scene();
    const order = sell(ctx);
    ctx.book.status = 'removed';

    const result = await orders.runAutomation();
    assert.strictEqual(result.delisted, 1);
    assert.strictEqual(orderOf(order.order_id).status, 'cancelled');
    assert.strictEqual(balanceOf(ctx.buyer.user_id), 500);
    assert.strictEqual((await orders.runAutomation()).delisted, 0);
  }],

  ['下架的書仍有進行中的訂單時，管理員、賣家與審核核准都不可恢復上架', async () => {
    const ctx = scene();
    sell(ctx);
    Object.assign(ctx.book, { status: 'removed', is_approved: false });
    prisma.rows('ai_book_reviews').push({ book_id: ctx.book.book_id, status: 'rejected', verdict: 'reject' });

    const expectBlocked = (res) => {
      assert.strictEqual(res.status, 409, res.text);
      assert.strictEqual(res.body.code, 'BOOK_HAS_OPEN_ORDER');
      assert.strictEqual(res.body.message, '此書籍尚有進行中的訂單，無法重新上架');
    };
    expectBlocked(await setStatus(ctx, ctx.book, 'on_sale'));
    expectBlocked(await request('PATCH', `/api/admin/ai/reviews/${ctx.book.book_id}`, {
      token: ctx.adminToken, body: { decision: 'approve' }
    }));
    ctx.book.is_approved = true;
    prisma.store.ai_book_reviews = [];
    expectBlocked(await request('PUT', `/api/books/${ctx.book.book_id}`, { token: ctx.sellerToken, body: { status: 'on_sale' } }));
    assert.strictEqual(bookOf(ctx.book.book_id).status, 'removed');
  }],

  ['收藏通知：賣家重新上架、管理員恢復上架與審核核准時通知收藏者（不含賣家），狀態未改變時不重複通知', async () => {
    const ctx = scene();
    const fan = addUser();
    favorite(fan.user_id, ctx.book.book_id);
    favorite(ctx.seller.user_id, ctx.book.book_id);
    const edit = (body) => request('PUT', `/api/books/${ctx.book.book_id}`, { token: ctx.sellerToken, body });

    assert.strictEqual((await edit({ status: 'removed' })).status, 200);
    assert.strictEqual((await edit({ status: 'on_sale' })).status, 200);
    const [notice] = relistNotices(fan.user_id);
    assert.strictEqual(notice.content, '《小王子》已重新上架，現已開放購買。');
    assert.strictEqual(notice.related_type, 'book');
    assert.strictEqual(notice.related_id, ctx.book.book_id);
    assert.strictEqual(relistNotices(ctx.seller.user_id).length, 0);

    await edit({ status: 'on_sale' });
    await edit({ price: 90 });
    await setStatus(ctx, ctx.book, 'on_sale');
    assert.strictEqual(relistNotices(fan.user_id).length, 1);

    await setStatus(ctx, ctx.book, 'removed');
    await setStatus(ctx, ctx.book, 'on_sale');
    assert.strictEqual(relistNotices(fan.user_id).length, 2);

    ctx.book.is_approved = false;
    prisma.rows('ai_book_reviews').push({ book_id: ctx.book.book_id, status: 'pending', verdict: 'review' });
    const approved = await request('PATCH', `/api/admin/ai/reviews/${ctx.book.book_id}`, {
      token: ctx.adminToken, body: { decision: 'approve' }
    });
    assert.strictEqual(approved.status, 200, approved.text);
    assert.strictEqual(relistNotices(fan.user_id).length, 3);
  }],

  ['收藏通知：等待審核而未公開時、仍被他人預約保留時不通知', async () => {
    const ctx = scene();
    const fan = addUser();
    favorite(fan.user_id, ctx.book.book_id);
    Object.assign(ctx.book, { status: 'removed', is_approved: false });
    prisma.rows('ai_book_reviews').push({ book_id: ctx.book.book_id, status: 'pending', verdict: 'review' });

    const relist = await request('PUT', `/api/books/${ctx.book.book_id}`, { token: ctx.sellerToken, body: { status: 'on_sale' } });
    assert.strictEqual(relist.status, 200, relist.text);
    assert.strictEqual(relistNotices(fan.user_id).length, 0);

    const held = addBook({ sellerId: ctx.seller.user_id, title: '夜間飛行', status: 'removed' });
    favorite(fan.user_id, held.book_id);
    addReservation({ bookId: held.book_id, buyerId: addUser().user_id, sellerId: ctx.seller.user_id, status: 'confirmed' });
    assert.strictEqual((await setStatus(ctx, held, 'on_sale')).status, 200);
    assert.strictEqual(relistNotices(fan.user_id).length, 0);
  }],

  ['收藏通知：逾期暫停販售的存書取回後自動恢復上架時通知；取回販售中的書不通知', async () => {
    const ctx = scene();
    const cabinet = addCabinet({ name: '台大書櫃' });
    const fan = addUser();
    const paused = addBook({ sellerId: ctx.seller.user_id, title: '夜間飛行', status: 'removed', cabinet_id: cabinet.cabinet_id });
    const listed = addBook({ sellerId: ctx.seller.user_id, title: '風沙星辰', cabinet_id: cabinet.cabinet_id });
    const deposit = (book, extra) => prisma.rows('book_deposits').push({
      book_id: book.book_id, cabinet_id: cabinet.cabinet_id, deposited_at: hoursAgo(24 * 40), paused_at: null,
      auto_paused: false, reminded_at: null, escalated_at: null, ...extra
    });
    deposit(paused, { paused_at: hoursAgo(24), reminded_at: hoursAgo(24), auto_paused: true });
    deposit(listed);
    for (const book of [paused, listed]) favorite(fan.user_id, book.book_id);

    for (const book of [paused, listed]) {
      const pending = await request('POST', `/api/books/${book.book_id}/retrieve`, { token: ctx.sellerToken });
      assert.strictEqual((await confirmManual(pending)).status, 200);
      assert.strictEqual(bookOf(book.book_id).status, 'on_sale');
    }
    const notices = relistNotices(fan.user_id);
    assert.deepStrictEqual(notices.map((n) => n.related_id), [paused.book_id]);
    assert.strictEqual(notices[0].content, '《夜間飛行》已重新上架，現已開放購買。');
  }]
];

module.exports = { name: '書籍下架的訂單與預約處理、收藏重新上架通知', tests };
