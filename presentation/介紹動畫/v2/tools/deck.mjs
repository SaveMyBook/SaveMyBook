// 複評簡報素材：以 deck.html（src/deck.ts）算出書櫃與手機的圖，輸出到 presentation/複評/素材/render/。
// 需先開 dev server（npm run dev，5290 埠；其他埠用 DECK_PORT=5291）。中間格放 DECK_TMP（預設 out/deck）。
//
//   node tools/deck.mjs photo <封面照片.jpg>   把手拿的實拍封面校正成正面貼圖 public/deck/cover_html_css.jpg
//   node tools/deck.mjs cover                  cover.png（3840×2160 透明，簡報封面右半邊用）
//   node tools/deck.mjs hero                   cabinet_hero.png（透明，約 2400 高）
//   node tools/deck.mjs xray                   cabinet_xray.png＋cabinet_xray_points.json
//   node tools/deck.mjs gif deposit|pickup [--tl match:5.2,open:7.2] [--preset draft]   cabinet_deposit.gif／cabinet_pickup.gif
//   node tools/deck.mjs video deposit|pickup [--tl ...]   60 fps MP4（素材/video/cabinet3d_deposit.mp4、cabinet3d_pickup.mp4＋poster）
//   node tools/deck.mjs spin                   cabinet_spin.mp4（360° 旋轉展示，8 秒一圈，1600×1600）
//   node tools/deck.mjs glb                    cabinet.glb（PowerPoint 3D 模型用，單位公尺、原點在底面中心）
//   node tools/deck.mjs check deposit|pickup [--fps 60]   書與櫃門、書櫃結構穿模檢查
//   以上加 --cam front：接近正面的鏡頭（hero → cabinet_front.png、xray → cabinet_xray_front.*、spin → cabinet_spin_front.mp4，
//   video 仍輸出 cabinet3d_*.mp4）；glb 加 --solid 輸出櫃門不透明的 cabinet_solid.glb
//   node tools/deck.mjs review <檔案.gif|mp4|png>  每 0.2 秒一格、半尺寸總覽（GIF／MP4）或半尺寸預覽（PNG）
//   node tools/deck.mjs shot "<網址參數>" <輸出.png>   除錯截圖
// GIF 時間軸參數在 src/deck.ts 的 TL。
import { createRequire } from 'node:module';
import { dirname, resolve, join, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { mkdirSync, writeFileSync, rmSync, readdirSync, statSync, readFileSync } from 'node:fs';
import { spawnSync, spawn } from 'node:child_process';
import sharp from 'sharp';

const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const puppeteer = require(resolve(here, '../../src/node_modules/puppeteer'));
const ffmpeg = require(resolve(here, '../../src/node_modules/ffmpeg-static'));
/** MP4 用 imageio-ffmpeg 7.1（含 libx264），找不到時退回 ffmpeg-static。 */
const ffmpeg7 = (() => {
  const r = spawnSync(resolve(here, '../audio/.venv/bin/python'), ['-c', 'import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())'], { encoding: 'utf8' });
  return r.status === 0 ? r.stdout.trim() : ffmpeg;
})();

const PORT = process.env.DECK_PORT || '5290';
const OUT = resolve(here, '../../../複評/素材/render');
const VIDEO = resolve(here, '../../../複評/素材/video');
const TMP = resolve(process.env.DECK_TMP || join(here, '../out/deck'));
const FPS = 25;
/** GIF 背景，與 src/deck.ts 的 GIF_BG 相同（投影片內容區底色）。 */
const BG = [0xf8, 0xfa, 0xfb];
/** GIF 輸出尺寸（CSS 像素＝最終像素，以 2 倍算圖後縮小）。 */
const GIF_SIZE = { w: Number(process.env.GIF_W || 1000), h: Number(process.env.GIF_H || 900) };

const [cmd, ...rest] = process.argv.slice(2);
const flag = (name) => { const i = rest.indexOf(name); return i >= 0 ? rest[i + 1] : undefined; };
mkdirSync(OUT, { recursive: true });
mkdirSync(TMP, { recursive: true });

async function open(query, w, h, pr) {
  const browser = await puppeteer.launch({ headless: true, args: ['--use-angle=metal', '--enable-gpu', '--ignore-gpu-blocklist', '--hide-scrollbars'] });
  const page = await browser.newPage();
  await page.setViewport({ width: w, height: h, deviceScaleFactor: pr });
  page.on('pageerror', (e) => console.log('pageerror', e.message));
  page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warn') console.log('console', m.text()); });
  const cam = flag('--cam');
  await page.goto(`http://127.0.0.1:${PORT}/deck.html?${query}&w=${w}&h=${h}&pr=${pr}${cam && !query.includes('cam=') ? `&cam=${cam}` : ''}`, { waitUntil: 'networkidle0' });
  await page.waitForFunction(() => window.__ready === true, { timeout: 120000 });
  await page.evaluate(() => document.fonts.ready);
  return { browser, page };
}

const frameReady = (page) => page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))));

