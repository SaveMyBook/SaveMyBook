// 產生海報共用的向量素材，並輸出 Logo 交付檔。
//   node tools/build-assets.mjs
// 1. src/assets/logo.svg      由 介紹動畫/v2/src/lib/logo.ts 的路徑原樣轉出（動畫最終畫面：填色、書頁、書背、書籤、疊層陰影）
// 2. src/assets/qr-site.svg   https://savemybook.today/ 的 QR Code（ECC Q、4 模組留白、ink 深色、白底）
// 3. 成品/Logo與圖檔/115414－Logo.svg、115414－Logo.png（透明背景、長邊約 6000 px、300 dpi）
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';
import qrcode from 'qrcode-generator';
import jsQR from 'jsqr';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const LOGO_TS = join(ROOT, '..', '介紹動畫', 'v2', 'src', 'lib', 'logo.ts');
const OUT_ASSETS = join(ROOT, 'src', 'assets');
const OUT_DELIV = join(ROOT, '成品', 'Logo與圖檔');
mkdirSync(OUT_ASSETS, { recursive: true });
mkdirSync(OUT_DELIV, { recursive: true });

/* ---------- 1. Logo ---------- */
const ts = readFileSync(LOGO_TS, 'utf8');
const one = (re, what) => {
  const m = ts.match(re);
  if (!m) throw new Error(`logo.ts: 找不到 ${what}`);
  return m[1];
};
const pages = [...ts.matchAll(/\{ fill: '([^']+)', edge: '([^']+)' \}/g)].map((m) => ({ fill: m[1], edge: m[2] }));
if (pages.length !== 6) throw new Error(`logo.ts: 書頁數量應為 6，實得 ${pages.length}`);
const COVER = one(/const COVER = '([^']+)'/, 'COVER');
const BOOKMARK = one(/const BOOKMARK = '([^']+)'/, 'BOOKMARK');
const SPINE_X = one(/const SPINE_X = (\d+)/, 'SPINE_X');
const BRAND = one(/const BRAND = '([^']+)'/, 'BRAND');
const PAGE = one(/const PAGE = '([^']+)'/, 'PAGE');
const SPINE = `M${SPINE_X} 1612L${SPINE_X} 856`;

// 外框：封面 x 210–1830、書頁頂端約 y 378、疊層陰影最低約 y 1703；四周各留約 20 單位。
const VB = { x: 190, y: 358, w: 1660, h: 1366 };
const shadow = [8, 16, 24, 32, 40, 48, 56, 64]
  .map((dy) => `    <path d="${COVER}" fill="#46606F" fill-opacity="0.034" transform="translate(0 ${dy})"/>`)
  .join('\n');
const pageEls = pages
  .map((p) => `    <path d="${p.fill}" fill="${PAGE}"/>\n    <path d="${p.edge}" fill="none" stroke="${BRAND}" stroke-width="24" stroke-linejoin="round" stroke-linecap="round"/>`)
  .join('\n');
const logoSvg = `<?xml version="1.0" encoding="UTF-8"?>
<!-- 救「舊」我的書 Logo（向量）。路徑取自 presentation/介紹動畫/v2/src/lib/logo.ts，
     呈現動畫描繪完成後的最終畫面：疊層陰影 → 書頁（底色＋邊線）→ 封面漸層＋柔光 → 書背 → 書籤。 -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="${VB.x} ${VB.y} ${VB.w} ${VB.h}" width="${VB.w}" height="${VB.h}">
  <defs>
    <linearGradient id="smb-cover" x1="0.2" y1="0.25" x2="0.95" y2="1">
      <stop offset="0" stop-color="${BRAND}"/>
      <stop offset="0.45" stop-color="${BRAND}"/>
      <stop offset="1" stop-color="#98ABB7"/>
    </linearGradient>
    <radialGradient id="smb-glow" cx="1560" cy="1420" r="760" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.3"/>
      <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="smb-spine" x1="0" y1="856" x2="0" y2="1612" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#C9D3D9"/>
      <stop offset="1" stop-color="#B3C0C8"/>
    </linearGradient>
  </defs>
  <g id="shadow">
${shadow}
  </g>
  <g id="pages">
${pageEls}
  </g>
  <path id="cover" d="${COVER}" fill="url(#smb-cover)"/>
  <path id="cover-glow" d="${COVER}" fill="url(#smb-glow)"/>
  <path id="spine" d="${SPINE}" fill="none" stroke="url(#smb-spine)" stroke-width="34" stroke-linecap="round"/>
  <path id="bookmark" d="${BOOKMARK}" fill="#FFFFFF" fill-opacity="0.14" stroke="#FFFFFF" stroke-opacity="0.55" stroke-width="5" stroke-linejoin="round"/>
</svg>
`;
writeFileSync(join(OUT_ASSETS, 'logo.svg'), logoSvg);
writeFileSync(join(OUT_DELIV, '115414－Logo.svg'), logoSvg);

