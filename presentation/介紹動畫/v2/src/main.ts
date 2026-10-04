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
import { intro } from './scenes/intro';
import { list } from './scenes/list';
import { find } from './scenes/find';
import { deal } from './scenes/deal';
import { pay } from './scenes/pay';
import { deposit } from './scenes/deposit';
import { transit } from './scenes/transit';
import { pickup } from './scenes/pickup';
import { after } from './scenes/after';
import { system } from './scenes/system';
import { fee } from './scenes/fee';
import { end } from './scenes/end';
import { escrow } from './scenes/escrow';
import { HEADLINES } from './scenes/kit';
import { Corner } from './scenes/brand';
import { BRAND_LAND } from './scenes/intro';

const params = new URLSearchParams(location.search);
const RENDER = params.has('render');
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
const SCREENS = [
  's_sell_isbn', 's_sell_fill', 's_sell_info', 's_sell_photos', 's_sell_ai_sheet_220', 's_sell_ready', 'b_home', 'b_chat_list', 'b_advisor', 'b_book_detail',
  'b_chat_1', 'b_chat_2', 'b_chat_3', 'b_chat_4', 'b_chat_warn', 'b_pay_0', 'b_pay_1', 'b_pay_2', 'b_pay_3', 'b_pay_4', 'b_pay_5', 'b_pay_6', 'b_pay_done',
  's_cab_scan', 's_cab_match_empty', 's_cab_match', 's_cab_open', 's_cab_done', 'b_guide_long', 'a_cabinet_pre', 'a_cabinet_edit',
  'b_pickup_scan', 'b_cab_match_empty', 'b_cab_match', 'b_pickup_open', 'b_pickup_done', 's_wallet', 'b_support', 'a_dispute_ai', 'b_ai_consent',
];
const world = new World(stage, SCREENS);

type Scene = (t: number) => void;
type Factory = (ui: HTMLElement, fx: HTMLElement) => Scene;
const FACTORY: Record<string, Factory> = {
  intro: (u) => intro(world, u),
  list: (u) => list(world, u),
  find: (u) => find(world, u),
  deal: (u) => deal(world, u),
  pay: (u) => pay(world, u),
  deposit: (u, f) => deposit(world, u, f),
  transit: (u) => transit(world, u),
  pickup: (u) => pickup(world, u),
  after: (u) => after(world, u),
  system: (u) => system(world, u),
  fee: (u) => fee(world, u),
  end: (u) => end(world, u),
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
  LAYERS.push({ start: s.start, end: s.end, ui: u, fx: f, scene: FACTORY[s.id](u, f) });
}
cueBase(0);
const hudLayer = document.createElement('div');
hudLayer.className = 'layer';
ui.append(hudLayer);
const hud = escrow(world, hudLayer);
const corner = new Corner(hudLayer);
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
  hud(t);
  // 品牌段結束時片頭的 logo 與名稱飛到左上角（intro.ts），之後固定到片尾
  corner.at(t, BRAND_LAND, END - 0.15);
  // 任一支手機放大特寫時，上方標題淡出；並排時的 1.32 倍不算，推近一開始就淡出，手機不會長到標題上
  const zoom = Math.max(0, ...world.frame.phones.map((p) => (p ? ((p.pose.s ?? 1) - 1.34) / 0.16 : 0)));
  const hv = (1 - Math.min(1, zoom)).toFixed(3);
  for (const h of HEADLINES) if (h.style.opacity !== hv) h.style.opacity = hv;
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
const TEXT_SEL = '.rise, .sub, .cap, .chip, .gate, .hud, .ptag, .lcard, .stepbar, .xlabel, .arch-node, .arch-server, .stat2, .fee-row, .fee-cap, .meta, .tile, .ffwd, .h-display, .dcard, .dmethods, .dcmp, .cbadge, .corner__name';
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
  return [...pairs, ...offscreen, ...phones];
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
