/**
 * 系統簡介影片的版面語言（與介紹動畫 v2 區隔）：
 * - 右上角章節導覽列（ChapterNav）全片常駐，標出目前所在章節。
 * - 每章左側是章節標題（ChapterHead）與功能清單（FeatureList）：旁白講到哪一項，那一項展開成白色卡片，講過的收合變淡並打勾。
 * - 右側一支 3D 手機（略朝左轉）展示 App 畫面；重點區塊以放大鏡（Lens）從手機「拉出來」放大，不推近手機。
 * - 畫面下方 y > 930 保留給字幕，任何元素不得進入。
 */
import { span, clamp, easeOut, easeInOut, lerp, type Pose } from '../lib/kf';
import { el, css, place, Rise, fade } from '../lib/ui';
import { cue } from '../lib/cues';
import TL from '../timeline.json';
import type { World } from '../world';
import type { Rect } from '../scenes/kit';

/** 字幕安全區：此高度以下不放任何畫面元素。 */
export const SAFE_BOTTOM = 930;

/** 章節（右上角導覽列的順序與名稱）。open、end 不顯示在導覽列。 */
export const CHAPTERS: { id: string; name: string; en: string }[] = [
  { id: 'overview', name: '系統總覽', en: 'OVERVIEW' },
  { id: 'list', name: '賣家上架', en: 'LISTING' },
  { id: 'find', name: '買家找書', en: 'DISCOVERY' },
  { id: 'pay', name: '付款暫管', en: 'ESCROW' },
  { id: 'cabinet', name: '智慧書櫃', en: 'SMART CABINET' },
  { id: 'after', name: '驗收售後', en: 'AFTER-SALES' },
  { id: 'account', name: '帳號會員', en: 'ACCOUNT' },
  { id: 'admin', name: '管理後台', en: 'ADMIN' },
  { id: 'tech', name: '技術架構', en: 'TECHNOLOGY' },
];
export const chapterNo = (id: string) => CHAPTERS.findIndex((c) => c.id === id) + 1;

type Sec = { id: string; start: number; end: number };
const SECS = TL.sections as Sec[];
export const section = (id: string) => SECS.find((s) => s.id === id)!;
type Line = { id: string; sec: string; at: number; dur: number; text: string };
const LINES = TL.lines as Line[];
/** 旁白句在所屬段落內的開始秒數與長度。 */
export function line(id: string) {
  const l = LINES.find((x) => x.id === id);
  if (!l) throw new Error(`timeline 沒有 ${id}`);
  return { at: l.at, dur: l.dur, end: l.at + l.dur };
}

