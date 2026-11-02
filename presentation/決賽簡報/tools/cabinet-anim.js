// 存書／取書的書櫃動畫（官網現行模型），與手機錄影同長度、同時間點，放在展示頁與手機影片並排同步播放。
// 用法：node tools/cabinet-anim.js [deposit|pickup]（預設兩支都做）→ 素材/video/cabinet3d_<flow>.mp4 與 _poster.png
// 算圖用 ../海報_v2/tools/3d/render-web.mjs 的 seq 模式（時間軸見 ../海報_v2/tools/3d/web/harness.ts）。
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const sharp = require('sharp');

sharp.cache(false);
const ROOT = path.join(__dirname, '..');
const POSTER = path.join(ROOT, '..', '海報_v2');
const VIDEO = path.join(ROOT, '素材', 'video');
const WORK = path.join(ROOT, 'build', 'cabinet-anim');
const FPS = 30, FADE = 0.4, OUT_H = 1080, BG = [245, 245, 247];
// 相機：書本從左前方送進 A01，所以視角偏正面、畫面放寬，最後再依所有畫格的實際範圍裁切
const CAM = { w: 2000, h: 1800, yaw: 0.32, pitch: 0.15, dist: 44 };

const duration = (file) => parseFloat(execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', file]).toString());

// 與底色差異超過門檻的像素範圍（所有畫格聯集）
async function contentBox(files) {
  let x0 = Infinity, y0 = Infinity, x1 = -1, y1 = -1;
  for (const f of files.filter((_, i) => i % 3 === 0)) {
    const { data, info } = await sharp(f).removeAlpha().raw().toBuffer({ resolveWithObject: true });
    for (let y = 0; y < info.height; y += 2) {
      for (let x = 0; x < info.width; x += 2) {
        const i = (y * info.width + x) * 3;
        if (Math.abs(data[i] - BG[0]) + Math.abs(data[i + 1] - BG[1]) + Math.abs(data[i + 2] - BG[2]) > 12) {
          if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y;
        }
      }
    }
  }
  return { x0, y0, x1, y1 };
}

async function make(flow) {
  const phone = path.join(VIDEO, `cabinet_${flow}.mp4`);
  const dur = duration(phone);
  const frames = path.join(WORK, flow);
  fs.rmSync(frames, { recursive: true, force: true });
  execFileSync('node', ['tools/3d/render-web.mjs', frames, JSON.stringify({ seq: flow, fps: FPS, dur, ...CAM })], { cwd: POSTER, stdio: 'inherit' });
  const files = fs.readdirSync(frames).filter((f) => f.endsWith('.png')).sort().map((f) => path.join(frames, f));

  // 裁切：內容範圍外留 4% 邊，寬高取偶數；縮到高 1,080
  const b = await contentBox(files);
  const pad = Math.round((b.y1 - b.y0) * 0.04);
  const left = Math.max(0, b.x0 - pad), top = Math.max(0, b.y0 - pad);
  const cw = Math.min(CAM.w - left, b.x1 - b.x0 + 2 * pad), ch = Math.min(CAM.h - top, b.y1 - b.y0 + 2 * pad);
  const outW = Math.round(cw * OUT_H / ch / 2) * 2;
  const frame = (f) => sharp(f).removeAlpha().extract({ left, top, width: cw, height: ch }).resize(outW, OUT_H).raw().toBuffer();

  const first = await frame(files[0]);
  const out = path.join(VIDEO, `cabinet3d_${flow}.mp4`);
  const enc = require('child_process').spawn('ffmpeg', [
    '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', `${outW}x${OUT_H}`, '-r', String(FPS), '-i', '-',
    '-vf', 'scale=out_color_matrix=bt709:out_range=tv', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-profile:v', 'high', '-crf', '18', '-preset', 'slow',
    '-x264-params', 'colorprim=bt709:transfer=bt709:colormatrix=bt709', '-movflags', '+faststart', '-an', out
  ], { stdio: ['pipe', 'inherit', 'inherit'] });
  const done = new Promise((ok, fail) => enc.on('close', (c) => (c ? fail(new Error(`ffmpeg ${c}`)) : ok())));
  for (let i = 0; i < files.length; i++) {
    let buf = i === 0 ? first : await frame(files[i]);
    // 結尾 0.4 秒淡回第一格（同手機錄影），循環時不跳格
    const k = (i / FPS - (dur - FADE)) / FADE;
    if (k > 0) {
      const a = Math.min(1, k);
      buf = Buffer.from(buf.map((v, j) => Math.round(v * (1 - a) + first[j] * a)));
    }
    if (!enc.stdin.write(buf)) await new Promise((r) => enc.stdin.once('drain', r));
  }
  enc.stdin.end();
  await done;
  await sharp(first, { raw: { width: outW, height: OUT_H, channels: 3 } }).png().toFile(path.join(VIDEO, `cabinet3d_${flow}_poster.png`));
  console.log(`${out}：${files.length} 格、${dur.toFixed(3)} 秒、${outW}×${OUT_H}`);
}

(async () => {
  const flows = process.argv.slice(2);
  for (const f of flows.length ? flows : ['deposit', 'pickup']) await make(f);
})().catch((e) => { console.error(e); process.exit(1); });
