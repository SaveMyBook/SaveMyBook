import '@fontsource/noto-sans-tc/300.css';
import '@fontsource/noto-sans-tc/400.css';
import '@fontsource/noto-sans-tc/500.css';
import '@fontsource/noto-sans-tc/700.css';
import '@fontsource/noto-sans-tc/900.css';
import '@fontsource/ibm-plex-mono/500.css';
import './style.css';
import { Stage, W, H } from './stage';
import * as THREE from 'three';
import { World, CUTS } from './world';
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
import { SubtitleBand, loadCues } from './v3/subtitles';
import { V3, TITLE_BOTTOM } from './v3/spec';
import { Backdrop } from './v3/backdrop';
import { sAfter } from './tour/s_after';
import { sAccount } from './tour/s_account';
import { sAdmin } from './tour/s_admin';
import { sTech } from './tour/s_tech';
import { sEnd } from './tour/s_end';

const params = new URLSearchParams(location.search);
const RENDER = params.has('render');
if (params.get('theme') === 'dark') document.body.classList.add('dark');
if (params.get('tc')) document.body.classList.add(`tc-${params.get('tc')}`);
/** 動態模糊（輸出成品用）：快門預設 90 度（每格前 1/240 秒），mb 為取樣數上限；sh 指定快門角度（新版樣片用 180 度，只有快速移動才會取樣）。 */
const BLUR = Number(params.get('mb') || 0);
const SHUTTER = Number(params.get('sh') || 90) / 360 / 60;
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
/**
 * v3（網址加 ?v3）：各段為 src/tour/s_<段落>_v3.ts（export default (world, ui, fx) => (t) => void）。
 * 以動態載入個別處理：某一段的檔案有語法錯誤時只有那一段留白，其他段照常顯示（多個代理同時編輯時互不影響）。
 */
const V3_MODE = params.has('v3');
type V3Module = { default: (world: World, ui: HTMLElement, fx: HTMLElement) => Scene };
const V3_MODS = import.meta.glob<V3Module>('./tour/s_*_v3.ts');
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
type Layer = { start: number; end: number; ui: HTMLElement; fx: HTMLElement; scene: Scene };
const LAYERS: Layer[] = [];
let corner: Corner;
/** v3：字幕帶（網址加 nosub 時不顯示，輸出成品時另外燒入字幕）與全片共用的背景。 */
let band: SubtitleBand | null = null;
let backdrop: Backdrop | null = null;

async function buildLayers() {
  const v3: Record<string, Factory> = {};
  if (V3_MODE) {
    await Promise.all(Object.entries(V3_MODS).map(async ([path, load]) => {
      const id = path.match(/s_(\w+)_v3\.ts$/)?.[1];
      if (!id) return;
      try {
        const m = await load();
        v3[id] = (u, f) => m.default(world, u, f);
      } catch (e) {
        console.error(`v3 段落載入失敗：${id}`, e);
      }
    }));
    const bgLayer = document.createElement('div');
    bgLayer.className = 'layer';
    fx.prepend(bgLayer);
    backdrop = new Backdrop(bgLayer);
  }
  for (const s of TL.sections) {
    cueBase(s.start);
    const u = document.createElement('div');
    const f = document.createElement('div');
    u.className = f.className = 'layer';
    ui.append(u);
    fx.append(f);
    const make = V3_MODE ? v3[s.id] ?? todo(s.id) : FACTORY[s.id] ?? todo(s.id);
    LAYERS.push({ start: s.start, end: s.end, ui: u, fx: f, scene: make(u, f) });
  }
  cueBase(0);
  const hudLayer = document.createElement('div');
  hudLayer.className = 'layer';
  ui.append(hudLayer);
  corner = new Corner(hudLayer);
  if (V3_MODE && !params.has('nosub')) band = new SubtitleBand(hudLayer);
  if (V3_MODE) world.later.push(() => loadCues());
}
/** 左上角 logo：片頭品牌段結束時由 open 場景交接（BRAND_LAND），片尾收起。 */
export const BRAND_LAND = TL.sections.find((s) => s.id === 'overview')!.start;
const END = TL.sections.find((s) => s.id === 'end')!.start;
export const DURATION = TL.duration;

