import '@fontsource/noto-sans-tc/400.css';
import '@fontsource/noto-sans-tc/500.css';
import '@fontsource/noto-sans-tc/700.css';
import '@fontsource/ibm-plex-mono/500.css';
import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/examples/jsm/geometries/RoundedBoxGeometry.js';
import { Stage } from './stage';
import { Cabinet } from './three/cabinet';
import { Phone, PHONE } from './three/phone';
import { screenTexture, type KioskParams } from './three/textures';
import { span, easeInOut, easeOut, keyframes, type Pose } from './lib/kf';
import { GLTFExporter } from 'three/examples/jsm/exporters/GLTFExporter.js';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';

/**
 * 複評簡報素材：沿用介紹影片的書櫃與手機模型算圖（tools/deck.mjs 截圖輸出）。
 * mode=cover 封面右半邊（書櫃＋兩支手機）、hero 書櫃 3/4 視角、xray 透視圖、gif 存書／取書循環（flow=deposit|pickup）。
 * 不修改影片的模型檔；需要的姿態、書本與透視元件都在這裡另外加到物件上。
 */

/**
 * 存書／取書動畫的時間軸（秒）。對齊 D3 的 60 fps 手機影片（素材/video/cabinet_deposit.mp4 11.917 秒、cabinet_pickup.mp4 11.967 秒）：
 * 手機 1.217 掃描畫面滑入、2.517 掃到 QR Code、3.200 確認存書／取書項目、5.150 書櫃顯示比對碼、6.633 按確認、7.117 開鎖開門、
 * 7.433 倒數 0:30 開始、7.43–9.23 放入／取出並關門、9.800（取書 9.967）手機完成且書櫃回到待機、11.517（取書 11.567）起 0.4 秒淡回首格。
 * 要再對齊時改這裡，或用網址參數覆寫：?tl=match:5.2,open:7.2（tools/deck.mjs gif／video 的 --tl 參數同義）；?preset=draft 為最初 9 秒版。
 */
const TL_D3 = {
  /** 循環總長（取書版見 TL_D3_PICKUP） */
  loop: 11.917,
  /** 手機進入確認項目，書櫃螢幕由 QR Code 換成「書櫃使用中，請於手機確認項目」 */
  busy: 3.2,
  /** 書櫃螢幕顯示比對碼「25」 */
  match: 5.15,
  /** 手機按確認後，螢幕顯示「櫃門開啟中」 */
  unlock: 6.7,
  /** A01 開鎖、櫃門開始打開，螢幕改顯示作業中（A01 說明與倒數） */
  open: 7.117,
  /** 開門所需時間 */
  openDur: 0.6,
  /** 倒數 30 秒開始（與手機 0:30 同步） */
  count: 7.433,
  /** 存書：書出現在櫃門前；取書：書開始抬起。須晚於 open + 0.45（櫃門轉開到不會碰到書的角度，tools/deck.mjs check 會檢查） */
  bookIn: 7.567,
  /** 存書：書平放到 A01 底板；取書：書淡出 */
  bookEnd: 8.6,
  /** 開始關門 */
  close: 8.65,
  /** 門關上，螢幕顯示作業完成 */
  closeEnd: 9.2,
  /** 螢幕回到待機 QR Code（與手機顯示完成同時） */
  qr: 9.8,
  /** 循環接縫：內容結束後 0.4 秒淡回首格（存書版 A01 的書淡出、取書版淡入） */
  seam: 11.517,
};
const TL_D3_PICKUP = { ...TL_D3, loop: 11.967, qr: 9.967, seam: 11.567 };
/** 最初的 9 秒版（0–2.4 QR、2.4 比對碼、3.5 開門、3.5–6.5 放入／取出、6.5–7.3 關門、7.3–8 完成）。 */
const TL_DRAFT = { loop: 9.0, busy: 2.4, match: 2.4, unlock: 3.1, open: 3.5, openDur: 0.6, count: 3.5, bookIn: 3.95, bookEnd: 6.4, close: 6.5, closeEnd: 7.3, qr: 8.0, seam: 8.4 };

const params = new URLSearchParams(location.search);
type Mode = 'cover' | 'hero' | 'xray' | 'gif' | 'glb' | 'spin' | 'flat';
const MODE = (params.get('mode') ?? 'gif') as Mode;
const FLOW = params.get('flow') === 'pickup' ? 'pickup' : 'deposit';
const VW = Number(params.get('w') ?? 1920);
const VH = Number(params.get('h') ?? 1080);
const PR = Number(params.get('pr') ?? 2);
/** 主視覺與旋轉展示共用的角度：正面偏右（看得到左側板）、略俯視約 15°。 */
const HERO_RY = 0.52;
const HERO_EL = 0.26;
/**
 * 接近正面的鏡頭（cam=front）：書櫃轉 -8°（看得到一點右側板）、俯角 6°、視角 12°（鏡頭拉遠、透視感較低），
 * 螢幕與 A01–A04 櫃門正對觀眾。存取書影片、正面圖、正面透視圖與正面旋轉共用，簡報可平滑轉場。
 */
const FRONT_CAM = params.get('cam') === 'front';
const FRONT_VIEW = { ry: -0.14, el: 0.105, fov: 12 };
/** 透視圖的 12V 電源線在左側板外垂下的距離；正面鏡頭看得到右側板，線要離遠一點才不會落在櫃體輪廓內。 */
const CABLE_OUT = FRONT_CAM ? 1.3 : 0.45;
/**
 * 櫃門全開角度（弧度）。正面鏡頭若開到 1.65（同影片），門板幾乎正對鏡頭只剩一條線；
 * 開小於 90° 時門內側的電磁鎖會擋到書的路徑，所以改為開過 90°（約 117°）往右側甩開，門板斜向鏡頭看得清楚。
 */
const DOOR_MAX = FRONT_CAM ? 2.05 : 1.65;
/** 旋轉展示一圈的秒數。 */
const SPIN_PERIOD = 8;
/** 投影片內容區底色（GIF 不用透明以免邊緣鋸齒）。 */
const GIF_BG = '#F8FAFB';
export const TL = params.get('preset') === 'draft' ? { ...TL_DRAFT } : { ...(FLOW === 'pickup' ? TL_D3_PICKUP : TL_D3) };
for (const kv of (params.get('tl') ?? '').split(',').filter(Boolean)) {
  const [k, v] = kv.split(':');
  if (k in TL && Number.isFinite(Number(v))) (TL as Record<string, number>)[k] = Number(v);
}

/* ---------- 書櫃尺寸（與 three/cabinet.ts 相同，單位 4 公分） ---------- */
const CW = Cabinet.WIDTH, CH = Cabinet.HEIGHT, CD = Cabinet.DEPTH;
const T = 0.225, A = 0.125, TOP = 2.05;
const IN_W = CW - T * 2;
const CELL_H = (CH - T * 2 - TOP - T * 4) / 4;
const FRONT = CD / 2 + A;
const topRowY = CH / 2 - T - TOP / 2;
const cellTop = (i: number) => CH / 2 - T - TOP - T - i * (CELL_H + T);
const cellY = (i: number) => cellTop(i) - CELL_H / 2;
const SCR_W = 1.76, SCR_H = 1.32, BEZEL_W = 1.98;
const screenX = CW / 2 - T - 0.3 - BEZEL_W / 2;
const LOCK = { w: 1.35, h: 1.03, d: 0.68, inset: 0.17 };
const lockX = -IN_W / 2 + 0.03 + LOCK.inset + LOCK.w / 2;
const lockZ = CD / 2 - LOCK.d / 2;
/** A01 底板高度。 */
const floorY = cellTop(0) - CELL_H;
const KIOSK_NAME = '國立臺北商業大學';

/* ---------- 書（比照影片 cabinet.ts 的平放書，封面換成《HTML & CSS》實拍照片） ---------- */
/** 寬（x）× 厚（y）× 長（z），長寬比依實書 0.78。 */
const BOOK = { w: 4.05, t: 0.5, l: 5.2 };
const restY = floorY + BOOK.t / 2 + 0.004;

function canvasTex(c: HTMLCanvasElement) {
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 8;
  return t;
}

class DeckBook {
  readonly group = new THREE.Group();
  private mats: THREE.MeshStandardMaterial[];
  private fading = false;
  constructor(cover: THREE.Texture) {
    const pages = new THREE.MeshStandardMaterial({ color: 0xf2eee4, roughness: 0.9 });
    const face = new THREE.MeshStandardMaterial({ map: cover, roughness: 0.5 });
    const brown = new THREE.MeshStandardMaterial({ color: 0x3b2e2c, roughness: 0.6 });
    this.mats = [pages, brown, face, brown, pages];
    // RoundedBoxGeometry 頂面 uv：u 往 +x、v 往 -z，封面上緣朝書櫃內側，由正面看是正的
    const mesh = new THREE.Mesh(new RoundedBoxGeometry(BOOK.w, BOOK.t, BOOK.l, 2, 0.04), [pages, brown, face, brown, pages, pages]);
    this.group.add(mesh);
  }
  set(p: Pose) {
    this.group.position.set(p.x, p.y, p.z);
    this.group.rotation.set(p.rx ?? 0, p.ry ?? 0, 0);
    const op = Math.max(0, Math.min(1, p.op ?? 1));
    this.group.visible = op > 0.002;
    const fade = op < 0.999;
    if (fade !== this.fading) {
      for (const m of this.mats) { m.transparent = fade; m.needsUpdate = true; }
      this.fading = fade;
    }
    for (const m of this.mats) m.opacity = op;
  }
}

/** 書的關鍵姿態（書櫃座標）。 */
const P_REST: Pose = { x: 0.3, y: restY, z: -0.5, rx: 0, ry: 0, op: 1 };
const P_LIFT: Pose = { ...P_REST, y: restY + 0.14 };
/** 平放在 A01 開口正前方：書的後緣仍在壓克力面板之前。 */
const P_ALIGN: Pose = { ...P_LIFT, z: FRONT + BOOK.l / 2 + 0.2 };
/** 斜拿在櫃門前，封面朝向鏡頭；放在左側，不擋右上角螢幕，也避開右側打開的櫃門。 */
const P_SHOW: Pose = { x: -0.9, y: cellY(0) - 0.3, z: FRONT + 3.9, rx: 0.8, ry: 0.1, op: 1 };
const P_FAR: Pose = { x: -1.05, y: cellY(0) - 0.2, z: FRONT + 4.7, rx: 0.85, ry: 0.14, op: 0 };

