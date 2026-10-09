import { clamp, easeOut, span } from '../lib/kf';
import { el, css } from '../lib/ui';
import { LogoDraw } from '../lib/logo';
import { CORNER } from '../scenes/brand';
import './open.css';

/**
 * 品牌組：logo 與名稱的相對位置、字級、樣式都和左上角固定標誌（brand.ts 的 Corner）一模一樣，
 * 只對整組做「平移＋等比縮放」。縮放倍率回到 1、平移回到 0 時，畫面與 Corner 逐像素相同，交接時不會跳動。
 */
export class Lockup {
  readonly root: HTMLElement;
  private logo: LogoDraw;
  private name: HTMLElement;
  private nameW = 0;

  constructor(parent: HTMLElement) {
    this.root = el('div', 'open-lock', parent);
    this.logo = new LogoDraw(this.root);
    css(this.logo.root, 'transform', `translate(${CORNER.logoX - 825}px, ${CORNER.logoY - 650}px) scale(${CORNER.logoScale})`);
    this.name = el('p', 'corner__name', this.root, '救<i>「舊」</i>我的書');
    css(this.name, 'transform', `translate(${CORNER.textX}px, ${CORNER.textY}px) translateY(-50%)`);
  }

  /** 整組在 Corner 座標中的水平中心（logo 左緣到名稱右緣）；logo 可見寬約 ±31px。 */
  get cx0() {
    if (!this.nameW) this.nameW = this.name.offsetWidth;
    return (CORNER.logoX - 31 + CORNER.textX + (this.nameW || 209)) / 2;
  }

  /**
   * draw0：logo 開始描線；name：名稱 0～1 的出現程度（由 logo 後方往右展開）。
   * cx、cy：整組中心在畫面上的位置；f：相對 Corner 的倍率。
   */
  at(t: number, on: boolean, draw0: number, name: number, cx: number, cy: number, f: number) {
    css(this.root, 'visibility', on ? 'visible' : 'hidden');
    // LogoDraw 會把自己設成 visible，不受外框 hidden 影響；交接後若不另外藏起來，會和 Corner 的 logo 疊成兩層
    if (!on) { css(this.logo.root, 'visibility', 'hidden'); return; }
    this.logo.at(t, draw0);
    const ox = cx - this.cx0 * f, oy = cy - CORNER.logoY * f;
    css(this.root, 'transform', `translate(${ox.toFixed(2)}px, ${oy.toFixed(2)}px) scale(${f.toFixed(5)})`);
    const k = clamp(name);
    css(this.name, 'opacity', easeOut(span(k, 0, 0.6)).toFixed(3));
    // 名稱完全出現後，transform 與 clip-path 回到 Corner 的原樣
    const dx = (1 - easeOut(k)) * -18;
    css(this.name, 'transform', `translate(${(CORNER.textX + dx).toFixed(2)}px, ${CORNER.textY}px) translateY(-50%)`);
    css(this.name, 'clip-path', k >= 1 ? 'none' : `inset(-20% ${((1 - easeOut(k)) * 100).toFixed(2)}% -20% 0)`);
  }
}

/** 數字（例如 57.4%）：數值滾動，% 用較小字級。 */
export class BigNum {
  readonly root: HTMLElement;
  private val: HTMLElement;
  constructor(parent: HTMLElement) {
    this.root = el('div', 'h-display open-num', parent);
    this.val = el('span', '', this.root);
    el('small', '', this.root, '%');
  }
  set(v: number, dec = 1) {
    const s = v.toFixed(dec);
    if (this.val.textContent !== s) this.val.textContent = s;
  }
}