/** 透明 PNG 裁到不透明範圍外加 margin（像素）。 */
async function cropAlpha(buf, margin) {
  const img = sharp(buf);
  const { data, info } = await img.clone().ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  let x0 = info.width, y0 = info.height, x1 = -1, y1 = -1;
  for (let y = 0; y < info.height; y++) for (let x = 0; x < info.width; x++) {
    if (data[(y * info.width + x) * 4 + 3] > 2) { if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
  }
  const left = Math.max(0, x0 - margin), top = Math.max(0, y0 - margin);
  const width = Math.min(info.width, x1 + margin + 1) - left, height = Math.min(info.height, y1 + margin + 1) - top;
  const touches = { left: x0 === 0, top: y0 === 0, right: x1 === info.width - 1, bottom: y1 === info.height - 1 };
  return { buf: await sharp(buf).extract({ left, top, width, height }).png().toBuffer(), left, top, width, height, touches };
}

function run(args, bin = ffmpeg) {
  const r = spawnSync(bin, ['-hide_banner', '-loglevel', 'error', ...args], { encoding: 'utf8' });
  if (r.status !== 0) throw new Error(r.stderr);
  return r.stderr;
}

/** 讀 GIF 每格的延遲（百分之一秒），依區塊結構走訪，檢查總長與格數。 */
function gifDelays(file) {
  const b = readFileSync(file);
  const out = [];
  let i = 13;
  if (b[10] & 0x80) i += 3 * (1 << ((b[10] & 7) + 1));
  const skipSub = () => { while (b[i] !== 0) i += b[i] + 1; i++; };
  while (i < b.length) {
    const t = b[i];
    if (t === 0x21) {
      if (b[i + 1] === 0xf9) out.push(b[i + 4] | (b[i + 5] << 8));
      i += 2;
      skipSub();
    } else if (t === 0x2c) {
      const flags = b[i + 9];
      i += 10;
      if (flags & 0x80) i += 3 * (1 << ((flags & 7) + 1));
      i++;
      skipSub();
    } else break;
  }
  return out;
}

async function photo(src) {
  // 手拿斜拍的封面四角（原圖像素，左上角略超出畫面）；校正成 780×1000 正面貼圖
  const quad = [[-23, 215], [482, 0], [668, 805], [125, 861]];
  const OW = 780, OH = 1000, inset = 0.012;
  const { data, info } = await sharp(src).removeAlpha().raw().toBuffer({ resolveWithObject: true });
  // 單位正方形 → 四邊形的投影轉換
  const [[x0, y0], [x1, y1], [x2, y2], [x3, y3]] = quad;
  const dx1 = x1 - x2, dx2 = x3 - x2, dy1 = y1 - y2, dy2 = y3 - y2;
  const sx = x0 - x1 + x2 - x3, sy = y0 - y1 + y2 - y3;
  const den = dx1 * dy2 - dx2 * dy1;
  const g = (sx * dy2 - dx2 * sy) / den, h = (dx1 * sy - sx * dy1) / den;
  const a = x1 - x0 + g * x1, b = x3 - x0 + h * x3, c = x0;
  const d = y1 - y0 + g * y1, e = y3 - y0 + h * y3, f = y0;
  const map = (u, v) => { const w = g * u + h * v + 1; return [(a * u + b * v + c) / w, (d * u + e * v + f) / w]; };
  const px = (x, y) => { const i = (y * info.width + x) * 3; return [data[i], data[i + 1], data[i + 2]]; };
  const sample = (x, y) => {
    if (x < 0 || y < 0 || x > info.width - 1.001 || y > info.height - 1.001) return null;
    const xi = Math.floor(x), yi = Math.floor(y), fx = x - xi, fy = y - yi;
    const p00 = px(xi, yi), p10 = px(xi + 1, yi), p01 = px(xi, yi + 1), p11 = px(xi + 1, yi + 1);
    return [0, 1, 2].map((k) => p00[k] * (1 - fx) * (1 - fy) + p10[k] * fx * (1 - fy) + p01[k] * (1 - fx) * fy + p11[k] * fx * fy);
  };
  // 封面底色：取左側中段深色區的平均
  let base = [0, 0, 0], n = 0;
  for (let v = 0.55; v < 0.75; v += 0.01) for (let u = 0.08; u < 0.14; u += 0.01) { const s = sample(...map(u, v)); if (s) { base = base.map((q, k) => q + s[k]); n++; } }
  base = base.map((q) => q / n);
  const baseLum = 0.3 * base[0] + 0.6 * base[1] + 0.1 * base[2];
  const out = Buffer.alloc(OW * OH * 3);
  // 補色區：左上角（畫面外與露出的背景）、左緣中段（手指）；每列取補色區右側的封面顏色，左右接得上
  const zone = (u, v) => (v < 0.16 ? 0.024 : v > 0.5 && v < 0.78 ? 0.075 : 0);
  let last = base;
  for (let j = 0; j < OH; j++) {
    const v = inset + (1 - 2 * inset) * (j + 0.5) / OH;
    const edge = zone(0, v);
    let fill = base;
    if (edge > 0) {
      let acc = [0, 0, 0], k = 0;
      for (let du = 0.004; du <= 0.016; du += 0.002) { const q = sample(...map(edge + du, v)); if (q) { acc = acc.map((a, c) => a + q[c]); k++; } }
      fill = k ? acc.map((a) => a / k) : last;
      // 碰到白字（標誌）時沿用上一列
      if (0.3 * fill[0] + 0.6 * fill[1] + 0.1 * fill[2] > baseLum + 40) fill = last;
      last = fill;
    }
    for (let i = 0; i < OW; i++) {
      const u = inset + (1 - 2 * inset) * (i + 0.5) / OW;
      let s = sample(...map(u, v));
      if (!s) s = fill;
      else if (edge > 0 && u < edge + 0.006) {
        const kk = Math.min(1, Math.max(0, (u - edge) / 0.006));
        s = s.map((q, c) => fill[c] * (1 - kk) + q * kk);
      }
      out.set(s.map((q) => Math.round(q)), (j * OW + i) * 3);
    }
  }
  const dst = resolve(here, '../public/deck/cover_html_css.jpg');
  mkdirSync(dirname(dst), { recursive: true });
  await sharp(out, { raw: { width: OW, height: OH, channels: 3 } }).jpeg({ quality: 92 }).toFile(dst);
  console.log(dst);
}

async function shot(query, out, w = 1200, h = 1200, pr = 1) {
  const { browser, page } = await open(query, Number(w), Number(h), Number(pr));
  await frameReady(page);
  const info = await page.evaluate(() => window.__info());
  await page.screenshot({ path: out, omitBackground: !query.includes('mode=gif') });
  await browser.close();
  console.log(out, JSON.stringify(info));
}

async function cover() {
  const { browser, page } = await open('mode=cover', 1920, 1080, 2);
  await frameReady(page);
  const info = await page.evaluate(() => window.__info());
  const out = join(OUT, 'cover.png');
  await page.screenshot({ path: out, omitBackground: true, type: 'png' });
  await browser.close();
  const m = await sharp(out).metadata();
  console.log(out, m.width, m.height, JSON.stringify(info.kioskScreen));
}

async function hero() {
  const front = flag('--cam') === 'front';
  const { browser, page } = await open('mode=hero', front ? 1450 : 1300, front ? 1400 : 1250, 2);
  await frameReady(page);
  const buf = await page.screenshot({ omitBackground: true, type: 'png' });
  await browser.close();
  const c = await cropAlpha(buf, 40);
  const out = join(OUT, front ? 'cabinet_front.png' : 'cabinet_hero.png');
  writeFileSync(out, c.buf);
  console.log(out, c.width, c.height, JSON.stringify(c.touches));
}

async function xray() {
  const front = flag('--cam') === 'front';
  const base = front ? 'cabinet_xray_front' : 'cabinet_xray';
  const { browser, page } = await open('mode=xray', 1300, 1250, 2);
  await frameReady(page);
  const info = await page.evaluate(() => window.__info());
  const buf = await page.screenshot({ omitBackground: true, type: 'png' });
  await browser.close();
  const c = await cropAlpha(buf, 40);
  const out = join(OUT, `${base}.png`);
  writeFileSync(out, c.buf);
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
    image: `${base}.png`, width: c.width, height: c.height,
    note: '座標為圖片像素（左上角為原點）；nx、ny 為相對寬高的比例。主控板來源：' + info.boardSource,
    points,
  };
  writeFileSync(join(OUT, `${base}_points.json`), JSON.stringify(json, null, 2) + '\n');
  console.log(out, c.width, c.height, JSON.stringify(c.touches));
}

