const assert = require('assert');
const integrity = require('../../scripts/db-integrity');

const { RELATIONS, SOFT, planFor, orphanWhere, constraintSql } = integrity;

const rel = (table, column) => RELATIONS.find((r) => r.table === table && r.column === column);

// 以查詢字串比對回應的假資料庫；orphans 以「資料表.欄位」為鍵，fixes 模擬每次清理後剩下的筆數。
const fakeDb = ({ tables, engines = {}, fks = [], orphans = {}, failOn = [] }) => {
  const executed = [];
  const state = { ...orphans };
  const keyOf = (sql) => {
    const m = /FROM (\w+) c WHERE c\.(\w+) IS NOT NULL/.exec(sql) ?? /UPDATE (\w+) c SET c\.(\w+)/.exec(sql);
    return m ? `${m[1]}.${m[2]}` : null;
  };
  return {
    executed,
    state,
    async $queryRawUnsafe(sql) {
      if (/information_schema\.TABLES/.test(sql)) return tables.map((name) => ({ name, engine: engines[name] ?? 'InnoDB' }));
      if (/information_schema\.COLUMNS/.test(sql)) {
        return [...RELATIONS, ...SOFT].filter((r) => tables.includes(r.table)).map((r) => ({ tbl: r.table, col: r.column }));
      }
      if (/REFERENCED_TABLE_NAME IS NOT NULL/.test(sql)) return fks;
      if (/CONSTRAINT_NAME = 'PRIMARY'/.test(sql)) return [{ name: 'id' }];
      if (/SELECT COUNT\(\*\) AS n/.test(sql)) return [{ n: BigInt(state[keyOf(sql)] ?? 0) }];
      if (/LIMIT 5/.test(sql)) return [{ id: 1 }];
      throw new Error(`未預期的查詢：${sql}`);
    },
    async $executeRawUnsafe(sql) {
      executed.push(sql);
      const key = keyOf(sql);
      if (failOn.includes(key)) throw new Error('Cannot delete or update a parent row: a foreign key constraint fails');
      if (/^(UPDATE|DELETE)/.test(sql)) {
        const n = state[key] ?? 0;
        state[key] = 0;
        return n;
      }
      return 0;
    }
  };
};

