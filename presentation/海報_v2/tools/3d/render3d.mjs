// 書櫃 3D 算圖：node tools/3d/render3d.mjs <out.png> '<cfg JSON>'
//   cfg: { model, w, h, cam:[x,y,z]（以模型最大邊為單位）, target, fov, exposure, key, ambient, light, shadow, shadowOpacity, ortho, zoom }
import { createServer } from 'node:http';
import { createReadStream, existsSync, statSync, writeFileSync } from 'node:fs';
import { dirname, extname, join, normalize, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer-core';
const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const [out, cfgJson] = process.argv.slice(2);
const cfg = { model: '/src/assets/model/cabinet.glb', w: 2400, h: 2400, ...JSON.parse(cfgJson || '{}') };
const T = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.glb': 'model/gltf-binary', '.png': 'image/png' };
const server = createServer((req, res) => {
  const p = normalize(join(ROOT, decodeURIComponent(new URL(req.url, 'http://x').pathname)));
  if (!p.startsWith(ROOT + sep) || !existsSync(p) || !statSync(p).isFile()) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'Content-Type': T[extname(p)] || 'application/octet-stream' }); createReadStream(p).pipe(res);
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const browser = await puppeteer.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
try {
  const page = await browser.newPage();
  page.on('pageerror', (e) => console.error('pageerror', e.message));
  page.on('console', (m) => { if (m.type() === 'error') console.error(m.text()); });
  await page.setViewport({ width: cfg.w, height: cfg.h, deviceScaleFactor: 1 });
  await page.goto(`http://127.0.0.1:${server.address().port}/tools/3d/scene.html?cfg=${Buffer.from(JSON.stringify(cfg)).toString('base64')}`);
  await page.waitForFunction('window.__done === true', { timeout: 300000 });
  const data = await page.evaluate(() => document.querySelector('canvas').toDataURL('image/png'));
  writeFileSync(out, Buffer.from(data.split(',')[1], 'base64'));
  console.log(out, JSON.stringify(await page.evaluate('window.__info')));
} finally { await browser.close(); server.close(); }
