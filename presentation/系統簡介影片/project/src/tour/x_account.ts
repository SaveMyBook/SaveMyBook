import { el, css, place, fade } from '../lib/ui';
import { CUTS } from '../world';
import { spread } from './kit5';
import './account.css';

/**
 * 語言名稱副標：五種語言排成一行，手機畫面切到哪一種語言，哪個名稱就換成深色（只用 promo.css 的兩種藍）。
 */
export class LangSub {
  private root: HTMLElement;
  private items: HTMLElement[];
  constructor(parent: HTMLElement, names: string[], readonly y = 204) {
    this.root = el('p', 'promo__sub acc__langs', parent);
    this.items = names.map((n) => el('span', 'acc__lang', this.root, n));
  }
  /** t0 進場、t1 退場；cur 為目前畫面的語言序號。 */
  at(t: number, t0: number, t1: number, cur: number) {
    fade(this.root, t, t0, t1, 16, 0);
    place(this.root, 960, this.y);
    this.items.forEach((s, i) => css(s, 'color', i === cur ? 'var(--blue)' : ''));
  }
}

/**
 * kit5.spread 的結果整組平移，讓這組元件的垂直中心落在 cy（App 邏輯 pt）。
 * 這段的元件在螢幕下半部，照原位置展開會壓進字幕區。
 * gap：放大一倍以上的元件浮出時有回彈，移動距離長的元件會短暫越過預定位置，間距要加大才不會碰到旁邊已浮出的元件。
 */
export function spreadAt(names: string[], grow: number, dir: 'col' | 'row', cy: number, gap = 24) {
  const out = spread(names, grow, dir, gap);
  const rs = names.map((n) => CUTS[n]);
  if (rs.some((r) => !r)) return out;
  const top = Math.min(...rs.map((r, i) => r.y + r.h / 2 + out[i].dy - r.h * (1 + grow) / 2));
  const bottom = Math.max(...rs.map((r, i) => r.y + r.h / 2 + out[i].dy + r.h * (1 + grow) / 2));
  const shift = cy - (top + bottom) / 2;
  return out.map((o) => ({ dx: o.dx, dy: o.dy + shift }));
}
