import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/examples/jsm/geometries/RoundedBoxGeometry.js';
import { Kiosk, doorPlate, loadImage } from './textures';
import { roundedRect } from './phone';

/** 外觀比照介紹動畫：白色機身、上方螢幕、2×2 玻璃櫃門 A01–A04。單位約為 10 公分。 */
const W = 6.2;
const H = 11.4;
const D = 3.6;
const HEAD = 4.5;
const BASE = 0.3;
const WALL = 0.2;
const MID = 0.16;

interface Door { pivot: THREE.Group; light: THREE.Mesh<THREE.CircleGeometry, THREE.MeshBasicMaterial> }

async function brandLabel(): Promise<THREE.CanvasTexture> {
  const c = document.createElement('canvas');
  c.width = 720;
  c.height = 110;
  const g = c.getContext('2d')!;
  try {
    const mark = await loadImage('/brand/book-slate-128.png');
    g.drawImage(mark, 150, 22, 66, 66);
  } catch { /* 標誌載入失敗時只顯示文字 */ }
  g.textBaseline = 'middle';
  g.font = '700 46px "Noto Sans TC", sans-serif';
  let x = 232;
  for (const [t, color] of [['救', '#151E27'], ['「舊」', '#627D8D'], ['我的書', '#151E27']] as const) {
    g.fillStyle = color;
    g.fillText(t, x, 58);
    x += g.measureText(t).width;
  }
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 8;
  return tex;
}

export class Cabinet {
  readonly group = new THREE.Group();
  readonly kiosk = new Kiosk();
  readonly doors: Door[] = [];
  readonly anchors: Record<string, THREE.Object3D> = {};
  private shellMats: THREE.MeshPhysicalMaterial[] = [];
  private edges: THREE.LineSegments[] = [];
  private parts = new THREE.Group();
  private wires: THREE.LineSegments;
  private deposit: THREE.Group;
  private screenMesh: THREE.Mesh;
  private xrayOn = false;