function update(t: number) {
  world.reset();
  let active: Layer | null = null;
  for (const L of LAYERS) {
    const on = t >= L.start - 1 && t <= L.end + 1;
    L.ui.style.display = on ? '' : 'none';
    L.fx.style.display = on ? '' : 'none';
    if (V3_MODE && t >= L.start && t < L.end) active = L;
    else if (on) L.scene(t - L.start);
  }
  if (active) {
    // v3：相鄰段落在交界前後各 0.05 秒仍會寫入 3D 物件，交界那一格會把上一段的書櫃畫進下一段的鏡頭；
    // 3D 物件與鏡頭只由目前的段落寫入（其他段落只更新自己的標題等畫面元件）
    world.reset();
    active.scene(t - active.start);
  }
  backdrop?.draw(true, t);
  // 片尾標誌在段落一開始就淡入：左上角的標誌提早在交界前收完，畫面上不會同時出現兩份
  corner?.at(t, BRAND_LAND, V3_MODE ? END - 0.5 : END - 0.15);
  band?.at(t);
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
// 各段在 buildLayers 時才登記音效，所以取用時才整理
Object.defineProperty(window, '__cues', { get: () => ({ cues: [...CUES].sort((a, b) => a.t - b.t), sections: TL.sections, duration: TL.duration }) });
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
/** 檢查用：這一格每支手機的畫面狀態（換畫面時的 a、b、k、mode），找出淡化交疊的時刻。 */
(window as unknown as { __screens: (t: number) => unknown }).__screens = (t: number) => {
  update(t);
  return world.frame.phones.map((p, i) => (p ? { i, ...p.scr } : null)).filter(Boolean);
};
/** 穿模檢查用：這一格所有 3D 物件的方向盒（世界矩陣＋本體半尺寸），含手機、書櫃本體、浮出的書櫃螢幕。 */
(window as unknown as { __solids: (t: number) => unknown }).__solids = async (t: number) => {
  await window.__seek(t);
  const out: { name: string; m: number[]; half: number[] }[] = [];
  world.phones.forEach((p, i) => {
    if (!p.group.visible) return;
    p.body.updateMatrixWorld(true);
    out.push({ name: `手機${i}`, m: [...p.body.matrixWorld.elements], half: [7.15 / 2, 14.96 / 2, 0.83 / 2 + 0.25] });
  });
  if (world.cabinet.group.visible) {
    const g = world.cabinet.group;
    g.updateMatrixWorld(true);
    out.push({ name: '書櫃', m: [...g.matrixWorld.elements], half: [Cabinet.WIDTH / 2, Cabinet.HEIGHT / 2, Cabinet.DEPTH / 2] });
    if (world.cabinet.popShown) out.push({ name: '浮出螢幕', m: world.cabinet.popMatrix(), half: [Cabinet.SCREEN.bezelW / 2, Cabinet.SCREEN.bezelH / 2, 0.06] });
  }
  return out;
};

// 輸出 4K 時視窗為 3840×2160，整個畫面放大 2 倍（文字會以實際解析度重新繪製）
if (RENDER && params.get('scale')) frame.style.transform = `scale(${params.get('scale')})`;

// 檢查用：回傳目前畫面上互相重疊的文字區塊，以及蓋在手機上的文字區塊（tools/overlap.mjs 使用）
const TEXT_SEL = '.cnav, .chead, .fitem, .lens, .callout, .rise, .sub, .cap, .chip, .gate, .hud, .ptag, .lcard, .stepbar, .xlabel, .arch-node, .arch-server, .stat2, .fee-row, .fee-cap, .meta, .tile, .ffwd, .h-display, .dcard, .dmethods, .dcmp, .cbadge, .corner__name, .promo__title, .promo__sub, .tech__stat, .tech__unit, .cab-digit, .open-num, .open-sub, .end__brand, .cword, .v3-cap';
const INK = document.createElement('canvas').getContext('2d')!;
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
  // 文字外框不含字形的上伸、下伸部分（例如 150px 數字的逗號會往下伸出約 0.25em）：
  // 以 canvas 量出這段文字實際的墨跡高度，超出字框的部分加進外框，才抓得到逗號壓到下一行這類問題
  const ink = (e: HTMLElement) => {
    const cs = getComputedStyle(e);
    const size = parseFloat(cs.fontSize) || 16;
    INK.font = `${cs.fontWeight} ${cs.fontSize} ${cs.fontFamily}`;
    const m = INK.measureText((e.textContent || '').trim() || 'x');
    // 行高 1 時字框約為基線上 0.88em、下 0.12em（Noto Sans TC）
    return { up: Math.max(0, m.actualBoundingBoxAscent - 0.88 * size), down: Math.max(0, m.actualBoundingBoxDescent - 0.12 * size) };
  };
  const box = (e: HTMLElement) => {
    const r = e.getBoundingClientRect();
    const k = ink(e);
    return { x: r.left / scale, y: r.top / scale - k.up, w: r.width / scale, h: r.height / scale + k.up + k.down, name: e.className.split(' ')[0] + ':' + (e.textContent || '').trim().slice(0, 12) };
  };
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
  // 浮出的去背元件必須和手機目前的畫面一致：畫面已換掉（推入、換狀態）但元件還浮在上面，會蓋在不相干的內容上
  // 同一畫面的逐字、捲動、逐格、倒數秒數版本（_t03、_s05、_f2、_29）視為同一張；對話框浮起後原位顯示的 <畫面>_under 也算同一張
  const family = (n: string) => n.replace(/_under$/, '').replace(/_(t|s|f)?\d+$/, '');
  const stale: string[] = [];
  world.frame.phones.forEach((st, i) => {
    if (!st) return;
    const shown = [st.scr.a, st.scr.b].filter(Boolean).map((n) => family(n as string));
    for (const pp of st.pops ?? []) {
      if (!pp.cut || pp.k <= 0.02) continue;
      const src = CUTS[pp.cut]?.screen;
      if (src && !shown.includes(family(src))) stale.push(`浮出元件與畫面不符 手機${i}:${pp.cut}（畫面 ${shown.join('/')}）`);
    }
  });
  // 字幕區（y > 930）只留給字幕：文字與浮出元件不得進入
  const subZone = [...boxes, ...cards].filter((b) => !b.name.startsWith('v3-cap') && b.y + b.h > 930 && b.y < 1080).map((b) => `進入字幕區 ${b.name}`);
  return [...pairs, ...offscreen, ...phones, ...popHits, ...subZone, ...stale];
};

