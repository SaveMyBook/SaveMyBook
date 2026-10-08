import '@fontsource/noto-sans-tc/300.css';
import '@fontsource/noto-sans-tc/400.css';
import '@fontsource/noto-sans-tc/500.css';
import '@fontsource/noto-sans-tc/700.css';
import '@fontsource/noto-sans-tc/900.css';
import '@fontsource/ibm-plex-mono/500.css';
import './style.css';
import { Stage, W, H } from './stage';
import * as THREE from 'three';
import { World } from './world';
import { Cabinet } from './three/cabinet';
import TL from './timeline.json';
import { CUES, cueBase } from './lib/cues';
import { Corner } from './scenes/brand';
import './tour/tour.css';
import './tour/type.css';
import './tour/promo.css';
import { sList } from './tour/s_list';
import { sOpen } from './tour/s_open';
import { sOverview } from './tour/s_overview';
import { sFind } from './tour/s_find';
import { sPay } from './tour/s_pay';
import { sCabinet } from './tour/s_cabinet';
import { sAfter } from './tour/s_after';
import { sAccount } from './tour/s_account';
import { sAdmin } from './tour/s_admin';
import { sTech } from './tour/s_tech';
import { sEnd } from './tour/s_end';

const params = new URLSearchParams(location.search);
const RENDER = params.has('render');
if (params.get('theme') === 'dark') document.body.classList.add('dark');
if (params.get('tc')) document.body.classList.add(`tc-${params.get('tc')}`);
/** 動態模糊（輸出成品用）：快門 90 度（每格前 1/240 秒），mb 為取樣數上限；180 度時快速移動的介面會糊到看不清楚。 */
const BLUR = Number(params.get('mb') || 0);
const SHUTTER = 1 / 240;
/** 相鄰取樣間物件最多移動的裝置像素；取樣太疏時快速移動的物件會出現一層層的殘影。 */
const BLUR_STEP = 1.2;
const PR = Number(params.get('pr') || (RENDER ? 1 : Math.min(2, devicePixelRatio || 1)));

const frame = document.getElementById('frame')!;
const ui = document.getElementById('ui')!;
const fx = document.getElementById('fx')!;
const stage = new Stage(document.getElementById('gl') as HTMLCanvasElement, PR);
const world = new World(stage, []);

type Scene = (t: number) => void;
type Factory = (ui: HTMLElement, fx: HTMLElement) => Scene;
/** 尚未製作的段落：留白。 */
const todo = (_id: string): Factory => () => () => {};
const FACTORY: Record<string, Factory> = {
  open: (u, f) => sOpen(world, u, f),
  overview: (u, f) => sOverview(world, u, f),
  list: (u, f) => sList(world, u, f),
  find: (u, f) => sFind(world, u, f),
  pay: (u, f) => sPay(world, u, f),
  cabinet: (u, f) => sCabinet(world, u, f),
  after: (u, f) => sAfter(world, u, f),
  account: (u, f) => sAccount(world, u, f),
  admin: (u, f) => sAdmin(world, u, f),
  tech: (u, f) => sTech(world, u, f),
  end: (u, f) => sEnd(world, u, f),
};
// 每段各自一層：段落外整層隱藏，殘留的元素不會出現在其他段落
const LAYERS: { start: number; end: number; ui: HTMLElement; fx: HTMLElement; scene: Scene }[] = [];
for (const s of TL.sections) {
  cueBase(s.start);
  const u = document.createElement('div');
  const f = document.createElement('div');
  u.className = f.className = 'layer';
  ui.append(u);
  fx.append(f);
  LAYERS.push({ start: s.start, end: s.end, ui: u, fx: f, scene: (FACTORY[s.id] ?? todo(s.id))(u, f) });
}
cueBase(0);
const hudLayer = document.createElement('div');
hudLayer.className = 'layer';
ui.append(hudLayer);
const corner = new Corner(hudLayer);
/** 左上角 logo：片頭品牌段結束時由 open 場景交接（BRAND_LAND），片尾收起。 */
export const BRAND_LAND = TL.sections.find((s) => s.id === 'overview')!.start;
const END = TL.sections.find((s) => s.id === 'end')!.start;
export const DURATION = TL.duration;

