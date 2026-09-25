#!/usr/bin/env node
// 書籍資料自動補齊的健檢：檢查資料表、Google Books 金鑰、補齊紀錄統計，並可實際查詢一本書的書目來源。
//   node scripts/enrich-check.js                 只看設定與統計
//   node scripts/enrich-check.js 9789573317241   另外實際查詢這個 ISBN，看各來源有沒有資料與簡介
// 不會修改任何資料，也不會印出金鑰內容。

const { env } = require('../config/env');

const probeGoogle = async (isbn) => {
  const url = new URL('https://www.googleapis.com/books/v1/volumes');
  url.searchParams.set('q', `isbn:${isbn}`);
  url.searchParams.set('printType', 'books');
  if (env.googleBooksApiKey) url.searchParams.set('key', env.googleBooksApiKey);
  try {
    const response = await fetch(url, { signal: AbortSignal.timeout(8000) });
    if (!response.ok) return `HTTP ${response.status}${response.status === 429 ? '（額度用完或被限流）' : ''}`;
    const info = (await response.json())?.items?.[0]?.volumeInfo;
    if (!info) return '查無此書';
    return `有資料：《${info.title ?? ''}》，簡介 ${String(info.description ?? '').length} 字`;
  } catch (err) {
    return `連線失敗：${err.message}`;
  }
};

const probeOpenLibrary = async (isbn) => {
  const openLibrary = require('../lib/open-library');
  const { variantsOf } = require('../services/isbn-lookup');
  try {
    const edition = await openLibrary.fetchEditionByIsbn(variantsOf(isbn));
    if (!edition) return '查無此書';
    const detail = await openLibrary.fetchEditionDetailByIsbn(edition.isbn).catch(() => null);
    return `有資料：《${edition.title}》，簡介 ${String(detail?.description ?? '').length} 字`;
  } catch (err) {
    return `連線失敗：${err.message}`;
  }
};

const main = async () => {
  const prisma = require('../lib/prisma');
  try {
    console.log(`Google Books 金鑰：${env.googleBooksApiKey ? '已設定' : '未設定（共用額度常被用完，回 429）'}`);

    const [table] = await prisma.$queryRaw`
      SELECT COUNT(*) AS n FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ai_book_enrichments'`;
    if (Number(table.n) === 0) {
      console.log('補齊紀錄表：缺少，請先執行 migrations/022_book_enrichment.sql（未執行時補齊功能完全停用）');
    } else {
      const rows = await prisma.$queryRaw`SELECT status, COUNT(*) AS n, MAX(attempted_at) AS last FROM ai_book_enrichments GROUP BY status`;
      console.log('補齊紀錄：');
      for (const r of rows) console.log(`  ${r.status === 'done' ? '已補齊' : '查無可補資料'}：${Number(r.n)} 本，最近一次 ${r.last?.toISOString?.() ?? r.last}`);
      if (rows.length === 0) console.log('  尚無任何紀錄');
      const [pending] = await prisma.$queryRaw`
        SELECT COUNT(*) AS n FROM books b LEFT JOIN ai_book_enrichments e ON e.book_id = b.book_id
        WHERE e.book_id IS NULL AND b.status = 'on_sale' AND b.is_approved = 1 AND b.isbn IS NOT NULL AND b.isbn <> ''
          AND (b.description IS NULL OR b.description = '' OR b.author IS NULL OR b.author = ''
            OR b.publisher IS NULL OR b.publisher = '' OR b.publish_date IS NULL OR b.publish_date = '')`;
      console.log(`  等待處理：${Number(pending.n)} 本（每 30 分鐘處理 20 本）`);
    }

    const isbn = process.argv[2]?.replace(/[-\s]/g, '').toUpperCase();
    if (isbn) {
      console.log(`\n查詢 ISBN ${isbn}：`);
      console.log(`  Google Books：${await probeGoogle(isbn)}`);
      console.log(`  Open Library：${await probeOpenLibrary(isbn)}`);
    }
  } finally {
    await prisma.$disconnect();
  }
};

main().catch((err) => {
  console.error('❌ 執行失敗：', err.message);
  process.exitCode = 1;
});
