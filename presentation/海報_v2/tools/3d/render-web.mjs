// 官網現行書櫃模型算圖：node tools/3d/render-web.mjs <out.png> '<cfg JSON>'
//   cfg：{ w, h, yaw, pitch, dist, fov, target, doors:[…], xray, exposure, kiosk, glb }（見 web/harness.ts）
//   glb: true 時改輸出模型：node tools/3d/render-web.mjs <out.glb> '{"glb":true,"w":1600,"ay":0.5,"pitch":0.17}'
//     另寫 <out>-preview.png（PowerPoint 同相機的替代圖，正方形視野）與 <out>.json（相機與投影範圍）
//   seq: 'deposit'|'pickup' 時 <out> 是資料夾，依 fps、dur 逐格輸出存書／取書動畫（時間軸見 web/harness.ts）
//   第一次或官網模型更新後要重新打包：node tools/3d/render-web.mjs --build
import { createServer } from 'node:http';
import { createReadStream, existsSync, mkdirSync, statSync, writeFileSync } from 'node:fs';
import { dirname, extname, join, normalize, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import esbuild from 'esbuild';
import puppeteer from 'puppeteer-core';
const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const WEB_PUBLIC = resolve(ROOT, '..', '..', 'savemybook_web', 'public');
const args = process.argv.slice(2);
async function build() {
  await esbuild.build({ entryPoints: [join(ROOT, 'tools/3d/web/harness.ts')], bundle: true, outfile: join(ROOT, 'tools/3d/web/bundle.js'), format: 'iife', nodePaths: [join(ROOT, 'node_modules')], logLevel: 'warning' });
}
if (args[0] === '--build' || !existsSync(join(ROOT, 'tools/3d/web/bundle.js'))) { await build(); if (args[0] === '--build') { console.log('bundled'); process.exit(0); } }
const [out, cfgJson] = args;
const cfg = { w: 2400, h: 2400, ...JSON.parse(cfgJson || '{}') };
const T = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.png': 'image/png', '.webp': 'image/webp', '.stl': 'application/octet-stream', '.ttf': 'font/ttf' };
const server = createServer((req, res) => {
  const u = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  let p = normalize(join(ROOT, u));
  if (!existsSync(p)) p = normalize(join(WEB_PUBLIC, u)); // 官網 public/（/model、/brand）
  const ok = (p.startsWith(ROOT + sep) || p.startsWith(WEB_PUBLIC + sep)) && existsSync(p) && statSync(p).isFile();
  if (!ok) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'Content-Type': T[extname(p).toLowerCase()] || 'application/octet-stream' }); createReadStream(p).pipe(res);
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const browser = await puppeteer.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
try {
  const page = await browser.newPage();
  page.on('pageerror', (e) => console.error('pageerror', e.message));
  page.on('console', (m) => { if (m.type() === 'error') console.error(m.text()); });
  await page.setViewport({ width: cfg.w, height: cfg.h, deviceScaleFactor: 1 });
  await page.goto(`http://127.0.0.1:${server.address().port}/tools/3d/web/index.html?cfg=${Buffer.from(JSON.stringify(cfg)).toString('base64')}`);
  await page.waitForFunction('window.__done === true || !!window.__error', { timeout: 300000 });
  const err = await page.evaluate('window.__error'); if (err) throw new Error(err);
  if (cfg.seq) {
    // 時間軸模式：<out> 是資料夾，依 fps、dur 逐格輸出 00000.png…
    mkdirSync(out, { recursive: true });
    const n = Math.round(cfg.dur * cfg.fps);
    for (let i = 0; i < n; i++) {
      const url = await page.evaluate(`window.__seqFrame(${i / cfg.fps})`);
      writeFileSync(join(out, `${String(i).padStart(5, '0')}.png`), Buffer.from(url.split(',')[1], 'base64'));
    }
    console.log(out, `${n} 格`);
  } else {
    const data = await page.evaluate(() => document.querySelector('canvas').toDataURL('image/png'));
    if (cfg.glb) {
      // <out>.glb 之外，另存同一相機的替代圖 <out>-preview.png 與相機參數 <out>.json（簡報嵌入 3D 模型用）
      writeFileSync(out, Buffer.from(await page.evaluate('window.__glb'), 'base64'));
      const base = out.replace(/\.glb$/i, '');
      writeFileSync(`${base}-preview.png`, Buffer.from(data.split(',')[1], 'base64'));
      writeFileSync(`${base}.json`, JSON.stringify(await page.evaluate('window.__model3d'), null, 2));
    } else writeFileSync(out, Buffer.from(data.split(',')[1], 'base64'));
    console.log(out, JSON.stringify(await page.evaluate('window.__info')));
  }
} finally { await browser.close(); server.close(); }
