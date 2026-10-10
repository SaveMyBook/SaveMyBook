// 海報用高解析度 3D 算圖（Windows 版）：沿用 介紹動畫/v2 的 deck.html（src/deck.ts）與 pcb.html（src/pcb-page.ts），
// 取景、模型、材質與 v2/tools/deck.mjs、v2/tools/pcb.mjs 完全相同，只提高像素密度。
// 需先在 介紹動畫/v2 執行 npm run dev（5290 埠）。
//
//   node render3d.mjs hero  [pr]     cabinet_hero.png（透明，預設 pr 4.5 ≈ 原圖 2.25 倍）
//   node render3d.mjs xray  [pr]     cabinet_xray.png＋cabinet_xray_points.json
//   node render3d.mjs cover [pr]     cover.png（1920×1080 × pr，預設 4 → 7680×4320）
//   node render3d.mjs pcb   [width]  pcb_3q_esp32.png（預設輸出 4800 寬；受 WebGL 緩衝上限所限，以 7680 寬算圖後縮小）＋points
//   node render3d.mjs info           顯示 WebGL 渲染器與上限
//
// 與原工具的差異：puppeteer-core＋本機 Chrome、ANGLE 用 d3d11（原為 macOS metal）；
// 封面手機畫面以請求攔截改用 v2/assets-src/screens 的 Flutter 原始 PNG（原本載入 public/screens 的有損 WebP）。
import { dirname, resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { mkdirSync, writeFileSync, existsSync, readFileSync } from 'node:fs';
import puppeteer from 'puppeteer-core';
import sharp from 'sharp';

const here = dirname(fileURLToPath(import.meta.url));
const V2 = resolve(here, '../../../介紹動畫/v2');
const OUT = resolve(process.env.OUT || resolve(here, '../../src/assets/3d'));
const PORT = process.env.DECK_PORT || '5290';
const CHROME = process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const ANGLE = process.env.ANGLE || 'd3d11';
const PNG_SCREENS = process.env.SCREENS !== 'webp';
mkdirSync(OUT, { recursive: true });

const [cmd, arg] = process.argv.slice(2);

async function launch() {
  const args = [`--use-angle=${ANGLE}`, '--enable-gpu', '--ignore-gpu-blocklist', '--hide-scrollbars', '--force-color-profile=srgb'];
  if (process.env.SWIFTSHADER) args.push('--enable-unsafe-swiftshader');
  return puppeteer.launch({ executablePath: CHROME, headless: true, args, protocolTimeout: 600000 });
}

const usedScreens = [];
async function newPage(browser, w, h, pr) {
  const page = await browser.newPage();
  await page.setViewport({ width: w, height: h, deviceScaleFactor: pr });
  page.on('pageerror', (e) => console.log('pageerror', e.message));
  page.on('console', (m) => { if ((m.type() === 'error' || m.type() === 'warn') && !m.text().includes('X4122')) console.log('console', m.text()); });
  if (PNG_SCREENS) {
    await page.setRequestInterception(true);
    page.on('request', (req) => {
      const m = /\/screens\/([^/?]+)\.webp(\?|$)/.exec(req.url());
      if (m) {
        const png = join(V2, 'assets-src/screens', `${decodeURIComponent(m[1])}.png`);
        if (existsSync(png)) {
          usedScreens.push(`${m[1]}.webp → assets-src/screens/${m[1]}.png`);
          return req.respond({ status: 200, contentType: 'image/png', body: readFileSync(png) });
        }
        usedScreens.push(`${m[1]}.webp（無對應 PNG，沿用 WebP）`);
      }
      req.continue();
    });
  }
  return page;
}

async function glInfo(page) {
  return page.evaluate(() => {
    const c = document.getElementById('gl');
    const gl = c && (c.getContext('webgl2') || c.getContext('webgl'));
    if (!gl) return null;
    const ext = gl.getExtension('WEBGL_debug_renderer_info');
    return {
      renderer: ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER),
      maxTex: gl.getParameter(gl.MAX_TEXTURE_SIZE), maxRb: gl.getParameter(gl.MAX_RENDERBUFFER_SIZE),
      maxViewport: [...gl.getParameter(gl.MAX_VIEWPORT_DIMS)],
      canvas: [c.width, c.height], drawingBuffer: [gl.drawingBufferWidth, gl.drawingBufferHeight],
      samples: gl.getParameter(gl.SAMPLES),
    };
  });
}

