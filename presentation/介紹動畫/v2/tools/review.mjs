// 交付前逐格檢查：依間隔截圖，每張總覽 2 欄 × 4 列、每格 960×540（原尺寸的一半），細節看得清楚。
// 用法：node tools/review.mjs <輸出前綴> <起秒> <迄秒> [間隔秒]；需先 npm run dev（5290 埠）。
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const puppeteer = require(resolve(here, '../../src/node_modules/puppeteer'));

const [prefix, a, b, stepArg = '0.5'] = process.argv.slice(2);
const step = Number(stepArg);
const times = [];
for (let t = Number(a); t <= Number(b) + 1e-6; t += step) times.push(+t.toFixed(3));

const browser = await puppeteer.launch({ headless: true, args: ['--use-angle=metal', '--enable-gpu', '--ignore-gpu-blocklist'] });
const page = await browser.newPage();
await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 1 });
page.on('pageerror', (e) => console.log('pageerror', e.message));
await page.goto('http://127.0.0.1:5290/?render', { waitUntil: 'networkidle0' });
await page.waitForFunction(() => window.__ready === true, { timeout: 60000 });
const shots = [];
for (const t of times) {
  await page.evaluate((x) => window.__seek(x), t);
  await page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))));
  shots.push({ t, buf: await page.screenshot({ type: 'png' }) });
}
await browser.close();

const per = 8, tw = 960, th = 540;
for (let s = 0; s * per < shots.length; s++) {
  const group = shots.slice(s * per, s * per + per);
  const tiles = await Promise.all(group.map(async ({ t, buf }, i) => {
    const img = await sharp(buf).resize(tw, th).toBuffer();
    const svg = Buffer.from(`<svg width="90" height="26" xmlns="http://www.w3.org/2000/svg"><rect width="90" height="26" fill="#000" opacity=".75"/><text x="6" y="19" font-size="17" fill="#ff0" font-family="Menlo">${t.toFixed(2)}s</text></svg>`);
    return { input: await sharp(img).composite([{ input: svg, top: 0, left: 0 }]).toBuffer(), left: (i % 2) * (tw + 4), top: Math.floor(i / 2) * (th + 4) };
  }));
  const out = `${prefix}-${String(s + 1).padStart(2, '0')}.png`;
  await sharp({ create: { width: tw * 2 + 4, height: 4 * (th + 4), channels: 3, background: '#222' } }).composite(tiles).png().toFile(out);
  console.log(out);
}
