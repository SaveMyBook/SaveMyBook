// 由 3 倍 App 截圖裁出可浮出的介面元素：依元素本身的邊界與圓角去背成透明 WebP，並取元素外圍顏色的中位數作為浮起時留下的空位底色。
// 輸出 public/pops/<名稱>@1x／@2x／@3x.webp 與 src/data/pops.ts。座標單位為 393 寬的點（截圖為 1179 × 2556）。
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const web = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const src = join(web, 'assets-src/screens');
const out = join(web, 'public/pops');
const S = 3;

const POPS = [
  { key: 'notice', screen: 'notifications', x: 16.33, y: 226.33, w: 360.33, h: 136.33, r: 16 },
  { key: 'price', screen: 'sell_price', x: 16, y: 514, w: 361, h: 111, r: 12 },
  { key: 'advisor', screen: 'ai_chat', x: 53, y: 378, w: 156, h: 206, r: 12 },
  { key: 'banner', screen: 'chat_room', x: 0, y: 116, w: 393, h: 68, r: 0, slot: [243, 245, 247] },
  { key: 'progress', screen: 'order_detail', x: 20, y: 227, w: 353, h: 252, r: 16 },
];

mkdirSync(out, { recursive: true });
const hex = (c) => '#' + c.map((v) => v.toString(16).padStart(2, '0')).join('').toUpperCase();
const entries = [];
for (const p of POPS) {
  const file = join(src, `${p.screen}.png`);
  const { data, info } = await sharp(file).removeAlpha().raw().toBuffer({ resolveWithObject: true });
  const px = (x, y) => {
    const X = Math.min(info.width - 1, Math.max(0, Math.round(x * S))), Y = Math.min(info.height - 1, Math.max(0, Math.round(y * S)));
    const o = (Y * info.width + X) * 3;
    return [data[o], data[o + 1], data[o + 2]];
  };
  const samples = [px(p.x - 5, p.y + p.h / 2), px(p.x + p.w + 5, p.y + p.h / 2), px(p.x + p.w / 2, p.y - 5), px(p.x + p.w / 2, p.y + p.h + 5),
    px(p.x - 5, p.y + 8), px(p.x + p.w + 5, p.y + p.h - 8)];
  const slot = p.slot ?? [0, 1, 2].map((c) => samples.map((s) => s[c]).sort((a, b) => a - b)[Math.floor(samples.length / 2)]);

  const left = Math.round(p.x * S), top = Math.round(p.y * S), w = Math.round(p.w * S), h = Math.round(p.h * S), r = p.r * S;
  const mask = Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}"><rect width="${w}" height="${h}" rx="${r}" ry="${r}" fill="#fff"/></svg>`);
  const lw = 0.75 * S, inset = 0.4 * S;
  const edge = Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}"><rect x="${inset}" y="${inset}" width="${w - inset * 2}" height="${h - inset * 2}" rx="${r - inset}" ry="${r - inset}" fill="none" stroke="rgb(27,58,138)" stroke-opacity="0.10" stroke-width="${lw}"/></svg>`);
  const full = await sharp(file).extract({ left, top, width: w, height: h }).ensureAlpha()
    .composite([{ input: mask, blend: 'dest-in' }, { input: edge }])
    .png().toBuffer();
  const sizes = [];
  for (const k of [1, 2, 3]) {
    const width = Math.round(p.w * k);
    await sharp(full).resize({ width }).webp({ quality: 92, alphaQuality: 100, effort: 6 }).toFile(join(out, `${p.key}@${k}x.webp`));
    sizes.push(`/pops/${p.key}@${k}x.webp ${width}w`);
  }
  entries.push(`  ${p.key}: { src: '/pops/${p.key}@3x.webp', srcset: '${sizes.join(', ')}', screen: '${p.screen}', x: ${p.x}, y: ${p.y}, w: ${p.w}, h: ${p.h}, r: ${p.r}, slot: '${hex(slot)}' },`);
}

writeFileSync(join(web, 'src/data/pops.ts'), `// 由 scripts/pops.mjs 產生，請勿手動修改\nexport const POPS = {\n${entries.join('\n')}\n} as const;\n\nexport type PopKey = keyof typeof POPS;\n`);
console.log('pops:', POPS.length);
