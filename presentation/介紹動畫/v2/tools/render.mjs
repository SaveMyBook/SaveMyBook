// 逐格算圖並交給 ffmpeg 編碼：node tools/render.mjs <out.mp4> [起秒] [迄秒] [pixelRatio] [workers] [動態模糊取樣數]
// 每格先以 __seek 設定時間再截圖，輸出與播放速度無關。需先 npm run dev（5290 埠）。
import { createRequire } from 'node:module';
import { dirname, resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { mkdirSync, writeFileSync, unlinkSync, rmSync } from 'node:fs';
import { spawn } from 'node:child_process';

const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const puppeteer = require(resolve(here, '../../src/node_modules/puppeteer'));
const ffmpeg = require(resolve(here, '../../src/node_modules/ffmpeg-static'));

const [out, fromArg = '0', toArg, prArg = '1', workersArg = '4', mbArg = '0'] = process.argv.slice(2);
const FPS = 60;
const PR = Number(prArg);
const WORKERS = Number(workersArg);

function run(args, input) {
  return new Promise((ok, fail) => {
    const p = spawn(ffmpeg, args, { stdio: [input ? 'pipe' : 'ignore', 'ignore', 'pipe'] });
    let err = '';
    p.stderr.on('data', (d) => { err = (err + d).slice(-4000); });
    p.on('close', (code) => (code === 0 ? ok() : fail(new Error(err))));
    if (input) input(p);
  });
}

async function segment(start, end, target, log) {
  const browser = await puppeteer.launch({ headless: true, args: ['--use-angle=metal', '--enable-gpu', '--ignore-gpu-blocklist', '--hide-scrollbars'] });
  const page = await browser.newPage();
  await page.setViewport({ width: 1920 * PR, height: 1080 * PR, deviceScaleFactor: 1 });
  await page.goto(`http://127.0.0.1:5290/?render&pr=${PR}&scale=${PR}&mb=${mbArg}`, { waitUntil: 'networkidle0' });
  await page.waitForFunction(() => window.__ready === true, { timeout: 120000 });
  const cdp = await page.createCDPSession();
  await run([
    '-y', '-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'mjpeg', '-i', '-',
    '-vf', 'scale=in_range=pc:out_range=tv:out_color_matrix=bt709,format=yuv420p',
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '15', '-profile:v', 'high',
    '-colorspace', 'bt709', '-color_primaries', 'bt709', '-color_trc', 'bt709', '-color_range', 'tv',
    '-r', String(FPS), target,
  ], async (p) => {
    for (let f = start; f < end; f++) {
      await page.evaluate((t) => window.__seek(t), f / FPS);
      await page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))));
      const { data } = await cdp.send('Page.captureScreenshot', { format: 'jpeg', quality: 95 });
      if (!p.stdin.write(Buffer.from(data, 'base64'))) await new Promise((r) => p.stdin.once('drain', r));
      if ((f - start) % 120 === 0) log(f);
    }
    p.stdin.end();
  });
  await browser.close();
}

const probe = await puppeteer.launch({ headless: true });
const pg = await probe.newPage();
await pg.goto('http://127.0.0.1:5290/?render', { waitUntil: 'networkidle0' });
const duration = await pg.evaluate(() => window.__duration);
await probe.close();

const first = Math.round(Number(fromArg) * FPS);
const total = Math.round(Math.min(Number(toArg ?? duration), duration) * FPS);
const dir = join(dirname(resolve(out)), '.segments');
mkdirSync(dir, { recursive: true });
const size = Math.ceil((total - first) / WORKERS);
const segs = [];
for (let i = 0; i < WORKERS; i++) {
  const s = first + i * size;
  const e = Math.min(total, s + size);
  if (s < e) segs.push({ i, s, e, file: join(dir, `seg${i}.mp4`) });
}
const t0 = Date.now();
await Promise.all(segs.map((sg) => segment(sg.s, sg.e, sg.file, (f) => process.stderr.write(`[${sg.i}] ${f}/${sg.e} ${((Date.now() - t0) / 1000).toFixed(0)}s\n`))));
const list = join(dir, 'list.txt');
writeFileSync(list, segs.map((sg) => `file '${sg.file.replace(/'/g, "'\\''")}'`).join('\n'));
await run(['-y', '-f', 'concat', '-safe', '0', '-i', list, '-c', 'copy', '-movflags', '+faststart', resolve(out)]);
for (const sg of segs) unlinkSync(sg.file);
rmSync(dir, { recursive: true, force: true });
console.log(JSON.stringify({ out: resolve(out), frames: total - first, seconds: (Date.now() - t0) / 1000 }));
