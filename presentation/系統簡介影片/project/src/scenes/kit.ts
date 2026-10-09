import { span, lerp, clamp, easeOut, easeInOut, monotone, type Pose } from '../lib/kf';
import { el, css, place, Rise, fade } from '../lib/ui';
import { cue } from '../lib/cues';
import TL from '../timeline.json';
import type { World, Scr } from '../world';

export const easeIn = (k: number) => k * k * k;
/** 略帶回彈的緩出。 */
export const back = (k: number) => (k <= 0 ? 0 : k >= 1 ? 1 : 1 + 2.4 * Math.pow(k - 1, 3) + 1.4 * Math.pow(k - 1, 2));

const KEYS = ['x', 'y', 'z', 'rx', 'ry', 'rz', 's'];
export function mix(a: Pose, b: Pose, k: number): Pose {
  const out: Pose = {};
  for (const key of KEYS) out[key] = lerp(a[key] ?? 0, b[key] ?? 0, k);
  return out;
}

/** 完整姿態的關鍵影格（每格都是完整姿態）；未指定緩動且有三個以上影格時，以單調三次插值讓中間影格速度連續。 */
export function track(t: number, frames: [number, Pose][], ease?: (k: number) => number): Pose {
  if (t <= frames[0][0]) return { ...frames[0][1] };
  if (!ease && frames.length > 2) {
    const ts = frames.map((f) => f[0]);
    const out: Pose = {};
    for (const key of KEYS) out[key] = monotone(ts, frames.map((f) => f[1][key] ?? 0), t);
    return out;
  }
  ease ??= easeInOut;
  for (let i = 0; i < frames.length - 1; i++) {
    const [a, pa] = frames[i];
    const [b, pb] = frames[i + 1];
    if (t <= b) return mix(pa, pb, b === a ? 1 : ease((t - a) / (b - a)));
  }
  return { ...frames[frames.length - 1][1] };
}

/** 段落內旁白的開始秒數（相對段落起點）。 */
export function at(id: string) {
  const l = TL.lines.find((x) => x.id === id);
  if (!l) throw new Error(`timeline 沒有 ${id}`);
  return l.at;
}

/* ─────────────── 取景：依介面版面決定放大 ─────────────── */

/** App 邏輯座標的 1pt 在手機縮放 1、正對鏡頭時等於幾個畫面像素。 */
const PX = 0.6346;

export interface Rect { x: number; y: number; w: number; h: number }

/**
 * 讓手機正對鏡頭，並把螢幕上的 rect（App 邏輯座標）放到畫面上 (cx, cy) 為中心、寬 w 像素的位置。
 * 依區塊的實際大小決定縮放，不同區塊放大倍率不同。
 */
export function frame(rect: Rect, cx: number, cy: number, w: number, tilt = 0): Pose {
  const s = w / (rect.w * PX);
  const ax = rect.x + rect.w / 2, ay = rect.y + rect.h / 2;
  const px = cx - (ax - 196.5) * PX * s;
  const py = cy - (ay - 426) * PX * s;
  return { x: (px - 960) / 960, y: (540 - py) / 540, z: 0, rx: 0.02, ry: tilt, rz: 0, s };
}

/** 依時間切換畫面：每步 [開始秒, 畫面, 轉場方式, 轉場秒數]。轉場方式：0 直接切換、1 推入、2 返回、3 底部展開。 */
export type Step = [number, string, number?, number?];
export function seq(t: number, steps: Step[], scroll?: (name: string, t: number) => number): Scr {
  let i = 0;
  while (i + 1 < steps.length && t >= steps[i + 1][0]) i++;
  const off = (n: string) => (scroll ? scroll(n, t) : 0);
  if (i === 0 || t >= steps[i][0] + (steps[i][3] ?? 0.45)) return { a: steps[i][1], offA: off(steps[i][1]) };
  const [t0, name, mode = 0, d0 = 0.45] = steps[i];
  // 換狀態（mode 0）的淡化最多 0.12 秒：兩張截圖的內容只要位置不完全相同（清單往上捲、跳出對話框、換語言），
  // 淡化較久時中間幾格會停在兩層字疊在一起；完全不淡化則像跳格，0.12 秒和 App 對話框出現的速度相近
  const d = mode === 0 ? Math.min(d0, 0.12) : d0;
  if (t >= t0 + d) return { a: name, offA: off(name) };
  const prev = steps[i - 1][1];
  return { a: prev, b: name, k: span(t, t0, t0 + d), mode, offA: off(prev), offB: off(name) };
}

/**
 * 逐字輸入、捲動、逐格動畫的一串 App 畫面：依序平均分配在 [t0, t1]，逐格直接替換。
 * 不可淡化：捲動的相鄰兩格位移不同，淡化（即使 0.03 秒）會在每一格疊出兩層字。
 */
export function frameSteps(frames: string[], t0: number, t1: number, d = 0.001): Step[] {
  const n = frames.length;
  return frames.map((f, i) => [n === 1 ? t0 : lerp(t0, t1, i / (n - 1)), f, 0, d] as Step);
}

