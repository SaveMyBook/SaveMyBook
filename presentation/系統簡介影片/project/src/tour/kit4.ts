/**
 * 產品宣傳片風格（參考使用者提供的 TAIWAN FIMILY 網站 2.0 介紹影片）：
 * - 白 → 品牌藍的直向漸層，全片單一藍色系。
 * - 畫面上方置中的粗體藍色大標＋一行副標；文案短、口語。
 * - 3D 手機是主角：飛入、傾斜、多支錯落、推近；重點以「螢幕變暗＋元件浮出」呈現（phone.ts 的 PopCard）。
 * - 手機後方有發光的同心圓環；段落轉場用圓環隧道穿越。
 * - y > 930 保留給字幕。
 */
import { span, clamp, easeOut, easeInOut, lerp } from '../lib/kf';
import { el, css, place, Rise, fade } from '../lib/ui';
import { cue } from '../lib/cues';
import type { Pose } from '../lib/kf';

/** 置中大標＋副標。 */
export class Title {
  private h: Rise[];
  private s: HTMLElement | null;
  constructor(parent: HTMLElement, title: string | string[], sub = '', readonly y = 122) {
    const lines = Array.isArray(title) ? title : [title];
    this.h = lines.map((l) => {
      let on = false;
      const marks: boolean[] = [];
      let text = '';
      for (const ch of l) { if (ch === '[') { on = true; continue; } if (ch === ']') { on = false; continue; } marks.push(on); text += ch; }
      return new Rise(parent, text, 'promo__title', (i) => marks[i]);
    });
    this.s = sub ? el('p', 'promo__sub', parent, sub) : null;
  }
  at(t: number, t0: number, t1: number) {
    this.h.forEach((r, i) => {
      r.at(t, t0 + i * 0.08, t1, 0.03);
      place(r.root, 960, this.y + i * 92);
    });
    if (this.s) {
      fade(this.s, t, t0 + 0.3, t1, 16, 0);
      // 副標與大標的間距要留給英文字母的下伸部分（Q、p、j 的尾巴約 0.2em），否則會碰到副標
      place(this.s, 960, this.y + (this.h.length - 1) * 92 + 88);
    }
  }
}

/** 手機後方的發光圓環（白色內面＋藍色光圈），放在 fx 層（3D 畫面之後）。 */
export class Halo {
  private root: HTMLElement;
  constructor(parent: HTMLElement, readonly size = 1040) {
    this.root = el('div', 'halo2', parent);
    css(this.root, 'width', `${size}px`);
    css(this.root, 'height', `${size}px`);
  }
  /** cx, cy：中心；k：0～1 出現程度（由中心放大）。 */
  at(k: number, cx = 960, cy = 560, scale = 1) {
    css(this.root, 'visibility', k > 0.001 ? 'visible' : 'hidden');
    if (k <= 0.001) return;
    place(this.root, cx, cy, ` scale(${(scale * (0.6 + 0.4 * easeOut(k))).toFixed(4)})`);
    css(this.root, 'opacity', clamp(k * 1.2).toFixed(3));
  }
}

/**
 * 圓環隧道轉場：一圈圈發光圓環由中心往外放大，像鏡頭穿過去；中段可放一行字。
 * at(t, t0, d)：t0 開始，d 秒內穿越完畢。
 */
export class Tunnel {
  private rings: HTMLElement[];
  private word: HTMLElement | null;
  constructor(parent: HTMLElement, readonly n = 7, word = '') {
    this.rings = Array.from({ length: n }, () => el('div', 'tring', parent));
    this.word = word ? el('p', 'tword', parent, word) : null;
  }
  register(t0: number, d: number) { cue('whoosh', t0 + d * 0.3, { gain: 0.7 }); return this; }
  at(t: number, t0: number, d: number, cx = 960, cy = 540) {
    const p = (t - t0) / d;
    const on = p > 0 && p < 1;
    for (const r of this.rings) css(r, 'visibility', on ? 'visible' : 'hidden');
    if (this.word) css(this.word, 'visibility', on ? 'visible' : 'hidden');
    if (!on) return;
    const z = easeInOut(p);
    this.rings.forEach((r, i) => {
      // 每圈的半徑隨時間指數放大，越外圈越早出畫
      const s = Math.pow(1.55, i) * 0.12 * Math.pow(9, z);
      place(r, cx, cy, ` scale(${s.toFixed(4)})`);
      const a = clamp(span(p, 0, 0.15)) * (1 - span(s, 2.2, 3.4));
      css(r, 'opacity', a.toFixed(3));
    });
    if (this.word) {
      const k = span(p, 0.15, 0.4) * (1 - span(p, 0.7, 0.95));
      place(this.word, cx, cy, ` scale(${lerp(0.7, 1.25, z).toFixed(3)})`);
      css(this.word, 'opacity', k.toFixed(3));
    }
  }
}