function update(t: number) {
  world.reset();
  for (const L of LAYERS) {
    const on = t >= L.start - 1 && t <= L.end + 1;
    L.ui.style.display = on ? '' : 'none';
    L.fx.style.display = on ? '' : 'none';
    if (on) L.scene(t - L.start);
  }
  corner.at(t, BRAND_LAND, END - 0.15);
  world.apply(t);
  for (const fn of world.frame.after) fn();
}

function draw(t: number) {
  update(t);
  stage.render();
}

declare global {
  interface Window { __ready: boolean; __seek: (t: number) => Promise<void>; __duration: number }
}
window.__duration = DURATION;
(window as unknown as { __cues: unknown }).__cues = { cues: [...CUES].sort((a, b) => a.t - b.t), sections: TL.sections, duration: TL.duration };
// 3D 物件外框角點在畫面上的位置，用來量測快門時間內的移動距離
const CORNERS = [[-1, -1], [1, -1], [1, 1], [-1, 1], [0, 1], [0, -1]] as const;
const CAB_CORNERS: THREE.Vector3[] = [];
for (const x of [-1, 1]) for (const y of [-1, 1]) for (const z of [-1, 1]) CAB_CORNERS.push(new THREE.Vector3(x * Cabinet.WIDTH / 2, y * Cabinet.HEIGHT / 2, z * Cabinet.DEPTH / 2));
const box3 = new THREE.Box3();
function probe() {
  const out = new Map<string, THREE.Vector2[]>();
  world.phones.forEach((_, i) => {
    if (world.frame.phones[i]) out.set(`p${i}`, CORNERS.map(([u, v]) => world.edge(i, u, v)));
  });
  if (world.frame.cabinet) {
    const g = world.cabinet.group;
    g.updateMatrixWorld(true);
    out.set('cab', CAB_CORNERS.map((c) => stage.toScreen(g.localToWorld(c.clone()))));
  }
  if (world.frame.parcel) {
    box3.setFromObject(world.box);
    const pts: THREE.Vector2[] = [];
    for (const x of [box3.min.x, box3.max.x]) for (const y of [box3.min.y, box3.max.y]) for (const z of [box3.min.z, box3.max.z]) pts.push(stage.toScreen(new THREE.Vector3(x, y, z)));
    out.set('box', pts);
  }
  return out;
}
function motion(a: Map<string, THREE.Vector2[]>, b: Map<string, THREE.Vector2[]>) {
  let d = 0;
  for (const [k, pa] of a) {
    const pb = b.get(k);
    if (pb) pa.forEach((p, i) => { d = Math.max(d, p.distanceTo(pb[i])); });
  }
  return d * PR;
}

// 只在物件移動夠快時才做動態模糊，取樣數依移動距離決定；靜止與緩慢移動的畫面維持清晰
/** 先算一次這一格用到哪些 App 畫面，載入後再算圖（材質按需載入）。 */
async function prepare(t: number) {
  update(t);
  await world.ensure(world.used, t);
  if (world.takeMissing().length) update(t);
}

