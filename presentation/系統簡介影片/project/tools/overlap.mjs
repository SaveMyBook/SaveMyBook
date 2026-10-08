// 易讀性檢查：逐格列出互相重疊的文字區塊、出界的文字、以及壓在手機上的文字。
// 用法：node tools/overlap.mjs [起秒] [迄秒] [間隔秒]；需先 npm run dev（5291 埠）。
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const puppeteer = require('puppeteer');
const [a = '0', b = '999', st = '0.25'] = process.argv.slice(2);
const browser = await puppeteer.launch({ headless: true, args: ['--use-angle=metal', '--enable-gpu'] });
const page = await browser.newPage();
await page.setViewport({ width: 1920, height: 1080 });
await page.goto('http://127.0.0.1:5291/?render', { waitUntil: 'networkidle0' });
await page.waitForFunction(() => window.__ready === true, { timeout: 60000 });
const end = Math.min(Number(b), await page.evaluate(() => window.__duration));
const seen = new Map();
for (let t = Number(a); t <= end + 1e-9; t += Number(st)) {
  const list = await page.evaluate((x) => window.__overlaps(x), t);
  for (const k of list) {
    if (!seen.has(k)) seen.set(k, [t, t]);
    else seen.get(k)[1] = t;
  }
}
await browser.close();
const rows = [...seen.entries()].sort((p, q) => p[1][0] - q[1][0]).map(([k, [t0, t1]]) => `${t0.toFixed(2)}–${t1.toFixed(2)}s  ${k}`);
console.log(rows.join('\n') || '無重疊');
console.log(`共 ${rows.length} 項`);
