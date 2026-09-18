const assert = require('assert');
const fs = require('fs');
const path = require('path');
const h = require('./harness');

const { prisma } = h;
const account = h.api('services/account');
const { UPLOAD_ROOT } = h.api('lib/upload');

// 迷你 SQL 直譯器不支援 JOIN，依工單擁有者與上傳者自行篩選。
prisma.onSql(/FROM support_ticket_attachments a LEFT JOIN support_ticket_messages m/, (sql, [uploaderId, ownerId]) => {
  const owners = new Map(prisma.rows('support_tickets').map((t) => [t.ticket_id, t.user_id]));
  const ticketOf = new Map(prisma.rows('support_ticket_messages').map((m) => [m.message_id, m.ticket_id]));
  return prisma.rows('support_ticket_attachments')
    .filter((a) => a.uploader_id === uploaderId || owners.get(ticketOf.get(a.message_id)) === ownerId)
    .map((a) => ({ url: a.url }));
});

const attachment = (row) => prisma.rows('support_ticket_attachments').push({
  byte_size: 10, sort_order: 0, created_at: new Date(), message_id: null, ...row
});

module.exports = {
  name: '平台：客服附件的匯出與匿名化',
  tests: [
    ['資料匯出：工單訊息附上效期七天的附件網址', async () => {
      const user = h.addUser();
      prisma.rows('support_tickets').push({
        ticket_id: 1, user_id: user.user_id, subject: '無法取件',
        messages: [{ message_id: 11, content: '附圖' }, { message_id: 12, content: '補充' }]
      });
      attachment({ attachment_id: 1, message_id: 11, uploader_id: user.user_id, url: '/uploads/support/1-aaaa.jpg' });

      const data = await account.exportData(user.user_id);
      const [first, second] = data.support_tickets[0].messages;
      assert.strictEqual(first.attachments.length, 1);
      const exp = Number(/exp=(\d+)/.exec(first.attachments[0].url)[1]);
      assert.ok(exp - Date.now() / 1000 > 6 * 86400);
      assert.deepStrictEqual(second.attachments, []);
    }],

    ['資料匯出：尚未執行 017 時附件為空陣列', async () => {
      h.reset({ schema: h.without(h.FULL_SCHEMA, ['support_ticket_attachments']) });
      const user = h.addUser();
      prisma.rows('support_tickets').push({ ticket_id: 1, user_id: user.user_id, messages: [{ message_id: 1 }] });
      const data = await account.exportData(user.user_id);
      assert.deepStrictEqual(data.support_tickets[0].messages[0].attachments, []);
    }],

    ['匿名化：移除本人上傳與本人工單內的附件檔案', async () => {
      const user = h.addUser();
      const staff = h.addUser({ role: 'admin' });
      const other = h.addUser();
      user.deletion_requested_at = new Date(Date.now() - 31 * 86400000);

      prisma.rows('support_tickets').push({ ticket_id: 1, user_id: user.user_id });
      prisma.rows('support_tickets').push({ ticket_id: 2, user_id: other.user_id });
      prisma.store.support_ticket_messages = [
        { message_id: 1, ticket_id: 1, sender_id: user.user_id },
        { message_id: 2, ticket_id: 1, sender_id: staff.user_id },
        { message_id: 3, ticket_id: 2, sender_id: staff.user_id }
      ];
      const dir = path.join(UPLOAD_ROOT, 'support');
      fs.mkdirSync(dir, { recursive: true });
      const names = ['9-mine.jpg', '9-staff.jpg', '9-other.jpg', '9-pending.jpg'].map((n) => `${Date.now()}${n}`);
      for (const name of names) fs.writeFileSync(path.join(dir, name), 'x');

      attachment({ attachment_id: 1, message_id: 1, uploader_id: user.user_id, url: `/uploads/support/${names[0]}` });
      attachment({ attachment_id: 2, message_id: 2, uploader_id: staff.user_id, url: `/uploads/support/${names[1]}` });
      attachment({ attachment_id: 3, message_id: 3, uploader_id: staff.user_id, url: `/uploads/support/${names[2]}` });
      attachment({ attachment_id: 4, uploader_id: user.user_id, url: `/uploads/support/${names[3]}` });

      try {
        assert.strictEqual(await account.processDueDeletions(), 1);
        assert.deepStrictEqual(prisma.rows('support_ticket_attachments').map((a) => a.attachment_id), [3]);
        await new Promise((resolve) => setTimeout(resolve, 20));
        assert.deepStrictEqual(names.map((n) => fs.existsSync(path.join(dir, n))), [false, false, true, false]);
      } finally {
        for (const name of names) fs.rmSync(path.join(dir, name), { force: true });
      }
    }]
  ]
};
