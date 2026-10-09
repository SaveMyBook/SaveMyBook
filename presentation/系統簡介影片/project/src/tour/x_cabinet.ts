import * as THREE from 'three';
import { span, lerp, easeOut, easeInOut } from '../lib/kf';
import { el, css, place } from '../lib/ui';
import { TAPS, type World } from '../world';
import { CAM_Z } from '../stage';
import { Cabinet } from '../three/cabinet';
import { Kiosk, type KioskPop } from '../three/textures';
import type { Pose } from '../lib/kf';
import './cabinet.css';

/**
 * 透視時的元件名稱：不畫引線，只把文字放在書櫃外框旁、與元件同高，元件本身同時轉成品牌藍（Cabinet.setFocus）對應。
 * 類別名稱前段沿用 xlabel，讓 tools/overlap.mjs 檢查到。
 */
export class PartLabel {
  readonly root: HTMLElement;
  constructor(parent: HTMLElement, text: string, readonly anchor: string, readonly side: 'left' | 'right') {
    this.root = el('div', `xlabel cab-lbl cab-lbl--${side}`, parent, text);
  }
  at(world: World, t: number, t0: number, t1: number) {
    const a = easeOut(span(t, t0, t0 + 0.5));
    const b = easeInOut(span(t, t1, t1 + 0.35));
    const k = a * (1 - b);
    css(this.root, 'visibility', k > 0.001 && world.frame.cabinet ? 'visible' : 'hidden');
    if (k <= 0.001 || !world.frame.cabinet) return;
    world.frame.after.push(() => {
      // 書櫃投影外框（八個角）的左右緣，標籤放在外框外 40px
      const xs: number[] = [];
      for (const sx of [-1, 1]) for (const sy of [-1, 1]) for (const sz of [-1, 1]) {
        xs.push(world.project(world.cabinet.group, new THREE.Vector3(sx * Cabinet.WIDTH / 2, sy * Cabinet.HEIGHT / 2, sz * Cabinet.DEPTH / 2)).x);
      }
      const p = world.project(world.cabinet.anchors[this.anchor]);
      const left = this.side === 'left';
      const x = left ? Math.min(...xs) - 40 - (1 - a) * 24 : Math.max(...xs) + 40 + (1 - a) * 24;
      css(this.root, 'transform', `translate(${x.toFixed(1)}px, ${p.y.toFixed(1)}px) translate(${left ? '-100%' : '0'}, -50%)`);
      css(this.root, 'opacity', k.toFixed(3));
    });
  }
}

/**
 * 書櫃螢幕浮出的外框在畫面上的範圍：透明、不可見的方塊，只供 tools/overlap.mjs 檢查浮出的螢幕
 * 是否壓到手機、標題或字幕區（類別名稱前段沿用 xlabel）。
 */
export class PopBox {
  private root: HTMLElement;
  constructor(parent: HTMLElement) {
    this.root = el('div', 'xlabel cab-popbox', parent);
  }
  at(world: World) {
    const on = !!world.frame.cabinet;
    if (!on) { css(this.root, 'visibility', 'hidden'); return; }
    world.frame.after.push(() => {
      if (!world.cabinet.popShown) { css(this.root, 'visibility', 'hidden'); return; }
      const c = world.cabinet.popCorners().map((v) => world.stage.toScreen(v));
      const x0 = Math.min(...c.map((p) => p.x)), x1 = Math.max(...c.map((p) => p.x));
      const y0 = Math.min(...c.map((p) => p.y)), y1 = Math.max(...c.map((p) => p.y));
      css(this.root, 'visibility', 'visible');
      css(this.root, 'transform', `translate(${x0.toFixed(1)}px, ${y0.toFixed(1)}px)`);
      css(this.root, 'width', `${(x1 - x0).toFixed(1)}px`);
      css(this.root, 'height', `${(y1 - y0).toFixed(1)}px`);
    });
  }
}

/**
 * 比對數字：數字本身由浮出的書櫃螢幕飛進手機的兩個輸入格（只有數字，沒有底框）。
 * 終點取自截圖工具量到的輸入格（taps.json 的 tap_cab_digit_1、tap_cab_digit_2），字級由 28pt 換算。
 */
