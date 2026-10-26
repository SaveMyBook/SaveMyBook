// 沿各章節進度逐格截圖並拼成總覽，供人工逐張檢查版面。
// 用法：node scripts/shoot.mjs [網址] [寬度或寬x高...]，預設 http://127.0.0.1:5280/、1440 與 390。
import { createRequire } from 'node:module';
import { mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const here = dirname(fileURLToPath(import.meta.url));
const web = resolve(here, '..');
const require = createRequire(import.meta.url);
const puppeteer = require(resolve(web, '../presentation/介紹動畫/src/node_modules/puppeteer'));

const url = process.argv[2] || 'http://127.0.0.1:5280/';
const specs = process.argv.slice(3).filter(Boolean);
const sizes = (specs.length ? specs : ['1440', '390']).map((spec) => {
  const [w, h] = spec.split('x').map(Number);
  return w < 700 ? { w, h: h || 844, mobile: true } : { w, h: h || 900, mobile: false };
});
const out = join(web, '.shots');
mkdirSync(out, { recursive: true });

const PLAN = [
  ['top', [0]],
  ['survey', ['mid']],
  ['sell', ['enter', 'mid']],
  ['advisor', ['enter', 'mid']],
  ['chat', ['top', 'bottom']],
  ['cabinet', ['top']],
  ['cab-pin', [0, 0.07, 0.16, 0.3, 0.37, 0.53, 0.6, 0.7, 0.84, 0.97]],
  ['board', ['enter', 'mid']],
  ['pay', ['enter', 'mid']],
  ['fee', ['mid']],
  ['ai-rules', ['mid']],
  ['lang', ['mid']],
  ['system', ['mid']],
  ['end', ['end']],
];

const browser = await puppeteer.launch({ headless: true, args: ['--use-angle=metal', '--enable-gpu', '--ignore-gpu-blocklist'] });
for (const size of sizes) {
  const page = await browser.newPage();
  await page.setViewport({ width: size.w, height: size.h, deviceScaleFactor: 1, isMobile: size.mobile, hasTouch: size.mobile });
  page.on('pageerror', (e) => console.log('pageerror', e.message));
  page.on('console', (m) => { if (m.type() === 'error') console.log('console', m.text()); });
  await page.goto(url, { waitUntil: 'networkidle0' });
  await page.evaluate(() => document.fonts.ready);
  await new Promise((r) => setTimeout(r, 2500));
  const files = [];
  for (const [id, ps] of PLAN) {
    for (const p of ps) {
      await page.evaluate((i, k) => {
        const el = i === 'cab-pin' ? document.querySelector('[data-pin="cab"]') : document.getElementById(i);
        const top = el.getBoundingClientRect().top + scrollY, h = el.offsetHeight, vh = innerHeight;
        const y = typeof k === 'number' ? top + (h - vh) * k
          : k === 'top' ? top - 52 : k === 'enter' ? top - vh * 0.62 : k === 'mid' ? top + h / 2 - vh / 2
          : k === 'bottom' ? top + h - vh : document.documentElement.scrollHeight - vh;
        const lenis = window.__site?.lenis;
        if (lenis) lenis.scrollTo(Math.max(0, y), { immediate: true, force: true }); else scrollTo(0, Math.max(0, y));
      }, id, p);
      await new Promise((r) => setTimeout(r, 1400));
      const f = join(out, `${size.w}x${size.h}-${id}-${String(p).replace('.', '_')}.png`);
      await page.screenshot({ path: f });
      files.push({ f, label: `${id} ${p}` });
    }
  }
  await page.close();
  // 總覽
  const tw = size.mobile ? 195 : 480;
  const th = Math.round(tw * size.h / size.w);
  const cols = size.mobile ? 8 : 4;
  const rows = Math.ceil(files.length / cols);
  const tiles = await Promise.all(files.map(async ({ f, label }, i) => {
    const img = await sharp(f).resize(tw, th).toBuffer();
    const svg = Buffer.from(`<svg width="${tw}" height="18" xmlns="http://www.w3.org/2000/svg"><rect width="${tw}" height="18" fill="#000" opacity=".7"/><text x="4" y="13" font-size="12" fill="#ff0" font-family="Menlo">${label}</text></svg>`);
    const tile = await sharp(img).composite([{ input: svg, top: 0, left: 0 }]).toBuffer();
    return { input: tile, left: (i % cols) * (tw + 6), top: Math.floor(i / cols) * (th + 6) };
  }));
  await sharp({ create: { width: cols * (tw + 6), height: rows * (th + 6), channels: 3, background: '#222' } })
    .composite(tiles).png().toFile(join(out, `sheet-${size.w}x${size.h}.png`));
  console.log('sheet', size.w, files.length);
}
await browser.close();
