// 由網站序章畫面產生社群分享預覽圖 public/og.jpg（1200 × 630）。
import { createRequire } from 'node:module';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const web = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const require = createRequire(import.meta.url);
const puppeteer = require(resolve(web, '../presentation/介紹動畫/src/node_modules/puppeteer'));
const url = process.argv[2] || 'http://127.0.0.1:5280/';

const browser = await puppeteer.launch({ headless: true, args: ['--use-angle=metal', '--enable-gpu', '--ignore-gpu-blocklist'] });
const page = await browser.newPage();
await page.setViewport({ width: 1200, height: 630, deviceScaleFactor: 2 });
await page.goto(url, { waitUntil: 'networkidle0' });
await page.evaluate(() => document.fonts.ready);
await page.addStyleTag({ content: '.masthead, .fore-edge, .cover__turn, .cover__spine { visibility: hidden !important; } .cover__text { bottom: 70px !important; }' });
await new Promise((r) => setTimeout(r, 3500));
const png = await page.screenshot();
await sharp(png).resize(1200, 630).jpeg({ quality: 88, mozjpeg: true }).toFile(join(web, 'public/og.jpg'));
await browser.close();
console.log('og.jpg');
