import * as THREE from 'three';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';
import { GLTFExporter } from 'three/examples/jsm/exporters/GLTFExporter.js';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { mergeGeometries, mergeVertices } from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import { createPcb, pcbBox, pcbData, setPcbEsp32, PCB_REGIONS, PCB_SIZE, PCB_SCALE, type PcbRegion } from './deck/pcb';

/**
 * 主控板算圖頁：由 tools/pcb.mjs 呼叫 window.__pcb 逐張輸出透明 PNG。
 * 燈光、色調對應比照動畫的 Stage（src/stage.ts），燈光方向跟著鏡頭，換角度時明暗位置不變。
 */
type View = '3q' | 'top' | 'spin';

interface FrameOpts {
  view: View;
  esp32: boolean;
  /** 旋轉角（弧度，繞垂直軸）。 */
  angle?: number;
  /** 輸出寬度或高度（像素，擇一）。 */
  width?: number;
  height?: number;
  /** 取景時一併納入的角度與開發板狀態，讓多張圖framing一致。 */
  fitAngles?: number[];
  fitEsp32?: boolean[];
  /** 內容外圍留白（占內容寬高的比例）。 */
  margin?: number;
  /** 底下的柔和陰影：true 跟著板子的矩形陰影、'disc' 不旋轉的圓形陰影。 */
  shadow?: boolean | 'disc';
  /** 元件表面印字（繼電器、光耦、穩壓 IC、模組屏蔽罩）。 */
  decals?: boolean;
  /** 一併回傳各功能區在圖上的位置（畫面像素）。 */
  points?: boolean;
  /** 以讀回的 glb 取代原模型算圖（檢查用；取景仍以原模型計算）。 */
  glb?: boolean;
}

/** 3/4 視角標註點：功能區外框中心投影到畫面，另附投影後的外框。 */
const POINTS: { key: string; label: string; refs: string[] | 'devkit' }[] = [
  { key: 'power', label: '電源區（J5 12V DC 插座、C1、L7805、C2）', refs: PCB_REGIONS.power.refs },
  { key: 'powerIn', label: 'J5 12V DC 插座', refs: ['J5'] },
  { key: 'regulator', label: 'U4 L7805 穩壓', refs: ['U4'] },
  { key: 'esp32', label: 'ESP32-S3-DevKitC-1 開發板（插在 U1 排母）', refs: 'devkit' },
  { key: 'driver', label: '光耦驅動區（PC815 ×4、S8050 ×4、指示燈 D9–D12）', refs: [...PCB_REGIONS.driver.refs, ...PCB_REGIONS.led.refs] },
  { key: 'relays', label: '繼電器 K1–K4', refs: PCB_REGIONS.relay.refs },
  { key: 'locks', label: '電磁鎖端子台 J1–J4', refs: PCB_REGIONS.lock.refs },
  { key: 'door', label: '門磁排針 J7–J10', refs: PCB_REGIONS.door.refs },
  { key: 'tft', label: '螢幕排針 J6', refs: PCB_REGIONS.tft.refs },
  { key: 'headers', label: '門磁與螢幕排針（J7–J10、J6）', refs: [...PCB_REGIONS.door.refs, ...PCB_REGIONS.tft.refs] },
];

declare global {
  interface Window {
    __pcb: {
      ready: Promise<void>;
      frame: (o: FrameOpts) => { url: string; width: number; height: number; points: Record<string, unknown> };
      exportGlb: () => Promise<{ b64: string; sourceMeshes: number; meshes: number }>;
      loadGlb: (b64: string) => Promise<Record<string, unknown>>;
      top: (o: { pxPerMm: number; marginMm: [number, number, number, number]; esp32: boolean; shadow?: boolean }) => { url: string; width: number; height: number; regions: Record<string, unknown>; components: Record<string, number[]> };
    };
  }
}

