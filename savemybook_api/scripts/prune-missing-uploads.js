#!/usr/bin/env node
// 掃描資料庫中指向 /uploads 的欄位，列出檔案已不存在者；加上 --apply 才會清除。
const prisma = require('../lib/prisma');
const { sweep } = require('../services/uploads-cleanup');

const main = async () => {
  const apply = process.argv.includes('--apply');
  const { results, missingCount } = await sweep({ apply });

  for (const r of results) {
    if (r.error) {
      console.log(`${r.table}.${r.column}：略過（${r.error}）`);
      continue;
    }
    console.log(`${r.table}.${r.column}：檢查 ${r.checked} 筆，找不到檔案 ${r.missing.length} 筆`);
    for (const item of r.missing.slice(0, 10)) console.log(`  - ${item.url}`);
    if (r.missing.length > 10) console.log(`  …另有 ${r.missing.length - 10} 筆`);
  }

  console.log(apply
    ? `\n已清除 ${missingCount} 筆失效的圖片欄位。`
    : `\n共 ${missingCount} 筆失效，尚未變更資料。確認無誤後加上 --apply 重新執行。`);
};

main()
  .catch((err) => {
    console.error('❌ 執行失敗：', err.message);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
