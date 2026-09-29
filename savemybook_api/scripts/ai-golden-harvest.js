#!/usr/bin/env node
// 每月一次：把上個月管理員推翻的上架審核整理成去識別化的評測集候選，並統計 AI 客服與書籍顧問的負評原因（不含對話內容）。
//   node scripts/ai-golden-harvest.js                     輸出上個月的候選到標準輸出
//   node scripts/ai-golden-harvest.js 2026-09 out.json    指定月份並寫入檔案
// 只讀取資料，不修改任何資料。輸出檔含上架內容，請勿提交到版本庫；人工改寫並標註後才加入 test/ai/golden。

const fs = require('fs');

const main = async () => {
  const prisma = require('../lib/prisma');
  const harvest = require('../services/ai/golden-harvest');
  const [month, out] = process.argv.slice(2);
  try {
    const result = await harvest.collect(month || harvest.previousMonth());
    const json = `${JSON.stringify(result, null, 2)}\n`;
    if (out) {
      fs.writeFileSync(out, json);
      console.log(`已寫入 ${out}：上架審核 ${result.moderation.length} 件，客服負評 ${result.support_feedback.unhelpful} 則、書籍顧問負評 ${result.book_chat_feedback.unhelpful} 則`);
    } else {
      process.stdout.write(json);
    }
  } finally {
    await prisma.$disconnect();
  }
};

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
