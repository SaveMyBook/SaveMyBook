import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/examples/jsm/geometries/RoundedBoxGeometry.js';
import { Kiosk, doorPlate, loadImage } from './textures';

/**
 * 比照實機：9 公釐合板櫃體（寬 31 × 深 31 × 高 38 公分），正面為雷射切割之壓克力。
 * 頂列左側貼標誌、右上角為橫向 2.8 吋螢幕，下方 A01–A04 四扇櫃門由上而下；鉸鏈在右側，電磁鎖裝在門板內側左邊、隨門轉動。單位為 4 公分。
 */
const W = 7.75;
const H = 9.5;
const D = 7.75;
const T = 0.225;
const A = 0.125;
const TOP = 2.05;
const IN_W = W - T * 2;
const CELL_H = (H - T * 2 - TOP - T * 4) / 4;
/** 螢幕可視區 4:3（略大於實機 5.8 × 4.3 公分，影片中才看得清楚）。 */
const SCR_W = 1.76;
const SCR_H = 1.32;
const BEZEL_W = 1.98;
const BEZEL_H = 1.54;

const FRONT = D / 2 + A;
const topRowY = H / 2 - T - TOP / 2;
const cellTop = (i: number) => H / 2 - T - TOP - T - i * (CELL_H + T);
const cellY = (i: number) => cellTop(i) - CELL_H / 2;
const screenX = W / 2 - T - 0.3 - BEZEL_W / 2;
/** 電磁鎖（5.4 × 4.1 × 2.7 公分）在門板內側的位置：門板左緣往內 0.17。 */
const LOCK = { w: 1.35, h: 1.03, d: 0.68, inset: 0.17 };
const lockX = -IN_W / 2 + 0.03 + LOCK.inset + LOCK.w / 2;
const lockZ = D / 2 - LOCK.d / 2;

interface Door { pivot: THREE.Group }

/** 壓克力櫃門的反光：斜向的亮帶，讓透明門板看得出來。 */
function sheenTexture(): THREE.CanvasTexture {
  const c = document.createElement('canvas');
  c.width = 512;
  c.height = 128;
  const g = c.getContext('2d')!;
  const grad = g.createLinearGradient(0, 0, 512, 128);
  grad.addColorStop(0, 'rgba(255,255,255,0.20)');
  grad.addColorStop(0.42, 'rgba(255,255,255,0.04)');
  grad.addColorStop(0.5, 'rgba(255,255,255,0.42)');
  grad.addColorStop(0.56, 'rgba(255,255,255,0.06)');
  grad.addColorStop(0.62, 'rgba(255,255,255,0.26)');
  grad.addColorStop(0.68, 'rgba(255,255,255,0.03)');
  grad.addColorStop(1, 'rgba(255,255,255,0.14)');
  g.fillStyle = grad;
  g.fillRect(0, 0, 512, 128);
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

function woodTexture(): THREE.CanvasTexture {
  const c = document.createElement('canvas');
  c.width = c.height = 512;
  const g = c.getContext('2d')!;
  g.fillStyle = '#D9BC92';
  g.fillRect(0, 0, 512, 512);
  let seed = 7;
  const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  for (let i = 0; i < 140; i++) {
    const y0 = rnd() * 512, amp = 2 + rnd() * 6, freq = 0.004 + rnd() * 0.01, phase = rnd() * 6;
    g.strokeStyle = `rgba(${150 + rnd() * 30 | 0}, ${108 + rnd() * 25 | 0}, ${66 + rnd() * 20 | 0}, ${0.08 + rnd() * 0.16})`;
    g.lineWidth = 0.6 + rnd() * 1.8;
    g.beginPath();
    for (let x = 0; x <= 512; x += 8) {
      const y = y0 + Math.sin(x * freq + phase) * amp;
      if (x === 0) g.moveTo(x, y); else g.lineTo(x, y);
    }
    g.stroke();
  }
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.anisotropy = 8;
  return tex;
}

/** 頂列左側的標誌貼紙：書本圖示、名稱與英文名。 */
async function brandSticker(): Promise<THREE.CanvasTexture> {
  const c = document.createElement('canvas');
  c.width = 840;
  c.height = 240;
  const g = c.getContext('2d')!;
  try {
    const mark = await loadImage('/brand/book-slate-128.png');
    g.drawImage(mark, 40, 40, 160, 160);
  } catch { /* 標誌載入失敗時只顯示文字 */ }
  g.textBaseline = 'middle';
  g.font = '700 78px "Noto Sans TC", sans-serif';
  let x = 228;
  for (const [t, color] of [['救', '#151E27'], ['「舊」', '#627D8D'], ['我的書', '#151E27']] as const) {
    g.fillStyle = color;
    g.fillText(t, x, 100);
    x += g.measureText(t).width;
  }
  g.fillStyle = '#627D8D';
  g.font = '500 46px "Noto Sans TC", sans-serif';
  g.fillText('SaveMyBook', 234, 174);
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 8;
  return tex;
}

/** 平放的書：x 為書寬、z 為書長。 */
function flatBook(color: number) {
  const g = new THREE.Group();
  const cover = new THREE.MeshStandardMaterial({ color, roughness: 0.75 });
  const pages = new THREE.MeshStandardMaterial({ color: 0xf2eee4, roughness: 0.9 });
  const b = new THREE.Mesh(new RoundedBoxGeometry(3.7, 0.5, 5.1, 2, 0.04), [pages, pages, cover, cover, cover, pages]);
  const band = new THREE.Mesh(new THREE.PlaneGeometry(2.4, 0.5), new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.7 }));
  band.rotation.x = -Math.PI / 2;
  band.position.set(-0.2, 0.252, -1.0);
  g.add(b, band);
  return g;
}

