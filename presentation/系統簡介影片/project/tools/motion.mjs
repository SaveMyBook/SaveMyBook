// 量測運動是否滑順：逐格取每支手機的畫面中心、大小、角度，找出加速度突變（頓挫）。
// 用法：node tools/motion.mjs <起秒> <迄秒>；需先 npm run dev。
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const puppeteer = require('puppeteer');
const [a, b] = process.argv.slice(2).map(Number);
const browser = await puppeteer.launch({ headless: true, args: ['--use-angle=metal'] });
const page = await browser.newPage();
await page.setViewport({ width: 1920, height: 1080 });
await page.goto('http://127.0.0.1:5291/?render', { waitUntil: 'networkidle0' });
await page.waitForFunction(() => window.__ready === true);
const dt = 1 / 60, rows = [];
for (let t = a; t <= b; t += dt) rows.push({ t, m: await page.evaluate((x) => window.__motion(x), t) });
await browser.close();
// 對每個量算二階差分（加速度，以每格為單位）與三階差分（加加速度），列出加加速度最大的時刻
const keys = new Set(rows.flatMap((r) => Object.keys(r.m)));
const report = [];
for (const k of keys) {
  const n = rows[0].m[k]?.length ?? 4;
  for (let c = 0; c < n; c++) {
    for (let i = 3; i < rows.length; i++) {
      const v = [0, 1, 2, 3].map((j) => rows[i - j].m[k]?.[c]);
      if (v.some((x) => x === undefined)) continue;
      const a1 = v[0] - 2 * v[1] + v[2], a0 = v[1] - 2 * v[2] + v[3];
      const scale = k.startsWith('r') ? 1000 : 1; // 旋轉以毫弧度計
      report.push({ k: `${k}[${c}]`, t: +rows[i].t.toFixed(3), jerk: Math.abs(a1 - a0) * scale, acc: Math.abs(a1) * scale });
    }
  }
}
report.sort((x, y) => y.jerk - x.jerk);
for (const r of report.slice(0, 40)) console.log(r.k.padEnd(10), r.t.toFixed(3).padStart(8), 'jerk', r.jerk.toFixed(2).padStart(8), 'acc', r.acc.toFixed(2));
