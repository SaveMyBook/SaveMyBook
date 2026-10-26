import { POPS, type PopKey } from '../data/pops';
import { clamp } from '../lib/util';

type Rect = { x: number; y: number; w: number; h: number };
export type Dir = 'left' | 'right' | 'up';

export interface LiftOptions {
  S: number;
  dir?: Dir;
  rot?: number;
  host?: HTMLElement;
  bounds?: () => DOMRect;
  place?: (slot: DOMRect, w: number, h: number) => { x: number; y: number };
}

export class Lift {
  readonly el = document.createElement('div');
  readonly slot = document.createElement('span');
  private img: HTMLImageElement;
  private e = -1;

  constructor(private phone: HTMLElement, readonly key: PopKey, private o: LiftOptions) {
    const d = POPS[key];
    this.slot.className = 'slot';
    this.slot.style.background = d.slot;
    this.el.className = 'lift';
    this.el.innerHTML = `<div class="lift__in"><span class="lift__shadow"></span><img class="lift__img" src="${d.src}" srcset="${d.srcset}" alt="" decoding="async"></div>`;
    this.img = this.el.querySelector('img')!;
    this.screen.append(this.slot);
    (o.host ?? phone).append(this.el);
  }

  private get screen() { return this.phone.querySelector<HTMLElement>('.phone__screen')!; }

  layout() {
    const d = POPS[this.key];
    const screen = this.screen;
    const k = screen.clientWidth / 393;
    if (!k) return;
    Object.assign(this.slot.style, { left: `${d.x * k}px`, top: `${d.y * k}px`, width: `${d.w * k}px`, height: `${d.h * k}px`, borderRadius: `${d.r * k}px` });
    const host = this.o.host ?? this.phone;
    let slot: Rect;
    if (this.o.host) {
      const r = this.slot.getBoundingClientRect(), hr = host.getBoundingClientRect();
      slot = { x: r.left - hr.left, y: r.top - hr.top, w: r.width, h: r.height };
    } else {
      const bezel = screen.parentElement as HTMLElement;
      slot = { x: bezel.offsetLeft + screen.offsetLeft + d.x * k, y: bezel.offsetTop + screen.offsetTop + d.y * k, w: d.w * k, h: d.h * k };
    }
    const S = this.o.S, W = slot.w * S, H = slot.h * S, pw = this.phone.offsetWidth;
    const hr = host.getBoundingClientRect();
    let fx: number, fy: number;
    if (this.o.place) {
      const p = this.o.place(new DOMRect(hr.left + slot.x, hr.top + slot.y, slot.w, slot.h), W, H);
      fx = p.x - hr.left;
      fy = p.y - hr.top;
    } else if (this.o.dir === 'left') {
      fx = slot.x - (W - slot.w) - pw * 0.26;
      fy = slot.y - (H - slot.h) / 2 - pw * 0.03;
    } else if (this.o.dir === 'up') {
      fx = slot.x - (W - slot.w) / 2;
      fy = slot.y - (H - slot.h) - pw * 0.12;
    } else {
      fx = slot.x + pw * 0.26;
      fy = slot.y - (H - slot.h) / 2 - pw * 0.03;
    }
    if (this.o.bounds) {
      const b = this.o.bounds();
      const x0 = b.left - hr.left, x1 = b.right - hr.left, y0 = b.top - hr.top, y1 = b.bottom - hr.top;
      fx = W > x1 - x0 ? x0 + (x1 - x0 - W) / 2 : clamp(fx, x0, x1 - W);
      fy = H > y1 - y0 ? y0 : clamp(fy, y0, y1 - H);
    }
    Object.assign(this.el.style, { left: `${fx}px`, top: `${fy}px`, width: `${W}px`, borderRadius: `${d.r * k * S}px` });
    this.el.style.setProperty('--S', String(S));
    this.el.style.setProperty('--dxp', `${fx - slot.x}px`);
    this.el.style.setProperty('--dyp', `${fy - slot.y}px`);
    this.el.style.setProperty('--rot', `${this.o.rot ?? 0}deg`);
    this.img.sizes = `${Math.ceil(W)}px`;
  }

  set(e: number) {
    e = e > 0.995 ? 1 : e < 0.005 ? 0 : e;
    if (e === this.e) return;
    this.e = e;
    const v = String(+e.toFixed(4));
    this.el.style.setProperty('--e', v);
    this.slot.style.setProperty('--e', v);
    this.el.classList.toggle('on', e > 0);
    this.el.classList.toggle('up', e === 1);
  }
}
