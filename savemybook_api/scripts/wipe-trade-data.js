#!/usr/bin/env node
const prisma = require('../lib/prisma');

// 依外鍵相依順序刪除，不關閉 FOREIGN_KEY_CHECKS：該設定只作用於單一連線，而 Prisma 連線池無法保證每道指令使用同一條連線。
const STEPS = [
  ['聊天室商品與預約卡片', "DELETE FROM chat_messages WHERE message_type = 'system' AND (content LIKE '[reservation]%' OR content LIKE '[book]%')"],
  ['聊天室關聯書籍', 'UPDATE chat_rooms SET book_id = NULL WHERE book_id IS NOT NULL'],
  ['書櫃格位狀態', "UPDATE cabinet_slots SET status = 'empty' WHERE status IN ('occupied', 'reserved')"],
  ['書櫃格位關聯', 'UPDATE cabinet_slots SET current_book_id = NULL, current_order_id = NULL WHERE current_book_id IS NOT NULL OR current_order_id IS NOT NULL'],
  ['錢包紀錄關聯訂單', 'UPDATE wallet_transactions SET related_order_id = NULL WHERE related_order_id IS NOT NULL'],
  ['訂單與書籍通知', "DELETE FROM notifications WHERE related_type IN ('order', 'book')"],
  ['書籍檢舉', "DELETE FROM reports WHERE target_type = 'book'"],
  ['書籍審核紀錄', "DELETE FROM content_reviews WHERE content_type = 'book'"],
  ['退款紀錄', 'DELETE FROM refund_records'],
  ['交易爭議', 'DELETE FROM transaction_disputes'],
  ['訂單明細', 'DELETE FROM order_items'],
  ['訂單', 'DELETE FROM orders'],
  ['預約', 'DELETE FROM reservations'],
  ['購物車', 'DELETE FROM shopping_cart'],
  ['收藏', 'DELETE FROM favorites'],
  ['推薦紀錄', 'DELETE FROM recommendation_logs'],
  ['書籍照片', 'DELETE FROM book_images'],
  ['書籍', 'DELETE FROM books']
];

const COUNTS = ['books', 'book_images', 'orders', 'order_items', 'reservations', 'refund_records', 'transaction_disputes', 'shopping_cart', 'favorites'];

const main = async () => {
  const confirmed = process.argv.includes('--yes');

  for (const table of COUNTS) {
    const [row] = await prisma.$queryRawUnsafe(`SELECT COUNT(*) AS n FROM ${table}`);
    console.log(`${table}: ${Number(row.n)} 筆`);
  }

  if (!confirmed) {
    console.log('\n以上為目前資料筆數，尚未刪除任何資料。確認要刪除請加上 --yes 重新執行。');
    return;
  }

  await prisma.$transaction(async (tx) => {
    for (const [label, sql] of STEPS) {
      const affected = await tx.$executeRawUnsafe(sql);
      console.log(`✔ ${label}：${affected} 筆`);
    }
  }, { timeout: 10 * 60 * 1000, maxWait: 30 * 1000 });

  console.log('\n已刪除所有書籍、訂單與預約資料。');
};

main()
  .catch((err) => {
    console.error('❌ 執行失敗，所有變更均已復原：', err.message);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
