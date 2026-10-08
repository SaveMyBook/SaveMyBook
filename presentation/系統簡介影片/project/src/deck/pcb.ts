import '@fontsource/ibm-plex-mono/500.css';
import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/examples/jsm/geometries/RoundedBoxGeometry.js';

/**
 * DoorLock ESP32-S3 主控板 Rev A 的立體模型。
 * 元件配置依 KiCad 3D 檢視截圖：以 U1 排母（腳距 2.54、排距 22.86 公釐）為尺標換算，板子約 130 × 80 公釐。
 *
 * 座標：原點在板子底面中心；+x 朝端子台（右緣），+z 朝前緣排針（J7–J10、J6），+y 朝上。
 * 內部以公釐建模，再依 scale 縮放；預設與書櫃模型相同的單位（1 單位 = 4 公分）。
 */
export const PCB_SIZE = { w: 130, d: 80, t: 1.6 } as const;
/** 每公釐對應的世界單位。 */
export const PCB_SCALE = { mm: 1, cm: 0.1, cabinet: 1 / 40 } as const;

export type PcbRegion = 'power' | 'mcu' | 'driver' | 'relay' | 'lock' | 'door' | 'tft' | 'led';

const refs = (p: string, a: number, b: number) => Array.from({ length: b - a + 1 }, (_, i) => `${p}${a + i}`);

export const PCB_REGIONS: Record<PcbRegion, { label: string; refs: string[] }> = {
  power: { label: '電源區', refs: ['J5', 'C1', 'U4', 'C2', 'C3', 'C4'] },
  mcu: { label: 'ESP32 插座', refs: ['U1'] },
  driver: { label: '光耦驅動區', refs: [...refs('U', 5, 8), ...refs('Q', 1, 4), ...refs('R', 1, 8), ...refs('D', 5, 8)] },
  relay: { label: '繼電器', refs: refs('K', 1, 4) },
  lock: { label: '電磁鎖端子', refs: refs('J', 1, 4) },
  door: { label: '門磁排針', refs: refs('J', 7, 10) },
  tft: { label: '螢幕排針', refs: ['J6'] },
  led: { label: '指示燈', refs: refs('D', 9, 12) },
};

export interface PcbOptions {
  /** 每公釐的世界單位，預設 PCB_SCALE.cabinet。 */
  scale?: number;
  /** U1 排母上插著 ESP32-S3-DevKitC-1（之後可用 setPcbEsp32 切換）。 */
  esp32?: boolean;
  /** 元件投射陰影、板面接收陰影；renderer.shadowMap 需另外開啟。 */
  shadows?: boolean;
}

export interface PcbData {
  /** 絲印字型載入並重畫貼圖後完成。 */
  ready: Promise<void>;
  /** 元件標號 → 元件物件（U1 為兩排排母）。 */
  parts: Map<string, THREE.Object3D>;
  /** 插在 U1 上的開發板。 */
  devkit: THREE.Object3D;
}

/* ------------------------------------------------------------------ */
/* 版面（公釐；X 由左緣向右、Y 由後緣向前）                             */
/* ------------------------------------------------------------------ */

const W = PCB_SIZE.w;
const D = PCB_SIZE.d;
const T = PCB_SIZE.t;
/** 四路驅動的中心線 Y（後→前：K1–K4）。 */
const CH = [7.4, 26.8, 46.2, 65.6];
const U_X = 80.2;
const K_X = 100.5;
const K_DY = 1.5;
const TB_X = 124.5;
const DL_X = 115;
/** D1–D4 中心相對於繼電器中心線的位移。 */
const DL_DY = 1.6;
const P = 2.54;
const U1_X0 = 6;
const U1_FRONT = 48;
const U1_BACK = U1_FRONT - 22.86;
const HDR_Y = 75.6;
const DOOR_X = [8.3, 18.5, 28.7, 38.9];
const J6_X0 = 46.7;
const C1_AT = { x: 24.3, y: 6.2, r: 5, h: 16 };
const C2_AT = { x: 51.5, y: 5.3, r: 4, h: 11.5 };
const U4_AT = { x: 39.2, y: 9.6 };
const JP1_AT = { x: 62.87, y: 7.2 };
const J5_AT = { x: 5.0, y: 4.7 };
/** ESP32-S3-DevKitC-1：板長 66、寬 25.4，下緣在板面上方 11（排母 8.5＋公排針塑膠 2.5）。 */
const DEV = { x: U1_X0 + P * 10.5, y: (U1_FRONT + U1_BACK) / 2, l: 66, w: 25.4, z0: 11, t: 1.6 };

const u1Front = (n: number) => ({ x: U1_X0 + P * (n - 1), y: U1_FRONT });
const u1Back = (n: number) => ({ x: U1_X0 + P * (n - 23), y: U1_BACK });
/** 每一路的小元件位置（相對於 PC815 中心）。 */
const CHP = {
  ra: { x: -8.2, y: -3.0 },
  led: { x: -8.2, y: 0.5 },
  rb: { x: -2.2, y: 4.6 },
  q: { x: 2.0, y: 5.0 },
  df: { x: 8.1, y: 0.0 },
};
/** 繼電器腳位（相對於繼電器中心；線圈端朝驅動區）。 */
const RELAY_PINS = [
  { x: -6.05, y: 0 }, { x: -4.05, y: -6 }, { x: -4.05, y: 6 }, { x: 6.05, y: -6 }, { x: 6.05, y: 6 },
];

/* ------------------------------------------------------------------ */
/* 貼圖                                                                */
/* ------------------------------------------------------------------ */

const FONT = '"IBM Plex Mono", Menlo, monospace';
const COLORS = {
  mask: '#0F3A26',
  trace: '#17503A',
  pad: '#D2AA5A',
  silk: '#EEF1EC',
  hole: '#0E1611',
};

