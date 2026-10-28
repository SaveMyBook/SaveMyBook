// 官網現行書櫃模型算圖：node tools/3d/render-web.mjs <out.png> '<cfg JSON>'
//   cfg：{ w, h, yaw, pitch, dist, fov, target, doors:[…], xray, exposure, kiosk }（見 web/harness.ts）
//   第一次或官網模型更新後要重新打包：node tools/3d/render-web.mjs --build
import { createServer } from 'node:http';
import { createReadStream, existsSync, statSync, writeFileSync } from 'node:fs';
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
  const data = await page.evaluate(() => document.querySelector('canvas').toDataURL('image/png'));
  writeFileSync(out, Buffer.from(data.split(',')[1], 'base64'));
  console.log(out, JSON.stringify(await page.evaluate('window.__info')));
} finally { await browser.close(); server.close(); }
