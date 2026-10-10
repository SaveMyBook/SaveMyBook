// 海報用：比照介紹影片「存書」段（約 82 秒）的書櫃透視畫面，輸出高解析度透明 PNG。
// 直接載入 介紹動畫/v2 的 index.html?t=82（同一套場景、姿勢、鏡頭、燈光與材質），只在瀏覽器端：
//   1. 以請求攔截在 main.ts（vite 轉譯後）末尾加一行，把 stage / world / update 掛到 window（不改動 v2 原始檔）；
//   2. 隱藏所有 DOM 疊層（#bg 背景、#ui 標題/HUD/角標、#fx 標註），畫布本來就是透明底（clear alpha 0）；
//   3. 螢幕、標誌貼紙、門牌換成同樣畫法的高解析度畫布（影片原本 640×480 / 840×240 / 128×56，放大後會糊）；
//   4. 1 像素的 WebGL 線改成 LineSegments2 粗線，線寬固定為 1080p 畫面的 0.5 像素（影片以 4K 算圖，線寬 1 像素；放大後線條比例與影片相同）；
//   5. 以 camera.setViewOffset 只算書櫃所在區域、分塊算圖後拼接，再以 lanczos3 縮小（超取樣）。
// 變體 B 另外加上四個門磁微動開關（同影片元件的淺色方塊樣式，位置取自 deck.ts：各格頂部前緣、電磁鎖右側）。
//
// 需先在 介紹動畫/v2 執行 npm run dev（5290 埠）。
//   node render_xray_video.mjs [t=82] [finalScale=8] [renderScale=12]
import { dirname, resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { mkdirSync, writeFileSync } from 'node:fs';
import puppeteer from 'puppeteer-core';
import sharp from 'sharp';

const here = dirname(fileURLToPath(import.meta.url));
const OUT = resolve(process.env.OUT || resolve(here, '../../src/assets/3d'));
const DBG = process.env.DBG || '';
const PORT = process.env.DECK_PORT || '5290';
const BASE = `http://127.0.0.1:${PORT}`;
const CHROME = process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const T = Number(process.argv[2] || 82);
const SF = Number(process.argv[3] || 8);
const SR = Number(process.argv[4] || 12);
const WIRES = process.env.SW_WIRES === '1';
const LWL = Number(process.env.LINE_PX || 0.5); // 線寬（1080p 畫面像素）
mkdirSync(OUT, { recursive: true });

const browser = await puppeteer.launch({
  executablePath: CHROME, headless: true, protocolTimeout: 900000,
  args: ['--use-angle=d3d11', '--enable-gpu', '--ignore-gpu-blocklist', '--hide-scrollbars', '--force-color-profile=srgb'],
});
const page = await browser.newPage();
await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 1 });
page.on('pageerror', (e) => console.log('pageerror', e.message));
page.on('console', (m) => { if ((m.type() === 'error' || m.type() === 'warn') && !m.text().includes('X4122')) console.log('console', m.text()); });
await page.setRequestInterception(true);
page.on('request', async (req) => {
  const u = new URL(req.url());
  if (u.pathname === '/src/main.ts') {
    const js = await (await fetch(BASE + '/src/main.ts')).text();
    const body = js.replace(/\/\/# sourceMappingURL=.*$/m, '') + '\nwindow.__px = { stage, world, update, THREE };\n';
    return req.respond({ status: 200, contentType: 'text/javascript', body });
  }
  req.continue();
});

await page.goto(`${BASE}/index.html?render&pr=1&t=${T}`, { waitUntil: 'networkidle0', timeout: 300000 });
await page.waitForFunction(() => window.__ready === true && !!window.__px, { timeout: 300000 });

// ---------- 瀏覽器端準備 ----------
const setup = await page.evaluate(async ({ T, SR, WIRES, LWL }) => {
  const { stage, world, update, THREE } = window.__px;
  const cab = world.cabinet;
  for (const id of ['bg', 'ui', 'fx', 'bar']) { const e = document.getElementById(id); if (e) e.style.display = 'none'; }

  // 幾何常數（同 cabinet.ts）
  const W = 7.75, H = 9.5, D = 7.75, T_ = 0.225, A = 0.125, TOP = 2.05;
  const IN_W = W - T_ * 2, CELL_H = (H - T_ * 2 - TOP - T_ * 4) / 4;
  const topRowY = H / 2 - T_ - TOP / 2, floor = H / 2 - T_ - TOP;
  const cellTop = (i) => H / 2 - T_ - TOP - T_ - i * (CELL_H + T_);
  const cellY = (i) => cellTop(i) - CELL_H / 2;
  const BEZEL_W = 1.98, BEZEL_H = 1.54;
  const screenX = W / 2 - T_ - 0.3 - BEZEL_W / 2;
  const LOCK = { w: 1.35, h: 1.03, d: 0.68, inset: 0.17 };
  const lockX = -IN_W / 2 + 0.03 + LOCK.inset + LOCK.w / 2, lockZ = D / 2 - LOCK.d / 2;
  const parts = cab.parts;
  // 確認常數與模型一致：四個電磁鎖外框方塊
  const lockBoxes = parts.children.filter((o) => o.isMesh && Math.abs(o.position.x - lockX) < 1e-4 && Math.abs(o.position.z - lockZ) < 1e-4);
  if (lockBoxes.length !== 4) throw new Error('電磁鎖方塊位置與預期不符：' + lockBoxes.length);

  // 門磁微動開關（變體 B）：deck.ts 的開關在 x=-1.45、格子頂部前緣（含小電路板 0.78×0.5、本體、槓桿），這裡以同影片元件的淺色方塊表示
  const partMat = parts.children.find((o) => o.isMesh).material;
  const partEdge = parts.children.find((o) => o.isLineSegments).material;
  const SW = { x: -1.45, w: 0.8, h: 0.31, d: 0.52, z: D / 2 - 0.34 };
  const swY = (i) => cellTop(i) - 0.02 - SW.h / 2;
  const swObjs = [];
  for (let i = 0; i < 4; i++) {
    const m = new THREE.Mesh(new THREE.BoxGeometry(SW.w, SW.h, SW.d), partMat);
    m.position.set(SW.x, swY(i), SW.z);
    const e = new THREE.LineSegments(new THREE.EdgesGeometry(m.geometry), partEdge);
    e.position.copy(m.position);
    parts.add(m, e);
    swObjs.push(m, e);
    if (WIRES) {
      const railX = -W / 2 + T_ + 0.12, wy = cellTop(i) - 0.08;
      const g = new THREE.BufferGeometry();
      g.setAttribute('position', new THREE.Float32BufferAttribute([railX, wy, 1.6, SW.x - SW.w / 2, wy, SW.z], 3));
      const w = new THREE.LineSegments(g, partEdge);
      parts.add(w);
      swObjs.push(w);
    }
  }

  // 高解析度畫布：螢幕（Kiosk）
  const K = 3;
  const kiosk = cab.kiosk;
  const kc = document.createElement('canvas');
  kc.width = kiosk.canvas.width * K; kc.height = kiosk.canvas.height * K;
  const kctx = kc.getContext('2d');
  kctx.setTransform(K, 0, 0, K, 0, 0);
  kiosk.canvas = kc; kiosk.ctx = kctx; kiosk.last = '';
  const ktex = new THREE.CanvasTexture(kc);
  ktex.colorSpace = THREE.SRGBColorSpace; ktex.anisotropy = 8;
  cab.screenMesh.material.map = ktex; cab.screenMesh.material.needsUpdate = true;
  kiosk.texture = ktex;

  const loadImage = (src) => new Promise((res, rej) => { const i = new Image(); i.onload = () => res(i); i.onerror = rej; i.src = src; });
  const mkTex = (c) => { const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8; return t; };
  await document.fonts.load('700 78px "Noto Sans TC"', '救「舊」我的書');
  await document.fonts.load('500 46px "Noto Sans TC"', 'SaveMyBook');
  await document.fonts.load('500 32px "IBM Plex Mono"', 'A01A02A03A04');
  // 標誌貼紙（同 cabinet.ts brandSticker，放大 4 倍；圖示改用同一張 512 版）
  const SK = 4;
  const mark = await loadImage('/brand/book-slate.webp');
  const drawSticker = () => {
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
    return mkTex(c);
  };
  // 門牌（同 textures.ts doorPlate，放大 4 倍）
  const PK = 4;
  const plate = (text) => {
    const c = document.createElement('canvas');
    c.width = 128 * PK; c.height = 56 * PK;
    const g = c.getContext('2d');
    g.scale(PK, PK);
    g.fillStyle = '#627D8D'; g.beginPath(); g.roundRect(0, 0, 128, 56, 12); g.fill();
    g.fillStyle = '#FFFFFF'; g.font = '500 32px "IBM Plex Mono", monospace'; g.textAlign = 'center'; g.textBaseline = 'middle';
    g.fillText(text, 64, 30);
    return mkTex(c);
  };
  let stickers = 0, plates = 0;
  cab.group.traverse((o) => {
    const img = o.material && o.material.map && o.material.map.image;
    if (img && img.width === 840 && img.height === 240) { o.material.map = drawSticker(); o.material.needsUpdate = true; stickers++; }
  });
  cab.doors.forEach((d, i) => d.pivot.traverse((o) => {
    const img = o.material && o.material.map && o.material.map.image;
    if (img && img.width === 128 && img.height === 56) { o.material.map = plate(`A0${i + 1}`); o.material.needsUpdate = true; plates++; }
  }));

  // 先算一次讓螢幕字型載入，再重畫
  update(T);
  await document.fonts.ready;
  await new Promise((r) => setTimeout(r, 400));
  await document.fonts.ready;
  kiosk.last = '';
  update(T);

  // 粗線：取代 cabinet 內所有 LineSegments（櫃體外框、元件外框、配線）
  const { LineSegments2 } = await import('/node_modules/three/examples/jsm/lines/LineSegments2.js');
  const { LineSegmentsGeometry } = await import('/node_modules/three/examples/jsm/lines/LineSegmentsGeometry.js');
  const { LineMaterial } = await import('/node_modules/three/examples/jsm/lines/LineMaterial.js');
  // 影片以 4K（pr 2）算圖再輸出 1080p：線寬為 4K 的 1 像素＝1080p 的 0.5 像素
  const LW = SR * LWL;
  const lineMats = new Map();
  const fatOf = new Map();
  const lines = [];
  cab.group.traverse((o) => { if (o.isLineSegments && !o.isLineSegments2) lines.push(o); });
  for (const o of lines) {
    const src = o.material;
    if (!lineMats.has(src)) {
      lineMats.set(src, new LineMaterial({ color: src.color.getHex(), linewidth: LW, transparent: src.transparent, opacity: src.opacity, depthWrite: src.depthWrite, depthTest: src.depthTest, worldUnits: false }));
    }
    let geo = o.geometry;
    if (geo.index) geo = geo.toNonIndexed();
    const lg = new LineSegmentsGeometry().setPositions(Array.from(geo.attributes.position.array));
    const fat = new LineSegments2(lg, lineMats.get(src));
    fat.position.copy(o.position); fat.quaternion.copy(o.quaternion); fat.scale.copy(o.scale);
    fat.renderOrder = o.renderOrder;
    o.parent.add(fat);
    o.visible = false;
    fatOf.set(o, fat);
  }
  window.__xr = { swObjs: swObjs.map((o) => [o, fatOf.get(o)]).flat().filter(Boolean), lineMats: [...lineMats.values()] };

  const phonesVisible = world.phones.filter((p) => p.group.visible).length;
  const g = cab.group;
  g.updateMatrixWorld(true);
  const toS = (x, y, z) => { const v = stage.toScreen(g.localToWorld(new THREE.Vector3(x, y, z))); return [v.x, v.y]; };
  // 書櫃投影外框（邏輯 1920×1080 座標）
  const cs = [];
  for (const sx of [-1, 1]) for (const sy of [-1, 1]) for (const sz of [-1, 1]) cs.push(toS(sx * (W / 2 + 0.05), sy * (H / 2 + 0.05), sz * (D / 2 + A + 0.05)));
  const bbox = [Math.min(...cs.map((p) => p[0])), Math.min(...cs.map((p) => p[1])), Math.max(...cs.map((p) => p[0])), Math.max(...cs.map((p) => p[1]))];

  // 元件：中心、外框、影片引線端點（rig.ts 的 anchors：方塊正面中心；螢幕為邊框右緣中點）
  const anchorOf = (k) => { const v = cab.anchors[k].position; return toS(v.x, v.y, v.z); };
  const boxOf = (cx, cy, cz, w, h, d) => {
    const pts = [];
    for (const sx of [-1, 1]) for (const sy of [-1, 1]) for (const sz of [-1, 1]) pts.push(toS(cx + sx * w / 2, cy + sy * h / 2, cz + sz * d / 2));
    const x0 = Math.min(...pts.map((p) => p[0])), y0 = Math.min(...pts.map((p) => p[1])), x1 = Math.max(...pts.map((p) => p[0])), y1 = Math.max(...pts.map((p) => p[1]));
    return { center: toS(cx, cy, cz), box: [x0, y0, x1 - x0, y1 - y0] };
  };
  const P = {};
  P.power = { label: '12V 電源', anchor: anchorOf('power'), ...boxOf(-2.15, floor + 0.43, 0.6, 2.4, 0.85, 1.8) };
  P.relays = { label: '四路繼電器', anchor: anchorOf('relay'), ...boxOf(-0.25, floor + 0.15, 1.6, 1.4, 0.3, 1.9) };
  P.board = { label: 'ESP32-S3 控制板', anchor: anchorOf('board'), ...boxOf(1.2, topRowY + 0.15, 1.8, 1.72, 0.25, 0.66) };
  P.screen = { label: '2.8 吋 TFT 螢幕', anchor: anchorOf('screen'), ...boxOf(screenX, topRowY, D / 2 - 0.05, BEZEL_W, BEZEL_H, 0.08) };
  P.locks = { label: '電磁鎖 ×4（影片引線端點，即 A02 電磁鎖正面）', anchor: anchorOf('locks') };
  for (let i = 0; i < 4; i++) {
    const d = LOCK.d + 0.06;
    P[`lockA0${i + 1}`] = { label: `A0${i + 1} 電磁鎖`, anchor: toS(lockX, cellY(i), lockZ + d / 2), ...boxOf(lockX, cellY(i), lockZ, LOCK.w + 0.06, LOCK.h + 0.06, d) };
  }
  for (let i = 0; i < 4; i++) {
    P[`switchA0${i + 1}`] = { label: `A0${i + 1} 門磁微動開關`, anchor: toS(SW.x, swY(i), SW.z + SW.d / 2), ...boxOf(SW.x, swY(i), SW.z, SW.w, SW.h, SW.d), variantBOnly: true };
  }
  const gl = stage.renderer.getContext();
  return {
    bbox, P, phonesVisible, boxVisible: world.box.visible, stickers, plates, lines: lines.length,
    cabPose: { pos: g.position.toArray(), rot: [g.rotation.x, g.rotation.y, g.rotation.z], scale: g.scale.x },
    cam: stage.camera.position.toArray(),
    maxRb: gl.getParameter(gl.MAX_RENDERBUFFER_SIZE), maxVp: [...gl.getParameter(gl.MAX_VIEWPORT_DIMS)],
    renderer: (() => { const e = gl.getExtension('WEBGL_debug_renderer_info'); return e ? gl.getParameter(e.UNMASKED_RENDERER_WEBGL) : ''; })(),
  };
}, { T, SR, WIRES, LWL });
console.log('setup', JSON.stringify({ ...setup, P: undefined }));
if (setup.phonesVisible || setup.boxVisible) throw new Error('畫面上還有手機或包裹');

// ---------- 分塊算圖 ----------
const M = 14; // 外框外留白（邏輯像素）
const rx0 = Math.floor((setup.bbox[0] - M) * SR), ry0 = Math.floor((setup.bbox[1] - M) * SR);
const rx1 = Math.ceil((setup.bbox[2] + M) * SR), ry1 = Math.ceil((setup.bbox[3] + M) * SR);
const RW = rx1 - rx0, RH = ry1 - ry0;
const TILE = 4096;
console.log(`算圖區域 ${RW}×${RH}（×${SR}），輸出約 ${Math.round(RW * SF / SR)}×${Math.round(RH * SF / SR)}`);

async function renderVariant(showSwitches) {
  await page.evaluate((on) => { for (const o of window.__xr.swObjs) o.visible = on; }, showSwitches);
  const tiles = [];
  for (let ty = 0; ty < RH; ty += TILE) for (let tx = 0; tx < RW; tx += TILE) {
    const tw = Math.min(TILE, RW - tx), th = Math.min(TILE, RH - ty);
    const url = await page.evaluate(({ ox, oy, tw, th, SR }) => {
      const { stage } = window.__px;
      const r = stage.renderer;
      r.setPixelRatio(1);
      r.setSize(tw, th, false);
      stage.camera.setViewOffset(1920 * SR, 1080 * SR, ox, oy, tw, th);
      for (const m of window.__xr.lineMats) m.resolution.set(tw, th);
      stage.render();
      const gl = r.getContext();
      if (gl.drawingBufferWidth !== tw || gl.drawingBufferHeight !== th) throw new Error(`drawing buffer ${gl.drawingBufferWidth}×${gl.drawingBufferHeight} ≠ ${tw}×${th}`);
      const u = r.domElement.toDataURL('image/png');
      stage.camera.clearViewOffset();
      return u;
    }, { ox: rx0 + tx, oy: ry0 + ty, tw, th, SR });
    tiles.push({ input: Buffer.from(url.slice(url.indexOf(',') + 1), 'base64'), left: tx, top: ty });
  }
  const big = await sharp({ create: { width: RW, height: RH, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } } }).composite(tiles).png().toBuffer();
  const FW = Math.round(RW * SF / SR), FH = Math.round(RH * SF / SR);
  const small = await sharp(big, { limitInputPixels: false }).resize(FW, FH, { kernel: 'lanczos3' }).png().toBuffer();
  return { buf: small, FW, FH, big };
}