/** 板面貼圖：顏色一張、粗糙度／金屬度一張（G＝粗糙度、B＝金屬度），單位公釐。 */
class Sheet {
  readonly color = document.createElement('canvas');
  readonly orm = document.createElement('canvas');
  readonly c: CanvasRenderingContext2D;
  readonly o: CanvasRenderingContext2D;
  constructor(readonly w: number, readonly h: number, readonly k: number, base: string, rough = 0.55) {
    this.color.width = this.orm.width = Math.round(w * k);
    this.color.height = this.orm.height = Math.round(h * k);
    this.c = this.color.getContext('2d')!;
    this.o = this.orm.getContext('2d')!;
    this.c.fillStyle = base;
    this.c.fillRect(0, 0, this.color.width, this.color.height);
    this.o.fillStyle = this.ormStyle(rough, 0);
    this.o.fillRect(0, 0, this.orm.width, this.orm.height);
  }
  ormStyle(rough: number, metal: number) { return `rgb(255,${Math.round(rough * 255)},${Math.round(metal * 255)})`; }
  private both(fn: (g: CanvasRenderingContext2D, isOrm: boolean) => void) {
    fn(this.c, false);
    fn(this.o, true);
  }
  rect(x: number, y: number, w: number, h: number, color: string, rough?: number, metal = 0, r = 0) {
    const k = this.k;
    this.both((g, isOrm) => {
      if (isOrm && rough === undefined) return;
      g.fillStyle = isOrm ? this.ormStyle(rough!, metal) : color;
      g.beginPath();
      g.roundRect((x - w / 2) * k, (y - h / 2) * k, w * k, h * k, r * k);
      g.fill();
    });
  }
  circle(x: number, y: number, r: number, color: string, rough?: number, metal = 0) {
    const k = this.k;
    this.both((g, isOrm) => {
      if (isOrm && rough === undefined) return;
      g.fillStyle = isOrm ? this.ormStyle(rough!, metal) : color;
      g.beginPath();
      g.arc(x * k, y * k, r * k, 0, Math.PI * 2);
      g.fill();
    });
  }
  line(pts: [number, number][], width: number, color: string, rough?: number) {
    const k = this.k;
    this.both((g, isOrm) => {
      if (isOrm && rough === undefined) return;
      g.strokeStyle = isOrm ? this.ormStyle(rough!, 0) : color;
      g.lineWidth = width * k;
      g.lineCap = 'round';
      g.lineJoin = 'round';
      g.beginPath();
      pts.forEach(([x, y], i) => (i ? g.lineTo(x * k, y * k) : g.moveTo(x * k, y * k)));
      g.stroke();
    });
  }
  outline(x: number, y: number, w: number, h: number, width = 0.15) {
    const k = this.k;
    this.both((g, isOrm) => {
      g.strokeStyle = isOrm ? this.ormStyle(0.8, 0) : COLORS.silk;
      g.lineWidth = width * k;
      g.strokeRect((x - w / 2) * k, (y - h / 2) * k, w * k, h * k);
    });
  }
  ring(x: number, y: number, r: number, width = 0.15) {
    const k = this.k;
    this.both((g, isOrm) => {
      g.strokeStyle = isOrm ? this.ormStyle(0.8, 0) : COLORS.silk;
      g.lineWidth = width * k;
      g.beginPath();
      g.arc(x * k, y * k, r * k, 0, Math.PI * 2);
      g.stroke();
    });
  }
  text(s: string, x: number, y: number, size: number, rot = 0, color = COLORS.silk, weight = 500, align: CanvasTextAlign = 'center') {
    const k = this.k;
    this.both((g, isOrm) => {
      g.save();
      g.translate(x * k, y * k);
      g.rotate(rot);
      g.font = `${weight} ${size * k}px ${FONT}`;
      g.textAlign = align;
      g.textBaseline = 'middle';
      g.fillStyle = isOrm ? this.ormStyle(0.8, 0) : color;
      g.fillText(s, 0, 0);
      g.restore();
    });
  }
  textures() {
    const map = new THREE.CanvasTexture(this.color);
    map.colorSpace = THREE.SRGBColorSpace;
    map.anisotropy = 16;
    const orm = new THREE.CanvasTexture(this.orm);
    orm.anisotropy = 16;
    return { map, orm };
  }
}

/** 透明底的印字貼圖（元件表面的雷射印字、絲印）。 */
function decal(wMm: number, hMm: number, k: number, draw: (g: CanvasRenderingContext2D, k: number) => void) {
  const c = document.createElement('canvas');
  c.width = Math.round(wMm * k);
  c.height = Math.round(hMm * k);
  const g = c.getContext('2d')!;
  draw(g, k);
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 16;
  return { tex, redraw: () => { g.clearRect(0, 0, c.width, c.height); draw(g, k); tex.needsUpdate = true; } };
}

/* ------------------------------------------------------------------ */
/* 材質與基本形狀                                                      */
/* ------------------------------------------------------------------ */

function makeMats() {
  const std = (color: number, roughness: number, metalness = 0) => new THREE.MeshStandardMaterial({ color, roughness, metalness });
  const mats = {
    plastic: std(0x1c1e21, 0.55),
    header: std(0x18191b, 0.58),
    epoxy: std(0x17181b, 0.42),
    gold: std(0xdcb66b, 0.26, 1),
    tin: std(0xc8cdd2, 0.28, 1),
    alu: std(0xd9dde0, 0.3, 0.85),
    relay: new THREE.MeshPhysicalMaterial({ color: 0x2760b2, roughness: 0.42, clearcoat: 0.25, clearcoatRoughness: 0.4 }),
    relayBase: std(0x1d2226, 0.6),
    terminal: std(0x2b7a4b, 0.55),
    terminalDark: std(0x0c1a11, 0.85),
    hole: std(0x0a0b0c, 0.9),
    resistor: std(0x1b1c1d, 0.5),
    mlcc: std(0xa07d56, 0.55),
    ledBase: std(0xeeece6, 0.45),
    ledLens: new THREE.MeshPhysicalMaterial({ color: 0xf7ece0, roughness: 0.1, clearcoat: 1, clearcoatRoughness: 0.05 }),
    band: std(0xbcc1c6, 0.5),
    edge: std(0x6e6744, 0.75),
    bottom: std(0x0f3a26, 0.55),
    capSleeve: std(0x2a5da6, 0.35),
    rubber: std(0x2a2b2d, 0.8),
    devPcb: std(0x141619, 0.5),
    devEdge: std(0x3a3a33, 0.7),
    modPcb: std(0x1c2530, 0.5),
    shield: std(0xc9ced3, 0.32, 0.9),
    usb: std(0xcfd4d8, 0.24, 1),
    button: std(0x1a1b1c, 0.5),
    white: std(0xefefea, 0.5),
  };
  for (const [k, v] of Object.entries(mats)) v.name = k;
  return mats;
}
type Mats = ReturnType<typeof makeMats>;

function boxMesh(w: number, h: number, d: number, mat: THREE.Material | THREE.Material[], r = 0) {
  const geo = r > 0 ? new RoundedBoxGeometry(w, h, d, 2, Math.min(r, w / 2, h / 2, d / 2) * 0.999) : new THREE.BoxGeometry(w, h, d);
  return new THREE.Mesh(geo, mat);
}

/** 由底面算起放置的方塊。 */
function block(parent: THREE.Object3D, w: number, h: number, d: number, x: number, y0: number, z: number, mat: THREE.Material | THREE.Material[], r = 0) {
  const m = boxMesh(w, h, d, mat, r);
  m.position.set(x, y0 + h / 2, z);
  parent.add(m);
  return m;
}

function decalPlane(parent: THREE.Object3D, w: number, d: number, x: number, y: number, z: number, tex: THREE.Texture, rough = 0.6, face: 'up' | 'front' = 'up') {
  const mat = new THREE.MeshStandardMaterial({ map: tex, transparent: true, roughness: rough, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2 });
  const m = new THREE.Mesh(new THREE.PlaneGeometry(w, d), mat);
  if (face === 'up') m.rotation.x = -Math.PI / 2;
  m.position.set(x, y, z);
  m.renderOrder = 1;
  m.userData.decal = true;
  parent.add(m);
  return m;
}

/* ------------------------------------------------------------------ */
/* 元件                                                                */
/* ------------------------------------------------------------------ */

/** 0805 等片狀元件：長軸沿 x。 */
function chip(g: THREE.Group, m: Mats, L: number, Wd: number, H: number, body: THREE.Material) {
  const e = L * 0.2;
  block(g, L - e * 2 + 0.02, H, Wd, 0, 0, 0, body);
  for (const s of [-1, 1]) block(g, e, H + 0.02, Wd + 0.02, s * (L / 2 - e / 2), 0, 0, m.tin);
}

function led0805(g: THREE.Group, m: Mats) {
  block(g, 2.0, 0.32, 1.25, 0, 0, 0, m.ledBase);
  for (const s of [-1, 1]) block(g, 0.32, 0.34, 1.27, s * 0.84, 0, 0, m.tin);
  block(g, 1.3, 0.42, 1.05, 0, 0.3, 0, m.ledLens, 0.18);
}