async function gif(flow) {
  const tl = flag('--tl');
  const { w, h } = GIF_SIZE;
  const preset = flag('--preset');
  const { browser, page } = await open(`mode=gif&flow=${flow}${tl ? `&tl=${tl}` : ''}${preset ? `&preset=${preset}` : ''}`, w, h, 2);
  const info = await page.evaluate(() => window.__info());
  const loop = info.tl.loop;
  const N = Math.round(loop * FPS);
  const dir = join(TMP, `gif_${flow}`);
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(dir, { recursive: true });
  const cdp = await page.createCDPSession();
  const uniq = [];
  let prev = null;
  for (let i = 0; i < N; i++) {
    await page.evaluate((t) => window.__seek(t), i / FPS);
    await frameReady(page);
    const { data } = await cdp.send('Page.captureScreenshot', { format: 'png' });
    // 2 倍算圖 → 縮成最終尺寸
    const raw = await sharp(Buffer.from(data, 'base64')).resize(w, h, { kernel: 'lanczos3' }).removeAlpha().raw().toBuffer();
    if (prev && raw.equals(prev)) { uniq[uniq.length - 1].n++; continue; }
    prev = raw;
    const file = join(dir, `f${String(i).padStart(4, '0')}.png`);
    await sharp(raw, { raw: { width: w, height: h, channels: 3 } }).png().toFile(file);
    uniq.push({ file, n: 1, i });
  }
  await browser.close();
  // 每格停留時間：GIF 以 1/100 秒計，25 fps 一格 4（ffmpeg 6 會採用最後一格的 duration，不必重複列出）
  const list = ['ffconcat version 1.0'];
  for (const u of uniq) list.push(`file '${u.file}'`, `duration ${(u.n / FPS).toFixed(2)}`);
  const listFile = join(dir, 'list.txt');
  writeFileSync(listFile, list.join('\n') + '\n');
  const pal = join(dir, 'palette.png');
  run(['-y', '-f', 'concat', '-safe', '0', '-i', listFile, '-vf', 'palettegen=max_colors=256:reserve_transparent=0:stats_mode=full', pal]);
  // 調色盤中最接近背景色的一格改成背景色，背景與投影片底色完全一致
  const p = await sharp(pal).removeAlpha().raw().toBuffer({ resolveWithObject: true });
  let best = 0, bd = Infinity;
  for (let k = 0; k < p.info.width * p.info.height; k++) {
    const d = (p.data[k * 3] - BG[0]) ** 2 + (p.data[k * 3 + 1] - BG[1]) ** 2 + (p.data[k * 3 + 2] - BG[2]) ** 2;
    if (d < bd) { bd = d; best = k; }
  }
  p.data[best * 3] = BG[0]; p.data[best * 3 + 1] = BG[1]; p.data[best * 3 + 2] = BG[2];
  await sharp(p.data, { raw: p.info }).png().toFile(pal + '.fix.png');
  const out = join(OUT, `cabinet_${flow}.gif`);
  run(['-y', '-f', 'concat', '-safe', '0', '-i', listFile, '-i', pal + '.fix.png', '-lavfi', '[0:v][1:v]paletteuse=dither=sierra2_4a:diff_mode=rectangle', '-fps_mode', 'passthrough', '-loop', '0', out]);
  // 首格 PNG（PDF 版與縮圖用）
  await sharp(uniq[0].file).png().toFile(join(OUT, `cabinet_${flow}_poster.png`));
  const delays = gifDelays(out);
  const total = delays.reduce((s, d) => s + d, 0) / 100;
  console.log(out, `${(statSync(out).size / 1024 / 1024).toFixed(2)} MB`, `${w}×${h}`, `${delays.length} 格（原 ${N} 格）`, `總長 ${total}s`, `背景色差 ${bd}`);
}


