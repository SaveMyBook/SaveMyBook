import { span, easeInOut } from '../lib/kf';
import { el, css } from '../lib/ui';
import { LogoDraw } from '../lib/logo';

/** 品牌名稱「救「舊」我的書」：「舊」與括號用石板藍，其餘深墨色（比照第一版）。 */
export const BRAND = '救「舊」我的書';
export const brandAccent = (i: number) => i >= 1 && i <= 3;

/** 左上角固定標誌的位置：logo 中心、logo 縮放（原圖 1300 高），名稱左緣、字級與中線。 */
export const CORNER = { logoX: 72, logoY: 58, logoScale: 0.038, textX: 118, textY: 58, size: 34 };

/** 左上角固定的 logo 與名稱：品牌段結束時由片頭的 logo 與名稱飛入，片尾大字出現前收起。 */
export class Corner {
  readonly root: HTMLElement;
  private logo: LogoDraw;
  private name: HTMLElement;
  constructor(parent: HTMLElement) {
    this.root = el('div', 'corner', parent);
    this.logo = new LogoDraw(this.root);
    this.logo.at(99, 0);
    // LogoDraw 會把自己設成 visible，子元素 visible 時不受父元素 hidden 影響，改回跟隨外框
    css(this.logo.root, 'visibility', 'inherit');
    css(this.logo.root, 'transform', `translate(${CORNER.logoX - 825}px, ${CORNER.logoY - 650}px) scale(${CORNER.logoScale})`);
    this.name = el('p', 'corner__name', this.root, '救<i>「舊」</i>我的書');
  }

  at(t: number, t0: number, t1: number) {
    const k = 1 - easeInOut(span(t, t1, t1 + 0.35));
    const on = t >= t0 && k > 0.001;
    css(this.root, 'visibility', on ? 'visible' : 'hidden');
    if (!on) return;
    css(this.root, 'opacity', k.toFixed(3));
    css(this.name, 'transform', `translate(${CORNER.textX}px, ${CORNER.textY}px) translateY(-50%)`);
  }
}
