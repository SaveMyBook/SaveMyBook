// 指定秒數截全尺寸單張：node tools/still.mjs <輸出資料夾> <秒> [秒...]；需先 npm run dev（5291 埠）。
import { createRequire } from 'node:module';
import { mkdirSync } from 'node:fs';
const require = createRequire(import.meta.url);
const puppeteer = require('puppeteer');
const [dir, ...ts] = process.argv.slice(2);
mkdirSync(dir, { recursive: true });
const browser = await puppeteer.launch({ headless: true, args: ['--use-angle=metal', '--enable-gpu', '--ignore-gpu-blocklist'] });
const page = await browser.newPage();
await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 1 });
page.on('pageerror', (e) => console.log('pageerror', e.message));
page.on('console', (m) => { if (m.type() === 'error') console.log('console', m.text()); });
await page.goto('http://127.0.0.1:5291/?render' + (process.env.Q ? '&' + process.env.Q : ''), { waitUntil: 'networkidle0' });
await page.waitForFunction(() => window.__ready === true, { timeout: 60000 });
for (const t of ts) {
  await page.evaluate((x) => window.__seek(x), Number(t));
  await page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))));
  const f = `${dir}/t${Number(t).toFixed(2).padStart(6, '0')}.png`;
  await page.screenshot({ path: f, type: 'png' });
  console.log(f);
}
await browser.close();