const canvas = document.getElementById('gl') as HTMLCanvasElement;
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true, preserveDrawingBuffer: true });
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.NeutralToneMapping;
renderer.toneMappingExposure = 1.12;
renderer.setClearColor(0x000000, 0);
renderer.setPixelRatio(1);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFShadowMap;

const scene = new THREE.Scene();
const pmrem = new THREE.PMREMGenerator(renderer);
scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.035).texture;
scene.environmentIntensity = 0.9;
pmrem.dispose();

/** 燈光方向以鏡頭座標表示（同 Stage：鏡頭在 +z 看向原點）。 */
const LIGHTS: { dir: THREE.Vector3; color: number; intensity: number; shadow?: boolean }[] = [
  { dir: new THREE.Vector3(-18, 26, 34), color: 0xffffff, intensity: 1.7, shadow: true },
  { dir: new THREE.Vector3(22, -8, 18), color: 0xdfe8ee, intensity: 0.55 },
  { dir: new THREE.Vector3(14, 22, -40), color: 0xf4f8ff, intensity: 1.2 },
  { dir: new THREE.Vector3(-26, -6, -30), color: 0xdbe7f0, intensity: 0.7 },
];
const lights = LIGHTS.map((l) => {
  const d = new THREE.DirectionalLight(l.color, l.intensity);
  if (l.shadow) {
    d.castShadow = true;
    d.shadow.mapSize.set(4096, 4096);
    const c = d.shadow.camera;
    c.left = -110; c.right = 110; c.top = 110; c.bottom = -110; c.near = 20; c.far = 700;
    d.shadow.bias = -0.0004;
    d.shadow.normalBias = 0.03;
    d.shadow.radius = 5;
    d.shadow.intensity = 0.55;
  }
  scene.add(d, d.target);
  return d;
});
scene.add(new THREE.AmbientLight(0xffffff, 0.25));

const turn = new THREE.Group();
scene.add(turn);
const pcb = createPcb({ scale: PCB_SCALE.mm, esp32: true, shadows: true });
turn.add(pcb);

/** 板子下方的柔和接觸陰影（透明 PNG 中為半透明黑）。 */
const SH_PAD = 26;
const shadowTex = (() => {
  const c = document.createElement('canvas');
  const k = 8;
  c.width = (PCB_SIZE.w + SH_PAD * 2) * k;
  c.height = (PCB_SIZE.d + SH_PAD * 2) * k;
  const g = c.getContext('2d')!;
  g.filter = `blur(${7 * k}px)`;
  g.fillStyle = 'rgba(16,28,36,0.42)';
  g.beginPath();
  g.roundRect((SH_PAD - 1) * k, (SH_PAD - 1) * k, (PCB_SIZE.w + 2) * k, (PCB_SIZE.d + 2) * k, 4 * k);
  g.fill();
  g.filter = `blur(${1.6 * k}px)`;
  g.fillStyle = 'rgba(16,28,36,0.35)';
  g.beginPath();
  g.roundRect((SH_PAD + 1) * k, (SH_PAD + 1) * k, (PCB_SIZE.w - 2) * k, (PCB_SIZE.d - 2) * k, 2 * k);
  g.fill();
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
})();
const shadowPlane = new THREE.Mesh(
  new THREE.PlaneGeometry(PCB_SIZE.w + SH_PAD * 2, PCB_SIZE.d + SH_PAD * 2),
  new THREE.MeshBasicMaterial({ map: shadowTex, transparent: true, depthWrite: false, toneMapped: false }),
);
shadowPlane.rotation.x = -Math.PI / 2;
shadowPlane.position.y = -0.3;
shadowPlane.renderOrder = -1;
turn.add(shadowPlane);

/** 旋轉用的圓形地面陰影：不跟著板子轉，GIF 相鄰兩格之間板外的像素不變，檔案小很多。 */
const DISC_R = Math.hypot(PCB_SIZE.w, PCB_SIZE.d) / 2 + 4;
const discShadow = (() => {
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
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  const m = new THREE.Mesh(new THREE.PlaneGeometry(DISC_R * 2, DISC_R * 2), new THREE.MeshBasicMaterial({ map: t, transparent: true, depthWrite: false, toneMapped: false }));
  m.rotation.x = -Math.PI / 2;
  m.position.y = -0.3;
  m.renderOrder = -1;
  m.visible = false;
  scene.add(m);
  return m;
})();