/** SOT-23：本體長軸沿 z，兩腳在 -x、一腳在 +x。 */
function sot23(g: THREE.Group, m: Mats) {
  block(g, 1.3, 0.95, 2.9, 0, 0.08, 0, m.epoxy, 0.08);
  const lead = (x: number, z: number, s: number) => {
    block(g, 0.5, 0.14, 0.42, x + s * 0.2, 0.45, z, m.tin);
    block(g, 0.14, 0.5, 0.42, x + s * 0.45, 0, z, m.tin);
    block(g, 0.4, 0.12, 0.42, x + s * 0.62, 0, z, m.tin);
  };
  lead(-0.65, -0.95, -1);
  lead(-0.65, 0.95, -1);
  lead(0.65, 0, 1);
}

/** SMA 二極體：長軸沿 z，陰極環在 -z。 */
function sma(g: THREE.Group, m: Mats) {
  block(g, 2.6, 2.0, 3.6, 0, 0.12, 0, m.epoxy, 0.18);
  block(g, 2.62, 0.02, 0.7, 0, 2.11, -1.25, m.band);
  for (const s of [-1, 1]) {
    block(g, 1.5, 1.05, 0.16, 0, 0.12, s * 1.88, m.tin);
    block(g, 1.5, 0.14, 1.0, 0, 0, s * 2.3, m.tin);
  }
}

/** PC815（DIP-4）：兩排腳沿 x 相距 7.62，第 1 腳在 (-x, -z)。 */
function dip4(g: THREE.Group, m: Mats, mark: THREE.Texture) {
  block(g, 6.4, 3.3, 4.6, 0, 0.6, 0, m.epoxy, 0.25);
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
    block(g, 0.75, 0.25, 0.9, sx * 3.55, 1.7, sz * P / 2, m.tin);
    block(g, 0.26, 1.95, 0.5, sx * 3.81, 0, sz * P / 2, m.tin);
  }
  const dot = new THREE.Mesh(new THREE.CircleGeometry(0.42, 20), m.hole);
  dot.rotation.x = -Math.PI / 2;
  dot.position.set(-2.3, 3.905, -1.4);
  g.add(dot);
  decalPlane(g, 5.6, 2.2, 0.5, 3.906, 0.55, mark, 0.6);
}

/** TO-220 直立：腳排沿 x，金屬散熱片在 -z。 */
function to220(g: THREE.Group, m: Mats, mark: THREE.Texture) {
  const stand = 3.0;
  for (let i = -1; i <= 1; i++) {
    block(g, 0.8, stand, 0.5, i * P, 0, 0, m.tin);
    block(g, 1.4, 1.0, 0.5, i * P, stand - 0.9, 0, m.tin);
  }
  block(g, 10.0, 9.2, 3.2, 0, stand, 0, m.epoxy, 0.25);
  const tab = new THREE.Shape();
  tab.moveTo(-5, 0);
  tab.lineTo(5, 0);
  tab.lineTo(5, 15.6);
  tab.lineTo(-5, 15.6);
  tab.closePath();
  const hole = new THREE.Path();
  hole.absarc(0, 12.8, 1.8, 0, Math.PI * 2, true);
  tab.holes.push(hole);
  const tabMesh = new THREE.Mesh(new THREE.ExtrudeGeometry(tab, { depth: 1.3, bevelEnabled: true, bevelThickness: 0.08, bevelSize: 0.08, bevelSegments: 1, curveSegments: 32 }), m.tin);
  tabMesh.position.set(0, stand, -2.9);
  g.add(tabMesh);
  const front = decalPlane(g, 8.6, 3.0, 0, stand + 5.6, 1.601, mark, 0.5, 'front');
  front.rotation.set(0, 0, 0);
}

/** DC 插座（PJ-063AH）：長軸沿 z，插孔朝 -z（板子後緣）。 */
function barrelJack(g: THREE.Group, m: Mats) {
  block(g, 9.0, 11.0, 14.4, 0, 0, 0, m.plastic, 0.45);
  const collar = new THREE.Mesh(new THREE.CylinderGeometry(4.0, 4.0, 0.6, 40), m.plastic);
  collar.rotation.x = Math.PI / 2;
  collar.position.set(0, 6.3, -7.35);
  const mouth = new THREE.Mesh(new THREE.CircleGeometry(3.15, 40), m.hole);
  mouth.rotation.y = Math.PI;
  mouth.position.set(0, 6.3, -7.66);
  const pin = new THREE.Mesh(new THREE.CylinderGeometry(1.0, 1.0, 1.4, 20), m.tin);
  pin.rotation.x = Math.PI / 2;
  pin.position.set(0, 6.3, -7.0);
  g.add(collar, mouth, pin);
  for (const x of [-2.4, 0, 2.4]) block(g, 1.1, 3.6, 0.35, x, 0, 7.3, m.tin);
  block(g, 6.4, 0.5, 1.2, 0, 10.9, 4.0, m.plastic, 0.2);
}

/** 鋁質電解電容：套管顏色帶負極白條，頂部鋁蓋有防爆刻痕。 */
function eCap(g: THREE.Group, m: Mats, r: number, h: number, stripeDir: number) {
  const prof: [number, number][] = [
    [r - 0.35, 0], [r, 0.35], [r, h - 1.9], [r - 0.24, h - 1.55], [r, h - 1.2], [r, h - 0.45], [r - 0.45, h], [r - 0.95, h],
  ];
  // 依弧長重新取樣，讓貼圖 v 與高度大致成正比
  const segLen = prof.slice(1).map(([x, y], i) => Math.hypot(x - prof[i][0], y - prof[i][1]));
  const total = segLen.reduce((a, b) => a + b, 0);
  const pts: THREE.Vector2[] = [];
  const N = 48;
  for (let j = 0; j < N; j++) {
    let s = (j / (N - 1)) * total;
    let i = 0;
    while (i < segLen.length - 1 && s > segLen[i]) { s -= segLen[i]; i++; }
    const f = Math.min(1, s / segLen[i]);
    pts.push(new THREE.Vector2(prof[i][0] + (prof[i + 1][0] - prof[i][0]) * f, prof[i][1] + (prof[i + 1][1] - prof[i][1]) * f));
  }
  const tex = decal(2 * Math.PI * r, total, 40, (c, k) => {
    c.fillStyle = '#2B5FA8';
    c.fillRect(0, 0, c.canvas.width, c.canvas.height);
    const sw = 2 * Math.PI * r * 0.14;
    const sx = c.canvas.width / 2 - (sw * k) / 2;
    c.fillStyle = '#C9CED3';
    c.fillRect(sx, 0, sw * k, c.canvas.height);
    c.fillStyle = '#2B5FA8';
    const body0 = 0.6, body1 = h - 2.3;
    for (let y = body0 + 1.2; y < body1 - 0.6; y += 2.6) {
      const py = (total - y) * k;
      c.fillRect(c.canvas.width / 2 - 0.55 * k, py - 0.18 * k, 1.1 * k, 0.36 * k);
    }
  }).tex;
  tex.anisotropy = 16;
  const sleeve = new THREE.Mesh(new THREE.LatheGeometry(pts, 64), new THREE.MeshPhysicalMaterial({ map: tex, roughness: 0.32, clearcoat: 0.6, clearcoatRoughness: 0.2 }));
  sleeve.rotation.y = stripeDir;
  const top = decal(2 * r, 2 * r, 40, (c, k) => {
    const R = r * k;
    c.fillStyle = '#E4E7EA';
    c.beginPath();
    c.arc(R, R, R, 0, Math.PI * 2);
    c.fill();
    c.strokeStyle = 'rgba(80,88,96,0.55)';
    c.lineWidth = 0.18 * k;
    c.beginPath();
    c.moveTo(R, R * 0.25);
    c.lineTo(R, R * 1.75);
    c.moveTo(R * 0.25, R);
    c.lineTo(R * 1.75, R);
    c.stroke();
  }).tex;
  const lid = new THREE.Mesh(new THREE.CircleGeometry(r - 0.9, 48), new THREE.MeshStandardMaterial({ map: top, roughness: 0.3, metalness: 0.8 }));
  lid.rotation.x = -Math.PI / 2;
  lid.position.y = h - 0.12;
  g.add(sleeve, lid);
}

