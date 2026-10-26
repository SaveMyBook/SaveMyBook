// 新版樣片的版面檢查（比照 NTUB REEL_CHECK）：node tools/reelcheck.mjs <起秒> <迄秒> [間隔秒] [--detail]；網址參數用環境變數 Q（例如 Q=v3）。
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const puppeteer = require('puppeteer');
const args = process.argv.slice(2);
const detail = args.includes('--detail');
const [a, b, st = '0.1'] = args.filter((x) => x !== '--detail');
const browser = await puppeteer.launch({ headless: true, args: ['--use-angle=metal', '--enable-gpu'] });
const page = await browser.newPage();
await page.evaluateOnNewDocument(() => { window.WebSocket = class { addEventListener() {} removeEventListener() {} send() {} close() {} }; }); // 停用 Vite 的熱更新連線：其他人存檔時頁面不會重新載入、檢查不會中斷
await page.setViewport({ width: 1920, height: 1080 });
await page.goto('http://127.0.0.1:5291/?render' + (process.env.Q ? '&' + process.env.Q : ''), { waitUntil: 'networkidle0' });
await page.waitForFunction(() => window.__ready === true, { timeout: 60000 });
const seen = new Map();
for (let t = Number(a); t <= Number(b) + 1e-9; t += Number(st)) {
  const r = await page.evaluate(async (x) => { await window.__seek(x); return window.__reelCheck(x); }, t);
  if (detail) console.log(t.toFixed(2), JSON.stringify(r));
  for (const k of r.out) {
    const key = k.replace(/\d+px/, '').replace(/x [\d–-]+ y [\d–-]+/, '');
    if (!seen.has(key)) seen.set(key, { t0: t, t1: t, sample: k });
    else seen.get(key).t1 = t;
  }
}
await browser.close();
const rows = [...seen.values()].map((v) => `${v.t0.toFixed(2)}–${v.t1.toFixed(2)}s  ${v.sample}`);
console.log(rows.join('\n') || '無問題');
console.log(`共 ${rows.length} 項`);
