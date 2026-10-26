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
await page.evaluateOnNewDocument(() => { window.WebSocket = class { addEventListener() {} removeEventListener() {} send() {} close() {} }; }); // 停用 Vite 的熱更新連線：其他人存檔時頁面不會重新載入、檢查不會中斷
// 環境變數 Q 會加到網址參數（v3 輸出用 Q=v3）；各段在載入完成後才登記音效，所以等 __ready
await page.goto('http://127.0.0.1:5291/?render' + (process.env.Q ? '&' + process.env.Q : ''), { waitUntil: 'networkidle0' });
await page.waitForFunction(() => window.__ready === true, { timeout: 120000 });
const data = await page.evaluate(() => window.__cues);
await browser.close();
writeFileSync(join(here, '../audio/cues.json'), JSON.stringify(data, null, 1));
console.log('cues', data.cues.length);