/** 逐格算圖到 dir/f00000.png（多個分頁平行），page.screenshot 取裝置像素（2 倍）。 */
async function renderFrames(query, w, h, pr, N, fps, dir, workers = 4) {
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(dir, { recursive: true });
  const size = Math.ceil(N / workers);
  const t0 = Date.now();
  await Promise.all(Array.from({ length: workers }, async (_, k) => {
    const a = k * size, b = Math.min(N, a + size);
    if (a >= b) return;
    const { browser, page } = await open(query, w, h, pr);
    for (let i = a; i < b; i++) {
      await page.evaluate((t) => window.__seek(t), i / fps);
      await frameReady(page);
      await page.screenshot({ path: join(dir, `f${String(i).padStart(5, '0')}.png`), type: 'png' });
      if ((i - a) % 120 === 0) process.stderr.write(`[${k}] ${i}/${b} ${((Date.now() - t0) / 1000).toFixed(0)}s\n`);
    }
    await browser.close();
  }));
}

/** H.264 60 fps（規格見 deck_video_brief.md），輸出後量背景色與串流資訊。 */
async function encode(dir, fps, out, poster) {
  mkdirSync(dirname(out), { recursive: true });
  run([
    '-y', '-framerate', String(fps), '-i', join(dir, 'f%05d.png'),
    '-vf', 'scale=out_color_matrix=bt709:out_range=tv:flags=accurate_rnd+full_chroma_int,format=yuv420p,setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709:range=tv',
    '-c:v', 'libx264', '-profile:v', 'high', '-preset', 'slow', '-crf', '18', '-r', String(fps),
    '-colorspace', 'bt709', '-color_primaries', 'bt709', '-color_trc', 'bt709', '-color_range', 'tv',
    '-movflags', '+faststart', '-an', out,
  ], ffmpeg7);
  await sharp(join(dir, 'f00000.png')).png().toFile(poster);
  // 抽一格量背景色（以 bt709 tv range、精確捨入解回 RGB）
  const probe = join(dir, 'bgprobe.png');
  run(['-y', '-i', out, '-vf', 'select=eq(n\\,30),scale=in_color_matrix=bt709:in_range=tv:flags=accurate_rnd+full_chroma_int,format=rgb24', '-frames:v', '1', '-update', '1', probe], ffmpeg7);
  const { data: px, info: pi } = await sharp(probe).removeAlpha().raw().toBuffer({ resolveWithObject: true });
  const at = (x, y) => [...px.subarray((y * pi.width + x) * 3, (y * pi.width + x) * 3 + 3)];
  const corners = [at(4, 4), at(pi.width - 5, 4), at(4, pi.height - 5), at(pi.width - 5, pi.height - 5)];
  const diff = Math.max(...corners.flatMap((c) => c.map((v, k) => Math.abs(v - BG[k]))));
  const meta = spawnSync(ffmpeg7, ['-hide_banner', '-i', out], { encoding: 'utf8' }).stderr.split('\n').filter((l) => /Duration|Stream/.test(l)).map((l) => l.trim()).join(' | ');
  console.log(out, `${(statSync(out).size / 1024 / 1024).toFixed(2)} MB`, `背景 ${JSON.stringify(corners[0])} 最大色差 ${diff}`);
  console.log(meta);
}

