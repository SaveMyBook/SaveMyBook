// 拼總覽圖：node tools/montage.mjs <輸出.png> <欄數> <每張寬度> <圖檔...>（本機沒有 ImageMagick，用 sharp 代替 magick montage）
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const sharp = require('sharp');
const [out, cols, w, ...files] = process.argv.slice(2);
const W = +w, C = +cols;
const imgs = await Promise.all(files.map(async (f) => { const b = await sharp(f).resize({ width: W }).png().toBuffer(); const m = await sharp(b).metadata(); return { b, h: m.height }; }));
const H = Math.max(...imgs.map((i) => i.h)) + 30;
const rows = Math.ceil(imgs.length / C);
const comps = [];
imgs.forEach((im, i) => {
  const x = (i % C) * (W + 10), y = Math.floor(i / C) * (H + 10);
  comps.push({ input: im.b, left: x, top: y + 30 });
  const name = files[i].split('/').pop().replace(/&/g, '&amp;');
  comps.push({ input: Buffer.from(`<svg width="${W}" height="30"><text x="4" y="22" font-size="18" font-family="sans-serif">${name}</text></svg>`), left: x, top: y });
});
await sharp({ create: { width: C * (W + 10), height: rows * (H + 10), channels: 3, background: '#ddd' } }).composite(comps).png().toFile(out);
console.log(out);