function bookPose(t: number): Pose {
  const L = TL;
  if (FLOW === 'deposit') {
    if (t < L.bookIn) return { ...P_REST, op: 0 };
    if (t >= L.seam) return { ...P_REST, op: 1 - easeInOut(span(t, L.seam, L.loop)) };
    const a = L.bookIn, b = L.bookEnd, d = b - a;
    const tShow = a + d * 0.2, tAlign = a + d * 0.48, tIn = a + d * 0.82;
    const p = keyframes(t, [[a, P_FAR], [tShow, P_SHOW], [tAlign, P_ALIGN], [tIn, P_LIFT], [b, P_REST]]);
    p.op = easeOut(span(t, a, tShow));
    return p;
  }
  if (t >= L.seam) return { ...P_REST, op: easeInOut(span(t, L.seam, L.loop)) };
  if (t < L.bookIn) return P_REST;
  const a = L.bookIn, b = L.bookEnd, d = b - a;
  const tLift = a + d * 0.15, tOut = a + d * 0.57, tShow = a + d * 0.8;
  const p = keyframes(t, [[a, P_REST], [tLift, P_LIFT], [tOut, P_ALIGN], [tShow, P_SHOW], [b, { ...P_FAR, op: 1 }]]);
  p.op = 1 - easeInOut(span(t, tShow - d * 0.05, b));
  return p;
}

function kioskAt(t: number): KioskParams {
  const L = TL;
  // QR Code 更新條：回到 QR 時重新計時，循環接縫處連續
  const qrAge = (((t - L.qr) % L.loop) + L.loop) % L.loop;
  if (t < Math.min(L.busy, L.match) || t >= L.qr) return { state: 'qr', refresh: qrAge / 30, seconds: 60, digits: 1, check: 0 };
  if (t < L.match) return { state: 'busy', refresh: 0, seconds: 60 - Math.floor(t - L.busy), digits: 1, check: 0 };
  if (t < L.unlock) return { state: 'match', refresh: 0, seconds: 60 - Math.floor(t - L.match), digits: 1, check: 0 };
  if (t < L.open) return { state: 'opening', refresh: 0, seconds: 30, digits: 1, check: 0 };
  if (t < L.closeEnd) return { state: 'open', refresh: 0, seconds: 30 - Math.max(0, Math.floor(t - L.count)), digits: 1, check: 0, take: FLOW === 'pickup' };
  return { state: 'done', refresh: 0, seconds: 0, digits: 1, check: easeOut(span(t, L.closeEnd, L.closeEnd + 0.5)) };
}

const doorAt = (t: number) => easeInOut(span(t, TL.open, TL.open + TL.openDur)) * (1 - easeInOut(span(t, TL.close, TL.closeEnd)));

/* ---------- 場景 ---------- */
const canvas = document.getElementById('gl') as HTMLCanvasElement;
const stage = new Stage(canvas, PR);
stage.renderer.setSize(VW, VH, false);
canvas.style.width = `${VW}px`;
canvas.style.height = `${VH}px`;
stage.camera.aspect = VW / VH;
if (FRONT_CAM) {
  stage.camera.fov = FRONT_VIEW.fov;
  stage.scene.fog = null;
}
stage.camera.updateProjectionMatrix();
if (MODE === 'gif' || MODE === 'spin' || (MODE === 'flat' && params.get('bg') !== '0')) document.body.style.background = GIF_BG;

/** 地面柔影：放在物件底部的水平面上。 */
function floorShadow(w: number, d: number, strength: number) {
  const c = document.createElement('canvas');
  c.width = c.height = 256;
  const g = c.getContext('2d')!;
  const grad = g.createRadialGradient(128, 128, 8, 128, 128, 128);
  grad.addColorStop(0, `rgba(22,34,43,${strength})`);
  grad.addColorStop(0.55, `rgba(22,34,43,${strength * 0.45})`);
  grad.addColorStop(1, 'rgba(22,34,43,0)');
  g.fillStyle = grad;
  g.fillRect(0, 0, 256, 256);
  const m = new THREE.Mesh(new THREE.PlaneGeometry(w, d), new THREE.MeshBasicMaterial({ map: canvasTex(c), transparent: true, depthWrite: false, toneMapped: false }));
  m.rotation.x = -Math.PI / 2;
  m.renderOrder = -1;
  return m;
}

/** 書櫃螢幕標題列右上角：實機韌體顯示臺灣時間（預覽圖固定 14:25），取代影片材質的連線點。 */
function kioskClock(cab: Cabinet) {
  const g = cab.kiosk.canvas.getContext('2d')!;
  const k = 2;
  g.fillStyle = '#18212A';
  g.fillRect(262 * k, 0, 58 * k, 28 * k);
  g.font = `500 ${16 * k}px "Noto Sans TC", sans-serif`;
  g.fillStyle = '#EEF2F5';
  g.textAlign = 'right';
  g.textBaseline = 'middle';
  g.fillText('14:25', 310 * k, 14 * k);
  cab.kiosk.texture.needsUpdate = true;
}

function drawKiosk(cab: Cabinet, p: KioskParams) {
  cab.kiosk.draw(p);
  kioskClock(cab);
}

async function loadFonts() {
  const text = `${KIOSK_NAME}請使用 SaveMyBook App 掃描請於手機輸入下列數字剩餘秒櫃門開啟中書籍放入後關上取出內的作業完成使用中確認項目0123456789:救「舊」我的書`;
  await Promise.all([
    document.fonts.load('400 30px "Noto Sans TC"', text),
    document.fonts.load('500 30px "Noto Sans TC"', text),
    document.fonts.load('700 30px "Noto Sans TC"', text),
    document.fonts.load('500 32px "IBM Plex Mono"', 'A01234'),
  ]);
  await document.fonts.ready;
}

function loadTex(src: string) {
  return new Promise<THREE.Texture>((ok, fail) => new THREE.TextureLoader().load(src, (t) => {
    t.colorSpace = THREE.SRGBColorSpace;
    t.anisotropy = 8;
    ok(t);
  }, undefined, fail));
}

function place(obj: THREE.Object3D, p: Pose) {
  obj.position.set((p.x ?? 0) * stage.halfW, (p.y ?? 0) * stage.halfH, p.z ?? 0);
  obj.rotation.set(p.rx ?? 0, p.ry ?? 0, p.rz ?? 0);
  obj.scale.setScalar(p.s ?? 1);
}

/** 世界座標 → 截圖裝置像素。 */
function toPx(v: THREE.Vector3) {
  const p = v.clone().project(stage.camera);
  return [+((p.x + 1) / 2 * VW * PR).toFixed(1), +((1 - p.y) / 2 * VH * PR).toFixed(1)] as [number, number];
}

/**
 * 鏡頭對準：固定仰角 el（由上往下看）與方位，調整距離與注視點，讓 pts 在畫面上置中並留 pad（半寬／半高的比例）。
 */
function fitCamera(pts: THREE.Vector3[], el: number, pad: { x: number; y: number }, bias = { x: 0, y: 0 }, az = 0) {
  const cam = stage.camera;
  const dir = new THREE.Vector3(Math.sin(az) * Math.cos(el), Math.sin(el), Math.cos(az) * Math.cos(el));
  const box = new THREE.Box3().setFromPoints(pts);
  const target = box.getCenter(new THREE.Vector3());
  let dist = 60;
  for (let k = 0; k < 60; k++) {
    cam.position.copy(target).addScaledVector(dir, dist);
    cam.lookAt(target);
    cam.updateMatrixWorld(true);
    let x0 = Infinity, x1 = -Infinity, y0 = Infinity, y1 = -Infinity;
    for (const p of pts) {
      const q = p.clone().project(cam);
      x0 = Math.min(x0, q.x); x1 = Math.max(x1, q.x); y0 = Math.min(y0, q.y); y1 = Math.max(y1, q.y);
    }
    const cx = (x0 + x1) / 2 - bias.x, cy = (y0 + y1) / 2 - bias.y;
    const halfH = Math.tan(THREE.MathUtils.degToRad(cam.fov / 2)) * dist;
    const right = new THREE.Vector3().setFromMatrixColumn(cam.matrixWorld, 0);
    const up = new THREE.Vector3().setFromMatrixColumn(cam.matrixWorld, 1);
    target.addScaledVector(right, cx * halfH * cam.aspect).addScaledVector(up, cy * halfH);
    const s = Math.max((x1 - x0) / 2 / (1 - pad.x), (y1 - y0) / 2 / (1 - pad.y));
    dist *= Math.pow(s, 0.8);
  }
  cam.position.copy(target).addScaledVector(dir, dist);
  cam.lookAt(target);
  cam.updateMatrixWorld(true);
  return { target, dist };
}

/** 鏡頭放在 target 的方位角 az、仰角 el、距離 dist 處。 */
function aimCamera(target: THREE.Vector3, az: number, el: number, dist: number) {
  const cam = stage.camera;
  cam.position.set(target.x + Math.sin(az) * Math.cos(el) * dist, target.y + Math.sin(el) * dist, target.z + Math.cos(az) * Math.cos(el) * dist);
  cam.lookAt(target);
  cam.updateMatrixWorld(true);
}

/** 書櫃地面柔影（CW*1.55 × CD*1.6，中心 (0.3, -CH/2, -0.3)）肉眼可見的範圍。 */
function shadowExtent(k = 0.72) {
  const out: THREE.Vector3[] = [];
  for (const [x, z] of [[-1, 0], [1, 0], [0, 1], [0, -1], [-0.7, 0.7], [0.7, 0.7]]) out.push(V(0.3 + x * CW * 1.55 / 2 * k, -CH / 2, -0.3 + z * CD * 1.6 / 2 * k));
  return out;
}

/** 書櫃外框角點與（選擇性）A01 打開的櫃門角點，書櫃座標。 */
function cabinetCorners(withDoor: boolean) {
  const pts: THREE.Vector3[] = [];
  for (const x of [-1, 1]) for (const y of [-1, 1]) for (const z of [-1, 1]) pts.push(new THREE.Vector3(x * CW / 2, y * CH / 2, z * (CD / 2 + (z > 0 ? A : 0))));
  if (withDoor) {
    const hx = IN_W / 2 - 0.03, hz = CD / 2 + A / 2, dw = IN_W - 0.06, th = DOOR_MAX;
    for (const y of [cellY(0) - CELL_H / 2, cellY(0) + CELL_H / 2]) pts.push(new THREE.Vector3(hx - dw * Math.cos(th), y, hz + dw * Math.sin(th)));
  }
  return pts;
}

/* ---------- 透視元件 ---------- */