async function video(flow) {
  const tl = flag('--tl');
  const fps = 60;
  // 與 GIF 版相同長寬比，2 倍：2000×1800
  const { w, h } = GIF_SIZE;
  const preset = flag('--preset');
  const query = `mode=gif&flow=${flow}${tl ? `&tl=${tl}` : ''}${preset ? `&preset=${preset}` : ''}`;
  const probe = await open(query, 200, 180, 1);
  const info = await probe.page.evaluate(() => window.__info());
  await probe.browser.close();
  const N = Math.round(info.tl.loop * fps);
  const dir = join(TMP, `video_${flow}`);
  await renderFrames(query, w, h, 2, N, fps, dir);
  await encode(dir, fps, join(VIDEO, `cabinet3d_${flow}.mp4`), join(VIDEO, `cabinet3d_${flow}_poster.png`));
  console.log(`${N} 格，${(N / fps).toFixed(3)} 秒`);
}

async function spin() {
  const fps = 60, N = 8 * fps;
  const front = flag('--cam') === 'front';
  const name = front ? 'cabinet_spin_front' : 'cabinet_spin';
  const dir = join(TMP, `video_${name}`);
  await renderFrames(`mode=spin${front ? '&cam=front' : ''}`, 800, 800, 2, N, fps, dir);
  await encode(dir, fps, join(VIDEO, `${name}.mp4`), join(VIDEO, `${name}_poster.png`));
  console.log(`${N} 格，${(N / fps).toFixed(3)} 秒`);
}

