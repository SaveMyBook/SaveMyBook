const assert = require('assert');
const h = require('./harness');
const { prisma, write, missing, uploadsFs, nextName } = h;

const guard = h.api('middleware/uploads-guard');

const through = (body) => {
  let sent = null;
  const res = { json: (value) => { sent = value; return value; } };
  guard.uploadsGuard({}, res, () => {});
  res.json(body);
  return sent;
};

const settle = () => new Promise((resolve) => setTimeout(resolve, 0));

const tests = [
  ['檔案存在時原樣回傳', () => {
    const url = write(`avatars/${nextName()}`);
    assert.deepStrictEqual(through({ data: { avatar_url: url } }), { data: { avatar_url: url } });
  }],

  ['檔案不存在時回傳 null', () => {
    const url = missing(`avatars/${nextName()}`);
    assert.strictEqual(through({ data: { avatar_url: url } }).data.avatar_url, null);
  }],

  ['圖片清單中失效的項目會被移除', () => {
    const ok = write(`books/${nextName()}`);
    const gone = missing(`books/${nextName()}`);
    const body = { data: { book_images: [{ image_url: gone }, { image_url: ok }] } };
    const out = through(body);
    assert.deepStrictEqual(out.data.book_images.map((i) => i.image_url), [ok]);
  }],

  ['巢狀結構也會處理', () => {
    const gone = missing(`avatars/${nextName()}`);
    const out = through({ data: { rows: [{ users: { avatar_url: gone, nickname: '甲' } }] } });
    assert.strictEqual(out.data.rows[0].users.avatar_url, null);
    assert.strictEqual(out.data.rows[0].users.nickname, '甲');
  }],

  ['外部網址與一般文字不受影響', () => {
    const body = { data: { avatar_url: 'https://example.com/a.png', content: '/uploads/chat/x.jpg 這是訊息內容' } };
    assert.deepStrictEqual(through(body), body);
  }],

  ['路徑穿越的網址一律視為失效', () => {
    assert.strictEqual(through({ data: { image_url: '/uploads/../../etc/passwd' } }).data.image_url, null);
  }],

  ['大頭貼失效會在背景清空欄位', async () => {
    const url = missing(`avatars/${nextName()}`);
    prisma.rows('users').push({ user_id: 1, avatar_url: url, nickname: '甲' });
    through({ data: { avatar_url: url } });
    await settle();
    assert.strictEqual(prisma.rows('users')[0].avatar_url, null);
  }],

  ['書籍圖片失效會刪除該筆圖片', async () => {
    const url = missing(`books/${nextName()}`);
    prisma.rows('book_images').push({ image_id: 1, book_id: 7, image_url: url });
    through({ data: { book_images: [{ image_url: url }] } });
    await settle();
    assert.strictEqual(prisma.rows('book_images').length, 0);
  }],

  ['群組頭貼失效會清空聊天室欄位', async () => {
    const url = missing(`chat/${nextName()}`);
    prisma.rows('chat_rooms').push({ room_id: 3, avatar_url: url });
    through({ data: { room: { avatar_url: url } } });
    await settle();
    assert.strictEqual(prisma.rows('chat_rooms')[0].avatar_url, null);
  }],

  ['檔案存在的結果會被快取，不重複檢查磁碟', () => {
    const url = write(`avatars/${nextName()}`);
    assert.strictEqual(uploadsFs.exists(url), true);
    require('fs').unlinkSync(require('path').join(h.root, url.slice('/uploads/'.length)));
    // 仍在快取有效期內，因此維持 true；剛上傳完的檔案才不會被誤判為失效。
    assert.strictEqual(uploadsFs.exists(url), true);
    uploadsFs.forget(url);
    assert.strictEqual(uploadsFs.exists(url), false);
  }]
];

module.exports = { name: '圖片檔案遺失時的處理', tests };
