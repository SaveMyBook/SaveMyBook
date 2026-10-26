import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/examples/jsm/geometries/RoundedBoxGeometry.js';
import { STLLoader } from 'three/examples/jsm/loaders/STLLoader.js';
import { toCreasedNormals } from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import { Kiosk, doorPlate, loadImage } from './textures';

/**
 * 比照實機：9 公釐合板櫃體（寬 31 × 深 31 × 高 38 公分），正面為雷射切割之壓克力。
 * 頂列左上角為橫向 2.8 吋螢幕、右側貼標誌，下方 A01–A04 四扇櫃門由上而下；櫃門標籤在右上角，鉸鏈在右側、另一片固定在凸出櫃面的白色壓克力墊塊上；
 * 電磁鎖裝在門板內側左邊，門外同一位置有木製把手，皆隨門轉動。單位為 4 公分。
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
const screenX = -W / 2 + T + 0.3 + BEZEL_W / 2;
/** 電磁鎖（5.4 × 4.1 × 2.7 公分）在門板內側的位置：門板左緣往內 0.17。 */
const LOCK = { w: 1.35, h: 1.03, d: 0.68, inset: 0.17 };
const lockX = -IN_W / 2 + 0.03 + LOCK.inset + LOCK.w / 2;
const lockZ = D / 2 - LOCK.d / 2;
/** 鉸鏈片（約 1.7 × 3.8 公分）與鉸鏈另一片所在的白色壓克力墊塊。 */
const HINGE = { w: 0.42, h: 0.95 };

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

/**
 * 實機為橡木紋貼皮：灰褐底色上細密的深淺長紋。vertical 為側板用，紋路改成上下走向；
 * 直接畫成直紋而不用貼圖旋轉，匯出 GLB 時才不需要 KHR_texture_transform。
 */