/** 圓角折線，用來畫電線。 */
function polyCurve(pts: THREE.Vector3[], r = 0.14) {
  const path = new THREE.CurvePath<THREE.Vector3>();
  let prev = pts[0].clone();
  for (let i = 1; i < pts.length; i++) {
    const p = pts[i];
    if (i < pts.length - 1) {
      const a = p.clone().sub(pts[i - 1]), b = pts[i + 1].clone().sub(p);
      const rr = Math.min(r, a.length() / 2, b.length() / 2);
      a.normalize(); b.normalize();
      const p1 = p.clone().addScaledVector(a, -rr), p2 = p.clone().addScaledVector(b, rr);
      if (prev.distanceTo(p1) > 1e-4) path.add(new THREE.LineCurve3(prev, p1));
      path.add(new THREE.QuadraticBezierCurve3(p1, p.clone(), p2));
      prev = p2;
    } else path.add(new THREE.LineCurve3(prev, p.clone()));
  }
  return path;
}
function wire(pts: THREE.Vector3[], radius: number, mat: THREE.Material) {
  return new THREE.Mesh(new THREE.TubeGeometry(polyCurve(pts), Math.max(16, pts.length * 28), radius, 8, false), mat);
}
const V = (x: number, y: number, z: number) => new THREE.Vector3(x, y, z);

/** 主控板版面座標（公釐，X 由左緣向右、Y 由後緣向前），與 src/deck/pcb.ts 相同；佔位模型定位用。 */
const PCB_MM = { w: 130, d: 80, j5: [5, 4.7], term: 124.5, ch: [8.9, 28.3, 47.7, 67.1], door: [8.3, 18.5, 28.7, 38.9], hdr: 75.6, j6: [46.7, 64.5] };
/**
 * 主控板直立裝在頂列背板內側（元件朝前，透視時正面看得到）：板高 8 公分，頂列內高 8.2 公分。
 * 這個方向 J5 DC 插座在板子上緣、插孔朝上，由頂板開孔插入 12V 插頭。原點在板子底面中心，繞 x 軸轉 90°。
 */
const BOARD_AT = V(-1.75, CH / 2 - T - TOP / 2, -CD / 2 + T + 0.12);
const lay = (X: number, Y: number, h = 0) => V(BOARD_AT.x + (X - PCB_MM.w / 2) / 40, BOARD_AT.y - (Y - PCB_MM.d / 2) / 40, BOARD_AT.z + h / 40);

interface Board { group: THREE.Object3D; source: string; at: (key: string) => THREE.Vector3 }

/** 主控板：使用 D5 的 src/deck/pcb.ts（DoorLock ESP32-S3 主控板 Rev A）；載入失敗時以綠色佔位板代替。回傳的 at() 為書櫃座標。 */
async function mainBoard(cab: Cabinet, parent: THREE.Group): Promise<Board> {
  const mods = import.meta.glob('./deck/pcb.ts');
  const load = mods['./deck/pcb.ts'];
  if (load && params.get('pcb') !== '0') {
    try {
      const mod = (await load()) as typeof import('./deck/pcb');
      const g = mod.createPcb({ esp32: true });
      g.position.copy(BOARD_AT);
      g.rotation.x = Math.PI / 2;
      parent.add(g);
      await mod.pcbData(g).ready;
      const at = (key: string) => {
        g.updateWorldMatrix(true, true);
        const box = key === 'board' ? new THREE.Box3().setFromObject(g.getObjectByName('board')!) : mod.pcbBox(g, key);
        return cab.group.worldToLocal(box.getCenter(new THREE.Vector3()));
      };
      return { group: g, source: 'src/deck/pcb.ts（DoorLock ESP32-S3 主控板 Rev A）', at };
    } catch (e) { console.error('pcb.ts 載入失敗', e); }
  }
  const g = new THREE.Group();
  const pcb = new THREE.Mesh(new THREE.BoxGeometry(PCB_MM.w / 40, 0.04, PCB_MM.d / 40), new THREE.MeshStandardMaterial({ color: 0x1f7a4a, roughness: 0.45 }));
  pcb.position.y = 0.02;
  g.add(pcb);
  g.position.copy(BOARD_AT);
  g.rotation.x = Math.PI / 2;
  parent.add(g);
  const table: Record<string, THREE.Vector3> = {
    board: lay(65, 40, 1.6), J5: lay(PCB_MM.j5[0], PCB_MM.j5[1], 6), J6: lay((PCB_MM.j6[0] + PCB_MM.j6[1]) / 2, PCB_MM.hdr, 4),
    U1: lay(32.7, 36.6, 12), relay: lay(100.5, 40, 8), U4: lay(39.2, 9.6, 8),
  };
  PCB_MM.ch.forEach((y, i) => { table[`J${i + 1}`] = lay(PCB_MM.term, y, 5); });
  PCB_MM.door.forEach((x, i) => { table[`J${i + 7}`] = lay(x, PCB_MM.hdr, 4); });
  return { group: g, source: '佔位模型（src/deck/pcb.ts 未載入）', at: (k) => table[k].clone() };
}

/**
 * 透視用元件，全部加在書櫃群組內：主控板（直立在頂列背板內側）、各格頂部前緣的門磁微動開關、12V 電源線與配線。
 * 影片模型內的 12V 電源、繼電器、控制板方塊與舊配線改由主控板取代，透視時隱藏；四組電磁鎖沿用。
 */
async function buildXray(cab: Cabinet) {
  const parts = (cab as unknown as { parts: THREE.Group }).parts;
  for (const o of parts.children) o.visible = Math.abs(o.position.x - lockX) < 1e-3;
  const extra = new THREE.Group();
  cab.group.add(extra);
  cab.group.updateMatrixWorld(true);
  const board = await mainBoard(cab, extra);
  const P = (k: string) => board.at(k);
  const anchors: Record<string, THREE.Vector3> = {
    board: P('board'), powerIn: P('J5'), esp32: P('U1'), relays: P('relay'), regulator: P('U4'),
  };

  const wireMat = new THREE.MeshStandardMaterial({ color: 0x3b505c, roughness: 0.6 });
  const cableMat = new THREE.MeshStandardMaterial({ color: 0x20262b, roughness: 0.55 });
  const swBody = new THREE.MeshStandardMaterial({ color: 0x23282d, roughness: 0.5 });
  const swPcb = new THREE.MeshStandardMaterial({ color: 0xe9eef1, roughness: 0.6 });
  const lever = new THREE.MeshStandardMaterial({ color: 0xc3cad0, roughness: 0.3, metalness: 0.85 });
  const edgeMat = new THREE.LineBasicMaterial({ color: 0x3b505c });
  const floorTop = CH / 2 - T - TOP;
  const back = -CD / 2;

  // 12V 電源線：插頭由頂板開孔往下插進 DC 插座 → 往左 → 沿左側外面垂到地面
  const j5 = anchors.powerIn, top = CH / 2;
  const plug = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.1, 0.5, 20), cableMat);
  plug.position.set(j5.x, top + 0.05, j5.z);
  const grommet = new THREE.Mesh(new THREE.CylinderGeometry(0.15, 0.15, T + 0.03, 24), new THREE.MeshStandardMaterial({ color: 0x15191c, roughness: 0.7 }));
  grommet.position.set(j5.x, top - T / 2, j5.z);
  extra.add(plug, grommet);
  extra.add(wire([V(j5.x, top + 0.25, j5.z), V(j5.x, top + 0.55, j5.z), V(-CW / 2 - CABLE_OUT, top + 0.55, j5.z), V(-CW / 2 - CABLE_OUT, -CH / 2 + 0.12, j5.z), V(-CW / 2 - CABLE_OUT - 1.55, -CH / 2 + 0.12, j5.z + 1.0)], 0.06, cableMat));
  anchors.cableEntry = V(j5.x, top, j5.z);

  // 主幹：左後角（主控板前方）往下穿過各層板
  const tx = -IN_W / 2 + 0.14, tz = -2.75;
  extra.add(wire([V(tx, floorTop + 0.1, tz), V(tx, cellY(3) - 0.3, tz)], 0.06, wireMat));
  // 電磁鎖端子台 J1–J4（板子右緣）→ 往前 → 沿頂列底板往左併入主幹
  for (let k = 0; k < 4; k++) {
    const tk = P(`J${k + 1}`), y = floorTop + 0.08 + k * 0.04, z = tz + 0.04 + k * 0.05;
    extra.add(wire([V(tk.x + 0.1, tk.y, tk.z), V(tk.x + 0.32, tk.y, tk.z), V(tk.x + 0.32, tk.y, z), V(tk.x + 0.32, y, z), V(tx + 0.02, y, z)], 0.022, wireMat));
  }
  // 門磁排針 J7–J10（板子下緣左側）→ 往前往下 → 併入主幹
  for (let k = 0; k < 4; k++) {
    const hk = P(`J${k + 7}`), y = floorTop + 0.08 + k * 0.035, z = tz + 0.3 + k * 0.04;
    extra.add(wire([V(hk.x, hk.y, hk.z + 0.05), V(hk.x, hk.y, z), V(hk.x, y, z), V(tx + 0.02, y, z)], 0.02, wireMat));
  }
  // 螢幕排線 J6（板子下緣中間）→ 沿頂列底板往前 → 往右 → 螢幕背面
  const j6 = P('J6'), yr = floorTop + 0.1;
  extra.add(wire([V(j6.x, j6.y, j6.z + 0.05), V(j6.x, yr, j6.z + 0.25), V(j6.x, yr, CD / 2 - 0.9), V(screenX - 0.3, yr, CD / 2 - 0.9), V(screenX - 0.3, topRowY - 0.1, CD / 2 - 0.12)], 0.035, wireMat));

  for (let i = 0; i < 4; i++) {
    const name = `A0${i + 1}`;
    // 門磁微動開關：裝在格子頂部前緣、電磁鎖右側，櫃門關上時壓下槓桿
    const sx = -1.45, sy = cellTop(i) - 0.2, sz = CD / 2 - 0.32;
    const pcb = new THREE.Mesh(new THREE.BoxGeometry(0.78, 0.04, 0.5), swPcb);
    pcb.position.set(sx, cellTop(i) - 0.02, sz - 0.02);
    const pe = new THREE.LineSegments(new THREE.EdgesGeometry(pcb.geometry), edgeMat);
    pe.position.copy(pcb.position);
    const body = new THREE.Mesh(new RoundedBoxGeometry(0.5, 0.26, 0.28, 2, 0.03), swBody);
    body.position.set(sx, sy + 0.02, sz);
    const lv = new THREE.Mesh(new THREE.BoxGeometry(0.44, 0.03, 0.03), lever);
    lv.position.set(sx + 0.05, sy - 0.08, sz + 0.2);
    lv.rotation.y = -0.35;
    extra.add(pcb, pe, body, lv);
    anchors[`switch${name}`] = V(sx, sy, sz + 0.14);
    anchors[`lock${name}`] = V(lockX, cellY(i), lockZ + LOCK.d / 2 + 0.03);

    // 每格一條線：主幹 → 沿左側板頂部往前，到電磁鎖後方分成兩條，一條進電磁鎖、一條到開關
    const wy = cellTop(i) - 0.1, wx = -IN_W / 2 + 0.11, split = lockZ - LOCK.d / 2 - 0.22;
    extra.add(wire([V(tx, wy, tz), V(wx, wy, tz + 0.2), V(wx, wy, split), V(lockX - 0.3, wy, split), V(lockX - 0.3, cellY(i) + 0.15, split), V(lockX - 0.3, cellY(i) + 0.15, lockZ - LOCK.d / 2 + 0.05)], 0.03, wireMat));
    extra.add(wire([V(lockX - 0.3, wy, split), V(sx - 0.1, wy, split), V(sx - 0.1, wy, sz - 0.1)], 0.03, wireMat));
  }
  return { anchors, source: board.source };
}