// PNG：長邊 6000 px，透明背景，寫入 300 dpi
const LONG = 6000;
const density = (72 * LONG) / Math.max(VB.w, VB.h);
const logoPng = join(OUT_DELIV, '115414－Logo.png');
const info = await sharp(Buffer.from(logoSvg), { density, limitInputPixels: false })
  .png({ compressionLevel: 9 })
  .withDensity(300)
  .toFile(logoPng);
// 檢查四周留白：確認沒有裁到圖形
const { info: tinfo } = await sharp(logoPng).trim({ threshold: 0 }).toBuffer({ resolveWithObject: true });
const meta = await sharp(logoPng).metadata();
console.log(`Logo PNG ${info.width}×${info.height}，density ${meta.density} dpi，alpha=${meta.hasAlpha}`);
console.log(`  圖形外框 ${tinfo.width}×${tinfo.height}，左 ${-tinfo.trimOffsetLeft}、上 ${-tinfo.trimOffsetTop}、右 ${info.width - tinfo.width + tinfo.trimOffsetLeft}、下 ${info.height - tinfo.height + tinfo.trimOffsetTop} px 留白`);

/* ---------- 2. QR Code ---------- */
const URL_SITE = 'https://savemybook.today/';
const qr = qrcode(0, 'Q');
qr.addData(URL_SITE, 'Byte');
qr.make();
const n = qr.getModuleCount();
const QZ = 4;
const size = n + QZ * 2;
let d = '';
for (let r = 0; r < n; r++) {
  let c = 0;
  while (c < n) {
    if (!qr.isDark(r, c)) { c++; continue; }
    const c0 = c;
    while (c < n && qr.isDark(r, c)) c++;
    d += `M${c0 + QZ} ${r + QZ}h${c - c0}v1h-${c - c0}z`;
  }
}
const qrSvg = `<?xml version="1.0" encoding="UTF-8"?>
<!-- ${URL_SITE} · QR version ${(n - 17) / 4} · ECC Q · quiet zone ${QZ} modules -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${size} ${size}" width="${size * 10}" height="${size * 10}" shape-rendering="crispEdges">
  <rect width="${size}" height="${size}" fill="#FFFFFF"/>
  <path d="${d}" fill="#16222B"/>
</svg>
`;
writeFileSync(join(OUT_ASSETS, 'qr-site.svg'), qrSvg);

// 驗證：點陣化後用 jsQR 解碼，內容必須與網址完全相同
const raw = await sharp(Buffer.from(qrSvg), { density: 72 * 4 }).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
const decoded = jsQR(new Uint8ClampedArray(raw.data), raw.info.width, raw.info.height);
if (!decoded || decoded.data !== URL_SITE) throw new Error(`QR 驗證失敗：${decoded ? JSON.stringify(decoded.data) : '無法解碼'}`);
console.log(`QR ${n}×${n} 模組（version ${(n - 17) / 4}，ECC Q），解碼內容 = ${JSON.stringify(decoded.data)} ✓`);