/* ─────────────── 圖示（24×24 線條，與 App 線條圖示同風格） ─────────────── */
const P: Record<string, string> = {
  barcode: '<path d="M4 6v12M7 6v12M10 6v12M14 6v12M17 6v12M20 6v12M8.5 6v12M15.5 6v12" stroke-width="1.3"/>',
  camera: '<path d="M4 8h3l2-2.5h6L17 8h3v11H4z"/><circle cx="12" cy="13.2" r="3.6"/>',
  shield: '<path d="M12 3l7.5 3v5.5c0 4.6-3.1 8.3-7.5 9.5-4.4-1.2-7.5-4.9-7.5-9.5V6z"/><path d="M8.6 12.2l2.4 2.4 4.6-4.8"/>',
  search: '<circle cx="10.5" cy="10.5" r="6"/><path d="M15 15l5 5"/>',
  sparkle: '<path d="M12 3.5l1.9 5.1 5.1 1.9-5.1 1.9L12 17.5l-1.9-5.1L5 10.5l5.1-1.9z"/><path d="M18.5 15.5l.8 2 2 .8-2 .8-.8 2-.8-2-2-.8 2-.8z"/>',
  chat: '<path d="M4 5.5h16v10H10l-4.5 3.5v-3.5H4z"/><path d="M8 9.5h8M8 12.3h5"/>',
  alert: '<path d="M12 4l9 15.5H3z"/><path d="M12 10v4.2M12 16.8v.4"/>',
  lock: '<rect x="5" y="10.5" width="14" height="10" rx="2"/><path d="M8 10.5V8a4 4 0 018 0v2.5"/><path d="M12 14.5v2.2"/>',
  finger: '<path d="M12 4.5a6.5 6.5 0 00-6.5 6.5v2M18.5 11a6.5 6.5 0 00-2.4-5M9 19.5c.7-1.5 1-3.3 1-5.5v-2.6a2 2 0 014 0V14c0 2.8-.5 5-1.6 6.8M16.8 18c.5-1.4.7-2.8.7-4.2V12"/>',
  coin: '<ellipse cx="12" cy="7" rx="7" ry="3"/><path d="M5 7v5c0 1.7 3.1 3 7 3s7-1.3 7-3V7M5 12v5c0 1.7 3.1 3 7 3s7-1.3 7-3v-5"/>',
  cabinet: '<rect x="5" y="3.5" width="14" height="17" rx="1.2"/><path d="M5 9.2h14M5 14.8h14M12 3.5v17"/><path d="M15.5 6.3h1.5"/>',
  chip: '<rect x="7" y="7" width="10" height="10" rx="1.2"/><path d="M10 4v3M14 4v3M10 17v3M14 17v3M4 10h3M4 14h3M17 10h3M17 14h3"/>',
  qr: '<path d="M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4z"/><path d="M14 14h2.5v2.5H14zM17.5 17.5H20V20h-2.5zM14 19v1M19 14h1"/>',
  pin: '<path d="M12 21s-6.5-6.2-6.5-11a6.5 6.5 0 0113 0c0 4.8-6.5 11-6.5 11z"/><circle cx="12" cy="10" r="2.4"/>',
  keypad: '<rect x="4.5" y="3.5" width="15" height="17" rx="2"/><path d="M8.5 8h.01M12 8h.01M15.5 8h.01M8.5 11.5h.01M12 11.5h.01M15.5 11.5h.01M8.5 15h.01M12 15h.01M15.5 15h.01" stroke-width="2.4"/>',
  door: '<path d="M6 20.5V4.5a1 1 0 011-1h10a1 1 0 011 1v16"/><path d="M4 20.5h16M14.5 12.5h.01" stroke-width="1.6"/>',
  bell: '<path d="M6 16.5V11a6 6 0 0112 0v5.5l1.5 2h-15z"/><path d="M10 20.5a2.2 2.2 0 004 0"/>',
  bus: '<rect x="5" y="3.5" width="14" height="14" rx="2.5"/><path d="M5 11h14M8 17.5V20M16 17.5V20"/><path d="M8.5 14.3h.01M15.5 14.3h.01" stroke-width="2.4"/>',
  check: '<circle cx="12" cy="12" r="8.5"/><path d="M8.3 12.3l2.6 2.6 5-5.3"/>',
  scale: '<path d="M12 4v16M7 20h10M5 7.5h14"/><path d="M5 7.5l-2.5 6h5zM19 7.5l-2.5 6h5z"/>',
  headset: '<path d="M4.5 14v-2a7.5 7.5 0 0115 0v2"/><rect x="3.5" y="13" width="4" height="6" rx="1.4"/><rect x="16.5" y="13" width="4" height="6" rx="1.4"/><path d="M18.5 19c0 1.2-1.6 2-3.5 2h-2"/>',
  key: '<circle cx="8" cy="15" r="4"/><path d="M11 12.2L19.5 4M16 7.5l2.5 2.5M14 9.5l2 2"/>',
  user: '<circle cx="12" cy="8.5" r="4"/><path d="M4.5 20.5c1-3.9 4-6 7.5-6s6.5 2.1 7.5 6"/>',
  medal: '<circle cx="12" cy="14.5" r="5.5"/><path d="M9 4h6l-1.5 5.3M9 4l1.5 5.3"/><path d="M12 12v5M10.2 13.4l1.8-1.4" stroke-width="1.4"/>',
  globe: '<circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17M12 3.5c2.5 2.6 3.6 5.4 3.6 8.5s-1.1 5.9-3.6 8.5c-2.5-2.6-3.6-5.4-3.6-8.5S9.5 6.1 12 3.5z"/>',
  moon: '<path d="M19.5 14.5A7.5 7.5 0 019.5 4.5a7.5 7.5 0 1010 10z"/>',
  dash: '<rect x="3.5" y="4.5" width="17" height="15" rx="2"/><path d="M3.5 9h17M9 9v10.5"/>',
  link: '<path d="M10 14a4 4 0 005.7 0l3-3a4 4 0 00-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 00-5.7 0l-3 3a4 4 0 005.7 5.7l1-1"/>',
  server: '<rect x="4" y="4" width="16" height="7" rx="1.5"/><rect x="4" y="13" width="16" height="7" rx="1.5"/><path d="M7.5 7.5h.01M7.5 16.5h.01" stroke-width="2.4"/>',
  flask: '<path d="M9.5 3.5h5M10.5 3.5v6L5 19a1.2 1.2 0 001 1.5h12a1.2 1.2 0 001-1.5l-5.5-9.5v-6"/><path d="M7.5 15h9"/>',
  phone: '<rect x="6.5" y="3" width="11" height="18" rx="2.2"/><path d="M10.5 18h3"/>',
  doc: '<path d="M6 3.5h8l4 4v13H6z"/><path d="M14 3.5v4h4M9 12h6M9 15.5h6"/>',
  book: '<path d="M4 5.5c2.8-1 5.5-.8 8 .8 2.5-1.6 5.2-1.8 8-.8v13c-2.8-1-5.5-.8-8 .8-2.5-1.6-5.2-1.8-8-.8z"/><path d="M12 6.3v13"/>',
};
export function icon(name: string, size = 36) {
  return `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">${P[name] ?? ''}</svg>`;
}