/** 公排針 1×N（沿 x），塑膠座 2.5、針露出 6。 */
function maleHeader(g: THREE.Group, m: Mats, n: number) {
  const cone = new THREE.CylinderGeometry(0.12, 0.45, 0.5, 4, 1);
  cone.rotateY(Math.PI / 4);
  for (let i = 0; i < n; i++) {
    const x = (i - (n - 1) / 2) * P;
    block(g, 2.48, 2.5, 2.48, x, 0, 0, m.header, 0.3);
    block(g, 0.64, 5.6, 0.64, x, 2.5, 0, m.gold);
    const tip = new THREE.Mesh(cone, m.gold);
    tip.position.set(x, 8.35, 0);
    g.add(tip);
  }
}

/** 母排座 1×N（沿 x），高 8.5。 */
function femaleHeader(g: THREE.Group, m: Mats, n: number) {
  block(g, n * P, 8.5, 2.54, 0, 0, 0, m.header, 0.25);
  const hole = new THREE.PlaneGeometry(0.95, 0.95);
  for (let i = 0; i < n; i++) {
    const h = new THREE.Mesh(hole, m.hole);
    h.rotation.x = -Math.PI / 2;
    h.position.set((i - (n - 1) / 2) * P, 8.505, 0);
    g.add(h);
  }
}

/** 繼電器 JQC-3F：長邊沿 x。 */
function relay(g: THREE.Group, m: Mats, mark: THREE.Texture) {
  block(g, 18.8, 0.9, 15.3, 0, 0, 0, m.relayBase, 0.3);
  block(g, 19.0, 14.6, 15.5, 0, 0.9, 0, m.relay, 0.55);
  decalPlane(g, 16.5, 11.5, 0, 15.505, 0, mark, 0.5);
}

/** 5.08 公釐二位端子台：接線孔朝 +x（板緣），螺絲在頂面。 */
function terminal(g: THREE.Group, m: Mats) {
  const s = new THREE.Shape();
  s.moveTo(-4.9, 0);
  s.lineTo(4.9, 0);
  s.lineTo(4.9, 10);
  s.lineTo(0.2, 10);
  s.lineTo(-4.9, 3.8);
  s.closePath();
  const geo = new THREE.ExtrudeGeometry(s, { depth: 10.0, bevelEnabled: true, bevelThickness: 0.08, bevelSize: 0.08, bevelSegments: 1 });
  geo.translate(0, 0, -5.0);
  g.add(new THREE.Mesh(geo, m.terminal));
  for (const z of [-P, P]) {
    const mouth = new THREE.Mesh(new THREE.PlaneGeometry(3.3, 3.3), m.terminalDark);
    mouth.rotation.y = Math.PI / 2;
    mouth.position.set(4.99, 3.6, z);
    const recess = new THREE.Mesh(new THREE.CylinderGeometry(1.75, 1.75, 0.06, 32), m.terminalDark);
    recess.position.set(2.55, 10.03, z);
    const screw = new THREE.Mesh(new THREE.CylinderGeometry(1.45, 1.45, 0.3, 32), m.alu);
    screw.position.set(2.55, 10.1, z);
    const slot = new THREE.Mesh(new THREE.BoxGeometry(2.7, 0.08, 0.38), m.terminalDark);
    slot.position.set(2.55, 10.27, z);
    slot.rotation.y = 0.5;
    g.add(mouth, recess, screw, slot);
  }
}

/** 跳帽：套在 JP1 兩支針上。 */
function jumperCap(g: THREE.Group, m: Mats) {
  maleHeader(g, m, 2);
  block(g, 5.0, 6.0, 2.4, 0, 2.55, 0, m.plastic, 0.35);
  for (const x of [-P / 2, P / 2]) {
    const h = new THREE.Mesh(new THREE.PlaneGeometry(0.9, 0.9), m.hole);
    h.rotation.x = -Math.PI / 2;
    h.position.set(x, 8.56, 0);
    g.add(h);
  }
}

/* ------------------------------------------------------------------ */
/* ESP32-S3-DevKitC-1                                                  */
/* ------------------------------------------------------------------ */

const J1_NAMES = ['3V3', '3V3', 'RST', '4', '5', '6', '7', '15', '16', '17', '18', '8', '3', '46', '9', '10', '11', '12', '13', '14', '5V', 'G'];
const J3_NAMES = ['G', 'TX', 'RX', '1', '2', '42', '41', '40', '39', '38', '37', '36', '35', '0', '45', '48', '47', '21', '20', '19', 'G', 'G'];

