const assert = require('assert');
const {
  request, addUser, addAdmin, addBook, tokenFor, bookOf, prisma, reviewOf, enableModeration, stubModeration, api
} = require('./harness');

const screening = api('services/listing-screening');

const eventsOf = (bookId) => prisma.rows('ai_review_events').filter((e) => Number(e.book_id) === Number(bookId));
const lastEvent = (bookId) => eventsOf(bookId).at(-1);

const seller = () => {
  const user = addUser({ nickname: '賣家' });
  return { user, token: tokenFor(user) };
};

const contentAdmin = () => tokenFor(addAdmin({ can_manage_content: true }));

const heldBook = (sellerId, review) => {
  const book = addBook({ sellerId, is_approved: false, ...(review.status === 'rejected' && { status: 'removed' }) });
  prisma.rows('ai_book_reviews').push({
    book_id: book.book_id, verdict: 'review', reasons: '[]', categories: '[]', provider: 'deepseek', model: 'deepseek-flash',
    confidence: 0.6, created_at: new Date(), reviewed_by: null, reviewed_at: null, ...review
  });
  return book;
};

const decide = (token, bookId, body) => request('PATCH', `/api/admin/ai/reviews/${bookId}`, { token, body });

const tests = [
  ['背景審核送審與駁回各留下一筆系統事件，審核紀錄保存把握度', async () => {
    const { token } = seller();
    enableModeration({ action: 'block' });
    stubModeration({ verdict: 'review', confidence: 0.61, reasons: ['書名與描述疑似不符'], categories: ['misleading'] });
    const held = await request('POST', '/api/books', { token, body: { title: '小王子', price: 200 } });
    await screening.settled();

    const heldId = held.body.data.book_id;
    assert.strictEqual(Number(reviewOf(heldId).confidence), 0.61);
    assert.deepStrictEqual(
      (({ actor, prior, status, verdict, origin, categories }) => ({ actor, prior, status, verdict, origin, categories }))(lastEvent(heldId)),
      { actor: 'system', prior: null, status: 'pending', verdict: 'review', origin: 'ai', categories: '["misleading"]' }
    );

    stubModeration({ verdict: 'reject', confidence: 0.95, reasons: ['非書籍商品'], categories: ['not_book'] });
    const rejected = await request('POST', '/api/books', { token, body: { title: '遊戲點數卡', price: 200 } });
    await screening.settled();
    const rejectedId = rejected.body.data.book_id;
    assert.strictEqual(eventsOf(rejectedId).length, 1);
    assert.strictEqual(lastEvent(rejectedId).status, 'rejected');
    assert.strictEqual(lastEvent(rejectedId).misjudged, null);

    const relist = await request('PATCH', `/api/admin/books/${rejectedId}`, { token: contentAdmin(), body: { status: 'on_sale' } });
    assert.strictEqual(relist.status, 200);
    const overturn = lastEvent(rejectedId);
    assert.deepStrictEqual(
      (({ actor, prior, status, verdict, categories, misjudged }) => ({ actor, prior, status, verdict, categories, misjudged }))(overturn),
      { actor: 'relist', prior: 'rejected', status: 'approved', verdict: 'reject', categories: '["not_book"]', misjudged: true },
      '審核清單只列待審，從書籍管理恢復背景審核駁回的書即推翻駁回判定'
    );
  }],

  ['即時規則送審的事件標示來源為規則，把握度為 null', async () => {
    const { token } = seller();
    const res = await request('POST', '/api/books', {
      token, body: { title: '小王子', price: 200, description: '有館藏章，圖書館淘汰出售' }
    });
    const bookId = res.body.data.book_id;
    assert.strictEqual(reviewOf(bookId).confidence, null);
    assert.strictEqual(lastEvent(bookId).origin, 'rules');
    assert.strictEqual(lastEvent(bookId).confidence, null);
  }],

  ['管理員推翻駁回判定計為誤判，並記下原判定', async () => {
    const { user } = seller();
    const book = heldBook(user.user_id, { status: 'rejected', verdict: 'reject', categories: '["not_book"]', confidence: 0.92 });

    const res = await decide(contentAdmin(), book.book_id, { decision: 'approve' });
    assert.strictEqual(res.status, 200);
    const event = lastEvent(book.book_id);
    assert.strictEqual(event.actor, 'admin');
    assert.strictEqual(event.prior, 'rejected');
    assert.strictEqual(event.status, 'approved');
    assert.strictEqual(event.verdict, 'reject');
    assert.strictEqual(event.categories, '["not_book"]');
    assert.strictEqual(event.confidence, 0.92);
    assert.strictEqual(event.misjudged, true);
  }],

  ['建議人工檢視後核准不算誤判；標示送審原因不成立才算', async () => {
    const { user } = seller();
    const token = contentAdmin();
    const plain = heldBook(user.user_id, { status: 'pending', categories: '["price"]' });
    const unfounded = heldBook(user.user_id, { status: 'pending', categories: '["source"]', model: 'rules', confidence: null });

    await decide(token, plain.book_id, { decision: 'approve' });
    await decide(token, unfounded.book_id, { decision: 'approve', unfounded: true });
    assert.strictEqual(lastEvent(plain.book_id).misjudged, false);
    assert.strictEqual(lastEvent(unfounded.book_id).misjudged, true);
    assert.strictEqual(lastEvent(unfounded.book_id).origin, 'rules');
  }],

  ['管理員更正先前的核准或駁回不歸咎原判定，也不重複計入', async () => {
    const { user } = seller();
    const token = contentAdmin();
    const rejectedFirst = heldBook(user.user_id, { status: 'pending', categories: '["price"]' });
    const approvedFirst = heldBook(user.user_id, { status: 'pending', categories: '["price"]' });

    assert.strictEqual((await decide(token, rejectedFirst.book_id, { decision: 'reject', category: 'price' })).status, 200);
    assert.strictEqual((await decide(token, rejectedFirst.book_id, { decision: 'approve' })).status, 200);
    assert.deepStrictEqual(eventsOf(rejectedFirst.book_id).map((e) => e.misjudged), [false, null]);

    assert.strictEqual((await decide(token, approvedFirst.book_id, { decision: 'approve' })).status, 200);
    assert.strictEqual((await decide(token, approvedFirst.book_id, { decision: 'reject', category: 'price' })).status, 200);
    assert.deepStrictEqual(eventsOf(approvedFirst.book_id).map((e) => e.misjudged), [false, null]);
  }],

  ['駁回時記錄結構化原因；駁回不算誤判，未知類別回 400', async () => {
    const { user } = seller();
    const token = contentAdmin();
    const book = heldBook(user.user_id, { status: 'pending', categories: '["contact"]' });

    const invalid = await decide(token, book.book_id, { decision: 'reject', category: 'spam' });
    assert.strictEqual(invalid.status, 400);

    const res = await decide(token, book.book_id, { decision: 'reject', category: 'contact', unfounded: true, note: '描述留有電話' });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(reviewOf(book.book_id).decision_reason, 'contact');
    const event = lastEvent(book.book_id);
    assert.strictEqual(event.category, 'contact');
    assert.strictEqual(event.misjudged, false);
    assert.strictEqual(bookOf(book.book_id).status, 'removed');

    const listed = await request('GET', '/api/admin/ai/reviews?status=rejected', { token });
    const item = listed.body.data.find((r) => r.book_id === book.book_id);
    assert.strictEqual(item.decision_reason, 'contact');
    assert.strictEqual(item.origin, 'ai');
    assert.strictEqual(item.confidence, 0.6);
  }],

  ['管理員改回在售管理員駁回或待審的書、賣家修改後通過另記執行者，不填誤判', async () => {
    const { user, token } = seller();
    const admin = addAdmin({ can_manage_content: true });
    const byAdmin = heldBook(user.user_id, { status: 'rejected', verdict: 'review', reviewed_by: admin.user_id });
    const pending = heldBook(user.user_id, { status: 'pending' });
    for (const book of [byAdmin, pending]) {
      const res = await request('PATCH', `/api/admin/books/${book.book_id}`, { token: tokenFor(admin), body: { status: 'on_sale' } });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(lastEvent(book.book_id).actor, 'relist');
      assert.strictEqual(lastEvent(book.book_id).misjudged, null);
    }

    const edited = heldBook(user.user_id, { status: 'pending' });
    enableModeration();
    stubModeration({ verdict: 'allow', confidence: 0.9 });
    const edit = await request('PUT', `/api/books/${edited.book_id}`, { token, body: { description: '改寫後的描述' } });
    assert.strictEqual(edit.status, 200);
    assert.strictEqual(reviewOf(edited.book_id).status, 'approved');
    const released = eventsOf(edited.book_id).find((e) => e.status === 'approved');
    assert.strictEqual(released.actor, 'seller_edit');
    assert.strictEqual(released.misjudged, null);
  }],

  ['賣家修改後送審記為賣家修改', async () => {
    const { user, token } = seller();
    const book = addBook({ sellerId: user.user_id });
    enableModeration();
    stubModeration({ verdict: 'review', confidence: 0.55, reasons: ['描述疑似不實'], categories: ['misleading'] });

    const res = await request('PUT', `/api/books/${book.book_id}`, { token, body: { description: '全新未拆封，保證正版' } });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(reviewOf(book.book_id).status, 'pending');
    assert.strictEqual(lastEvent(book.book_id).actor, 'seller_edit');
    assert.strictEqual(lastEvent(book.book_id).status, 'pending');
  }]
];

module.exports = { name: '上架審核事件', tests };
