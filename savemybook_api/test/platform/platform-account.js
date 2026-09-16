const assert = require('assert');
const h = require('./harness');

const { prisma, request } = h;
const account = h.api('services/account');
const authToken = h.api('lib/auth-token');

const signedIn = () => {
  const user = h.addUser();
  const session = h.addSession(user);
  return { user, session, token: h.tokenFor(user, session.sid) };
};

const sensitive = (ctx) => ({ 'x-verify-token': h.verifyTokenFor({ user: ctx.user, sid: ctx.session.sid }) });

const addOrder = (userId, status) => prisma.rows('orders').push({
  order_id: prisma.rows('orders').length + 1,
  order_no: `OD${prisma.rows('orders').length + 1}`,
  buyer_id: userId,
  seller_id: 999,
  status,
  total_amount: 100,
  created_at: new Date()
});

module.exports = {
  name: '平台：帳號隱私',
  tests: [
    ['資料匯出：涵蓋個人檔案、書籍、訂單、錢包、申訴與登入方式', async () => {
      const ctx = signedIn();
      const userId = ctx.user.user_id;
      prisma.rows('books').push({ book_id: 1, seller_id: userId, title: '我的書', status: 'on_sale' });
      addOrder(userId, 'completed');
      prisma.rows('orders').push({ order_id: 9, order_no: 'OD9', seller_id: userId, buyer_id: 555, status: 'completed' });
      prisma.rows('wallets').push({ user_id: userId, balance: 120 });
      prisma.rows('reports').push({ report_id: 1, reporter_id: userId, reason: '違規' });
      prisma.rows('transaction_disputes').push({ dispute_id: 1, applicant_id: userId, reason: '書況不符' });
      prisma.rows('support_tickets').push({ ticket_id: 1, user_id: userId, subject: '無法取件' });
      prisma.rows('user_identities').push({
        identity_id: 1, user_id: userId, provider: 'google', email: 'me@example.com', phone: null,
        display_name: '我', created_at: new Date(), last_login_at: null
      });

      const res = await request('GET', '/api/users/me/export', { token: ctx.token, headers: sensitive(ctx) });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.headers.get('cache-control'), 'no-store');
      assert.ok(res.headers.get('content-disposition').startsWith('attachment; filename="savemybook-'));

      const data = res.body;
      assert.strictEqual(data.format_version, 1);
      assert.ok(data.exported_at);
      assert.strictEqual(data.profile.email, ctx.user.email);
      // 匯出內容不得包含密碼雜湊。
      assert.strictEqual('password_hash' in data.profile, false);
      assert.strictEqual(data.books.length, 1);
      assert.strictEqual(data.orders_as_buyer.length, 1);
      assert.strictEqual(data.orders_as_seller.length, 1);
      assert.strictEqual(Number(data.wallet.balance), 120);
      assert.strictEqual(data.reports.length, 1);
      assert.strictEqual(data.disputes.length, 1);
      assert.strictEqual(data.support_tickets.length, 1);
      assert.strictEqual(data.sign_in_methods.password_set, true);
      assert.deepStrictEqual(data.sign_in_methods.items.map((i) => i.provider), ['google']);
      assert.strictEqual(data.ai.consent, null);
    }],

    ['資料匯出：需要先完成身分驗證', async () => {
      const ctx = signedIn();
      const res = await request('GET', '/api/users/me/export', { token: ctx.token });
      assert.strictEqual(res.status, 403);
      assert.strictEqual(res.body.code, 'VERIFICATION_REQUIRED');
    }],

    ['資料匯出：尚未執行 014 時登入方式標示為未保存', async () => {
      h.reset({ schema: h.without(h.FULL_SCHEMA, ['user_identities']) });
      const ctx = signedIn();
      const data = await account.exportData(ctx.user.user_id);
      assert.strictEqual(data.sign_in_methods, null);
    }],

    ['刪除帳號：尚未申請時的狀態', async () => {
      const ctx = signedIn();
      const res = await request('GET', '/api/users/me/deletion', { token: ctx.token });
      assert.strictEqual(res.status, 200);
      assert.deepStrictEqual(res.body.data, { pending: false, requested_at: null, purge_at: null, grace_days: 30 });
    }],

    ['刪除帳號：必須輸入密碼，且密碼要正確', async () => {
      const ctx = signedIn();
      const empty = await request('POST', '/api/users/me/deletion', { token: ctx.token, body: {} });
      assert.strictEqual(empty.status, 400);
      assert.strictEqual(empty.body.message, '請輸入密碼以確認身分');

      const wrong = await request('POST', '/api/users/me/deletion', { token: ctx.token, body: { password: '不是密碼' } });
      assert.strictEqual(wrong.status, 400);
      assert.strictEqual(wrong.body.message, '密碼錯誤');
      assert.strictEqual(ctx.user.deletion_requested_at, null);
    }],

    ['刪除帳號：還有進行中的訂單時不受理', async () => {
      const ctx = signedIn();
      addOrder(ctx.user.user_id, 'pending_pickup');
      addOrder(ctx.user.user_id, 'refunding');
      addOrder(ctx.user.user_id, 'completed');

      const res = await request('POST', '/api/users/me/deletion', { token: ctx.token, body: { password: 'Passw0rd123' } });
      assert.strictEqual(res.status, 400);
      assert.strictEqual(res.body.code, 'OPEN_ORDERS');
      assert.strictEqual(res.body.message, '尚有 2 筆進行中的訂單，請先完成或取消後再申請刪除');
    }],

    ['刪除帳號：受理後有 30 天緩衝期，重複申請不會延長', async () => {
      const ctx = signedIn();
      const res = await request('POST', '/api/users/me/deletion', { token: ctx.token, body: { password: 'Passw0rd123' } });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.message, '已受理，30 天內重新登入即可取消');
      assert.strictEqual(res.body.data.grace_days, 30);
      const requestedAt = ctx.user.deletion_requested_at;
      assert.ok(requestedAt);
      assert.strictEqual(
        new Date(res.body.data.purge_at).getTime(),
        new Date(requestedAt).getTime() + 30 * 86400000
      );

      const again = await request('POST', '/api/users/me/deletion', { token: ctx.token, body: { password: 'Passw0rd123' } });
      assert.strictEqual(again.status, 200);
      assert.strictEqual(new Date(ctx.user.deletion_requested_at).getTime(), new Date(requestedAt).getTime());

      const info = await request('GET', '/api/users/me/deletion', { token: ctx.token });
      assert.strictEqual(info.body.data.pending, true);

      const cancel = await request('DELETE', '/api/users/me/deletion', { token: ctx.token });
      assert.strictEqual(cancel.status, 200);
      assert.strictEqual(cancel.body.message, '已取消刪除帳號');
      assert.strictEqual(ctx.user.deletion_requested_at, null);
    }],

    ['匿名化：清掉個資、下架書籍並刪除連動資料', async () => {
      const user = h.addUser({ nickname: '王小明' });
      const other = h.addUser();
      const userId = user.user_id;
      user.deletion_requested_at = new Date(Date.now() - 31 * 86400000);
      user.bio = '自我介紹';
      user.phone = '0912345678';
      user.avatar_url = '/uploads/avatars/a.jpg';
      user.share_token = 'share-token';

      prisma.rows('books').push({ book_id: 1, seller_id: userId, status: 'on_sale' });
      prisma.rows('books').push({ book_id: 2, seller_id: userId, status: 'sold' });
      prisma.rows('books').push({ book_id: 3, seller_id: other.user_id, status: 'on_sale' });
      prisma.rows('shopping_cart').push({ cart_id: 1, user_id: userId });
      prisma.rows('favorites').push({ favorite_id: 1, user_id: userId });
      prisma.rows('user_qr_codes').push({ qr_id: 1, user_id: userId });
      prisma.rows('notifications').push({ notification_id: 1, user_id: userId, title: '通知' });
      prisma.rows('notifications').push({ notification_id: 2, user_id: other.user_id, title: '別人的通知' });
      prisma.rows('user_identities').push({ identity_id: 1, user_id: userId, provider: 'google', subject: 'g-1' });
      prisma.rows('ai_consents').push({ user_id: userId, granted: 1 });
      prisma.rows('chat_messages').push({ message_id: 1, sender_id: userId, content: '你好', message_type: 'text' });
      h.addSession(user);
      h.addDevice(user, { token: `fcm-${'z'.repeat(30)}` });

      const processed = await account.processDueDeletions();
      assert.strictEqual(processed, 1);

      assert.strictEqual(user.nickname, '已刪除的使用者');
      assert.ok(user.email.startsWith(`deleted+${userId}.`));
      assert.ok(user.email.endsWith('@savemybook.invalid'));
      assert.strictEqual(user.avatar_url, null);
      assert.strictEqual(user.bio, null);
      assert.strictEqual(user.phone, null);
      assert.strictEqual(user.birthday, null);
      assert.strictEqual(user.gender, 'undisclosed');
      assert.strictEqual(user.is_active, false);
      assert.strictEqual(user.share_token, null);
      assert.ok(user.anonymized_at);
      assert.notStrictEqual(user.password_hash, '');
      assert.strictEqual(user.password_set, 1);

      const books = Object.fromEntries(prisma.rows('books').map((b) => [b.book_id, b.status]));
      assert.deepStrictEqual(books, { 1: 'removed', 2: 'sold', 3: 'on_sale' });

      assert.deepStrictEqual(prisma.rows('shopping_cart'), []);
      assert.deepStrictEqual(prisma.rows('favorites'), []);
      assert.deepStrictEqual(prisma.rows('user_qr_codes'), []);
      assert.deepStrictEqual(prisma.rows('notifications').map((n) => n.notification_id), [2]);
      assert.deepStrictEqual(prisma.rows('user_identities'), []);
      assert.deepStrictEqual(prisma.rows('ai_consents'), []);
      assert.deepStrictEqual(prisma.rows('push_devices'), []);
      assert.strictEqual(prisma.rows('chat_messages')[0].content, '（使用者已刪除帳號）');
      assert.strictEqual(prisma.rows('chat_messages')[0].message_type, 'system');
      assert.ok(prisma.rows('user_sessions')[0].revoked_at);
    }],

    ['匿名化：緩衝期內或仍有進行中訂單時不執行', async () => {
      const soon = h.addUser();
      soon.deletion_requested_at = new Date(Date.now() - 1 * 86400000);
      const busy = h.addUser();
      busy.deletion_requested_at = new Date(Date.now() - 40 * 86400000);
      addOrder(busy.user_id, 'deposited');

      await account.processDueDeletions();
      assert.strictEqual(soon.anonymized_at, null);
      assert.strictEqual(busy.anonymized_at, null);
    }],

    ['變更密碼：必填欄位、密碼規則與目前密碼檢查', async () => {
      const ctx = signedIn();
      const change = (body) => request('PUT', '/api/users/me/password', { token: ctx.token, body });

      assert.strictEqual((await change({})).body.message, '請填寫目前密碼與新密碼');
      assert.strictEqual((await change({ current_password: 'Passw0rd123' })).body.message, '請填寫目前密碼與新密碼');
      assert.strictEqual(
        (await change({ current_password: 'Passw0rd123', new_password: 'abc' })).body.message,
        '新密碼長度至少 8 個字元'
      );
      assert.strictEqual(
        (await change({ current_password: '錯的密碼', new_password: 'NewPass123' })).body.message,
        '目前密碼錯誤'
      );
      assert.strictEqual(
        (await change({ current_password: 'Passw0rd123', new_password: 'Passw0rd123' })).body.message,
        '新密碼不可與目前密碼相同'
      );
    }],

    ['變更密碼：成功後換發 Token 並登出其他裝置', async () => {
      const ctx = signedIn();
      const other = h.addSession(ctx.user, { deviceName: 'Pixel' });
      h.addDevice(ctx.user, { token: `fcm-${'q'.repeat(30)}` });

      const res = await request('PUT', '/api/users/me/password', {
        token: ctx.token, body: { current_password: 'Passw0rd123', new_password: 'NewPass123' }
      });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.message, '密碼已更新，其他裝置須重新登入');

      const decoded = authToken.verify(res.body.data.token);
      assert.strictEqual(decoded.userId, ctx.user.user_id);
      assert.strictEqual(decoded.sid, ctx.session.sid);
      assert.strictEqual(decoded.pwv, authToken.passwordVersion(ctx.user.password_hash));

      assert.ok(other.revoked_at);
      assert.strictEqual(ctx.session.revoked_at, null);
      assert.deepStrictEqual(prisma.rows('push_devices'), []);

      // 新的 Token 可用，舊的立即失效。
      assert.strictEqual((await request('GET', '/api/security', { token: res.body.data.token })).status, 200);
      assert.strictEqual((await request('GET', '/api/security', { token: ctx.token })).body.code, 'TOKEN_REVOKED');
    }],

    ['通知設定：預設全部開啟，可個別關閉', async () => {
      const ctx = signedIn();
      const initial = await request('GET', '/api/users/me/notification-settings', { token: ctx.token });
      assert.deepStrictEqual(initial.body.data, { order: true, message: true, promotion: true });

      const updated = await request('PUT', '/api/users/me/notification-settings', {
        token: ctx.token, body: { promotion: false }
      });
      assert.strictEqual(updated.status, 200);
      assert.strictEqual(updated.body.message, '已更新通知設定');
      assert.deepStrictEqual(updated.body.data, { order: true, message: true, promotion: false });
      assert.strictEqual(prisma.rows('user_settings')[0].notification_promo, false);

      const again = await request('GET', '/api/users/me/notification-settings', { token: ctx.token });
      assert.strictEqual(again.body.data.promotion, false);
    }],

    ['通知設定：只接受布林值，且至少要有一項', async () => {
      const ctx = signedIn();
      const bad = await request('PUT', '/api/users/me/notification-settings', { token: ctx.token, body: { order: 'off' } });
      assert.strictEqual(bad.status, 400);
      assert.strictEqual(bad.body.message, 'order 必須是 true 或 false');

      const empty = await request('PUT', '/api/users/me/notification-settings', { token: ctx.token, body: {} });
      assert.strictEqual(empty.status, 400);
      assert.strictEqual(empty.body.message, '沒有要更新的設定');
    }],

    ['個人檔案：暱稱、電話與生日都有格式限制', async () => {
      const ctx = signedIn();
      const update = (body) => request('PUT', '/api/users/me', { token: ctx.token, body });

      assert.strictEqual((await update({ nickname: '甲' })).body.message, '暱稱至少需 2 個字');
      assert.strictEqual((await update({ nickname: 'a'.repeat(51) })).body.message, '暱稱不可超過 50 個字');
      assert.strictEqual((await update({ phone: 'abc' })).body.message, '電話格式不正確');
      assert.strictEqual((await update({ avatar_url: 'javascript:alert(1)' })).body.message, '頭像網址格式不正確');
      assert.strictEqual((await update({ birthday: '2999-01-01' })).body.message, '生日不在合理範圍內');
      assert.strictEqual((await update({ birthday: '1800-01-01' })).body.message, '生日不在合理範圍內');

      const ok = await update({ nickname: '小明', bio: '你好', phone: '02-2345 6789', gender: 'male' });
      assert.strictEqual(ok.status, 200);
      assert.strictEqual(ok.body.data.nickname, '小明');
      assert.strictEqual(ok.body.data.gender, 'male');
      // 回傳的個人檔案不得包含密碼雜湊。
      assert.strictEqual('password_hash' in ok.body.data, false);
    }]
  ]
};
