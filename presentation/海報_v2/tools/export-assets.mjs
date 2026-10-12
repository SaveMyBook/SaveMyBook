// 交付附件：Logo 與海報中使用的圖檔（PNG，另附 SVG 向量檔）→ 成品/Logo與圖檔/
//   node tools/export-assets.mjs
import { copyFileSync, mkdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const A = join(ROOT, 'src', 'assets');
const OUT = join(ROOT, '成品', 'Logo與圖檔');
const G = '115414';
mkdirSync(OUT, { recursive: true });

// 向量檔：SVG 原檔＋高解析 PNG（透明背景）
async function svg(src, name, width) {
  copyFileSync(join(A, src), join(OUT, `${G}－${name}.svg`));
  const buf = readFileSync(join(A, src));
  await sharp(buf, { density: 600 }).resize({ width }).png().withDensity(300).toFile(join(OUT, `${G}－${name}.png`));
  console.log(`${G}－${name}.svg / .png`);
}
// 點陣檔：原解析度 PNG
async function png(src, name) {
  await sharp(join(A, src), { limitInputPixels: false }).png().withDensity(300).toFile(join(OUT, `${G}－${name}.png`));
  console.log(`${G}－${name}.png`);
}

await svg('brand/logo.svg', 'Logo', 3000);
await svg('brand/qr-site-ink.svg', '官網QR', 1500);
await png('3d/cabinet.png', '智慧書櫃3D示意');
await png('3d/pcb.png', '主控板3D示意');