/* ─────────────── 右上角章節導覽列 ─────────────── */

/** 右上角的章節導覽：目前章節變深色加粗，下方石板藍短條滑到目前章節；片頭與片尾隱藏。 */
export class ChapterNav {
  private root: HTMLElement;
  private items: HTMLElement[];
  private bar: HTMLElement;
  private x0: number[] = [];
  private w: number[] = [];
  constructor(parent: HTMLElement) {
    this.root = el('div', 'cnav', parent);
    this.items = CHAPTERS.map((c, i) => el('span', 'cnav__item', this.root, `<i>${String(i + 1).padStart(2, '0')}</i>${c.name}`));
    this.bar = el('b', 'cnav__bar', this.root);
  }
  /** 量測各項位置（字型載入後呼叫一次）。 */
  private measure() {
    if (this.x0.length) return;
    const base = this.root.getBoundingClientRect().left;
    const scale = this.root.getBoundingClientRect().width / this.root.offsetWidth || 1;
    for (const it of this.items) {
      const r = it.getBoundingClientRect();
      this.x0.push((r.left - base) / scale);
      this.w.push(r.width / scale);
    }
  }
  at(t: number) {
    const first = section(CHAPTERS[0].id).start;
    const last = section(CHAPTERS[CHAPTERS.length - 1].id).end;
    const a = easeOut(span(t, first - 0.2, first + 0.6));
    const b = easeInOut(span(t, last - 0.3, last + 0.3));
    const k = a * (1 - b);
    css(this.root, 'visibility', k > 0.001 ? 'visible' : 'hidden');
    if (k <= 0.001) return;
    css(this.root, 'opacity', k.toFixed(3));
    this.measure();
    // 目前章節（以段落開始為界，轉場 0.6 秒內滑動）
    let pos = 0;
    CHAPTERS.forEach((c, i) => {
      const s = section(c.id).start;
      if (i > 0) pos += easeInOut(span(t, s - 0.2, s + 0.5));
    });
    const i0 = Math.floor(pos), f = pos - i0;
    const i1 = Math.min(CHAPTERS.length - 1, i0 + 1);
    const x = lerp(this.x0[i0], this.x0[i1], f), w = lerp(this.w[i0], this.w[i1], f);
    css(this.bar, 'transform', `translate(${x.toFixed(1)}px, 0) scaleX(${(w / 100).toFixed(4)})`);
    this.items.forEach((it, i) => {
      const on = clamp(1 - Math.abs(pos - i));
      css(it, 'color', on > 0.5 ? 'var(--ink)' : 'var(--muted)');
      css(it, 'opacity', (0.55 + 0.45 * on).toFixed(3));
      css(it, 'font-weight', on > 0.5 ? '700' : '500');
    });
  }
}

/* ─────────────── 章節標題 ─────────────── */

/** 左側章節標題：大號章節編號＋中文標題＋英文小標。 */
export class ChapterHead {
  private root: HTMLElement;
  private no: HTMLElement;
  private title: Rise;
  private en: HTMLElement;
  constructor(parent: HTMLElement, id: string, readonly x = 140, readonly y = 200) {
    const c = CHAPTERS.find((q) => q.id === id)!;
    this.root = el('div', 'chead', parent);
    this.no = el('p', 'chead__no', this.root, String(chapterNo(id)).padStart(2, '0'));
    this.title = new Rise(this.root, c.name, 'chead__title');
    this.en = el('p', 'chead__en', this.root, `CHAPTER ${String(chapterNo(id)).padStart(2, '0')} · ${c.en}`);
  }
  at(t: number, t0: number, t1: number) {
    const vis = t >= t0 - 0.05 && t <= t1 + 0.6;
    css(this.root, 'visibility', vis ? 'visible' : 'hidden');
    if (!vis) return;
    css(this.root, 'transform', `translate(${this.x}px, ${this.y}px)`);
    fade(this.no, t, t0, t1, 30);
    fade(this.en, t, t0 + 0.25, t1, 12);
    this.title.at(t, t0 + 0.1, t1);
  }
}

