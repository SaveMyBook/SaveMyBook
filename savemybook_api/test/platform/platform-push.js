const assert = require('assert');
const h = require('./harness');

const { prisma, request } = h;
const push = h.api('services/push');
const setup = h.api('services/push/setup');

const TOKEN = `fcm-${'a'.repeat(40)}`;

const addNotification = (userId, overrides = {}) => {
  const row = {
    notification_id: prisma.nextId('notifications'),
    user_id: userId,
    type: 'system',
    title: '系統通知',
    content: '內容',
    related_id: null,
    related_type: null,
    actor_id: null,
    is_read: false,
    pushed_at: null,
    created_at: new Date(),
    ...overrides
  };
  prisma.rows('notifications').push(row);
  return row;
};

const withPushDisabled = async (fn) => {
  const original = push.isReady;
  push.isReady = () => false;
  try {
    await fn();
  } finally {
    push.isReady = original;
  }
};

module.exports = {
  name: '平台：推播',
  before: async () => {
    await h.enablePush();
    push.retryQueue.length = 0;
  },
  tests: [
    ['推播服務未啟用時各端點回 503 PUSH_DISABLED', async () => {
      const user = h.addUser();
      const token = h.tokenFor(user);
      await withPushDisabled(async () => {
        const list = await request('GET', '/api/push/devices', { token });
        const add = await request('POST', '/api/push/devices', { token, body: { token: TOKEN, platform: 'ios' } });
        const remove = await request('DELETE', '/api/push/devices', { token, body: { token: TOKEN } });
        for (const res of [list, add, remove]) {
          assert.strictEqual(res.status, 503);
          assert.strictEqual(res.body.code, 'PUSH_DISABLED');
          assert.strictEqual(res.body.message, '推播服務尚未啟用');
        }
      });
      assert.strictEqual(setup.isReady(), true);
    }],

    ['登記裝置：token 與平台格式檢查', async () => {
      const user = h.addUser();
      const token = h.tokenFor(user);
      const post = (body) => request('POST', '/api/push/devices', { token, body });

      assert.strictEqual((await post({ platform: 'ios' })).body.message, '裝置 token 格式不正確');
      assert.strictEqual((await post({ token: 'too-short', platform: 'ios' })).body.message, '裝置 token 格式不正確');
      assert.strictEqual((await post({ token: `${TOKEN}!!`, platform: 'ios' })).body.message, '裝置 token 格式不正確');
      assert.strictEqual((await post({ token: 'x'.repeat(256), platform: 'ios' })).body.message, '裝置 token不可超過 255 個字');
      assert.strictEqual((await post({ token: TOKEN, platform: 'web' })).body.message, 'platform 僅接受：ios, android');
    }],

    ['登記裝置：綁定目前的登入裝置，重複登記會更新而非新增', async () => {
      const user = h.addUser();
      const session = h.addSession(user);
      const token = h.tokenFor(user, session.sid);

      const first = await request('POST', '/api/push/devices', { token, body: { token: TOKEN, platform: 'ios', app_version: '1.2.3' } });
      assert.strictEqual(first.status, 200);
      assert.strictEqual(first.body.message, '已登記推播裝置');
      assert.strictEqual(prisma.rows('push_devices').length, 1);
      assert.strictEqual(prisma.rows('push_devices')[0].session_sid, session.sid);
      assert.strictEqual(prisma.rows('push_devices')[0].app_version, '1.2.3');

      await request('POST', '/api/push/devices', { token, body: { token: TOKEN, platform: 'android' } });
      assert.strictEqual(prisma.rows('push_devices').length, 1);
      assert.strictEqual(prisma.rows('push_devices')[0].platform, 'android');
    }],

    ['登記裝置：同一支手機換帳號登入時會轉給新帳號', async () => {
      const first = h.addUser();
      const second = h.addUser();
      await request('POST', '/api/push/devices', { token: h.tokenFor(first), body: { token: TOKEN, platform: 'ios' } });
      await request('POST', '/api/push/devices', { token: h.tokenFor(second), body: { token: TOKEN, platform: 'ios' } });

      assert.strictEqual(prisma.rows('push_devices').length, 1);
      assert.strictEqual(Number(prisma.rows('push_devices')[0].user_id), second.user_id);
    }],

    ['登記裝置：每個帳號最多保留 10 台，最久沒用的會被淘汰', async () => {
      const user = h.addUser();
      for (let i = 0; i < 10; i += 1) {
        h.addDevice(user, { token: `fcm-old-${i}-${'b'.repeat(20)}`, lastSeenAt: new Date(2026, 0, 1, 0, i) });
      }
      await request('POST', '/api/push/devices', { token: h.tokenFor(user), body: { token: TOKEN, platform: 'ios' } });

      const tokens = prisma.rows('push_devices').map((d) => d.token);
      assert.strictEqual(tokens.length, 10);
      assert.ok(tokens.includes(TOKEN));
      assert.ok(!tokens.includes(`fcm-old-0-${'b'.repeat(20)}`));
    }],

    ['裝置清單只顯示 token 末六碼', async () => {
      const user = h.addUser();
      h.addDevice(user, { token: TOKEN, platform: 'ios', appVersion: '1.0.0' });
      h.addDevice(h.addUser(), { token: `fcm-other-${'c'.repeat(20)}` });

      const res = await request('GET', '/api/push/devices', { token: h.tokenFor(user) });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.data.length, 1);
      assert.strictEqual(res.body.data[0].token_tail, TOKEN.slice(-6));
      assert.strictEqual(res.body.data[0].platform, 'ios');
      assert.strictEqual(JSON.stringify(res.body).includes(TOKEN), false);
    }],

    ['取消登記只會移除自己的裝置', async () => {
      const user = h.addUser();
      const other = h.addUser();
      h.addDevice(user, { token: TOKEN });
      h.addDevice(other, { token: `fcm-other-${'d'.repeat(20)}` });

      const res = await request('DELETE', '/api/push/devices', { token: h.tokenFor(user), body: { token: TOKEN } });
      assert.strictEqual(res.body.message, '已取消推播裝置');
      assert.deepStrictEqual(prisma.rows('push_devices').map((d) => Number(d.user_id)), [other.user_id]);
    }],

    ['測試通知：僅限管理員，且必須先有推播裝置', async () => {
      const member = await request('POST', '/api/push/test', { token: h.tokenFor(h.addUser()), body: {} });
      assert.strictEqual(member.status, 403);
      assert.strictEqual(member.body.message, '僅管理員可傳送測試通知');

      const admin = h.addAdmin();
      const none = await request('POST', '/api/push/test', { token: h.tokenFor(admin), body: {} });
      assert.strictEqual(none.status, 409);
      assert.strictEqual(none.body.code, 'NO_PUSH_DEVICE');

      h.addDevice(admin, { token: TOKEN });
      const ok = await request('POST', '/api/push/test', { token: h.tokenFor(admin), body: {} });
      assert.strictEqual(ok.status, 200);
      assert.deepStrictEqual(ok.body.data, { devices: 1, delay_seconds: 10 });
      const [notice] = prisma.rows('notifications');
      assert.strictEqual(notice.title, '測試通知');
      assert.strictEqual(notice.related_type, 'push_test');
      assert.ok(new Date(notice.created_at).getTime() > Date.now());
    }],

    ['派送：一般通知在 iOS 帶有 alert 與未讀數徽章', async () => {
      const user = h.addUser();
      h.addDevice(user, { token: TOKEN, platform: 'ios' });
      addNotification(user.user_id, { type: 'order', title: '訂單已成立', content: '請盡快付款', related_type: 'order', related_id: 12 });
      addNotification(user.user_id, { is_read: false, pushed_at: new Date() });

      const sent = await push.dispatchOnce();
      assert.strictEqual(sent, 1);
      assert.strictEqual(h.pushMessages.length, 1);

      const [message] = h.pushMessages;
      assert.strictEqual(message.token, TOKEN);
      assert.deepStrictEqual(message.notification, { title: '訂單已成立', body: '請盡快付款' });
      assert.strictEqual(message.data.type, 'order');
      assert.strictEqual(message.data.related_type, 'order');
      assert.strictEqual(message.data.related_id, '12');
      assert.strictEqual(message.apns.headers['apns-push-type'], 'alert');
      assert.strictEqual(message.apns.payload.aps.badge, 2);
      assert.strictEqual(message.apns.payload.aps['thread-id'], 'order-12');
      assert.strictEqual(message.apns.payload.aps['mutable-content'], undefined);
      assert.strictEqual(message.apns.payload.aps.category, undefined);
      assert.strictEqual(message.android.notification.channel_id, 'savemybook_default');

      // 送出前就先標記已推播，重啟後不會重複推。
      assert.ok(prisma.rows('notifications')[0].pushed_at);
      assert.strictEqual(await push.dispatchOnce(), 0);
    }],

    ['派送：聊天訊息在 iOS 需要 mutable-content 與分類，才能補上頭貼', async () => {
      const user = h.addUser();
      const actor = h.addUser({ nickname: '賣家小美' });
      h.addDevice(user, { token: TOKEN, platform: 'ios' });
      addNotification(user.user_id, {
        type: 'message', title: '新訊息', content: '賣家小美：您好', related_type: 'chat_room', related_id: 5, actor_id: actor.user_id
      });

      await push.dispatchOnce();
      const [message] = h.pushMessages;
      assert.strictEqual(message.apns.payload.aps['mutable-content'], 1);
      assert.strictEqual(message.apns.payload.aps.category, 'CHAT_MESSAGE');
      assert.strictEqual(message.apns.payload.aps['thread-id'], 'chat_room-5');
      assert.strictEqual(message.notification.title, '賣家小美');
      assert.strictEqual(message.data.sender_id, String(actor.user_id));
      assert.strictEqual(message.data.sender_name, '賣家小美');
      assert.strictEqual(message.data.room_type, 'direct');
      assert.strictEqual(message.data.mentioned, '');
    }],

    ['派送：聊天訊息在 Android 改送純資料訊息', async () => {
      const user = h.addUser();
      const actor = h.addUser({ nickname: '賣家小美' });
      h.addDevice(user, { token: TOKEN, platform: 'android' });
      addNotification(user.user_id, {
        type: 'message', title: '新訊息', content: '賣家小美：您好', related_type: 'chat_room', related_id: 5, actor_id: actor.user_id
      });

      await push.dispatchOnce();
      const [message] = h.pushMessages;
      assert.strictEqual(message.notification, undefined);
      assert.strictEqual(message.apns, undefined);
      assert.strictEqual(message.data.title, '賣家小美');
      assert.strictEqual(message.data.body, '賣家小美：您好');
      assert.strictEqual(message.android.priority, 'HIGH');
    }],

    ['派送：群組訊息以群組名稱為標題，提及時標記 mentioned', async () => {
      const user = h.addUser();
      const actor = h.addUser({ nickname: '小美' });
      h.addDevice(user, { token: TOKEN, platform: 'ios' });
      prisma.rows('chat_rooms').push({ room_id: 7, room_type: 'group', name: '交換書社團' });
      addNotification(user.user_id, {
        type: 'message', title: '新訊息', content: '小美 提及了您：記得帶書',
        related_type: 'chat_room', related_id: 7, actor_id: actor.user_id
      });

      await push.dispatchOnce();
      const [message] = h.pushMessages;
      assert.strictEqual(message.notification.title, '交換書社團');
      assert.strictEqual(message.data.room_title, '交換書社團');
      assert.strictEqual(message.data.room_type, 'group');
      assert.strictEqual(message.data.mentioned, '1');
    }],

    ['派送：關閉的通知類型不會送出', async () => {
      const user = h.addUser();
      h.addDevice(user, { token: TOKEN, platform: 'ios' });
      prisma.rows('user_settings').push({
        user_id: user.user_id, notification_order: false, notification_message: true, notification_promo: false
      });
      addNotification(user.user_id, { type: 'order' });
      addNotification(user.user_id, { type: 'reservation' });
      addNotification(user.user_id, { type: 'promotion' });
      addNotification(user.user_id, { type: 'message' });
      addNotification(user.user_id, { type: 'system' });

      await push.dispatchOnce();
      assert.deepStrictEqual(h.pushMessages.map((m) => m.data.type), ['message', 'system']);
    }],

    ['派送：靜音的聊天室只在被提及時推播', async () => {
      const user = h.addUser();
      const actor = h.addUser({ nickname: '小美' });
      h.addDevice(user, { token: TOKEN, platform: 'ios' });
      prisma.rows('chat_rooms').push({ room_id: 7, room_type: 'group', name: '交換書社團' });
      prisma.rows('chat_room_mutes').push({ user_id: user.user_id, room_id: 7 });
      addNotification(user.user_id, {
        type: 'message', title: '新訊息', content: '小美：閒聊', related_type: 'chat_room', related_id: 7, actor_id: actor.user_id
      });
      addNotification(user.user_id, {
        type: 'message', title: '新訊息', content: '小美 提及了您：記得帶書', related_type: 'chat_room', related_id: 7, actor_id: actor.user_id
      });

      await push.dispatchOnce();
      assert.strictEqual(h.pushMessages.length, 1);
      assert.strictEqual(h.pushMessages[0].data.mentioned, '1');
    }],

    ['派送：停權或黑名單的帳號不會收到推播', async () => {
      const blocked = h.addUser({ isBlacklisted: true });
      const suspended = h.addUser({ isActive: false });
      const normal = h.addUser();
      h.addDevice(blocked, { token: `fcm-1-${'e'.repeat(30)}` });
      h.addDevice(suspended, { token: `fcm-2-${'e'.repeat(30)}` });
      h.addDevice(normal, { token: TOKEN });
      for (const user of [blocked, suspended, normal]) addNotification(user.user_id);

      await push.dispatchOnce();
      assert.deepStrictEqual(h.pushMessages.map((m) => m.token), [TOKEN]);
    }],

    ['派送：同一位使用者的多台裝置都會收到', async () => {
      const user = h.addUser();
      h.addDevice(user, { token: TOKEN, platform: 'ios' });
      h.addDevice(user, { token: `fcm-2-${'f'.repeat(30)}`, platform: 'android' });
      addNotification(user.user_id);

      await push.dispatchOnce();
      assert.strictEqual(h.pushMessages.length, 2);
    }],

    ['派送：FCM 回報 token 失效時會刪掉該裝置', async () => {
      const user = h.addUser();
      h.addDevice(user, { token: TOKEN, platform: 'ios' });
      h.addDevice(user, { token: `fcm-ok-${'g'.repeat(30)}`, platform: 'ios' });
      addNotification(user.user_id);

      h.queuePush(
        { status: 404, body: { error: { status: 'NOT_FOUND', message: 'Requested entity was not found.' } } },
        { body: { name: 'ok' } }
      );
      await push.dispatchOnce();

      const tokens = prisma.rows('push_devices').map((d) => d.token);
      assert.strictEqual(tokens.length, 1);
      assert.ok(!tokens.includes(TOKEN));
      assert.strictEqual(push.retryQueue.length, 0);
    }],

    ['派送：暫時性失敗會排入重試佇列，裝置已移除時不再補送', async () => {
      const user = h.addUser();
      h.addDevice(user, { token: TOKEN, platform: 'ios' });
      addNotification(user.user_id);

      h.queuePush({ status: 503, body: { error: { status: 'UNAVAILABLE', message: '暫時無法使用' } } });
      await push.dispatchOnce();
      assert.strictEqual(push.retryQueue.length, 1);
      assert.strictEqual(prisma.rows('push_devices').length, 1);

      push.retryQueue[0].dueAt = Date.now() - 1;
      prisma.store.push_devices = [];
      const retried = await push.dispatchRetries();
      assert.strictEqual(retried, 1);
      assert.strictEqual(h.pushMessages.length, 1);
      assert.strictEqual(push.retryQueue.length, 0);
    }],

    ['派送：重試成功後不再排入佇列', async () => {
      const user = h.addUser();
      h.addDevice(user, { token: TOKEN, platform: 'ios' });
      addNotification(user.user_id);

      h.queuePush({ status: 500, body: { error: { status: 'INTERNAL' } } });
      await push.dispatchOnce();
      assert.strictEqual(push.retryQueue.length, 1);

      push.retryQueue[0].dueAt = Date.now() - 1;
      await push.dispatchRetries();
      assert.strictEqual(h.pushMessages.length, 2);
      assert.strictEqual(push.retryQueue.length, 0);
    }],

    ['派送：沒有登記裝置時不會送出任何訊息', async () => {
      const user = h.addUser();
      addNotification(user.user_id);
      const sent = await push.dispatchOnce();
      assert.strictEqual(sent, 1);
      assert.strictEqual(h.pushMessages.length, 0);
    }]
  ]
};