/* ---------------- 鏡頭 ---------------- */

const persp = new THREE.PerspectiveCamera(24, 1, 10, 3000);
const ortho = new THREE.OrthographicCamera(-1, 1, 1, -1, 1, 1000);
const TARGET = new THREE.Vector3(0, 5, 0);

function aimPersp(elev: number, azim: number, dist: number) {
  const e = THREE.MathUtils.degToRad(elev), a = THREE.MathUtils.degToRad(azim);
  persp.position.set(TARGET.x + Math.sin(a) * Math.cos(e) * dist, TARGET.y + Math.sin(e) * dist, TARGET.z + Math.cos(a) * Math.cos(e) * dist);
  persp.up.set(0, 1, 0);
  persp.lookAt(TARGET);
  persp.clearViewOffset();
  persp.aspect = 1;
  persp.updateProjectionMatrix();
  persp.updateMatrixWorld();
}

/** 正上方俯視時主光改由接近頭頂的方向打下，陰影短、板面不反白。 */
const TOP_KEY = new THREE.Vector3(-20, 24, 30);

function placeLights(cam: THREE.Camera, topView = false) {
  cam.updateMatrixWorld();
  const q = new THREE.Quaternion();
  cam.getWorldQuaternion(q);
  renderer.toneMappingExposure = topView ? 0.98 : 1.12;
  scene.environmentIntensity = topView ? 0.42 : 0.9;
  lights[0].shadow.intensity = topView ? 0.32 : 0.55;
  lights[1].intensity = topView ? 0.25 : LIGHTS[1].intensity;
  LIGHTS.forEach((l, i) => {
    const d = (topView && i === 0 ? TOP_KEY : l.dir).clone().normalize().applyQuaternion(q);
    lights[i].position.copy(TARGET).addScaledVector(d, 350);
    lights[i].target.position.copy(TARGET);
    lights[i].target.updateMatrixWorld();
  });
}

const VIEWS: Record<Exclude<View, 'top'>, { elev: number; azim: number; dist: number }> = {
  // 接近 KiCad 截圖：前方偏左、俯角約 38 度
  '3q': { elev: 38, azim: -13, dist: 520 },
  spin: { elev: 34, azim: 0, dist: 560 },
};

/** 以各網格的外框角點投影到 NDC，取聯集外框。 */
function ndcBox(cam: THREE.Camera, angles: number[], esp: boolean[], shadow: boolean | 'disc') {
  const box = { x0: Infinity, x1: -Infinity, y0: Infinity, y1: -Infinity };
  const v = new THREE.Vector3();
  const add = (p: THREE.Vector3) => {
    v.copy(p).project(cam);
    box.x0 = Math.min(box.x0, v.x); box.x1 = Math.max(box.x1, v.x);
    box.y0 = Math.min(box.y0, v.y); box.y1 = Math.max(box.y1, v.y);
  };
  for (const on of esp) {
    setPcbEsp32(pcb, on);
    for (const a of angles) {
      turn.rotation.y = a;
      turn.updateMatrixWorld(true);
      pcb.traverseVisible((o) => {
        const mesh = o as THREE.Mesh;
        if (!mesh.isMesh) return;
        const g = mesh.geometry;
        if (!g.boundingBox) g.computeBoundingBox();
        const b = g.boundingBox!;
        for (let i = 0; i < 8; i++) {
          add(new THREE.Vector3(i & 1 ? b.max.x : b.min.x, i & 2 ? b.max.y : b.min.y, i & 4 ? b.max.z : b.min.z).applyMatrix4(mesh.matrixWorld));
        }
      });
      if (shadow === 'disc') {
        for (const sx of [-1, 1]) for (const sz of [-1, 1]) add(new THREE.Vector3(sx * DISC_R * 0.8, 0, sz * DISC_R * 0.8));
      } else if (shadow) {
        const ext = 9;
        for (const sx of [-1, 1]) for (const sz of [-1, 1]) add(new THREE.Vector3(sx * (PCB_SIZE.w / 2 + ext), 0, sz * (PCB_SIZE.d / 2 + ext)).applyMatrix4(turn.matrixWorld));
      }
    }
  }
  return box;
}

