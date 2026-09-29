const assert = require('assert');
const h = require('./harness');
const { prisma, write, missing, nextName } = h;

const cleanup = h.api('services/uploads-cleanup');

prisma.onSql(/^SELECT \w+ AS id, \w+ AS url FROM/, (sql, values) => {
  const [, idColumn, column, table] = /^SELECT (\w+) AS id, (\w+) AS url FROM (\w+)/.exec(sql);
  if (!prisma.store[table]) throw new Error('connection lost');
  return prisma.rows(table)
    .filter((row) => typeof row[column] === 'string' && row[column].startsWith('/uploads/') && Number(row[idColumn]) > Number(values[0]))
    .sort((a, b) => a[idColumn] - b[idColumn])
    .map((row) => ({ id: row[idColumn], url: row[column] }));
});

const tests = [
  ['只回報不變更資料', async () => {
    const gone = missing(`avatars/${nextName()}`);
    prisma.rows('users').push({ user_id: 1, avatar_url: gone });

    const report = await cleanup.sweep();
    assert.strictEqual(report.missingCount, 1);
    assert.strictEqual(report.applied, false);
    assert.strictEqual(prisma.rows('users')[0].avatar_url, gone, '未指定 apply 時不得變更');
  }],

  ['apply 時清除失效欄位、保留正常檔案', async () => {
    const ok = write(`avatars/${nextName()}`);
    const gone = missing(`avatars/${nextName()}`);
    const goneImage = missing(`books/${nextName()}`);
    prisma.rows('users').push({ user_id: 1, avatar_url: ok }, { user_id: 2, avatar_url: gone });
    prisma.rows('book_images').push({ image_id: 1, image_url: goneImage });

    const report = await cleanup.sweep({ apply: true });
    assert.strictEqual(report.missingCount, 2);
    assert.strictEqual(prisma.rows('users')[0].avatar_url, ok);
    assert.strictEqual(prisma.rows('users')[1].avatar_url, null);
    assert.strictEqual(prisma.rows('book_images').length, 0);
  }],

  ['單一資料表查詢失敗時只標記錯誤，不中斷其他項目', async () => {
    const gone = missing(`avatars/${nextName()}`);
    prisma.rows('users').push({ user_id: 1, avatar_url: gone });
    delete prisma.store.chat_rooms;

    const report = await cleanup.sweep({ apply: true });
    const chatResult = report.results.find((r) => r.table === 'chat_rooms');
    assert.ok(chatResult.error, '查詢失敗的資料表應記錄錯誤');
    assert.strictEqual(prisma.rows('users')[0].avatar_url, null, '其他資料表仍要處理');
  }]
];

module.exports = { name: '失效圖片欄位清理', tests };