function woodTexture(vertical = false): THREE.CanvasTexture {
  const c = document.createElement('canvas');
  c.width = c.height = 512;
  const g = c.getContext('2d')!;
  if (vertical) {
    g.translate(512, 0);
    g.rotate(Math.PI / 2);
  }
  g.fillStyle = '#7C644B';
  g.fillRect(0, 0, 512, 512);
  let seed = 7;
  const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  for (let i = 0; i < 300; i++) {
    const y0 = rnd() * 512, amp = 1 + rnd() * 4, freq = 0.003 + rnd() * 0.008, phase = rnd() * 6;
    g.strokeStyle = rnd() < 0.6
      ? `rgba(${52 + rnd() * 22 | 0}, ${40 + rnd() * 16 | 0}, ${28 + rnd() * 12 | 0}, ${0.2 + rnd() * 0.32})`
      : `rgba(${160 + rnd() * 28 | 0}, ${138 + rnd() * 24 | 0}, ${108 + rnd() * 20 | 0}, ${0.08 + rnd() * 0.2})`;
    g.lineWidth = 0.5 + rnd() * 2.2;
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

/**
 * 鉸鏈保護蓋：hardware_design/v8_protect/絞鍊保護蓋.STL 的複本（公釐，寬 12 × 高 54 × 深 10）。
 * L 形外殼，正面板在前、右側翼板往後包，左側與背面挖空包住櫃面上的鉸鏈片。
 * 原點移到左後緣、高度置中並換成書櫃單位（1 單位 = 4 公分）；圓角用摺角法線才不會一面一面的。
 */
async function hingeCoverGeometry(): Promise<THREE.BufferGeometry> {
  const geo = new STLLoader().parse(await (await fetch('/model/hinge-cover.stl')).arrayBuffer());
  geo.translate(0, -27, 0);
  geo.scale(1 / 40, 1 / 40, 1 / 40);
  return toCreasedNormals(geo, Math.PI / 6);
}

/** 頂列左側的標誌貼紙：書本圖示、名稱與英文名。 */
async function brandSticker(): Promise<THREE.CanvasTexture> {
  const c = document.createElement('canvas');
  c.width = 760;
  c.height = 240;
  const g = c.getContext('2d')!;
  try {
    const mark = await loadImage('/brand/book-slate-128.png');
    g.drawImage(mark, 40, 40, 160, 160);
  } catch { /* 標誌載入失敗時只顯示文字 */ }
  // 字型未載入時量到的寬度不準，先等字型；名稱依實際寬度縮小到放得進畫布，避免「書」被切掉
  await document.fonts.load('700 78px "Noto Sans TC"', '救「舊」我的書').catch(() => {});
  const parts = [['救', '#151E27'], ['「舊」', '#627D8D'], ['我的書', '#151E27']] as const;
  g.textBaseline = 'middle';
  g.font = '700 78px "Noto Sans TC", sans-serif';
  const nameW = parts.reduce((w, [t]) => w + g.measureText(t).width, 0);
  g.font = `700 ${Math.min(78, (78 * (c.width - 228 - 32)) / nameW).toFixed(1)}px "Noto Sans TC", sans-serif`;
  let x = 228;
  for (const [t, color] of parts) {
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
  /** 標誌貼紙與鉸鏈保護蓋（非同步載入）都放上後完成。 */
  readonly ready: Promise<void>;
  readonly anchors: Record<string, THREE.Object3D> = {};
  /** 比對數字在螢幕上的字級與兩字中心距（世界單位），供飛行動畫由螢幕起飛。 */
  readonly digitSize = SCR_H * Kiosk.DIGIT_EM;
  readonly digitGap = SCR_W * Kiosk.DIGIT_GAP;
  private shellMats: THREE.Material[] = [];
  private edges: THREE.LineSegments[] = [];
  private parts = new THREE.Group();
  private deposit: THREE.Group;
  private screenMesh: THREE.Mesh;
  private stickerMat!: THREE.MeshBasicMaterial;
  private xrayOn = false;

  constructor() {
    this.kiosk = new Kiosk();
    const wood = new THREE.MeshStandardMaterial({ map: woodTexture(), roughness: 0.72, metalness: 0 });
    const inner = new THREE.MeshStandardMaterial({ map: woodTexture(true), color: 0xcfc7bd, roughness: 0.8, metalness: 0 });
    const face = new THREE.MeshPhysicalMaterial({ color: 0xf4f6f7, roughness: 0.3, metalness: 0, clearcoat: 0.8, clearcoatRoughness: 0.12, transparent: true, opacity: 0.94 });
    const woodSide = new THREE.MeshStandardMaterial({ map: woodTexture(true), roughness: 0.72, metalness: 0 });
    // setXray 依索引調整前三個的透明度，其餘一律視同櫃體木板
    // 鉸鏈保護蓋是 3D 列印的白色件，不透明、霧面
    const printed = new THREE.MeshStandardMaterial({ color: 0xf2f3f3, roughness: 0.62, metalness: 0 });
    this.shellMats.push(wood, inner, face, woodSide, printed);
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
    box(T, H - T * 2, D, -W / 2 + T / 2, 0, 0, woodSide);
    box(T, H - T * 2, D, W / 2 - T / 2, 0, 0, woodSide);
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
    const stickerW = 4.4, stickerH = 4.4 * 240 / 760;
    // 貼紙背景透明：不可寫入深度，且一律畫在壓克力之後，否則透明處會把壓克力挖空而露出櫃內木板
    const sticker = new THREE.Mesh(new THREE.PlaneGeometry(stickerW, stickerH), new THREE.MeshBasicMaterial({ transparent: true, depthWrite: false, toneMapped: false }));
    sticker.renderOrder = 1;
    this.stickerMat = sticker.material as THREE.MeshBasicMaterial;
    sticker.position.set(screenX + BEZEL_W / 2 + 0.3 + stickerW / 2, topRowY, FRONT + 0.004);
    const stickerReady = brandSticker().then((tex) => { (sticker.material as THREE.MeshBasicMaterial).map = tex; (sticker.material as THREE.MeshBasicMaterial).needsUpdate = true; });
    this.group.add(sticker);

    // 各格左側板上的鎖扣，門上的電磁鎖關門時扣在這裡
    const lockMat = new THREE.MeshStandardMaterial({ color: 0x9aa1a7, roughness: 0.38, metalness: 0.65 });
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
    const screwGeo = new THREE.CylinderGeometry(0.035, 0.035, 0.02, 12);
    const screwMat = new THREE.MeshStandardMaterial({ color: 0x2c3135, roughness: 0.4, metalness: 0.7 });
    const hingeScrewMat = new THREE.MeshStandardMaterial({ color: 0x8d959b, roughness: 0.35, metalness: 0.85 });
    // 蘑菇形木製把手：沿 y 軸旋轉成形，裝上時轉成朝外
    const knobGeo = new THREE.LatheGeometry(
      [[0, 0], [0.11, 0], [0.11, 0.09], [0.19, 0.13], [0.27, 0.2], [0.3, 0.27], [0.28, 0.34], [0.19, 0.39], [0, 0.41]].map(([x, y]) => new THREE.Vector2(x, y)),
      24,
    );
    const knobMat = new THREE.MeshStandardMaterial({ color: 0xbdab91, roughness: 0.7, metalness: 0 });
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
      tag.position.set(-HINGE.w - 0.15 - 0.31, dh / 2 - 0.26, A / 2 + 0.004);
      const lockCx = -dw + LOCK.inset + LOCK.w / 2;
      const lock = new THREE.Mesh(new RoundedBoxGeometry(LOCK.w, LOCK.h, LOCK.d, 2, 0.05), lockMat);
      lock.position.set(lockCx, 0, -A / 2 - LOCK.d / 2 - 0.02);
      pivot.add(panel, ...rims, sheen, tag, lock);
      // 電磁鎖固定板的四顆螺絲，隔著透明門板看得到
      for (const [sx, sy] of [[-1, 1], [1, 1], [-1, -1], [1, -1]]) {
        const screw = new THREE.Mesh(screwGeo, screwMat);
        screw.rotation.x = Math.PI / 2;
        screw.position.set(lockCx + sx * (LOCK.w / 2 - 0.13), sy * (LOCK.h / 2 - 0.12), -A / 2 - 0.012);
        pivot.add(screw);
      }
      const knob = new THREE.Mesh(knobGeo, knobMat);
      knob.rotation.x = Math.PI / 2;
      knob.position.set(lockCx - LOCK.w * 0.12, 0, A / 2);
      // 鉸鏈：門板上的鉸鏈片、兩顆螺絲與門軸
      const leaf = new THREE.Mesh(new RoundedBoxGeometry(HINGE.w, HINGE.h, 0.025, 1, 0.01), hingeMat);
      leaf.position.set(-HINGE.w / 2 - 0.03, 0, A / 2 + 0.013);
      const barrel = new THREE.Mesh(new THREE.CylinderGeometry(0.045, 0.045, HINGE.h, 12), hingeMat);
      barrel.position.set(0, 0, A / 2 + 0.03);
      pivot.add(knob, leaf, barrel);
      for (const sy of [HINGE.h / 2 - 0.16, -HINGE.h / 2 + 0.16]) {
        const screw = new THREE.Mesh(screwGeo, hingeScrewMat);
        screw.rotation.x = Math.PI / 2;
        screw.position.set(-HINGE.w / 2 - 0.03, sy, A / 2 + 0.035);
        pivot.add(screw);
      }
      this.group.add(pivot);
      this.doors.push({ pivot });
    });

    // 鉸鏈保護蓋緊貼門軸右側（留 0.6 公釐讓門轉動），凸出櫃面 10 公釐，右側翼板略超出櫃體
    const coversReady = hingeCoverGeometry().then((geo) => {
      const coverEdges = new THREE.EdgesGeometry(geo, 30);
      for (let i = 0; i < 4; i++) {
        const cover = new THREE.Mesh(geo, printed);
        cover.position.set(IN_W / 2 + 0.03, cellY(i), D / 2 + A);
        const e = new THREE.LineSegments(coverEdges, edgeMat);
        e.position.copy(cover.position);
        this.edges.push(e);
        this.group.add(cover, e);
      }
    });
    this.ready = Promise.all([stickerReady, coversReady]).then(() => {});

    // 透視時才出現的元件（頂列右後方平放的主控板、各格左側的電磁鎖與配線）
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
    // 主控板 Rev A（130 × 80 公釐）元件面朝上平放在頂列右後方，長邊沿前後方向貼著右側板：
    // DC 插座在右後角、插孔朝後對著背板右側的電源孔（實物插孔朝版面 X=0 邊，和設計檔朝後緣不同）；
    // 電磁鎖端子台在前端朝前；螢幕與門磁排針在左緣。
    // X、Y 為 PCB 版面座標（公釐，X 由左緣向右、Y 由後緣向前），轉 90° 後 X 朝前、Y 朝左
    const PCB = { w: 80 / 40, d: 130 / 40 };
    const bx = IN_W / 2 - 0.4 - PCB.w / 2, bz = -D / 2 + T + 0.45 + PCB.d / 2, top = floor + 0.17;
    const at = (X: number, Y: number) => [bx + (40 - Y) / 40, bz + (X - 65) / 40] as const;
    /** 板上元件；w 沿版面 X、d 沿版面 Y（公釐）。 */
    const onBoard = (key: string | null, X: number, Y: number, w: number, h: number, d: number) => {
      const [x, z] = at(X, Y);
      part(key, d / 40, h, w / 40, x, top + h / 2, z);
    };
    part(null, PCB.w, 0.04, PCB.d, bx, top - 0.02, bz);
    // 元件位置與尺寸同 PCB 版面（實拍：開發板居中、DC 插座與 L7805 散熱片在電源區、繼電器與端子台一排）
    onBoard('board', 32.7, 36.6, 66, 0.41, 25.4);
    onBoard('power', 4.7, 5, 14.8, 0.28, 9.4);
    onBoard(null, 39.2, 9.6, 16, 0.5, 12);
    onBoard(null, 24.3, 6.2, 10, 0.4, 10);
    onBoard(null, 51.5, 5.3, 8, 0.29, 8);
    const CH_Y = [8.9, 28.3, 47.7, 67.1];
    CH_Y.forEach((y, i) => {
      onBoard(i === 1 ? 'relay' : null, 100.5, y, 19, 0.39, 15.5);
      onBoard(null, 124.5, y, 10, 0.26, 10);
    });
    // 外框比電磁鎖本體略大，兩者表面重疊時會閃爍
    for (let i = 0; i < 4; i++) part(i === 1 ? 'locks' : null, LOCK.w + 0.06, LOCK.h + 0.06, LOCK.d + 0.06, lockX, cellY(i), lockZ);
    const pts: number[] = [];
    const path = (...p: [number, number, number][]) => {
      for (let k = 1; k < p.length; k++) pts.push(...p[k - 1], ...p[k]);
    };
    // 12V 電源：背板右側開孔，插頭由後往前插入 DC 插座，電源線沿背面垂下
    const [jx, jz] = at(4.7 - 7.4, 5);
    path([jx, top + 0.14, jz], [jx, top + 0.14, -D / 2 - 0.12], [jx, -H / 2 + 0.05, -D / 2 - 0.12], [jx + 0.6, -H / 2 + 0.05, -D / 2 - 1.0]);
    // 配線全走右側：沿右側板往前，到右前角往下穿過各層板
    const tx = IN_W / 2 - 0.08, zf = D / 2 - 0.12;
    path([tx, floor + 0.1, zf], [tx, cellY(3), zf]);
    // 電磁鎖端子台（前端）往前，再往右到側板，沿側板往前併入右前角
    const [, zt] = at(130, 0);
    CH_Y.forEach((y, i) => {
      const [x] = at(130, y), xi = tx - 0.03 * i;
      path([x, top + 0.13, zt], [x, floor + 0.08, zt + 0.2], [xi, floor + 0.08, zt + 0.2], [xi, floor + 0.08, zf]);
    });
    // 門磁排針（左緣）往左，沿板子左側往前，繞到板前併入右側
    const [hx, hz] = at(23.6, 80);
    path([hx, top + 0.05, hz], [hx - 0.15, floor + 0.06, hz], [hx - 0.15, floor + 0.06, zt + 0.35], [tx - 0.15, floor + 0.06, zt + 0.35], [tx - 0.15, floor + 0.06, zf]);
    // 螢幕排線（左緣中段）往左，再往前到螢幕背面
    const [sx6, sz6] = at(55.6, 80);
    path([sx6, top + 0.05, sz6], [sx6 - 0.25, floor + 0.08, sz6], [screenX, floor + 0.08, sz6], [screenX, floor + 0.08, D / 2 - 0.9], [screenX, topRowY, D / 2 - 0.1]);
    // 每格：右前角往左沿格子頂部前緣，到電磁鎖上方往下接入
    for (let i = 0; i < 4; i++) {
      const wy = cellTop(i) - 0.08, lx = lockX + LOCK.w / 2 - 0.25;
      path([tx, wy, zf], [lx, wy, zf], [lx, cellY(i) + LOCK.h / 2, zf]);
    }
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
    for (const m of this.shellMats.slice(3)) (m as THREE.MeshStandardMaterial).opacity = 1 - t * 0.9;
    for (const e of this.edges) (e.material as THREE.LineBasicMaterial).opacity = t * 0.55;
    this.parts.traverse((o) => {
      const mat = (o as THREE.Mesh).material as THREE.Material | undefined;
      if (mat) mat.opacity = t;
    });
    this.screenMesh.renderOrder = on ? 5 : 0;
    // 標誌在控制板前方，透視時隨壓克力淡出，標註引線才不會穿過標誌文字
    this.stickerMat.opacity = 1 - t * 0.9;
  }
}
