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
type Mode = 'cover' | 'hero' | 'xray' | 'gif' | 'glb' | 'spin';
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
if (MODE === 'gif' || MODE === 'spin') document.body.style.background = GIF_BG;

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
function fitCamera(pts: THREE.Vector3[], el: number, pad: { x: number; y: number }, bias = { x: 0, y: 0 }) {
  const cam = stage.camera;
  const dir = new THREE.Vector3(0, Math.sin(el), Math.cos(el));
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