async function cropAlpha(buf, margin) {
  const { data, info } = await sharp(buf).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  let x0 = info.width, y0 = info.height, x1 = -1, y1 = -1;
  for (let y = 0; y < info.height; y++) for (let x = 0; x < info.width; x++) {
    if (data[(y * info.width + x) * 4 + 3] > 2) { if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
  }
  const left = Math.max(0, x0 - margin), top = Math.max(0, y0 - margin);
  const width = Math.min(info.width, x1 + margin + 1) - left, height = Math.min(info.height, y1 + margin + 1) - top;
  const touches = { left: x0 === 0, top: y0 === 0, right: x1 === info.width - 1, bottom: y1 === info.height - 1 };
  return { buf: await sharp(buf).extract({ left, top, width, height }).png().toBuffer(), left, top, width, height, touches };
}

async function output(name, showSwitches) {
  const r = await renderVariant(showSwitches);
  const c = await cropAlpha(r.buf, 40);
  const file = join(OUT, `${name}.png`);
  await sharp(c.buf).withMetadata({ density: 300 }).png({ compressionLevel: 9 }).toFile(file);
  const kx = r.FW / RW, ky = r.FH / RH;
  const map = ([x, y]) => [Math.round((x * SR - rx0) * kx - c.left), Math.round((y * SR - ry0) * ky - c.top)];
  const points = {};
  for (const [k, p] of Object.entries(setup.P)) {
    if (p.variantBOnly && !showSwitches) continue;
    const [x, y] = map(p.anchor);
    const o = { label: p.label, x, y, nx: +(x / c.width).toFixed(4), ny: +(y / c.height).toFixed(4) };
    if (p.center) o.center = map(p.center);
    if (p.box) { const [bx, by] = map([p.box[0], p.box[1]]); const [bx2, by2] = map([p.box[0] + p.box[2], p.box[1] + p.box[3]]); o.box = [bx, by, bx2 - bx, by2 - by]; }
    points[k] = o;
  }
  const json = {
    image: `${name}.png`, width: c.width, height: c.height, dpi: 300,
    note: `座標為圖片像素（左上角為原點）；x、y 為介紹影片 rig.ts 引線端點的規則（元件方塊正面中心，螢幕為邊框右緣中點），nx、ny 為相對寬高比例；center 為元件立體中心投影，box 為元件立體外框投影 [x, y, w, h]。` +
      `來源：介紹動畫/v2 index.html?t=${T}（存書段透視畫面，與影片 ${T} 秒同一姿勢、鏡頭與燈光），以 render_xray_video.mjs 算圖（${SR} 倍算圖、lanczos3 縮成 ${SF} 倍；線寬為 1080p 的 ${LWL} 像素，同影片 4K 算圖的 1 像素）。` +
      (showSwitches ? '門磁微動開關為影片模型沒有的元件，依 deck.ts 位置（各格頂部前緣、電磁鎖右側）以同樣的淺色方塊補上。' : '影片模型沒有門磁微動開關。'),
    points,
  };
  writeFileSync(join(OUT, `${name}_points.json`), JSON.stringify(json, null, 2) + '\n');
  console.log(file, `${c.width}×${c.height}`, 'touches', JSON.stringify(c.touches));
  if (DBG) writeFileSync(join(DBG, `${name}_render_full.png`), r.buf);
  return { file, c, points };
}

const onlyB = process.env.ONLY === 'B', onlyA = process.env.ONLY === 'A';
if (!onlyB) await output('cabinet_xray_video', false);
if (!onlyA) await output('cabinet_xray_video_sw', true);
await browser.close();
