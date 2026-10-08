import * as THREE from 'three';
import { span, lerp, easeOut, easeInOut } from '../lib/kf';
import { el, css, place } from '../lib/ui';
import type { World } from '../world';
import { Cabinet } from '../three/cabinet';

const NS = 'http://www.w3.org/2000/svg';

/** 透視標註：元件名稱與說明；side 表示放在書櫃左側或右側。 */
const PARTS: { key: string; title: string; note: string; side: 'left' | 'right' }[] = [
  { key: 'screen', title: '2.8 吋 TFT 螢幕', note: '橫向 320 × 240，顯示 QR Code 與數字', side: 'right' },
  { key: 'board', title: 'ESP32-S3 控制板', note: 'Wi-Fi 連線・HTTPS 同步', side: 'right' },
  { key: 'relay', title: '四路繼電器', note: '驅動電磁鎖', side: 'left' },
  { key: 'power', title: '12V 電源', note: '降壓 5V 供應控制板', side: 'left' },
  { key: 'locks', title: '電磁鎖 ×4', note: 'A01–A04，裝在櫃門左側', side: 'left' },
];
export const PART_COUNT = PARTS.length;
export const partSide = (i: number) => PARTS[i].side;

/** 書櫃透視時的元件標註與引線，依元件在畫面上的位置排到書櫃兩側。 */
export class XrayLabels {
  private labels;
  constructor(fx: HTMLElement) {
    const svg = document.createElementNS(NS, 'svg');
    svg.setAttribute('class', 'overlay');
    svg.setAttribute('viewBox', '0 0 1920 1080');
    fx.append(svg);
    this.labels = PARTS.map((p) => {
      const li = el('div', `xlabel xlabel--${p.side}`, fx);
      el('b', '', li, p.title);
      el('span', '', li, p.note);
      const line = document.createElementNS(NS, 'path');
      line.setAttribute('class', 'xline');
      svg.append(line);
      const dot = document.createElementNS(NS, 'circle');
      dot.setAttribute('class', 'xdot');
      dot.setAttribute('r', '6');
      svg.append(dot);
      return { ...p, li, line, dot };
    });
  }
  hide() { this.labels.forEach((lb) => { css(lb.li, 'visibility', 'hidden'); lb.line.setAttribute('opacity', '0'); lb.dot.setAttribute('opacity', '0'); }); }
  at(world: World, xray: number) {
    if (xray <= 0.001 || !world.frame.cabinet) { this.hide(); return; }
    world.frame.after.push(() => {
      const show = span(xray, 0.7, 1);
      // 標註放在書櫃投影外框的左右兩側（櫃體近似立方體，轉動時側面也會佔寬度）
      const xs: number[] = [];
      for (const sx of [-1, 1]) for (const sy of [-1, 1]) for (const sz of [-1, 1]) {
        xs.push(world.project(world.cabinet.group, new THREE.Vector3(sx * Cabinet.WIDTH / 2, sy * Cabinet.HEIGHT / 2, sz * Cabinet.DEPTH / 2)).x);
      }
      const minX = Math.min(...xs), maxX = Math.max(...xs);
      const placed = this.labels.map((lb, i) => {
        const a = world.project(world.cabinet.anchors[lb.key]);
        const edge = lb.side === 'left' ? minX - 40 : maxX + 40;
        return { lb, a, edge, y: a.y, i };
      });
      for (const side of ['left', 'right']) {
        const g = placed.filter((p) => p.lb.side === side).sort((p, q) => p.y - q.y);
        for (let k = 1; k < g.length; k++) g[k].y = Math.max(g[k].y, g[k - 1].y + 96);
      }
      for (const p of placed) {
        const k = easeOut(span(show, p.i * 0.12, 0.5 + p.i * 0.12));
        const left = p.lb.side === 'left';
        css(p.lb.li, 'opacity', k.toFixed(3));
        css(p.lb.li, 'visibility', k > 0.001 ? 'visible' : 'hidden');
        css(p.lb.li, 'transform', `translate(${(left ? p.edge - 360 - (1 - k) * 20 : p.edge + 22 + (1 - k) * 20).toFixed(1)}px, ${(p.y - 22).toFixed(1)}px)`);
        const x1 = lerp(p.a.x, p.edge + 10, k), y1 = lerp(p.a.y, p.y, k);
        p.lb.line.setAttribute('d', `M${p.a.x.toFixed(1)} ${p.a.y.toFixed(1)} L${x1.toFixed(1)} ${y1.toFixed(1)}`);
        p.lb.line.setAttribute('opacity', k.toFixed(3));
        p.lb.dot.setAttribute('cx', p.a.x.toFixed(1));
        p.lb.dot.setAttribute('cy', p.a.y.toFixed(1));
        p.lb.dot.setAttribute('opacity', k.toFixed(3));
      }
    });
  }
}

