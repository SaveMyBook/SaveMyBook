const prisma = require('../lib/prisma');
const { exists, forget } = require('../lib/uploads-fs');

const BATCH = 500;

// 逐批掃描，避免一次把整張表讀進記憶體。
const scanColumn = async ({ table, idColumn, column, apply, onMissing }) => {
  let lastId = 0;
  let checked = 0;
  const missing = [];

  for (;;) {
    const rows = await prisma.$queryRawUnsafe(
      `SELECT ${idColumn} AS id, ${column} AS url FROM ${table}
       WHERE ${column} IS NOT NULL AND ${column} LIKE '/uploads/%' AND ${idColumn} > ?
       ORDER BY ${idColumn} LIMIT ${BATCH}`,
      lastId
    );
    if (rows.length === 0) break;

    for (const row of rows) {
      checked += 1;
      lastId = Number(row.id);
      forget(row.url);
      if (exists(row.url)) continue;
      missing.push({ id: lastId, url: row.url });
      if (apply) await onMissing(lastId, row.url);
    }
  }

  return { table, column, checked, missing };
};

const TARGETS = [
  {
    table: 'users',
    idColumn: 'user_id',
    column: 'avatar_url',
    onMissing: (id) => prisma.$executeRaw`UPDATE users SET avatar_url = NULL WHERE user_id = ${id}`
  },
  {
    table: 'chat_rooms',
    idColumn: 'room_id',
    column: 'avatar_url',
    onMissing: (id) => prisma.$executeRaw`UPDATE chat_rooms SET avatar_url = NULL WHERE room_id = ${id}`
  },
  {
    table: 'book_images',
    idColumn: 'image_id',
    column: 'image_url',
    onMissing: (id) => prisma.$executeRaw`DELETE FROM book_images WHERE image_id = ${id}`
  }
];

/** 掃描資料庫中指向 /uploads 的欄位，找出檔案已不存在者；apply 為真時一併清除。 */
const sweep = async ({ apply = false } = {}) => {
  const results = [];
  for (const target of TARGETS) {
    try {
      results.push(await scanColumn({ ...target, apply }));
    } catch (err) {
      // 資料表尚未建立（例如聊天功能未啟用）時略過，不影響其他項目。
      results.push({ table: target.table, column: target.column, checked: 0, missing: [], error: err.message });
    }
  }
  const missingCount = results.reduce((sum, r) => sum + r.missing.length, 0);
  return { results, missingCount, applied: apply };
};

module.exports = { sweep, TARGETS };