/** 長截圖捲動：[秒, 捲動量] 關鍵點之間平滑移動。 */
export function scrollKeys(t: number, keys: [number, number][]) {
  if (t <= keys[0][0]) return keys[0][1];
  for (let i = 0; i < keys.length - 1; i++) {
    const [a, va] = keys[i];
    const [b, vb] = keys[i + 1];
    if (t <= b) return lerp(va, vb, easeInOut((t - a) / (b - a)));
  }
  return keys[keys.length - 1][1];
}

/** 登記畫面切換的音效（推入、返回、展開才有聲音，淡化沒有）。 */
export function stepCues(steps: Step[]) {
  steps.slice(1).forEach(([t0, , mode = 0]) => {
    if (mode === 1 || mode === 2) cue('swipe', t0, { gain: 0.8 });
    else if (mode === 3) cue('sheet', t0, { gain: 0.8 });
  });
}

/* ─────────────── 畫面上的標示 ─────────────── */

/** 標示框：框出螢幕上的區塊，可附一個小標籤；跟著手機移動。 */
export class Mark {
  private box: HTMLElement;
  private tag: HTMLElement | null;
  constructor(parent: HTMLElement, readonly phone: number, public rect: Rect, label = '', readonly radius = 14) {
    this.box = el('div', 'mark', parent);
    this.tag = label ? el('span', 'mark__tag', this.box, label) : null;
  }
  register(t0: number) { cue('select', t0 + 0.05, { gain: 0.7 }); return this; }
  at(world: World, t: number, t0: number, t1: number) {
    const a = easeOut(span(t, t0, t0 + 0.45));
    const b = easeInOut(span(t, t1, t1 + 0.3));
    const k = a * (1 - b);
    css(this.box, 'visibility', k > 0.001 ? 'visible' : 'hidden');
    if (k <= 0.001) return;
    world.frame.after.push(() => {
      const p0 = world.point(this.phone, this.rect.x, this.rect.y);
      const p1 = world.point(this.phone, this.rect.x + this.rect.w, this.rect.y + this.rect.h);
      const pad = 6;
      const w = p1.x - p0.x + pad * 2, h = p1.y - p0.y + pad * 2;
      const scale = (p1.x - p0.x) / this.rect.w;
      css(this.box, 'width', `${w.toFixed(1)}px`);
      css(this.box, 'height', `${h.toFixed(1)}px`);
      css(this.box, 'border-radius', `${(this.radius * scale + pad).toFixed(1)}px`);
      css(this.box, 'transform', `translate(${(p0.x - pad).toFixed(1)}px, ${(p0.y - pad).toFixed(1)}px) scale(${(1.04 - 0.04 * a).toFixed(3)})`);
      css(this.box, 'opacity', k.toFixed(3));
      if (this.tag) css(this.tag, 'opacity', easeOut(span(t, t0 + 0.2, t0 + 0.6)).toFixed(3));
    });
  }
}

/** 點擊：手指位置的圓點按下再放開，並擴散一圈。 */
export class Tap {
  private dot: HTMLElement;
  private ring: HTMLElement;
  constructor(parent: HTMLElement, readonly phone: number, public x: number, public y: number, readonly t0: number) {
    this.dot = el('i', 'tap', parent);
    this.ring = el('i', 'tap-ring', parent);
    cue('tap', t0 + 0.32);
  }
  at(world: World, t: number) {
    const k = span(t, this.t0, this.t0 + 0.9);
    const vis = k > 0 && k < 1;
    css(this.dot, 'visibility', vis ? 'visible' : 'hidden');
    css(this.ring, 'visibility', vis ? 'visible' : 'hidden');
    if (!vis) return;
    world.frame.after.push(() => {
      const p = world.point(this.phone, this.x, this.y);
      const appear = easeOut(span(k, 0, 0.25));
      const press = Math.sin(Math.PI * span(k, 0.28, 0.5));
      const out = span(k, 0.55, 1);
      place(this.dot, p.x, p.y, ` scale(${(appear * (1 - 0.18 * press)).toFixed(3)})`);
      css(this.dot, 'opacity', (appear * (1 - out)).toFixed(3));
      const r = span(k, 0.35, 0.95);
      place(this.ring, p.x, p.y, ` scale(${(0.6 + r * 1.4).toFixed(3)})`);
      css(this.ring, 'opacity', (r > 0 ? (1 - r) * 0.8 : 0).toFixed(3));
    });
  }
}

/** 手機下方的身分標籤（賣家・侖娥／買家・海嫄／管理員）。 */
export class Tag {
  readonly root: HTMLElement;
  constructor(parent: HTMLElement, readonly phone: number, role: string, name: string) {
    this.root = el('div', 'ptag', parent, `<b>${role}</b>${name ? `<span>${name}</span>` : ''}`);
  }
  at(world: World, t: number, t0: number, t1: number) {
    const k = easeOut(span(t, t0, t0 + 0.5)) * (1 - easeInOut(span(t, t1, t1 + 0.35)));
    css(this.root, 'visibility', k > 0.001 ? 'visible' : 'hidden');
    if (k <= 0.001) return;
    world.frame.after.push(() => {
      const st = world.frame.phones[this.phone];
      if (!st) { css(this.root, 'opacity', '0'); return; }
      // 手機放大特寫時底邊出畫，標籤會壓在螢幕內容上，跟著標題的門檻一起淡出
      const zoom = clamp(((st.pose.s ?? 1) - 1.34) / 0.16);
      const p = world.edge(this.phone, 0, -1);
      place(this.root, p.x, Math.min(1040, p.y + 34));
      css(this.root, 'opacity', (k * (1 - zoom)).toFixed(3));
    });
  }
}