function devkit(m: Mats, redraws: (() => void)[]) {
  const g = new THREE.Group();
  g.name = 'ESP32-S3-DevKitC-1';
  const L = DEV.l, Wd = DEV.w, t = DEV.t;
  const pinX = (i: number) => (i - 10.5) * P;
  const rowZ = 22.86 / 2;
  // 公排針塑膠座（插進排母後露出的部分）與板子
  for (const z of [-rowZ, rowZ]) block(g, 22 * P, 2.5, 2.5, 0, 0, z, m.header, 0.2);
  const top = decal(L, Wd, 32, (c, k) => {
    c.fillStyle = '#15171A';
    c.fillRect(0, 0, c.canvas.width, c.canvas.height);
    const X = (x: number) => (x + L / 2) * k;
    const Z = (z: number) => (z + Wd / 2) * k;
    c.fillStyle = '#C9CDD1';
    for (let i = 0; i < 22; i++) for (const z of [-rowZ, rowZ]) {
      c.beginPath();
      c.arc(X(pinX(i)), Z(z), 0.85 * k, 0, Math.PI * 2);
      c.fill();
    }
    c.fillStyle = '#EDEFEA';
    c.textBaseline = 'middle';
    c.font = `500 ${0.95 * k}px ${FONT}`;
    for (let i = 0; i < 22; i++) {
      c.save();
      c.translate(X(pinX(i)), Z(rowZ - 1.75));
      c.rotate(-Math.PI / 2);
      c.textAlign = 'left';
      c.fillText(J1_NAMES[i], 0, 0);
      c.restore();
      c.save();
      c.translate(X(pinX(i)), Z(-rowZ + 1.75));
      c.rotate(-Math.PI / 2);
      c.textAlign = 'right';
      c.fillText(J3_NAMES[i], 0, 0);
      c.restore();
    }
    c.textAlign = 'center';
    c.font = `500 ${1.5 * k}px ${FONT}`;
    c.fillText('ESP32-S3-DevKitC-1', X(4.5), Z(0));
    c.font = `500 ${1.0 * k}px ${FONT}`;
    c.fillText('v1.1', X(4.5), Z(1.9));
    c.fillText('USB', X(18.6), Z(7.6));
    c.fillText('UART', X(18.6), Z(-7.6));
    c.fillText('BOOT', X(21.6), Z(-3.9));
    c.fillText('RST', X(21.6), Z(3.9));
    c.strokeStyle = '#EDEFEA';
    c.lineWidth = 0.14 * k;
    for (const z of [-3.9, 3.9]) c.strokeRect(X(23.0 - 2.3), Z(z - 1.85), 4.6 * k, 3.7 * k);
  });
  redraws.push(top.redraw);
  const pcbMats = [m.devEdge, m.devEdge, new THREE.MeshStandardMaterial({ map: top.tex, roughness: 0.5 }), m.devPcb, m.devEdge, m.devEdge];
  block(g, L, t, Wd, 0, 2.5, 0, pcbMats);
  const y1 = 2.5 + t;
  // 焊點與穿出的針尖
  const fillet = new THREE.CylinderGeometry(0.4, 0.85, 0.5, 16);
  for (let i = 0; i < 22; i++) for (const z of [-rowZ, rowZ]) {
    const f = new THREE.Mesh(fillet, m.tin);
    f.position.set(pinX(i), y1 + 0.25, z);
    g.add(f);
    block(g, 0.64, 1.3, 0.64, pinX(i), y1, z, m.tin);
  }
  // 模組 ESP32-S3-WROOM-1：天線端朝 -x（第 1 腳端）
  const modL = 25.5, modW = 18, modX0 = -L / 2 - 1.5;
  const modTex = decal(modL, modW, 32, (c, k) => {
    c.fillStyle = '#1D2632';
    c.fillRect(0, 0, c.canvas.width, c.canvas.height);
    c.strokeStyle = '#33404E';
    c.lineWidth = 0.5 * k;
    c.beginPath();
    let x = 1.0;
    c.moveTo(x * k, 2.0 * k);
    for (let i = 0; i < 6; i++) {
      c.lineTo(x * k, (i % 2 ? 2.0 : 15.5) * k);
      x += 0.95;
      c.lineTo(x * k, (i % 2 ? 2.0 : 15.5) * k);
    }
    c.stroke();
  });
  redraws.push(modTex.redraw);
  block(g, modL, 0.8, modW, modX0 + modL / 2, y1, 0, [m.modPcb, m.modPcb, new THREE.MeshStandardMaterial({ map: modTex.tex, roughness: 0.5 }), m.modPcb, m.modPcb, m.modPcb]);
  const shL = 17.6, shW = 15.8;
  const shX = modX0 + modL - 0.6 - shL / 2;
  block(g, shL, 2.4, shW, shX, y1 + 0.8, 0, m.shield, 0.2);
  const shMark = decal(shL - 2, shW - 2, 40, (c, k) => {
    c.fillStyle = 'rgba(70,76,82,0.85)';
    c.textAlign = 'left';
    c.textBaseline = 'middle';
    c.font = `600 ${1.55 * k}px ${FONT}`;
    c.fillText('ESP32-S3-WROOM-1', 0.6 * k, 3.0 * k);
    c.font = `500 ${1.25 * k}px ${FONT}`;
    c.fillText('N16R8', 0.6 * k, 5.6 * k);
    c.fillStyle = 'rgba(70,76,82,0.8)';
    const s = 0.42;
    let seed = 11;
    const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
    for (let i = 0; i < 9; i++) for (let j = 0; j < 9; j++) if (rnd() > 0.5 || i < 2 && j < 2) c.fillRect((10.8 + i * s) * k, (9.4 + j * s) * k, s * k, s * k);
  });
  redraws.push(shMark.redraw);
  const markPlane = decalPlane(g, shL - 2, shW - 2, shX, y1 + 3.205, 0, shMark.tex, 0.5);
  markPlane.rotation.z = Math.PI / 2;
  markPlane.scale.set((shW - 2) / (shL - 2), (shL - 2) / (shW - 2), 1);
  // USB-C ×2（插口朝 +x）
  for (const z of [-6.2, 6.2]) {
    const shell = boxMesh(7.35, 3.2, 8.94, m.usb, 1.5);
    shell.position.set(L / 2 - 7.35 / 2 + 1.4, y1 + 1.6, z);
    const mouth = boxMesh(0.1, 2.3, 7.9, m.hole, 0.05);
    mouth.position.set(L / 2 + 1.4 + 0.02, y1 + 1.6, z);
    g.add(shell, mouth);
  }
  // 按鍵、RGB LED、穩壓與 USB 轉 UART
  for (const z of [-3.9, 3.9]) {
    block(g, 3.6, 0.9, 2.9, 23.0, y1, z, m.tin, 0.1);
    block(g, 1.6, 0.6, 1.4, 23.0, y1 + 0.9, z, m.button, 0.15);
  }
  block(g, 2.2, 0.8, 2.2, 4.0, y1, 6.0, m.white, 0.1);
  block(g, 6.5, 1.6, 3.5, 11.0, y1, -6.3, m.epoxy, 0.1);
  block(g, 3.0, 0.4, 1.0, 11.0, y1, -2.9, m.tin);
  block(g, 4.0, 0.85, 4.0, 15.5, y1, 5.6, m.epoxy, 0.05);
  const smd: [number, number, number][] = [[-3.5, 4.2, 0], [-3.5, -4.2, 0], [8.5, 4.0, 1], [5.0, -3.6, 0], [17.5, -2.0, 1], [18.2, 1.6, 0], [-6.5, 6.8, 1], [0.5, -7.0, 0]];
  for (const [x, z, rot] of smd) {
    const c = new THREE.Group();
    chip(c, m, 1.6, 0.8, 0.45, x > 10 ? m.mlcc : m.resistor);
    c.position.set(x, y1, z);
    c.rotation.y = rot ? Math.PI / 2 : 0;
    g.add(c);
  }
  return g;
}

/* ------------------------------------------------------------------ */
/* 板面（銅箔、焊墊、絲印）                                             */
/* ------------------------------------------------------------------ */