/** 原尺寸連續 6 格（1/60 秒間隔）裁出指定區域並排，檢查轉場是否平順。 */
async function strip(file, t0, region) {
  const [x, y, cw, ch] = region.split(',').map(Number);
  const dir = join(TMP, `strip_${basename(file).replace(/\.\w+$/, '')}`);
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(dir, { recursive: true });
  run(['-y', '-ss', String(t0), '-i', file, '-vf', `scale=in_color_matrix=bt709:in_range=tv,format=rgb24,crop=${cw}:${ch}:${x}:${y}`, '-frames:v', '6', join(dir, 's%d.png')], ffmpeg7);
  const tiles = await Promise.all([1, 2, 3, 4, 5, 6].map(async (k, i) => ({ input: await sharp(join(dir, `s${k}.png`)).png().toBuffer(), left: (i % 3) * (cw + 6), top: Math.floor(i / 3) * (ch + 6) })));
  const out = join(dir, 'strip.png');
  await sharp({ create: { width: 3 * (cw + 6), height: 2 * (ch + 6), channels: 3, background: '#333' } }).composite(tiles).png().toFile(out);
  console.log(out);
}

async function glb(solid = rest.includes('--solid')) {
  const { browser, page } = await open(`mode=glb${solid ? '&solid=1' : ''}`, 800, 600, 1);
  const info = await page.evaluate(() => window.__info());
  await frameReady(page);
  await page.screenshot({ path: join(TMP, solid ? 'glb_solid_preview.png' : 'glb_preview.png'), omitBackground: true });
  await browser.close();
  const out = join(OUT, solid ? 'cabinet_solid.glb' : 'cabinet.glb');
  writeFileSync(out, Buffer.from(info.glb, 'base64'));
  // 以 node 直接讀 GLB 的 JSON 區塊確認
  const b = readFileSync(out);
  const jsonLen = b.readUInt32LE(12);
  const j = JSON.parse(b.subarray(20, 20 + jsonLen).toString('utf8'));
  const prims = j.meshes.reduce((n, m) => n + m.primitives.length, 0);
  const alpha = {};
  for (const m of j.materials) alpha[m.alphaMode || 'OPAQUE'] = (alpha[m.alphaMode || 'OPAQUE'] || 0) + 1;
  console.log(out, `${(b.length / 1024 / 1024).toFixed(2)} MB`);
  console.log('glTF 讀回：', JSON.stringify({ magic: b.subarray(0, 4).toString(), version: b.readUInt32LE(4), nodes: j.nodes.length, meshes: j.meshes.length, primitives: prims, materials: j.materials.length, textures: (j.textures || []).length, images: (j.images || []).map((im) => im.mimeType), alphaModes: alpha, extensionsUsed: j.extensionsUsed || [], rootScale: j.nodes[j.scenes[0].nodes[0]].scale }));
  console.log('three.js 讀回：', JSON.stringify(info.check));
}

