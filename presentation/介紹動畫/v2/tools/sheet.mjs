// 指定秒數逐格截圖並拼成總覽，供人工檢查版面。
// 用法：node tools/sheet.mjs <輸出檔> <秒數...>；需先 npm run dev（5290 埠）。
import { createRequire } from 'node:module';
import { dirname, resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { mkdirSync } from 'node:fs';
import sharp from 'sharp';

const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const puppeteer = require(resolve(here, '../../src/node_modules/puppeteer'));

const [out, ...times] = process.argv.slice(2);
const ts = times.map(Number);
const dir = join(here, '../.frames');
mkdirSync(dir, { recursive: true });

const browser = await puppeteer.launch({ headless: true, args: ['--use-angle=metal', '--enable-gpu', '--ignore-gpu-blocklist'] });
const page = await browser.newPage();
await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 1 });
page.on('pageerror', (e) => console.log('pageerror', e.message));
page.on('console', (m) => { if (m.type() === 'error') console.log('console', m.text()); });
await page.goto('http://127.0.0.1:5290/?render', { waitUntil: 'networkidle0' });
await page.waitForFunction(() => window.__ready === true, { timeout: 60000 });
const files = [];
for (const t of ts) {
  await page.evaluate((x) => window.__seek(x), t);
  await page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))));
  const f = join(dir, `f-${t.toFixed(2)}.png`);
  await page.screenshot({ path: f });
  files.push({ f, label: `${t.toFixed(2)}s` });
}
await browser.close();

const cols = Math.min(4, files.length);
const tw = 480, th = 270;
const rows = Math.ceil(files.length / cols);
const tiles = await Promise.all(files.map(async ({ f, label }, i) => {
  const img = await sharp(f).resize(tw, th).toBuffer();
  const svg = Buffer.from(`<svg width="${tw}" height="20" xmlns="http://www.w3.org/2000/svg"><rect width="64" height="20" fill="#000" opacity=".7"/><text x="4" y="15" font-size="13" fill="#ff0" font-family="Menlo">${label}</text></svg>`);
  return { input: await sharp(img).composite([{ input: svg, top: 0, left: 0 }]).toBuffer(), left: (i % cols) * (tw + 6), top: Math.floor(i / cols) * (th + 6) };
}));
await sharp({ create: { width: cols * (tw + 6), height: rows * (th + 6), channels: 3, background: '#222' } }).composite(tiles).png().toFile(out);
console.log('sheet', out, files.length);
