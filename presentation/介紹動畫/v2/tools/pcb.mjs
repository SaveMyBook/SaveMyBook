// DoorLock ESP32-S3 主控板算圖：3/4 俯視（有無開發板各一張）、正上方俯視與功能區座標、旋轉一圈 GIF。
// 用法：node tools/pcb.mjs [all|3q|top|spin|glb|mp4] [輸出資料夾]；需先 npm run dev（預設 5290 埠，可用 PORT 指定）。
// mp4：插上開發板旋轉一圈的 60 fps 影片（簡報用），預設輸出到 複評/素材/video/。
// glb：插上開發板的主控板，單位公尺、原點在板子中心、Y 朝上，供 PowerPoint 3D 模型使用。
// 皆以 2 倍解析度算圖後縮小；GIF 調色盤用 ffmpeg（取自 ../src/node_modules/ffmpeg-static），編碼用 tools/gif.mjs。
// GIF 參數可用環境變數調整：PCB_SPIN_FPS、PCB_SPIN_H、PCB_SPIN_NAME、PCB_SPIN_TH（相鄰格容差）、PCB_SPIN_ESP32=1。
import { createRequire } from 'node:module';
import { dirname, resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { execFileSync, spawn } from 'node:child_process';
import { tmpdir } from 'node:os';
import sharp from 'sharp';
import { encodeGif } from './gif.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const puppeteer = require(resolve(here, '../../src/node_modules/puppeteer'));
const ffmpeg = resolve(here, '../../src/node_modules/ffmpeg-static/ffmpeg');

const what = process.argv[2] || 'all';
const outDir = resolve(process.argv[3] || resolve(here, '../../../複評/素材/render'));
const port = process.env.PORT || '5290';
const framesDir = process.env.PCB_FRAMES || join(tmpdir(), 'pcb_spin_frames');
mkdirSync(outDir, { recursive: true });

/**
 * GIF：一圈 6 秒，底色與投影片內容區相同，第一格為 3/4 視角。
 * 旋轉時每格約三成像素都在變，700 高、25 fps 即使用 tools/gif.mjs 也超過 10 MB；
 * 預設 20 fps、高 540、63 色（背景陰影加抖色）才能壓在 6 MB 以內。
 */
const env = process.env;
const SPIN = {
  seconds: 6,
  fps: Number(env.PCB_SPIN_FPS || 20),
  height: Number(env.PCB_SPIN_H || 540),
  colors: Number(env.PCB_SPIN_COLORS || 63),
  start: 0.35,
  threshold: Number(env.PCB_SPIN_TH ?? 8),
  name: env.PCB_SPIN_NAME || 'pcb_spin.gif',
  bg: '#F8FAFB',
};

const browser = await puppeteer.launch({ headless: true, args: ['--use-angle=metal', '--enable-gpu', '--ignore-gpu-blocklist'] });
const page = await browser.newPage();
await page.setViewport({ width: 1000, height: 800, deviceScaleFactor: 1 });
page.on('pageerror', (e) => console.log('pageerror', e.message));
page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') console.log('console', m.text()); });
await page.goto(`http://127.0.0.1:${port}/pcb.html`, { waitUntil: 'networkidle0' });
await page.waitForFunction(() => !!window.__pcb, { timeout: 60000 });
await page.evaluate(() => window.__pcb.ready);

const png = (url) => Buffer.from(url.slice(url.indexOf(',') + 1), 'base64');
const half = (buf, w, h) => sharp(buf).resize(w, h, { kernel: 'lanczos3' }).png({ compressionLevel: 9 });

if (what === 'all' || what === '3q') {
  for (const esp32 of [false, true]) {
    const r = await page.evaluate((e) => window.__pcb.frame({ view: '3q', esp32: e, width: 4800, fitEsp32: [false, true], margin: 0.03, points: e }), esp32);
    const name = esp32 ? 'pcb_3q_esp32.png' : 'pcb_3q.png';
    const file = join(outDir, name);
    const w = r.width / 2, h = r.height / 2;
    await half(png(r.url), w, h).toFile(file);
    console.log(file, `${w}×${h}`);
    if (esp32) {
      const r4 = (n) => Math.round(n * 10000) / 10000;
      const points = Object.fromEntries(Object.entries(r.points).map(([key, p]) => [key, {
        label: p.label, x: Math.round(p.x / 2), y: Math.round(p.y / 2), nx: r4(p.x / 2 / w), ny: r4(p.y / 2 / h),
        box: p.box.map((v) => Math.round(v / 2)),
      }]));
      const json = {
        image: name, width: w, height: h,
        note: '座標為圖片像素（左上角為原點）；x、y 為該區立體外框中心的投影，nx、ny 為相對寬高的比例，box 為該區投影後的外框 [x, y, w, h]。pcb_3q.png 取景相同，座標通用。來源：src/deck/pcb.ts（DoorLock ESP32-S3 主控板 Rev A）',
        points,
      };
      writeFileSync(join(outDir, 'pcb_3q_esp32_points.json'), JSON.stringify(json, null, 2) + '\n');
    }
  }
}

if (what === 'all' || what === 'top') {
  // 每公釐 35 像素算圖、縮半後為 17.5；板子後緣上方多留 J5 插座凸出的空間
  const k = 35;
  const margin = [6.0, 62.5 / 17.5, 3.6, 62.5 / 17.5];
  const r = await page.evaluate((o) => window.__pcb.top(o), { pxPerMm: k, marginMm: margin, esp32: false });
  const file = join(outDir, 'pcb_top.png');
  await half(png(r.url), r.width / 2, r.height / 2).toFile(file);
  const scaleBox = (b) => ({ ...b, x: b.x / 2, y: b.y / 2, w: b.w / 2, h: b.h / 2 });
  const regions = Object.fromEntries(Object.entries(r.regions).map(([key, b]) => [key, scaleBox(b)]));
  const components = Object.fromEntries(Object.entries(r.components).map(([ref, [x, y, w, h]]) => [ref, [x / 2, y / 2, w / 2, h / 2]]));
  const json = {
    image: 'pcb_top.png',
    width: r.width / 2,
    height: r.height / 2,
    note: '正上方正交俯視；座標單位為像素，原點在圖片左上角，x 向右、y 向下；外框為 [x, y, w, h]。前緣排針（J7–J10、J6）在下方，端子台在右側。',
    pxPerMm: k / 2,
    board: { x: margin[3] * k / 2, y: margin[0] * k / 2, w: 130 * k / 2, h: 80 * k / 2, mm: [130, 80] },
    regions,
    components,
  };
  writeFileSync(join(outDir, 'pcb_top_points.json'), JSON.stringify(json, null, 2) + '\n');
  console.log(file, `${r.width / 2}×${r.height / 2}`);
}

if (what === 'all' || what === 'spin') {
  const n = SPIN.seconds * SPIN.fps;
  const fitAngles = Array.from({ length: 48 }, (_, i) => (i / 48) * Math.PI * 2);
  rmSync(framesDir, { recursive: true, force: true });
  mkdirSync(framesDir, { recursive: true });
  const frames = [];
  let size = null;
  for (let i = 0; i < n; i++) {
    const angle = SPIN.start + (i / n) * Math.PI * 2;
    const r = await page.evaluate((o) => window.__pcb.frame(o), { view: 'spin', esp32: env.PCB_SPIN_ESP32 === '1', angle, height: SPIN.height * 2, fitAngles, fitEsp32: [false, true], margin: 0.035, shadow: 'disc' });
    size = [r.width / 2, r.height / 2];
    const img = sharp(png(r.url)).resize(size[0], size[1], { kernel: 'lanczos3' }).flatten({ background: SPIN.bg });
    const file = join(framesDir, `f${String(i).padStart(3, '0')}.png`);
    await img.clone().png().toFile(file);
    frames.push(await img.clone().raw().toBuffer());
  }
  const palFile = join(framesDir, 'palette.png');
  execFileSync(ffmpeg, ['-y', '-loglevel', 'error', '-framerate', String(SPIN.fps), '-i', join(framesDir, 'f%03d.png'),
    '-vf', `palettegen=max_colors=${SPIN.colors}:reserve_transparent=0:stats_mode=full`, palFile]);
  const pr = await sharp(palFile).removeAlpha().raw().toBuffer();
  const palette = Array.from({ length: SPIN.colors }, (_, i) => [pr[i * 3], pr[i * 3 + 1], pr[i * 3 + 2]]);
  // 底色一定要在調色盤裡，否則整片背景會換成相近色
  const bg = [1, 3, 5].map((o) => parseInt(SPIN.bg.slice(o, o + 2), 16));
  let bi = 0, bd = Infinity;
  palette.forEach((c, i) => { const d = c.reduce((s, v, k) => s + (v - bg[k]) ** 2, 0); if (d < bd) { bd = d; bi = i; } });
  palette[bi] = bg;
  await sharp(join(framesDir, 'f000.png')).toFile(join(outDir, SPIN.name.replace(/\.gif$/, '_poster.png')));
  const gif = join(outDir, SPIN.name);
  const bytes = encodeGif(gif, { width: size[0], height: size[1], frames, palette, delayCs: Math.round(100 / SPIN.fps), threshold: SPIN.threshold, lightDither: 10 });
  console.log(gif, `${size[0]}×${size[1]}`, `${n} 格 ${SPIN.fps} fps`, `${(bytes / 1048576).toFixed(2)} MB`);
}

if (what === 'glb') {
  const r = await page.evaluate(() => window.__pcb.exportGlb());
  const buf = Buffer.from(r.b64, 'base64');
  const file = join(outDir, 'pcb.glb');
  writeFileSync(file, buf);
  console.log(file, `${(buf.length / 1048576).toFixed(2)} MB`, `原始網格 ${r.sourceMeshes} 個，依材質合併為 ${r.meshes} 個`);
  // 讀回：解析 glb 的 JSON 區塊，並用 GLTFLoader 載入後算一張 3/4 視角比對
  const jsonLen = buf.readUInt32LE(12);
  const gltf = JSON.parse(buf.subarray(20, 20 + jsonLen).toString('utf8'));
  const prims = gltf.meshes.reduce((n, m) => n + m.primitives.length, 0);
  console.log('glb 內容', JSON.stringify({ meshes: gltf.meshes.length, primitives: prims, materials: gltf.materials.length, textures: (gltf.textures || []).length, images: (gltf.images || []).map((im) => `${im.mimeType} ${(gltf.bufferViews[im.bufferView].byteLength / 1024).toFixed(0)}KB`), lights: gltf.extensions?.KHR_lights_punctual ? 'yes' : 'no', extensionsUsed: gltf.extensionsUsed || [] }));
  const st = await page.evaluate((b) => window.__pcb.loadGlb(b), r.b64);
  console.log('GLTFLoader 讀回', JSON.stringify(st));
  const chk = await page.evaluate(() => window.__pcb.frame({ view: '3q', esp32: true, width: 2400, fitEsp32: [false, true], margin: 0.03, glb: true }));
  const chkFile = join(framesDir, 'glb_check.png');
  mkdirSync(framesDir, { recursive: true });
  await sharp(png(chk.url)).flatten({ background: '#F8FAFB' }).png().toFile(chkFile);
  console.log('比對圖', chkFile);
}

if (what === 'mp4') {
  // H.264 yuv420p（BT.709、TV range），背景 #F8FAFB 轉換後仍在 2 階以內；ffmpeg 取自 audio/.venv 的 imageio_ffmpeg（含 libx264）
  const ff = execFileSync(resolve(here, '../audio/.venv/bin/python'), ['-c', 'import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())']).toString().trim();
  const fps = 60, seconds = 6, n = fps * seconds;
  const width = Number(env.PCB_MP4_W || 1600);
  const vdir = process.argv[3] ? outDir : resolve(here, '../../../複評/素材/video');
  mkdirSync(vdir, { recursive: true });
  const fitAngles = Array.from({ length: 48 }, (_, i) => (i / 48) * Math.PI * 2);
  const base = { view: 'spin', esp32: true, fitAngles, fitEsp32: [true], margin: 0.035, shadow: 'disc' };
  const probe = await page.evaluate((o) => window.__pcb.frame(o), { ...base, angle: SPIN.start, width: width * 2 });
  const height = Math.round(probe.height / 4) * 2;
  const mp4 = join(vdir, 'pcb_spin.mp4');
  const enc = spawn(ff, ['-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', `${width}x${height}`, '-r', String(fps), '-i', '-',
    '-vf', 'scale=out_color_matrix=bt709:out_range=tv,format=yuv420p,setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709:range=tv', '-c:v', 'libx264', '-profile:v', 'high', '-preset', 'slow', '-crf', '18',
    '-colorspace', 'bt709', '-color_primaries', 'bt709', '-color_trc', 'bt709', '-color_range', 'tv', '-r', String(fps), '-an', '-movflags', '+faststart', mp4], { stdio: ['pipe', 'inherit', 'inherit'] });
  const done = new Promise((ok, fail) => enc.on('close', (c) => (c === 0 ? ok() : fail(new Error(`ffmpeg ${c}`)))));
  for (let i = 0; i < n; i++) {
    const r = await page.evaluate((o) => window.__pcb.frame(o), { ...base, angle: SPIN.start + (i / n) * Math.PI * 2, width: width * 2, height: height * 2 });
    const img = sharp(png(r.url)).resize(width, height, { kernel: 'lanczos3' }).flatten({ background: SPIN.bg });
    if (i === 0) await img.clone().png().toFile(join(vdir, 'pcb_spin_poster.png'));
    const raw = await img.clone().raw().toBuffer();
    if (!enc.stdin.write(raw)) await new Promise((ok) => enc.stdin.once('drain', ok));
    if (i % 60 === 0) console.log(`格 ${i}/${n}`);
  }
  enc.stdin.end();
  await done;
  console.log(mp4, `${width}×${height}`, `${n} 格 ${fps} fps`);
}

await browser.close();
