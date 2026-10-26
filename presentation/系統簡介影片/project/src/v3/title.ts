import { span } from '../lib/kf';
import { el, css } from '../lib/ui';
import { V3, hyphen } from './spec';
import './v3.css';

const easeOutCubic = (x: number) => 1 - (1 - Math.min(1, Math.max(0, x))) ** 3;
const easeInCubic = (x: number) => Math.min(1, Math.max(0, x)) ** 3;

/**
 * 置中兩行標題（情境＋解法）加一行副標。進場整塊由下方 40px 上移並淡入，離場再上移 40px 並淡出（NTUB 的 lift），
 * 不逐字散開。類別沿用 promo__title／promo__sub，tools/overlap.mjs 會檢查到。
 */
export class TitleV3 {
  private root: HTMLElement;
  private lines: HTMLElement[];
  private sub: HTMLElement;
  constructor(ui: HTMLElement, lines: [string, string], sub: string) {
    this.root = el('div', 'v3-title-block', ui);
    this.lines = lines.map((text) => el('div', 'promo__title v3-title', this.root, hyphen(text)));
    this.sub = el('div', 'promo__sub v3-sub', this.root, hyphen(sub));
    // 圖層在段落前後 1 秒就會顯示，場景提早返回、沒呼叫 at() 時不可停在可見的初始狀態
    css(this.root, 'visibility', 'hidden');
  }

  /** t0 起進場，t1 起離場。 */
  at(t: number, t0: number, t1: number) {
    const { lift, inDur, outDur } = V3.title;
    const a = easeOutCubic(span(t, t0, t0 + inDur));
    const b = easeInCubic(span(t, t1, t1 + outDur));
    const k = a * (1 - b);
    css(this.root, 'visibility', k > 0.002 ? 'visible' : 'hidden');
    css(this.root, 'opacity', k.toFixed(3));
    css(this.root, 'transform', `translateY(${((1 - a) * lift - b * lift).toFixed(2)}px)`);
  }
}
