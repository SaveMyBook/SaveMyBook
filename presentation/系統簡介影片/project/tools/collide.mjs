// 穿模檢查：逐格取手機機身、書櫃本體、浮出書櫃螢幕的方向盒（OBB），以分離軸定理判斷兩兩是否相交。
// 用法：node tools/collide.mjs [起秒] [迄秒] [間隔秒]；需先 npm run dev（5291 埠）。
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const puppeteer = require('puppeteer');
const [a = '0', b = '36', stepArg = '1/60'] = process.argv.slice(2);
const step = eval(stepArg);
// 機身半尺寸（公分）：寬、高、厚（含背面相機凸起）
const HALF = [7.15 / 2, 14.96 / 2, 0.83 / 2 + 0.25];

function box(m, half = HALF) {
  const axes = [[m[0], m[1], m[2]], [m[4], m[5], m[6]], [m[8], m[9], m[10]]];
  const len = axes.map((v) => Math.hypot(...v));
  return { c: [m[12], m[13], m[14]], u: axes.map((v, i) => v.map((x) => x / len[i])), e: half.map((h, i) => h * len[i]) };
}
const dot = (p, q) => p[0] * q[0] + p[1] * q[1] + p[2] * q[2];
const cross = (p, q) => [p[1] * q[2] - p[2] * q[1], p[2] * q[0] - p[0] * q[2], p[0] * q[1] - p[1] * q[0]];
function overlap(A, B) {
  const d = [B.c[0] - A.c[0], B.c[1] - A.c[1], B.c[2] - A.c[2]];
  const axes = [...A.u, ...B.u];
  for (const x of A.u) for (const y of B.u) { const c = cross(x, y); if (Math.hypot(...c) > 1e-6) axes.push(c); }
  let min = Infinity;
  for (const L of axes) {
    const n = Math.hypot(...L);
    const l = L.map((v) => v / n);
    const ra = A.e.reduce((s, e, i) => s + e * Math.abs(dot(A.u[i], l)), 0);
    const rb = B.e.reduce((s, e, i) => s + e * Math.abs(dot(B.u[i], l)), 0);
    const gap = Math.abs(dot(d, l)) - ra - rb;
    if (gap > 0) return null;
    min = Math.min(min, -gap);
  }
  return min;
}

const browser = await puppeteer.launch({ headless: true, args: ['--use-angle=metal', '--enable-gpu'] });
const page = await browser.newPage();
await page.setViewport({ width: 1920, height: 1080 });
await page.goto('http://127.0.0.1:5291/?render', { waitUntil: 'networkidle0' });
await page.waitForFunction(() => window.__ready === true, { timeout: 60000 });
const hits = [];
const end = Math.min(Number(b), await page.evaluate(() => window.__duration));
for (let t = Number(a); t <= end + 1e-9; t += step) {
  // 手機、書櫃本體、浮出的書櫃螢幕兩兩檢查（浮出螢幕本來就由書櫃螢幕原位浮起，只在浮出時才算進來）
  const solids = await page.evaluate((x) => window.__solids(x), t);
  const boxes = solids.map((s) => ({ name: s.name, ...box(s.m, s.half) }));
  for (let i = 0; i < boxes.length; i++) for (let j = i + 1; j < boxes.length; j++) {
    const o = overlap(boxes[i], boxes[j]);
    if (o != null && o > 0.02) hits.push(`${t.toFixed(3)}s ${boxes[i].name}×${boxes[j].name} 重疊深度 ${o.toFixed(2)}`);
  }
}
await browser.close();
console.log(hits.length ? hits.join('\n') : '無穿模');
console.log(`共 ${hits.length} 筆`);
