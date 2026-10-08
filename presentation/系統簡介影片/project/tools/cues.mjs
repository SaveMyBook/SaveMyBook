// 匯出各場景登記的卡點音效時間到 audio/cues.json。需先 npm run dev（5291 埠）。
import { createRequire } from 'node:module';
import { dirname, resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { writeFileSync } from 'node:fs';

const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const puppeteer = require('puppeteer');
const browser = await puppeteer.launch({ headless: true });
const page = await browser.newPage();
await page.goto('http://127.0.0.1:5291/?render', { waitUntil: 'networkidle0' });
const data = await page.evaluate(() => window.__cues);
await browser.close();
writeFileSync(join(here, '../audio/cues.json'), JSON.stringify(data, null, 1));
console.log('cues', data.cues.length);