/**
 * 平放版透視（硬體組成 → 主控板的轉場用）：主控板元件面朝上平放在頂列底板左後方，避開右上角螢幕。
 * J5 DC 插座在板子左後角、插孔朝後，12V 插頭由背板開孔插入；電磁鎖端子台在板子右緣、門磁排針與螢幕排針在前緣。
 */
const FLAT = {
  /** 主控板底面中心（書櫃座標）：板子 3.25 × 2.0 單位（13 × 8 公分），後緣離背板 0.3。 */
  at: V(-1.75, CH / 2 - T - TOP + 0.01, -CD / 2 + T + 0.3 + 1.0),
  /** 鏡頭：沿用 FRONT_VIEW 的水平偏轉與視角，俯角提高到 22°，平放的板面才看得清楚。 */
  el: THREE.MathUtils.degToRad(22),
  /** 推進終點：主控板 3/4 俯視（板子座標的方位角 −30°、俯角 40°），板寬約占畫布 80%。 */
  endEl: THREE.MathUtils.degToRad(40),
  endAz: THREE.MathUtils.degToRad(-30),
  endWidth: 0.8,
  /** 推進秒數；之後原地旋轉，每圈秒數（寬版 12 秒一圈、轉 3 圈）。 */
  zoom: 2.0,
  spin: params.get('wide') === '1' ? 12.0 : 8.0,
  turns: params.get('wide') === '1' ? 3 : 1,
  /** 推進途中櫃體與其他元件淡出、板下柔影淡入的時段（秒）。 */
  fade: [0.25, 1.3] as [number, number],
  shadow: [1.0, 1.9] as [number, number],
};
/**
 * 寬版（wide=1，簡報第 22 頁主控板頁，畫布 2588×1600 對應投影片 x 0.83–8.92、y 1.62–6.62 吋）：
 * 第 0 格的透視取景與 2000×2200 版相同，等比縮到畫布高、靠右（左側留白）；推進時主點偏移跟著平移，
 * 終點主控板置中於左側大框（畫布 x 0–2208、y 218–1594）。以畫布寬高的比例表示，與算圖倍率無關。
 */
const FLAT_WIDE = {
  /** 原透視畫布的寬高比（2000×2200）。 */
  aspect: 2000 / 2200,
  /**
   * 終點主控板中心與含元件寬度（相對畫布寬高）。取景以外框角點計算，高元件的角點使框偏上、偏寬，
   * 實際像素中心約 (1104, 906)、寬約 1650。
   */
  cx: 1095 / 2588,
  cy: 857 / 1600,
  w: 1696 / 2588,
  /** 旋轉起步與停止的加減速時間（秒）；總圈數不變，中段速度略快於 12 秒一圈。 */
  ramp: 1.0,
};

async function buildXrayFlat(cab: Cabinet) {
  const parts = (cab as unknown as { parts: THREE.Group }).parts;
  for (const o of parts.children) o.visible = Math.abs(o.position.x - lockX) < 1e-3;
  const extra = new THREE.Group();
  cab.group.add(extra);
  cab.group.updateMatrixWorld(true);
  const mod = await import('./deck/pcb');
  const g = mod.createPcb({ esp32: true });
  g.position.copy(FLAT.at);
  cab.group.add(g);
  await mod.pcbData(g).ready;
  cab.group.updateMatrixWorld(true);
  const P = (key: string) => {
    const box = key === 'board' ? new THREE.Box3().setFromObject(g.getObjectByName('board')!) : mod.pcbBox(g, key);
    return cab.group.worldToLocal(box.getCenter(new THREE.Vector3()));
  };
  const top = (key: string) => {
    const box = mod.pcbBox(g, key);
    const c = box.getCenter(new THREE.Vector3());
    c.y = box.max.y;
    return cab.group.worldToLocal(c);
  };
  const anchors: Record<string, THREE.Vector3> = {
    board: P('board'), powerIn: P('J5'), esp32: P('U1'), relays: P('relay'), regulator: P('U4'),
  };

  const wireMat = new THREE.MeshStandardMaterial({ color: 0x3b505c, roughness: 0.6 });
  const cableMat = new THREE.MeshStandardMaterial({ color: 0x20262b, roughness: 0.55 });
  const swBody = new THREE.MeshStandardMaterial({ color: 0x23282d, roughness: 0.5 });
  const swPcb = new THREE.MeshStandardMaterial({ color: 0xe9eef1, roughness: 0.6 });
  const lever = new THREE.MeshStandardMaterial({ color: 0xc3cad0, roughness: 0.3, metalness: 0.85 });
  const edgeMat = new THREE.LineBasicMaterial({ color: 0x3b505c });
  const floorTop = CH / 2 - T - TOP;
  const bx = FLAT.at.x, bz = FLAT.at.z;
  const backIn = -CD / 2 + T;

  // 12V：插頭由後方插進 J5 → 沿背板內側往左 → 穿過左側板 → 在左外側離遠一點垂到地面 → 沿地面往左前方
  // （鏡頭看得到右側板，線若貼著左側板或走在背後，投影會落在櫃體輪廓內，看起來像穿過書櫃）
  const j5 = anchors.powerIn, jy = j5.y;
  const jackBack = bz - 1.0 - 0.07, plugEnd = jackBack - 0.16, runZ = backIn + 0.07;
  const plug = new THREE.Mesh(new THREE.CylinderGeometry(0.11, 0.11, 0.16, 20), cableMat);
  plug.rotation.x = Math.PI / 2;
  plug.position.set(j5.x, jy, jackBack - 0.08);
  const grommet = new THREE.Mesh(new THREE.CylinderGeometry(0.14, 0.14, T + 0.03, 24), new THREE.MeshStandardMaterial({ color: 0x15191c, roughness: 0.7 }));
  grommet.rotation.z = Math.PI / 2;
  grommet.position.set(-CW / 2 + T / 2, jy, runZ);
  extra.add(plug, grommet);
  const outX = -CW / 2 - 2.3, floorY = -CH / 2 + 0.06;
  extra.add(wire([V(j5.x, jy, plugEnd), V(j5.x, jy, runZ), V(outX, jy, runZ), V(outX, floorY, runZ), V(outX, floorY, 1.2), V(outX - 0.5, floorY, 2.3)], 0.06, cableMat));
  anchors.cableEntry = V(-CW / 2, jy, runZ);

  // 主幹：板子左前方沿頂列底板收線，再往下穿過各層板
  const tx = -IN_W / 2 + 0.14, tz = bz + 1.45, ty = floorTop + 0.06;
  extra.add(wire([V(tx, ty, bz + 1.05), V(tx, ty, tz), V(tx, cellY(3) - 0.3, tz)], 0.06, wireMat));
  // 電磁鎖端子台 J1–J4（右緣）→ 往右 → 沿底板繞到板子前方 → 往左接主幹；後排的線走外圈，彼此不交叉
  for (let k = 0; k < 4; k++) {
    const tk = P(`J${k + 1}`), xr = bx + 1.9 + (3 - k) * 0.05, yk = floorTop + 0.03 + k * 0.045;
    extra.add(wire([V(tk.x + 0.12, tk.y, tk.z), V(xr, tk.y, tk.z), V(xr, yk, tk.z), V(xr, yk, tz), V(tx + 0.06, yk, tz)], 0.022, wireMat));
  }
  // 門磁排針 J7–J10（前緣左側）→ 往前 → 往左接主幹
  for (let k = 0; k < 4; k++) {
    const hk = top(`J${k + 7}`), zk = bz + 1.12 + k * 0.045;
    extra.add(wire([V(hk.x, hk.y + 0.02, hk.z), V(hk.x, hk.y + 0.02, zk), V(hk.x, floorTop + 0.03, zk), V(tx + 0.06, floorTop + 0.03, zk)], 0.02, wireMat));
  }
  // 螢幕排線 J6（前緣中間）→ 從線束上方越過 → 沿底板往前 → 往右 → 螢幕背面
  const j6 = top('J6'), over = j6.y + 0.04;
  extra.add(wire([V(j6.x, j6.y + 0.02, j6.z), V(j6.x, over, j6.z + 0.12), V(j6.x, over, tz + 0.35), V(j6.x, floorTop + 0.04, tz + 0.6), V(j6.x, floorTop + 0.04, CD / 2 - 0.9), V(screenX - 0.3, floorTop + 0.04, CD / 2 - 0.9), V(screenX - 0.3, topRowY - 0.1, CD / 2 - 0.12)], 0.035, wireMat));

  for (let i = 0; i < 4; i++) {
    const name = `A0${i + 1}`;
    const sx = -1.45, sy = cellTop(i) - 0.2, sz = CD / 2 - 0.32;
    const pcb = new THREE.Mesh(new THREE.BoxGeometry(0.78, 0.04, 0.5), swPcb);
    pcb.position.set(sx, cellTop(i) - 0.02, sz - 0.02);
    const pe = new THREE.LineSegments(new THREE.EdgesGeometry(pcb.geometry), edgeMat);
    pe.position.copy(pcb.position);
    const body = new THREE.Mesh(new RoundedBoxGeometry(0.5, 0.26, 0.28, 2, 0.03), swBody);
    body.position.set(sx, sy + 0.02, sz);
    const lv = new THREE.Mesh(new THREE.BoxGeometry(0.44, 0.03, 0.03), lever);
    lv.position.set(sx + 0.05, sy - 0.08, sz + 0.2);
    lv.rotation.y = -0.35;
    extra.add(pcb, pe, body, lv);
    anchors[`switch${name}`] = V(sx, sy, sz + 0.14);
    anchors[`lock${name}`] = V(lockX, cellY(i), lockZ + LOCK.d / 2 + 0.03);
    const wy = cellTop(i) - 0.1, wx = -IN_W / 2 + 0.11, split = lockZ - LOCK.d / 2 - 0.22;
    extra.add(wire([V(tx, wy, tz), V(wx, wy, tz + 0.2), V(wx, wy, split), V(lockX - 0.3, wy, split), V(lockX - 0.3, cellY(i) + 0.15, split), V(lockX - 0.3, cellY(i) + 0.15, lockZ - LOCK.d / 2 + 0.05)], 0.03, wireMat));
    extra.add(wire([V(lockX - 0.3, wy, split), V(sx - 0.1, wy, split), V(sx - 0.1, wy, sz - 0.1)], 0.03, wireMat));
  }

  // 主控板各網格外框在板子座標的聯集（取景與外框座標用）
  g.updateMatrixWorld(true);
  const inv = new THREE.Matrix4().copy(g.matrixWorld).invert();
  const local = new THREE.Box3();
  g.traverseVisible((o) => {
    const mesh = o as THREE.Mesh;
    if (!mesh.isMesh) return;
    if (!mesh.geometry.boundingBox) mesh.geometry.computeBoundingBox();
    local.union(mesh.geometry.boundingBox!.clone().applyMatrix4(new THREE.Matrix4().multiplyMatrices(inv, mesh.matrixWorld)));
  });
  const plate = new THREE.Box3().setFromObject(g.getObjectByName('board')!).applyMatrix4(inv);
  return { anchors, board: g, extra, local, plate };
}

