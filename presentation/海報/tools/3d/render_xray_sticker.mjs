// 海報 3 用：cabinet_xray.png（v1，deck.html?mode=xray，pr 4.5）的貼紙修正版。
// 取景、模型、材質與 render3d.mjs xray 完全相同，只改書櫃正面頂列左側的標誌貼紙（logo＋救「舊」我的書＋SaveMyBook）：
//   stickerfix：貼紙比照透視時的壓克力面板一起淡化（不透明度 = 壓克力透視係數），不寫深度、仍畫在面板之後；
//               貼紙畫布改為同畫法的 4 倍解析度（圖示改用 512 版 book-slate.webp），淡化後仍可辨識。
//   nosticker ：不顯示貼紙。
//   base      ：不改任何東西（用來確認與現有 cabinet_xray.png 相同）。
// 不改 介紹動畫/v2 原始檔：以請求攔截在 deck.ts（vite 轉譯後）末尾加一行，把 cab / stage / THREE 掛到 window。
// 需先在 介紹動畫/v2 執行 npm run dev（5290 埠）。
//
//   node render_xray_sticker.mjs [variants=stickerfix,nosticker] [pr=4.5]
//   環境變數：STICKER_OPACITY（預設 0.1）、OUT（輸出資料夾）、BASE_OUT（base 版輸出檔，預設不存）
import { dirname, resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { mkdirSync, writeFileSync } from 'node:fs';
import puppeteer from 'puppeteer-core';
import sharp from 'sharp';

const here = dirname(fileURLToPath(import.meta.url));
const OUT = resolve(process.env.OUT || resolve(here, '../../src/assets/3d'));
const PORT = process.env.DECK_PORT || '5290';
const BASE = `http://127.0.0.1:${PORT}`;
const CHROME = process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const VARIANTS = (process.argv[2] || 'stickerfix,nosticker').split(',');
const PR = Number(process.argv[3] || 4.5);
const OPACITY = Number(process.env.STICKER_OPACITY || 0.1);
mkdirSync(OUT, { recursive: true });

const browser = await puppeteer.launch({
  executablePath: CHROME, headless: true, protocolTimeout: 900000,
  args: ['--use-angle=d3d11', '--enable-gpu', '--ignore-gpu-blocklist', '--hide-scrollbars', '--force-color-profile=srgb'],
});
const W = 1300, H = 1250;
const page = await browser.newPage();
await page.setViewport({ width: W, height: H, deviceScaleFactor: PR });
page.on('pageerror', (e) => console.log('pageerror', e.message));
page.on('console', (m) => { if ((m.type() === 'error' || m.type() === 'warn') && !m.text().includes('X4122')) console.log('console', m.text()); });
await page.setRequestInterception(true);
page.on('request', async (req) => {
  const u = new URL(req.url());
  if (u.pathname === '/src/deck.ts') {
    const js = await (await fetch(BASE + u.pathname + u.search)).text();
    const body = js.replace(/\/\/# sourceMappingURL=.*$/m, '') + '\nwindow.__dk = { get cab() { return cab; }, stage, THREE };\n';
    return req.respond({ status: 200, contentType: 'text/javascript', body });
  }
  req.continue();
});

await page.goto(`${BASE}/deck.html?mode=xray&w=${W}&h=${H}&pr=${PR}`, { waitUntil: 'networkidle0', timeout: 300000 });
await page.waitForFunction(() => window.__ready === true && !!window.__dk, { timeout: 300000 });
await page.evaluate(() => document.fonts.ready);
const gi = await page.evaluate(() => {
  const gl = window.__dk.stage.renderer.getContext();
  const c = gl.canvas;
  return { canvas: [c.width, c.height], drawingBuffer: [gl.drawingBufferWidth, gl.drawingBufferHeight] };
});
console.log('WebGL', JSON.stringify(gi));
if (gi.drawingBuffer[0] !== gi.canvas[0] || gi.drawingBuffer[1] !== gi.canvas[1]) throw new Error('drawing buffer 被縮小');

// 找出貼紙，並記錄透視時的材質設定（報告用）
const before = await page.evaluate(() => {
  const { cab } = window.__dk;
  const found = [];
  cab.group.traverse((o) => { if (o.isMesh && o.geometry?.parameters?.width === 3.85 && o.geometry?.parameters?.height === 1.1) found.push(o); });
  if (found.length !== 1) throw new Error('貼紙數量不符：' + found.length);
  window.__sticker = found[0];
  const m = found[0].material;
  const shell = cab.shellMats.map((s) => ({ type: s.type, opacity: +s.opacity.toFixed(4), transparent: s.transparent, depthWrite: s.depthWrite }));
  const edge = cab.edges[0].material;
  return {
    sticker: { opacity: m.opacity, transparent: m.transparent, depthWrite: m.depthWrite, depthTest: m.depthTest, toneMapped: m.toneMapped, renderOrder: found[0].renderOrder, map: m.map ? [m.map.image.width, m.map.image.height] : null },
    shell, edge: { color: '#' + edge.color.getHexString(), opacity: edge.opacity },
  };
});
console.log('透視時材質', JSON.stringify(before));

const frame = () => page.evaluate(() => new Promise((r) => { window.__dk.stage.render(); requestAnimationFrame(() => requestAnimationFrame(r)); }));
const shot = () => page.screenshot({ omitBackground: true, type: 'png', captureBeyondViewport: false });

async function cropAlpha(buf, margin) {
  const { data, info } = await sharp(buf).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  let x0 = info.width, y0 = info.height, x1 = -1, y1 = -1;
  for (let y = 0; y < info.height; y++) for (let x = 0; x < info.width; x++) {
    if (data[(y * info.width + x) * 4 + 3] > 2) { if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
  }
  const left = Math.max(0, x0 - margin), top = Math.max(0, y0 - margin);
  const width = Math.min(info.width, x1 + margin + 1) - left, height = Math.min(info.height, y1 + margin + 1) - top;
  const touches = { left: x0 === 0, top: y0 === 0, right: x1 === info.width - 1, bottom: y1 === info.height - 1 };
  return { buf: await sharp(buf).extract({ left, top, width, height }).png().toBuffer(), left, top, width, height, touches, full: [info.width, info.height] };
}
const save = (buf, file) => sharp(buf).withMetadata({ density: 300 }).png({ compressionLevel: 9 }).toFile(file);

const info = await page.evaluate(() => window.__info());
const results = {};
for (const v of VARIANTS) {
  if (v === 'stickerfix') {
    const r = await page.evaluate(async (OPACITY) => {
      const { THREE, cab } = window.__dk;
      const s = window.__sticker;
      const loadImage = (src) => new Promise((res, rej) => { const i = new Image(); i.onload = () => res(i); i.onerror = rej; i.src = src; });
      // 同 cabinet.ts brandSticker 的畫法，放大 4 倍
      const SK = 4;
      const mark = await loadImage('/brand/book-slate.webp');
      await document.fonts.load('700 78px "Noto Sans TC"', '救「舊」我的書');
      await document.fonts.load('500 46px "Noto Sans TC"', 'SaveMyBook');
      const c = document.createElement('canvas');
      c.width = 840 * SK; c.height = 240 * SK;
      const g = c.getContext('2d');
      g.scale(SK, SK);
      g.drawImage(mark, 40, 40, 160, 160);
      g.textBaseline = 'middle';
      g.font = '700 78px "Noto Sans TC", sans-serif';
      let x = 228;
      for (const [t, color] of [['救', '#151E27'], ['「舊」', '#627D8D'], ['我的書', '#151E27']]) { g.fillStyle = color; g.fillText(t, x, 100); x += g.measureText(t).width; }
      g.fillStyle = '#627D8D';
      g.font = '500 46px "Noto Sans TC", sans-serif';
      g.fillText('SaveMyBook', 234, 174);
      const tex = new THREE.CanvasTexture(c);
      tex.colorSpace = THREE.SRGBColorSpace; tex.anisotropy = 8;
      const m = s.material;
      m.map = tex;
      // 與壓克力面板同一套透視淡化：面板 0.94 → 0.094（× 0.1），貼紙 1 → OPACITY
      m.opacity = OPACITY;
      m.transparent = true;
      m.depthWrite = false;
      m.needsUpdate = true;
      s.visible = true;
      return { opacity: m.opacity, face: cab.shellMats[2].opacity, map: [c.width, c.height] };
    }, OPACITY);
    console.log('stickerfix', JSON.stringify(r));
  } else if (v === 'nosticker') {
    await page.evaluate(() => { window.__sticker.visible = false; });
  } else if (v !== 'base') throw new Error('未知變體 ' + v);
  await frame();
  const buf = await shot();
  const c = await cropAlpha(buf, Math.round(40 * PR / 2));
  const name = v === 'base' ? (process.env.BASE_OUT || null) : `cabinet_xray_v1_${v}.png`;
  if (name) await save(c.buf, resolve(OUT, name));
  results[v] = { file: name, left: c.left, top: c.top, width: c.width, height: c.height, full: c.full, touches: c.touches };
  console.log(v, JSON.stringify(results[v]));
}
// 各變體的標註點（與 render3d.mjs xray 同算法），供確認 cabinet_xray_points.json 是否仍適用
const pts = {};
for (const [v, c] of Object.entries(results)) {
  pts[v] = Object.fromEntries(Object.entries(info.points).map(([k, [x, y]]) => [k, [Math.round(x - c.left), Math.round(y - c.top)]]));
}
if (process.env.PTS_OUT) writeFileSync(process.env.PTS_OUT, JSON.stringify({ pr: PR, opacity: OPACITY, before, results, points: pts }, null, 2));
else console.log('points', JSON.stringify(pts));
await browser.close();