function paintBoard(s: Sheet) {
  const pad = (x: number, y: number, w: number, h: number, r = 0.15) => s.rect(x, y, w, h, COLORS.pad, 0.3, 1, r);
  const thPad = (x: number, y: number, r: number, square = false) => {
    if (square) pad(x, y, r * 2, r * 2, 0.1); else s.circle(x, y, r, COLORS.pad, 0.3, 1);
    s.circle(x, y, r * 0.5, COLORS.hole, 0.9, 0);
  };
  const via = (x: number, y: number) => {
    s.circle(x, y, 0.38, COLORS.pad, 0.3, 1);
    s.circle(x, y, 0.17, COLORS.hole, 0.9, 0);
  };
  const tr = (pts: [number, number][], w = 0.3) => s.line(pts, w, COLORS.trace);

  /* 走線（示意；12V 與 GND 主要走背面，正面只畫到導通孔） */
  // 12V：DC 插座 → 沿後緣 → 導通孔；C1 正極與 7805 輸入接在這條線上
  tr([[J5_AT.x, 10.6], [J5_AT.x, 17.8], [60.0, 17.8]], 1.2);
  via(60.0, 17.8);
  via(61.3, 17.8);
  tr([[C1_AT.x + 2.5, C1_AT.y], [C1_AT.x + 2.5, 17.8]], 1.0);
  tr([[35.4, 17.8], [35.4, 12.0], [U4_AT.x - P, U4_AT.y + 0.6]], 1.0);
  // 5V：7805 輸出 → C4、C2 → JP1；JD-VCC：JP1 → 繼電器線圈
  tr([[U4_AT.x + P, U4_AT.y + 0.6], [43.6, 11.6], [56.0, 11.6], [59.4, 8.2], [JP1_AT.x - P / 2, JP1_AT.y]], 0.8);
  tr([[C2_AT.x - 1.75, C2_AT.y], [C2_AT.x - 1.75, 11.6]], 0.8);
  tr([[C4_X() + 0.95, 13.3], [C4_X() + 0.95, 11.6]], 0.6);
  tr([[JP1_AT.x + P / 2, JP1_AT.y], [JP1_AT.x + P / 2, 4.4], [65.6, CH[0] + K_DY - 6], [U_X + CHP.df.x, CH[0] + K_DY - 6]], 0.6);
  // GPIO4–7 → 各路指示燈（經兩排排母之間繞到右側）
  for (let k = 0; k < 4; k++) {
    const p = u1Front(4 + k);
    const lane = 42.7 + 0.9 * k;
    const xv = k === 0 || k === 3 ? 66.0 : 66.9;
    const yLed = CH[k] + CHP.led.y;
    tr([[p.x, p.y], [p.x, lane], [xv, lane], [xv, yLed], [U_X + CHP.led.x - 0.95, yLed]]);
  }
  // 門磁：GPIO42–39 繞過左端 → J10–J7 中間腳
  const doorPins = [28, 29, 30, 31];
  const doorTo = [3, 2, 1, 0];
  doorPins.forEach((n, i) => {
    const p = u1Back(n);
    const yl = 22.4 - 0.8 * i, xm = 3.6 - 0.8 * i, yf = 69.0 + 0.8 * i;
    const hx = DOOR_X[doorTo[i]];
    tr([[p.x, p.y], [p.x, yl], [xm, yl], [xm, yf], [hx, yf], [hx, HDR_Y]]);
  });
  DOOR_X.forEach((x) => {
    tr([[x - P, HDR_Y], [x - P, 72.6]]);
    via(x - P, 72.6);
    tr([[x + P, HDR_Y], [x + P + 0.6, 72.9]]);
    via(x + P + 0.6, 72.9);
  });
  // 螢幕：GPIO8/9/11/12/13 扇出到 J6；TFT_CS 由背面走（兩個導通孔）
  const tft: [number, number][] = [[12, 4], [15, 5], [17, 6], [18, 7], [19, 8]];
  for (const [n, j] of tft) {
    const p = u1Front(n);
    const tx = J6_X0 + P * (j - 1);
    const ys = 50.5;
    tr([[p.x, p.y], [p.x, ys], [tx, ys + (tx - p.x)], [tx, HDR_Y]]);
  }
  tr([[u1Front(16).x, U1_FRONT], [u1Front(16).x, 50.0]]);
  via(u1Front(16).x, 50.0);
  tr([[J6_X0 + P * 2, HDR_Y], [J6_X0 + P * 2, 72.4]]);
  via(J6_X0 + P * 2, 72.4);
  tr([[J6_X0, HDR_Y], [J6_X0, 71.8]], 0.6);
  via(J6_X0, 71.8);
  tr([[J6_X0 + P, HDR_Y], [J6_X0 + P, 72.9]], 0.6);
  via(J6_X0 + P, 72.9);
  // 每一路：光耦、電晶體、續流二極體、繼電器線圈；NO 接點 → 電磁鎖正極，負極接地
  CH.forEach((y) => {
    const ra = { x: U_X + CHP.ra.x, y: y + CHP.ra.y };
    const ld = { x: U_X + CHP.led.x, y: y + CHP.led.y };
    const rb = { x: U_X + CHP.rb.x, y: y + CHP.rb.y };
    const q = { x: U_X + CHP.q.x, y: y + CHP.q.y };
    const df = { x: U_X + CHP.df.x, y: y + CHP.df.y };
    const yc = y + K_DY;
    const dl = yc + DL_DY;
    tr([[ra.x + 0.95, ra.y], [74.6, ra.y], [U_X - 3.81, y - P / 2]]);
    tr([[ld.x + 0.95, ld.y], [75.6, ld.y], [U_X - 3.81, y + P / 2]]);
    tr([[ra.x - 0.95, ra.y], [ra.x - 2.1, ra.y]], 0.4);
    via(ra.x - 2.1, ra.y);
    tr([[U_X + 3.81, y + P / 2], [U_X + 3.81, y + 2.9], [rb.x - 0.95, y + 2.9], [rb.x - 0.95, rb.y]]);
    tr([[rb.x + 0.95, rb.y], [q.x - 1.1, q.y - 0.95]]);
    tr([[q.x - 1.1, q.y + 0.95], [q.x - 1.1, q.y + 2.2]]);
    via(q.x - 1.1, q.y + 2.2);
    tr([[q.x + 1.1, q.y], [86.0, q.y], [86.0, yc + 6], [K_X - 4.05, yc + 6]], 0.5);
    tr([[df.x, df.y + 2.0], [df.x, yc + 6]], 0.5);
    tr([[df.x, df.y - 2.0], [df.x, yc - 6], [K_X - 4.05, yc - 6]], 0.5);
    tr([[U_X + 3.81, y - P / 2], [85.0, y - 2.0], [df.x - 1.0, y - 2.0]]);
    tr([[K_X - 6.05, yc], [90.3, yc]], 0.8);
    via(90.3, yc);
    tr([[K_X + 6.05, yc - 6], [117.6, yc - 6], [121.0, yc - P], [TB_X - 1.0, yc - P]], 1.0);
    tr([[DL_X, dl - 2.0], [DL_X, yc - 6]], 0.6);
    tr([[DL_X, dl + 2.0], [120.6, dl + 2.0], [TB_X - 1.0, yc + P]], 1.0);
    tr([[118.4, dl + 2.0], [118.4, dl + 3.4]], 0.6);
    via(118.4, dl + 3.4);
  });

  /* 焊墊 */
  for (let n = 1; n <= 22; n++) { const p = u1Front(n); thPad(p.x, p.y, 0.85, n === 1); }
  for (let n = 23; n <= 44; n++) { const p = u1Back(n); thPad(p.x, p.y, 0.85); }
  DOOR_X.forEach((x) => { for (let i = -1; i <= 1; i++) thPad(x + i * P, HDR_Y, 0.85, i === -1); });
  for (let i = 0; i < 8; i++) thPad(J6_X0 + P * i, HDR_Y, 0.85, i === 0);
  thPad(JP1_AT.x - P / 2, JP1_AT.y, 0.85, true);
  thPad(JP1_AT.x + P / 2, JP1_AT.y, 0.85);
  for (let i = -1; i <= 1; i++) { pad(U4_AT.x + i * P, U4_AT.y, 1.8, 2.4, 0.9); s.circle(U4_AT.x + i * P, U4_AT.y, 0.5, COLORS.hole, 0.9, 0); }
  for (const [c, pitch] of [[C1_AT, 5], [C2_AT, 3.5]] as const) for (const sx of [-1, 1]) thPad(c.x + sx * pitch / 2, c.y, 1.0, sx === 1);
  pad(J5_AT.x, 11.3, 2.6, 1.6, 0.3);
  pad(J5_AT.x - 2.9, 7.2, 1.4, 2.6, 0.3);
  pad(J5_AT.x + 2.9, 7.2, 1.4, 2.6, 0.3);
  for (const x of [C3_X(), C4_X()]) for (const sx of [-1, 1]) pad(x + sx * 0.95, 13.3, 1.0, 1.3);
  CH.forEach((y) => {
    const yc = y + K_DY;
    for (const sx of [-1, 1]) for (const sy of [-1, 1]) thPad(U_X + sx * 3.81, y + sy * P / 2, 0.8, sx === -1 && sy === -1);
    for (const c of [CHP.ra, CHP.led, CHP.rb]) for (const sx of [-1, 1]) pad(U_X + c.x + sx * 0.95, y + c.y, 1.0, 1.3);
    pad(U_X + CHP.q.x - 1.1, y + CHP.q.y - 0.95, 0.9, 0.8);
    pad(U_X + CHP.q.x - 1.1, y + CHP.q.y + 0.95, 0.9, 0.8);
    pad(U_X + CHP.q.x + 1.1, y + CHP.q.y, 0.9, 0.8);
    for (const sy of [-1, 1]) pad(U_X + CHP.df.x, y + CHP.df.y + sy * 2.0, 1.7, 1.6);
    for (const sy of [-1, 1]) pad(DL_X, yc + DL_DY + sy * 2.0, 1.7, 1.6);
    for (const rp of RELAY_PINS) thPad(K_X + rp.x, yc + rp.y, 1.25);
    for (const sy of [-1, 1]) thPad(TB_X - 1.0, yc + sy * P, 1.25, sy === -1);
  });

  /* 導通孔（散布在空白處） */
  const vias: [number, number][] = [
    [14, 3], [20, 13.5], [31, 14.6], [47, 15.0], [58.5, 14.2], [68.6, 12.8], [70.0, 21.0], [69.6, 38.4], [70.0, 57.0], [64.0, 33.0],
    [62.5, 52.0], [64.0, 62.0], [44.0, 66.5], [30.0, 63.0], [18.0, 58.0], [9.0, 52.5], [6.0, 63.0], [24.0, 66.0], [52.0, 21.0], [40.0, 20.5],
    [12.5, 14.5], [87.0, 17.0], [88.6, 36.0], [88.6, 55.6], [86.5, 74.5], [118.5, 18.6], [118.5, 38.0], [118.5, 57.4], [114.0, 75.5], [127.0, 77.0],
    [98.0, 78.0], [80.0, 77.0], [72.0, 77.5], [1.5, 78.2], [127.5, 2.5], [92.0, 1.8], [75.0, 1.8], [56.0, 1.8], [68.0, 70.0], [75.6, 72.5],
  ];
  vias.forEach(([x, y]) => via(x, y));

  /* 絲印外框 */
  s.outline(U1_X0 + P * 10.5, U1_FRONT, 22 * P + 0.4, 2.94);
  s.outline(U1_X0 + P * 10.5, U1_BACK, 22 * P + 0.4, 2.94);
  DOOR_X.forEach((x) => s.outline(x, HDR_Y, 3 * P + 0.4, 2.94));
  s.outline(J6_X0 + P * 3.5, HDR_Y, 8 * P + 0.4, 2.94);
  s.outline(JP1_AT.x, JP1_AT.y, 2 * P + 0.4, 2.94);
  s.outline(J5_AT.x, J5_AT.y, 9.4, 14.8);
  s.ring(C1_AT.x, C1_AT.y, C1_AT.r + 0.3);
  s.ring(C2_AT.x, C2_AT.y, C2_AT.r + 0.3);
  s.text('+', C1_AT.x + 3.6, C1_AT.y - 4.6, 1.6);
  s.text('+', C2_AT.x + 3.2, C2_AT.y - 4.0, 1.4);
  s.outline(U4_AT.x, U4_AT.y - 0.9, 10.4, 4.9);
  for (const x of [C3_X(), C4_X()]) s.outline(x, 13.3, 3.2, 1.9, 0.12);
  CH.forEach((y, i) => {
    const yc = y + K_DY;
    s.outline(U_X, y, 5.0, 4.9);
    s.rect(U_X - 2.6, y - 2.7, 0.5, 0.5, COLORS.silk, 0.8);
    for (const c of [CHP.ra, CHP.led, CHP.rb]) s.outline(U_X + c.x, y + c.y, 3.2, 1.9, 0.12);
    s.outline(U_X + CHP.q.x, y + CHP.q.y, 1.6, 3.4, 0.12);
    s.outline(U_X + CHP.df.x, y + CHP.df.y, 3.2, 5.4, 0.12);
    s.outline(DL_X, yc + DL_DY, 3.2, 5.4, 0.12);
    s.outline(K_X, yc, 19.6, 16.0);
    s.outline(TB_X, yc, 10.2, 10.6);
    // 標號
    s.text(`U${5 + i}`, U_X, y - 3.4, 1.0);
    s.text(`R${1 + i}`, U_X + CHP.ra.x, y + CHP.ra.y - 1.7, 1.0);
    s.text(`D${9 + i}`, U_X + CHP.led.x, y + CHP.led.y + 1.8, 1.0);
    s.text(`R${5 + i}`, U_X + CHP.rb.x, y + CHP.rb.y + 1.75, 1.0);
    s.text(`Q${1 + i}`, U_X + CHP.q.x + 0.2, y + CHP.q.y + 2.65, 1.0);
    s.text(`D${5 + i}`, U_X + CHP.df.x, y + CHP.df.y + 3.6, 1.0);
    s.text(`D${1 + i}`, DL_X, yc + DL_DY + 3.6, 1.0);
    s.text(`K${1 + i}`, K_X, yc + 9.1, 1.2);
    s.text(`J${1 + i}`, 117.6, yc, 1.1, -Math.PI / 2);
  });
  s.text('J5', 11.0, 7.4, 1.2, -Math.PI / 2);
  s.text('C1', 31.0, 6.2, 1.2, -Math.PI / 2);
  s.text('U4', 45.4, 7.0, 1.1, -Math.PI / 2);
  s.text('C3', C3_X(), 15.0, 0.9);
  s.text('C4', C4_X(), 15.0, 0.9);
  s.text('C2', 45.9 + 0.8, 3.0, 1.1, -Math.PI / 2);
  s.text('JP1', 59.0, JP1_AT.y, 1.1, -Math.PI / 2);
  s.text('U1', 2.0, 36.6, 1.3, -Math.PI / 2);
  DOOR_X.forEach((x, i) => s.text(`J${7 + i}`, x - 4.6, 77.0, 1.1, -Math.PI / 2));
  s.text('J6', J6_X0 - 2.6, 77.0, 1.1, -Math.PI / 2);
}