function frame(o: FrameOpts) {
  const v = VIEWS[o.view as Exclude<View, 'top'>];
  aimPersp(v.elev, v.azim, v.dist);
  placeLights(persp);
  const shadow = o.shadow ?? true;
  const b = ndcBox(persp, o.fitAngles ?? [o.angle ?? 0], o.fitEsp32 ?? [o.esp32], shadow);
  const F = 10000;
  let px0 = (b.x0 + 1) / 2 * F, px1 = (b.x1 + 1) / 2 * F;
  let py0 = (1 - b.y1) / 2 * F, py1 = (1 - b.y0) / 2 * F;
  const m = o.margin ?? 0.03;
  const mw = (px1 - px0) * m, mh = (py1 - py0) * m;
  const pad = Math.max(mw, mh);
  px0 -= pad; px1 += pad; py0 -= pad; py1 += pad;
  const aspect = (px1 - px0) / (py1 - py0);
  const width = o.width ?? Math.round((o.height! * aspect) / 2) * 2;
  const height = o.height ?? Math.round((o.width! / aspect) / 2) * 2;
  // 依輸出比例補齊較短的一邊（置中）
  const want = width / height;
  if (want > aspect) {
    const nw = (py1 - py0) * want;
    px0 -= (nw - (px1 - px0)) / 2; px1 = px0 + nw;
  } else {
    const nh = (px1 - px0) / want;
    py0 -= (nh - (py1 - py0)) / 2; py1 = py0 + nh;
  }
  persp.setViewOffset(F, F, px0, py0, px1 - px0, py1 - py0);
  persp.updateProjectionMatrix();
  setPcbEsp32(pcb, o.esp32);
  turn.rotation.y = o.angle ?? 0;
  const decals = o.decals ?? true;
  pcb.traverse((x) => { if (x.userData.decal) x.visible = decals; });
  shadowPlane.visible = shadow === true;
  discShadow.visible = shadow === 'disc';
  renderer.setSize(width, height, false);
  turn.updateMatrixWorld(true);
  const points: Record<string, unknown> = {};
  if (o.points) {
    const v = new THREE.Vector3();
    const proj = (p: THREE.Vector3) => { v.copy(p).project(persp); return [(v.x + 1) / 2 * width, (1 - v.y) / 2 * height]; };
    for (const pt of POINTS) {
      const box = new THREE.Box3();
      if (pt.refs === 'devkit') box.setFromObject(pcbData(pcb).devkit);
      else for (const r of pt.refs) box.union(pcbBox(pcb, r));
      const c = proj(box.getCenter(new THREE.Vector3()));
      const xs: number[] = [], ys: number[] = [];
      for (let i = 0; i < 8; i++) {
        const q = proj(new THREE.Vector3(i & 1 ? box.max.x : box.min.x, i & 2 ? box.max.y : box.min.y, i & 4 ? box.max.z : box.min.z));
        xs.push(q[0]); ys.push(q[1]);
      }
      points[pt.key] = { label: pt.label, x: c[0], y: c[1], box: [Math.min(...xs), Math.min(...ys), Math.max(...xs) - Math.min(...xs), Math.max(...ys) - Math.min(...ys)] };
    }
  }
  if (o.glb && glbView) { pcb.visible = false; glbView.visible = true; }
  renderer.render(scene, persp);
  pcb.visible = true;
  if (glbView) glbView.visible = false;
  return { url: canvas.toDataURL('image/png'), width, height, points };
}

/* ---------------- glb 匯出（PowerPoint 3D 模型用） ---------------- */

