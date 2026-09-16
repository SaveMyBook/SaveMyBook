#!/usr/bin/env node
// 執行 test/ 下各組測試：每組是獨立的行程，避免不同組的假 Prisma 與假 fetch 互相污染。
const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const groups = fs.readdirSync(__dirname, { withFileTypes: true })
  .filter((entry) => entry.isDirectory() && fs.existsSync(path.join(__dirname, entry.name, 'run-all.js')))
  .map((entry) => entry.name)
  .sort();

let failed = 0;
for (const group of groups) {
  console.log(`\n=== ${group} ===`);
  const result = spawnSync(process.execPath, [path.join(__dirname, group, 'run-all.js')], { stdio: 'inherit' });
  if (result.status !== 0) failed += 1;
}

console.log(`\n${failed === 0 ? '✅ 全部測試通過' : `❌ ${failed} 組測試未通過`}（共 ${groups.length} 組）`);
process.exit(failed ? 1 : 0);