function C3_X() { return U4_AT.x - 2.3; }
function C4_X() { return U4_AT.x + 2.6; }

/* ------------------------------------------------------------------ */
/* 組裝                                                                */
/* ------------------------------------------------------------------ */

/**
 * 建立主控板模型。回傳的 Group 可任意移動、旋轉；內部縮放在子群組上。
 * 元件以標號為名稱（例如 getObjectByName('K1')），userData.region 為所屬功能區。
 */
export function createPcb(opts: PcbOptions = {}): THREE.Group {
  const scale = opts.scale ?? PCB_SCALE.cabinet;
  const root = new THREE.Group();
  root.name = 'DoorLock-ESP32S3';
  const mm = new THREE.Group();
  mm.name = 'pcb-mm';
  mm.scale.setScalar(scale);
  root.add(mm);
  const m = makeMats();
  const redraws: (() => void)[] = [];
  const parts = new Map<string, THREE.Object3D>();
  const regionOf = new Map<string, PcbRegion>();
  for (const [key, r] of Object.entries(PCB_REGIONS) as [PcbRegion, { refs: string[] }][]) for (const ref of r.refs) regionOf.set(ref, key);

  // 板子
  const sheet = new Sheet(W, D, 32, COLORS.mask);
  const draw = () => paintBoard(sheet);
  draw();
  const { map, orm } = sheet.textures();
  const topMat = new THREE.MeshPhysicalMaterial({ map, roughnessMap: orm, metalnessMap: orm, roughness: 1, metalness: 1, clearcoat: 0.22, clearcoatRoughness: 0.42 });
  const board = new THREE.Mesh(new THREE.BoxGeometry(W, T, D), [m.edge, m.edge, topMat, m.bottom, m.edge, m.edge]);
  board.position.y = T / 2;
  board.name = 'board';
  mm.add(board);
  redraws.push(() => {
    const fresh = new Sheet(W, D, 32, COLORS.mask);
    paintBoard(fresh);
    sheet.c.drawImage(fresh.color, 0, 0);
    sheet.o.drawImage(fresh.orm, 0, 0);
    map.needsUpdate = true;
    orm.needsUpdate = true;
  });

  const place = (ref: string, X: number, Y: number, rotY = 0) => {
    const g = new THREE.Group();
    g.name = ref;
    g.position.set(X - W / 2, T, Y - D / 2);
    g.rotation.y = rotY;
    g.userData.ref = ref;
    const region = regionOf.get(ref);
    if (region) g.userData.region = region;
    mm.add(g);
    parts.set(ref, g);
    return g;
  };

  // 印字貼圖
  const textDecal = (wMm: number, hMm: number, lines: [string, number, number][], color: string, weight = 600) => {
    const d = decal(wMm, hMm, 48, (c, k) => {
      c.fillStyle = color;
      c.textAlign = 'center';
      c.textBaseline = 'middle';
      for (const [s, y, size] of lines) {
        c.font = `${weight} ${size * k}px ${FONT}`;
        c.fillText(s, (wMm / 2) * k, y * k);
      }
    });
    redraws.push(d.redraw);
    return d.tex;
  };
  const relayMark = textDecal(16.5, 11.5, [['JQC-3F(T73)', 2.2, 1.6], ['05VDC-C', 4.6, 1.6], ['10A 250VAC', 7.4, 1.15], ['10A 30VDC', 9.2, 1.15]], 'rgba(236,242,250,0.9)');
  const pcMark = textDecal(5.6, 2.2, [['PC815', 1.1, 1.1]], 'rgba(180,184,188,0.75)');
  const regMark = textDecal(8.6, 3.0, [['L7805CV', 1.0, 1.3], ['GK 26 40', 2.3, 0.9]], 'rgba(185,188,192,0.8)');

  // 電源區
  barrelJack(place('J5', J5_AT.x, J5_AT.y), m);
  eCap(place('C1', C1_AT.x, C1_AT.y), m, C1_AT.r, C1_AT.h, Math.atan2(0.35, -1));
  to220(place('U4', U4_AT.x, U4_AT.y), m, regMark);
  eCap(place('C2', C2_AT.x, C2_AT.y), m, C2_AT.r, C2_AT.h, 0);
  chip(place('C3', C3_X(), 13.3), m, 2.0, 1.25, 0.85, m.mlcc);
  chip(place('C4', C4_X(), 13.3), m, 2.0, 1.25, 0.85, m.mlcc);
  jumperCap(place('JP1', JP1_AT.x, JP1_AT.y), m);

  // U1 排母
  const u1 = place('U1', U1_X0 + P * 10.5, (U1_FRONT + U1_BACK) / 2);
  for (const z of [U1_FRONT, U1_BACK]) {
    const row = new THREE.Group();
    row.position.z = z - (U1_FRONT + U1_BACK) / 2;
    femaleHeader(row, m, 22);
    u1.add(row);
  }

  // 驅動、繼電器、端子台
  CH.forEach((y, i) => {
    const yc = y + K_DY;
    dip4(place(`U${5 + i}`, U_X, y), m, pcMark);
    chip(place(`R${1 + i}`, U_X + CHP.ra.x, y + CHP.ra.y), m, 2.0, 1.25, 0.5, m.resistor);
    led0805(place(`D${9 + i}`, U_X + CHP.led.x, y + CHP.led.y), m);
    chip(place(`R${5 + i}`, U_X + CHP.rb.x, y + CHP.rb.y), m, 2.0, 1.25, 0.5, m.resistor);
    sot23(place(`Q${1 + i}`, U_X + CHP.q.x, y + CHP.q.y), m);
    sma(place(`D${5 + i}`, U_X + CHP.df.x, y + CHP.df.y), m);
    sma(place(`D${1 + i}`, DL_X, yc + DL_DY), m);
    relay(place(`K${1 + i}`, K_X, yc), m, relayMark);
    terminal(place(`J${1 + i}`, TB_X, yc), m);
  });

  // 前緣排針
  DOOR_X.forEach((x, i) => maleHeader(place(`J${7 + i}`, x, HDR_Y), m, 3));
  maleHeader(place('J6', J6_X0 + P * 3.5, HDR_Y), m, 8);

  // 開發板
  const dev = devkit(m, redraws);
  dev.position.set(DEV.x - W / 2, T + 8.5, DEV.y - D / 2);
  dev.userData.ref = 'U1';
  dev.userData.region = 'mcu';
  dev.visible = !!opts.esp32;
  mm.add(dev);

  if (opts.shadows) {
    mm.traverse((o) => {
      const mesh = o as THREE.Mesh;
      if (!mesh.isMesh) return;
      const mat = mesh.material as THREE.Material;
      const isDecal = !Array.isArray(mat) && mat.transparent;
      mesh.castShadow = !isDecal && mesh !== board;
      mesh.receiveShadow = !isDecal;
    });
  }

  const ready = document.fonts.load(`500 40px ${FONT}`).then(() => document.fonts.load(`600 40px ${FONT}`)).then(() => { redraws.forEach((f) => f()); });
  const data: PcbData = { ready, parts, devkit: dev };
  root.userData.pcb = data;
  return root;
}

export function pcbData(group: THREE.Object3D): PcbData {
  return group.userData.pcb as PcbData;
}

/** 顯示或隱藏插在 U1 上的 ESP32-S3-DevKitC-1。 */
export function setPcbEsp32(group: THREE.Object3D, on: boolean) {
  pcbData(group).devkit.visible = on;
}

/** 功能區（或單一元件）在世界座標的外框；U1 在插上開發板時包含開發板。 */
export function pcbBox(group: THREE.Object3D, key: PcbRegion | string): THREE.Box3 {
  const data = pcbData(group);
  group.updateWorldMatrix(true, true);
  const list = key in PCB_REGIONS ? PCB_REGIONS[key as PcbRegion].refs : [key];
  const box = new THREE.Box3();
  for (const ref of list) {
    const o = data.parts.get(ref);
    if (o) box.expandByObject(o);
    if (ref === 'U1' && data.devkit.visible) box.expandByObject(data.devkit);
  }
  return box;
}