export class Cabinet {
  static readonly WIDTH = W;
  static readonly HEIGHT = H;
  static readonly DEPTH = D;
  readonly group = new THREE.Group();
  readonly kiosk: Kiosk;
  readonly doors: Door[] = [];
  readonly anchors: Record<string, THREE.Object3D> = {};
  /** 比對數字在螢幕上的字級與兩字中心距（世界單位），供飛行動畫由螢幕起飛。 */
  readonly digitSize = SCR_H * Kiosk.DIGIT_EM;
  readonly digitGap = SCR_W * Kiosk.DIGIT_GAP;
  private shellMats: THREE.Material[] = [];
  private edges: THREE.LineSegments[] = [];
  private parts = new THREE.Group();
  private deposit: THREE.Group;
  private screenMesh: THREE.Mesh;
  private xrayOn = false;

  /** name：書櫃螢幕頂列顯示的書櫃名稱，與 App 畫面一致。 */
  constructor(name: string) {
    this.kiosk = new Kiosk(name);
    const wood = new THREE.MeshStandardMaterial({ map: woodTexture(), roughness: 0.72, metalness: 0 });
    const inner = new THREE.MeshStandardMaterial({ color: 0xcfb289, roughness: 0.8, metalness: 0 });
    const face = new THREE.MeshPhysicalMaterial({ color: 0xf4f6f7, roughness: 0.3, metalness: 0, clearcoat: 0.8, clearcoatRoughness: 0.12, transparent: true, opacity: 0.94 });
    this.shellMats.push(wood, inner, face);
    const edgeMat = new THREE.LineBasicMaterial({ color: 0x627d8d, transparent: true, opacity: 0 });

    const box = (w: number, h: number, d: number, x: number, y: number, z: number, mat: THREE.Material, r = 0.03) => {
      const m = new THREE.Mesh(new RoundedBoxGeometry(w, h, d, 2, r), mat);
      m.position.set(x, y, z);
      const e = new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.BoxGeometry(w, h, d)), edgeMat);
      e.position.copy(m.position);
      this.edges.push(e);
      this.group.add(m, e);
      return m;
    };

    // 合板櫃體與層板
    box(W, T, D, 0, H / 2 - T / 2, 0, wood);
    box(W, T, D, 0, -H / 2 + T / 2, 0, wood);
    box(T, H - T * 2, D, -W / 2 + T / 2, 0, 0, wood);
    box(T, H - T * 2, D, W / 2 - T / 2, 0, 0, wood);
    box(IN_W, H - T * 2, T, 0, 0, -D / 2 + T / 2, inner);
    for (let i = 0; i < 4; i++) box(IN_W, T, D - T, 0, cellTop(i) + T / 2, T / 2, inner, 0.01);

    // 正面壓克力：挖出螢幕窗與四個櫃門開口
    const shape = new THREE.Shape();
    shape.moveTo(-W / 2, -H / 2);
    shape.lineTo(W / 2, -H / 2);
    shape.lineTo(W / 2, H / 2);
    shape.lineTo(-W / 2, H / 2);
    shape.closePath();
    const hole = (cx: number, cy: number, w: number, h: number) => {
      const p = new THREE.Path();
      p.moveTo(cx - w / 2, cy - h / 2);
      p.lineTo(cx - w / 2, cy + h / 2);
      p.lineTo(cx + w / 2, cy + h / 2);
      p.lineTo(cx + w / 2, cy - h / 2);
      p.closePath();
      shape.holes.push(p);
    };
    hole(screenX, topRowY, SCR_W + 0.06, SCR_H + 0.06);
    for (let i = 0; i < 4; i++) hole(0, cellY(i), IN_W, CELL_H);
    const facePanel = new THREE.Mesh(new THREE.ExtrudeGeometry(shape, { depth: A, bevelEnabled: false }), face);
    facePanel.position.z = D / 2;
    this.group.add(facePanel);
    const faceEdge = new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.BoxGeometry(W, H, A)), edgeMat);
    faceEdge.position.z = D / 2 + A / 2;
    this.edges.push(faceEdge);
    this.group.add(faceEdge);

    // 螢幕（裝在壓克力後方，由螢幕窗露出）
    const bezel = new THREE.Mesh(new RoundedBoxGeometry(BEZEL_W, BEZEL_H, 0.08, 2, 0.04), new THREE.MeshPhysicalMaterial({ color: 0x1d2126, roughness: 0.35, clearcoat: 0.8 }));
    bezel.position.set(screenX, topRowY, D / 2 - 0.05);
    this.screenMesh = new THREE.Mesh(new THREE.PlaneGeometry(SCR_W, SCR_H), new THREE.MeshBasicMaterial({ map: this.kiosk.texture, toneMapped: false }));
    this.screenMesh.position.set(screenX, topRowY, D / 2 - 0.005);
    this.group.add(bezel, this.screenMesh);
    this.anchors.screen = new THREE.Object3D();
    this.anchors.screen.position.set(screenX + BEZEL_W / 2, topRowY, FRONT);
    this.anchors.digits = new THREE.Object3D();
    this.anchors.digits.position.set(screenX + SCR_W * (this.kiosk.digitsAt.x - 0.5), topRowY + SCR_H * (0.5 - this.kiosk.digitsAt.y), FRONT);
    this.group.add(this.anchors.screen, this.anchors.digits);

    // 標誌貼紙
    const stickerW = 3.85, stickerH = 1.1;
    // 貼紙背景透明：不可寫入深度，且一律畫在壓克力之後，否則透明處會把壓克力挖空而露出櫃內木板
    const sticker = new THREE.Mesh(new THREE.PlaneGeometry(stickerW, stickerH), new THREE.MeshBasicMaterial({ transparent: true, depthWrite: false, toneMapped: false }));
    sticker.renderOrder = 1;
    sticker.position.set(-W / 2 + T + 0.3 + stickerW / 2, topRowY, FRONT + 0.004);
    brandSticker().then((tex) => { (sticker.material as THREE.MeshBasicMaterial).map = tex; (sticker.material as THREE.MeshBasicMaterial).needsUpdate = true; });
    this.group.add(sticker);

    // 各格左側板上的鎖扣，門上的電磁鎖關門時扣在這裡
    const lockMat = new THREE.MeshStandardMaterial({ color: 0x4a5258, roughness: 0.45, metalness: 0.5 });
    const strikeMat = new THREE.MeshStandardMaterial({ color: 0x9aa3a9, roughness: 0.3, metalness: 0.8 });
    for (let i = 0; i < 4; i++) {
      const strike = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.5, 0.32), strikeMat);
      strike.position.set(-IN_W / 2 + 0.03, cellY(i), D / 2 - 0.2);
      this.group.add(strike);
    }

    // 櫃內書籍
    const covers = [0x5e8068, 0xa8735f, 0x6f87a8, 0x8a7fa0];
    for (let i = 1; i < 4; i++) {
      const b = flatBook(covers[i]);
      b.position.set(0.55 + (i % 2) * 0.25, cellTop(i) - CELL_H + 0.25, -0.6);
      b.rotation.y = (i % 2 ? 1 : -1) * 0.06;
      this.group.add(b);
    }
    this.deposit = flatBook(covers[0]);
    this.group.add(this.deposit);
    this.setDeposit(0);
    this.anchors.cellA01 = new THREE.Object3D();
    this.anchors.cellA01.position.set(-IN_W / 2, cellTop(0), FRONT);
    this.anchors.screenTop = new THREE.Object3D();
    this.anchors.screenTop.position.set(screenX, topRowY + BEZEL_H / 2, FRONT);
    this.anchors.topCenter = new THREE.Object3D();
    this.anchors.topCenter.position.set(0, H / 2, FRONT);
    this.group.add(this.anchors.screenTop, this.anchors.topCenter);
    this.anchors.topLeft = new THREE.Object3D();
    this.anchors.topLeft.position.set(-W / 2, H / 2, FRONT);
    this.group.add(this.anchors.cellA01, this.anchors.topLeft);

    // 櫃門：透明壓克力，右側鉸鏈
    const doorMat = new THREE.MeshPhysicalMaterial({ color: 0xc9dbe5, roughness: 0.05, metalness: 0, transparent: true, opacity: 0.32, clearcoat: 1, clearcoatRoughness: 0.03, depthWrite: false });
    const rimMat = new THREE.MeshStandardMaterial({ color: 0xa9c0cc, roughness: 0.2, metalness: 0, transparent: true, opacity: 0.95 });
    const sheenMat = new THREE.MeshBasicMaterial({ map: sheenTexture(), transparent: true, depthWrite: false, toneMapped: false });
    const hingeMat = new THREE.MeshStandardMaterial({ color: 0xb7bec4, roughness: 0.3, metalness: 0.8 });
    ['A01', 'A02', 'A03', 'A04'].forEach((name, i) => {
      const dw = IN_W - 0.06, dh = CELL_H - 0.06;
      const pivot = new THREE.Group();
      pivot.position.set(IN_W / 2 - 0.03, cellY(i), D / 2 + A / 2);
      const panelGeo = new THREE.BoxGeometry(dw, dh, A);
      const panel = new THREE.Mesh(panelGeo, doorMat);
      panel.position.x = -dw / 2;
      // 雷射切割的壓克力切邊較亮，以細邊條表現門板輪廓
      const rim = 0.045;
      const rims = [[dw, rim, -dw / 2, dh / 2 - rim / 2], [dw, rim, -dw / 2, -dh / 2 + rim / 2], [rim, dh, -rim / 2, 0], [rim, dh, -dw + rim / 2, 0]].map(([w, h, x, y]) => {
        const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, A + 0.01), rimMat);
        m.position.set(x, y, 0);
        return m;
      });
      const sheen = new THREE.Mesh(new THREE.PlaneGeometry(dw, dh), sheenMat);
      sheen.position.set(-dw / 2, 0, A / 2 + 0.003);
      const tag = new THREE.Mesh(new THREE.PlaneGeometry(0.62, 0.27), new THREE.MeshBasicMaterial({ map: doorPlate(name), toneMapped: false, transparent: true, depthWrite: false }));
      tag.renderOrder = 1;
      tag.position.set(-dw + 0.5, dh / 2 - 0.26, A / 2 + 0.004);
      const lock = new THREE.Mesh(new RoundedBoxGeometry(LOCK.w, LOCK.h, LOCK.d, 2, 0.05), lockMat);
      lock.position.set(-dw + LOCK.inset + LOCK.w / 2, 0, -A / 2 - LOCK.d / 2);
      pivot.add(panel, ...rims, sheen, tag, lock);
      for (const hy of [dh / 2 - 0.3, -dh / 2 + 0.3]) {
        const hinge = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.05, 0.3, 12), hingeMat);
        hinge.position.set(0.02, hy, A / 2 + 0.02);
        pivot.add(hinge);
      }
      this.group.add(pivot);
      this.doors.push({ pivot });
    });

    // 透視時才出現的元件（頂列內的控制電路、各格左側的電磁鎖）
    const partMat = new THREE.MeshStandardMaterial({ color: 0xe9eef1, roughness: 0.6, transparent: true, opacity: 0 });
    const partEdge = new THREE.LineBasicMaterial({ color: 0x3b505c, transparent: true, opacity: 0 });
    const part = (key: string | null, w: number, h: number, d: number, x: number, y: number, z: number) => {
      const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), partMat);
      m.position.set(x, y, z);
      const e = new THREE.LineSegments(new THREE.EdgesGeometry(m.geometry), partEdge);
      e.position.copy(m.position);
      this.parts.add(m, e);
      if (key) {
        const a = new THREE.Object3D();
        a.position.set(x, y, z + d / 2);
        this.anchors[key] = a;
        this.parts.add(a);
      }
    };
    const floor = H / 2 - T - TOP;
    part('power', 2.4, 0.85, 1.8, -2.15, floor + 0.43, 0.6);
    part('relay', 1.4, 0.3, 1.9, -0.25, floor + 0.15, 1.6);
    part('board', 1.72, 0.25, 0.66, 1.2, topRowY + 0.15, 1.8);
    part(null, 0.6, 0.2, 0.9, -0.95, floor + 0.1, 0.4);
    // 外框比電磁鎖本體略大，兩者表面重疊時會閃爍
    for (let i = 0; i < 4; i++) part(i === 1 ? 'locks' : null, LOCK.w + 0.06, LOCK.h + 0.06, LOCK.d + 0.06, lockX, cellY(i), lockZ);
    const wireZ = 1.6, railX = -W / 2 + T + 0.12;
    const pts: number[] = [];
    const seg = (x1: number, y1: number, z1: number, x2: number, y2: number, z2: number) => pts.push(x1, y1, z1, x2, y2, z2);
    seg(-0.95, floor + 0.2, 0.4, -0.95, floor + 0.2, 1.6);
    seg(-0.95, floor + 0.2, 1.6, 0.34, topRowY + 0.15, 1.8);
    seg(1.2, topRowY + 0.15, 2.13, screenX, topRowY, D / 2 - 0.1);
    seg(-0.95, floor + 0.3, wireZ, railX, floor + 0.3, wireZ);
    seg(railX, floor + 0.3, wireZ, railX, cellY(3), wireZ);
    for (let i = 0; i < 4; i++) seg(railX, cellY(i), wireZ, lockX - LOCK.w / 2, cellY(i), lockZ);
    const wg = new THREE.BufferGeometry();
    wg.setAttribute('position', new THREE.Float32BufferAttribute(pts, 3));
    this.parts.add(new THREE.LineSegments(wg, partEdge));
    this.group.add(this.parts);
  }

  /** deposit 0：在櫃門外，1：平放進 A01；withdraw 0→1：再從 A01 取出（取書）。 */
  setDeposit(t: number, withdraw = 0) {
    this.deposit.visible = t > 0.01 && withdraw < 0.99;
    const k = Math.min(1, t) * (1 - withdraw);
    const out = 1 - k;
    this.deposit.position.set(0.6 - out * 0.9, cellTop(0) - CELL_H + 0.25 + out * 0.35, -0.6 + out * 7.4);
    this.deposit.rotation.set(-out * 0.18, out * 0.2, 0);
  }

  setDoor(i: number, open: number) {
    this.doors[i].pivot.rotation.y = open * 1.65;
  }

  setXray(t: number) {
    const on = t > 0.002;
    if (on !== this.xrayOn) {
      for (const m of this.shellMats) { m.transparent = on || m === this.shellMats[2]; m.depthWrite = !on; m.needsUpdate = true; }
      this.xrayOn = on;
    }
    (this.shellMats[0] as THREE.MeshStandardMaterial).opacity = 1 - t * 0.9;
    (this.shellMats[1] as THREE.MeshStandardMaterial).opacity = 1 - t * 0.9;
    (this.shellMats[2] as THREE.MeshPhysicalMaterial).opacity = 0.94 * (1 - t * 0.9);
    for (const e of this.edges) (e.material as THREE.LineBasicMaterial).opacity = t * 0.55;
    this.parts.traverse((o) => {
      const mat = (o as THREE.Mesh).material as THREE.Material | undefined;
      if (mat) mat.opacity = t;
    });
    this.screenMesh.renderOrder = on ? 5 : 0;
  }
}
