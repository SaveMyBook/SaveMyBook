// 斷行檢查：列出所有文字區塊中最後一行只剩 1～2 個字的情況（例如標題「輸入 ISBN，帶出書」＋「目」）。
// 用法：node tools/wrap.mjs；需先 npm run dev（5291 埠）。
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const puppeteer = require('puppeteer');

const browser = await puppeteer.launch({ headless: true });
const page = await browser.newPage();
await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 1 });
await page.goto('http://127.0.0.1:5291/?render', { waitUntil: 'networkidle0' });
await page.waitForFunction(() => window.__ready === true, { timeout: 60000 });
const found = await page.evaluate(() => {
  for (const l of document.querySelectorAll('.layer')) l.style.display = '';
  const out = [];
  const sel = '.cap__title, .cap__body, .cap__eyebrow, .sub, .rise, .chip, .gate__row, .gate__title, .banner__title, .banner__body, .arch-node b, .arch-node small, .arch-server small, .stat2__unit, .stat2__note, .fee-row, .fee-cap, .tile b, .mark__tag, .ptag, .stepbar span, .xlabel, .lcard__title, .h-display, p';
  for (const e of document.querySelectorAll(sel)) {
    const text = e.textContent.trim();
    if (!text) continue;
    const range = document.createRange();
    range.selectNodeContents(e);
    const rects = [...range.getClientRects()].filter((r) => r.width > 0);
    if (!rects.length) continue;
    const fs = parseFloat(getComputedStyle(e).fontSize);
    // 同一行的字距、圖示高度不同，頂端相差半個字高以內視為同一行
    const tops = [];
    for (const t of rects.map((r) => r.top).sort((a, b) => a - b)) if (!tops.length || t - tops[tops.length - 1] > fs * 0.5) tops.push(t);
    if (tops.length < 2) continue;
    const lastTop = tops[tops.length - 1];
    const lastWidth = rects.filter((r) => r.top >= lastTop - 0.1).reduce((s, r) => s + r.width, 0);
    // 側邊說明的標題一律一行
    if (e.classList.contains('cap__title')) out.push({ text, lines: tops.length, last: +(lastWidth / fs).toFixed(1), cls: 'cap__title 換行' });
    else if (lastWidth < fs * 2.6) out.push({ text, lines: tops.length, last: +(lastWidth / fs).toFixed(1), cls: e.className });
  }
  return out;
});
await browser.close();
for (const f of found) console.log(`${f.lines} 行，末行約 ${f.last} 字寬  [${f.cls}]  ${f.text}`);
console.log(found.length ? `共 ${found.length} 處` : '沒有孤字斷行');