  constructor() {
    const white = new THREE.MeshPhysicalMaterial({ color: 0xf4f6f8, roughness: 0.48, metalness: 0, clearcoat: 0.35, clearcoatRoughness: 0.4 });
    const inner = new THREE.MeshPhysicalMaterial({ color: 0xe4e9ed, roughness: 0.7, metalness: 0 });
    this.shellMats.push(white, inner);
    const edgeMat = new THREE.LineBasicMaterial({ color: 0x627d8d, transparent: true, opacity: 0 });

    const box = (w: number, h: number, d: number, x: number, y: number, z: number, mat = white, r = 0.05) => {
      const m = new THREE.Mesh(new RoundedBoxGeometry(w, h, d, 3, r), mat);
      m.position.set(x, y, z);
      const e = new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.BoxGeometry(w, h, d)), edgeMat);
      e.position.copy(m.position);
      this.edges.push(e);
      this.group.add(m, e);
      return m;
    };

    const lowH = H - HEAD - BASE;
    const lowY = -H / 2 + BASE + lowH / 2;
    box(W, HEAD, D, 0, H / 2 - HEAD / 2, 0, white, 0.14);
    box(W, BASE, D, 0, -H / 2 + BASE / 2, 0, white, 0.08);
    box(WALL, lowH, D, -W / 2 + WALL / 2, lowY, 0);
    box(WALL, lowH, D, W / 2 - WALL / 2, lowY, 0);
    box(MID, lowH, D - 0.1, 0, lowY, -0.05, inner, 0.03);
    box(W - WALL * 2, MID, D - 0.1, 0, lowY, -0.05, inner, 0.03);
    box(W - WALL * 2, lowH, 0.12, 0, lowY, -D / 2 + 0.06, inner, 0.02);

    // 螢幕
    const bezel = new THREE.Mesh(new RoundedBoxGeometry(3.15, 3.95, 0.14, 4, 0.18), new THREE.MeshPhysicalMaterial({ color: 0x23292f, roughness: 0.35, clearcoat: 0.8 }));
    bezel.position.set(0, H / 2 - 0.35 - 3.95 / 2, D / 2 + 0.04);
    this.screenMesh = new THREE.Mesh(new THREE.PlaneGeometry(2.88, 3.84), new THREE.MeshBasicMaterial({ map: this.kiosk.texture, toneMapped: false }));
    this.screenMesh.position.set(0, bezel.position.y - 0.02, D / 2 + 0.115);
    this.group.add(bezel, this.screenMesh);
    this.anchors.screen = new THREE.Object3D();
    this.anchors.screen.position.set(1.6, bezel.position.y, D / 2 + 0.1);
    this.anchors.digits = new THREE.Object3D();
    this.anchors.digits.position.set(0, this.screenMesh.position.y + 3.84 * (0.5 - this.kiosk.digitsAt.y), D / 2 + 0.12);

    // 標誌
    const label = new THREE.Mesh(new THREE.PlaneGeometry(3.6, 0.55), new THREE.MeshBasicMaterial({ transparent: true, toneMapped: false }));
    label.position.set(0, H / 2 - HEAD + 0.36, D / 2 + 0.005);
    brandLabel().then((tex) => { (label.material as THREE.MeshBasicMaterial).map = tex; (label.material as THREE.MeshBasicMaterial).needsUpdate = true; });
    this.group.add(label);
    this.group.add(this.anchors.screen, this.anchors.digits);

    // 櫃內書籍
    const cellW = (W - WALL * 2 - MID) / 2;
    const cellH = (lowH - MID) / 2;
    const cell = (i: number) => {
      const col = i % 2, row = Math.floor(i / 2);
      return new THREE.Vector3(-W / 2 + WALL + cellW / 2 + col * (cellW + MID), lowY + (cellH + MID) / 2 * (row === 0 ? 1 : -1), 0);
    };
    const bookMesh = (color: number) => {
      const g = new THREE.Group();
      const b = new THREE.Mesh(new RoundedBoxGeometry(1.32, 1.86, 0.3, 2, 0.03), new THREE.MeshStandardMaterial({ color, roughness: 0.75 }));
      const band = new THREE.Mesh(new THREE.PlaneGeometry(0.9, 0.12), new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.75 }));
      band.position.set(-0.05, 0.45, 0.152);
      const band2 = band.clone();
      band2.scale.set(0.55, 1, 1);
      band2.position.set(-0.24, 0.28, 0.152);
      g.add(b, band, band2);
      return g;
    };
    const covers = [0x5e8068, 0xa8735f, 0x6f87a8, 0x8a7fa0];
    for (let i = 1; i < 4; i++) {
      const b = bookMesh(covers[i]);
      const p = cell(i);
      b.position.set(p.x + 0.38, p.y - cellH / 2 + 0.98, -0.25);
      b.rotation.y = -0.5;
      this.group.add(b);
    }
    this.deposit = bookMesh(covers[0]);
    this.group.add(this.deposit);
    this.setDeposit(0);
    this.anchors.cellA01 = new THREE.Object3D();
    this.anchors.cellA01.position.copy(cell(0)).add(new THREE.Vector3(-cellW / 2, cellH / 2, D / 2));
    this.group.add(this.anchors.cellA01);

    // 櫃門
    const frameMat = new THREE.MeshPhysicalMaterial({ color: 0xd9e0e5, roughness: 0.4, metalness: 0.1, clearcoat: 0.4 });
    const glassMat = new THREE.MeshPhysicalMaterial({ color: 0xdfe8ee, roughness: 0.06, metalness: 0, transparent: true, opacity: 0.22, clearcoat: 1, clearcoatRoughness: 0.03, depthWrite: false });
    const streakMat = new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.32, depthWrite: false });
    ['A01', 'A02', 'A03', 'A04'].forEach((name, i) => {
      const p = cell(i);
      const dw = cellW - 0.12, dh = cellH - 0.12;
      const pivot = new THREE.Group();
      pivot.position.set(p.x - dw / 2, p.y, D / 2 + 0.06);
      const shape = roundedRect(dw, dh, 0.16);
      shape.holes.push(roundedRect(dw - 0.24, dh - 0.24, 0.09) as unknown as THREE.Path);
      const frame = new THREE.Mesh(new THREE.ExtrudeGeometry(shape, { depth: 0.06, bevelEnabled: true, bevelThickness: 0.02, bevelSize: 0.02, bevelSegments: 2, curveSegments: 10 }), frameMat);
      frame.position.x = dw / 2;
      const glass = new THREE.Mesh(new THREE.PlaneGeometry(dw - 0.22, dh - 0.22), glassMat);
      glass.position.set(dw / 2, 0, 0.04);
      const s1 = new THREE.Mesh(new THREE.PlaneGeometry(0.16, dh * 0.9), streakMat);
      s1.position.set(dw * 0.66, 0, 0.045);
      s1.rotation.z = -0.32;
      const s2 = new THREE.Mesh(new THREE.PlaneGeometry(0.06, dh * 0.8), streakMat);
      s2.position.set(dw * 0.78, 0, 0.045);
      s2.rotation.z = -0.32;
      const tag = new THREE.Mesh(new THREE.PlaneGeometry(0.62, 0.27), new THREE.MeshBasicMaterial({ map: doorPlate(name), toneMapped: false, transparent: true }));
      tag.position.set(0.5, dh / 2 - 0.3, 0.05);
      const latch = new THREE.Mesh(new THREE.PlaneGeometry(0.14, 0.24), new THREE.MeshBasicMaterial({ color: 0x3b505c }));
      latch.position.set(dw - 0.2, dh / 2 - 0.42, 0.05);
      latch.visible = i === 0;
      pivot.add(frame, glass, s1, s2, tag, latch);
      const light = new THREE.Mesh(new THREE.CircleGeometry(0.055, 20), new THREE.MeshBasicMaterial({ color: 0xb9c3ca }));
      light.position.set(i % 2 === 0 ? p.x + cellW / 2 + MID / 2 : p.x - cellW / 2 - MID / 2, p.y + (i % 2 === 0 ? 0.1 : -0.1), D / 2 + 0.03);
      light.visible = i % 2 === 0;
      this.group.add(pivot, light);
      this.doors.push({ pivot, light });
    });

    // 透視時才出現的元件
    const partMat = new THREE.MeshStandardMaterial({ color: 0xe9eef1, roughness: 0.6, transparent: true, opacity: 0 });
    const partEdge = new THREE.LineBasicMaterial({ color: 0x3b505c, transparent: true, opacity: 0 });
    const part = (key: string, w: number, h: number, d: number, x: number, y: number, z: number) => {
      const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), partMat);
      m.position.set(x, y, z);
      const e = new THREE.LineSegments(new THREE.EdgesGeometry(m.geometry), partEdge);
      e.position.copy(m.position);
      this.parts.add(m, e);
      const a = new THREE.Object3D();
      a.position.set(x, y, z + d / 2);
      this.anchors[key] = a;
      this.parts.add(a);
    };
    part('relay', 1.0, 0.62, 0.3, -2.1, H / 2 - 0.75, 0.6);
    part('board', 1.0, 0.62, 0.3, 2.1, H / 2 - 0.75, 0.6);
    part('locks', 0.16, 0.6, 0.3, 0, lowY + cellH / 2 + MID / 2, D / 2 - 0.3);
    part('lock2', 0.16, 0.6, 0.3, 0, lowY - cellH / 2 - MID / 2, D / 2 - 0.3);
    part('power', 1.3, 0.24, 0.6, -0.2, -H / 2 + 0.16, 0.6);
    const wirePts = [
      -2.1, H / 2 - 1.05, 0.6, -2.1, H / 2 - HEAD + 0.2, 0.6,
      -2.1, H / 2 - HEAD + 0.2, 0.6, 0, H / 2 - HEAD + 0.2, 0.6,
      0, H / 2 - HEAD + 0.2, 0.6, 0, lowY - cellH / 2 - MID / 2, 0.6,
      2.1, H / 2 - 1.05, 0.6, 2.1, -H / 2 + 0.16, 0.6,
      2.1, -H / 2 + 0.16, 0.6, 0.45, -H / 2 + 0.16, 0.6,
      1.6, H / 2 - 0.75, 0.6, 1.0, H / 2 - 0.75, 0.6,
    ];
    const wg = new THREE.BufferGeometry();
    wg.setAttribute('position', new THREE.Float32BufferAttribute(wirePts, 3));
    this.wires = new THREE.LineSegments(wg, partEdge);
    this.parts.add(this.wires);
    this.group.add(this.parts);
  }

  private cellCenter(i: number) {
    const lowH = H - HEAD - BASE;
    const lowY = -H / 2 + BASE + lowH / 2;
    const cellW = (W - WALL * 2 - MID) / 2;
    const cellH = (lowH - MID) / 2;
    const col = i % 2, row = Math.floor(i / 2);
    return { x: -W / 2 + WALL + cellW / 2 + col * (cellW + MID), y: lowY + (cellH + MID) / 2 * (row === 0 ? 1 : -1), cellH };
  }

  /** 0：在櫃門外，1：放進 A01。 */
  setDeposit(t: number) {
    const c = this.cellCenter(0);
    this.deposit.visible = t > 0.01;
    const k = Math.min(1, t);
    this.deposit.position.set(c.x + 0.3 - (1 - k) * 0.6, c.y - c.cellH / 2 + 0.98 + (1 - k) * 0.5, -0.25 + (1 - k) * 3.6);
    this.deposit.rotation.set(0, -0.5 * k, (1 - k) * 0.25);
  }

  setDoor(i: number, open: number) {
    const d = this.doors[i];
    d.pivot.rotation.y = -open * 1.85;
    (d.light.material as THREE.MeshBasicMaterial).color.set(open > 0.02 ? 0x3ccf8e : 0xb9c3ca);
  }

  setXray(t: number) {
    const on = t > 0.002;
    if (on !== this.xrayOn) {
      for (const m of this.shellMats) { m.transparent = on; m.depthWrite = !on; m.needsUpdate = true; }
      this.xrayOn = on;
    }
    for (const m of this.shellMats) m.opacity = 1 - t * 0.9;
    for (const e of this.edges) (e.material as THREE.LineBasicMaterial).opacity = t * 0.55;
    this.parts.traverse((o) => {
      const mat = (o as THREE.Mesh).material as THREE.Material | undefined;
      if (mat) mat.opacity = t;
    });
    this.screenMesh.renderOrder = on ? 5 : 0;
  }
}