export class DigitFly {
  private digits: HTMLElement[];
  constructor(ui: HTMLElement, readonly phone: number, text = ['2', '5']) {
    this.digits = text.map((d) => el('span', 'cab-digit', ui, d));
  }
  at(world: World, t: number, t0: number, t1: number) {
    const flying = t > t0 && t < t1 + 0.05 && !!world.frame.cabinet && !!world.frame.phones[this.phone];
    if (!flying) { this.digits.forEach((d) => css(d, 'visibility', 'hidden')); return; }
    world.frame.after.push(() => {
      const popped = world.cabinet.popShown;
      const v = 126 / 240;
      this.digits.forEach((d, i) => {
        const box = TAPS[`tap_cab_digit_${i + 1}`];
        if (!box) return;
        // 兩個數字同時起飛、同時抵達（錯開時途中的左右順序會暫時顛倒），路徑微微上拱
        const f = span(t, t0, t1);
        const k = easeInOut(f);
        const u = 0.5 + (i === 0 ? -1 : 1) * Kiosk.DIGIT_GAP;
        const top = world.stage.toScreen(world.cabinet.screenPoint(u, v - Kiosk.DIGIT_EM / 2, popped));
        const bot = world.stage.toScreen(world.cabinet.screenPoint(u, v + Kiosk.DIGIT_EM / 2, popped));
        const from = world.stage.toScreen(world.cabinet.screenPoint(u, v, popped));
        // 螢幕字型 96px（含行距）對應字身高度約 0.72
        const fromSize = (bot.y - top.y) * 0.98;
        const cx = box.x + box.w / 2, cy = box.y + box.h / 2;
        const to = world.point(this.phone, cx, cy);
        const toSize = world.point(this.phone, cx, cy + 14).y - world.point(this.phone, cx, cy - 14).y;
        const c = span(k, 0.25, 0.6);
        css(d, 'visibility', f > 0 ? 'visible' : 'hidden');
        css(d, 'font-size', `${lerp(fromSize, toSize, k).toFixed(1)}px`);
        css(d, 'color', `rgb(${lerp(238, 21, c).toFixed(0)}, ${lerp(242, 30, c).toFixed(0)}, ${lerp(245, 39, c).toFixed(0)})`);
        place(d, lerp(from.x, to.x, k), lerp(from.y, to.y, k) - Math.sin(Math.PI * k) * 70);
        css(d, 'opacity', (span(f, 0, 0.04) * (1 - span(f, 0.95, 1))).toFixed(3));
      });
    });
  }
}

/**
 * 螢幕浮出的目標：讓浮出的螢幕外框在畫面上以 (x, y) 為中心、寬 w 像素（1920×1080），浮在世界座標 z 的深度。
 * 依書櫃當下的姿態（只計 ry 轉角與縮放）換算成 KioskPop 的書櫃本體座標位移，書櫃移動或轉動時浮出的螢幕仍停在同一處。
 */
/** 浮出螢幕的世界深度：書櫃轉 0.24–0.3 rad、放大 1.55–1.64 倍時左前角伸到 z≈7.7，浮出的螢幕必須在它前方，否則會嵌進櫃體 */
export const POP_Z = 10;

export function popAt(world: World, pose: Pose, x: number, y: number, w: number, z = 4): Omit<KioskPop, 'k'> {
  const { halfW, halfH } = world.stage;
  const ppu = (540 / halfH) * CAM_Z / (CAM_Z - z);
  const s = pose.s ?? 1, ry = pose.ry ?? 0;
  const c = Math.cos(ry), sn = Math.sin(ry);
  const S = Cabinet.SCREEN;
  // 螢幕中心的世界座標（本體座標經縮放、轉角後加上書櫃位置）
  const sx = (pose.x ?? 0) * halfW + (S.x * c + S.z * sn) * s;
  const sy = (pose.y ?? 0) * halfH + S.y * s;
  const sz = (pose.z ?? 0) + (-S.x * sn + S.z * c) * s;
  const wx = (x - 960) / ppu - sx, wy = (540 - y) / ppu - sy, wz = z - sz;
  return {
    dx: (wx * c - wz * sn) / s,
    dy: wy / s,
    dz: (wx * sn + wz * c) / s,
    s: (w / ppu) / (S.bezelW * s),
  };
}
