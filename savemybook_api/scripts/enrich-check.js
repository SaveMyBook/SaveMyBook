#!/usr/bin/env node
// 書籍資料自動補齊的健檢：檢查 Google Books 金鑰、補齊紀錄統計，並可實際查詢一本書的書目來源。
//   node scripts/enrich-check.js                 只看設定與統計
//   node scripts/enrich-check.js 9789573317241   另外實際查詢這個 ISBN，看各來源有沒有資料與簡介
// 不會修改任何資料，也不會印出金鑰內容。

const { env } = require('../config/env');

const probeGoogle = async (isbn) => {
  const googleBooks = require('../lib/google-books');
  try {
    const info = await googleBooks.fetchVolumeByIsbn(isbn);
    if (!info) return '查無 ISBN 相符的資料';
    return `有資料：《${info.title ?? ''}》，簡介 ${String(info.description ?? '').length} 字`;
  } catch (err) {
    return `連線失敗：${err.message}${/429/.test(err.message) ? '（額度用完或被限流）' : ''}`;
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

const STATUS_LABELS = { done: '已補齊', partial: '部分補齊', none: '查無可補資料', mismatch: '書名不符' };

const main = async () => {
  const prisma = require('../lib/prisma');
  try {
    console.log(`Google Books 金鑰：${env.googleBooksApiKey ? '已設定' : '未設定（共用額度常被用完，回 429）'}`);

    const rows = await prisma.$queryRaw`SELECT status, COUNT(*) AS n, MAX(attempted_at) AS last FROM ai_book_enrichments GROUP BY status`;
    console.log('補齊紀錄：');
    for (const r of rows) console.log(`  ${STATUS_LABELS[r.status] ?? r.status}：${Number(r.n)} 本，最近一次 ${r.last?.toISOString?.() ?? r.last}`);
    if (rows.length === 0) console.log('  尚無任何紀錄');
    const [stats] = await prisma.$queryRaw`
      SELECT
        COALESCE(SUM(e.status = 'done' AND (b.description IS NULL OR b.description = '') AND FIND_IN_SET('description', e.seller_fields) = 0), 0) AS done_blank,
        COALESCE(SUM(e.next_attempt_at IS NOT NULL), 0) AS retrying,
        COALESCE(SUM(e.rejected_fields <> ''), 0) AS rejected,
        COALESCE(SUM(FIND_IN_SET('simplified', e.observations) > 0), 0) AS simplified,
        COALESCE(SUM(FIND_IN_SET('unsourced_numbers', e.observations) > 0), 0) AS unsourced,
        COALESCE(SUM(FIND_IN_SET('uncited', e.observations) > 0), 0) AS uncited
      FROM ai_book_enrichments e JOIN books b ON b.book_id = e.book_id`;
    console.log(`  標記完成但簡介空白：${Number(stats.done_blank)} 本；等待重試：${Number(stats.retrying)} 本；賣家修改過自動補齊欄位：${Number(stats.rejected)} 本`);
    console.log(`  觀察項目：簡體字比例偏高 ${Number(stats.simplified)} 本、簡介含來源外數字 ${Number(stats.unsourced)} 本、網路搜尋沒有引用標註 ${Number(stats.uncited)} 本`);
    const [pending] = await prisma.$queryRaw`
      SELECT COUNT(*) AS n FROM books b LEFT JOIN ai_book_enrichments e ON e.book_id = b.book_id
      WHERE e.book_id IS NULL AND b.status = 'on_sale' AND b.is_approved = 1 AND b.isbn IS NOT NULL AND b.isbn <> ''
        AND (b.description IS NULL OR b.description = '' OR b.author IS NULL OR b.author = ''
          OR b.publisher IS NULL OR b.publisher = '' OR b.publish_date IS NULL OR b.publish_date = '')`;
    console.log(`  等待處理：${Number(pending.n)} 本（每 30 分鐘處理 20 本）`);

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