let glbView: THREE.Object3D | null = null;

/**
 * 插上開發板的主控板匯出成 glb：單位公尺、原點在板子中心（板厚一半處）、Y 朝上。
 * 依材質合併成少數幾個網格並把縮放烘進頂點；平貼的印字面往外推 0.03 公釐，避免檢視器深度精度不足時閃爍。
 */
async function exportGlb() {
  const src = createPcb({ scale: 0.001, esp32: true });
  await pcbData(src).ready;
  src.updateMatrixWorld(true);
  const lift = 0.00003;
  const center = new THREE.Matrix4().makeTranslation(0, -PCB_SIZE.t / 2 / 1000, 0);
  const buckets = new Map<THREE.Material, THREE.BufferGeometry[]>();
  const add = (mat: THREE.Material, g: THREE.BufferGeometry) => {
    if (!buckets.has(mat)) buckets.set(mat, []);
    buckets.get(mat)!.push(g);
  };
  const slice = (g: THREE.BufferGeometry, start: number, count: number) => {
    const out = new THREE.BufferGeometry();
    for (const name of ['position', 'normal', 'uv']) {
      const a = g.getAttribute(name) as THREE.BufferAttribute;
      out.setAttribute(name, new THREE.Float32BufferAttribute(Array.from(a.array as Float32Array).slice(start * a.itemSize, (start + count) * a.itemSize), a.itemSize));
    }
    return out;
  };
  let sourceMeshes = 0;
  src.traverseVisible((o) => {
    const mesh = o as THREE.Mesh;
    if (!mesh.isMesh) return;
    sourceMeshes++;
    const m = mesh.matrixWorld.clone().premultiply(center);
    const t = mesh.geometry.type;
    if (t === 'PlaneGeometry' || t === 'CircleGeometry') {
      const n = new THREE.Vector3(0, 0, 1).transformDirection(mesh.matrixWorld).multiplyScalar(lift);
      m.premultiply(new THREE.Matrix4().makeTranslation(n.x, n.y, n.z));
    }
    const g = (mesh.geometry.index ? mesh.geometry.toNonIndexed() : mesh.geometry.clone()).applyMatrix4(m);
    const count = g.getAttribute('position').count;
    if (Array.isArray(mesh.material)) {
      const groups = g.groups.length ? g.groups : [{ start: 0, count, materialIndex: 0 }];
      for (const grp of groups) add(mesh.material[grp.materialIndex ?? 0], slice(g, grp.start, Math.min(grp.count, count - grp.start)));
    } else add(mesh.material, slice(g, 0, count));
  });
  const root = new THREE.Group();
  root.name = 'DoorLock_ESP32-S3_RevA';
  let i = 0;
  for (const [mat, list] of buckets) {
    const merged = mergeVertices(mergeGeometries(list, false)!, 1e-7);
    const mesh = new THREE.Mesh(merged, mat);
    mesh.name = mat.name || `part_${i}`;
    if (!mat.name) mat.name = mesh.name;
    i++;
    root.add(mesh);
  }
  const ab = (await new GLTFExporter().parseAsync(root, { binary: true, onlyVisible: true })) as ArrayBuffer;
  const bytes = new Uint8Array(ab);
  let bin = '';
  for (let k = 0; k < bytes.length; k += 0x8000) bin += String.fromCharCode(...bytes.subarray(k, k + 0x8000));
  return { b64: btoa(bin), sourceMeshes, meshes: root.children.length };
}