/** 柔和的圓形接觸陰影（不跟著板子轉）。 */
function discShadow(r: number) {
  const c = document.createElement('canvas');
  c.width = c.height = 512;
  const g = c.getContext('2d')!;
  const grad = g.createRadialGradient(256, 256, 0, 256, 256, 256);
  grad.addColorStop(0, 'rgba(16,28,36,0.30)');
  grad.addColorStop(0.55, 'rgba(16,28,36,0.20)');
  grad.addColorStop(0.82, 'rgba(16,28,36,0.07)');
  grad.addColorStop(1, 'rgba(16,28,36,0)');
  g.fillStyle = grad;
  g.fillRect(0, 0, 512, 512);
  const m = new THREE.Mesh(new THREE.PlaneGeometry(r * 2, r * 2), new THREE.MeshBasicMaterial({ map: canvasTex(c), transparent: true, depthWrite: false, toneMapped: false, opacity: 0 }));
  m.rotation.x = -Math.PI / 2;
  m.renderOrder = -1;
  return m;
}

/** 把一組物件整體淡出：記住原本的透明設定，alpha = 1 時完全還原（第一格與靜態透視圖逐像素一致）。 */
function fader(objs: THREE.Object3D[]) {
  const base = new Map<THREE.Material, { opacity: number; transparent: boolean; depthWrite: boolean }>();
  const all: THREE.Object3D[] = [];
  for (const root of objs) root.traverse((o) => {
    all.push(o);
    const m = (o as THREE.Mesh).material;
    for (const mat of m ? (Array.isArray(m) ? m : [m]) : []) if (!base.has(mat)) base.set(mat, { opacity: mat.opacity, transparent: mat.transparent, depthWrite: mat.depthWrite });
  });
  const vis = new Map(all.map((o) => [o, o.visible]));
  let last = 1;
  return (a: number) => {
    if (a === last) return;
    last = a;
    for (const o of all) o.visible = a > 0.001 && vis.get(o)!;
    for (const [mat, b] of base) {
      const fade = a < 0.999;
      const transparent = fade ? true : b.transparent;
      if (mat.transparent !== transparent) mat.needsUpdate = true;
      mat.transparent = transparent;
      mat.opacity = fade ? b.opacity * a : b.opacity;
      mat.depthWrite = fade ? false : b.depthWrite;
    }
  };
}

/* ---------- 各模式 ---------- */

declare global {
  interface Window { __ready: boolean; __seek: (t: number) => Promise<void>; __info: () => unknown; __collide: (t: number) => string[] }
}

let book: DeckBook | null = null;
let cab: Cabinet;
let gifAt: (t: number) => void = () => {};

