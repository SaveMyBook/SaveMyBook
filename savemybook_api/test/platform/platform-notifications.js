const assert = require('assert');
const h = require('./harness');

const { prisma, request } = h;
const { notify, notifyMany, notifyActiveUsers } = h.api('services/notify');
const categories = h.api('services/notification-categories');
const { UNREAD_BY_CATEGORY_SQL } = h.api('services/notifications');

// 所有建立通知的呼叫端實際使用的 (type, related_type) 組合；新增通知種類時須一併補上。
const EMITTED = [
  ['order', 'order', 'trade'],
  ['reservation', 'chat_room', 'trade'],
  ['reservation', 'book', 'trade'],
  ['reservation', null, 'trade'],
  ['system', 'wallet', 'trade'],
  ['system', 'book', 'trade'],
  ['system', null, 'account'],
  ['message', 'chat_room', 'chat'],
  ['system', 'security', 'account'],
  ['system', 'password', 'account'],
  ['system', 'legal', 'account'],
  ['system', 'member_level', 'account'],
  ['system', 'user', 'account'],
  ['system', 'push_test', 'account'],
  ['system', 'ticket', 'service'],
  ['system', 'report', 'service'],
  ['system', 'admin_ticket', 'service'],
  ['promotion', 'book', 'promotion'],
  ['promotion', 'announcement', 'promotion'],
  ['system', 'announcement', 'promotion']
];

const addNotification = (userId, overrides = {}) => {
  const row = {
    notification_id: prisma.nextId('notifications'),
    user_id: userId,
    type: 'system',
    title: '通知',
    content: '內容',
    related_id: null,
    related_type: null,
    is_read: false,
    pushed_at: null,
    created_at: new Date(),
    ...overrides
  };
  prisma.rows('notifications').push(row);
  return row;
};

