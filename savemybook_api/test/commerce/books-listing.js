const assert = require('assert');
const {
  request, addUser, addBook, addImage, addCategory, addCabinet, tokenFor, bookOf, prisma, notificationsOf, flush
} = require('./harness');

const seller = () => {
  const user = addUser({ nickname: '賣家' });
  return { user, token: tokenFor(user) };
};

const create = (token, body) => request('POST', '/api/books', { token, body });

const tests = [
  ['缺少書名或價格時回 400', async () => {
    const { token } = seller();
    const noTitle = await create(token, { price: 100 });
    assert.strictEqual(noTitle.status, 400);
    assert.strictEqual(noTitle.body.message, '缺少必要欄位：書名(title) 或 價格(price)');

    const noPrice = await create(token, { title: '小王子' });
    assert.strictEqual(noPrice.status, 400);
  }],

  ['售價必須大於 0 且不可超過 99999', async () => {
    const { token } = seller();
    const zero = await create(token, { title: '小王子', price: 0 });
    assert.strictEqual(zero.status, 400);
    assert.strictEqual(zero.body.message, '售價必須大於 0');

    const tooHigh = await create(token, { title: '小王子', price: 100000 });
    assert.strictEqual(tooHigh.status, 400);
    assert.strictEqual(tooHigh.body.message, '售價不可超過 99,999 代幣');
  }],

  ['ISBN 只接受數字並正規化為大寫、去除連字號', async () => {
    const { token } = seller();
    const bad = await create(token, { title: '小王子', price: 100, isbn: 'ABC-123' });
    assert.strictEqual(bad.status, 400);
    assert.strictEqual(bad.body.message, 'ISBN 只能包含數字，且不超過 13 碼');

    const ok = await create(token, { title: '小王子', price: 100, isbn: '978-986-1234x' });
    assert.strictEqual(ok.status, 201);
    assert.strictEqual(ok.body.data.isbn, '9789861234X');
  }],

  ['不支援的書況回 400，未指定時預設為 good', async () => {
    const { token } = seller();
    const bad = await create(token, { title: '小王子', price: 100, condition_level: 'mint' });
    assert.strictEqual(bad.status, 400);
    assert.strictEqual(bad.body.message, '不支援的書況');

    const ok = await create(token, { title: '小王子', price: 100 });
    assert.strictEqual(ok.body.data.condition_level, 'good');
  }],

  ['分類不存在或書櫃已停用時回 400', async () => {
    const { token } = seller();
    const noCategory = await create(token, { title: '小王子', price: 100, category_id: 999 });
    assert.strictEqual(noCategory.status, 400);
    assert.strictEqual(noCategory.body.message, '找不到此分類');

    const cabinet = addCabinet({ isActive: false });
    const disabled = await create(token, { title: '小王子', price: 100, cabinet_id: cabinet.cabinet_id });
    assert.strictEqual(disabled.status, 400);
    assert.strictEqual(disabled.body.message, '找不到此書櫃，或書櫃已停用');
  }],

  ['上架成功後為上架中、已審核，且屬於當前賣家', async () => {
    const { user, token } = seller();
    const category = addCategory();
    const cabinet = addCabinet();

    const res = await create(token, {
      title: '小王子',
      price: 250,
      author: '聖修伯里',
      publish_date: '2020-',
      category_id: category.category_id,
      cabinet_id: cabinet.cabinet_id
    });

    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.message, '書籍上架成功');
    assert.strictEqual(res.body.data.status, 'on_sale');
    assert.strictEqual(res.body.data.is_approved, true);
    assert.strictEqual(res.body.data.seller_id, user.user_id);
    assert.strictEqual(res.body.data.quantity, 1);
    // 只到年份的出版日期會被送成 "2020-"，須去掉尾端的連字號。
    assert.strictEqual(res.body.data.publish_date, '2020');
    assert.strictEqual(res.body.moderation, undefined);
  }],

  ['未登入無法上架', async () => {
    const res = await request('POST', '/api/books', { body: { title: '小王子', price: 100 } });
    assert.strictEqual(res.status, 401);
  }],

  ['不可修改他人的書籍', async () => {
    const owner = addUser();
    const other = addUser();
    const book = addBook({ sellerId: owner.user_id });

    const res = await request('PUT', `/api/books/${book.book_id}`, {
      token: tokenFor(other), body: { price: 50 }
    });
    assert.strictEqual(res.status, 403);
    assert.strictEqual(res.body.message, '存取被拒，您無權限修改他人的商品');
  }],

  ['書名不可改為空字串', async () => {
    const { user, token } = seller();
    const book = addBook({ sellerId: user.user_id });

    const res = await request('PUT', `/api/books/${book.book_id}`, { token, body: { title: '   ' } });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.message, '書名不可為空');
  }],

  ['賣家只能將狀態設為上架或下架', async () => {
    const { user, token } = seller();
    const book = addBook({ sellerId: user.user_id });

    const res = await request('PUT', `/api/books/${book.book_id}`, { token, body: { status: 'sold' } });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.message, '不支援的書籍狀態');

    const ok = await request('PUT', `/api/books/${book.book_id}`, { token, body: { status: 'removed' } });
    assert.strictEqual(ok.status, 200);
    assert.strictEqual(bookOf(book.book_id).status, 'removed');
  }],

  ['交易中或已售出的書籍不可變更狀態', async () => {
    const { user, token } = seller();
    const reserved = addBook({ sellerId: user.user_id, status: 'reserved' });
    const sold = addBook({ sellerId: user.user_id, status: 'sold' });

    const one = await request('PUT', `/api/books/${reserved.book_id}`, { token, body: { status: 'removed' } });
    assert.strictEqual(one.status, 409);
    assert.strictEqual(one.body.message, '此書籍交易中，無法變更狀態');

    const two = await request('PUT', `/api/books/${sold.book_id}`, { token, body: { status: 'removed' } });
    assert.strictEqual(two.status, 409);
    assert.strictEqual(two.body.message, '此書籍已售出，無法變更狀態');
  }],

  ['違規下架的書籍不可自行重新上架', async () => {
    const { user, token } = seller();
    const book = addBook({ sellerId: user.user_id, status: 'removed', is_approved: false });

    const res = await request('PUT', `/api/books/${book.book_id}`, { token, body: { status: 'on_sale' } });
    assert.strictEqual(res.status, 403);
    assert.strictEqual(res.body.code, 'BOOK_NOT_APPROVED');
    assert.strictEqual(res.body.message, '此書籍因違規遭下架，無法自行重新上架，請聯絡客服');
    assert.strictEqual(bookOf(book.book_id).status, 'removed');
  }],

  ['檢舉成立的書籍即使仍為已審核也不可重新上架', async () => {
    const { user, token } = seller();
    const book = addBook({ sellerId: user.user_id, status: 'removed' });
    prisma.rows('reports').push({
      report_id: 1, reporter_id: addUser().user_id, target_type: 'book', target_id: book.book_id,
      reason: '盜版', status: 'resolved', created_at: new Date()
    });

    const res = await request('PUT', `/api/books/${book.book_id}`, { token, body: { status: 'on_sale' } });
    assert.strictEqual(res.status, 403);
    assert.strictEqual(res.body.code, 'BOOK_NOT_APPROVED');
  }],

  ['等待 AI 審核的書籍仍可由賣家自行重新上架', async () => {
    const { user, token } = seller();
    const book = addBook({ sellerId: user.user_id, status: 'removed', is_approved: false });
    prisma.rows('ai_book_reviews').push({ book_id: book.book_id, status: 'pending', verdict: 'review' });

    const res = await request('PUT', `/api/books/${book.book_id}`, { token, body: { status: 'on_sale' } });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(bookOf(book.book_id).status, 'on_sale');
    // 重新上架不代表通過審核，仍不公開。
    assert.strictEqual(bookOf(book.book_id).is_approved, false);
    assert.strictEqual(res.body.data.review_status, 'pending');
  }],

  ['降價時通知收藏此書的其他會員', async () => {
    const { user, token } = seller();
    const fan = addUser();
    const book = addBook({ sellerId: user.user_id, price: 200, title: '追風箏的孩子' });
    prisma.rows('favorites').push({
      favorite_id: 1, user_id: fan.user_id, book_id: book.book_id, created_at: new Date()
    });
    prisma.rows('favorites').push({
      favorite_id: 2, user_id: user.user_id, book_id: book.book_id, created_at: new Date()
    });

    const res = await request('PUT', `/api/books/${book.book_id}`, { token, body: { price: 150 } });
    assert.strictEqual(res.status, 200);
    await flush();

    const notice = notificationsOf(fan.user_id)[0];
    assert.ok(notice, '收藏者應收到降價通知');
    assert.strictEqual(notice.type, 'promotion');
    assert.strictEqual(notice.title, '收藏的書籍已降價');
    assert.strictEqual(notice.content, '《追風箏的孩子》從 200 降至 150 代幣。');
    // 賣家自己不會收到自己書籍的降價通知。
    assert.strictEqual(notificationsOf(user.user_id).length, 0);
  }],

  ['漲價不會發出降價通知', async () => {
    const { user, token } = seller();
    const fan = addUser();
    const book = addBook({ sellerId: user.user_id, price: 100 });
    prisma.rows('favorites').push({
      favorite_id: 1, user_id: fan.user_id, book_id: book.book_id, created_at: new Date()
    });

    await request('PUT', `/api/books/${book.book_id}`, { token, body: { price: 180 } });
    await flush();
    assert.strictEqual(notificationsOf(fan.user_id).length, 0);
  }],

  ['下架書籍', async () => {
    const { user, token } = seller();
    const book = addBook({ sellerId: user.user_id });

    const res = await request('DELETE', `/api/books/${book.book_id}`, { token });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.message, '書籍已成功下架');
    assert.strictEqual(bookOf(book.book_id).status, 'removed');
  }],

  ['交易中的書籍不可下架，他人也不可下架', async () => {
    const { user, token } = seller();
    const other = addUser();
    const book = addBook({ sellerId: user.user_id, status: 'reserved' });

    const conflict = await request('DELETE', `/api/books/${book.book_id}`, { token });
    assert.strictEqual(conflict.status, 409);
    assert.strictEqual(conflict.body.message, '此書籍交易中，請先處理訂單再下架');

    const forbidden = await request('DELETE', `/api/books/${book.book_id}`, { token: tokenFor(other) });
    assert.strictEqual(forbidden.status, 403);
    assert.strictEqual(forbidden.body.message, '存取被拒，您無權限刪除他人的書籍');
  }],

  ['新增圖片需附檔案，且僅限賣家本人', async () => {
    const { user, token } = seller();
    const other = addUser();
    const book = addBook({ sellerId: user.user_id });

    const empty = await request('POST', `/api/books/${book.book_id}/images`, { token, body: {} });
    assert.strictEqual(empty.status, 400);
    assert.strictEqual(empty.body.message, '請選擇要上傳的圖片');

    const forbidden = await request('POST', `/api/books/${book.book_id}/images`, { token: tokenFor(other), body: {} });
    assert.strictEqual(forbidden.status, 403);
    assert.strictEqual(forbidden.body.message, '存取被拒，您無權限修改他人的商品');
  }],

  ['刪除圖片', async () => {
    const { user, token } = seller();
    const book = addBook({ sellerId: user.user_id });
    const image = addImage(book.book_id);

    const missing = await request('DELETE', `/api/books/${book.book_id}/images/9999`, { token });
    assert.strictEqual(missing.status, 404);
    assert.strictEqual(missing.body.message, '找不到該圖片');

    const res = await request('DELETE', `/api/books/${book.book_id}/images/${image.image_id}`, { token });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(prisma.rows('book_images').length, 0);
  }],

  ['公開列表只顯示上架中且已審核的書籍', async () => {
    const owner = addUser();
    const onSale = addBook({ sellerId: owner.user_id, title: '公開的書' });
    addBook({ sellerId: owner.user_id, title: '已下架的書', status: 'removed' });
    addBook({ sellerId: owner.user_id, title: '審核中的書', is_approved: false });

    const res = await request('GET', '/api/books');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.data.length, 1);
    assert.strictEqual(res.body.data[0].book_id, onSale.book_id);
    assert.strictEqual(res.body.pagination.total, 1);
  }],

  ['公開列表不可查詢已下架的書籍，賣家本人則可以', async () => {
    const owner = addUser();
    addBook({ sellerId: owner.user_id, status: 'removed' });

    const publicView = await request('GET', '/api/books?status=removed');
    assert.strictEqual(publicView.status, 400);
    assert.strictEqual(publicView.body.message, '不支援的書籍狀態');

    const ownView = await request('GET', `/api/books?status=removed&seller_id=${owner.user_id}`, {
      token: tokenFor(owner)
    });
    assert.strictEqual(ownView.status, 200);
    assert.strictEqual(ownView.body.data.length, 1);
  }],

  ['賣家檢視自己的書籍時會附上審核狀態', async () => {
    const owner = addUser();
    const book = addBook({ sellerId: owner.user_id, is_approved: false });
    prisma.rows('ai_book_reviews').push({ book_id: book.book_id, status: 'pending', verdict: 'review' });

    const res = await request('GET', `/api/books?status=all&seller_id=${owner.user_id}`, { token: tokenFor(owner) });
    assert.strictEqual(res.body.data.length, 1);
    assert.strictEqual(res.body.data[0].review_status, 'pending');
  }],

  ['關鍵字可比對書名與作者', async () => {
    const owner = addUser();
    addBook({ sellerId: owner.user_id, title: '深度學習' });
    addBook({ sellerId: owner.user_id, title: '小王子', author: '聖修伯里' });

    const byTitle = await request('GET', '/api/books?keyword=深度');
    assert.strictEqual(byTitle.body.data.length, 1);
    assert.strictEqual(byTitle.body.data[0].title, '深度學習');

    const byAuthor = await request('GET', '/api/books?keyword=聖修伯里');
    assert.strictEqual(byAuthor.body.data.length, 1);
    assert.strictEqual(byAuthor.body.data[0].title, '小王子');
  }],

  ['未審核的書籍只有賣家本人看得到詳情', async () => {
    const owner = addUser();
    const other = addUser();
    const book = addBook({ sellerId: owner.user_id, is_approved: false });

    const stranger = await request('GET', `/api/books/${book.book_id}`, { token: tokenFor(other) });
    assert.strictEqual(stranger.status, 404);
    assert.strictEqual(stranger.body.message, '找不到該書籍');

    const mine = await request('GET', `/api/books/${book.book_id}`, { token: tokenFor(owner) });
    assert.strictEqual(mine.status, 200);
    assert.strictEqual(mine.body.data.book_id, book.book_id);
  }],

  ['瀏覽他人書籍會累計瀏覽數，賣家自己瀏覽則不會', async () => {
    const owner = addUser();
    const viewer = addUser();
    const book = addBook({ sellerId: owner.user_id });

    await request('GET', `/api/books/${book.book_id}`, { token: tokenFor(viewer) });
    await flush();
    assert.strictEqual(bookOf(book.book_id).view_count, 1);

    await request('GET', `/api/books/${book.book_id}`, { token: tokenFor(owner) });
    await flush();
    assert.strictEqual(bookOf(book.book_id).view_count, 1);
  }],

  ['分享連結以權杖產生且重複索取不變', async () => {
    const owner = addUser();
    const book = addBook({ sellerId: owner.user_id, title: '小王子' });

    const first = await request('GET', `/api/books/${book.book_id}/share-link`);
    assert.strictEqual(first.status, 200);
    assert.strictEqual(first.body.data.title, '小王子');
    const token = first.body.data.url.replace('https://example.test/b/', '');
    assert.match(token, /^[0-9a-f]{32}$/);
    // 連結不可透露流水號（權杖本身可能碰巧含有該數字，只檢查路徑段）。
    assert.strictEqual(first.body.data.url.endsWith(`/${book.book_id}`), false);
    assert.ok(!first.body.data.url.includes(`/b/${book.book_id}/`));

    const second = await request('GET', `/api/books/${book.book_id}/share-link`);
    assert.strictEqual(second.body.data.url, first.body.data.url);
  }],

  ['已下架的書籍無法產生分享連結', async () => {
    const owner = addUser();
    const book = addBook({ sellerId: owner.user_id, status: 'removed' });

    const res = await request('GET', `/api/books/${book.book_id}/share-link`);
    assert.strictEqual(res.status, 409);
    assert.strictEqual(res.body.message, '此書籍已下架，無法分享');
  }],

  ['以分享權杖取書：格式錯誤或已下架皆回 404', async () => {
    const owner = addUser();
    const book = addBook({ sellerId: owner.user_id, share_token: 'a'.repeat(32) });
    addBook({ sellerId: owner.user_id, status: 'removed', share_token: 'b'.repeat(32) });

    const ok = await request('GET', `/api/books/share/${'a'.repeat(32)}`);
    assert.strictEqual(ok.status, 200);
    assert.strictEqual(ok.body.data.book_id, book.book_id);

    const badFormat = await request('GET', '/api/books/share/12345');
    assert.strictEqual(badFormat.status, 404);
    assert.strictEqual(badFormat.body.message, '找不到此書籍');

    const gone = await request('GET', `/api/books/share/${'b'.repeat(32)}`);
    assert.strictEqual(gone.status, 404);
    assert.strictEqual(gone.body.message, '找不到此書籍');
  }]
];

module.exports = { name: '書籍上架與檢視', tests };