/* ─────────────── 功能清單 ─────────────── */

export interface Feature {
  /** 對應的旁白句 id：該句開始時展開。 */
  line: string;
  icon: string;
  title: string;
  body: string;
  /** 卡片內的小標籤（例如資料來源、數字）。 */
  chips?: string[];
  /** 提前或延後展開的秒數。 */
  shift?: number;
}

/** 左側功能清單：每項在對應旁白開始時以白色卡片展開；下一項開始後收合成一行、變淡並打勾。 */
export class FeatureList {
  private root: HTMLElement;
  private rows: { e: HTMLElement; body: HTMLElement; mark: HTMLElement; f: Feature; t0: number }[] = [];
  constructor(parent: HTMLElement, items: Feature[], readonly x = 140, readonly y = 360, readonly w = 700) {
    this.root = el('div', 'flist', parent);
    css(this.root, 'width', `${w}px`);
    for (const f of items) {
      const e = el('div', 'fitem', this.root);
      el('span', 'fitem__ico', e, icon(f.icon, 34));
      const txt = el('div', 'fitem__txt', e);
      el('p', 'fitem__title', txt, f.title);
      const body = el('div', 'fitem__body', txt, `<p>${f.body}</p>${f.chips?.length ? `<p class="fitem__chips">${f.chips.map((c) => `<span>${c}</span>`).join('')}</p>` : ''}`);
      const mark = el('span', 'fitem__mark', e, icon('check', 30));
      this.rows.push({ e, body, mark, f, t0: line(f.line).at + (f.shift ?? 0) });
      cue('select', line(f.line).at + (f.shift ?? 0) + 0.05, { gain: 0.55 });
    }
  }
  /** t1：整個清單退場的時間。 */
  at(t: number, t1: number) {
    const vis = t >= this.rows[0].t0 - 0.1 && t <= t1 + 0.6;
    css(this.root, 'visibility', vis ? 'visible' : 'hidden');
    if (!vis) return;
    css(this.root, 'transform', `translate(${this.x}px, ${this.y}px)`);
    const out = easeInOut(span(t, t1, t1 + 0.5));
    css(this.root, 'opacity', (1 - out).toFixed(3));
    this.rows.forEach((r, i) => {
      const next = this.rows[i + 1]?.t0 ?? 1e9;
      const a = easeOut(span(t, r.t0, r.t0 + 0.55));
      // 下一項開始時收合
      const c = easeInOut(span(t, next - 0.1, next + 0.45));
      const open = a * (1 - c);
      css(r.e, 'display', a <= 0.001 ? 'none' : '');
      css(r.e, 'opacity', (a * (1 - 0.5 * c)).toFixed(3));
      css(r.e, 'transform', `translateX(${((1 - a) * -40).toFixed(1)}px)`);
      css(r.e, '--open', open.toFixed(3));
      css(r.body, 'max-height', `${(open * 160).toFixed(1)}px`);
      css(r.body, 'opacity', open.toFixed(3));
      css(r.mark, 'opacity', c.toFixed(3));
      css(r.mark, 'transform', `scale(${(0.6 + 0.4 * easeOut(c)).toFixed(3)})`);
    });
  }
}

/* ─────────────── 手機與放大鏡 ─────────────── */

/** 右側展示用手機的標準姿態：略朝左轉，下緣高於字幕區。 */
export const PHONE_RIGHT: Pose = { x: 0.44, y: 0.04, z: 0, rx: 0.02, ry: -0.2, rz: 0, s: 1.4 };
/** 進出場：從右側外飛入。 */
export const PHONE_AWAY: Pose = { x: 1.25, y: 0.02, z: -10, rx: 0.05, ry: -1.1, rz: -0.04, s: 1.3 };

/**
 * 放大鏡：把手機螢幕上的 rect（App 邏輯座標）以 DOM 圖片放大顯示在 (cx, cy)，寬 w；
 * 出場時從手機上的原位置「拉出」放大，並以細線連回手機。
 */
