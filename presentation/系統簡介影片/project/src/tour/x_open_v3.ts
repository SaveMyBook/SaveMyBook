import { clamp, span, lerp } from '../lib/kf';
import { el, css } from '../lib/ui';
import { LogoDraw } from '../lib/logo';
import { CORNER } from '../scenes/brand';
import { V3 } from '../v3/spec';
import './open_v3.css';

const easeOutCubic = (x: number) => 1 - (1 - clamp(x)) ** 3;
const easeInCubic = (x: number) => clamp(x) ** 3;
/** 標誌出現：淡入 0.5 秒，同時由 0.92 倍輕微放大到原尺寸（0.9 秒、減速）。不彈跳、不搭配圓環或漣漪。 */
export const MARK_IN = { fade: 0.5, grow: 0.9, from: 0.92 };
export const markIn = (t: number, t0: number) => ({ fade: easeOutCubic(span(t, t0, t0 + MARK_IN.fade)), grow: span(t, t0, t0 + MARK_IN.grow) });

/**
 * 片頭品牌段與片尾共用的直式排列（NTUB 片頭、片尾的做法：標誌在上、名稱在下）。
 * logo 0.2 倍約 324×250px；名稱為 Corner 字級的 1.88 倍（約 64px）。整組約 y 293–670，中心在扣掉字幕帶後的畫面中央。
 */
export const HERO = { logoY: 418, logoS: 0.2, nameY: 638, nameF: 1.88 };
/** 標題第一行的標誌：名稱字級同大標，中線在第一行中央。 */
export const ROW_F = V3.title.size / CORNER.size;
export const ROW_Y = V3.title.top + V3.title.lineH / 2;

/** logo 中心、縮放（原圖 1300 高）；名稱左緣、中線、相對 Corner 字級的倍率。 */
export interface MarkPose { lx: number; ly: number; ls: number; nx: number; ny: number; nf: number }

/**
 * 標誌（logo＋名稱）：名稱沿用左上角 Corner 的 corner__name 樣式，logo 沿用 LogoDraw。
 * 姿態回到 cornerPose(1) 時，transform 與 Corner 完全相同，交接時逐像素重合。
 */
export class BrandMark {
  readonly root: HTMLElement;
  readonly logo: LogoDraw;
  readonly name: HTMLElement;
  private nameW = 0;
  constructor(parent: HTMLElement) {
    this.root = el('div', 'ov3-mark', parent);
    this.logo = new LogoDraw(this.root);
    this.name = el('p', 'corner__name ov3-mark__name', this.root, '救<i>「舊」</i>我的書');
  }

  /** 名稱在 Corner 字級下的寬度（字型載入後量測）。 */
  get w() {
    if (!this.nameW) this.nameW = this.name.offsetWidth;
    return this.nameW || 209;
  }

  /** 橫式（同 Corner 的排列）放大 f 倍，整組中心在 (gx, gy)；f = 1 且中心為 cornerCenter 時與 Corner 相同。 */
  rowPose(f: number, gx: number, gy: number): MarkPose {
    const cx0 = (CORNER.logoX - 31 + CORNER.textX + this.w) / 2;
    return { lx: gx + (CORNER.logoX - cx0) * f, ly: gy, ls: CORNER.logoScale * f, nx: gx + (CORNER.textX - cx0) * f, ny: gy, nf: f };
  }
  get cornerCenter(): [number, number] {
    return [(CORNER.logoX - 31 + CORNER.textX + this.w) / 2, CORNER.logoY];
  }
  cornerPose(): MarkPose {
    return { lx: CORNER.logoX, ly: CORNER.logoY, ls: CORNER.logoScale, nx: CORNER.textX, ny: CORNER.textY, nf: 1 };
  }
  /** 直式（logo 在上、名稱在下，置中），NTUB 片頭與片尾的排列。 */
  stackPose(cx: number, logoY: number, logoS: number, nameY: number, nameF: number): MarkPose {
    return { lx: cx, ly: logoY, ls: logoS, nx: cx - (this.w * nameF) / 2, ny: nameY, nf: nameF };
  }