/** iOS 樣式的推播通知，自手機頂端滑下。 */
export class Banner {
  readonly root: HTMLElement;
  constructor(parent: HTMLElement, readonly phone: number, title: string, body: string, time = '現在') {
    this.root = el('div', 'banner', parent, `<p class="banner__app"><img src="/brand/icon-512.png" alt="">救「舊」我的書<i>${time}</i></p><p class="banner__title">${title}</p><p class="banner__body">${body}</p>`);
  }
  at(world: World, t: number, t0: number, t1: number) {
    const a = back(span(t, t0, t0 + 0.55));
    const b = easeInOut(span(t, t1, t1 + 0.35));
    const k = Math.min(1, a) * (1 - b);
    css(this.root, 'visibility', k > 0.001 ? 'visible' : 'hidden');
    if (k <= 0.001) return;
    world.frame.after.push(() => {
      const p0 = world.point(this.phone, 12, 56);
      const p1 = world.point(this.phone, 381, 56);
      const w = p1.x - p0.x;
      const s = w / 460;
      css(this.root, 'transform', `translate(${p0.x.toFixed(1)}px, ${(p0.y - (1 - a) * 90 * s - b * 40 * s).toFixed(1)}px) scale(${s.toFixed(3)})`);
      css(this.root, 'opacity', clamp(k * 1.3).toFixed(3));
    });
  }
}

/** 所有置中標題的容器；手機放大特寫時由 main.ts 整體淡出，避免與手機重疊。 */
export const HEADLINES: HTMLElement[] = [];

/** 置中的標題＋副標（畫面上方）。 */
export class Headline {
  private h: Rise;
  private s: HTMLElement | null;
  constructor(ui: HTMLElement, title: string, sub = '') {
    const box = el('div', 'hl', ui);
    HEADLINES.push(box);
    this.h = new Rise(box, title, 'h-headline');
    this.s = sub ? el('p', 'sub', box, sub) : null;
  }
  at(t: number, t0: number, t1: number, y = 118) {
    this.h.at(t, t0, t1);
    place(this.h.root, 960, y, ' scale(0.8)');
    if (this.s) {
      // 副標淡出時不上移，否則會疊到正在上移淡出的標題
      fade(this.s, t, t0 + 0.3, t1, 24, 0);
      place(this.s, 960, y + 70);
    }
  }
}

/** 側邊說明：手機旁的空白處，小標＋標題＋說明。 */
export class Caption {
  readonly root: HTMLElement;
  constructor(parent: HTMLElement, eyebrow: string, title: string, body = '', readonly x = 120, readonly align: 'left' | 'right' = 'left') {
    this.root = el('div', `cap cap--${align}`, parent);
    if (eyebrow) el('p', 'cap__eyebrow', this.root, eyebrow);
    el('p', 'cap__title', this.root, title);
    if (body) el('p', 'cap__body', this.root, body);
  }
  at(t: number, t0: number, t1: number, y: number) {
    const a = easeOut(span(t, t0, t0 + 0.6));
    const b = easeInOut(span(t, t1, t1 + 0.4));
    css(this.root, 'opacity', (a * (1 - b)).toFixed(3));
    css(this.root, 'transform', `translate(${this.x}px, ${(y + (1 - a) * 30 - b * 30).toFixed(1)}px) translateY(-50%)`);
    css(this.root, 'visibility', a * (1 - b) <= 0.001 ? 'hidden' : 'visible');
  }
}

/** 一組小標籤，依序淡入。 */
export class Chips {
  readonly root: HTMLElement;
  private items: HTMLElement[];
  constructor(parent: HTMLElement, labels: string[], cls = '') {
    this.root = el('div', `chips ${cls}`, parent);
    this.items = labels.map((l) => el('span', 'chip', this.root, l));
  }
  at(t: number, t0: number, t1: number, x: number, y: number, stagger = 0.12) {
    const vis = t >= t0 - 0.01 && t <= t1 + 0.5;
    css(this.root, 'visibility', vis ? 'visible' : 'hidden');
    css(this.root, 'transform', `translate(${x}px, ${y}px)`);
    this.items.forEach((c, i) => {
      const a = easeOut(span(t, t0 + i * stagger, t0 + i * stagger + 0.5));
      const b = easeInOut(span(t, t1, t1 + 0.4));
      css(c, 'opacity', (a * (1 - b)).toFixed(3));
      css(c, 'transform', `translateY(${((1 - a) * 16).toFixed(1)}px)`);
    });
  }
}
