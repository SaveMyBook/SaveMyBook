// 海報輸出工具：以本機 HTTP 伺服器＋Chrome（puppeteer-core）把 src/<name>.html 輸出成 PDF／PNG／預覽圖。
//
//   node tools/render.mjs <poster-html-name> [--bleed|--trim|--both] [--pdf] [--png] [--preview] [--guides] [--dpi 300]
//
//   <poster-html-name>  src/ 底下的檔名（不含 .html），例：poster1
//   --bleed | --trim | --both   含出血版、不含出血版或兩者（預設 --both）
//   --pdf       成品/含出血|不含出血/115414－海報N.pdf（文字向量、字型內嵌，單頁，紙張＝@page 尺寸）
//   --png       成品/含出血|不含出血/115414－海報N.png（預設 300 dpi，分塊截圖再以 sharp 拼接，寫入 dpi）
//   --preview   預覽/<name>-bleed.jpg、<name>-trim.jpg（長邊 1600 px）
//   --guides    預覽圖另外輸出一張疊上完成線／內容範圍的版本（<name>-bleed-guides.jpg）
//   --dpi N     PNG 解析度（預設 300）
//   未指定 --pdf/--png/--preview 時三者都做。
//
// 輸出前會檢查：所有文字實際使用的字型（必須是內嵌的 Noto Sans TC / IBM Plex Mono，不可是系統替代字型）、
// 內容是否超出 .safe 範圍；輸出後檢查 PDF 頁數與紙張尺寸、內嵌字型，PNG 像素與 dpi。
import { createServer } from 'node:http';
import { createReadStream, existsSync, mkdirSync, readFileSync, renameSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { dirname, extname, join, normalize, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer-core';
import sharp from 'sharp';
import { PDFDocument, PDFDict, PDFName, PDFRawStream } from 'pdf-lib';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const CHROME = process.env.CHROME_PATH || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const GROUP = '115414';
const TILE_CSS = 2048; // 300 dpi 時一塊 6400 device px（≤ 8000）

/* ---------- 參數 ---------- */
const args = process.argv.slice(2);
const name = args.find((a) => !a.startsWith('--') && !/^\d+$/.test(a));
if (!name) {
  console.error('用法：node tools/render.mjs <poster-html-name> [--bleed|--trim|--both] [--pdf] [--png] [--preview] [--guides] [--dpi 300]');
  process.exit(1);
}
const has = (f) => args.includes(f);
const dpiIdx = args.indexOf('--dpi');
const DPI = dpiIdx >= 0 ? Number(args[dpiIdx + 1]) : 300;
let variants = has('--bleed') ? ['bleed'] : has('--trim') ? ['trim'] : ['bleed', 'trim'];
if (has('--both')) variants = ['bleed', 'trim'];
let doPdf = has('--pdf'), doPng = has('--png'), doPreview = has('--preview');
if (!doPdf && !doPng && !doPreview) doPdf = doPng = doPreview = true;
const num = (name.match(/(\d+)$/) || [])[1];
const outBase = num ? `${GROUP}－海報${num}` : `${GROUP}－${name}`;
const DIR = { bleed: join(ROOT, '成品', '含出血'), trim: join(ROOT, '成品', '不含出血') };
const PREVIEW_DIR = join(ROOT, '預覽');

/* ---------- 靜態伺服器（字型需經 http 載入） ---------- */
const TYPES = {
  '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json', '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp',
  '.ttf': 'font/ttf', '.otf': 'font/otf', '.woff': 'font/woff', '.woff2': 'font/woff2',
};
const server = createServer((req, res) => {
  const p = normalize(join(ROOT, decodeURIComponent(new URL(req.url, 'http://x').pathname)));
  if (!p.startsWith(ROOT + sep) || !existsSync(p) || !statSync(p).isFile()) { res.writeHead(404); res.end('not found'); return; }
  res.writeHead(200, { 'Content-Type': TYPES[extname(p).toLowerCase()] || 'application/octet-stream', 'Cache-Control': 'no-store' });
  createReadStream(p).pipe(res);
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const ORIGIN = `http://127.0.0.1:${server.address().port}`;

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: true,
  args: ['--hide-scrollbars', '--font-render-hinting=none', '--disable-lcd-text', '--force-color-profile=srgb'],
});

const cm = (mm) => (mm / 10).toFixed(1);
// Windows 上成品檔若正被看圖程式或防毒掃描開著，直接覆寫會失敗：先寫暫存檔，再重試改名取代
async function writeAtomic(file, buf) {
  const tmp = `${file}.tmp`;
  writeFileSync(tmp, buf);
  for (let i = 0; ; i++) {
    try { renameSync(tmp, file); return; } catch (e) {
      if (i >= 9) { rmSync(tmp, { force: true }); throw new Error(`無法寫入 ${file}（可能正被其他程式開啟）：${e.message}`); }
      await new Promise((r) => setTimeout(r, 1000));
    }
  }
}

const report = [];

async function open(variant, extra = '') {
  const page = await browser.newPage();
  page.on('console', (m) => { if (m.type() === 'error') console.warn('  [page]', m.text()); });
  page.on('pageerror', (e) => console.warn('  [pageerror]', e.message));
  await page.setViewport({ width: 1200, height: 800, deviceScaleFactor: 1 });
  const qs = [variant === 'trim' ? 'bleed=0' : '', extra].filter(Boolean).join('&');
  await page.goto(`${ORIGIN}/src/${name}.html${qs ? `?${qs}` : ''}`, { waitUntil: 'load' });
  await page.waitForFunction('window.__ready === true || !!window.__error', { timeout: 120000 });
  const err = await page.evaluate('window.__error');
  if (err) throw new Error(`頁面錯誤：${err}`);
  const pg = await page.evaluate('window.__page');
  const css = {
    w: await page.evaluate(() => document.querySelector('.sheet').getBoundingClientRect().width),
    h: await page.evaluate(() => document.querySelector('.sheet').getBoundingClientRect().height),
  };
  return { page, pg, css };
}

/** 檢查每個文字節點實際用到的字型（CDP CSS.getPlatformFontsForNode）。 */
async function checkFonts(page) {
  const cdp = await page.createCDPSession();
  await cdp.send('DOM.enable');
  await cdp.send('CSS.enable');
  const n = await page.evaluate(() => {
    let i = 0;
    for (const el of document.querySelectorAll('body *')) {
      if ([...el.childNodes].some((c) => c.nodeType === 3 && c.textContent.trim())) el.setAttribute('data-fc', String(i++));
    }
    return i;
  });
  const { root } = await cdp.send('DOM.getDocument', { depth: 0 });
  const { nodeIds } = await cdp.send('DOM.querySelectorAll', { nodeId: root.nodeId, selector: '[data-fc]' });
  const used = new Map();
  for (const id of nodeIds) {
    const { fonts } = await cdp.send('CSS.getPlatformFontsForNode', { nodeId: id });
    for (const f of fonts) {
      const k = `${f.familyName}${f.isCustomFont ? '' : '（系統字型）'}`;
      used.set(k, (used.get(k) || 0) + f.glyphCount);
    }
  }
  await page.evaluate(() => document.querySelectorAll('[data-fc]').forEach((e) => e.removeAttribute('data-fc')));
  await cdp.detach();
  const bad = [...used.keys()].filter((k) => k.includes('系統字型'));
  console.log(`  字型（${n} 個文字元素）：${[...used].map(([k, v]) => `${k} ${v} 字`).join('、')}`);
  if (bad.length) console.warn(`  ⚠ 有文字使用系統替代字型：${bad.join('、')}`);
  return { used: Object.fromEntries(used), bad };
}

/** 檢查 .safe 內所有元素（含陰影以外的實體外框）是否落在內容範圍內。 */
async function checkSafe(page) {
  return page.evaluate(() => {
    const safe = document.querySelector('.safe');
    if (!safe) return ['找不到 .safe'];
    const s = safe.getBoundingClientRect();
    const out = [];
    const eps = 0.5;
    for (const el of safe.querySelectorAll('*')) {
      const r = el.getBoundingClientRect();
      if (!r.width || !r.height) continue;
      if (r.left < s.left - eps || r.top < s.top - eps || r.right > s.right + eps || r.bottom > s.bottom + eps) {
        out.push(`${el.tagName.toLowerCase()}.${[...el.classList].join('.')} 超出 ${[s.left - r.left, s.top - r.top, r.right - s.right, r.bottom - s.bottom].map((v) => (v * 25.4 / 96).toFixed(1)).join('/')} mm（左/上/右/下）`);
      }
    }
    // 回報實際內容外框與 .safe 的距離（mm）
    let L = Infinity, T = Infinity, R = -Infinity, B = -Infinity;
    for (const el of safe.querySelectorAll('*')) {
      const r = el.getBoundingClientRect();
      if (!r.width || !r.height) continue;
      L = Math.min(L, r.left); T = Math.min(T, r.top); R = Math.max(R, r.right); B = Math.max(B, r.bottom);
    }
    const k = 25.4 / 96;
    window.__contentBox = { left: (L - s.left) * k, top: (T - s.top) * k, right: (s.right - R) * k, bottom: (s.bottom - B) * k };
    return out;
  });
}

async function verifyPdf(file, pg) {
  const bytes = readFileSync(file);
  const doc = await PDFDocument.load(bytes, { updateMetadata: false });
  const pages = doc.getPages();
  const { width, height } = pages[0].getSize();
  const wmm = (width / 72) * 25.4, hmm = (height / 72) * 25.4;
  const fonts = new Set();
  let images = 0, embedded = 0;
  for (const [, obj] of doc.context.enumerateIndirectObjects()) {
    const dict = obj instanceof PDFDict ? obj : obj instanceof PDFRawStream ? obj.dict : null;
    if (!dict) continue;
    const type = dict.get(PDFName.of('Type'));
    const sub = dict.get(PDFName.of('Subtype'));
    if (type && type.toString() === '/FontDescriptor') {
      fonts.add(String(dict.get(PDFName.of('FontName'))).replace(/^\/[A-Z]{6}\+/, '/'));
      if (dict.get(PDFName.of('FontFile2')) || dict.get(PDFName.of('FontFile3')) || dict.get(PDFName.of('FontFile'))) embedded++;
    }
    if (sub && sub.toString() === '/Image') images++;
  }
  const ok = pages.length === 1 && Math.abs(wmm - pg.w) < 0.01 && Math.abs(hmm - pg.h) < 0.01;
  const tb = pages[0].getTrimBox();
  console.log(`  PDF ${pages.length} 頁，${cm(wmm)} × ${cm(hmm)} cm（${wmm.toFixed(2)} × ${hmm.toFixed(2)} mm；TrimBox ${(tb.width / 72 * 25.4).toFixed(2)} × ${(tb.height / 72 * 25.4).toFixed(2)} mm）${ok ? '✓' : '✗ 與規格不符'}`);
  console.log(`      內嵌字型 ${embedded}/${fonts.size}：${[...fonts].join(' ')}；點陣影像 ${images} 個（陰影／柔光）`);
  if (!ok) process.exitCode = 1;
  return { pages: pages.length, wmm, hmm, fonts: [...fonts], embedded, images, ok, bytes: bytes.length };
}

/**
 * Chrome 會把紙張尺寸取整到 0.01 inch（誤差最多約 0.13mm）。
 * 做法：先以「無條件進位到 0.01 inch」的紙張輸出（內容貼齊左上角，不會被裁到），
 * 再用 pdf-lib 把 MediaBox 裁成精確尺寸，並寫入 TrimBox／BleedBox。
 */
async function renderPdf(variant, page, pg) {
  const file = join(DIR[variant], `${outBase}.pdf`);
  mkdirSync(DIR[variant], { recursive: true });
  const upIn = (mm) => Math.ceil((mm / 25.4) * 100 - 1e-6) / 100;
  const wIn = upIn(pg.w), hIn = upIn(pg.h);
  await page.evaluate((w, h) => {
    const st = document.createElement('style');
    st.id = '__pdfpage';
    st.textContent = `@page { size: ${w}in ${h}in; margin: 0; }`;
    document.head.append(st);
  }, wIn, hIn);
  const raw = await page.pdf({
    printBackground: true,
    preferCSSPageSize: false,
    width: `${wIn}in`,
    height: `${hIn}in`,
    margin: { top: 0, right: 0, bottom: 0, left: 0 },
    tagged: false,
    outline: false,
    timeout: 0,
  });
  await page.evaluate(() => document.getElementById('__pdfpage')?.remove());
  const doc = await PDFDocument.load(raw, { updateMetadata: false });
  const pt = (mm) => (mm / 25.4) * 72;
  const W = pt(pg.w), H = pt(pg.h), b = pt(pg.bleed);
  for (const p of doc.getPages()) {
    const top = p.getMediaBox().height;
    p.setMediaBox(0, top - H, W, H);
    p.setCropBox(0, top - H, W, H);
    p.setBleedBox(0, top - H, W, H);
    p.setTrimBox(b, top - H + b, W - 2 * b, H - 2 * b);
  }
  doc.setTitle(outBase);
  doc.setProducer('Chrome (Skia/PDF) + pdf-lib');
  writeFileSync(file, await doc.save());
  console.log(`  → ${file}`);
  return { file, ...(await verifyPdf(file, pg)) };
}

/** 分塊截圖：視窗固定為一塊大小，平移 .sheet 取得每一塊，再以 sharp 拼接。 */
async function capture(page, css, scale, tile = TILE_CSS) {
  const W = Math.round(css.w * scale), H = Math.round(css.h * scale);
  const tw = Math.min(tile, Math.ceil(css.w)), th = Math.min(tile, Math.ceil(css.h));
  await page.setViewport({ width: tw, height: th, deviceScaleFactor: scale });
  const tiles = [];
  for (let y = 0; y < css.h; y += th) {
    for (let x = 0; x < css.w; x += tw) {
      await page.evaluate((x, y) => {
        document.querySelector('.sheet').style.transform = `translate(${-x}px, ${-y}px)`;
        return new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
      }, x, y);
      const buf = await page.screenshot({ type: 'png', captureBeyondViewport: false, optimizeForSpeed: true });
      const left = Math.round(x * scale), top = Math.round(y * scale);
      const w = Math.min(Math.round(tw * scale), W - left), h = Math.min(Math.round(th * scale), H - top);
      if (w <= 0 || h <= 0) continue;
      const input = await sharp(buf, { limitInputPixels: false }).extract({ left: 0, top: 0, width: w, height: h }).removeAlpha().png({ compressionLevel: 0 }).toBuffer();
      tiles.push({ input, left, top });
    }
  }
  await page.evaluate(() => { document.querySelector('.sheet').style.transform = ''; });
  return { W, H, tiles };
}

async function renderPng(variant, page, pg, css) {
  const file = join(DIR[variant], `${outBase}.png`);
  mkdirSync(DIR[variant], { recursive: true });
  const scale = DPI / 96;
  // 每塊的 CSS 寬度取「乘上倍率後為整數裝置像素」的值，接縫才不會有細線；每塊 ≤ 8000 device px
  const gcd = (a, b) => (b ? gcd(b, a % b) : a);
  const step = 96 / gcd(DPI, 96);
  const tile = Math.max(step, Math.floor(Math.min(TILE_CSS, 8000 / scale) / step) * step);
  const { W, H, tiles } = await capture(page, css, scale, tile);
  // 目標像素＝紙張 mm 換算 dpi
  const tw = Math.round((pg.w / 25.4) * DPI), thh = Math.round((pg.h / 25.4) * DPI);
  let img = sharp({ create: { width: W, height: H, channels: 3, background: '#FFFFFF' }, limitInputPixels: false }).composite(tiles);
  if (W !== tw || H !== thh) {
    // 寬高與 mm 換算差 1 px 以內時裁切／補邊對齊
    const buf = await img.png({ compressionLevel: 0 }).toBuffer();
    img = sharp(buf, { limitInputPixels: false }).resize(tw, thh, { fit: 'fill' });
  }
  const buf = await img.png({ compressionLevel: 6, adaptiveFiltering: true }).withDensity(DPI).toBuffer();
  await writeAtomic(file, buf);
  const meta = await sharp(file, { limitInputPixels: false }).metadata();
  const st = statSync(file);
  console.log(`  → ${file}`);
  console.log(`  PNG ${meta.width} × ${meta.height} px，${meta.density} dpi（${cm(meta.width / DPI * 25.4)} × ${cm(meta.height / DPI * 25.4)} cm），${(st.size / 1048576).toFixed(1)} MB，${tiles.length} 塊拼接（原始 ${W}×${H}）`);
  return { file, width: meta.width, height: meta.height, density: meta.density, mb: +(st.size / 1048576).toFixed(1) };
}

async function renderPreview(variant, page, css, suffix = '') {
  mkdirSync(PREVIEW_DIR, { recursive: true });
  const scale = 1600 / Math.max(css.w, css.h);
  // 預覽的縮放倍率不是整數，分塊會在接縫留下細線，所以整張一次截取（裝置像素很小）
  const { W, H, tiles } = await capture(page, css, scale, Infinity);
  const file = join(PREVIEW_DIR, `${name}-${variant}${suffix}.jpg`);
  await sharp({ create: { width: W, height: H, channels: 3, background: '#FFFFFF' } }).composite(tiles).jpeg({ quality: 90 }).toFile(file);
  console.log(`  預覽 → ${file}（${W}×${H}）`);
  return file;
}

try {
  for (const variant of variants) {
    console.log(`\n[${name} · ${variant === 'bleed' ? '含出血' : '不含出血'}]`);
    const { page, pg, css } = await open(variant);
    console.log(`  紙張 ${cm(pg.w)} × ${cm(pg.h)} cm（完成 ${cm(pg.trimW)} × ${cm(pg.trimH)} cm，出血 ${pg.bleed} mm）`);
    const fonts = await checkFonts(page);
    const outside = await checkSafe(page);
    const box = await page.evaluate('window.__contentBox');
    if (box) console.log(`  內容外框距 .safe 邊：左 ${box.left.toFixed(1)}、上 ${box.top.toFixed(1)}、右 ${box.right.toFixed(1)}、下 ${box.bottom.toFixed(1)} mm`);
    if (outside.length) { console.warn(`  ⚠ 超出內容範圍：\n    ${outside.join('\n    ')}`); process.exitCode = 1; }
    else console.log('  內容皆在內容範圍內 ✓');
    const r = { variant, page: pg, fonts, outside };
    if (doPdf) r.pdf = await renderPdf(variant, page, pg);
    if (doPng) r.png = await renderPng(variant, page, pg, css);
    if (doPreview) r.preview = await renderPreview(variant, page, css);
    await page.close();
    if (doPreview && has('--guides')) {
      const g = await open(variant, 'guides=1');
      r.previewGuides = await renderPreview(variant, g.page, g.css, '-guides');
      await g.page.close();
    }
    report.push(r);
  }
} finally {
  await browser.close();
  server.close();
}
