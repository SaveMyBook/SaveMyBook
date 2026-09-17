const assert = require('assert');
const {
  request, addUser, addBook, addImage, tokenFor, bookOf, prisma, reviewOf, notificationsOf, fetchLog,
  enableModeration, stubModeration, failModeration, api
} = require('./harness');

const screening = api('services/listing-screening');

const seller = () => {
  const user = addUser({ nickname: '賣家' });
  return { user, token: tokenFor(user) };
};

const create = (token, body = {}) => request('POST', '/api/books', {
  token, body: { title: '小王子', price: 200, ...body }
});

const screened = () => fetchLog.filter((f) => f.url.startsWith('https://api.deepseek.com')).length;

const gifForm = (field, count = 1) => {
  const form = new FormData();
  const bytes = Buffer.concat([Buffer.from('GIF89a', 'latin1'), Buffer.alloc(24, 1)]);
  for (let i = 0; i < count; i += 1) {
    form.append(field, new Blob([bytes], { type: 'image/gif' }), `book-${i}.gif`);
  }
  return form;
};

const tests = [
  ['AI 審核未啟用時不呼叫服務商，直接上架', async () => {
    const { token } = seller();
    const res = await create(token);

    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.data.is_approved, true);
    assert.strictEqual(screened(), 0);
    assert.strictEqual(prisma.rows('ai_book_reviews').length, 0);
  }],

  ['上架不等待 AI 審核：先回應成功，背景判定需人工審核時撤下並通知賣家與管理員', async () => {
    const { user, token } = seller();
    const admin = addUser({ nickname: '管理員', role: 'admin' });
    enableModeration();
    stubModeration({ verdict: 'review', confidence: 0.5, reasons: ['書名與描述疑似不符'], categories: ['misleading'] });

    const res = await create(token);
    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.message, '書籍上架成功');
    assert.strictEqual(res.body.data.is_approved, true);
    assert.strictEqual(res.body.moderation, undefined);

    await screening.settled();
    const bookId = res.body.data.book_id;
    assert.strictEqual(bookOf(bookId).is_approved, false);
    const review = reviewOf(bookId);
    assert.strictEqual(review.status, 'pending');
    assert.strictEqual(review.verdict, 'review');

    const notice = notificationsOf(user.user_id)[0];
    assert.strictEqual(notice.title, '書籍已送交審核');
    assert.strictEqual(notice.content, '您的書籍《小王子》已送交審核，審核通過後將公開販售。');
    const adminNotice = notificationsOf(admin.user_id)[0];
    assert.strictEqual(adminNotice.related_type, 'book_review');
    assert.strictEqual(adminNotice.content, '《小王子》需要人工審核：書名與描述疑似不符');
  }],

  ['處理方式為封鎖且信心足夠時，背景審核直接下架並通知賣家', async () => {
    const { user, token } = seller();
    enableModeration({ action: 'block' });
    stubModeration({ verdict: 'reject', confidence: 0.95, reasons: ['非書籍商品', '疑似盜版'], categories: ['not_book'] });

    const res = await create(token);
    assert.strictEqual(res.status, 201);
    await screening.settled();

    const book = bookOf(res.body.data.book_id);
    assert.strictEqual(book.status, 'removed');
    assert.strictEqual(book.is_approved, false);
    assert.strictEqual(reviewOf(book.book_id).status, 'rejected');
    const notice = notificationsOf(user.user_id)[0];
    assert.strictEqual(notice.title, '書籍未通過上架審核');
    assert.ok(notice.content.includes('非書籍商品、疑似盜版'));
  }],

  ['信心不足時即使判定違規也只送交人工審核', async () => {
    const { token } = seller();
    enableModeration({ action: 'block' });
    stubModeration({ verdict: 'reject', confidence: 0.5, reasons: ['疑似非書籍'], categories: ['not_book'] });

    const res = await create(token);
    await screening.settled();
    assert.strictEqual(bookOf(res.body.data.book_id).status, 'on_sale');
    assert.strictEqual(bookOf(res.body.data.book_id).is_approved, false);
    assert.strictEqual(reviewOf(res.body.data.book_id).status, 'pending');
  }],

  ['處理方式為人工審核時，違規判定不會直接下架', async () => {
    const { token } = seller();
    enableModeration({ action: 'review' });
    stubModeration({ verdict: 'reject', confidence: 1, reasons: ['非書籍商品'], categories: ['not_book'] });

    const res = await create(token);
    await screening.settled();
    assert.strictEqual(bookOf(res.body.data.book_id).status, 'on_sale');
    assert.strictEqual(bookOf(res.body.data.book_id).is_approved, false);
  }],

  ['服務商錯誤時採放行策略，不阻擋上架', async () => {
    const { token } = seller();
    enableModeration({ action: 'block' });
    failModeration(401);

    const res = await create(token);
    await screening.settled();
    assert.strictEqual(res.status, 201);
    assert.strictEqual(bookOf(res.body.data.book_id).is_approved, true);
    assert.ok(screened() > 0, '應確實呼叫過服務商');
    assert.strictEqual(prisma.rows('ai_book_reviews').length, 0);
  }],

  ['模型回傳無法解析時同樣放行', async () => {
    const { token } = seller();
    enableModeration({ action: 'block' });
    stubModeration('不是 JSON');

    const res = await create(token);
    await screening.settled();
    assert.strictEqual(bookOf(res.body.data.book_id).is_approved, true);
  }],

  ['售價異常高時即時送審，不需 AI 也會通知管理員', async () => {
    const { user, token } = seller();
    const admin = addUser({ nickname: '管理員', role: 'admin' });

    const res = await create(token, { price: 5000 });
    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.message, '書籍已送交審核，審核通過後將公開販售');
    assert.strictEqual(res.body.data.is_approved, false);
    assert.deepStrictEqual(res.body.moderation.reasons, ['售價 5000 代幣明顯高於一般二手書行情']);
    assert.strictEqual(screened(), 0);
    assert.strictEqual(reviewOf(res.body.data.book_id).model, 'rules');
    assert.strictEqual(notificationsOf(user.user_id)[0].title, '書籍已送交審核');
    assert.strictEqual(notificationsOf(admin.user_id)[0].related_type, 'book_review');
  }],

  ['售價遠高於站上同 ISBN 書籍時送審，合理範圍內則正常上架', async () => {
    const { token } = seller();
    const other = addUser();
    addBook({ sellerId: other.user_id, isbn: '9789571234567', price: 200 });
    addBook({ sellerId: other.user_id, isbn: '9789571234567', price: 240 });

    const high = await create(token, { isbn: '9789571234567', price: 900 });
    assert.strictEqual(high.body.data.is_approved, false);
    assert.deepStrictEqual(high.body.moderation.reasons, ['售價明顯高於站上同書行情（約 220 代幣）']);

    const fair = await create(token, { isbn: '9789571234567', price: 350 });
    assert.strictEqual(fair.body.data.is_approved, true);
    assert.strictEqual(fair.body.moderation, undefined);
  }],

  ['描述提及圖書館館藏等非正規來源時送審', async () => {
    const { token } = seller();
    const res = await create(token, { description: '學校圖書館淘汰書，封底有館藏條碼' });
    assert.strictEqual(res.body.data.is_approved, false);
    assert.deepStrictEqual(res.body.moderation.reasons, ['疑似圖書館館藏或非正規來源書籍']);
  }],

  ['調高售價到異常價格時送審', async () => {
    const { user, token } = seller();
    const book = addBook({ sellerId: user.user_id, price: 300 });
    const res = await request('PUT', `/api/books/${book.book_id}`, { token, body: { price: 8000 } });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(bookOf(book.book_id).is_approved, false);
    assert.strictEqual(reviewOf(book.book_id).status, 'pending');
  }],

  ['修改書名會重新送審', async () => {
    const { user, token } = seller();
    const book = addBook({ sellerId: user.user_id, title: '小王子' });
    addImage(book.book_id);
    enableModeration();
    stubModeration({ verdict: 'review', confidence: 0.6, reasons: ['需人工確認'] });

    const res = await request('PUT', `/api/books/${book.book_id}`, { token, body: { title: '限量帳號代購' } });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.message, '書籍資料已更新並送交審核，審核通過後將公開販售');
    assert.strictEqual(bookOf(book.book_id).is_approved, false);
    assert.strictEqual(reviewOf(book.book_id).status, 'pending');
    assert.strictEqual(notificationsOf(user.user_id).length, 1);
  }],

  ['只改價格不會送審', async () => {
    const { user, token } = seller();
    const book = addBook({ sellerId: user.user_id, price: 300 });
    enableModeration();
    stubModeration({ verdict: 'review', confidence: 0.6, reasons: ['需人工確認'] });

    const res = await request('PUT', `/api/books/${book.book_id}`, { token, body: { price: 280 } });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(screened(), 0);
    assert.strictEqual(bookOf(book.book_id).is_approved, true);
  }],

  ['已在審核中的書籍再次編輯不會重複通知賣家', async () => {
    const { user, token } = seller();
    const book = addBook({ sellerId: user.user_id, is_approved: false });
    prisma.rows('ai_book_reviews').push({ book_id: book.book_id, status: 'pending', verdict: 'review' });
    enableModeration();
    stubModeration({ verdict: 'review', confidence: 0.6, reasons: ['需人工確認'] });

    const res = await request('PUT', `/api/books/${book.book_id}`, { token, body: { title: '換個書名' } });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(reviewOf(book.book_id).status, 'pending');
    assert.strictEqual(notificationsOf(user.user_id).length, 0);
  }],

  ['違規遭下架的書籍編輯後不會被改成審核中', async () => {
    const { user, token } = seller();
    const book = addBook({ sellerId: user.user_id, status: 'removed', is_approved: false });
    enableModeration();
    stubModeration({ verdict: 'review', confidence: 0.6, reasons: ['需人工確認'] });

    const res = await request('PUT', `/api/books/${book.book_id}`, { token, body: { title: '換個書名' } });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.moderation, undefined);
    // 轉成待審核會讓賣家得以自行重新上架，違規鎖定必須維持。
    assert.strictEqual(prisma.rows('ai_book_reviews').length, 0);
    assert.strictEqual(bookOf(book.book_id).is_approved, false);
  }],

  ['審核中的書籍編輯後若判定可上架則自動放行', async () => {
    const { user, token } = seller();
    const book = addBook({ sellerId: user.user_id, is_approved: false });
    prisma.rows('ai_book_reviews').push({ book_id: book.book_id, status: 'pending', verdict: 'review' });
    enableModeration();
    stubModeration({ verdict: 'allow', confidence: 1 });

    const res = await request('PUT', `/api/books/${book.book_id}`, { token, body: { title: '正常書名' } });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(bookOf(book.book_id).is_approved, true);
    assert.strictEqual(reviewOf(book.book_id).status, 'approved');
  }],

  ['新增圖片會送審，遭拒時回 422 且不寫入圖片', async () => {
    const { user, token } = seller();
    const book = addBook({ sellerId: user.user_id });
    enableModeration({ action: 'block' });
    stubModeration({ verdict: 'reject', confidence: 0.99, reasons: ['成人內容'], categories: ['adult'] });

    const res = await request('POST', `/api/books/${book.book_id}/images`, { token, raw: gifForm('images') });
    assert.strictEqual(res.status, 422);
    assert.strictEqual(res.body.code, 'LISTING_REJECTED');
    assert.strictEqual(res.body.message, '此商品未通過上架審核：成人內容');
    assert.strictEqual(prisma.rows('book_images').length, 0);
    assert.strictEqual(notificationsOf(user.user_id).length, 0);
  }],

  ['每本書最多 10 張照片', async () => {
    const { user, token } = seller();
    const book = addBook({ sellerId: user.user_id });
    for (let i = 0; i < 9; i += 1) addImage(book.book_id);

    const res = await request('POST', `/api/books/${book.book_id}/images`, { token, raw: gifForm('images', 2) });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.message, '每本書最多 10 張照片，目前已有 9 張');
    assert.strictEqual(prisma.rows('book_images').length, 9);
  }]
];

module.exports = { name: 'AI 上架審核', tests };