export class Lens {
  private root: HTMLElement;
  private img: HTMLElement;
  private wire: SVGSVGElement;
  private line1: SVGLineElement;
  private line2: SVGLineElement;
  private ring: HTMLElement;
  constructor(parent: HTMLElement, readonly phone: number, readonly screen: string, readonly rect: Rect, readonly cx: number, readonly cy: number, readonly w: number) {
    this.wire = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    this.wire.setAttribute('class', 'lens-wire');
    this.wire.setAttribute('width', '1920');
    this.wire.setAttribute('height', '1080');
    this.line1 = document.createElementNS('http://www.w3.org/2000/svg', 'line');
    this.line2 = document.createElementNS('http://www.w3.org/2000/svg', 'line');
    this.wire.append(this.line1, this.line2);
    parent.append(this.wire);
    this.ring = el('div', 'lens-ring', parent);
    this.root = el('div', 'lens', parent);
    this.img = el('div', 'lens__img', this.root);
    css(this.img, 'background-image', `url(/screens/${screen}.webp)`);
  }
  register(t0: number) { cue('pop', t0 + 0.1, { gain: 0.6 }); return this; }
  at(world: World, t: number, t0: number, t1: number) {
    const a = easeOut(span(t, t0, t0 + 0.6));
    const b = easeInOut(span(t, t1, t1 + 0.4));
    const k = a * (1 - b);
    const vis = k > 0.001;
    for (const e of [this.root, this.ring]) css(e, 'visibility', vis ? 'visible' : 'hidden');
    css(this.wire as unknown as HTMLElement, 'visibility', vis ? 'visible' : 'hidden');
    if (!vis) return;
    world.frame.after.push(() => {
      const p0 = world.point(this.phone, this.rect.x, this.rect.y);
      const p1 = world.point(this.phone, this.rect.x + this.rect.w, this.rect.y + this.rect.h);
      // 手機上的框
      css(this.ring, 'transform', `translate(${p0.x.toFixed(1)}px, ${p0.y.toFixed(1)}px)`);
      css(this.ring, 'width', `${(p1.x - p0.x).toFixed(1)}px`);
      css(this.ring, 'height', `${(p1.y - p0.y).toFixed(1)}px`);
      css(this.ring, 'opacity', k.toFixed(3));
      // 放大鏡：由手機上的框位置移動、放大到目標位置
      const h = this.w * this.rect.h / this.rect.w;
      const sx = (p1.x - p0.x) / this.w;
      const x = lerp((p0.x + p1.x) / 2, this.cx, a), y = lerp((p0.y + p1.y) / 2, this.cy, a);
      const s = lerp(sx, 1, a) * (1 - 0.06 * b);
      css(this.root, 'width', `${this.w}px`);
      css(this.root, 'height', `${h.toFixed(1)}px`);
      css(this.root, 'transform', `translate(${(x - this.w / 2).toFixed(1)}px, ${(y - h / 2).toFixed(1)}px) scale(${s.toFixed(4)})`);
      css(this.root, 'opacity', clamp(k * 1.4).toFixed(3));
      const z = this.w / this.rect.w; // 每個 App 邏輯點的像素
      css(this.img, 'background-size', `${(393 * z).toFixed(1)}px auto`);
      css(this.img, 'background-position', `${(-this.rect.x * z).toFixed(1)}px ${(-this.rect.y * z).toFixed(1)}px`);
      // 連線：放大鏡左右兩側的上下角，連到手機框對應的角
      const L = x - this.w / 2 * s, R = x + this.w / 2 * s, T = y - h / 2 * s, B = y + h / 2 * s;
      const right = this.cx > (p0.x + p1.x) / 2;
      const ex = right ? L : R, px = right ? p1.x : p0.x;
      for (const [ln, py, ey] of [[this.line1, p0.y, T], [this.line2, p1.y, B]] as const) {
        ln.setAttribute('x1', px.toFixed(1)); ln.setAttribute('y1', py.toFixed(1));
        ln.setAttribute('x2', ex.toFixed(1)); ln.setAttribute('y2', ey.toFixed(1));
      }
      css(this.wire as unknown as HTMLElement, 'opacity', (k * 0.9).toFixed(3));
    });
  }
}

/** 畫面上方置中的大字標語（章節中段強調一句話）。 */
export class Callout {
  private root: HTMLElement;
  constructor(parent: HTMLElement, html: string, readonly x: number, readonly y: number, cls = '') {
    this.root = el('div', `callout ${cls}`, parent, html);
  }
  at(t: number, t0: number, t1: number) {
    place(this.root, this.x, this.y);
    fade(this.root, t, t0, t1, 20);
  }
}