async function openDeck(query, w, h, pr) {
  const browser = await launch();
  const page = await newPage(browser, w, h, pr);
  await page.goto(`http://127.0.0.1:${PORT}/deck.html?${query}&w=${w}&h=${h}&pr=${pr}`, { waitUntil: 'networkidle0', timeout: 300000 });
  await page.waitForFunction(() => window.__ready === true, { timeout: 300000 });
  await page.evaluate(() => document.fonts.ready);
  const gi = await glInfo(page);
  console.log('WebGL', JSON.stringify(gi));
  if (gi && (gi.drawingBuffer[0] !== gi.canvas[0] || gi.drawingBuffer[1] !== gi.canvas[1])) {
    throw new Error(`drawing buffer 被縮小：${gi.drawingBuffer} ≠ ${gi.canvas}，需改用分塊算圖`);
  }
  return { browser, page };
}
const frameReady = (page) => page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))));

/** 與 v2/tools/deck.mjs 的 cropAlpha 相同。 */
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

async function shotCanvas(page) {
  return page.screenshot({ omitBackground: true, type: 'png', captureBeyondViewport: false });
}

async function hero(pr) {
  const { browser, page } = await openDeck('mode=hero', 1300, 1250, pr);
  await frameReady(page);
  const buf = await shotCanvas(page);
  await browser.close();
  const c = await cropAlpha(buf, Math.round(40 * pr / 2));
  const out = join(OUT, 'cabinet_hero.png');
  await save(c.buf, out);
  console.log(out, c.width, c.height, 'full', c.full, JSON.stringify(c.touches));
}

async function xray(pr) {
  const { browser, page } = await openDeck('mode=xray', 1300, 1250, pr);
  await frameReady(page);
  const info = await page.evaluate(() => window.__info());
  const buf = await shotCanvas(page);
  await browser.close();
  const c = await cropAlpha(buf, Math.round(40 * pr / 2));
  const out = join(OUT, 'cabinet_xray.png');
  await save(c.buf, out);
  // 標籤文字與 v2/tools/deck.mjs 相同
  const names = {
    screen: '2.8 吋 TFT 螢幕（右上角，橫向 320×240）',
    board: '主控板（DoorLock ESP32-S3 主控板 Rev A，直立裝在頂列背板內側）',
    powerIn: '電源輸入（主控板 J5 的 12V DC 插座，插頭由頂板開孔插入）',
    cableEntry: '電源線穿過頂板處',
    esp32: 'ESP32-S3 開發板（插在主控板 U1）',
    relays: '四路繼電器 K1–K4（主控板上）',
    regulator: 'L7805 穩壓（主控板上）',
    lockA01: 'A01 電磁鎖', lockA02: 'A02 電磁鎖', lockA03: 'A03 電磁鎖', lockA04: 'A04 電磁鎖',
    switchA01: 'A01 門磁開關', switchA02: 'A02 門磁開關', switchA03: 'A03 門磁開關', switchA04: 'A04 門磁開關',
  };
  const points = {};
  for (const [k, [x, y]] of Object.entries(info.points)) {
    const px = Math.round(x - c.left), py = Math.round(y - c.top);
    points[k] = { label: names[k] ?? k, x: px, y: py, nx: +(px / c.width).toFixed(4), ny: +(py / c.height).toFixed(4) };
  }
  const json = {
    image: 'cabinet_xray.png', width: c.width, height: c.height,
    note: '座標為圖片像素（左上角為原點）；nx、ny 為相對寬高的比例。主控板來源：' + info.boardSource + `。由 deck.html?mode=xray 以 pr ${pr} 算圖（原 複評/素材/render 版為 pr 2），與圖片同時產生。`,
    points,
  };
  writeFileSync(join(OUT, 'cabinet_xray_points.json'), JSON.stringify(json, null, 2) + '\n');
  console.log(out, c.width, c.height, 'full', c.full, JSON.stringify(c.touches));
}

