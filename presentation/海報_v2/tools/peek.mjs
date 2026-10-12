// 審稿用：把海報輸出成低 dpi PNG，再切成數段 JPG（預覽/peek/<name>-<i>.jpg）
//   node tools/peek.mjs poster3 [dpi=45] [段數=3]
import { execFileSync } from 'node:child_process';
import { mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';
const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const [name, dpi = '45', parts = '3'] = process.argv.slice(2);
execFileSync('node', [join(ROOT, 'tools/render.mjs'), name, '--trim', '--png', '--dpi', dpi], { stdio: 'inherit' });
const num = name.match(/(\d+)$/)[1];
const src = join(ROOT, '成品', '不含出血', `115414－海報${num}.png`);
const out = join(ROOT, '預覽', 'peek');
mkdirSync(out, { recursive: true });
const { width, height } = await sharp(src).metadata();
const n = +parts, h = Math.ceil(height / n);
for (let i = 0; i < n; i++) {
  const top = i * h, hh = Math.min(h, height - top);
  await sharp(src).extract({ left: 0, top, width, height: hh }).jpeg({ quality: 88 }).toFile(join(out, `${name}-${i + 1}.jpg`));
}
console.log(`peek → ${out}（${n} 段）`);
