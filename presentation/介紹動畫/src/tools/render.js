'use strict';

// 以 Chrome 逐格算圖並交給 ffmpeg 編碼：node tools/render.js <svg> <out.mp4> [workers] [fps]
// 每格先暫停動畫、設定時間，再截圖，因此輸出與播放速度無關，每一格都精準對在時間軸上。
const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');
const puppeteer = require('puppeteer');
const ffmpeg = require('ffmpeg-static');

const [svg, out, workersArg = '4', fpsArg = '60'] = process.argv.slice(2);
const FPS = Number(fpsArg);
const WORKERS = Number(workersArg);

function run(args, { input } = {}) {
  return new Promise((resolve, reject) => {
    const p = spawn(ffmpeg, args, { stdio: [input ? 'pipe' : 'ignore', 'ignore', 'pipe'] });
    let err = '';
    p.stderr.on('data', (d) => {
      err = (err + d).slice(-4000);
    });
    p.on('close', (code) => (code === 0 ? resolve() : reject(new Error(err))));
    if (input) input(p);
  });
}

async function segment(file, start, end, target, log) {
  const browser = await puppeteer.launch({ headless: 'shell', args: ['--hide-scrollbars'] });
  const page = await browser.newPage();
  await page.setViewport({ width: 3840, height: 2160, deviceScaleFactor: 1 });
  await page.goto(`file://${file}`, { waitUntil: 'load' });
  await page.evaluate(() => document.documentElement.pauseAnimations());
  const cdp = await page.createCDPSession();
  const args = [
    '-y',
    '-f', 'image2pipe',
    '-framerate', String(FPS),
    '-c:v', 'mjpeg',
    '-i', '-',
    '-vf', 'scale=in_range=pc:out_range=tv:out_color_matrix=bt709,format=yuv420p',
    '-c:v', 'libx264',
    '-preset', 'medium',
    '-crf', '15',
    '-profile:v', 'high',
    '-level', '5.2',
    '-colorspace', 'bt709',
    '-color_primaries', 'bt709',
    '-color_trc', 'bt709',
    '-color_range', 'tv',
    '-r', String(FPS),
    target,
  ];
  await run(args, {
    input: async (p) => {
      for (let f = start; f < end; f++) {
        await page.evaluate((tt) => document.documentElement.setCurrentTime(tt), f / FPS);
        await page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))));
        const { data } = await cdp.send('Page.captureScreenshot', { format: 'jpeg', quality: 95 });
        if (!p.stdin.write(Buffer.from(data, 'base64'))) await new Promise((r) => p.stdin.once('drain', r));
        if ((f - start) % 120 === 0) log(f);
      }
      p.stdin.end();
    },
  });
  await browser.close();
}

async function main() {
  const file = path.resolve(svg);
  const src = fs.readFileSync(file, 'utf8');
  const m = src.match(/<animate attributeName="x" values="0;2;0" dur="([\d.]+)s"/);
  const duration = m ? Number(m[1]) : 177;
  const first = Math.round(Number(process.env.RENDER_FROM || 0) * FPS);
  const total = Math.round(Number(process.env.RENDER_TO || duration) * FPS);
  const dir = path.join(path.dirname(path.resolve(out)), '.segments');
  fs.mkdirSync(dir, { recursive: true });
  const size = Math.ceil((total - first) / WORKERS);
  const segs = [];
  for (let i = 0; i < WORKERS; i++) {
    const s = first + i * size;
    const e = Math.min(total, s + size);
    if (s < e) segs.push({ i, s, e, file: path.join(dir, `seg${i}.mp4`) });
  }
  const t0 = Date.now();
  await Promise.all(segs.map((sg) => segment(file, sg.s, sg.e, sg.file, (f) => process.stderr.write(`[${sg.i}] frame ${f}/${sg.e} ${((Date.now() - t0) / 1000).toFixed(0)}s\n`))));
  const list = path.join(dir, 'list.txt');
  fs.writeFileSync(list, segs.map((sg) => `file '${sg.file.replace(/'/g, "'\\''")}'`).join('\n'));
  await run(['-y', '-f', 'concat', '-safe', '0', '-i', list, '-c', 'copy', '-movflags', '+faststart', path.resolve(out)]);
  for (const sg of segs) fs.unlinkSync(sg.file);
  fs.unlinkSync(list);
  fs.rmdirSync(dir);
  console.log(JSON.stringify({ out: path.resolve(out), frames: total - first, fps: FPS, seconds: (Date.now() - t0) / 1000 }));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
