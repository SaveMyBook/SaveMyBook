// 依網站實際用到的字，從 fontsource 的分片中只挑出需要的 woff2，寫成 src/styles/fonts.css。
// 改了頁面文字或程式中的字串後要重跑（npm run fonts，build 前會自動執行）。
import { readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const web = resolve(dirname(fileURLToPath(import.meta.url)), '..');

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else if (/\.(ts|html|css)$/.test(name) && !name.endsWith('fonts.css')) out.push(p);
  }
  return out;
}

const text = [join(web, 'index.html'), ...walk(join(web, 'src'))].map((f) => readFileSync(f, 'utf8')).join('');
const used = new Set();
for (const ch of text) used.add(ch.codePointAt(0));
// 基本拉丁字母與標點一律保留
for (let c = 0x20; c < 0x7f; c++) used.add(c);
for (const c of '，。、；：？！「」『』（）《》〈〉…—・／～％＋×') used.add(c.codePointAt(0));

function ranges(spec) {
  return spec.split(',').map((r) => r.trim().replace(/^U\+/i, '')).map((r) => {
    const [a, b] = r.split('-');
    return [parseInt(a, 16), parseInt(b ?? a, 16)];
  });
}

const FONTS = [
  ['noto-serif-tc', [700, 900]],
  ['noto-sans-tc', [400, 500, 700]],
  ['ibm-plex-mono', [400, 500]],
];

let css = '/* 由 scripts/fonts.mjs 產生，請勿手動修改 */\n';
let kept = 0, total = 0;
for (const [pkg, weights] of FONTS) {
  for (const w of weights) {
    const src = readFileSync(join(web, 'node_modules/@fontsource', pkg, `${w}.css`), 'utf8');
    for (const block of src.split('@font-face').slice(1)) {
      total++;
      const range = /unicode-range:\s*([^;]+);/.exec(block)?.[1];
      const hit = !range || ranges(range).some(([a, b]) => { for (const c of used) if (c >= a && c <= b) return true; return false; });
      if (!hit) continue;
      kept++;
      const woff2 = /url\(\.\/files\/([^)]+\.woff2)\)/.exec(block)[1];
      css += `@font-face${block.replace(/src:[^;]+;/, `src: url('../../node_modules/@fontsource/${pkg}/files/${woff2}') format('woff2');`).replace(/\/\*[^*]*\*\/\s*$/, '')}`;
    }
  }
}
writeFileSync(join(web, 'src/styles/fonts.css'), css.replace(/\n{3,}/g, '\n\n'));
console.log(`fonts: kept ${kept} of ${total} slices, ${used.size} code points`);