async function check(flow) {
  const tl = flag('--tl');
  const { browser, page } = await open(`mode=gif&flow=${flow}${tl ? `&tl=${tl}` : ''}`, 400, 360, 1);
  const info = await page.evaluate(() => window.__info());
  const fps = Number(flag('--fps') || FPS);
  const N = Math.round(info.tl.loop * fps);
  let bad = 0;
  for (let i = 0; i < N; i++) {
    const r = await page.evaluate((t) => window.__collide(t), i / fps);
    if (r.length) { bad++; console.log((i / fps).toFixed(3), r.join('；')); }
  }
  await browser.close();
  console.log(`${flow}：${N} 格，穿模 ${bad} 格`);
}

async function review(file) {
  const name = basename(file).replace(/\.\w+$/, '');
  const dir = join(TMP, `review_${name}`);
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(dir, { recursive: true });
  if (file.endsWith('.gif') || file.endsWith('.mp4')) {
    const mp4 = file.endsWith('.mp4');
    run(['-y', '-i', file, '-vf', `fps=5,${mp4 ? 'scale=in_color_matrix=bt709:in_range=tv:w=iw/2:h=-2,format=rgb24' : 'scale=iw/2:-1:flags=lanczos'}`, join(dir, 'r%03d.png')], mp4 ? ffmpeg7 : ffmpeg);
    const frames = readdirSync(dir).filter((f) => f.startsWith('r')).sort();
    const per = 12, cols = 4;
    const m0 = await sharp(join(dir, frames[0])).metadata();
    const tw = m0.width, th = m0.height;
    for (let s = 0; s * per < frames.length; s++) {
      const group = frames.slice(s * per, s * per + per);
      const tiles = await Promise.all(group.map(async (f, i) => {
        const t = ((s * per + i) * 0.2).toFixed(1);
        const svg = Buffer.from(`<svg width="64" height="22" xmlns="http://www.w3.org/2000/svg"><rect width="64" height="22" fill="#000" opacity=".7"/><text x="5" y="16" font-size="15" fill="#ff0" font-family="Menlo">${t}s</text></svg>`);
        return { input: await sharp(join(dir, f)).composite([{ input: svg, top: 0, left: 0 }]).png().toBuffer(), left: (i % cols) * (tw + 4), top: Math.floor(i / cols) * (th + 4) };
      }));
      const rows = Math.ceil(group.length / cols);
      const out = join(dir, `sheet${String(s + 1).padStart(2, '0')}.png`);
      await sharp({ create: { width: cols * (tw + 4), height: rows * (th + 4), channels: 3, background: '#333' } }).composite(tiles).png().toFile(out);
      console.log(out);
    }
  } else {
    const m = await sharp(file).metadata();
    const out = join(dir, `${name}_half.png`);
    // 透明圖放在投影片底色上看
    await sharp(file).resize(Math.round(m.width / 2)).flatten({ background: '#F8FAFB' }).png().toFile(out);
    console.log(out, m.width, m.height);
  }
}

if (cmd === 'photo') await photo(rest[0]);
else if (cmd === 'shot') await shot(rest[0], rest[1], rest[2], rest[3], rest[4]);
else if (cmd === 'cover') await cover();
else if (cmd === 'hero') await hero();
else if (cmd === 'xray') await xray();
else if (cmd === 'gif') await gif(rest[0] || 'deposit');
else if (cmd === 'check') await check(rest[0] || 'deposit');
else if (cmd === 'video') await video(rest[0] || 'deposit');
else if (cmd === 'spin') await spin();
else if (cmd === 'reencode') {
  // 只重新編碼已算好的格（TMP/video_<名稱>）
  const name = rest[0];
  const file = name === 'spin' ? 'cabinet_spin' : `cabinet3d_${name}`;
  await encode(join(TMP, `video_${name}`), 60, join(VIDEO, `${file}.mp4`), join(VIDEO, `${file}_poster.png`));
}
else if (cmd === 'strip') await strip(resolve(rest[0]), Number(rest[1]), rest[2]);
else if (cmd === 'glb') await glb();
else if (cmd === 'review') await review(resolve(rest[0]));
else console.log('用法見檔頭註解');