/** 比對數字：兩個數字由書櫃螢幕飛進手機的輸入格（放在 3D 畫布上層，途中不會被擋住）。 */
export class DigitFly {
  private digits: HTMLElement[];
  constructor(ui: HTMLElement, readonly phone: number, readonly boxes: [number, number][], text = ['2', '5']) {
    this.digits = text.map((d) => { const s = el('span', 'fly-digit', ui); s.textContent = d; return s; });
  }
  at(world: World, t: number, t0: number, t1: number) {
    const flying = t > t0 && t < t1 + 0.05 && !!world.frame.cabinet && !!world.frame.phones[this.phone];
    world.frame.after.push(() => {
      this.digits.forEach((d, i) => {
        if (!flying) { css(d, 'opacity', '0'); return; }
        const fly = span(t, t0, t1);
        const k = easeInOut(fly);
        const local = world.cabinet.anchors.digits.position.clone();
        local.x += (i === 0 ? -1 : 1) * world.cabinet.digitGap;
        const from = world.stage.toScreen(world.cabinet.group.localToWorld(local), new THREE.Vector2());
        const to = world.stage.toScreen(world.phones[this.phone].screenPoint(this.boxes[i][0], this.boxes[i][1]), new THREE.Vector2());
        const px = (u: number) => u / (world.stage.halfH * 2) * 1080;
        const fromSize = px(world.cabinet.digitSize * world.cabinet.group.scale.x);
        const toSize = px((30 * 6.61) / 393 * world.phones[this.phone].group.scale.x);
        const c = span(k, 0.2, 0.45);
        css(d, 'font-size', `${lerp(fromSize, toSize, k).toFixed(1)}px`);
        css(d, 'color', `rgb(${lerp(238, 21, c).toFixed(0)}, ${lerp(242, 30, c).toFixed(0)}, ${lerp(245, 39, c).toFixed(0)})`);
        place(d, lerp(from.x, to.x, k), lerp(from.y, to.y, k) - Math.sin(Math.PI * k) * 28);
        css(d, 'opacity', (span(fly, 0, 0.06) * (1 - span(fly, 0.92, 1))).toFixed(3));
      });
    });
  }
}

/**
 * 書櫃旁的狀態標記（QR Code 驗證成功、定位確認、櫃門已開鎖），跟著書櫃錨點移動。
 * dx、dy 為相對錨點的像素位移；align 為標記相對位置的對齊（center：置中於上方，left：放在錨點左側）。
 */
export class CabBadge {
  readonly root: HTMLElement;
  constructor(parent: HTMLElement, text: string, readonly anchor: string, readonly align: 'center' | 'left' = 'center', icon: 'check' | 'pin' | 'lock' = 'check') {
    this.root = el('div', `cbadge cbadge--${icon}`, parent, `<i></i>${text}`);
  }
  at(world: World, t: number, t0: number, t1: number) {
    const k = easeOut(span(t, t0, t0 + 0.35)) * (1 - easeInOut(span(t, t1, t1 + 0.3)));
    const on = k > 0.001 && !!world.frame.cabinet;
    css(this.root, 'visibility', on ? 'visible' : 'hidden');
    if (!on) return;
    world.frame.after.push(() => {
      const a = world.project(world.cabinet.anchors[this.anchor]);
      const y = a.y - 26 + (1 - k) * 10;
      const shift = this.align === 'left' ? 'translate(-100%, -50%)' : 'translate(-50%, -100%)';
      css(this.root, 'transform', `translate(${(this.align === 'left' ? a.x - 18 : a.x).toFixed(1)}px, ${(this.align === 'left' ? a.y + 34 : y).toFixed(1)}px) ${shift} scale(${(0.92 + 0.08 * k).toFixed(3)})`);
      css(this.root, 'opacity', k.toFixed(3));
    });
  }
}

/** 步驟列（畫面上方）：依序點亮目前的步驟。 */
export class StepBar {
  readonly root: HTMLElement;
  private items: HTMLElement[];
  constructor(ui: HTMLElement, labels: string[]) {
    this.root = el('ol', 'stepbar', ui);
    this.items = labels.map((l, i) => el('li', '', this.root, `<i>${String(i + 1).padStart(2, '0')}</i>${l}`));
  }
  at(t: number, t0: number, t1: number, marks: number[], y = 236) {
    const k = easeOut(span(t, t0, t0 + 0.5)) * (1 - easeInOut(span(t, t1, t1 + 0.4)));
    css(this.root, 'visibility', k > 0.001 ? 'visible' : 'hidden');
    css(this.root, 'opacity', k.toFixed(3));
    place(this.root, 960, y);
    this.items.forEach((li, i) => {
      li.classList.toggle('is-on', t >= marks[i] && (i === marks.length - 1 || t < marks[i + 1]));
      li.classList.toggle('is-done', i < marks.length - 1 ? t >= marks[i + 1] : false);
    });
  }
}
