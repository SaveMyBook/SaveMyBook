// 依網站實際用到的字，從 fontsource 的分片中挑出需要的 woff2，再把每片裁到只剩用到的字，
// 輸出到 src/styles/fonts/ 並寫成 src/styles/fonts.css。
// 改了頁面文字或程式中的字串後要重跑（npm run fonts，build 前會自動執行）。
import { mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import subsetFont from 'subset-font';

const web = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const outDir = join(web, 'src/styles/fonts');

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

const hex = (c) => c.toString(16).toUpperCase();

const FONTS = [
  ['noto-serif-tc', [700, 900]],
  ['noto-sans-tc', [400, 500, 700]],
  ['ibm-plex-mono', [400, 500]],
];

rmSync(outDir, { recursive: true, force: true });
mkdirSync(outDir, { recursive: true });

let css = '/* 由 scripts/fonts.mjs 產生，請勿手動修改 */\n';
let kept = 0, total = 0, bytes = 0;
for (const [pkg, weights] of FONTS) {
  for (const w of weights) {
    const src = readFileSync(join(web, 'node_modules/@fontsource', pkg, `${w}.css`), 'utf8');
    for (const block of src.split('@font-face').slice(1)) {
      total++;
      const range = /unicode-range:\s*([^;]+);/.exec(block)?.[1];
      const spans = range ? ranges(range) : [[0, 0x10ffff]];
      const hits = [...used].filter((c) => spans.some(([a, b]) => c >= a && c <= b)).sort((a, b) => a - b);
      if (!hits.length) continue;
      kept++;
      const file = /url\(\.\/files\/([^)]+\.woff2)\)/.exec(block)[1];
      const font = await subsetFont(readFileSync(join(web, 'node_modules/@fontsource', pkg, 'files', file)), String.fromCodePoint(...hits), { targetFormat: 'woff2' });
      writeFileSync(join(outDir, file), font);
      bytes += font.length;
      const family = /font-family:\s*([^;]+);/.exec(block)[1];
      css += `@font-face {
  font-family: ${family};
  font-style: normal;
  font-display: swap;
  font-weight: ${w};
  src: url('./fonts/${file}') format('woff2');
  unicode-range: ${hits.map((c) => `U+${hex(c)}`).join(', ')};
}
`;
    }
  }
}
writeFileSync(join(web, 'src/styles/fonts.css'), css);
console.log(`fonts: kept ${kept} of ${total} slices, ${used.size} code points, ${(bytes / 1024).toFixed(0)} KB`);