// 最後一個取樣落在 t，畫面上的文字與標註即為該格的位置
window.__seek = async (t: number) => {
  await prepare(t);
  if (BLUR < 2) return stage.render();
  update(t - SHUTTER);
  const a = probe();
  update(t);
  const n = Math.min(BLUR, Math.ceil(motion(a, probe()) / BLUR_STEP));
  if (n < 3) return stage.render();
  stage.renderBlurred(n, (i) => update(t - SHUTTER * (1 - i / (n - 1))));
};
// 檢查用：每支手機在畫面上的中心、對角線長度與旋轉角，供 tools/motion.mjs 量測速度與加速度是否連續
(window as unknown as { __motion: (t: number) => unknown }).__motion = (t: number) => {
  update(t);
  const out: Record<string, number[]> = {};
  for (const [k, pts] of probe()) {
    const cx = pts.reduce((a, p) => a + p.x, 0) / pts.length, cy = pts.reduce((a, p) => a + p.y, 0) / pts.length;
    out[k] = [cx, cy, Math.hypot(pts[2].x - pts[0].x, pts[2].y - pts[0].y), Math.atan2(pts[1].y - pts[0].y, pts[1].x - pts[0].x)];
  }
  world.phones.forEach((p, i) => { if (world.frame.phones[i]) out[`r${i}`] = [p.group.rotation.x, p.group.rotation.y, p.group.rotation.z, p.group.position.z]; });
  return out;
};
// 檢查用：回傳畫面上每支手機機身的世界矩陣，供 tools/collide.mjs 判斷是否穿模
(window as unknown as { __phones: (t: number) => number[][] }).__phones = (t: number) => {
  draw(t);
  return world.phones.filter((p) => p.group.visible).map((p) => {
    p.body.updateMatrixWorld(true);
    return [...p.body.matrixWorld.elements];
  });
};

// 輸出 4K 時視窗為 3840×2160，整個畫面放大 2 倍（文字會以實際解析度重新繪製）
if (RENDER && params.get('scale')) frame.style.transform = `scale(${params.get('scale')})`;

// 檢查用：回傳目前畫面上互相重疊的文字區塊，以及蓋在手機上的文字區塊（tools/overlap.mjs 使用）
const TEXT_SEL = '.cnav, .chead, .fitem, .lens, .callout, .rise, .sub, .cap, .chip, .gate, .hud, .ptag, .lcard, .stepbar, .xlabel, .arch-node, .arch-server, .stat2, .fee-row, .fee-cap, .meta, .tile, .ffwd, .h-display, .dcard, .dmethods, .dcmp, .cbadge, .corner__name';
(window as unknown as { __overlaps: (t: number) => unknown }).__overlaps = (t: number) => {
  draw(t);
  const scale = frame.getBoundingClientRect().width / W;
  const els = [...document.querySelectorAll<HTMLElement>(TEXT_SEL)].filter((e) => {
    if (e.closest('[style*="display: none"]')) return false;
    let n: HTMLElement | null = e;
    while (n && n !== frame) {
      const cs = getComputedStyle(n);
      if (cs.visibility === 'hidden' || cs.display === 'none' || Number(cs.opacity) < 0.12) return false;
      n = n.parentElement;
    }
    return true;
  }).filter((e) => !e.parentElement?.closest(TEXT_SEL));
  const box = (e: HTMLElement) => { const r = e.getBoundingClientRect(); return { x: r.left / scale, y: r.top / scale, w: r.width / scale, h: r.height / scale, name: e.className.split(' ')[0] + ':' + (e.textContent || '').trim().slice(0, 12) }; };
  const boxes = els.map(box).filter((b) => b.w > 2 && b.h > 2);
  const hit = (a: typeof boxes[0], b: typeof boxes[0], pad = 4) => a.x < b.x + b.w - pad && b.x < a.x + a.w - pad && a.y < b.y + b.h - pad && b.y < a.y + a.h - pad;
  const pairs: string[] = [];
  for (let i = 0; i < boxes.length; i++) for (let j = i + 1; j < boxes.length; j++) if (hit(boxes[i], boxes[j])) pairs.push(`${boxes[i].name} × ${boxes[j].name}`);
  const offscreen = boxes.filter((b) => b.x < -2 || b.y < -2 || b.x + b.w > W + 2 || b.y + b.h > H + 2).map((b) => `出界 ${b.name}`);
  const phones: string[] = [];
  world.phones.forEach((p, i) => {
    if (!world.frame.phones[i]) return;
    const c = [[-1, -1], [1, -1], [1, 1], [-1, 1]].map(([u, v]) => world.edge(i, u, v));
    const pb = { x: Math.min(...c.map((q) => q.x)), y: Math.min(...c.map((q) => q.y)), w: 0, h: 0, name: `手機${i}` };
    pb.w = Math.max(...c.map((q) => q.x)) - pb.x; pb.h = Math.max(...c.map((q) => q.y)) - pb.y;
    for (const b of boxes) if (!b.name.startsWith('ptag') && hit(b, pb, 10)) phones.push(`${b.name} 壓在 手機${i}`);
  });
  // 浮出元件互相重疊（同一支或不同手機的浮出卡片，在畫面上的外框相交）
  const cards: typeof boxes = [];
  world.phones.forEach((p, i) => {
    if (!world.frame.phones[i]) return;
    for (const [id, card] of p.pops) {
      if (!card.shown) continue;
      const c = card.corners().map((v) => stage.toScreen(v));
      const b = { x: Math.min(...c.map((q) => q.x)), y: Math.min(...c.map((q) => q.y)), w: 0, h: 0, name: `浮出${i}:${id}` };
      b.w = Math.max(...c.map((q) => q.x)) - b.x; b.h = Math.max(...c.map((q) => q.y)) - b.y;
      cards.push(b);
    }
  });
  const popHits: string[] = [];
  for (let i = 0; i < cards.length; i++) for (let j = i + 1; j < cards.length; j++) if (hit(cards[i], cards[j], 2)) popHits.push(`${cards[i].name} × ${cards[j].name}`);
  // 浮出元件與文字重疊
  for (const c of cards) for (const b of boxes) if (hit(b, c, 4)) popHits.push(`${b.name} 壓在 ${c.name}`);
  // 字幕區（y > 930）只留給字幕：文字與浮出元件不得進入
  const subZone = [...boxes, ...cards].filter((b) => b.y + b.h > 930 && b.y < 1080).map((b) => `進入字幕區 ${b.name}`);
  return [...pairs, ...offscreen, ...phones, ...popHits, ...subZone];
};