async function main() {
  await loadFonts();
  cab = new Cabinet(KIOSK_NAME);
  stage.scene.add(cab.group);
  const cover = await loadTex('/deck/cover_html_css.jpg');
  book = new DeckBook(cover);
  cab.group.add(book.group);
  // 等標誌貼紙（非同步載入）畫好
  await new Promise((r) => setTimeout(r, 300));

  const info: Record<string, unknown> = { mode: MODE, flow: FLOW, viewport: [VW, VH], pr: PR, tl: TL };
  const shadow = floorShadow(CW * 1.55, CD * 1.6, 0.36);
  shadow.position.set(0.3, -CH / 2 + 0.01, -0.3);

  if (MODE === 'gif') {
    cab.group.rotation.set(0, Number(params.get('ry') ?? (FRONT_CAM ? FRONT_VIEW.ry : 0.22)), 0);
    cab.group.add(shadow);
    const pts = cabinetCorners(true);
    for (let t = TL.bookIn; t <= TL.bookEnd; t += 0.05) {
      const p = bookPose(t);
      if ((p.op ?? 1) < 0.05) continue;
      book.set(p);
      book.group.updateMatrixWorld(true);
      for (const x of [-1, 1]) for (const y of [-1, 1]) for (const z of [-1, 1]) pts.push(V(x * BOOK.w / 2, y * BOOK.t / 2, z * BOOK.l / 2).applyMatrix4(book.group.matrix));
    }
    cab.group.updateMatrixWorld(true);
    // 地面柔影的前緣也要留在畫面內
    pts.push(V(0, -CH / 2, CD * 0.75));
    const wpts = pts.map((p) => p.clone().applyMatrix4(cab.group.matrixWorld));
    fitCamera(wpts, Number(params.get('el') ?? (FRONT_CAM ? FRONT_VIEW.el : 0.24)), { x: Number(params.get('padx') ?? 0.05), y: Number(params.get('pady') ?? 0.08) });
    const pp = wpts.map(toPx);
    info.content = [Math.min(...pp.map((q) => q[0])), Math.min(...pp.map((q) => q[1])), Math.max(...pp.map((q) => q[0])), Math.max(...pp.map((q) => q[1]))].map((v) => Math.round(v / PR));
    gifAt = (t: number) => {
      const tt = ((t % TL.loop) + TL.loop) % TL.loop;
      drawKiosk(cab, kioskAt(tt));
      cab.doors[0].pivot.rotation.y = doorAt(tt) * DOOR_MAX;
      book!.set(bookPose(tt));
      stage.render();
    };
    window.__seek = async (t: number) => gifAt(t);
    window.__collide = (t: number) => collide(t);
    gifAt(Number(params.get('t') ?? 0));
  } else if (MODE === 'hero') {
    cab.group.rotation.set(0, Number(params.get('ry') ?? (FRONT_CAM ? FRONT_VIEW.ry : HERO_RY)), 0);
    cab.group.add(shadow);
    book.set(P_REST);
    drawKiosk(cab, { state: 'qr', refresh: 0.3, seconds: 60, digits: 1, check: 0 });
    cab.group.updateMatrixWorld(true);
    // 地面柔影的可見範圍也要在畫面內，裁切時才不會切到
    // 正面鏡頭幾乎平視，柔影左右兩端整段都看得到，要整片納入
    const pts = [...cabinetCorners(false), ...shadowExtent(FRONT_CAM ? 1.0 : 0.72)].map((p) => p.applyMatrix4(cab.group.matrixWorld));
    fitCamera(pts, Number(params.get('el') ?? (FRONT_CAM ? FRONT_VIEW.el : HERO_EL)), { x: 0.04, y: 0.04 });
    stage.render();
  } else if (MODE === 'xray') {
    cab.group.rotation.set(0, Number(params.get('ry') ?? (FRONT_CAM ? FRONT_VIEW.ry : 0.36)), 0);
    book.set({ ...P_REST, op: 0 });
    drawKiosk(cab, { state: 'qr', refresh: 0.3, seconds: 60, digits: 1, check: 0 });
    const { anchors, source } = await buildXray(cab);
    cab.setXray(1);
    // 透視時標誌貼紙淡化
    cab.group.traverse((o) => {
      const m = (o as THREE.Mesh).material as THREE.MeshBasicMaterial | undefined;
      const geo = (o as THREE.Mesh).geometry as THREE.PlaneGeometry | undefined;
      if (m && (o as THREE.Mesh).isMesh && o.renderOrder === 1 && geo?.parameters?.width === 3.85) m.opacity = FRONT_CAM ? 0.14 : 0.22;
    });
    cab.group.updateMatrixWorld(true);
    const pts = cabinetCorners(false);
    pts.push(V(-CW / 2 - CABLE_OUT - 1.6, -CH / 2, -2.7), V(-CW / 2 - CABLE_OUT, CH / 2 + 0.7, -3.4));
    fitCamera(pts.map((p) => p.applyMatrix4(cab.group.matrixWorld)), Number(params.get('el') ?? (FRONT_CAM ? FRONT_VIEW.el : 0.12)), { x: 0.05, y: 0.05 });
    stage.render();
    const w = (v: THREE.Vector3) => toPx(v.clone().applyMatrix4(cab.group.matrixWorld));
    const pts2: Record<string, [number, number]> = { screen: w(V(screenX, topRowY, CD / 2)) };
    for (const [k, v] of Object.entries(anchors)) pts2[k] = w(v);
    info.points = pts2;
    info.boardSource = source;
  } else if (MODE === 'spin') {
    // 書櫃繞垂直軸轉一圈，鏡頭固定；地面柔影固定在書櫃正下方（圓形，轉動時不跟著偏）
    book.set(P_REST);
    drawKiosk(cab, { state: 'qr', refresh: 0.3, seconds: 60, digits: 1, check: 0 });
    const round = floorShadow(CW * 2.0, CW * 2.0, 0.32);
    round.position.set(0, -CH / 2 + 0.01, 0);
    stage.scene.add(round);
    const pts: THREE.Vector3[] = [];
    const ry0 = FRONT_CAM ? FRONT_VIEW.ry : HERO_RY;
    for (let k = 0; k < 72; k++) {
      cab.group.rotation.set(0, ry0 + (k / 72) * Math.PI * 2, 0);
      cab.group.updateMatrixWorld(true);
      for (const p of cabinetCorners(false)) pts.push(p.applyMatrix4(cab.group.matrixWorld));
    }
    for (let k = 0; k < 16; k++) { const a = (k / 16) * Math.PI * 2; pts.push(V(Math.cos(a) * CW * 0.72, -CH / 2, Math.sin(a) * CW * 0.72)); }
    fitCamera(pts, Number(params.get('el') ?? (FRONT_CAM ? FRONT_VIEW.el : HERO_EL)), { x: 0.06, y: 0.06 });
    gifAt = (t: number) => {
      const k = (((t % SPIN_PERIOD) + SPIN_PERIOD) % SPIN_PERIOD) / SPIN_PERIOD;
      cab.group.rotation.set(0, ry0 + k * Math.PI * 2, 0);
      stage.render();
    };
    window.__seek = async (t: number) => gifAt(t);
    info.tl = { loop: SPIN_PERIOD };
    gifAt(Number(params.get('t') ?? 0));
  } else if (MODE === 'flat') {
    const WIDE = params.get('wide') === '1';
    const LAYER = params.get('layer');
    stage.camera.fov = FRONT_VIEW.fov;
    stage.camera.near = 1;
    // 寬版與分層：鏡頭的完整畫面維持原透視畫布的比例（取景計算都在這個畫面上），實際畫布用 setViewOffset 開窗
    if (WIDE || LAYER) stage.camera.aspect = FLAT_WIDE.aspect;
    stage.camera.updateProjectionMatrix();
    stage.scene.fog = null;
    cab.group.rotation.set(0, FRONT_VIEW.ry, 0);
    book.set({ ...P_REST, op: 0 });
    drawKiosk(cab, { state: 'qr', refresh: 0.3, seconds: 60, digits: 1, check: 0 });
    const fx = await buildXrayFlat(cab);
    cab.setXray(1);
    cab.group.traverse((o) => {
      const m = (o as THREE.Mesh).material as THREE.MeshBasicMaterial | undefined;
      const geo = (o as THREE.Mesh).geometry as THREE.PlaneGeometry | undefined;
      if (m && (o as THREE.Mesh).isMesh && o.renderOrder === 1 && geo?.parameters?.width === 3.85) m.opacity = 0.14;
    });
    cab.group.updateMatrixWorld(true);
    // 板下柔影：圓形、固定不轉，推進後段才淡入
    const lb = fx.local;
    const disc = discShadow(Math.hypot(lb.max.x - lb.min.x, lb.max.z - lb.min.z) / 2 + 0.35);
    disc.position.set(FLAT.at.x, FLAT.at.y - 0.004, FLAT.at.z);
    cab.group.add(disc);
    const fadeOut = fader(cab.group.children.filter((o) => o !== fx.board && o !== disc));
    const W2 = (v: THREE.Vector3) => v.clone().applyMatrix4(cab.group.matrixWorld);
    const boxPts = (b: THREE.Box3, m: THREE.Matrix4) => { const o: THREE.Vector3[] = []; for (let i = 0; i < 8; i++) o.push(V(i & 1 ? b.max.x : b.min.x, i & 2 ? b.max.y : b.min.y, i & 4 ? b.max.z : b.min.z).applyMatrix4(m)); return o; };
    // 推進終點（先算，fitCamera 會改動鏡頭）
    fx.board.updateMatrixWorld(true);
    const endAz = FRONT_VIEW.ry + FLAT.endAz;
    const Wv = VH * FLAT_WIDE.aspect;
    const endPad = WIDE ? { x: 1 - (FLAT_WIDE.w * VW) / Wv, y: -10 } : { x: 1 - FLAT.endWidth, y: 0.02 };
    const end = fitCamera(boxPts(fx.local, fx.board.matrixWorld), FLAT.endEl, endPad, { x: 0, y: 0 }, endAz);
    // 起點：與正面透視圖同樣的取景，納入書櫃外框與 12V 電源線
    const pts = cabinetCorners(false);
    pts.push(V(-CW / 2 - 2.9, -CH / 2, 2.4), V(-CW / 2 - 2.4, CH / 2 - 1.8, -CD / 2), V(-CW / 2 - 2.4, -CH / 2, -CD / 2));
    const start = fitCamera(pts.map(W2), FLAT.el, { x: 0.05, y: 0.05 });
    if (LAYER) {
      await flatLayer(LAYER, fx, disc, fadeOut, boxPts, info);
      window.__info = () => info;
      window.__ready = true;
      return;
    }
    const cabBox = new THREE.Box3().setFromObject(cab.group);
    let minGap = Infinity;
    // 推進路徑以主控板為準：板子在畫面上的位置沿直線移到正中央、與鏡頭的距離按等比縮短，鏡頭角度同步轉到 3/4 俯視；
    // 第 0 格與起點取景完全相同，最後一格與終點取景完全相同
    const B = end.target.clone();
    const dirOf = (az: number, el: number) => V(Math.sin(az) * Math.cos(el), Math.sin(el), Math.cos(az) * Math.cos(el));
    const tanH = Math.tan(THREE.MathUtils.degToRad(stage.camera.fov / 2));
    const basis = (az: number, el: number) => {
      const d = dirOf(az, el);
      const right = new THREE.Vector3().crossVectors(new THREE.Vector3(0, 1, 0), d).normalize();
      const up = new THREE.Vector3().crossVectors(d, right).normalize();
      return { d, right, up };
    };
    const c0 = stage.camera.position.clone().sub(B);
    const b0 = basis(0, FLAT.el);
    const dB0 = c0.dot(b0.d), nx0 = -c0.dot(b0.right) / (dB0 * tanH * stage.camera.aspect), ny0 = -c0.dot(b0.up) / (dB0 * tanH);
    const camAt = (k: number) => {
      const az = endAz * k, el = FLAT.el + (FLAT.endEl - FLAT.el) * k;
      const { d, right, up } = basis(az, el);
      const dB = Math.exp(Math.log(dB0) + (Math.log(end.dist) - Math.log(dB0)) * k);
      const nx = nx0 * (1 - k), ny = ny0 * (1 - k);
      const cam = stage.camera;
      cam.position.copy(B).addScaledVector(d, dB).addScaledVector(right, -nx * dB * tanH * cam.aspect).addScaledVector(up, -ny * dB * tanH);
      cam.lookAt(cam.position.clone().sub(d));
      cam.updateMatrixWorld(true);
    };
    const at = (t: number) => {
      const z = Math.min(1, Math.max(0, t / FLAT.zoom));
      const k = easeInOut(z);
      if (k <= 0) { stage.camera.position.copy(start.target).addScaledVector(dirOf(0, FLAT.el), start.dist); stage.camera.lookAt(start.target); stage.camera.updateMatrixWorld(true); }
      else camAt(k);
      if (WIDE) {
        // 主點（完整畫面中心）在畫布上的位置：起點靠右（完整畫面右緣貼齊畫布右緣），終點為左側大框中主控板的位置
        const px = (VW - Wv / 2) + (FLAT_WIDE.cx * VW - (VW - Wv / 2)) * k;
        const py = VH / 2 + (FLAT_WIDE.cy * VH - VH / 2) * k;
        stage.camera.setViewOffset(Wv, VH, Wv / 2 - px, VH / 2 - py, VW, VH);
      }
      minGap = Math.min(minGap, cabBox.distanceToPoint(stage.camera.position));
      fadeOut(1 - easeInOut(span(t, FLAT.fade[0], FLAT.fade[1])));
      (disc.material as THREE.MeshBasicMaterial).opacity = easeInOut(span(t, FLAT.shadow[0], FLAT.shadow[1]));
      const T = FLAT.spin * FLAT.turns, u = Math.min(Math.max(0, t - FLAT.zoom), T), A = Math.PI * 2 * FLAT.turns;
      if (WIDE) {
        // 梯形速度：推進停下後轉盤緩緩起步，最後一圈緩緩停在原位
        const r = FLAT_WIDE.ramp, v = A / (T - r);
        fx.board.rotation.y = u < r ? (v * u * u) / (2 * r) : u > T - r ? A - (v * (T - u) * (T - u)) / (2 * r) : v * (u - r / 2);
      } else fx.board.rotation.y = ((u % FLAT.spin) / FLAT.spin) * Math.PI * 2;
      stage.render();
    };
    gifAt = at;
    window.__seek = async (t: number) => at(t);
    at(0);
    const w = (v: THREE.Vector3) => toPx(W2(v));
    const pts2: Record<string, [number, number]> = { screen: w(V(screenX, topRowY, CD / 2)) };
    for (const [key, v] of Object.entries(fx.anchors)) pts2[key] = w(v);
    const bb = boxPts(fx.local, fx.board.matrixWorld).map(toPx);
    const xs = bb.map((q) => q[0]), ys = bb.map((q) => q[1]);
    const pl = fx.plate;
    const corners = [[pl.min.x, pl.min.z], [pl.max.x, pl.min.z], [pl.max.x, pl.max.z], [pl.min.x, pl.max.z]].map(([x, zz]) => toPx(V(x, pl.max.y, zz).applyMatrix4(fx.board.matrixWorld)));
    info.points = pts2;
    info.boardBox = [Math.min(...xs), Math.min(...ys), Math.max(...xs) - Math.min(...xs), Math.max(...ys) - Math.min(...ys)].map((v) => +v.toFixed(1));
    info.boardCorners = corners;
    info.tl = { loop: FLAT.zoom + FLAT.spin * FLAT.turns, zoom: FLAT.zoom, spin: FLAT.spin, turns: FLAT.turns };
    (window as unknown as { __boardBox: (t: number) => number[] }).__boardBox = (t: number) => {
      at(t);
      fx.board.updateMatrixWorld(true);
      const q = boxPts(fx.local, fx.board.matrixWorld).map(toPx);
      const qx = q.map((v) => v[0]), qy = q.map((v) => v[1]);
      return [Math.min(...qx), Math.min(...qy), Math.max(...qx), Math.max(...qy)].map((v) => +v.toFixed(1));
    };
    info.camera = { start: { dist: +start.dist.toFixed(3) }, end: { dist: +end.dist.toFixed(3) } };
    (window as unknown as { __gap: () => number }).__gap = () => minGap;
  } else if (MODE === 'glb') {
    book.set(P_REST);
    drawKiosk(cab, { state: 'qr', refresh: 0.3, seconds: 60, digits: 1, check: 0 });
    cover.userData.mimeType = 'image/jpeg';
    Object.assign(info, await exportGlb());
  } else {
    await cover2(info);
  }

  window.__info = () => info;
  window.__ready = true;
}


