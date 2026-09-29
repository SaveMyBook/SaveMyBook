const assert = require('assert');
const {
  request, addUser, addBook, addImage, tokenFor, bookOf, prisma, reviewOf, notificationsOf, fetchLog,
  enableModeration, stubModeration, failModeration, pauseModeration, flush, api
} = require('./harness');

const screening = api('services/listing-screening');
const reviews = api('services/ai/reviews');
const aiImages = api('services/ai/images');
const MINUTE = 60 * 1000;
const later = (minutes) => new Date(Date.now() + minutes * MINUTE);
const ago = (minutes) => new Date(Date.now() - minutes * MINUTE);
const prompts = () => fetchLog
  .filter((f) => f.url.startsWith('https://api.deepseek.com'))
  .map((f) => JSON.parse(f.init.body).messages.map((m) => m.content).join('\n'));
const adminReviews = async (status = 'all') => {
  const admin = addUser({ nickname: '審核員', role: 'admin' });
  return request('GET', `/api/admin/ai/reviews?status=${status}`, { token: tokenFor(admin) });
};

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

  ['AI 審核通過時留下通過紀錄，後台審核清單不列出', async () => {
    const { token } = seller();
    enableModeration();
    stubModeration({ verdict: 'allow', confidence: 0.95 });

    const res = await create(token);
    await screening.settled();
    const review = reviewOf(res.body.data.book_id);
    assert.strictEqual(review.status, 'passed');
    assert.strictEqual(review.verdict, 'allow');
    assert.strictEqual(review.provider, 'deepseek');
    assert.strictEqual(bookOf(res.body.data.book_id).is_approved, true);

    const list = await adminReviews();
    assert.strictEqual(list.status, 200);
    assert.deepStrictEqual(list.body.data, []);
    assert.strictEqual(res.body.data.review_status, null);
  }],

  ['服務商錯誤時維持上架，但標記為略過並記錄原因，等待補審', async () => {
    const { token } = seller();
    enableModeration({ action: 'block' });
    failModeration(401);

    const res = await create(token);
    await screening.settled();
    assert.strictEqual(res.status, 201);
    assert.strictEqual(bookOf(res.body.data.book_id).is_approved, true);
    assert.strictEqual(screened(), 1, '服務商故障不重試');
    const review = reviewOf(res.body.data.book_id);
    assert.strictEqual(review.status, 'skipped');
    assert.strictEqual(review.skip_reason, 'auth');
    assert.strictEqual(review.attempts, 0);
    assert.strictEqual(review.provider, 'deepseek');
    assert.deepStrictEqual((await adminReviews()).body.data, []);
  }],

  ['模型回傳無法解析時先重試一次，仍失敗才標記為格式錯誤', async () => {
    const { token } = seller();
    enableModeration({ action: 'block' });
    stubModeration('不是 JSON');

    const res = await create(token);
    await screening.settled();
    assert.strictEqual(bookOf(res.body.data.book_id).is_approved, true);
    assert.strictEqual(screened(), 2);
    const review = reviewOf(res.body.data.book_id);
    assert.strictEqual(review.status, 'skipped');
    assert.strictEqual(review.skip_reason, 'invalid_output');
    assert.strictEqual(review.attempts, 1);
  }],

  ['補審：略過的書在服務商恢復後重新審核，判定需人工時撤下並通知賣家與管理員', async () => {
    const { user, token } = seller();
    const admin = addUser({ nickname: '管理員', role: 'admin' });
    enableModeration();
    failModeration(401);
    const res = await create(token);
    await screening.settled();
    const bookId = res.body.data.book_id;

    assert.strictEqual(await screening.recheckDue(later(5)), 0, '距離上次嘗試未滿 10 分鐘不補審');
    stubModeration({ verdict: 'review', confidence: 0.6, reasons: ['書名與照片不符'], categories: ['misleading'] });
    failModeration(null);
    assert.strictEqual(await screening.recheckDue(later(11)), 1);

    assert.strictEqual(bookOf(bookId).is_approved, false);
    const review = reviewOf(bookId);
    assert.strictEqual(review.status, 'pending');
    assert.strictEqual(review.skip_reason, null);
    assert.strictEqual(notificationsOf(user.user_id)[0].title, '書籍已送交審核');
    assert.strictEqual(notificationsOf(admin.user_id)[0].related_type, 'book_review');
  }],

  ['補審：只挑 7 天內上架、超過 15 分鐘仍沒有任何審核紀錄的在售書', async () => {
    const { user } = seller();
    enableModeration();
    stubModeration({ verdict: 'allow', confidence: 1 });
    const due = addBook({ sellerId: user.user_id, title: '重啟時遺失審核的書', created_at: ago(20) });
    const fresh = addBook({ sellerId: user.user_id, created_at: ago(5) });
    const old = addBook({ sellerId: user.user_id, created_at: ago(8 * 24 * 60) });
    const removed = addBook({ sellerId: user.user_id, status: 'removed', created_at: ago(20) });
    const sold = addBook({ sellerId: user.user_id, status: 'sold', created_at: ago(20) });
    const held = addBook({ sellerId: user.user_id, is_approved: false, created_at: ago(20) });
    prisma.rows('ai_book_reviews').push({ book_id: held.book_id, status: 'pending', verdict: 'review' });
    const passed = addBook({ sellerId: user.user_id, created_at: ago(20) });
    prisma.rows('ai_book_reviews').push({ book_id: passed.book_id, status: 'passed', verdict: 'allow', created_at: ago(20) });

    assert.strictEqual(await screening.recheckDue(), 1);
    assert.strictEqual(screened(), 1);
    assert.ok(prompts()[0].includes('重啟時遺失審核的書'));
    assert.strictEqual(reviewOf(due.book_id).status, 'passed');
    for (const book of [fresh, old, removed, sold]) assert.strictEqual(reviewOf(book.book_id), undefined);
    assert.strictEqual(reviewOf(held.book_id).status, 'pending');
  }],

  ['補審：服務商仍故障時整批停止，不逐本等待', async () => {
    const { user } = seller();
    enableModeration();
    failModeration(401);
    addBook({ sellerId: user.user_id, created_at: ago(30) });
    addBook({ sellerId: user.user_id, created_at: ago(20) });

    assert.strictEqual(await screening.recheckDue(), 0);
    assert.strictEqual(screened(), 1);
    assert.strictEqual(prisma.rows('ai_book_reviews').filter((r) => r.status === 'skipped').length, 1);
  }],

  ['補審：只影響單一本書的錯誤跳過這本繼續，同一本累計 3 次後改送人工審核', async () => {
    const { user } = seller();
    enableModeration();
    failModeration((body) => (body.includes('壞書') ? 400 : null));
    const bad = addBook({ sellerId: user.user_id, title: '壞書一', created_at: ago(300) });
    const worse = addBook({ sellerId: user.user_id, title: '壞書二', created_at: ago(200) });
    const good = addBook({ sellerId: user.user_id, title: '好書', created_at: ago(100) });

    assert.strictEqual(await screening.recheckDue(), 1);
    assert.strictEqual(reviewOf(good.book_id).status, 'passed');
    assert.strictEqual(reviewOf(bad.book_id).skip_reason, 'bad_request');
    assert.strictEqual(reviewOf(bad.book_id).attempts, 1);

    await screening.recheckDue(later(11));
    await screening.recheckDue(later(22));
    for (const book of [bad, worse]) {
      assert.strictEqual(bookOf(book.book_id).is_approved, false);
      assert.deepStrictEqual(JSON.parse(reviewOf(book.book_id).reasons), [screening.RETRY_HOLD_REASON]);
    }
  }],

  ['補審：未審過的書優先，其餘依上次嘗試時間由舊到新，剛失敗的書排到最後', async () => {
    const { user } = seller();
    enableModeration();
    failModeration(401);
    const recent = addBook({ sellerId: user.user_id, title: '剛嘗試過的書', created_at: ago(600) });
    prisma.rows('ai_book_reviews').push({ book_id: recent.book_id, status: 'skipped', skip_reason: 'timeout', attempts: 0, created_at: ago(15) });
    const stale = addBook({ sellerId: user.user_id, title: '較早嘗試的書', created_at: ago(300) });
    prisma.rows('ai_book_reviews').push({ book_id: stale.book_id, status: 'skipped', skip_reason: 'timeout', attempts: 0, created_at: ago(40) });
    const fresh = addBook({ sellerId: user.user_id, title: '尚未審核的書', created_at: ago(20) });

    await screening.recheckDue();
    assert.ok(prompts()[0].includes('尚未審核的書'));
    assert.strictEqual(reviewOf(fresh.book_id).attempts, 0, '服務中斷不累計在書上');

    await screening.recheckDue(later(11));
    assert.ok(prompts()[1].includes('較早嘗試的書'));
    assert.strictEqual(reviewOf(stale.book_id).attempts, 0);
  }],

  ['補審與編輯審核的照片取封面與最新加入的照片', async () => {
    const { user } = seller();
    enableModeration();
    const book = addBook({ sellerId: user.user_id, created_at: ago(20) });
    const images = Array.from({ length: 6 }, () => addImage(book.book_id));
    const loaded = [];
    const original = aiImages.fromUrls;
    aiImages.fromUrls = async (urls, max) => {
      loaded.push(urls.slice(0, max));
      return [];
    };
    try {
      await screening.recheckDue();
    } finally {
      aiImages.fromUrls = original;
    }
    assert.deepStrictEqual(loaded[0], [images[0], images[5], images[4], images[3]].map((i) => i.image_url));
  }],

  ['背景審核進行中賣家編輯且 AI 失敗時，依舊資料得出的通過結果不會蓋掉略過紀錄', async () => {
    const { token } = seller();
    enableModeration();
    const release = pauseModeration();
    const res = await create(token);
    const bookId = res.body.data.book_id;
    for (let i = 0; i < 20 && screened() === 0; i += 1) await flush();
    assert.strictEqual(screened(), 1);

    failModeration(401);
    const edit = await request('PUT', `/api/books/${bookId}`, { token, body: { description: '改寫後的描述' } });
    assert.strictEqual(edit.status, 200);
    assert.strictEqual(reviewOf(bookId).status, 'skipped');

    failModeration(null);
    release();
    await screening.settled();
    assert.strictEqual(reviewOf(bookId).status, 'skipped');
    assert.strictEqual(reviewOf(bookId).skip_reason, 'auth');
  }],

  ['補審進行中賣家編輯且 AI 失敗時，補審結果同樣不會蓋掉新的略過紀錄', async () => {
    const { user, token } = seller();
    enableModeration();
    const book = addBook({ sellerId: user.user_id, created_at: ago(60) });
    prisma.rows('ai_book_reviews').push({ book_id: book.book_id, status: 'skipped', skip_reason: 'timeout', attempts: 0, created_at: ago(20) });
    const release = pauseModeration();
    const job = screening.recheckDue();
    for (let i = 0; i < 20 && screened() === 0; i += 1) await flush();

    failModeration(401);
    await request('PUT', `/api/books/${book.book_id}`, { token, body: { description: '改寫後的描述' } });
    failModeration(null);
    release();
    await job;
    assert.strictEqual(reviewOf(book.book_id).status, 'skipped');
    assert.strictEqual(reviewOf(book.book_id).skip_reason, 'auth');
  }],

  ['補審：AI 關閉時不執行', async () => {
    const { user } = seller();
    addBook({ sellerId: user.user_id, created_at: ago(30) });
    assert.strictEqual(await screening.recheckDue(), 0);
    assert.strictEqual(screened(), 0);
  }],

  ['補審：同一本書連續 3 次格式錯誤時改送人工審核', async () => {
    const { user, token } = seller();
    enableModeration();
    stubModeration('不是 JSON');
    const res = await create(token);
    await screening.settled();
    const bookId = res.body.data.book_id;
    assert.strictEqual(reviewOf(bookId).attempts, 1);

    await screening.recheckDue(later(11));
    assert.strictEqual(reviewOf(bookId).attempts, 2);
    assert.strictEqual(bookOf(bookId).is_approved, true);

    await screening.recheckDue(later(22));
    assert.strictEqual(bookOf(bookId).is_approved, false);
    const review = reviewOf(bookId);
    assert.strictEqual(review.status, 'pending');
    assert.deepStrictEqual(JSON.parse(review.reasons), [screening.RETRY_HOLD_REASON]);
    assert.strictEqual(review.confidence, null, '轉交人工不是 AI 判定，不記把握度');
    const handover = prisma.rows('ai_review_events').filter((e) => Number(e.book_id) === bookId).at(-1);
    assert.strictEqual(handover.confidence, null);
    assert.strictEqual(notificationsOf(user.user_id)[0].title, '書籍已送交審核');
  }],

  ['審核中的書籍編輯時 AI 失敗不會被放行', async () => {
    const { user, token } = seller();
    const book = addBook({ sellerId: user.user_id, is_approved: false });
    prisma.rows('ai_book_reviews').push({ book_id: book.book_id, status: 'pending', verdict: 'review' });
    enableModeration();
    failModeration(401);

    const res = await request('PUT', `/api/books/${book.book_id}`, { token, body: { title: '換個書名' } });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(bookOf(book.book_id).is_approved, false);
    assert.strictEqual(reviewOf(book.book_id).status, 'pending');
  }],

  ['管理員核准過的書編輯時 AI 失敗改記為略過，之後由排程補審', async () => {
    const { user, token } = seller();
    const book = addBook({ sellerId: user.user_id, created_at: ago(30 * 24 * 60) });
    prisma.rows('ai_book_reviews').push({
      book_id: book.book_id, status: 'approved', verdict: 'review', reviewed_by: 1, reviewed_at: ago(60), created_at: ago(120), attempts: 0
    });
    enableModeration();
    failModeration(500);

    const res = await request('PUT', `/api/books/${book.book_id}`, { token, body: { description: '全新描述' } });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(reviewOf(book.book_id).status, 'skipped');
    assert.strictEqual(reviewOf(book.book_id).skip_reason, 'server');

    failModeration(null);
    const before = screened();
    assert.strictEqual(await screening.recheckDue(later(11)), 1);
    assert.strictEqual(screened(), before + 1);
    assert.strictEqual(reviewOf(book.book_id).status, 'passed');
  }],

  ['編輯時輸出格式錯誤不重送，記為略過交給補審', async () => {
    const { user, token } = seller();
    const book = addBook({ sellerId: user.user_id });
    enableModeration();
    stubModeration('不是 JSON');

    const res = await request('PUT', `/api/books/${book.book_id}`, { token, body: { description: '九成新' } });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(screened(), 1);
    assert.strictEqual(reviewOf(book.book_id).skip_reason, 'invalid_output');
    assert.strictEqual(reviewOf(book.book_id).attempts, 1);
  }],

  ['審核紀錄寫入失敗時編輯與新增照片仍回應成功', async () => {
    const { user, token } = seller();
    const book = addBook({ sellerId: user.user_id });
    enableModeration();
    const original = reviews.mark;
    reviews.mark = async () => {
      throw new Error('connection lost');
    };
    try {
      const edit = await request('PUT', `/api/books/${book.book_id}`, { token, body: { description: '九成新' } });
      assert.strictEqual(edit.status, 200);
      assert.strictEqual(bookOf(book.book_id).description, '九成新');
      const upload = await request('POST', `/api/books/${book.book_id}/images`, { token, raw: gifForm('images') });
      assert.strictEqual(upload.status, 201);
      assert.strictEqual(prisma.rows('book_images').length, 1);
    } finally {
      reviews.mark = original;
    }
  }],

  ['編輯時 AI 失敗會標記為略過，排程之後補審', async () => {
    const { user, token } = seller();
    const book = addBook({ sellerId: user.user_id });
    prisma.rows('ai_book_reviews').push({ book_id: book.book_id, status: 'passed', verdict: 'allow', attempts: 0 });
    enableModeration();
    failModeration(401);

    const res = await request('PUT', `/api/books/${book.book_id}`, { token, body: { description: '九成新' } });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(bookOf(book.book_id).is_approved, true);
    assert.strictEqual(reviewOf(book.book_id).status, 'skipped');
  }],

  ['編輯作者、出版社或書況說明會重新審核，並送出 ISBN 與出版社', async () => {
    const { user, token } = seller();
    const book = addBook({ sellerId: user.user_id, isbn: '9789571234567' });
    enableModeration();
    stubModeration({ verdict: 'allow', confidence: 1 });

    for (const body of [{ author: '新作者' }, { publisher: '新出版社' }, { condition_note: '封面有折痕' }]) {
      const res = await request('PUT', `/api/books/${book.book_id}`, { token, body });
      assert.strictEqual(res.status, 200, JSON.stringify(body));
    }
    assert.strictEqual(screened(), 3);
    const last = prompts()[2];
    assert.ok(last.includes('ISBN：9789571234567'));
    assert.ok(last.includes('出版社：新出版社'));
    assert.ok(last.includes('書況說明：封面有折痕'));
    assert.strictEqual(reviewOf(book.book_id).status, 'passed');
  }],

  ['書況說明提及館藏章時即時送審', async () => {
    const { user, token } = seller();
    const book = addBook({ sellerId: user.user_id });
    const res = await request('PUT', `/api/books/${book.book_id}`, { token, body: { condition_note: '封底有館藏章，已用貼紙覆蓋' } });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(bookOf(book.book_id).is_approved, false);
    assert.strictEqual(reviewOf(book.book_id).model, 'rules');
  }],

  ['新增照片只審新照片：通過時已通過的書維持通過，上架時未審的書仍等待補審', async () => {
    const { user, token } = seller();
    enableModeration();
    failModeration(500);
    const res = await create(token);
    await screening.settled();
    const bookId = res.body.data.book_id;
    assert.strictEqual(reviewOf(bookId).status, 'skipped');

    failModeration(null);
    const upload = await request('POST', `/api/books/${bookId}/images`, { token, raw: gifForm('images') });
    assert.strictEqual(upload.status, 201);
    assert.strictEqual(reviewOf(bookId).status, 'skipped');
    assert.strictEqual(reviewOf(bookId).skip_reason, 'server');

    const passed = addBook({ sellerId: user.user_id });
    prisma.rows('ai_book_reviews').push({ book_id: passed.book_id, status: 'passed', verdict: 'allow', attempts: 0, created_at: ago(60) });
    await request('POST', `/api/books/${passed.book_id}/images`, { token, raw: gifForm('images') });
    assert.strictEqual(reviewOf(passed.book_id).status, 'passed');

    failModeration(401);
    await request('POST', `/api/books/${passed.book_id}/images`, { token, raw: gifForm('images') });
    assert.strictEqual(reviewOf(passed.book_id).status, 'skipped');
  }],

  ['書名含「圖書館」等弱詞時交給 AI 判斷並附上規則提示，通過即維持上架', async () => {
    const { token } = seller();
    enableModeration();
    stubModeration({ verdict: 'allow', confidence: 0.9 });

    const res = await create(token, { title: '圖書館戰爭 1', description: '附 PDF 講義下載說明' });
    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.data.is_approved, true);
    assert.strictEqual(res.body.moderation, undefined);
    await screening.settled();
    assert.ok(prompts()[0].includes('規則提示（僅供參考，可能誤判）：書名含「圖書館」'));
    assert.strictEqual(bookOf(res.body.data.book_id).is_approved, true);
    assert.strictEqual(reviewOf(res.body.data.book_id).status, 'passed');
  }],

  ['「正版，非影印本」「無館藏章、索書號」等否定說法不直接送審，交給 AI 並附上規則提示', async () => {
    const { token } = seller();
    enableModeration();
    stubModeration({ verdict: 'allow', confidence: 0.9 });

    const cases = [
      ['正版，非影印本', '非影印本'], ['書況良好，無館藏章', '無館藏章'], ['無館藏章、索書號', '無館藏章、索書號'],
      ['非圖書館淘汰書', '非圖書館淘汰']
    ];
    for (const [description, word] of cases) {
      const res = await create(token, { description });
      assert.strictEqual(res.body.data.is_approved, true, description);
      await screening.settled();
      assert.ok(prompts().at(-1).includes(`描述含「${word}」`), description);
    }
    for (const description of ['無館藏章，但有索書號', '封底有館藏章', '未除籍']) {
      const res = await create(token, { description });
      assert.strictEqual(res.body.data.is_approved, false, description);
    }
  }],

  ['否定說法在 AI 無法使用時仍即時送審', async () => {
    const { token } = seller();
    const res = await create(token, { description: '正版，非影印本' });
    assert.strictEqual(res.body.data.is_approved, false);
    assert.deepStrictEqual(res.body.moderation.reasons, ['疑似圖書館館藏或非正規來源書籍']);
  }],

  ['只命中弱詞但 AI 無法使用時仍即時送審', async () => {
    const { token } = seller();
    const res = await create(token, { title: '圖書館戰爭 1' });
    assert.strictEqual(res.body.data.is_approved, false);
    assert.deepStrictEqual(res.body.moderation.reasons, ['疑似圖書館館藏或非正規來源書籍']);
    assert.strictEqual(screened(), 0);
  }],

  ['規則送審的書在背景取得 AI 判定並附在審核紀錄上，不改變送審狀態', async () => {
    const { token } = seller();
    enableModeration();
    stubModeration({ verdict: 'allow', confidence: 0.8 });

    const res = await create(token, { price: 5000 });
    assert.strictEqual(res.body.data.is_approved, false);
    await screening.settled();
    assert.strictEqual(screened(), 1);
    const review = reviewOf(res.body.data.book_id);
    assert.strictEqual(review.status, 'pending');
    assert.strictEqual(review.model, 'rules');
    assert.deepStrictEqual(JSON.parse(review.ai_opinion), { verdict: 'allow', confidence: 0.8, categories: [], reasons: [] });

    const list = await adminReviews('pending');
    assert.strictEqual(list.body.data.length, 1);
    assert.deepStrictEqual(list.body.data[0].ai_opinion, { verdict: 'allow', confidence: 0.8, categories: [], reasons: [] });
    assert.strictEqual(bookOf(res.body.data.book_id).is_approved, false);
  }],

  ['描述提及館藏條碼時直接送審，AI 判定只作為管理員參考', async () => {
    const { token } = seller();
    enableModeration();
    stubModeration({ verdict: 'review', confidence: 0.7, reasons: ['照片可見索書號標籤'], categories: ['source'] });

    const res = await create(token, { description: '學校圖書館淘汰書，封底有館藏條碼' });
    assert.strictEqual(res.body.data.is_approved, false);
    await screening.settled();
    const opinion = JSON.parse(reviewOf(res.body.data.book_id).ai_opinion);
    assert.strictEqual(opinion.verdict, 'review');
    assert.deepStrictEqual(opinion.reasons, ['照片可見索書號標籤']);
    assert.ok(prompts()[0].includes('規則提示'));
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

  ['書名或描述含站外聯絡方式時即時送審，不需 AI；拆字與全形寫法同樣攔得住', async () => {
    const { token } = seller();
    const cases = [
      { description: '九成新，欲購請加 LINE ID：book123' },
      { description: '可議價，電話 ０９１２－３４５－６７８' },
      { title: '小王子（可面交）' },
      { description: '詳見 https://shop.example.com/item/1' }
    ];
    for (const body of cases) {
      const res = await create(token, body);
      assert.strictEqual(res.body.data.is_approved, false, JSON.stringify(body));
      assert.deepStrictEqual(res.body.moderation.reasons, ['站外交易或聯絡資訊']);
      assert.strictEqual(reviewOf(res.body.data.book_id).model, 'rules');
    }
    assert.strictEqual(screened(), 0);

    const normal = await create(token, { description: '九成新，第 3 章有少量鉛筆筆記，共 320 頁。' });
    assert.strictEqual(normal.body.data.is_approved, true);
  }],

  ['常見的通訊軟體帳號寫法與繞過寫法都會送審', async () => {
    const { token } = seller();
    const cases = [
      '官方 LINE：@seller88', '加入官方賴 @seller88', 'IG：book_lover', 'Telegram: @book88', 'wechat: book88',
      '賣家LINE帳號綁定：seller88，歡迎詢問', '請先綁定 LINE 帳號 seller88 再私訊', '有問題請連結LINE帳號 seller88',
      '聯絡 abc (at) proton.me', '洽 0912—345—678', '讀者專線 (02)2500-7718', '請至 shopee.tw/seller88 購買'
    ];
    for (const description of cases) {
      const res = await create(token, { description });
      assert.strictEqual(res.body.data.is_approved, false, description);
      assert.deepStrictEqual(res.body.moderation.reasons, ['站外交易或聯絡資訊'], description);
    }
  }],

  ['銀行、會計、行銷類教科書的書名不會因「帳戶」「IG 帳號」等字詞送審', async () => {
    const { token } = seller();
    const titles = [
      '銀行實務：存款帳戶與放款管理', '存款銀行的經營與風險', '中級會計學：預付款項、應收帳款', '貨幣銀行學（附轉帳帳戶練習）',
      'Instagram 帳號經營術', '網路行銷：FB 帳號、IG 帳號與 LINE 官方帳號經營', 'Outlook.com 使用手冊',
      'Python 程式設計：從 Gmail.com API 到自動化'
    ];
    for (const title of titles) {
      const res = await create(token, { title });
      assert.strictEqual(res.body.data.is_approved, true, title);
      assert.strictEqual(res.body.moderation ?? null, null, title);
    }
    const course = await create(token, { description: '大學用書，課程代碼 101，原文書 ISBN 0-596-00712-4' });
    assert.strictEqual(course.body.data.is_approved, true);
  }],

  ['修改描述加入站外聯絡方式時送審', async () => {
    const { user, token } = seller();
    const book = addBook({ sellerId: user.user_id, description: '九成新' });
    const res = await request('PUT', `/api/books/${book.book_id}`, { token, body: { description: '九成新\n私下交易可再便宜 50 元' } });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(bookOf(book.book_id).is_approved, false);
    assert.strictEqual(reviewOf(book.book_id).status, 'pending');
    assert.strictEqual(screened(), 0);
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