const tests = [
  ['處理方式：串聯刪除的刪除、可為空的清空，帳務資料與必填關聯只列出', () => {
    assert.strictEqual(planFor(rel('book_images', 'book_id')), 'delete');
    assert.strictEqual(planFor(rel('books', 'cabinet_id')), 'null');
    assert.strictEqual(planFor(rel('chat_messages', 'sender_id')), 'report');
    assert.strictEqual(planFor(rel('wallets', 'user_id')), 'report', '錢包即使設定串聯也不自動刪除');
    assert.strictEqual(planFor(rel('order_items', 'order_id')), 'report');
    assert.strictEqual(planFor(SOFT.find((s) => s.table === 'chat_transfers' && s.column === 'room_id')), 'report');
  }],

  ['SQL：自我參照改用衍生資料表，向量索引的字串編號轉為數字比對', () => {
    assert.match(orphanWhere(rel('book_categories', 'parent_id')), /FROM \(SELECT DISTINCT category_id FROM book_categories\) p/);
    const embedding = SOFT.find((s) => s.table === 'ai_embeddings');
    assert.match(orphanWhere(embedding), /CAST\(c\.ref_id AS UNSIGNED\)/);
    assert.match(orphanWhere(embedding), /c\.kind = 'book'/);
    assert.match(constraintSql(rel('book_images', 'book_id'), 'fk_image_book'), /ON DELETE CASCADE ON UPDATE NO ACTION/);
  }],

  ['檢查：找出缺少的外鍵、不支援外鍵的引擎、孤兒資料與無法檢查的項目', async () => {
    const tables = ['users', 'books', 'book_images', 'favorites', 'smart_cabinets', 'book_categories'];
    const db = fakeDb({
      tables,
      engines: { favorites: 'MyISAM' },
      fks: [
        { tbl: 'books', col: 'seller_id', ref_tbl: 'users', name: 'fk_book_seller' },
        { tbl: 'books', col: 'category_id', ref_tbl: 'book_categories', name: 'fk_book_category' }
      ],
      orphans: { 'book_images.book_id': 3, 'books.cabinet_id': 2 }
    });
    const { results } = await integrity.inspect(db);
    const find = (t, c) => results.find((r) => r.table === t && r.column === c && r.kind === 'fk');

    assert.strictEqual(find('books', 'seller_id').constraint, 'fk_book_seller');
    assert.ok(find('book_images', 'book_id').issues.includes('缺少外鍵'));
    assert.ok(find('favorites', 'user_id').issues.some((i) => i.includes('MyISAM')));
    assert.strictEqual(find('book_images', 'book_id').orphans, 3);
    assert.deepStrictEqual(find('book_images', 'book_id').samples, ['id=1 book_id=undefined']);
    assert.ok(find('orders', 'buyer_id').skipped, '資料表不存在時略過');

    const lines = [];
    const summary = integrity.printReport({ results }, (line) => lines.push(line));
    assert.strictEqual(summary.orphanRelations, 2);
    assert.ok(lines.some((l) => l.includes('book_images.book_id → books.book_id：3 筆，處理方式：刪除')));
    assert.ok(lines.some((l) => l.includes('books.cabinet_id → smart_cabinets.cabinet_id：2 筆，處理方式：清空欄位')));
  }],

  ['清理：只處理可自動處理的項目，失敗時改列需人工確認並繼續', async () => {
    const tables = ['users', 'books', 'book_images', 'smart_cabinets', 'chat_rooms', 'chat_messages', 'wallets'];
    const db = fakeDb({
      tables,
      orphans: { 'book_images.book_id': 3, 'books.cabinet_id': 2, 'chat_messages.sender_id': 4, 'wallets.user_id': 1, 'books.seller_id': 1 },
      failOn: ['books.seller_id']
    });
    const { results } = await integrity.inspect(db);
    const fixed = await integrity.repair(db, results);
    const count = (t, c) => [...fixed].find(([r]) => r.table === t && r.column === c)?.[1];

    assert.strictEqual(count('book_images', 'book_id'), 3);
    assert.strictEqual(count('books', 'cabinet_id'), 2);
    assert.ok(!db.executed.some((sql) => /chat_messages c WHERE c\.sender_id/.test(sql)), '必填關聯不自動處理');
    assert.ok(!db.executed.some((sql) => /wallets/.test(sql)), '帳務資料不自動處理');
    const seller = results.find((r) => r.table === 'books' && r.column === 'seller_id');
    assert.strictEqual(seller.plan, 'report');
    assert.ok(seller.issues.some((i) => i.startsWith('自動清理失敗')));
  }],

  ['補建外鍵：仍有孤兒資料或引擎不支援時略過，其餘依預期名稱建立', async () => {
    const tables = ['users', 'books', 'book_images', 'favorites', 'shopping_cart'];
    const db = fakeDb({
      tables,
      engines: { favorites: 'MyISAM' },
      fks: [{ tbl: 'books', col: 'seller_id', ref_tbl: 'users', name: 'fk_book_seller' }],
      orphans: { 'shopping_cart.book_id': 2 }
    });
    const report = await integrity.inspect(db);
    const added = await integrity.addConstraints(db, report.results, report.schema);
    const of = (t, c) => added.find((a) => a.rel.table === t && a.rel.column === c);

    assert.strictEqual(of('book_images', 'book_id').ok, true);
    assert.ok(db.executed.some((sql) => sql.startsWith('ALTER TABLE book_images ADD CONSTRAINT fk_image_book')));
    assert.strictEqual(of('favorites', 'user_id').ok, false);
    assert.strictEqual(of('shopping_cart', 'book_id').message, '仍有孤兒資料，須先人工處理');
    assert.strictEqual(of('books', 'seller_id'), undefined, '已存在的外鍵不重建');
  }]
];

module.exports = { name: '資料庫關聯健檢', tests };