/**
 * v3 的版面檢查（比照 NTUB 宣傳片的 REEL_CHECK，數值見 src/v3/spec.ts）：
 * - 標題（.v3-title、.v3-sub）與手機、書櫃、浮出元件至少相距 40px。
 * - 手機、書櫃、浮出元件不得進入字幕帶（y ≥ 976）。
 * - 浮出元件完全浮出時距畫面邊緣 56px、在標題下方 40px 以下。
 * 有角點在鏡頭後方的物件（甩鏡途中）投影會發散，視為不在畫面內。
 */
(window as unknown as { __reelCheck: (t: number) => unknown }).__reelCheck = (t: number) => {
  draw(t);
  const scale = frame.getBoundingClientRect().width / W;
  const shown = (e: HTMLElement) => {
    let n: HTMLElement | null = e;
    while (n && n !== frame) {
      const cs = getComputedStyle(n);
      if (cs.visibility === 'hidden' || cs.display === 'none' || Number(cs.opacity) < 0.9) return false;
      n = n.parentElement;
    }
    return true;
  };
  const titles = [...document.querySelectorAll<HTMLElement>('.v3-title, .v3-sub')].filter(shown).map((e) => {
    const r = e.getBoundingClientRect();
    return { name: (e.textContent || '').trim().slice(0, 10), x0: r.left / scale, y0: r.top / scale, x1: r.right / scale, y1: r.bottom / scale };
  });
  const bb = (pts: THREE.Vector2[], name: string) => ({ name, x0: Math.min(...pts.map((p) => p.x)), y0: Math.min(...pts.map((p) => p.y)), x1: Math.max(...pts.map((p) => p.x)), y1: Math.max(...pts.map((p) => p.y)) });
  // 物件外框只算畫面內看得到的部分：沿方盒十二條邊取樣，只留鏡頭前方、左右在畫面內的點（物件跨出畫面左右緣、甩鏡途中時不會誤判）
  const visibleBox = (obj: THREE.Object3D, half: [number, number, number], zs: [number, number], name: string) => {
    obj.updateMatrixWorld(true);
    const pts: THREE.Vector2[] = [];
    const c = (sx: number, sy: number, sz: number) => new THREE.Vector3(sx * half[0], sy * half[1], sz < 0 ? zs[0] : zs[1]);
    const corners = [[-1, -1, -1], [1, -1, -1], [1, 1, -1], [-1, 1, -1], [-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]].map(([x, y, z]) => c(x, y, z));
    const edges = [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]];
    for (const [i, j] of edges) for (let k = 0; k <= 10; k++) {
      const v = obj.localToWorld(corners[i].clone().lerp(corners[j], k / 10));
      const n = v.clone().project(stage.camera);
      if (n.z >= 1 || n.z <= -1) continue;
      const q = stage.toScreen(v);
      if (q.x >= 0 && q.x <= W) pts.push(q);
    }
    return pts.length ? bb(pts, name) : null;
  };
  const objs: ReturnType<typeof bb>[] = [];
  world.phones.forEach((p, i) => {
    if (!world.frame.phones[i]) return;
    const b = visibleBox(p.body, [7.15 / 2, 14.96 / 2, 0], [-0.65, 0.45], `手機${i}`);
    if (b) objs.push(b);
  });
  const pops: ReturnType<typeof bb>[] = [];
  if (world.frame.cabinet) {
    const g = world.cabinet.group;
    const b = visibleBox(g, [Cabinet.WIDTH / 2, Cabinet.HEIGHT / 2, 0], [-Cabinet.DEPTH / 2, Cabinet.DEPTH / 2], '書櫃');
    if (b) objs.push(b);
    if (world.cabinet.popShown) {
      const b = bb(world.cabinet.popCorners().map((v) => stage.toScreen(v)), '浮出螢幕');
      objs.push(b);
      if (world.cabinet.popK > 0.95) pops.push(b);
    }
  }
  world.phones.forEach((p, i) => {
    if (!world.frame.phones[i]) return;
    for (const [id, card] of p.pops) {
      if (!card.shown) continue;
      const b = bb(card.corners().map((v) => stage.toScreen(v)), `浮出${i}:${id}`);
      objs.push(b);
      if (card.k > 0.95) pops.push(b);
    }
  });
  const out: string[] = [];
  for (const tb of titles) for (const o of objs) {
    const d = Math.hypot(Math.max(tb.x0 - o.x1, o.x0 - tb.x1, 0), Math.max(tb.y0 - o.y1, o.y0 - tb.y1, 0));
    if (d < V3.safe.titleGap) out.push(`標題「${tb.name}」距 ${o.name} ${d.toFixed(0)}px`);
  }
  for (const o of objs) if (o.y1 > V3.subtitle.bandTop + 1 && o.y0 < 1080) out.push(`${o.name} 進入字幕帶 y ${o.y1.toFixed(0)}`);
  const top = titles.length ? Math.max(...titles.map((b) => b.y1)) + V3.safe.titleGap : V3.safe.margin;
  for (const p of pops) {
    const m = V3.safe.margin;
    if (p.x0 < m - 2 || p.x1 > W - m + 2 || p.y0 < top - 2) out.push(`${p.name} 超出安全範圍 x ${p.x0.toFixed(0)}–${p.x1.toFixed(0)} y ${p.y0.toFixed(0)}–${p.y1.toFixed(0)}`);
  }
  return { out, objs: objs.map((o) => `${o.name} x ${o.x0.toFixed(0)}–${o.x1.toFixed(0)} y ${o.y0.toFixed(0)}–${o.y1.toFixed(0)}`), titles: titles.map((b) => `${b.name} x ${b.x0.toFixed(0)}–${b.x1.toFixed(0)} y ${b.y0.toFixed(0)}–${b.y1.toFixed(0)}`), titleBottom: TITLE_BOTTOM };
};

buildLayers().then(() => world.load()).then(async () => {
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
