// GIF 編碼：全片共用調色盤，後一格與畫面上已顯示的顏色相差不超過 threshold 的像素改為透明（沿用前一格），
// 只輸出有變動的矩形。旋轉物體每格都在動，單靠完全相同才透明的做法（ffmpeg 預設）檔案會大好幾倍。
import { writeFileSync } from 'node:fs';

/**
 * frames：同尺寸的 RGB 原始像素（Buffer，每像素 3 bytes）。
 * palette：最多 255 色 [[r,g,b], ...]；透明色用調色盤之後的下一個索引（127 色時 LZW 碼長 7 位元，檔案較小）。
 */
const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5].map((v) => (v + 0.5) / 16 - 0.5);

/**
 * lightDither：只在淺灰色（背景的柔和陰影）加固定位置的有序抖色，消除漸層色階；
 * 背景不隨板子轉動，抖色圖樣每格相同，只在第一格花費容量。
 */
export function encodeGif(file, { width, height, frames, palette, delayCs, threshold = 0, lightDither = 0 }) {
  const pal = palette.slice(0, 255);
  const bitsN = Math.max(2, Math.ceil(Math.log2(pal.length + 1)));
  const tableN = 1 << bitsN;
  const P = new Uint8Array(tableN * 3);
  pal.forEach(([r, g, b], i) => { P[i * 3] = r; P[i * 3 + 1] = g; P[i * 3 + 2] = b; });
  const TRANS = pal.length;
  // 最近色查表（每色 6 bits）
  const cache = new Int16Array(1 << 18).fill(-1);
  const nearest = (r, g, b) => {
    const key = ((r >> 2) << 12) | ((g >> 2) << 6) | (b >> 2);
    let v = cache[key];
    if (v >= 0) return v;
    let best = 0, bd = Infinity;
    for (let i = 0; i < pal.length; i++) {
      const dr = r - P[i * 3], dg = g - P[i * 3 + 1], db = b - P[i * 3 + 2];
      const d = 2 * dr * dr + 4 * dg * dg + 3 * db * db;
      if (d < bd) { bd = d; best = i; }
    }
    cache[key] = best;
    return best;
  };

  const out = [];
  const push = (...bytes) => { for (const b of bytes) out.push(b); };
  const u16 = (n) => push(n & 255, (n >> 8) & 255);
  push(...Buffer.from('GIF89a'));
  u16(width); u16(height);
  push(0xf0 | ((bitsN - 1) << 4 & 0x70) | (bitsN - 1), 0, 0);
  for (let i = 0; i < tableN * 3; i++) out.push(P[i]);
  push(0x21, 0xff, 0x0b, ...Buffer.from('NETSCAPE2.0'), 0x03, 0x01, 0, 0, 0);

  const n = width * height;
  const shown = new Uint8Array(n * 3);
  const idx = new Uint8Array(n);
  frames.forEach((rgb, f) => {
    let x0 = width, y0 = height, x1 = -1, y1 = -1;
    for (let p = 0; p < n; p++) {
      const r = rgb[p * 3], g = rgb[p * 3 + 1], b = rgb[p * 3 + 2];
      let c;
      if (lightDither > 0 && r + g + b > 450 && Math.max(r, g, b) - Math.min(r, g, b) < 16) {
        const o = BAYER[((p / width | 0) & 3) * 4 + (p % width & 3)] * lightDither;
        const cl = (v) => Math.max(0, Math.min(255, Math.round(v + o)));
        c = nearest(cl(r), cl(g), cl(b));
      } else c = nearest(r, g, b);
      if (f > 0) {
        const sr = shown[p * 3], sg = shown[p * 3 + 1], sb = shown[p * 3 + 2];
        const same = (P[c * 3] === sr && P[c * 3 + 1] === sg && P[c * 3 + 2] === sb)
          || (Math.abs(r - sr) <= threshold && Math.abs(g - sg) <= threshold && Math.abs(b - sb) <= threshold);
        if (same) { idx[p] = TRANS; continue; }
      }
      idx[p] = c;
      shown[p * 3] = P[c * 3]; shown[p * 3 + 1] = P[c * 3 + 1]; shown[p * 3 + 2] = P[c * 3 + 2];
      const x = p % width, y = (p / width) | 0;
      if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y;
    }
    if (x1 < 0) { x0 = 0; y0 = 0; x1 = 0; y1 = 0; idx[0] = TRANS; }
    const w = x1 - x0 + 1, h = y1 - y0 + 1;
    const sub = new Uint8Array(w * h);
    for (let y = 0; y < h; y++) sub.set(idx.subarray((y0 + y) * width + x0, (y0 + y) * width + x0 + w), y * w);
    push(0x21, 0xf9, 0x04, (1 << 2) | (f > 0 ? 1 : 0));
    u16(delayCs);
    push(TRANS, 0);
    push(0x2c); u16(x0); u16(y0); u16(w); u16(h); push(0);
    lzw(sub, bitsN, out);
  });
  push(0x3b);
  const buf = Buffer.from(out);
  writeFileSync(file, buf);
  return buf.length;
}

const stamp = new Int32Array(1 << 20);
const val = new Int16Array(1 << 20);
let gen = 0;

/** GIF 版 LZW（同 omggif 的寫法），輸出含最小碼長與 255 bytes 分段。 */
function lzw(index, minCode, out) {
  out.push(minCode);
  const bytes = [];
  const clear = 1 << minCode, eoi = clear + 1;
  let next = eoi + 1, size = minCode + 1, cur = 0, shift = 0;
  const emit = (code) => {
    cur |= code << shift;
    shift += size;
    while (shift >= 8) { bytes.push(cur & 255); cur >>>= 8; shift -= 8; }
  };
  gen++;
  emit(clear);
  let ib = index[0];
  for (let i = 1; i < index.length; i++) {
    const k = index[i];
    const key = (ib << 8) | k;
    if (stamp[key] === gen) { ib = val[key]; continue; }
    emit(ib);
    if (next === 4096) {
      emit(clear);
      next = eoi + 1;
      size = minCode + 1;
      gen++;
    } else {
      if (next >= (1 << size)) size++;
      stamp[key] = gen;
      val[key] = next++;
    }
    ib = k;
  }
  emit(ib);
  emit(eoi);
  if (shift > 0) bytes.push(cur & 255);
  for (let i = 0; i < bytes.length; i += 255) {
    const len = Math.min(255, bytes.length - i);
    out.push(len);
    for (let j = 0; j < len; j++) out.push(bytes[i + j]);
  }
  out.push(0);
}
