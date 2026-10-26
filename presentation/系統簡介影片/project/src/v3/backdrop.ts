import { el, css } from '../lib/ui';
import { V3 } from './spec';
import './v3.css';

/**
 * 背景：白到淡霧藍的斜向漸層，加兩團緩慢漂移的淡色光暈。不使用同心圓、圓環或漣漪
 * （2026-10-26 使用者要求全部移除；換鏡頭與段落交界一律只移動 3D 鏡頭）。
 * 畫在 main.ts 的背景層（3D 畫面之下），全片共用一份。
 */
const W = 1920, H = 1080;

export class Backdrop {
  private c: HTMLCanvasElement;
  private g: CanvasRenderingContext2D;
  private k: number;
  constructor(fx: HTMLElement) {
    this.k = Number(new URLSearchParams(location.search).get('scale') || 1);
    this.c = el('canvas', 'v3-bg', fx);
    this.c.width = W * this.k;
    this.c.height = H * this.k;
    this.g = this.c.getContext('2d')!;
  }

  /** on：是否顯示；t：全片秒數（光暈緩慢漂移，畫面不會完全靜止）。 */
  draw(on: boolean, t: number) {
    css(this.c, 'visibility', on ? 'visible' : 'hidden');
    if (!on) return;
    const g = this.g;
    g.setTransform(this.k, 0, 0, this.k, 0, 0);
    const bg = g.createLinearGradient(0, 0, W * 0.3, H);
    bg.addColorStop(0, V3.color.bgTop);
    bg.addColorStop(1, V3.color.bgBottom);
    g.fillStyle = bg;
    g.fillRect(0, 0, W, H);
    // 光暈的位置、大小沿用 NTUB 直式版面（1080 寬）換算到 1080p 橫式
    const rk = 1080 / 1920;
    [[0.15, 0.3, 560], [0.85, 0.75, 640]].forEach(([x, y, r], i) => {
      const dx = Math.sin(t * 0.45 + i * 2.1) * 40 * rk, dy = Math.cos(t * 0.37 + i) * 40 * rk;
      const cx = x * W + dx, cy = y * H + dy, rr = r * rk * 1.4;
      const glow = g.createRadialGradient(cx, cy, 0, cx, cy, rr);
      glow.addColorStop(0, 'rgba(98,125,141,0.13)');
      glow.addColorStop(0.45, 'rgba(98,125,141,0.05)');
      glow.addColorStop(1, 'rgba(98,125,141,0)');
      g.fillStyle = glow;
      g.fillRect(0, 0, W, H);
    });
  }
}