async function cover(pr) {
  const { browser, page } = await openDeck('mode=cover', 1920, 1080, pr);
  await frameReady(page);
  const info = await page.evaluate(() => window.__info());
  const buf = await shotCanvas(page);
  await browser.close();
  const out = join(OUT, 'cover.png');
  await save(buf, out);
  const m = await sharp(out).metadata();
  console.log(out, m.width, m.height, JSON.stringify({ kiosk: info.kioskScreen, cabinet: info.cabinet, phones: info.phones }));
  console.log('手機畫面來源：', [...new Set(usedScreens)].join('；') || '（未攔截）');
}

async function pcb(width) {
  const browser = await launch();
  const page = await newPage(browser, 1000, 800, 1);
  await page.goto(`http://127.0.0.1:${PORT}/pcb.html`, { waitUntil: 'networkidle0', timeout: 300000 });
  await page.waitForFunction(() => !!window.__pcb, { timeout: 120000 });
  await page.evaluate(() => window.__pcb.ready);
  // Chrome 的 WebGL 繪圖緩衝上限約 3317 萬像素（實測 7680×4320 可、9600×5186 被縮成 7836×4233），
  // 原工具以 2 倍寬算圖再縮半；這裡取上限內的 7680 寬算圖再縮到目標寬（1.6 倍超取樣）
  const srcW = Number(process.env.PCB_SRC_W || Math.min(width * 2, 7680));
  const r = await page.evaluate((w) => window.__pcb.frame({ view: '3q', esp32: true, width: w, fitEsp32: [false, true], margin: 0.03, points: true }), srcW);
  const gi = await glInfo(page);
  console.log('WebGL', JSON.stringify(gi));
  await browser.close();
  if (gi.drawingBuffer[0] !== r.width || gi.drawingBuffer[1] !== r.height) throw new Error(`drawing buffer 被縮小：${gi.drawingBuffer} ≠ ${r.width}×${r.height}`);
  const k = width / r.width;
  const w = width, h = Math.round(r.height * k);
  console.log(`算圖 ${r.width}×${r.height} → 縮成 ${w}×${h}（${(1 / k).toFixed(3)} 倍超取樣）`);
  const src = Buffer.from(r.url.slice(r.url.indexOf(',') + 1), 'base64');
  const buf = await sharp(src).resize(w, h, { kernel: 'lanczos3' }).png().toBuffer();
  const out = join(OUT, 'pcb_3q_esp32.png');
  await save(buf, out);
  const r4 = (n) => Math.round(n * 10000) / 10000;
  const points = Object.fromEntries(Object.entries(r.points).map(([key, p]) => [key, {
    label: p.label, x: Math.round(p.x * k), y: Math.round(p.y * k), nx: r4(p.x / r.width), ny: r4(p.y / r.height), box: p.box.map((v) => Math.round(v * k)),
  }]));
  writeFileSync(join(OUT, 'pcb_3q_esp32_points.json'), JSON.stringify({
    image: 'pcb_3q_esp32.png', width: w, height: h,
    note: '座標為圖片像素（左上角為原點）；x、y 為該區立體外框中心的投影，nx、ny 為相對寬高的比例，box 為該區投影後的外框 [x, y, w, h]。來源：src/deck/pcb.ts（DoorLock ESP32-S3 主控板 Rev A）',
    points,
  }, null, 2) + '\n');
  console.log(out, `${w}×${h}`);
}

async function infoOnly() {
  const { browser, page } = await openDeck('mode=hero', 400, 400, 1);
  await browser.close();
}

if (cmd === 'hero') await hero(Number(arg || 4.5));
else if (cmd === 'xray') await xray(Number(arg || 4.5));
else if (cmd === 'cover') await cover(Number(arg || 4));
else if (cmd === 'pcb') await pcb(Number(arg || 4800));
else if (cmd === 'info') await infoOnly();
else console.log('用法見檔頭註解');