/**
 * 簡報用的分層素材（PowerPoint 以平滑轉場放大同一張主控板圖，再接旋轉影片），鏡頭同平放透視的起點：
 * - noboard：透視圖隱藏主控板（含開發板與板上元件），配線保留。
 * - board：只畫主控板；region=x,y,w,h（2000×2200 透視畫布的像素）時以 setViewOffset 只算這一塊，用高倍率算圖等於放大後裁切。
 * - over：主控板前方的配線與櫃體面板（疊在 board 上即還原完整透視圖），取景同 board。
 * - spin：影片（畫布 2208×1376）。rect=x,y,w,h 為 board_layer_hr 在透視畫布中的位置；第 0 格是同一個鏡頭只放大，
 *   板圖對到置中、寬 1700 的 target；1.2–2.4 秒轉到 3/4 俯視（板子保持置中、寬約 1650）；2.4 秒起原地轉 3 圈。
 */
const SPIN_FROM_FLAT = {
  hold: 1.2,
  turn: 2.4,
  /** 第 0 格板圖寬（相對畫布寬 2208）。 */
  startW: 1700 / 2208,
  /** 終點：外框角點投影的寬與中心（相對畫布）；高元件使角點框偏上偏寬，實際像素寬約 1650、置中。 */
  endW: 1696 / 2208,
  endCx: 1095 / 2208,
  endCy: 638 / 1376,
  spin: 12,
  turns: 3,
  ramp: 1,
};

async function flatLayer(layer: string, fx: { board: THREE.Group; local: THREE.Box3 }, disc: THREE.Mesh, fadeOut: (a: number) => void, boxPts: (b: THREE.Box3, m: THREE.Matrix4) => THREE.Vector3[], info: Record<string, unknown>) {
  const cam = stage.camera;
  fx.board.updateMatrixWorld(true);
  const bb = boxPts(fx.local, fx.board.matrixWorld);
  const projBox = () => { const q = bb.map(toPx); return [Math.min(...q.map((v) => v[0])), Math.min(...q.map((v) => v[1])), Math.max(...q.map((v) => v[0])), Math.max(...q.map((v) => v[1]))]; };
  info.boardBox = projBox();
  if (layer === 'noboard') {
    fx.board.visible = false;
    disc.visible = false;
    stage.render();
    return;
  }
  const region = params.get('region');
  if (region) {
    const [x, y, w, h] = region.split(',').map(Number);
    cam.setViewOffset(2000, 2200, x, y, w, h);
    cam.updateProjectionMatrix();
  }
  if (layer === 'over') {
    // 主控板前方的東西（配線、櫃體半透明面板與輪廓線）：主控板只寫深度不上色，板子後方的東西被擋掉
    disc.visible = false;
    fx.board.traverse((o) => {
      const m = (o as THREE.Mesh).material;
      for (const mat of m ? (Array.isArray(m) ? m : [m]) : []) mat.colorWrite = false;
    });
    stage.render();
    return;
  }
  fadeOut(0);
  disc.visible = false;
  if (layer === 'board') {
    stage.render();
    return;
  }
  cam.clearViewOffset();
  // spin
  const [rx, ry, rw] = params.get('rect')!.split(',').map(Number);
  const rh = Number(params.get('rect')!.split(',')[3]);
  const Wd = VW * PR, Hd = VH * PR;
  const tanH = Math.tan(THREE.MathUtils.degToRad(cam.fov / 2));
  const tw = Wd * SPIN_FROM_FLAT.startW, th = rh * tw / rw;
  const tx = (Wd - tw) / 2, ty = (Hd - th) / 2;
  const sc = tw / rw;
  const f0 = sc * 1100 / tanH;
  const pp0 = V(tx + (1000 - rx) * sc, ty + (1100 - ry) * sc, 0);
  const startPos = cam.position.clone(), startQ = cam.quaternion.clone();
  // 終點取景：畫布比例、無偏移
  cam.aspect = Wd / Hd;
  cam.updateProjectionMatrix();
  const endAz = FRONT_VIEW.ry + FLAT.endAz;
  const end = fitCamera(bb, FLAT.endEl, { x: 1 - SPIN_FROM_FLAT.endW, y: -10 }, { x: 0, y: 0 }, endAz);
  cam.aspect = FLAT_WIDE.aspect;
  cam.position.copy(startPos);
  cam.quaternion.copy(startQ);
  cam.updateMatrixWorld(true);
  const B = end.target.clone();
  const f1 = (Hd / 2) / tanH;
  const pp1 = V(Wd * SPIN_FROM_FLAT.endCx, Hd * SPIN_FROM_FLAT.endCy, 0);
  const dirOf = (az: number, el: number) => V(Math.sin(az) * Math.cos(el), Math.sin(el), Math.cos(az) * Math.cos(el));
  const basis = (az: number, el: number) => {
    const d = dirOf(az, el);
    const r = new THREE.Vector3().crossVectors(new THREE.Vector3(0, 1, 0), d).normalize();
    const u = new THREE.Vector3().crossVectors(d, r).normalize();
    return { d, r, u };
  };
  const b0 = basis(0, FLAT.el);
  const c0 = startPos.clone().sub(B);
  const dB0 = c0.dot(b0.d), nx0 = -c0.dot(b0.r) / dB0, ny0 = -c0.dot(b0.u) / dB0;
  const C0 = V(pp0.x + f0 * nx0, pp0.y - f0 * ny0, 0);
  const lerpLog = (a: number, b: number, k: number) => Math.exp(Math.log(a) + (Math.log(b) - Math.log(a)) * k);
  // 板子參考點在畫布上的位置由起點平移到終點，主點跟著反推，運鏡途中板子一直在畫面中間
  const at = (t: number) => {
    const k = easeInOut(span(t, SPIN_FROM_FLAT.hold, SPIN_FROM_FLAT.turn));
    const { d, r, u } = basis(endAz * k, FLAT.el + (FLAT.endEl - FLAT.el) * k);
    const dB = lerpLog(dB0, end.dist, k), f = lerpLog(f0, f1, k);
    const nx = nx0 * (1 - k), ny = ny0 * (1 - k);
    const C = C0.clone().lerp(pp1, k);
    const ppx = C.x - f * nx, ppy = C.y + f * ny;
    cam.position.copy(B).addScaledVector(d, dB).addScaledVector(r, -nx * dB).addScaledVector(u, -ny * dB);
    cam.lookAt(cam.position.clone().sub(d));
    cam.updateMatrixWorld(true);
    const Hf = 2 * f * tanH, Wf = Hf * FLAT_WIDE.aspect;
    cam.setViewOffset(Wf, Hf, Wf / 2 - ppx, Hf / 2 - ppy, Wd, Hd);
    cam.updateProjectionMatrix();
    const sh = easeInOut(span(t, SPIN_FROM_FLAT.hold, SPIN_FROM_FLAT.turn));
    disc.visible = sh > 0.001;
    (disc.material as THREE.MeshBasicMaterial).opacity = sh;
    const T = SPIN_FROM_FLAT.spin * SPIN_FROM_FLAT.turns, A = Math.PI * 2 * SPIN_FROM_FLAT.turns, rr = SPIN_FROM_FLAT.ramp, v = A / (T - rr);
    const w = Math.min(Math.max(0, t - SPIN_FROM_FLAT.turn), T);
    fx.board.rotation.y = w < rr ? (v * w * w) / (2 * rr) : w > T - rr ? A - (v * (T - w) * (T - w)) / (2 * rr) : v * (w - rr / 2);
    stage.render();
  };
  window.__seek = async (t: number) => at(t);
  (window as unknown as { __boardBox: (t: number) => number[] }).__boardBox = (t: number) => { at(t); fx.board.updateMatrixWorld(true); bb.splice(0, 8, ...boxPts(fx.local, fx.board.matrixWorld)); return projBox(); };
  at(0);
  info.target = [tx, ty, tw, th];
  info.tl = { loop: SPIN_FROM_FLAT.turn + SPIN_FROM_FLAT.spin * SPIN_FROM_FLAT.turns };
}

/* ---------- PowerPoint 3D 模型（GLB） ---------- */

/**
 * 只留櫃體：合板、壓克力面板與櫃門、螢幕（QR 畫面）、標誌、四本書、電磁鎖與鉸鏈；不含燈光、地面、陰影與透視元件。
 * 單位公尺（書櫃 1 單位 = 4 公分）、原點在櫃體底面中心、Y 軸朝上、正面朝 +Z。
 * 不受光的貼圖（螢幕、標誌、門牌）改成標準材質加自發光，PowerPoint 不支援 unlit 也一樣亮；
 * 櫃門壓克力維持 alphaMode BLEND，白色面板與門框改成不透明，減少透明排序問題。
 */