world.load().then(async () => {
  await window.__seek(Number(params.get('t') || 0));
  window.__ready = true;
  if (!RENDER) preview();
});

function preview() {
  const fit = () => {
    const s = Math.min(innerWidth / W, (innerHeight - 48) / H);
    frame.style.transform = `scale(${s})`;
  };
  fit();
  addEventListener('resize', fit);
  const bar = document.getElementById('bar')!;
  const seek = document.getElementById('seek') as HTMLInputElement;
  const out = document.getElementById('time')!;
  const btn = document.getElementById('play')!;
  bar.hidden = false;
  seek.max = String(DURATION);
  let t = Number(params.get('t') || 0);
  let playing = false;
  let last = 0;
  // 預覽時先用已載入的材質畫，缺的畫面載入後再補畫一次
  const show = () => {
    seek.value = String(t); out.textContent = t.toFixed(2); draw(t);
    const at = t;
    world.ensure(world.used, at).then(() => { if (world.takeMissing().length && at === t) draw(at); });
  };
  seek.addEventListener('input', () => { t = Number(seek.value); show(); });
  const toggle = () => { playing = !playing; btn.textContent = playing ? '暫停' : '播放'; last = performance.now(); };
  btn.addEventListener('click', toggle);
  addEventListener('keydown', (e) => { if (e.code === 'Space') { e.preventDefault(); toggle(); } });
  const loop = (now: number) => {
    if (playing) {
      t += (now - last) / 1000;
      if (t > DURATION) t = 0;
      show();
    }
    last = now;
    requestAnimationFrame(loop);
  };
  requestAnimationFrame(loop);
  show();
}
