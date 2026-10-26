import { CUTS, type Scr } from '../world';
import { loadImage } from '../three/textures';
import { soft } from '../tour/kit4';
import { V3 } from './spec';

/**
 * 浮出：每句旁白只浮出一個元素。元素用 cuts.json 的去背元件（照元素本身的邊界與圓角），朝鏡頭浮起並放大，
 * 原位留下空位（周圍顏色的中位數加內陰影，比照 NTUB assemblePop），完全浮出至少停 1.5 秒再落回。
 */

/** 浮出程度：t0 起 0.5 秒浮出，t1 起 0.35 秒落回。完全浮出不足 1.5 秒時在主控台報錯（檢查工具會抓到）。 */
export function lift(t: number, t0: number, t1: number) {
  if (t1 - (t0 + V3.pop.rise) < V3.pop.hold - 1e-6 && !warned.has(`${t0}`)) {
    warned.add(`${t0}`);
    console.error(`浮出停留不足 ${V3.pop.hold} 秒：${t0.toFixed(2)}–${t1.toFixed(2)}`);
  }
  return soft(t, t0, t0 + V3.pop.rise) * (1 - soft(t, t1, t1 + V3.pop.fall));
}
const warned = new Set<string>();

const slots = new Map<string, string>();

/** 去背元件在原畫面上的周圍顏色（中位數），作為空位的底色；需先 preloadSlots。 */
export function slotColor(cut: string, fallback = '#F3F5F7') {
  return slots.get(cut) ?? fallback;
}

/** 由原畫面量出空位顏色：元件外 5pt 的上下左右與兩個角落，共六點取中位數。 */
export async function preloadSlots(cuts: string[]) {
  for (const name of cuts) {
    const r = CUTS[name];
    if (!r || slots.has(name)) continue;
    try {
      const img = await loadImage(`/v2/screens/${r.screen}.webp`);
      const k = img.width / 393;
      const c = document.createElement('canvas');
      c.width = img.width;
      c.height = img.height;
      const g = c.getContext('2d', { willReadFrequently: true })!;
      g.drawImage(img, 0, 0);
      const pts = [[r.x - 5, r.y + r.h / 2], [r.x + r.w + 5, r.y + r.h / 2], [r.x + r.w / 2, r.y - 5], [r.x + r.w / 2, r.y + r.h + 5], [r.x - 5, r.y + 8], [r.x + r.w + 5, r.y + r.h - 8]];
      const px = pts.map(([x, y]) => g.getImageData(Math.min(c.width - 1, Math.max(0, Math.round(x * k))), Math.min(c.height - 1, Math.max(0, Math.round(y * k))), 1, 1).data);
      const med = [0, 1, 2].map((i) => px.map((p) => p[i]).sort((a, b) => a - b)[3]);
      slots.set(name, `#${med.map((v) => v.toString(16).padStart(2, '0')).join('')}`);
    } catch { /* 量不到時用預設底色 */ }
  }
}

/**
 * 對話框類的浮出：對話框浮起後，原位不留單色空位，而是顯示對話框後方的頁面（加上同一層半透明遮罩）。
 * page 為 tools/under.py 產生的「<畫面>_under」截圖；k 為浮出程度，浮起的瞬間卡片仍蓋在原位，換畫面看不出來。
 */
export function under(scr: Scr, k: number, page: string): Scr {
  return k > 0.001 ? { a: page } : scr;
}

/** 浮出元件完全浮出後的輕微漂浮（比照 NTUB 的 fy／fz）：回傳要加到 dx、dy、dz 的量（App 邏輯 pt、公分），k 為浮出程度。 */
export function float(t: number, k: number, seed = 0) {
  const w = Math.max(0, Math.min(1, k)) ** 2;
  return { dx: Math.sin(t * 0.9 + seed) * 2.5 * w, dy: Math.sin(t * 1.7 + seed) * 3.5 * w, dz: Math.sin(t * 1.3 + 1 + seed) * 0.12 * w };
}
