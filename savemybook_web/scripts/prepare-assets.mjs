// 由專案素材產生網站用的圖示、App 畫面、算圖與介紹影片；產出放在 public/，可重複執行。
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const here = dirname(fileURLToPath(import.meta.url));
const web = resolve(here, '..');
const repo = resolve(web, '..');
const pub = join(web, 'public');
const logoDir = join(repo, 'branding/Logo Design');
const film = join(repo, 'presentation/系統簡介影片/成品');
const ffmpeg = join(repo, 'presentation/介紹動畫/src/node_modules/ffmpeg-static/ffmpeg');

const BRAND = '#627D8D';
const only = process.argv.slice(2);
const want = (k) => !only.length || only.includes(k);

function ensure(dir) {
  mkdirSync(dir, { recursive: true });
  return dir;
}

async function icons() {
  const out = ensure(join(pub, 'brand'));
  const white = join(logoDir, '全去背.png');
  const slate = join(logoDir, '銀藍反向版.png');
  await sharp(white).resize(1024).webp({ quality: 90 }).toFile(join(out, 'book-white.webp'));
  await sharp(slate).resize(512).webp({ quality: 90 }).toFile(join(out, 'book-slate.webp'));
  await sharp(slate).resize(128).png().toFile(join(out, 'book-slate-128.png'));
  // App 圖示樣式：石板藍底、白色書本，圓角交給各平台自行裁切。
  const tile = async (size, pad) => {
    const inner = Math.round(size * (1 - pad * 2));
    const mark = await sharp(white).resize(inner).png().toBuffer();
    return sharp({ create: { width: size, height: size, channels: 4, background: BRAND } })
      .composite([{ input: mark, gravity: 'center' }])
      .png();
  };
  await (await tile(32, 0.06)).toFile(join(pub, 'favicon-32.png'));
  await (await tile(180, 0.12)).toFile(join(pub, 'apple-touch-icon.png'));
  await (await tile(512, 0.12)).toFile(join(pub, 'icon-512.png'));
}

async function screens() {
  const src = join(web, 'assets-src/screens');
  if (!existsSync(src)) return console.log('screens: 尚無來源圖，略過');
  const out = ensure(join(pub, 'screens'));
  const files = readdirSync(src).filter((f) => f.endsWith('.png') && !f.startsWith('_'));
  for (const f of files) {
    const name = f.replace(/\.png$/, '');
    await sharp(join(src, f)).resize({ width: 1179 }).webp({ quality: 88 }).toFile(join(out, `${name}.webp`));
    await sharp(join(src, f)).resize({ width: 600 }).webp({ quality: 86 }).toFile(join(out, `${name}-s.webp`));
  }
  console.log('screens:', files.length);
}

// 檔名帶版本：/media/ 與 Cloudflare 都會快取一週，換片時改 VIDEO 才不會播到舊檔
const VIDEO = 'intro-v3';

async function video() {
  const out = ensure(join(pub, 'media'));
  // 中英字幕已燒在畫面上，網頁不另加字幕軌
  const src = join(film, '四技第115414組-救「舊」我的書-系統簡介影片-中英字幕.mp4');
  execFileSync(ffmpeg, ['-y', '-loglevel', 'error', '-i', src,
    '-vf', 'fps=30', '-c:v', 'libx264', '-preset', 'slow', '-crf', '27', '-pix_fmt', 'yuv420p',
    '-c:a', 'aac', '-b:a', '128k', '-movflags', '+faststart', join(out, `${VIDEO}.mp4`)]);
  // 封面取片頭品牌與書櫃、手機同框的那一格（無字幕的中文版）
  const still = join(out, '.poster.png');
  execFileSync(ffmpeg, ['-y', '-loglevel', 'error', '-ss', '15.5', '-i', join(film, '四技第115414組-救「舊」我的書-系統簡介影片-4K.mp4'),
    '-frames:v', '1', still]);
  await sharp(still).resize(1600).webp({ quality: 82 }).toFile(join(out, `${VIDEO}-poster.webp`));
  rmSync(still);
}

