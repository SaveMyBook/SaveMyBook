const assert = require('assert');
const {
  request, addUser, addAdmin, addBook, addTicket, addPaidOrder, tokenFor,
  bookOf, orderOf, balanceOf, notificationsOf, transactionsOf, logs, prisma
} = require('./harness');

const ticketBody = (overrides = {}) => ({ subject: '無法登入', content: '密碼一直錯誤', ...overrides });

const tests = [
  ['建立工單的欄位驗證', async () => {
    const token = tokenFor(addUser());

    const noSubject = await request('POST', '/api/support/tickets', { token, body: ticketBody({ subject: '' }) });
    assert.strictEqual(noSubject.status, 400);
    assert.strictEqual(noSubject.body.message, '請填寫問題主旨');

    const longSubject = await request('POST', '/api/support/tickets', {
      token, body: ticketBody({ subject: '主'.repeat(101) })
    });
    assert.strictEqual(longSubject.status, 400);
    assert.strictEqual(longSubject.body.message, '主旨不可超過 100 字');

    const noContent = await request('POST', '/api/support/tickets', { token, body: ticketBody({ content: '' }) });
    assert.strictEqual(noContent.status, 400);
    assert.strictEqual(noContent.body.message, '請描述您遇到的問題');
  }],

  ['建立工單會通知具客服權限的管理員', async () => {
    const user = addUser();
    const staff = addAdmin();
    const otherAdmin = addAdmin({ can_manage_support: false });

    const res = await request('POST', '/api/support/tickets', {
      token: tokenFor(user), body: ticketBody({ category: 'trade' })
    });
    assert.strictEqual(res.status, 201);
    const ticketId = res.body.data.ticket_id;
    assert.ok(ticketId);

    const ticket = prisma.rows('support_tickets')[0];
    assert.strictEqual(ticket.status, 'open');
    assert.strictEqual(ticket.category, 'trade');
    assert.strictEqual(prisma.rows('support_ticket_messages').length, 1);
    assert.strictEqual(prisma.rows('support_ticket_messages')[0].is_staff, false);

    const notice = notificationsOf(staff.user_id)[0];
    assert.strictEqual(notice.title, '新的客服工單');
    assert.strictEqual(notice.content, '「無法登入」等待處理。');
    assert.strictEqual(notice.related_type, 'admin_ticket');
    assert.strictEqual(notice.related_id, ticketId);
    assert.strictEqual(notificationsOf(otherAdmin.user_id).length, 0);
  }],

  ['處理中的工單最多 5 張', async () => {
    const user = addUser();
    for (let i = 0; i < 5; i += 1) addTicket({ userId: user.user_id, status: i % 2 ? 'pending' : 'open' });

    const res = await request('POST', '/api/support/tickets', { token: tokenFor(user), body: ticketBody() });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.message, '您已有 5 則處理中的提問，請待客服回覆後再提出新問題');
  }],

  ['使用者回覆工單會通知客服並讓工單回到待處理', async () => {
    const user = addUser();
    const staff = addAdmin();
    const ticket = addTicket({ userId: user.user_id, status: 'pending' });

    const res = await request('POST', `/api/support/tickets/${ticket.ticket_id}/messages`, {
      token: tokenFor(user), body: { content: '還是不行' }
    });
    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.message, '已送出');
    assert.strictEqual(prisma.rows('support_tickets')[0].status, 'open');
    assert.strictEqual(prisma.rows('support_ticket_messages')[0].is_staff, false);

    const notice = notificationsOf(staff.user_id)[0];
    assert.strictEqual(notice.title, '客服工單有新回覆');
    assert.strictEqual(notice.content, '工單「無法登入」有新的回覆。');
  }],

  ['客服回覆工單會通知使用者並改為等待回覆', async () => {
    const user = addUser();
    const staff = addAdmin();
    const ticket = addTicket({ userId: user.user_id });

    const res = await request('POST', `/api/support/tickets/${ticket.ticket_id}/messages`, {
      token: tokenFor(staff), body: { content: '請先重設密碼' }
    });
    assert.strictEqual(res.status, 201);
    assert.strictEqual(prisma.rows('support_tickets')[0].status, 'pending');
    assert.strictEqual(prisma.rows('support_ticket_messages')[0].is_staff, true);

    const notice = notificationsOf(user.user_id)[0];
    assert.strictEqual(notice.title, '客服已回覆您的問題');
    assert.strictEqual(notice.content, '您的提問「無法登入」有新的回覆。');
    assert.strictEqual(notice.related_type, 'ticket');
  }],

  ['已結案的工單不可再回覆，內容也不可為空', async () => {
    const user = addUser();
    const open = addTicket({ userId: user.user_id });
    const closed = addTicket({ userId: user.user_id, status: 'closed' });
    const token = tokenFor(user);

    const empty = await request('POST', `/api/support/tickets/${open.ticket_id}/messages`, {
      token, body: { content: '   ' }
    });
    assert.strictEqual(empty.status, 400);
    assert.strictEqual(empty.body.message, '請輸入內容');

    const res = await request('POST', `/api/support/tickets/${closed.ticket_id}/messages`, {
      token, body: { content: '再問一次' }
    });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.message, '此提問已結案，請提出新問題');
  }],

  ['工單僅限本人與客服檢視', async () => {
    const user = addUser();
    const stranger = addUser();
    const staff = addAdmin();
    const noSupport = addAdmin({ can_manage_support: false });
    const ticket = addTicket({ userId: user.user_id });

    const mine = await request('GET', `/api/support/tickets/${ticket.ticket_id}`, { token: tokenFor(user) });
    assert.strictEqual(mine.status, 200);
    assert.strictEqual(mine.body.data.subject, '無法登入');

    const byStaff = await request('GET', `/api/support/tickets/${ticket.ticket_id}`, { token: tokenFor(staff) });
    assert.strictEqual(byStaff.status, 200);
    assert.strictEqual(byStaff.body.data.from_ai_support, false);
    assert.strictEqual(mine.body.data.from_ai_support, undefined, '使用者端不提供工單來源');
    prisma.rows('ai_support_sessions').push({ session_id: 1, user_id: user.user_id, status: 'escalated', ticket_id: ticket.ticket_id });
    const escalated = await request('GET', `/api/support/tickets/${ticket.ticket_id}`, { token: tokenFor(staff) });
    assert.strictEqual(escalated.body.data.from_ai_support, true);

    const handoff = addTicket({ userId: user.user_id, subject: 'AI 客服轉接：取書期限' });
    prisma.rows('support_tickets').find((t) => t.ticket_id === handoff.ticket_id).from_ai_support = true;
    const afterPurge = await request('GET', `/api/support/tickets/${handoff.ticket_id}`, { token: tokenFor(staff) });
    assert.strictEqual(afterPurge.body.data.from_ai_support, true, 'AI 對話刪除後仍依工單標記判斷');

    for (const user2 of [stranger, noSupport]) {
      const res = await request('GET', `/api/support/tickets/${ticket.ticket_id}`, { token: tokenFor(user2) });
      assert.strictEqual(res.status, 403);
      assert.strictEqual(res.body.message, '無權限執行此操作');
    }

    const missing = await request('GET', '/api/support/tickets/9999', { token: tokenFor(user) });
    assert.strictEqual(missing.status, 404);
    assert.strictEqual(missing.body.message, '找不到此提問');
  }],

  ['使用者可自行結案，客服調整狀態會通知使用者並留下紀錄', async () => {
    const user = addUser();
    const staff = addAdmin();
    const ticket = addTicket({ userId: user.user_id });

    const closed = await request('PATCH', `/api/support/tickets/${ticket.ticket_id}/close`, { token: tokenFor(user) });
    assert.strictEqual(closed.status, 200);
    assert.strictEqual(closed.body.message, '問題已結案');
    assert.strictEqual(prisma.rows('support_tickets')[0].status, 'closed');

    const res = await request('PATCH', `/api/admin/tickets/${ticket.ticket_id}/status`, {
      token: tokenFor(staff), body: { status: 'resolved' }
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(prisma.rows('support_tickets')[0].status, 'resolved');

    const notice = notificationsOf(user.user_id).find((n) => n.title === '提問狀態更新');
    assert.strictEqual(notice.content, '您的提問「無法登入」已更新為「已解決」。');
    assert.strictEqual(logs()[0].action, '調整工單狀態');
  }],

  ['客服工單列表', async () => {
    const user = addUser();
    const staff = addAdmin();
    addTicket({ userId: user.user_id });
    addTicket({ userId: user.user_id, subject: '退款問題', status: 'closed' });

    const mine = await request('GET', '/api/support/tickets', { token: tokenFor(user) });
    assert.strictEqual(mine.status, 200);
    assert.strictEqual(mine.body.data.length, 2);

    const all = await request('GET', '/api/admin/tickets?status=closed', { token: tokenFor(staff) });
    assert.strictEqual(all.status, 200);
    assert.strictEqual(all.body.data.length, 1);
    assert.strictEqual(all.body.data[0].subject, '退款問題');
    assert.strictEqual(all.body.data[0].user.user_id, user.user_id);
  }],

  ['檢舉的欄位驗證', async () => {
    const user = addUser();
    const token = tokenFor(user);

    const badType = await request('POST', '/api/reports', { token, body: { target_type: 'order', target_id: 1, reason: 'x' } });
    assert.strictEqual(badType.status, 400);
    assert.strictEqual(badType.body.message, '檢舉類型不正確');

    const noTarget = await request('POST', '/api/reports', { token, body: { target_type: 'book', reason: 'x' } });
    assert.strictEqual(noTarget.status, 400);
    assert.strictEqual(noTarget.body.message, '請指定檢舉對象');

    const noReason = await request('POST', '/api/reports', { token, body: { target_type: 'book', target_id: 1, reason: '' } });
    assert.strictEqual(noReason.status, 400);
    assert.strictEqual(noReason.body.message, '請填寫檢舉原因');

    const badEvidence = await request('POST', '/api/reports', {
      token, body: { target_type: 'book', target_id: 1, reason: 'x', evidence_urls: ['javascript:alert(1)'] }
    });
    assert.strictEqual(badEvidence.status, 400);
    assert.strictEqual(badEvidence.body.message, '佐證連結格式不正確');
  }],

  ['不可檢舉自己的書籍或自己的帳號', async () => {
    const user = addUser();
    const book = addBook({ sellerId: user.user_id });
    const token = tokenFor(user);

    const ownBook = await request('POST', '/api/reports', {
      token, body: { target_type: 'book', target_id: book.book_id, reason: '測試' }
    });
    assert.strictEqual(ownBook.status, 400);
    assert.strictEqual(ownBook.body.message, '無法檢舉自己上架的商品');

    const self = await request('POST', '/api/reports', {
      token, body: { target_type: 'user', target_id: user.user_id, reason: '測試' }
    });
    assert.strictEqual(self.status, 400);
    assert.strictEqual(self.body.message, '無法檢舉自己');

    const missing = await request('POST', '/api/reports', {
      token, body: { target_type: 'book', target_id: 9999, reason: '測試' }
    });
    assert.strictEqual(missing.status, 404);
    assert.strictEqual(missing.body.message, '找不到該書籍');
  }],

  ['送出檢舉會通知賣家，重複檢舉會被擋下', async () => {
    const reporter = addUser();
    const seller = addUser();
    const book = addBook({ sellerId: seller.user_id, title: '小王子' });
    const token = tokenFor(reporter);
    const body = { target_type: 'book', target_id: book.book_id, reason: '盜版書' };

    const res = await request('POST', '/api/reports', { token, body });
    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.message, '檢舉已送出');
    assert.strictEqual(res.body.data.status, 'pending');

    const notice = notificationsOf(seller.user_id)[0];
    assert.strictEqual(notice.title, '您的商品遭到檢舉');
    assert.strictEqual(
      notice.content,
      '此商品已被檢舉，審核期間仍可正常販售；如違規成立將另行通知。'
    );
    assert.strictEqual(bookOf(book.book_id).status, 'on_sale');

    const again = await request('POST', '/api/reports', { token, body });
    assert.strictEqual(again.status, 409);
    assert.strictEqual(again.body.message, '此項目已檢舉，目前處理中');

    const mine = await request('GET', '/api/reports', { token });
    assert.strictEqual(mine.body.data.length, 1);

    const againstMe = await request('GET', '/api/reports/against-me', { token: tokenFor(seller) });
    assert.strictEqual(againstMe.body.data.length, 1);
    assert.strictEqual(againstMe.body.data[0].target_id, book.book_id);
  }],

  ['檢舉成立並下架商品時通知雙方並記錄操作', async () => {
    const reporter = addUser();
    const seller = addUser();
    const admin = addAdmin();
    const book = addBook({ sellerId: seller.user_id, title: '小王子' });
    prisma.rows('reports').push({
      report_id: 1, reporter_id: reporter.user_id, target_type: 'book', target_id: book.book_id,
      reason: '盜版書', status: 'pending', admin_id: null, admin_note: null, resolved_at: null, created_at: new Date()
    });

    const res = await request('PATCH', '/api/admin/reports/1', {
      token: tokenFor(admin), body: { status: 'resolved', admin_note: '確認盜版', remove_target: true }
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.message, '檢舉已處理');
    assert.strictEqual(res.body.data.status, 'resolved');
    assert.ok(res.body.data.resolved_at);

    assert.strictEqual(bookOf(book.book_id).status, 'removed');
    assert.strictEqual(bookOf(book.book_id).is_approved, false);

    const reporterNotice = notificationsOf(reporter.user_id)[0];
    assert.strictEqual(reporterNotice.title, '您的檢舉已處理');
    assert.strictEqual(reporterNotice.content, '檢舉已處理完成。');

    const sellerNotice = notificationsOf(seller.user_id)[0];
    assert.strictEqual(sellerNotice.title, '檢舉審核結果：違規成立');
    assert.strictEqual(sellerNotice.content, '經審核違規成立，該商品已下架。如有疑問請聯絡客服。');

    const log = logs()[0];
    assert.strictEqual(log.action, '處理檢舉');
    assert.ok(JSON.parse(log.detail).summary.includes('並下架《小王子》'));

    const again = await request('PATCH', '/api/admin/reports/1', {
      token: tokenFor(admin), body: { status: 'resolved' }
    });
    assert.strictEqual(again.status, 409);
    assert.strictEqual(again.body.message, '此檢舉已處理');
  }],

  ['檢舉不成立時商品不受影響', async () => {
    const reporter = addUser();
    const seller = addUser();
    const admin = addAdmin();
    const book = addBook({ sellerId: seller.user_id });
    prisma.rows('reports').push({
      report_id: 1, reporter_id: reporter.user_id, target_type: 'book', target_id: book.book_id,
      reason: '亂檢舉', status: 'pending', admin_id: null, admin_note: null, resolved_at: null, created_at: new Date()
    });

    const res = await request('PATCH', '/api/admin/reports/1', {
      token: tokenFor(admin), body: { status: 'dismissed' }
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(bookOf(book.book_id).status, 'on_sale');
    assert.strictEqual(notificationsOf(reporter.user_id)[0].content, '經審核未違反社群規範。');
    assert.strictEqual(notificationsOf(seller.user_id)[0].title, '檢舉審核結果：已駁回');
    assert.strictEqual(notificationsOf(seller.user_id)[0].content, '經審核未違反社群規範，此商品不受影響。');

    const list = await request('GET', '/api/admin/reports?status=dismissed', { token: tokenFor(admin) });
    assert.strictEqual(list.status, 200);
    assert.strictEqual(list.body.data.length, 1);
    assert.strictEqual(list.body.data[0].target.book_id, book.book_id);
  }],

  ['檢舉帳號時，被檢舉者收到的通知以帳號描述', async () => {
    const reporter = addUser();
    const target = addUser();
    const admin = addAdmin();

    const res = await request('POST', '/api/reports', {
      token: tokenFor(reporter), body: { target_type: 'user', target_id: target.user_id, reason: '騷擾' }
    });
    assert.strictEqual(res.status, 201);
    const [created] = notificationsOf(target.user_id);
    assert.strictEqual(created.title, '您的帳號遭到檢舉');
    assert.strictEqual(created.content, '此帳號已被檢舉，目前審核中；如違規成立將另行通知。');

    const reviewed = await request('PATCH', `/api/admin/reports/${res.body.data.report_id}`, {
      token: tokenFor(admin), body: { status: 'dismissed' }
    });
    assert.strictEqual(reviewed.status, 200);
    const dismissed = notificationsOf(target.user_id).find((n) => n.title === '檢舉審核結果：已駁回');
    assert.strictEqual(dismissed.content, '經審核未違反社群規範，此帳號不受影響。');
  }],

  ['提出爭議的權限與狀態限制', async () => {
    const buyer = addUser({ balance: 500 });
    const seller = addUser({ balance: 0 });
    const stranger = addUser();
    const book = addBook({ sellerId: seller.user_id });
    const order = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id });
    const cancelled = addPaidOrder({
      buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, status: 'cancelled'
    });

    const missing = await request('POST', '/api/disputes', {
      token: tokenFor(buyer), body: { order_id: 9999, reason: '沒收到書' }
    });
    assert.strictEqual(missing.status, 404);
    assert.strictEqual(missing.body.message, '找不到該訂單');

    const denied = await request('POST', '/api/disputes', {
      token: tokenFor(stranger), body: { order_id: order.order_id, reason: '沒收到書' }
    });
    assert.strictEqual(denied.status, 403);

    const noReason = await request('POST', '/api/disputes', {
      token: tokenFor(buyer), body: { order_id: order.order_id, reason: '' }
    });
    assert.strictEqual(noReason.status, 400);
    assert.strictEqual(noReason.body.message, '請填寫爭議說明');

    const closed = await request('POST', '/api/disputes', {
      token: tokenFor(buyer), body: { order_id: cancelled.order_id, reason: '沒收到書' }
    });
    assert.strictEqual(closed.status, 400);
    assert.strictEqual(closed.body.message, '此訂單已取消或已退款，無法申請爭議');
  }],

  ['以訂單編號提出爭議，編號不分大小寫並忽略空白', async () => {
    const buyer = addUser({ balance: 500 });
    const seller = addUser({ balance: 0 });
    const stranger = addUser();
    const book = addBook({ sellerId: seller.user_id });
    const order = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, status: 'deposited' });
    const file = (token, body) => request('POST', '/api/disputes', { token, body: { reason: '書況與描述不符', ...body } });

    const none = await file(tokenFor(buyer), {});
    assert.strictEqual(none.status, 400);
    assert.strictEqual(none.body.message, '請指定訂單');

    const unknown = await file(tokenFor(buyer), { order_no: 'SMB999999' });
    assert.strictEqual(unknown.status, 404);
    assert.strictEqual(unknown.body.message, '找不到該訂單');

    const denied = await file(tokenFor(stranger), { order_no: order.order_no });
    assert.strictEqual(denied.status, 403);

    const res = await file(tokenFor(buyer), { order_no: ` ${order.order_no.toLowerCase()} ` });
    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.data.order_id, order.order_id);
    assert.strictEqual(orderOf(order.order_id).status, 'refunding');
  }],

  ['取書後超過 24 小時或訂單已完成不可提出爭議，期限內與取書前皆可', async () => {
    const buyer = addUser({ balance: 500 });
    const seller = addUser({ balance: 0 });
    const book = addBook({ sellerId: seller.user_id });
    const hoursAgo = (h) => new Date(Date.now() - h * 60 * 60 * 1000);
    const dispute = (order, reason = '書況與描述不符') => request('POST', '/api/disputes', {
      token: tokenFor(buyer), body: { order_id: order.order_id, reason }
    });

    const late = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, status: 'deposited' });
    Object.assign(late, { picked_up_at: hoursAgo(25) });
    const expired = await dispute(late);
    assert.strictEqual(expired.status, 400);
    assert.strictEqual(expired.body.code, 'DISPUTE_WINDOW_PASSED');
    assert.strictEqual(expired.body.message, '已超過取書後 24 小時的爭議申請期限');
    assert.strictEqual(late.status, 'deposited', '被拒絕時不得變更訂單狀態');

    const done = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, status: 'completed' });
    Object.assign(done, { picked_up_at: hoursAgo(1), completed_at: hoursAgo(1) });
    const completed = await dispute(done);
    assert.strictEqual(completed.status, 400);
    assert.strictEqual(completed.body.message, '訂單已完成，無法再申請爭議');

    const recent = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, status: 'deposited' });
    Object.assign(recent, { picked_up_at: hoursAgo(23) });
    assert.strictEqual((await dispute(recent)).status, 201);

    const waiting = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, status: 'pending_deposit' });
    assert.strictEqual((await dispute(waiting, '賣家尚未放書')).status, 201);
  }],

  ['已取書的訂單爭議被駁回時直接完成並撥款給賣家', async () => {
    const buyer = addUser({ balance: 500 });
    const seller = addUser({ balance: 0 });
    const admin = addAdmin();
    const book = addBook({ sellerId: seller.user_id, status: 'reserved' });
    const order = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, status: 'deposited', amount: 120 });
    Object.assign(order, { deposited_at: new Date(), picked_up_at: new Date() });

    const filed = await request('POST', '/api/disputes', { token: tokenFor(buyer), body: { order_id: order.order_id, reason: '書況與描述不符' } });
    assert.strictEqual(filed.status, 201);
    const res = await request('PATCH', `/api/admin/disputes/${filed.body.data.dispute_id}`, {
      token: tokenFor(admin), body: { result: 'dismissed', admin_note: '書況與照片相符' }
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(orderOf(order.order_id).status, 'completed');
    assert.strictEqual(balanceOf(seller.user_id), 120);
  }],

  ['提出爭議後訂單暫停並通知對方，重複申請會被擋下', async () => {
    const buyer = addUser({ balance: 500 });
    const seller = addUser({ balance: 0 });
    const book = addBook({ sellerId: seller.user_id });
    const order = addPaidOrder({
      buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, status: 'deposited'
    });
    const body = { order_id: order.order_id, reason: '書況與描述不符' };

    const res = await request('POST', '/api/disputes', { token: tokenFor(buyer), body });
    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.message, '爭議申請已送出');
    assert.strictEqual(res.body.data.status, 'pending');
    assert.strictEqual(orderOf(order.order_id).status, 'refunding');

    const notice = notificationsOf(seller.user_id)[0];
    assert.strictEqual(notice.title, '買家已對訂單申請爭議');
    assert.strictEqual(
      notice.content,
      `訂單 ${order.order_no} 有一筆爭議申請，客服將協助處理，處理期間訂單暫停進行。`
    );

    const again = await request('POST', '/api/disputes', { token: tokenFor(buyer), body });
    assert.strictEqual(again.status, 409);
    assert.strictEqual(again.body.message, '此訂單已有處理中的爭議申請');

    const other = await request('POST', '/api/disputes', { token: tokenFor(seller), body });
    assert.strictEqual(other.status, 409);
    assert.strictEqual(other.body.message, '此訂單已有處理中的爭議申請');

    const mine = await request('GET', '/api/disputes', { token: tokenFor(buyer) });
    assert.strictEqual(mine.body.data.length, 1);
    assert.strictEqual(mine.body.data[0].orders.order_no, order.order_no);
  }],

  ['裁決退款：退還買家並向賣家收回貨款', async () => {
    const buyer = addUser({ balance: 500 });
    const seller = addUser({ balance: 0 });
    const admin = addAdmin();
    const book = addBook({ sellerId: seller.user_id });
    const order = addPaidOrder({
      buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, amount: 200, status: 'deposited'
    });
    prisma.rows('books')[0].status = 'reserved';
    await request('POST', '/api/disputes', {
      token: tokenFor(buyer), body: { order_id: order.order_id, reason: '書況不符' }
    });

    const res = await request('PATCH', '/api/admin/disputes/1', {
      token: tokenFor(admin), body: { result: 'refund_auto', admin_note: '照片佐證明確' }
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.message, '爭議已裁決');
    assert.strictEqual(res.body.data.status, 'resolved');
    assert.strictEqual(res.body.data.result, 'refund_auto');

    assert.strictEqual(orderOf(order.order_id).status, 'refunded');
    assert.strictEqual(balanceOf(buyer.user_id), 500);
    assert.strictEqual(bookOf(book.book_id).status, 'on_sale');
    assert.strictEqual(transactionsOf(buyer.user_id).find((t) => t.type === 'refund').amount, 200);

    const refund = prisma.rows('refund_records')[0];
    assert.strictEqual(refund.refund_type, 'auto');
    assert.strictEqual(Number(refund.amount), 200);
    assert.strictEqual(refund.status, 'completed');

    const buyerNotice = notificationsOf(buyer.user_id).find((n) => n.title === '爭議案件已裁決');
    assert.strictEqual(buyerNotice.content, `訂單 ${order.order_no} 裁決退款，200 代幣已退回您的錢包。`);
    const sellerNotice = notificationsOf(seller.user_id).find((n) => n.title === '爭議案件已裁決');
    assert.strictEqual(sellerNotice.content, `訂單 ${order.order_no} 裁決退款給買家，交易已取消。`);

    assert.strictEqual(logs()[0].action, '裁決交易爭議');

    const again = await request('PATCH', '/api/admin/disputes/1', {
      token: tokenFor(admin), body: { result: 'refund_auto' }
    });
    assert.strictEqual(again.status, 409);
    assert.strictEqual(again.body.message, '此爭議已裁決');
  }],

  ['駁回爭議會依時間欄位恢復原本的訂單狀態', async () => {
    const buyer = addUser({ balance: 500 });
    const seller = addUser({ balance: 0 });
    const admin = addAdmin();
    const book = addBook({ sellerId: seller.user_id });
    const order = addPaidOrder({
      buyerId: buyer.user_id,
      sellerId: seller.user_id,
      bookId: book.book_id,
      amount: 200,
      status: 'deposited',
      deposited_at: new Date()
    });
    await request('POST', '/api/disputes', {
      token: tokenFor(buyer), body: { order_id: order.order_id, reason: '書況不符' }
    });

    const res = await request('PATCH', '/api/admin/disputes/1', {
      token: tokenFor(admin), body: { result: 'dismissed', admin_note: '證據不足' }
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(orderOf(order.order_id).status, 'deposited');
    assert.strictEqual(balanceOf(seller.user_id), 0);
    assert.strictEqual(prisma.rows('refund_records').length, 0);

    const notice = notificationsOf(buyer.user_id).find((n) => n.title === '爭議案件已裁決');
    assert.strictEqual(notice.content, `訂單 ${order.order_no} 經審核維持原交易，訂單恢復為「已存書」。`);
  }],

  ['裁決結果不在允許清單時回 400', async () => {
    const buyer = addUser({ balance: 500 });
    const seller = addUser({ balance: 0 });
    const admin = addAdmin();
    const book = addBook({ sellerId: seller.user_id });
    const order = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id });
    await request('POST', '/api/disputes', {
      token: tokenFor(buyer), body: { order_id: order.order_id, reason: '書況不符' }
    });

    const res = await request('PATCH', '/api/admin/disputes/1', {
      token: tokenFor(admin), body: { result: 'refund_all' }
    });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.message, '裁決結果不正確');

    const missing = await request('PATCH', '/api/admin/disputes/999', {
      token: tokenFor(admin), body: { result: 'dismissed' }
    });
    assert.strictEqual(missing.status, 404);
    assert.strictEqual(missing.body.message, '找不到該爭議案件');
  }],

  ['裁決時記錄最後一次 AI 分析的建議是否與結果一致', async () => {
    const buyer = addUser({ balance: 500 });
    const seller = addUser({ balance: 0 });
    const admin = addAdmin();
    const book = addBook({ sellerId: seller.user_id });
    const order = addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, amount: 200, status: 'deposited' });
    await request('POST', '/api/disputes', { token: tokenFor(buyer), body: { order_id: order.order_id, reason: '書況不符' } });
    prisma.store.ai_dispute_analyses = [
      { analysis_id: 1, dispute_id: 1, suggestion: 'refund', agreed: null, created_at: new Date() },
      { analysis_id: 2, dispute_id: 1, suggestion: 'dismiss', agreed: null, created_at: new Date() }
    ];

    const res = await request('PATCH', '/api/admin/disputes/1', { token: tokenFor(admin), body: { result: 'refund_manual' } });
    assert.strictEqual(res.status, 200);
    const [first, last] = prisma.rows('ai_dispute_analyses');
    assert.strictEqual(first.agreed, null);
    assert.strictEqual(last.agreed, false);
    assert.strictEqual(last.resolved_result, 'refund_manual');
    assert.ok(last.resolved_at instanceof Date);
  }]
];

module.exports = { name: '客服工單、檢舉與交易爭議', tests };
