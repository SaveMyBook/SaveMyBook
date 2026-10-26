import * as THREE from 'three';
import { span } from '../lib/kf';
import { el, css } from '../lib/ui';
import type { World } from '../world';
import { V3, hyphen } from './spec';
import './v3.css';

const easeOutCubic = (x: number) => 1 - (1 - Math.min(1, Math.max(0, x))) ** 3;

/**
 * 物件旁的名稱標籤（例如書櫃透視時的元件名稱）：不畫引線，放在物件外框旁、與錨點同高，整塊淡入並橫移 24px。
 * 類別沿用 xlabel，tools/overlap.mjs 會檢查到。字級固定為 V3.label。
 */
export class LabelV3 {
  readonly root: HTMLElement;
  constructor(parent: HTMLElement, text: string, readonly side: 'left' | 'right') {
    this.root = el('div', `xlabel v3-label v3-label--${side}`, parent, hyphen(text));
    css(this.root, 'visibility', 'hidden');
  }
  /**
   * obj：物件（取外框左右緣）；half：物件本體半尺寸；anchor：錨點（物件本體座標）。t0 起進場、t1 起離場。
   */
  at(world: World, t: number, t0: number, t1: number, obj: THREE.Object3D | null, half: [number, number, number], anchor: THREE.Object3D | null) {
    const a = easeOutCubic(span(t, t0, t0 + 0.5));
    const k = a * (1 - span(t, t1, t1 + 0.35));
    css(this.root, 'visibility', k > 0.002 && obj && anchor ? 'visible' : 'hidden');
    if (k <= 0.002 || !obj || !anchor) return;
    world.frame.after.push(() => {
      const xs: number[] = [];
      for (const sx of [-1, 1]) for (const sy of [-1, 1]) for (const sz of [-1, 1]) xs.push(world.project(obj, new THREE.Vector3(sx * half[0], sy * half[1], sz * half[2])).x);
      const p = world.project(anchor);
      const left = this.side === 'left';
      const x = left ? Math.min(...xs) - V3.label.gap - (1 - a) * 24 : Math.max(...xs) + V3.label.gap + (1 - a) * 24;
      css(this.root, 'transform', `translate(${x.toFixed(1)}px, ${p.y.toFixed(1)}px) translate(${left ? '-100%' : '0'}, -50%)`);
      css(this.root, 'opacity', k.toFixed(3));
    });
  }
}