async function boardCutout(src, out) {
  const A = await sharp(join(src, 'pcb.png')).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const B = await sharp(join(src, 'pcb-empty.png')).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const W = A.info.width, H = A.info.height, R = 4;
  let m = new Uint8Array(W * H);
  for (let i = 0; i < W * H; i++) {
    const o = i * 4;
    let v = 0;
    for (let c = 0; c < 4; c++) v = Math.max(v, Math.abs(A.data[o + c] - B.data[o + c]));
    m[i] = v > 30 ? 1 : 0;
  }
  const pass = (src0, op, horiz) => {
    const res = new Uint8Array(W * H);
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      let v = op === 'max' ? 0 : 1;
      for (let k = -R; k <= R; k++) {
        const xx = horiz ? x + k : x, yy = horiz ? y : y + k;
        const s0 = xx < 0 || yy < 0 || xx >= W || yy >= H ? 0 : src0[yy * W + xx];
        v = op === 'max' ? Math.max(v, s0) : Math.min(v, s0);
      }
      res[y * W + x] = v;
    }
    return res;
  };
  m = pass(pass(m, 'max', true), 'max', false);
  m = pass(pass(m, 'min', true), 'min', false);
  const comp = new Int32Array(W * H).fill(-1);
  let best = -1, bestN = 0, id = 0;
  for (let i = 0; i < W * H; i++) {
    if (!m[i] || comp[i] >= 0) continue;
    const st = [i];
    comp[i] = id;
    let n = 0;
    while (st.length) {
      const j = st.pop();
      n++;
      const x = j % W, y = (j / W) | 0;
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const xx = x + dx, yy = y + dy;
        if (xx < 0 || yy < 0 || xx >= W || yy >= H) continue;
        const k = yy * W + xx;
        if (m[k] && comp[k] < 0) { comp[k] = id; st.push(k); }
      }
    }
    if (n > bestN) { bestN = n; best = id; }
    id++;
  }
  let x0 = W, y0 = H, x1 = 0, y1 = 0;
  const alpha = Buffer.alloc(W * H);
  for (let i = 0; i < W * H; i++) {
    if (comp[i] !== best) continue;
    alpha[i] = 255;
    const x = i % W, y = (i / W) | 0;
    x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y);
  }
  const bw = x1 - x0 + 1, bh = y1 - y0 + 1;
  const a = await sharp(alpha, { raw: { width: W, height: H, channels: 1 } }).blur(0.8).extract({ left: x0, top: y0, width: bw, height: bh }).extractChannel(0).raw().toBuffer();
  const rgba = await sharp(join(src, 'pcb.png')).ensureAlpha().extract({ left: x0, top: y0, width: bw, height: bh }).raw().toBuffer();
  for (let i = 0; i < bw * bh; i++) rgba[i * 4 + 3] = Math.min(rgba[i * 4 + 3], a[i]);
  const board = sharp(rgba, { raw: { width: bw, height: bh, channels: 4 } });
  await board.clone().webp({ quality: 88, alphaQuality: 100 }).toFile(join(out, 'pcb-board@2x.webp'));
  await board.clone().resize({ width: Math.round(bw / 2) }).webp({ quality: 88, alphaQuality: 100 }).toFile(join(out, 'pcb-board@1x.webp'));
  const f = (v) => +(v * 100).toFixed(3);
  writeFileSync(join(web, 'src/data/pcb.ts'), `// 由 scripts/prepare-assets.mjs 產生，請勿手動修改\nexport const BOARD = { x: ${f(x0 / W)}, y: ${f(y0 / H)}, w: ${f(bw / W)}, h: ${f(bh / H)}, px: ${bw} } as const;\n`);
}

async function renders() {
  const src = join(web, 'assets-src/renders');
  const out = ensure(join(pub, 'renders'));
  const job = [
    ['cabinet-hero.png', 'cabinet-hero.webp', 1600, 86],
    ['cabinet-front.png', 'cabinet-front.webp', 1600, 86],
    ['pcb.png', 'pcb.webp', 2400, 84],
    ['pcb.png', 'pcb@1x.webp', 1200, 84],
    ['pcb-empty.png', 'pcb-empty.webp', 2400, 84],
    ['pcb-empty.png', 'pcb-empty@1x.webp', 1200, 84],
  ];
  for (const [from, to, width, quality] of job) {
    await sharp(join(src, from)).resize({ width, withoutEnlargement: true }).webp({ quality, alphaQuality: 90 }).toFile(join(out, to));
  }
  await boardCutout(src, out);
  console.log('renders:', job.length + 1);
}

if (want('icons')) await icons();
if (want('screens')) await screens();
if (want('renders')) await renders();
if (want('video')) await video();
console.log('done');
