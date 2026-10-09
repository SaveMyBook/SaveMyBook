import * as THREE from 'three';
import { span, easeOut } from '../lib/kf';
import { el, css, place, Rise, fade, number } from '../lib/ui';
import { createPcb, pcbData, PCB_SCALE } from '../deck/pcb';
import type { World } from '../world';
import { soft } from './kit4';
import './tech.css';

/** 技術名稱：粗體大字由遮罩內升起，下附一行角色說明。 */
export class TechLabel {
  private r: Rise;
  private sub: HTMLElement;
  constructor(parent: HTMLElement, name: string, role: string, readonly x: number, readonly y: number) {
    this.r = new Rise(parent, name, 'promo__title tech__name');
    this.sub = el('p', 'promo__sub tech__role', parent, role);
  }
  /** x：跟著下方物件移動時每格傳入（畫面像素），省略則用建構時的位置。 */
  at(t: number, t0: number, t1: number, x = this.x) {
    this.r.at(t, t0, t1, 0.03);
    place(this.r.root, x, this.y);
    fade(this.sub, t, t0 + 0.3, t1, 16, 0);
    place(this.sub, x, this.y + 86);
  }
}

/**
 * 滾動數字：大數字由 0 滾到目標值（以最終寬度固定欄寬，位數增加時整行不會左右跳動），下一行為單位，再下一行為說明。
 * 不加任何圓圈或圓環。
 */
export class Stat {
  private n: HTMLElement;
  private plus: HTMLElement | null;
  private head: HTMLElement;
  private unit: HTMLElement;
  private sub: HTMLElement;
  private fixed = false;
  constructor(parent: HTMLElement, readonly to: number, unit: string, sub: string, plus: boolean, readonly x: number, readonly y: number) {
    this.head = el('div', 'tech__stat', parent);
    this.n = el('b', 'tech__n', this.head);
    this.plus = plus ? el('i', 'tech__plus', this.head, '+') : null;
    this.unit = el('p', 'tech__unit', parent, unit);
    this.sub = el('p', 'promo__sub tech__sub', parent, sub);
  }
  /** t0 進場、t1 退場；數字在 r0 起 dur 秒內滾到目標值。 */
  at(t: number, t0: number, t1: number, r0: number, dur: number) {
    if (!this.fixed && document.fonts.status === 'loaded') {
      number(this.n, this.to, 0, true);
      const w = this.n.offsetWidth;
      if (w > 0) { css(this.n, 'width', `${Math.ceil(w + 2)}px`); this.fixed = true; }
    }
    number(this.n, Math.round(this.to * easeOut(span(t, r0, r0 + dur))), 0, true);
    if (this.plus) css(this.plus, 'opacity', soft(t, r0 + dur - 0.1, r0 + dur + 0.25).toFixed(3));
    fade(this.head, t, t0, t1, 28);
    place(this.head, this.x, this.y);
    fade(this.unit, t, t0 + 0.15, t1, 20);
    // 數字 150px 的逗號會往下伸出字框約 0.25em：單位要排在逗號下緣之下，否則「3,914」的逗號會碰到「項」
    place(this.unit, this.x, this.y + 136);
    fade(this.sub, t, t0 + 0.35, t1, 16, 0);
    place(this.sub, this.x, this.y + 200);
  }
}

/**
 * 書櫃內的 ESP32-S3 開發板：取自主控板模型（src/deck/pcb.ts）中插在排母上的 ESP32-S3-DevKitC-1，單獨拿出來，
 * 不含自製主控板（Rev A 尚在打樣，不可呈現為已裝在書櫃內）。
 * 掛在書櫃群組下，以書櫃本體座標由頂列控制電路的位置（cabinet.ts 的 board：x 1.2、y 3.65、z 1.8，尺寸與開發板相同）抬出到櫃子前方。
 * 不經過 world.frame：可見與否綁定在本段寫入的那一格 frame 上，本段沒有執行的格（其他段落、跳轉播放）一律隱藏。
 */
export class DevBoard {
  private wrap = new THREE.Group();
  private frame: object | null = null;
  private show = false;
  constructor(private world: World) {
    const root = createPcb({ esp32: true, scale: 1 });
    const dev = pcbData(root).devkit;
    dev.removeFromParent();
    dev.position.set(0, 0, 0);
    dev.visible = true;
    // 開發板模型的原點在排針塑膠座底面、長邊沿 x：先置中再縮成書櫃單位（4 公分）
    const box = new THREE.Box3().setFromObject(dev);
    const c = box.getCenter(new THREE.Vector3());
    dev.position.sub(c);
    const inner = new THREE.Group();
    inner.scale.setScalar(PCB_SCALE.cabinet);
    inner.add(dev);
    this.wrap.add(inner);
    Object.defineProperty(this.wrap, 'visible', {
      get: () => this.show && this.frame === this.world.frame,
      set: () => {},
    });
    world.cabinet.group.add(this.wrap);
  }
  /** k：0 在櫃內原位，1 完全抬出；本段每格呼叫（k ≤ 0 時隱藏）。 */
  at(k: number, spin: number) {
    this.frame = this.world.frame;
    this.show = k > 0.001;
    const e = Math.max(0, k);
    const from = { x: 1.2, y: 3.65, z: 1.8 };
    const to = { x: 0.7, y: 1.2, z: 7.4 };
    this.wrap.position.set(from.x + (to.x - from.x) * e, from.y + (to.y - from.y) * e, from.z + (to.z - from.z) * e);
    this.wrap.rotation.set(1.05 * e, (0.42 + spin) * e, 0, 'YXZ');
    this.wrap.scale.setScalar(1 + 3.4 * e);
  }
}