module.exports = {
  name: '平台：站內通知',
  tests: [
    ['建立通知會截斷過長的標題並帶入關聯資訊', async () => {
      const user = h.addUser();
      const created = await notify(null, {
        userId: user.user_id,
        type: 'order',
        title: '標'.repeat(300),
        content: '您的訂單已成立',
        relatedId: 12,
        relatedType: 'order'
      });
      assert.strictEqual(created.title.length, 255);
      assert.ok(created.title.endsWith('…'));
      assert.strictEqual(created.type, 'order');
      assert.strictEqual(created.related_id, 12);
      assert.strictEqual(created.related_type, 'order');
      assert.strictEqual(created.is_read, undefined);
    }],

    ['指定操作者時會補寫 actor_id；欄位不存在時略過', async () => {
      const user = h.addUser();
      const actor = h.addUser();
      await notify(null, { userId: user.user_id, title: '新訊息', content: '你好', actorId: actor.user_id });
      assert.strictEqual(Number(prisma.rows('notifications')[0].actor_id), actor.user_id);

      h.reset({ schema: h.without(h.FULL_SCHEMA, ['notifications.actor_id']) });
      const other = h.addUser();
      await notify(null, { userId: other.user_id, title: '新訊息', content: '你好', actorId: 5 });
      assert.strictEqual(prisma.rows('notifications')[0].actor_id, undefined);
    }],

    ['批次通知可一次寫入多位使用者', async () => {
      const users = [h.addUser(), h.addUser(), h.addUser()];
      const count = await notifyMany(null, users.map((u) => u.user_id), {
        type: 'system', title: '系統公告', content: '將於今晚維護'
      });
      assert.strictEqual(count, 3);
      assert.strictEqual(prisma.rows('notifications').length, 3);
      assert.deepStrictEqual([...new Set(prisma.rows('notifications').map((n) => n.title))], ['系統公告']);
    }],

    ['批次通知帶有操作者時一併寫入 actor_id', async () => {
      const users = [h.addUser(), h.addUser()];
      const actor = h.addUser();
      await notifyMany(null, users.map((u) => u.user_id), {
        type: 'message', title: '新訊息', content: '有人提到您', actorId: actor.user_id
      });
      const rows = prisma.rows('notifications');
      assert.strictEqual(rows.length, 2);
      assert.deepStrictEqual(rows.map((n) => Number(n.actor_id)), [actor.user_id, actor.user_id]);
      assert.deepStrictEqual(rows.map((n) => Number(n.user_id)), users.map((u) => u.user_id));
    }],

    ['全站通知不寄給停權、黑名單與已刪除的帳號', async () => {
      const normal = h.addUser();
      h.addUser({ isActive: false });
      h.addUser({ isBlacklisted: true });
      const deleted = h.addUser();
      deleted.anonymized_at = new Date();

      const count = await notifyActiveUsers({ type: 'promotion', title: '活動開跑', content: '限時優惠' });
      assert.strictEqual(count, 1);
      assert.deepStrictEqual(prisma.rows('notifications').map((n) => Number(n.user_id)), [normal.user_id]);
    }],

    ['通知列表分頁並附上未讀數量', async () => {
      const user = h.addUser();
      for (let i = 0; i < 25; i += 1) {
        addNotification(user.user_id, { title: `通知 ${i}`, is_read: i < 20, created_at: new Date(2026, 0, 1, 0, i) });
      }
      addNotification(h.addUser().user_id, { title: '別人的通知' });

      const first = await request('GET', '/api/notifications', { token: h.tokenFor(user) });
      assert.strictEqual(first.status, 200);
      assert.strictEqual(first.body.data.length, 20);
      assert.strictEqual(first.body.unread_count, 5);
      assert.deepStrictEqual(first.body.pagination, { total: 25, page: 1, limit: 20, total_pages: 2 });
      // 預設由新到舊。
      assert.strictEqual(first.body.data[0].title, '通知 24');

      const second = await request('GET', '/api/notifications?page=2', { token: h.tokenFor(user) });
      assert.strictEqual(second.body.data.length, 5);
      assert.strictEqual(second.body.data[0].title, '通知 4');
    }],

    ['通知列表可依類型篩選，不支援的類型回 400', async () => {
      const user = h.addUser();
      addNotification(user.user_id, { type: 'order' });
      addNotification(user.user_id, { type: 'message' });

      const filtered = await request('GET', '/api/notifications?type=order', { token: h.tokenFor(user) });
      assert.strictEqual(filtered.body.data.length, 1);
      assert.strictEqual(filtered.body.pagination.total, 1);

      const bad = await request('GET', '/api/notifications?type=coupon', { token: h.tokenFor(user) });
      assert.strictEqual(bad.status, 400);
      assert.strictEqual(bad.body.message, '不支援的通知類型');
    }],

    ['未讀數量只計算自己的未讀通知', async () => {
      const user = h.addUser();
      addNotification(user.user_id);
      addNotification(user.user_id, { is_read: true });
      addNotification(h.addUser().user_id);

      const res = await request('GET', '/api/notifications/unread-count', { token: h.tokenFor(user) });
      assert.deepStrictEqual(res.body.data, {
        unread_count: 1,
        by_category: { trade: 0, chat: 0, account: 1, service: 0, promotion: 0 }
      });
    }],

    ['標為已讀：單筆與全部', async () => {
      const user = h.addUser();
      const mine = addNotification(user.user_id);
      const another = addNotification(user.user_id);
      const others = addNotification(h.addUser().user_id);
      const token = h.tokenFor(user);

      const one = await request('PATCH', `/api/notifications/${mine.notification_id}/read`, { token });
      assert.strictEqual(one.status, 200);
      assert.strictEqual(one.body.message, '已標為已讀');
      assert.strictEqual(mine.is_read, true);
      assert.strictEqual(another.is_read, false);

      const all = await request('PATCH', '/api/notifications/read-all', { token });
      assert.strictEqual(all.body.message, '已全部標為已讀');
      assert.strictEqual(another.is_read, true);
      assert.strictEqual(others.is_read, false);
    }],

    ['不能讀取或刪除別人的通知', async () => {
      const user = h.addUser();
      const others = addNotification(h.addUser().user_id);
      const token = h.tokenFor(user);

      const read = await request('PATCH', `/api/notifications/${others.notification_id}/read`, { token });
      assert.strictEqual(read.status, 404);
      assert.strictEqual(read.body.message, '找不到該通知');

      const removed = await request('DELETE', `/api/notifications/${others.notification_id}`, { token });
      assert.strictEqual(removed.status, 404);
      assert.strictEqual(prisma.rows('notifications').length, 1);
    }],

    ['刪除單筆與清除全部通知', async () => {
      const user = h.addUser();
      const mine = addNotification(user.user_id);
      addNotification(user.user_id);
      const others = addNotification(h.addUser().user_id);
      const token = h.tokenFor(user);

      const one = await request('DELETE', `/api/notifications/${mine.notification_id}`, { token });
      assert.strictEqual(one.body.message, '通知已刪除');

      const all = await request('DELETE', '/api/notifications/all', { token });
      assert.strictEqual(all.status, 200);
      assert.strictEqual(all.body.message, '已清除 1 則通知');
      assert.deepStrictEqual(all.body.data, { deleted: 1 });
      assert.deepStrictEqual(prisma.rows('notifications').map((n) => n.notification_id), [others.notification_id]);
    }],

    ['每一種通知組合恰好歸入一個分類', async () => {
      for (const [type, relatedType, expected] of EMITTED) {
        assert.strictEqual(categories.categoryOf(type, relatedType), expected, `${type}/${relatedType}`);
      }
      const user = h.addUser();
      const rows = [...EMITTED, ['system', 'unknown', 'account']]
        .map(([type, related_type]) => addNotification(user.user_id, { type, related_type }));
      const hits = new Map(rows.map((r) => [r.notification_id, []]));
      for (const category of categories.CATEGORIES) {
        const found = await prisma.notifications.findMany({ where: categories.whereOf(category) });
        for (const r of found) hits.get(r.notification_id).push(category);
      }
      for (const r of rows) {
        assert.deepStrictEqual(hits.get(r.notification_id), [categories.categoryOf(r.type, r.related_type)], `${r.type}/${r.related_type}`);
      }
    }],

    ['分類的 SQL 與程式判斷一致，未讀數以單一查詢完成', async () => {
      const branches = [...categories.caseSql().matchAll(/WHEN (type|related_type) IN \(([^)]*)\) THEN '(\w+)'/g)]
        .map(([, column, values, category]) => ({ column, values: values.split(', ').map((v) => v.replace(/'/g, '')), category }));
      const fallback = /ELSE '(\w+)' END/.exec(categories.caseSql())[1];
      const evaluate = (row) => branches.find((b) => b.values.includes(row[b.column]))?.category ?? fallback;
      for (const [type, related_type, expected] of [...EMITTED, ['system', 'unknown', 'account']]) {
        assert.strictEqual(evaluate({ type, related_type }), expected, `${type}/${related_type}`);
      }

      const user = h.addUser();
      addNotification(user.user_id, { type: 'order', related_type: 'order' });
      addNotification(user.user_id, { type: 'message', related_type: 'chat_room' });
      addNotification(user.user_id, { type: 'message', related_type: 'chat_room' });
      addNotification(user.user_id, { related_type: 'ticket' });
      addNotification(user.user_id, { related_type: 'announcement', is_read: true });
      prisma.sqlLog.length = 0;
      const res = await request('GET', '/api/notifications/unread-count', { token: h.tokenFor(user) });
      assert.deepStrictEqual(res.body.data, {
        unread_count: 4,
        by_category: { trade: 1, chat: 2, account: 0, service: 1, promotion: 0 }
      });
      assert.strictEqual(prisma.sqlLog.filter((q) => String(q.sql ?? q).includes('GROUP BY category')).length, 1);
      assert.ok(UNREAD_BY_CATEGORY_SQL.includes(categories.caseSql()));
    }],

    ['通知列表可依分類篩選並分頁，每筆附上分類', async () => {
      const user = h.addUser();
      for (let i = 0; i < 23; i += 1) {
        addNotification(user.user_id, { type: 'order', related_type: 'order', title: `訂單 ${i}`, created_at: new Date(2026, 0, 1, 0, i) });
      }
      addNotification(user.user_id, { type: 'promotion', related_type: 'book', title: '降價' });
      addNotification(user.user_id, { related_type: 'security', title: '新裝置登入' });
      const token = h.tokenFor(user);

      const trade = await request('GET', '/api/notifications?category=trade&page=2', { token });
      assert.strictEqual(trade.status, 200);
      assert.deepStrictEqual(trade.body.pagination, { total: 23, page: 2, limit: 20, total_pages: 2 });
      assert.strictEqual(trade.body.data.length, 3);
      assert.ok(trade.body.data.every((n) => n.category === 'trade'));
      assert.strictEqual(trade.body.unread_count, 25);

      const promotion = await request('GET', '/api/notifications?category=promotion', { token });
      assert.deepStrictEqual(promotion.body.data.map((n) => n.title), ['降價']);

      const account = await request('GET', '/api/notifications?category=account', { token });
      assert.deepStrictEqual(account.body.data.map((n) => [n.title, n.category]), [['新裝置登入', 'account']]);

      const bad = await request('GET', '/api/notifications?category=coupon', { token });
      assert.strictEqual(bad.status, 400);
      assert.strictEqual(bad.body.message, '不支援的通知分類');
    }],

    ['全部已讀與清除全部可限定分類', async () => {
      const user = h.addUser();
      const order = addNotification(user.user_id, { type: 'order', related_type: 'order' });
      const chat = addNotification(user.user_id, { type: 'message', related_type: 'chat_room' });
      const ticket = addNotification(user.user_id, { related_type: 'ticket' });
      const others = addNotification(h.addUser().user_id, { type: 'order', related_type: 'order' });
      const token = h.tokenFor(user);

      const read = await request('PATCH', '/api/notifications/read-all?category=trade', { token });
      assert.strictEqual(read.status, 200);
      assert.deepStrictEqual(read.body.data, { updated: 1 });
      assert.deepStrictEqual([order.is_read, chat.is_read, ticket.is_read, others.is_read], [true, false, false, false]);

      const cleared = await request('DELETE', '/api/notifications/all?category=chat', { token });
      assert.deepStrictEqual(cleared.body.data, { deleted: 1 });
      assert.deepStrictEqual(
        prisma.rows('notifications').map((n) => n.notification_id),
        [order.notification_id, ticket.notification_id, others.notification_id]
      );

      const badRead = await request('PATCH', '/api/notifications/read-all?category=coupon', { token });
      assert.strictEqual(badRead.status, 400);
      const badDelete = await request('DELETE', '/api/notifications/all?category=coupon', { token });
      assert.strictEqual(badDelete.status, 400);
      assert.strictEqual(prisma.rows('notifications').length, 3);
    }],

    ['通知編號格式不正確時回 400', async () => {
      const user = h.addUser();
      const res = await request('PATCH', '/api/notifications/abc/read', { token: h.tokenFor(user) });
      assert.strictEqual(res.status, 400);
      assert.strictEqual(res.body.message, '通知編號不正確');
    }]
  ]
};
