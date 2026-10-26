// v3 段落交界檢查：每個交界前後 0.7 秒逐格（1/60 秒）列出畫面上看得到的物件，量出「整格只剩背景」的時長，
// 並抓出物件消失後又閃現（例如交界前後 0.05 秒兩段同時寫入、鏡頭已換成下一段時，上一段的物件被看到）。
// 用法：Q=v3 node tools/bounds.mjs [最長空白秒數，預設 0.3]
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const puppeteer = require('puppeteer');
const maxGap = Number(process.argv[2] ?? 0.3);
const browser = await puppeteer.launch({ headless: true, args: ['--use-angle=metal', '--enable-gpu'] });
const page = await browser.newPage();
await page.evaluateOnNewDocument(() => { window.WebSocket = class { addEventListener() {} removeEventListener() {} send() {} close() {} }; });
await page.setViewport({ width: 1920, height: 1080 });
await page.goto('http://127.0.0.1:5291/?render' + (process.env.Q ? '&' + process.env.Q : ''), { waitUntil: 'networkidle0' });
await page.waitForFunction(() => window.__ready === true, { timeout: 120000 });
const sections = await page.evaluate(() => window.__cues.sections);
let bad = 0;
for (const s of sections.slice(1)) {
  const b = s.start;
  const rows = [];
  for (let f = -42; f <= 42; f++) {
    const t = +(b + f / 60).toFixed(4);
    const r = await page.evaluate(async (x) => { await window.__seek(x); return window.__reelCheck(x); }, t);
    rows.push({ t, n: r.objs.length, objs: r.objs });
  }
  // 最長的連續空白、空白之後又出現再消失（閃現）
  let run = 0, best = 0;
  for (const r of rows) { run = r.n === 0 ? run + 1 : 0; best = Math.max(best, run); }
  const flicker = [];
  for (let i = 1; i < rows.length - 1; i++) if (rows[i].n > 0 && rows[i - 1].n === 0 && rows[i + 1].n === 0) flicker.push(rows[i].t);
  const gap = best / 60;
  // 物件一直看得到、到交界那一格才突然消失（上一段在交界前沒有出畫）
  const pre = rows.filter((r) => r.t < b - 1e-6), post = rows.filter((r) => r.t >= b - 1e-6);
  if (pre.length && post.length && pre[pre.length - 1].n > 0 && post[0].n === 0) flicker.push(`交界前仍可見 ${pre[pre.length - 1].objs.join('；')}`);
  if (pre.length && post.length && post[0].n > 0 && pre[pre.length - 1].n === 0 && post[0].t < b + 0.02) flicker.push(`交界後立刻出現 ${post[0].objs.join('；')}`);
  const ok = gap <= maxGap + 1e-6 && flicker.length === 0;
  if (!ok) bad++;
  // 上一段最後看得到物件的格到交界、交界到下一段第一格看得到物件（校正 camera.ts 的 PANS 用）
  const lastPre = [...pre].reverse().find((r) => r.n > 0), firstPost = post.find((r) => r.n > 0);
  const side = `（出畫 ${lastPre ? (b - lastPre.t).toFixed(3) : '-'}／入畫 ${firstPost ? (firstPost.t - b).toFixed(3) : '-'}）`;
  console.log(`${s.id.padEnd(9)} ${b.toFixed(2)}s  空白 ${gap.toFixed(3)} 秒${side}${flicker.length ? `  閃現 ${flicker.join(', ')}` : ''}${ok ? '' : '  ←'}`);
}
await browser.close();
console.log(bad ? `共 ${bad} 處超過 ${maxGap} 秒或有閃現` : '全部通過');
