// 由專案素材產生網站用的圖示、App 畫面與介紹影片；產出放在 public/，可重複執行。
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const here = dirname(fileURLToPath(import.meta.url));
const web = resolve(here, '..');
const repo = resolve(web, '..');
const pub = join(web, 'public');
const logoDir = join(repo, 'branding/Logo Design');
const film = join(repo, 'presentation/介紹動畫/成品');
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

function srtToVtt(srt) {
  const body = srt.replace(/^\uFEFF/, '').replace(/\r/g, '').replace(/(\d\d:\d\d:\d\d),(\d\d\d)/g, '$1.$2');
  return `WEBVTT\n\n${body.trim()}\n`;
}

async function video() {
  const out = ensure(join(pub, 'media'));
  const src = join(film, '四技第115414組-救「舊」我的書-介紹動畫-1080p60.mp4');
  execFileSync(ffmpeg, ['-y', '-loglevel', 'error', '-i', src,
    '-vf', 'fps=30', '-c:v', 'libx264', '-preset', 'slow', '-crf', '27', '-pix_fmt', 'yuv420p',
    '-c:a', 'aac', '-b:a', '128k', '-movflags', '+faststart', join(out, 'intro.mp4')]);
  await sharp(join(film, 'YouTube封面_3840x2160.png')).resize(1600).webp({ quality: 82 }).toFile(join(out, 'intro-poster.webp'));
  writeFileSync(join(out, 'intro.vtt'), srtToVtt(readFileSync(join(film, '字幕_中英.srt'), 'utf8')));
}

if (want('icons')) await icons();
if (want('screens')) await screens();
if (want('video')) await video();
console.log('done');
