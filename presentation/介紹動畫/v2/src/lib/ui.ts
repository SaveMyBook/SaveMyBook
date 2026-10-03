import { clamp, span, easeOut } from './kf';

/** 全片字級（1920×1080 畫面上的實際像素）；同類文字一律取用這裡。 */
export const TY = { display: 132, headline: 80, number: 150, sub: 32, label: 30, note: 26, meta: 22 };

export const C = {
  ink: '#16222B',
  deep: '#2F4552',
  slate: '#627D8D',
  muted: '#5B6770',
  soft: '#E8ECEF',
  card: '#FFFFFF',
  success: '#2E9E5B',
  danger: '#D64545',
};

const cache = new WeakMap<HTMLElement, Record<string, string>>();
/** 只在值改變時寫入 style。 */
export function css(el: HTMLElement, prop: string, value: string) {
  let c = cache.get(el);
  if (!c) cache.set(el, (c = {}));
  if (c[prop] === value) return;
  c[prop] = value;
  el.style.setProperty(prop, value);
}

export function el<K extends keyof HTMLElementTagNameMap>(tag: K, cls: string, parent: HTMLElement, html = '') {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (html) e.innerHTML = html;
  parent.append(e);
  return e;
}

/** 以畫面中心為原點放置：x、y 為 1920×1080 的像素座標。 */
export function place(e: HTMLElement, x: number, y: number, extra = '') {
  css(e, 'transform', `translate(${x.toFixed(1)}px, ${y.toFixed(1)}px) translate(-50%, -50%)${extra}`);
}

/**
 * 逐字由遮罩內滑入的標題；進場後固定不動，確保好讀。
 * at(t, t0, t1)：t0 開始進場，t1 開始退場（往上滑出遮罩）。
 */
export class Rise {
  readonly root: HTMLElement;
  private chars: HTMLElement[] = [];
  constructor(parent: HTMLElement, text: string, cls: string) {
    this.root = el('div', `rise ${cls}`, parent);
    const line = el('span', 'rise__line', this.root);
    for (const ch of text) {
      const s = el('span', ch === ' ' ? 'rise__sp' : 'rise__ch', line);
      s.textContent = ch;
      if (ch !== ' ') this.chars.push(s);
    }
  }

  at(t: number, t0: number, t1 = Infinity, stagger = 0.022) {
    const n = this.chars.length;
    css(this.root, 'visibility', t < t0 - 0.01 || t > t1 + 0.45 + n * 0.01 ? 'hidden' : 'visible');
    this.chars.forEach((c, i) => {
      const a = easeOut(span(t, t0 + i * stagger, t0 + i * stagger + 0.6));
      const b = span(t, t1 + i * 0.01, t1 + i * 0.01 + 0.35);
      const y = (1 - a) * 105 - b * b * 105;
      css(c, 'transform', `translateY(${y.toFixed(2)}%)`);
      const blur = (1 - span(t, t0 + i * stagger, t0 + i * stagger + 0.22)) * 3;
      css(c, 'filter', blur > 0.05 && a > 0 ? `blur(${blur.toFixed(2)}px)` : 'none');
    });
  }
}

/** 帶模糊的淡入上浮、淡出上移。 */
export function fade(e: HTMLElement, t: number, t0: number, t1 = Infinity, dy = 24, dyOut = dy) {
  const a = easeOut(span(t, t0, t0 + 0.7));
  const b = span(t, t1, t1 + 0.4);
  css(e, 'opacity', (a * (1 - b)).toFixed(3));
  css(e, 'translate', `0 ${((1 - a) * dy - b * dyOut).toFixed(2)}px`);
  const blur = (1 - span(t, t0, t0 + 0.25)) * 3 + b * 3;
  css(e, 'filter', blur > 0.05 ? `blur(${blur.toFixed(2)}px)` : 'none');
  css(e, 'visibility', a * (1 - b) <= 0.001 ? 'hidden' : 'visible');
}

/** 數字滾動顯示。 */
export function number(e: HTMLElement, v: number, dec = 0, sep = false) {
  const s = v.toFixed(dec);
  const txt = sep ? Number(s).toLocaleString('en-US', { minimumFractionDigits: dec, maximumFractionDigits: dec }) : s;
  if (e.textContent !== txt) e.textContent = txt;
}