/** 讀回 glb：統計網格、材質與貼圖，並放進場景供 frame({ glb: true }) 算圖比對。 */
async function loadGlb(b64: string) {
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let k = 0; k < bin.length; k++) bytes[k] = bin.charCodeAt(k);
  const gltf = await new GLTFLoader().parseAsync(bytes.buffer, '');
  const meshes: THREE.Mesh[] = [];
  const mats = new Set<THREE.Material>();
  const texs = new Set<THREE.Texture>();
  gltf.scene.traverse((o) => {
    const m = o as THREE.Mesh;
    if (!m.isMesh) return;
    meshes.push(m);
    for (const mat of Array.isArray(m.material) ? m.material : [m.material]) {
      mats.add(mat);
      for (const v of Object.values(mat)) if ((v as THREE.Texture)?.isTexture) texs.add(v as THREE.Texture);
    }
  });
  const box = new THREE.Box3().setFromObject(gltf.scene);
  if (glbView) turn.remove(glbView);
  glbView = new THREE.Group();
  glbView.add(gltf.scene);
  glbView.scale.setScalar(1000);
  glbView.position.y = PCB_SIZE.t / 2;
  glbView.visible = false;
  turn.add(glbView);
  const tri = meshes.reduce((n, m) => n + (m.geometry.index ? m.geometry.index.count : m.geometry.getAttribute('position').count) / 3, 0);
  return {
    meshes: meshes.length,
    materials: mats.size,
    textures: texs.size,
    textureSizes: [...texs].map((t) => { const im = t.image as { width: number; height: number }; return `${t.name || ''}${im.width}×${im.height}`; }),
    triangles: Math.round(tri),
    sizeM: box.getSize(new THREE.Vector3()).toArray().map((n) => +n.toFixed(4)),
    centerM: box.getCenter(new THREE.Vector3()).toArray().map((n) => +n.toFixed(4)),
    meshNames: meshes.map((m) => m.name),
  };
}

/** 正上方正交俯視：每公釐固定像素，回傳各功能區與元件在圖上的外框。 */
function top(o: { pxPerMm: number; marginMm: [number, number, number, number]; esp32: boolean; shadow?: boolean }) {
  const [mt, mr, mb, ml] = o.marginMm;
  const left = -PCB_SIZE.w / 2 - ml, right = PCB_SIZE.w / 2 + mr;
  const far = -PCB_SIZE.d / 2 - mt, near = PCB_SIZE.d / 2 + mb;
  const width = Math.round((right - left) * o.pxPerMm);
  const height = Math.round((near - far) * o.pxPerMm);
  ortho.left = left; ortho.right = right; ortho.top = -far; ortho.bottom = -near;
  ortho.near = 1; ortho.far = 500;
  ortho.position.set(0, 300, 0);
  ortho.up.set(0, 0, -1);
  ortho.lookAt(0, 0, 0);
  ortho.updateProjectionMatrix();
  ortho.updateMatrixWorld();
  placeLights(ortho, true);
  setPcbEsp32(pcb, o.esp32);
  turn.rotation.y = 0;
  shadowPlane.visible = o.shadow ?? false;
  discShadow.visible = false;
  turn.updateMatrixWorld(true);
  renderer.setSize(width, height, false);
  renderer.render(scene, ortho);
  const toPx = (b: THREE.Box3) => {
    const xs = [b.min.x, b.max.x].map((x) => (x - left) * o.pxPerMm);
    const ys = [b.min.z, b.max.z].map((z) => (z - far) * o.pxPerMm);
    const r = (n: number) => Math.round(n * 10) / 10;
    return { x: r(xs[0]), y: r(ys[0]), w: r(xs[1] - xs[0]), h: r(ys[1] - ys[0]) };
  };
  const regions: Record<string, unknown> = {};
  for (const [key, r] of Object.entries(PCB_REGIONS) as [PcbRegion, { label: string; refs: string[] }][]) {
    regions[key] = { label: r.label, refs: r.refs, ...toPx(pcbBox(pcb, key)) };
  }
  const components: Record<string, number[]> = {};
  for (const ref of pcbData(pcb).parts.keys()) {
    const p = toPx(pcbBox(pcb, ref));
    components[ref] = [p.x, p.y, p.w, p.h];
  }
  return { url: canvas.toDataURL('image/png'), width, height, regions, components };
}

window.__pcb = {
  ready: pcbData(pcb).ready,
  frame,
  top,
  exportGlb,
  loadGlb,
};