  /**
   * p：姿態；logoK、nameK：logo 與名稱的出現程度（0～1）；draw0：LogoDraw 的描繪起點（決定填色與光澤的時間）。
   * grow：logo 出現時輕微放大的進度（0～1，見 markIn）。
   */
  at(t: number, on: boolean, p: MarkPose, draw0: number, logoK: number, nameK: number, grow = 1) {
    css(this.root, 'visibility', on ? 'visible' : 'hidden');
    if (!on) {
      // LogoDraw 會把自己設成 visible，不受外框 hidden 影響；不另外藏起來會和 Corner 的 logo 疊成兩層
      css(this.logo.root, 'visibility', 'hidden');
      css(this.name, 'visibility', 'hidden');
      return;
    }
    this.logo.at(t, draw0);
    const s = p.ls * (MARK_IN.from + (1 - MARK_IN.from) * easeOutCubic(grow));
    css(this.logo.root, 'visibility', logoK > 0.002 ? 'visible' : 'hidden');
    css(this.logo.root, 'opacity', logoK >= 0.999 ? '1' : logoK.toFixed(3));
    css(this.logo.root, 'transform', `translate(${(p.lx - 825).toFixed(2)}px, ${(p.ly - 650).toFixed(2)}px) scale(${s.toFixed(5)})`);
    const a = easeOutCubic(nameK);
    css(this.name, 'visibility', a > 0.002 ? 'visible' : 'hidden');
    css(this.name, 'opacity', a >= 0.999 ? '1' : a.toFixed(3));
    const dy = (1 - a) * 24;
    css(this.name, 'transform', `translate(${p.nx.toFixed(2)}px, ${(p.ny + dy).toFixed(2)}px) translateY(-50%) scale(${p.nf.toFixed(5)})`);
  }
}

const logLerp = (x: number, y: number, q: number) => Math.exp(lerp(Math.log(x), Math.log(y), q));

/** 兩個姿態之間：位置以 k 內插，縮放取對數內插（放大縮小的速度一致）；ky 讓垂直方向稍晚，路徑成弧線。 */
export function mixMark(a: MarkPose, b: MarkPose, k: number, ky = k): MarkPose {
  return { lx: lerp(a.lx, b.lx, k), ly: lerp(a.ly, b.ly, ky), ls: logLerp(a.ls, b.ls, k), nx: lerp(a.nx, b.nx, k), ny: lerp(a.ny, b.ny, ky), nf: logLerp(a.nf, b.nf, k) };
}

/**
 * 直式換成橫式：logo 由名稱上方移到名稱左側。logo 先往左、先縮小，再往下就位，路徑繞過名稱的左上角；
 * 同步內插時 logo 會斜切過「救」字，接近終點時也還比終點大，右緣會碰到名稱。
 */
export function stackToRow(a: MarkPose, b: MarkPose, t: number, t0: number, t1: number): MarkPose {
  const d = t1 - t0;
  const n = soft(t, t0, t1);
  return {
    lx: lerp(a.lx, b.lx, soft(t, t0, t1 - 0.35 * d)),
    ly: lerp(a.ly, b.ly, soft(t, t0 + 0.1 * d, t1)),
    ls: logLerp(a.ls, b.ls, soft(t, t0, t1 - 0.4 * d)),
    nx: lerp(a.nx, b.nx, n),
    ny: lerp(a.ny, b.ny, soft(t, t0 + 0.05 * d, t1)),
    nf: logLerp(a.nf, b.nf, n),
  };
}
const soft = (t: number, t0: number, t1: number) => { const k = clamp((t - t0) / (t1 - t0)); return k * k * k * (k * (k * 6 - 15) + 10); };

/** 以 (cx, cy) 為中心等比縮放 z 倍（片尾極慢推近）。 */
export function zoomMark(p: MarkPose, z: number, cx: number, cy: number): MarkPose {
  return { lx: cx + (p.lx - cx) * z, ly: cy + (p.ly - cy) * z, ls: p.ls * z, nx: cx + (p.nx - cx) * z, ny: cy + (p.ny - cy) * z, nf: p.nf * z };
}

/**
 * 品牌段的標題：第一行留給標誌（BrandMark 橫式），第二行大標、第三行副標，字級與進出場同 TitleV3。
 * 大標與副標帶 promo__title／promo__sub 類別，版面檢查會量到。離場只淡出（TitleV3 會再上移 40px，會疊到第一行的標誌）。
 */
export class BrandTitle {
  private root: HTMLElement;
  constructor(ui: HTMLElement, line: string, sub: string) {
    this.root = el('div', 'v3-title-block', ui);
    el('div', 'ov3-spacer', this.root);
    el('div', 'promo__title v3-title', this.root, line);
    el('div', 'promo__sub v3-sub', this.root, sub);
  }
  at(t: number, t0: number, t1: number) {
    const { lift, inDur, outDur } = V3.title;
    const a = easeOutCubic(span(t, t0, t0 + inDur));
    const b = easeInCubic(span(t, t1, t1 + outDur));
    const k = a * (1 - b);
    css(this.root, 'visibility', k > 0.002 ? 'visible' : 'hidden');
    css(this.root, 'opacity', k.toFixed(3));
    // 離場只淡出、不上移：上移會疊到第一行的標誌
    css(this.root, 'transform', `translateY(${((1 - a) * lift).toFixed(2)}px)`);
  }
}