/** 章名大字：放在 fx 層（3D 畫面之後），手機會從字的前方掃過。 */
export class ChapterWord {
  private r: Rise;
  constructor(parent: HTMLElement, text: string) {
    this.r = new Rise(parent, text, 'cword');
  }
  at(t: number, t0: number, t1: number, cx = 960, cy = 470) {
    this.r.at(t, t0, t1, 0.05);
    // 出現後持續極慢放大，畫面不靜止
    const s = 1 + 0.06 * clamp((t - t0) / 3);
    place(this.r.root, cx, cy, ` scale(${s.toFixed(4)})`);
  }
}

/** 閃白轉場：全畫面白色在 t0 前後 d 秒內淡入再淡出（放在 ui 層最上方）。 */
export class WhiteDip {
  private root: HTMLElement;
  constructor(parent: HTMLElement) { this.root = el('div', 'wdip', parent); }
  register(t0: number) { cue('whoosh', t0 - 0.25, { gain: 0.8 }); return this; }
  at(t: number, t0: number, d = 0.3, hold = 0.08) {
    const k = clamp(1 - (Math.abs(t - t0) - hold) / d);
    css(this.root, 'visibility', k > 0.001 ? 'visible' : 'hidden');
    css(this.root, 'opacity', easeInOut(k).toFixed(3));
  }
}

/* ─────────────── 平滑運動 ─────────────── */

const POSE_KEYS = ['x', 'y', 'z', 'rx', 'ry', 'rz', 's'];

/** 誤差函數（Abramowitz–Stegun 7.1.26 的高精度版，誤差 < 1.2e-7），本身是平滑函數。 */
function erf(x: number) {
  const z = Math.abs(x), t = 1 / (1 + 0.5 * z);
  const r = t * Math.exp(-z * z - 1.26551223 + t * (1.00002368 + t * (0.37409196 + t * (0.09678418 + t * (-0.18628806 + t * (0.27886807 + t * (-1.13520398 + t * (1.48851587 + t * (-0.82215223 + t * 0.17087277)))))))));
  return x >= 0 ? 1 - r : r - 1;
}
/** 斜坡函數 max(0, x) 與標準差 sigma 的高斯做卷積的解析解。 */
function smoothRamp(x: number, sigma: number) {
  const u = x / sigma;
  return x * 0.5 * (1 + erf(u / Math.SQRT2)) + sigma * Math.exp(-0.5 * u * u) / Math.sqrt(2 * Math.PI);
}

/**
 * 平滑軌跡：把關鍵姿態連成直線路徑（首尾之外保持不動），再與時間上的高斯（sigma 秒）做卷積。
 * 以解析解計算（路徑 = 起點值 + Σ 斜率變化 × 斜坡函數），結果無限次可微：
 * 位置、速度、加速度全部連續，不會在關鍵影格或取樣點出現頓挫；加減速自然形成緩入緩出。
 * 關鍵影格是「路徑經過的方向」，停留越久越接近該姿態。
 */
const CHECKED = new WeakSet<object>();
export function glide(t: number, keys: [number, Pose][], sigma = 0.3): Pose {
  // 關鍵影格時間沒有嚴格遞增時，路徑會發散、物件直接飛出畫面：第一次用到就報錯，檢查工具會抓到
  if (!CHECKED.has(keys)) {
    CHECKED.add(keys);
    for (let i = 1; i < keys.length; i++) {
      if (!(keys[i][0] > keys[i - 1][0])) console.error(`glide 關鍵影格時間未遞增：第 ${i} 格 ${keys[i][0].toFixed(3)} ≤ ${keys[i - 1][0].toFixed(3)}`);
    }
  }
  const out: Pose = {};
  for (const key of POSE_KEYS) {
    let v = keys[0][1][key] ?? 0;
    let prev = 0;
    for (let i = 0; i < keys.length; i++) {
      const next = i < keys.length - 1 ? ((keys[i + 1][1][key] ?? 0) - (keys[i][1][key] ?? 0)) / Math.max(1e-6, keys[i + 1][0] - keys[i][0]) : 0;
      const dm = next - prev;
      if (dm !== 0) v += dm * smoothRamp(t - keys[i][0], sigma);
      prev = next;
    }
    out[key] = v;
  }
  return out;
}

/** 數值的平滑階梯：在 t0、t1 之間以高斯平均後的直線過渡（比 easeInOut 更柔和，兩端加速度為 0）。 */
export function soft(t: number, t0: number, t1: number) {
  // 以 smootherstep（五次）近似，兩端速度與加速度皆為 0
  const k = clamp((t - t0) / (t1 - t0));
  return k * k * k * (k * (k * 6 - 15) + 10);
}