async function exportGlb(solid = params.get('solid') === '1') {
  const g = cab.group;
  const drop: THREE.Object3D[] = [];
  const parts = (cab as unknown as { parts: THREE.Group }).parts;
  drop.push(parts);
  g.traverse((o) => {
    if (o === g || o === parts) return;
    const mesh = o as THREE.Mesh;
    if ((o as THREE.LineSegments).isLineSegments) { drop.push(o); return; }
    if (!mesh.isMesh && o.children.length === 0) { drop.push(o); return; }
    if (mesh.isMesh && !o.visible) { drop.push(o); return; }
    // 櫃門上的反光貼片（影片用的假反射）不匯出
    if (mesh.isMesh && mesh.geometry.type === 'PlaneGeometry' && (mesh.geometry as THREE.PlaneGeometry).parameters.width > 7) drop.push(o);
  });
  for (const o of drop) o.parent?.remove(o);
  const converted = new Map<THREE.Material, THREE.Material>();
  g.traverse((o) => {
    const mesh = o as THREE.Mesh;
    if (!mesh.isMesh) return;
    const conv = (m: THREE.Material) => {
      if (converted.has(m)) return converted.get(m)!;
      let out = m;
      if ((m as THREE.MeshBasicMaterial).isMeshBasicMaterial) {
        const b = m as THREE.MeshBasicMaterial;
        out = new THREE.MeshStandardMaterial({
          map: b.map, color: b.color, transparent: b.transparent, opacity: b.opacity, roughness: 0.55, metalness: 0,
          emissive: b.map ? 0xe6e6e6 : 0x000000, emissiveMap: b.map, side: b.side,
        });
        out.name = b.map ? 'printed' : 'band';
      } else if ((m as THREE.MeshStandardMaterial).isMeshStandardMaterial && m.transparent && m.opacity > 0.9) {
        // 白色壓克力面板（0.94）與門框（0.95）幾乎不透明：改為不透明
        const c = (m as THREE.MeshStandardMaterial).clone();
        c.transparent = false;
        c.opacity = 1;
        c.depthWrite = true;
        out = c;
      } else if ((m as THREE.MeshStandardMaterial).isMeshStandardMaterial && m.transparent) {
        out = (m as THREE.MeshStandardMaterial).clone();
        out.name = 'acrylic-door';
        if (solid) {
          // 備用版：櫃門改為不透明的白霧壓克力
          out = new THREE.MeshStandardMaterial({ color: 0xeef3f6, roughness: 0.42, metalness: 0 });
          out.name = 'acrylic-door-frosted';
        }
      }
      // 備用版不留任何 BLEND：印刷貼圖改用 MASK（alphaCutoff 0.5），無貼圖的半透明條改為不透明
      if (solid && out.transparent) {
        const sm = out as THREE.MeshStandardMaterial;
        sm.transparent = false;
        sm.opacity = 1;
        sm.depthWrite = true;
        if (sm.map) sm.alphaTest = 0.5;
      }
      converted.set(m, out);
      return out;
    };
    mesh.material = Array.isArray(mesh.material) ? mesh.material.map(conv) : conv(mesh.material);
  });
  const root = new THREE.Group();
  root.name = 'SaveMyBook_SmartCabinet';
  const unit = 0.04;
  g.position.set(0, CH / 2, 0);
  root.add(g);
  root.scale.setScalar(unit);
  root.updateMatrixWorld(true);
  const buf = (await new GLTFExporter().parseAsync(root, { binary: true, onlyVisible: true, maxTextureSize: 2048 })) as ArrayBuffer;
  // 讀回確認
  const gltf = await new GLTFLoader().parseAsync(buf.slice(0), '');
  let meshes = 0, prims = 0;
  const mats = new Set<THREE.Material>(), texs = new Set<THREE.Texture>();
  const blend: string[] = [];
  gltf.scene.traverse((o) => {
    const mesh = o as THREE.Mesh;
    if (!mesh.isMesh) return;
    meshes++;
    for (const m of Array.isArray(mesh.material) ? mesh.material : [mesh.material]) {
      prims++;
      mats.add(m);
      const sm = m as THREE.MeshStandardMaterial;
      for (const t of [sm.map, sm.emissiveMap, sm.roughnessMap, sm.normalMap]) if (t) texs.add(t);
      if (m.transparent && !blend.includes(m.name || m.uuid)) blend.push(m.name || m.uuid.slice(0, 8));
    }
  });
  const box = new THREE.Box3().setFromObject(gltf.scene);
  const size = box.getSize(new THREE.Vector3());
  // 讀回的模型直接算一張 3/4 視角預覽（tools/deck.mjs glb 截圖檢查）
  const view = new THREE.Group();
  view.add(gltf.scene);
  view.rotation.y = 0.55;
  stage.scene.add(view);
  view.updateMatrixWorld(true);
  const vb = new THREE.Box3().setFromObject(view);
  const vp: THREE.Vector3[] = [];
  for (const x of [vb.min.x, vb.max.x]) for (const y of [vb.min.y, vb.max.y]) for (const z of [vb.min.z, vb.max.z]) vp.push(V(x, y, z));
  stage.camera.near = 0.01;
  stage.camera.far = 50;
  stage.camera.updateProjectionMatrix();
  stage.scene.fog = null;
  fitCamera(vp, 0.25, { x: 0.08, y: 0.08 });
  stage.render();
  let bin = '';
  const bytes = new Uint8Array(buf);
  for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return {
    glb: btoa(bin),
    check: {
      bytes: bytes.length, meshes, primitives: prims, materials: mats.size, textures: texs.size, blendMaterials: blend,
      sizeM: [size.x, size.y, size.z].map((v) => +v.toFixed(4)), minY: +box.min.y.toFixed(4), center: [box.getCenter(new THREE.Vector3()).x, box.getCenter(new THREE.Vector3()).z].map((v) => +v.toFixed(4)),
    },
  };
}

/* ---------- 封面 ---------- */

/** 封面右半邊：書櫃在左，兩支手機一前一後在右；前方手機頂端低於書櫃右上角螢幕，不遮螢幕。 */
const COVER = {
  cab: { x: 0.31, y: 0.05, z: 0, rx: 0.06, ry: 0.3, rz: 0, s: 1.5 } as Pose,
  seller: { x: 0.59, y: -0.26, z: 8, rx: 0.03, ry: -0.2, rz: 0, s: 0.9 } as Pose,
  buyer: { x: 0.82, y: 0.13, z: 1, rx: 0.03, ry: -0.32, rz: 0, s: 0.86 } as Pose,
  sellerScreen: 's_cab_done',
  buyerScreen: 'b_home',
};

async function cover2(info: Record<string, unknown>) {
  const cfg = COVER;
  for (const k of ['cab', 'seller', 'buyer'] as const) {
    const q = params.get(k);
    if (q) for (const kv of q.split(',')) { const [a, b] = kv.split(':'); (cfg[k] as Record<string, number>)[a] = Number(b); }
  }
  const cam = stage.camera;
  cam.position.set(0, 0.4, 62);
  cam.lookAt(0, 0, 0);
  cam.updateMatrixWorld(true);
  place(cab.group, cfg.cab);
  const shadow = floorShadow(CW * 1.5, CD * 1.5, 0.32);
  shadow.position.set(0.5, -CH / 2 + 0.01, -0.3);
  cab.group.add(shadow);
  book!.set(P_REST);
  drawKiosk(cab, { state: 'qr', refresh: 0.3, seconds: 60, digits: 1, check: 0 });
  const phones: [Pose, string][] = [[cfg.seller, cfg.sellerScreen], [cfg.buyer, cfg.buyerScreen]];
  for (const [pose, scr] of phones) {
    const ph = new Phone();
    place(ph.group, pose);
    const tex = await screenTexture(scr, false);
    stage.renderer.initTexture(tex);
    ph.setScreens(tex, null, 0);
    stage.scene.add(ph.group);
    const sh = floorShadow(PHONE.W * 1.35, PHONE.D * 9, 0.22);
    sh.position.set(ph.group.position.x, ph.group.position.y - PHONE.H * (pose.s ?? 1) / 2 - 0.6, ph.group.position.z);
    stage.scene.add(sh);
  }
  stage.render();
  // 檢查：書櫃螢幕外框與手機外框在畫面上的範圍（裝置像素）
  cab.group.updateMatrixWorld(true);
  const bbox = (vs: THREE.Vector3[]) => { const p = vs.map(toPx); return [Math.min(...p.map((q) => q[0])), Math.min(...p.map((q) => q[1])), Math.max(...p.map((q) => q[0])), Math.max(...p.map((q) => q[1]))]; };
  const corners = (w: number, h: number, d: number) => { const o: THREE.Vector3[] = []; for (const x of [-1, 1]) for (const y of [-1, 1]) for (const z of [-1, 1]) o.push(V(x * w / 2, y * h / 2, z * d / 2)); return o; };
  info.kioskScreen = bbox([V(screenX - BEZEL_W / 2, topRowY - 0.77, FRONT), V(screenX + BEZEL_W / 2, topRowY + 0.77, FRONT)].map((v) => v.applyMatrix4(cab.group.matrixWorld)));
  info.cabinet = bbox(cabinetCorners(false).map((v) => v.applyMatrix4(cab.group.matrixWorld)));
  info.phones = stage.scene.children.filter((o) => o instanceof THREE.Group && o !== cab.group).map((g) => { g.updateMatrixWorld(true); return bbox(corners(PHONE.W, PHONE.H, PHONE.D).map((v) => v.applyMatrix4(g.matrixWorld))); });
}

/* ---------- 穿模檢查（GIF）：書與櫃門、書與書櫃結構 ---------- */
function collide(t: number): string[] {
  gifAt(t);
  const out: string[] = [];
  if (!book!.group.visible) return out;
  cab.group.updateMatrixWorld(true);
  book!.group.updateMatrixWorld(true);
  const samples = (w: number, h: number, d: number, m: THREE.Matrix4) => {
    const pts: THREE.Vector3[] = [];
    const n = 6;
    for (let i = 0; i <= n; i++) for (let j = 0; j <= n; j++) for (let k = 0; k <= n; k++) {
      const onFace = i === 0 || i === n || j === 0 || j === n || k === 0 || k === n;
      if (onFace) pts.push(V((i / n - 0.5) * w, (j / n - 0.5) * h, (k / n - 0.5) * d).applyMatrix4(m));
    }
    return pts;
  };
  const inv = new THREE.Matrix4();
  // 書（書櫃座標）
  const bookPts = samples(BOOK.w, BOOK.t, BOOK.l, book!.group.matrix);
  // 書櫃結構：在正面之前（z > FRONT）或在 A01 格內都算合法
  for (const p of bookPts) {
    const front = p.z > FRONT + 0.005;
    const inCell = Math.abs(p.x) < IN_W / 2 - 0.005 && p.y > floorY + 0.001 && p.y < floorY + CELL_H - 0.005 && p.z > -CD / 2 + T + 0.005;
    if (!front && !inCell) { out.push(`書碰到書櫃 (${p.x.toFixed(2)}, ${p.y.toFixed(2)}, ${p.z.toFixed(2)})`); break; }
  }
  // 櫃門：門板（含電磁鎖）在 pivot 座標中的範圍
  const pivot = cab.doors[0].pivot;
  pivot.updateMatrixWorld(true);
  const toDoor = inv.copy(pivot.matrix).invert();
  const dw = IN_W - 0.06, dh = CELL_H - 0.06;
  const inDoor = (q: THREE.Vector3) => q.x > -dw - 0.02 && q.x < 0.08 && Math.abs(q.y) < dh / 2 + 0.02 && q.z > -A / 2 - LOCK.d - 0.02 && q.z < A / 2 + 0.03;
  for (const p of bookPts) if (inDoor(p.clone().applyMatrix4(toDoor))) { out.push('書碰到櫃門'); break; }
  const doorPts = samples(dw, dh, A + LOCK.d, new THREE.Matrix4().makeTranslation(-dw / 2, 0, -LOCK.d / 2)).map((q) => q.applyMatrix4(pivot.matrix));
  const toBook = inv.copy(book!.group.matrix).invert();
  for (const p of doorPts) {
    const q = p.clone().applyMatrix4(toBook);
    if (Math.abs(q.x) < BOOK.w / 2 && Math.abs(q.y) < BOOK.t / 2 && Math.abs(q.z) < BOOK.l / 2) { out.push('櫃門穿過書'); break; }
  }
  return out;
}

main();
