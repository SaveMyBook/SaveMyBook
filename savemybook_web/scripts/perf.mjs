// 以真實滾輪從頭捲到尾，統計每格耗時與各章節的慢格比例，用來確認捲動是否順暢。
// 用法：node scripts/perf.mjs [網址]，預設 http://127.0.0.1:5280/；環境變數 DPR 可指定裝置像素比（預設 2）。
import { createRequire } from 'node:module';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const puppeteer = require(resolve(here, '../../presentation/介紹動畫/src/node_modules/puppeteer'));
const browser = await puppeteer.launch({ headless: true, args: ['--use-angle=metal', '--enable-gpu', '--ignore-gpu-blocklist'] });
const page = await browser.newPage();
await page.setViewport({ width: 1440, height: 900, deviceScaleFactor: Number(process.env.DPR || 2) });
page.on('pageerror', (e) => console.log('pageerror', e.message));
await page.goto(process.argv[2] || 'http://127.0.0.1:5280/', { waitUntil: 'networkidle0' });
await new Promise((r) => setTimeout(r, 2500));
await page.evaluate(() => {
  window.__frames = [];
  let last = performance.now();
  const tick = (t) => { window.__frames.push([t - last, scrollY]); last = t; requestAnimationFrame(tick); };
  requestAnimationFrame(tick);
});
await page.mouse.move(720, 450);
const total = await page.evaluate(() => document.documentElement.scrollHeight - innerHeight);
let y = 0, n = 0;
while (y < total - 5 && n < 2000) {
  await page.mouse.wheel({ deltaY: 120 });
  await new Promise((r) => setTimeout(r, 50));
  y = await page.evaluate(() => scrollY);
  n++;
}
await new Promise((r) => setTimeout(r, 1000));
const frames = await page.evaluate(() => window.__frames);
const d = frames.map((f) => f[0]).sort((a, b) => a - b);
const pct = (q) => d[Math.floor(d.length * q)].toFixed(1);
console.log('wheel ticks', n, 'scrollY', y, 'of', total, 'frames', frames.length, 'p50', pct(.5), 'p95', pct(.95), 'p99', pct(.99), 'max', d[d.length - 1].toFixed(1));
const long = frames.filter((f) => f[0] > 34);
console.log('long frames >34ms:', long.length, long.slice(0, 30).map((f) => `${f[0].toFixed(0)}@${Math.round(f[1])}`).join(' '));
const sections = await page.evaluate(() => [...document.querySelectorAll('main > .ch')].map((c) => [c.id, c.offsetTop]));
console.log(sections.map((s) => s.join(':')).join(' '));
const secs = sections.map((s, i) => [s[0], s[1], sections[i + 1] ? sections[i + 1][1] : 1e9]);
for (const [id, a, b] of secs) {
  const fs = frames.filter((f) => f[1] >= a && f[1] < b).map((f) => f[0]);
  if (!fs.length) continue;
  console.log(id.padEnd(9), 'frames', String(fs.length).padStart(4), 'slow(>20ms)', (fs.filter((x) => x > 20).length / fs.length * 100).toFixed(0) + '%');
}
await browser.close();
