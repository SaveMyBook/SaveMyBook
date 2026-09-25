const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { registerModels } = require('../lib/fake-prisma');
const {
  request, addUser, addAdmin, addTicket, tokenFor, notificationsOf, prisma, api
} = require('./harness');

registerModels({ autoKeys: { support_ticket_attachments: 'attachment_id' } });

const { UPLOAD_ROOT } = api('lib/upload');
const attachments = api('services/support-attachments');
const SUPPORT_DIR = path.join(UPLOAD_ROOT, 'support');

let seq = 0;
const pending = (uploader, overrides = {}) => {
  seq += 1;
  const row = {
    attachment_id: prisma.nextId('support_ticket_attachments'),
    message_id: null,
    uploader_id: uploader.user_id,
    url: `/uploads/support/${Date.now()}-${String(seq).padStart(16, '0')}.jpg`,
    byte_size: 1024,
    sort_order: 0,
    created_at: new Date(),
    ...overrides
  };
  prisma.rows('support_ticket_attachments').push(row);
  return row;
};

const JPEG = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(64, 1)]);

const tests = [
  ['上傳客服圖片：記錄上傳者', async () => {
    const user = addUser();
    const token = tokenFor(user);
    const form = new FormData();
    form.append('file', new Blob([JPEG], { type: 'image/jpeg' }), 'photo.jpg');

    const res = await request('POST', '/api/uploads/support-image', { token, raw: form });
    try {
      assert.strictEqual(res.status, 201);
      assert.match(res.body.data.url, /^\/uploads\/support\/[\w-]+\.jpg$/);
      const row = prisma.rows('support_ticket_attachments')[0];
      assert.strictEqual(row.uploader_id, user.user_id);
      assert.strictEqual(row.url, res.body.data.url);
      assert.strictEqual(row.message_id ?? null, null);
    } finally {
      if (res.body?.data?.url) fs.rmSync(path.join(UPLOAD_ROOT, res.body.data.url.slice('/uploads/'.length)), { force: true });
    }
  }],

  ['上傳客服圖片：未送出的圖片達上限時拒收', async () => {
    const user = addUser();
    for (let i = 0; i < 20; i += 1) pending(user);
    const data = new FormData();
    data.append('file', new Blob([JPEG], { type: 'image/jpeg' }), 'photo.jpg');

    const res = await request('POST', '/api/uploads/support-image', { token: tokenFor(user), raw: data });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.code, 'SUPPORT_ATTACHMENTS_PENDING_LIMIT');
  }],

  ['開立工單可附加圖片，通知客服時註明張數', async () => {
    const user = addUser();
    const staff = addAdmin();
    const [a, b] = [pending(user), pending(user)];

    const res = await request('POST', '/api/support/tickets', {
      token: tokenFor(user),
      body: { subject: '無法登入', content: '畫面如附圖', attachments: [b.url, a.url] }
    });
    assert.strictEqual(res.status, 201);

    const message = prisma.rows('support_ticket_messages')[0];
    assert.strictEqual(a.message_id, message.message_id);
    assert.strictEqual(b.message_id, message.message_id);
    assert.deepStrictEqual([b.sort_order, a.sort_order], [0, 1]);
    assert.strictEqual(notificationsOf(staff.user_id)[0].content, '「無法登入」等待處理，附 2 張圖片。');
  }],

  ['附件驗證：格式、數量、重複、他人上傳與已使用的圖片皆拒收', async () => {
    const user = addUser();
    const other = addUser();
    const token = tokenFor(user);
    const create = (list) => request('POST', '/api/support/tickets', {
      token, body: { subject: '主旨', content: '內容說明', attachments: list }
    });

    const notArray = await create('/uploads/support/a.jpg');
    assert.strictEqual(notArray.body.message, '附件格式不正確');

    const foreignFolder = await create(['/uploads/chat/1-abc.jpg']);
    assert.strictEqual(foreignFolder.status, 400);
    assert.strictEqual(foreignFolder.body.message, '圖片請先透過 /api/uploads/support-image 上傳');

    const tooMany = await create([1, 2, 3, 4, 5].map(() => pending(user).url));
    assert.strictEqual(tooMany.body.message, '每則訊息最多附加 4 張圖片');

    const mine = pending(user);
    const duplicated = await create([mine.url, mine.url]);
    assert.strictEqual(duplicated.body.message, '附件不可重複');

    const theirs = pending(other);
    const stolen = await create([theirs.url]);
    assert.strictEqual(stolen.status, 400);
    assert.strictEqual(stolen.body.code, 'SUPPORT_ATTACHMENT_INVALID');

    const used = pending(user, { message_id: 99 });
    const reused = await create([used.url]);
    assert.strictEqual(reused.body.code, 'SUPPORT_ATTACHMENT_INVALID');

    assert.strictEqual(prisma.rows('support_tickets').length, 0);
    assert.strictEqual(theirs.message_id, null);
  }],

  ['回覆可只附圖片；客服也能附加自己上傳的圖片', async () => {
    const user = addUser();
    const staff = addAdmin();
    const ticket = addTicket({ userId: user.user_id });

    const photo = pending(user);
    const onlyImage = await request('POST', `/api/support/tickets/${ticket.ticket_id}/messages`, {
      token: tokenFor(user), body: { content: '', attachments: [photo.url] }
    });
    assert.strictEqual(onlyImage.status, 201);
    assert.strictEqual(notificationsOf(staff.user_id)[0].content, '工單「無法登入」有新的回覆，附 1 張圖片。');

    const staffPhoto = pending(staff);
    const byStaff = await request('POST', `/api/support/tickets/${ticket.ticket_id}/messages`, {
      token: tokenFor(staff), body: { content: '請參考標示處', attachments: [staffPhoto.url] }
    });
    assert.strictEqual(byStaff.status, 201);
    const staffMessage = prisma.rows('support_ticket_messages').find((m) => m.is_staff);
    assert.strictEqual(staffPhoto.message_id, staffMessage.message_id);

    const list = await request('GET', '/api/admin/tickets', { token: tokenFor(staff) });
    assert.ok(list.body.data[0].last_message);
  }],

  ['工單內容回傳簽章網址，僅本人與客服可取得；網址可讀取圖片且無法竄改', async () => {
    const user = addUser();
    const stranger = addUser();
    const staff = addAdmin();
    const ticket = addTicket({ userId: user.user_id });
    prisma.rows('support_ticket_messages').push({
      message_id: 1, ticket_id: ticket.ticket_id, sender_id: user.user_id, is_staff: false, content: '附圖', created_at: new Date()
    });
    const file = `${Date.now()}-0123456789abcdef.jpg`;
    pending(user, { url: `/uploads/support/${file}`, message_id: 1 });
    fs.mkdirSync(SUPPORT_DIR, { recursive: true });
    fs.writeFileSync(path.join(SUPPORT_DIR, file), JPEG);

    try {
      const mine = await request('GET', `/api/support/tickets/${ticket.ticket_id}`, { token: tokenFor(user) });
      const [attachment] = mine.body.data.messages[0].attachments;
      assert.match(attachment.url, new RegExp(`^/api/support/attachments/${file}\\?exp=\\d+&sig=[\\w-]{32}$`));
      assert.strictEqual(Object.keys(attachment).join(), 'url');

      const byStaff = await request('GET', `/api/support/tickets/${ticket.ticket_id}`, { token: tokenFor(staff) });
      assert.strictEqual(byStaff.body.data.messages[0].attachments.length, 1);

      const denied = await request('GET', `/api/support/tickets/${ticket.ticket_id}`, { token: tokenFor(stranger) });
      assert.strictEqual(denied.status, 403);

      const image = await request('GET', attachment.url);
      assert.strictEqual(image.status, 200);
      assert.strictEqual(image.headers.get('content-type'), 'image/jpeg');
      assert.match(image.headers.get('cache-control'), /^private, max-age=\d+$/);

      const tampered = await request('GET', attachment.url.replace(/sig=[\w-]+/, `sig=${'A'.repeat(32)}`));
      assert.strictEqual(tampered.status, 404);

      const expired = attachment.url.replace(/exp=\d+/, `exp=${Math.floor(Date.now() / 1000) - 10}`);
      assert.strictEqual((await request('GET', expired)).status, 404);

      const plain = await request('GET', `/api/support/attachments/${file}`);
      assert.strictEqual(plain.status, 404);
    } finally {
      fs.rmSync(path.join(SUPPORT_DIR, file), { force: true });
    }
  }],

  ['排程清理超過 24 小時未送出的圖片，已送出的保留', async () => {
    const user = addUser();
    const stale = pending(user, { created_at: new Date(Date.now() - 25 * 3600 * 1000) });
    const fresh = pending(user);
    const sent = pending(user, { message_id: 5, created_at: new Date(Date.now() - 48 * 3600 * 1000) });

    assert.strictEqual(await attachments.purgeStale(), 1);
    const urls = prisma.rows('support_ticket_attachments').map((r) => r.url);
    assert.deepStrictEqual(urls.sort(), [fresh.url, sent.url].sort());
    assert.ok(!urls.includes(stale.url));
  }]
];

module.exports = { name: '客服工單圖片附件', tests };
