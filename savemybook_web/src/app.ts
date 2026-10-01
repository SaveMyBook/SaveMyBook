import Lenis from 'lenis';
import * as THREE from 'three';
import { Stage } from './three/stage';
import { Phone, type PopRect } from './three/phone';
import { Book } from './three/book';
import { Cabinet } from './three/cabinet';
import { screenTexture, type KioskState } from './three/textures';
import { keyframes, span, beatAt, clamp, lerp, easeOut, type Frame, type Pose } from './lib/kf';
import { chapters, buildChrome, splitLines, revealOnView, magnetic, filmDialog, countUp, type Chapter } from './ui/chrome';
import { SHELF, AI_FEATURES } from './data/content';

/* ---------------- 共用 ---------------- */

const $ = <T extends Element = HTMLElement>(s: string, root: ParentNode = document) => root.querySelector<T>(s) as T;
const $$ = <T extends Element = HTMLElement>(s: string, root: ParentNode = document) => [...root.querySelectorAll<T>(s)];

const PAPER = new THREE.Color('#F3F5F7');
const SLATE = new THREE.Color('#627D8D');

function webglOK() {
  try {
    const c = document.createElement('canvas');
    return !!(c.getContext('webgl2') || c.getContext('webgl'));
  } catch { return false; }
}

function buildShelf() {
  const row = $('.shelf__row');
  row.innerHTML = SHELF.map((b) => `
    <li class="book" style="--c:${b.color};--w:${b.w}px;--h:${b.h}px;${b.text ? `--t:${b.text};` : ''}${b.band ? `--band:${b.band};` : ''}" tabindex="0">
      <div class="book__cover"><p class="book__title">${b.title}</p><p class="book__author">${b.author}</p></div>
      <p class="book__note"><b>推薦理由</b>${b.reason}</p>
    </li>`).join('');
}

function buildOrbit() {
  $('.orbit__ring').innerHTML = AI_FEATURES.map((f) => `<li><span class="ico">${f.icon}</span><b>${f.name}</b><small>${f.note}</small></li>`).join('');
}

/** 系統架構圖連線：依節點實際位置畫在 SVG 上。 */
function drawWires() {
  const arch = $('.arch');
  const svg = $<SVGSVGElement>('.arch__wires');
  const box = arch.getBoundingClientRect();
  if (!box.width) return [] as SVGPathElement[];
  const at = (n: string) => {
    const r = $(`.arch__nodes [data-n="${n}"]`).getBoundingClientRect();
    return { x: (r.left + r.width / 2 - box.left) / box.width * 1000, y: (r.top + r.height / 2 - box.top) / box.height * 560, visible: r.width > 0 };
  };
  const links: [string, string, boolean?][] = [['app', 'edge'], ['cab', 'edge'], ['edge', 'api'], ['edge', 'io'], ['api', 'db'], ['io', 'db'], ['api', 'ai', true], ['io', 'fb', true]];
  svg.innerHTML = '';
  const paths: SVGPathElement[] = [];
  for (const [a, b, dash] of links) {
    const p = at(a), q = at(b);
    if (!p.visible || !q.visible) continue;
    const mx = (p.x + q.x) / 2;
    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    path.setAttribute('d', `M${p.x},${p.y} C${mx},${p.y} ${mx},${q.y} ${q.x},${q.y}`);
    if (dash) path.setAttribute('class', 'dash');
    svg.append(path);
    paths.push(path);
  }
  return paths;
}

/* ---------------- 靜態版 ---------------- */

function stillMode(list: Chapter[], chrome: ReturnType<typeof buildChrome>) {
  const io = new IntersectionObserver((entries) => {
    for (const en of entries) if (en.isIntersecting) chrome.setCurrent(list.findIndex((c) => c.el === en.target));
  }, { rootMargin: '-45% 0px -50% 0px' });
  list.forEach((c) => io.observe(c.el));
  $$('.count').forEach((c) => countUp(c, 1));
  $$('.reveal, .reveal-lines, .fee').forEach((el) => el.classList.add('is-in'));
  $$('.beat').forEach((b) => b.classList.add('is-on'));
  requestAnimationFrame(() => drawWires());
}

/* ---------------- App 畫面與浮出卡片 ---------------- */

/** cabinet_match 畫面上兩個數字格的中心（App 邏輯座標）。 */
const DIGIT_BOXES: [number, number][] = [[162, 396], [230, 396]];

const SCREENS = ['home', 'sell_ai', 'sell_price', 'book_detail', 'sell_ai_sheet', 'ai_chat', 'chat_room', 'my_reservations', 'cabinet_scan', 'cabinet_match_empty', 'cabinet_match', 'cabinet_open', 'cabinet_done', 'pay_verify'];

/** 依序切換畫面：[名稱, 開始切入的進度]，每次切換歷時 d。 */
function chain(p: number, items: [string, number][], d = 0.05): [string | null, string | null, number] {
  let i = 0;
  while (i + 1 < items.length && p >= items[i + 1][1]) i++;
  if (i === 0) return [items[0][0], null, 0];
  return [items[i - 1][0], items[i][0], span(p, items[i][1], items[i][1] + d)];
}

/** 浮出卡片：取自 App 畫面的區塊（App 邏輯座標 393 × 852）。 */
const POPS: Record<string, { screen: string; rect: PopRect }> = {
  aiBar: { screen: 'sell_ai', rect: { x: 16, y: 131, w: 361, h: 46, r: 14 } },
  condition: { screen: 'sell_price', rect: { x: 16, y: 356, w: 361, h: 112, r: 12 } },
  price: { screen: 'sell_price', rect: { x: 16, y: 514, w: 361, h: 111, r: 12 } },
  intro: { screen: 'sell_ai_sheet', rect: { x: 17, y: 583, w: 360, h: 111, r: 12 } },
  advisorReq: { screen: 'ai_chat', rect: { x: 72, y: 131, w: 307, h: 60, r: 18 } },
  advisor: { screen: 'ai_chat', rect: { x: 52, y: 378, w: 326, h: 207, r: 14 } },
  chatReserve: { screen: 'chat_room', rect: { x: 77, y: 403, w: 304, h: 235, r: 16 } },
  chatBanner: { screen: 'chat_room', rect: { x: 6, y: 117, w: 381, h: 66, r: 12 } },
  chatWarn: { screen: 'chat_room', rect: { x: 52, y: 652, w: 334, h: 96, r: 12 } },
  resCard: { screen: 'my_reservations', rect: { x: 16, y: 176, w: 361, h: 162, r: 16 } },
};

/* ---------------- 主程式 ---------------- */

export function boot() {
  const root = document.documentElement;
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  splitLines();
  buildShelf();
  buildOrbit();
  const list = chapters();
  const motion = !reduce && webglOK();
  root.classList.add(motion ? 'motion' : 'still-mode');

  let lenis: Lenis | null = null;
  const jump = (id: string) => {
    const el = document.getElementById(id)!;
    if (lenis) lenis.scrollTo(el, { duration: 1.6, easing: (t) => 1 - Math.pow(1 - t, 4) });
    else el.scrollIntoView({ behavior: reduce ? 'auto' : 'smooth' });
  };
  const chrome = buildChrome(list, jump);
  revealOnView();
  magnetic();
  filmDialog();
  if (!motion) { stillMode(list, chrome); return; }

  lenis = new Lenis({ lerp: 0.085, wheelMultiplier: 0.95, touchMultiplier: 1.1 });
  const backdrop = document.createElement('div');
  backdrop.className = 'backdrop';
  document.body.prepend(backdrop);

  const stage = new Stage($<HTMLCanvasElement>('#gl'));
  const phone = new Phone();
  const book = new Book();
  const cabinet = new Cabinet();
  stage.scene.add(phone.group, book.group, cabinet.group);

  // 材質依需要載入；手機與窄螢幕用較小的圖
  const small = stage.narrow || (devicePixelRatio || 1) < 1.5;
  const textures = new Map<string, THREE.Texture>();
  const want = (name: string) => {
    if (!textures.has(name)) {
      textures.set(name, null as unknown as THREE.Texture);
      screenTexture(name, small).then((t) => textures.set(name, t)).catch(() => {});
    }
    return textures.get(name) || null;
  };
  want('home');
  setTimeout(() => SCREENS.forEach(want), 600);
  for (const [id, def] of Object.entries(POPS)) phone.addPop(id, def.rect);

  /* ---- 量測 ---- */
  let vh = innerHeight;
  const metric = new Map<string, { top: number; height: number }>();
  let stops: number[] = [];
  let wirePaths: SVGPathElement[] = [];
  const measure = () => {
    vh = innerHeight;
    for (const c of list) {
      const r = c.el.getBoundingClientRect();
      metric.set(c.id, { top: r.top + scrollY, height: r.height });
    }
    stops = [];
    const cuts: Record<string, number[]> = {
      listing: [0.12, 0.42, 0.74], discover: [0.2, 0.62], chat: [0.14, 0.46, 0.78], cabinet: [0.14, 0.38, 0.52, 0.7, 0.86],
      payment: [0.26, 0.64], together: [0.12, 0.44, 0.6, 0.84], cover: [0], problem: [0], fee: [0], end: [0.6],
    };
    for (const c of list) {
      const m = metric.get(c.id)!;
      for (const k of cuts[c.id] || [0]) stops.push(Math.round(m.top + k * Math.max(0, m.height - vh)));
    }
    stops.sort((a, b) => a - b);
    wirePaths = drawWires();
  };
  measure();
  addEventListener('resize', () => { measure(); lenis!.resize(); });
  // 檢查用：直接跳到某章節的指定進度（截圖腳本使用）
  (window as unknown as { __go: (id: string, p: number) => void }).__go = (id: string, p: number) => {
    const m = metric.get(id)!;
    const target = m.top + p * Math.max(0, m.height - vh);
    lenis!.scrollTo(target, { immediate: true, force: true });
  };
  document.fonts?.ready.then(measure);
  addEventListener('load', measure);

  const sticky = (id: string, y: number) => {
    const m = metric.get(id)!;
    return clamp((y - m.top) / Math.max(1, m.height - vh));
  };
  const flow = (id: string, y: number) => {
    const m = metric.get(id)!;
    return clamp((y - m.top + vh) / (m.height + vh));
  };

  /* ---- 指標微傾 ---- */
  const tilt = { x: 0, y: 0, tx: 0, ty: 0 };
  addEventListener('pointermove', (e) => {
    if (e.pointerType !== 'mouse') return;
    tilt.tx = (e.clientX / innerWidth - 0.5) * 2;
    tilt.ty = (e.clientY / innerHeight - 0.5) * 2;
  });
  addEventListener('deviceorientation', (e) => {
    if (e.gamma == null || e.beta == null) return;
    tilt.tx = clamp(e.gamma / 30, -1, 1);
    tilt.ty = clamp((e.beta - 45) / 30, -1, 1);
  });

  /* ---- 鍵盤逐段前進 ---- */
  addEventListener('keydown', (e) => {
    if (!['ArrowDown', 'ArrowUp'].includes(e.key) || e.altKey || e.metaKey || e.ctrlKey) return;
    if (!$<HTMLElement>('.toc').hidden || ($('.film') as HTMLDialogElement).open) return;
    const t = e.target as HTMLElement;
    if (t.closest('input, textarea, video')) return;
    e.preventDefault();
    const y = scrollY;
    const next = e.key === 'ArrowDown' ? stops.find((s) => s > y + 8) : [...stops].reverse().find((s) => s < y - 8);
    if (next != null) lenis!.scrollTo(next, { duration: 1.2 });
  });

  /* ---- 書架拖曳 ---- */
  const shelf = $('.shelf');
  const shelfRow = $('.shelf__row');
  const drag = { offset: 0, v: 0, active: false, x0: 0, last: 0 };
  shelf.addEventListener('pointerdown', (e) => {
    drag.active = true;
    drag.x0 = e.clientX;
    drag.last = e.clientX;
    shelf.setPointerCapture(e.pointerId);
    shelf.classList.add('is-dragging');
  });
  shelf.addEventListener('pointermove', (e) => {
    if (!drag.active) return;
    const dx = e.clientX - drag.last;
    drag.last = e.clientX;
    drag.offset += dx;
    drag.v = dx;
  });
  const endDrag = () => { drag.active = false; shelf.classList.remove('is-dragging'); };
  shelf.addEventListener('pointerup', endDrag);
  shelf.addEventListener('pointercancel', endDrag);

  /* ---- DOM 參照 ---- */
  const beatsOf = (id: string) => $$('.beat', document.getElementById(id)!);
  const beats: Record<string, HTMLElement[]> = {};
  for (const id of ['listing', 'discover', 'chat', 'cabinet', 'payment', 'together']) beats[id] = beatsOf(id);
  const setBeat = (id: string, i: number) => beats[id].forEach((b, k) => b.classList.toggle('is-on', k === i));
  const coverText = $('.cover__text');
  const coverSpine = $('.cover__spine');
  const coverTurn = $('.cover__turn');
  const shelfBooks = $$('.book', shelfRow);
  const labels = $$('.xray-labels li');
  const notice = $('.notice');
  const pill = document.createElement('p');
  pill.className = 'unlock-pill';
  pill.textContent = 'A01 已開鎖';
  $('#cabinet .stage').append(pill);
  const flyers = ['2', '5'].map((d) => {
    const el = document.createElement('span');
    el.className = 'flyer-digit';
    el.textContent = d;
    $('.flyers').append(el);
    return el;
  });
  const escrow = $('.escrow');
  const coin = $('.coin');
  const nodes = $$('.escrow__nodes li');
  const track = $$('.escrow__track li');
  const gain = $('.escrow__gain');
  const orbit = $('.orbit');
  const core = $('.orbit__core');
  const orbitItems = $$('.orbit__ring li');
  const rings = $$('.rings i');
  const arch = $('.arch');
  const stats = $('.stats');
  const endMark = $('.end__mark');
  endMark.style.visibility = 'hidden';
  let statsCounted = false;

  // 開場：書本攤開、書名落定
  const intro = { open: 0, t0: 0 };
  document.fonts?.ready.then(() => {
    $('.ch-cover .stage').classList.add('is-ready');
    $$('.ch-char').forEach((c, i) => c.style.setProperty('--i', String(i)));
    intro.t0 = performance.now();
  });

  const v3 = new THREE.Vector3();
  const v2 = new THREE.Vector2();
  const project = (obj: THREE.Object3D) => stage.toScreen(obj.getWorldPosition(v3), v2.clone());

  const place = (obj: THREE.Object3D, p: Pose) => {
    obj.position.set((p.x ?? 0) * stage.halfW, (p.y ?? 0) * stage.halfH, p.z ?? 0);
    obj.rotation.set(p.rx ?? 0, p.ry ?? 0, p.rz ?? 0);
    obj.scale.setScalar(p.s ?? 1);
  };

  /* ---------------- 各章節 ---------------- */

  const N = () => stage.narrow;
  const coverEnd = (): Pose => N() ? { x: 0, y: -0.36, z: 0, rx: 0.05, ry: -0.3, rz: 0, s: 0.95 } : { x: 0.36, y: -0.02, z: 0, rx: 0.05, ry: -0.42, rz: 0.03, s: 1.2 };
  const off = (p: Pose, dy: number): Pose => ({ ...p, y: dy });

  let screens: [string | null, string | null, number] = [null, null, 0];
  let pops: Record<string, number> = {};
  let phonePose: Pose | null = null;
  let bookPose: Pose | null = null;
  let bookState = { open: 1, turn: 0 };
  let cabinetPose: Pose | null = null;

  function cover(p: number) {
    const k = clamp((performance.now() - intro.t0) / 1900);
    intro.open = intro.t0 ? easeOut(k) : 0;
    const turn = span(p, 0.06, 0.42);
    bookState = { open: intro.open, turn };
    const sink = span(p, 0.4, 0.8);
    const base: Pose = N() ? { x: 0, y: 0.2, z: 0, rx: -0.98, ry: 0, rz: 0.06, s: 0.62 } : { x: 0.07, y: 0.12, z: 0, rx: -0.98, ry: 0, rz: 0.1, s: 1 };
    bookPose = { ...base, y: base.y - sink * 1.5, rx: base.rx - sink * 0.3, s: base.s * (1 - sink * 0.15) };
    coverText.style.opacity = String(1 - span(p, 0.22, 0.42));
    coverText.style.transform = `translateY(${-span(p, 0.22, 0.5) * 60}px)`;
    coverSpine.style.opacity = String(1 - span(p, 0.15, 0.35));
    coverTurn.style.opacity = String(1 - span(p, 0.02, 0.08));
    const rise = span(p, 0.38, 0.92);
    if (rise > 0) {
      const end = coverEnd();
      const start: Pose = { x: bookPose.x, y: bookPose.y - 0.08, z: -2, rx: -1.3, ry: 0, rz: 0, s: 0.3 };
      phonePose = keyframes(rise, [[0, start], [1, end]]);
      screens = ['home', null, 0];
    }
  }

  /** 序章結束後，第一章由下方進場時手機往上離開。 */
  function coverExit(y: number) {
    const m = metric.get('cover')!;
    const e = span(y, m.top + m.height - vh, m.top + m.height - vh * 0.35);
    if (e >= 1) return;
    const end = coverEnd();
    phonePose = keyframes(e, [[0, end], [1, { ...end, y: 1.8, ry: (end.ry ?? 0) + 0.3, rz: -0.08 }]], easeOut);
    screens = ['home', null, 0];
  }

  function listing(p: number) {
    const wide: Frame[] = [[0, { x: 0.36, y: -1.8, z: 0, rx: 0.2, ry: -0.62, rz: 0.1, s: 1.22 }], [0.1, { y: -0.02, rx: 0.05, ry: -0.38, rz: 0.02 }], [0.34, { ry: -0.3 }], [0.44, { x: 0.4, ry: 0.22, rz: -0.02 }], [0.66, { ry: 0.16 }], [0.76, { x: 0.37, ry: -0.2, rx: 0.1 }], [0.9, {}], [1, { y: 1.8, ry: -0.05 }]];
    const narrow: Frame[] = [[0, { x: 0, y: -1.8, z: 0, rx: 0.2, ry: -0.4, rz: 0, s: 0.95 }], [0.1, { y: -0.42, rx: 0.04, ry: -0.22 }], [0.44, { ry: 0.18 }], [0.76, { ry: -0.15 }], [0.9, {}], [1, { y: 1.8 }]];
    phonePose = keyframes(p, N() ? narrow : wide);
    screens = chain(p, [['home', 0], ['sell_ai', 0.02], ['sell_price', 0.22], ['book_detail', 0.37], ['sell_ai_sheet', 0.69]]);
    pops.aiBar = span(p, 0.11, 0.17) * (1 - span(p, 0.19, 0.22));
    pops.condition = span(p, 0.24, 0.28) * (1 - span(p, 0.33, 0.36));
    pops.price = span(p, 0.28, 0.32) * (1 - span(p, 0.33, 0.36));
    pops.intro = span(p, 0.76, 0.83) * (1 - span(p, 0.9, 0.95));
    setBeat('listing', beatAt(p, [0.36, 0.68]));
  }

  function discover(p: number) {
    const move = span(p, 0.03, 0.5);
    const rowW = shelfRow.scrollWidth;
    const minX = Math.min(0, innerWidth - rowW);
    if (!drag.active) { drag.offset += drag.v; drag.v *= 0.92; }
    const base = minX * move;
    drag.offset = clamp(drag.offset, minX - base, -base);
    const x = base + drag.offset;
    const out = span(p, 0.5, 0.58);
    shelfRow.style.transform = `translate3d(${x}px, 0, 0)`;
    shelf.style.opacity = String(1 - out);
    shelf.style.transform = `translateY(${out * 30}vh)`;
    shelf.style.visibility = out >= 1 ? 'hidden' : 'visible';
    const mid = innerWidth / 2;
    let best: HTMLElement | null = null, dist = Infinity;
    for (const b of shelfBooks) {
      const r = b.getBoundingClientRect();
      const d = Math.abs(r.left + r.width / 2 - mid);
      if (d < dist) { dist = d; best = b; }
    }
    shelfBooks.forEach((b) => b.classList.toggle('is-noted', b === best && p > 0.04 && p < 0.5));
    const wide: Frame[] = [[0, { x: 0.42, y: -1.8, z: 0, rx: 0.2, ry: -0.5, rz: 0.08, s: 1.22 }], [0.5, {}], [0.6, { y: -0.02, rx: 0.05, ry: -0.36, rz: 0.02 }], [0.88, { ry: -0.3 }], [1, { x: -0.38, ry: 0.36, rz: -0.02 }]];
    const narrow: Frame[] = [[0, { x: 0, y: -1.8, z: 0, rx: 0.2, ry: -0.3, rz: 0, s: 0.95 }], [0.5, {}], [0.6, { y: -0.42, rx: 0.04, ry: -0.2 }], [0.9, {}], [1, { ry: 0.2 }]];
    if (p > 0.48) {
      phonePose = keyframes(p, N() ? narrow : wide);
      screens = ['ai_chat', null, 0];
      pops.advisorReq = span(p, 0.62, 0.67) * (1 - span(p, 0.69, 0.72));
      pops.advisor = span(p, 0.72, 0.79) * (1 - span(p, 0.86, 0.92));
    }
    setBeat('discover', beatAt(p, [0.52]));
  }

  function chat(p: number) {
    const wide: Frame[] = [[0, { x: -0.38, y: -0.02, z: 0, rx: 0.05, ry: 0.36, rz: -0.02, s: 1.22 }], [0.36, { ry: 0.3 }], [0.44, { x: -0.36, ry: -0.18, rz: 0.02 }], [0.68, {}], [0.76, { ry: 0.3, rz: -0.02 }], [0.9, {}], [1, { y: -1.8, ry: 0.6 }]];
    const narrow: Frame[] = [[0, { x: 0, y: -0.42, z: 0, rx: 0.04, ry: 0.2, rz: 0, s: 0.95 }], [0.4, { ry: -0.15 }], [0.76, { ry: 0.18 }], [0.9, {}], [1, { y: -1.8 }]];
    phonePose = keyframes(p, N() ? narrow : wide);
    screens = chain(p, [['chat_room', 0], ['my_reservations', 0.69]]);
    pops.chatReserve = span(p, 0.1, 0.18) * (1 - span(p, 0.3, 0.35));
    pops.chatBanner = span(p, 0.42, 0.48) * (1 - span(p, 0.52, 0.55));
    pops.chatWarn = span(p, 0.54, 0.6) * (1 - span(p, 0.63, 0.67));
    pops.resCard = span(p, 0.78, 0.85) * (1 - span(p, 0.9, 0.95));
    setBeat('chat', beatAt(p, [0.36, 0.7]));
  }

  let kioskState: KioskState = 'qr';
  function cabinetScene(p: number, t: number) {
    const cw: Frame[] = [[0, { x: 0.12, y: -1.9, z: 0, rx: 0.12, ry: 0.72, rz: 0, s: 1.55 }], [0.08, { y: -0.04, rx: 0.06, ry: 0.42 }], [0.3, { ry: 0.16 }], [0.36, { x: -0.02, ry: 0.24, s: 1.42 }], [0.92, {}], [1, { x: -0.1, y: -1.9 }]];
    const cn: Frame[] = [[0, { x: 0, y: -1.9, z: 0, rx: 0.1, ry: 0.6, rz: 0, s: 0.8 }], [0.08, { y: -0.34, ry: 0.36 }], [0.11, { x: -0.44, ry: 0.22, s: 0.72 }], [0.3, { ry: 0.14 }], [0.36, { x: -0.4, y: -0.36, ry: 0.22, s: 0.6 }], [0.92, {}], [1, { y: -1.9 }]];
    cabinetPose = keyframes(p, N() ? cn : cw);
    const xray = span(p, 0.1, 0.16) * (1 - span(p, 0.25, 0.3));
    cabinet.setXray(xray);
    const door = span(p, 0.63, 0.67) * (1 - span(p, 0.79, 0.83));
    cabinet.setDoor(0, door);
    cabinet.setDeposit(span(p, 0.68, 0.75));

    let seconds = 60;
    if (p < 0.42) kioskState = 'qr';
    else if (p < 0.47) kioskState = 'busy';
    else if (p < 0.62) { kioskState = 'match'; seconds = 52; }
    else if (p < 0.8) { kioskState = 'open'; seconds = Math.round(lerp(30, 24, span(p, 0.62, 0.8))); }
    else kioskState = 'done';
    const fly = span(p, 0.5, 0.57);
    cabinet.kiosk.draw({ state: kioskState, refresh: (t / 30) % 1, seconds, digits: kioskState === 'match' ? 1 - 0.7 * span(fly, 0, 0.25) : 1, check: easeOut(span(p, 0.8, 0.84)) });

    const pw: Frame[] = [[0, { x: 0.58, y: -1.9, z: 0, rx: 0.12, ry: -0.5, rz: 0.05, s: 1.15 }], [0.3, {}], [0.36, { y: -0.02, rx: 0.04, ry: -0.3, rz: 0.02 }], [0.92, {}], [1, { y: 1.8 }]];
    const pn: Frame[] = [[0, { x: 0.46, y: -1.9, z: 0, rx: 0.1, ry: -0.3, rz: 0, s: 0.6 }], [0.3, {}], [0.36, { y: -0.36, rx: 0.04, ry: -0.22 }], [0.92, {}], [1, { y: 1.8 }]];
    if (p > 0.28) phonePose = keyframes(p, N() ? pn : pw);
    screens = chain(p, [['cabinet_scan', 0], ['cabinet_match_empty', 0.47], ['cabinet_match', 0.572], ['cabinet_open', 0.62], ['cabinet_done', 0.81]], 0.03);
    setBeat('cabinet', beatAt(p, [0.3, 0.47, 0.62, 0.8]));
    return { xray, fly, door };
  }

  function payment(p: number) {
    const k = span(p, 0.05, 0.46);
    const toHold = span(k, 0.06, 0.3);
    const toSeller = span(k, 0.72, 0.95);
    const out = span(p, 0.48, 0.55);
    escrow.style.opacity = String(1 - out);
    escrow.style.visibility = out >= 1 ? 'hidden' : 'visible';
    escrow.style.translate = `${out * 40}px 0`;
    const pts = nodes.map((n) => {
      const r = n.getBoundingClientRect();
      const e = escrow.getBoundingClientRect();
      const d = n.querySelector<HTMLElement>('b')!;
      const top = r.top - e.top;
      return { x: r.left - e.left + r.width / 2, y: top + (parseFloat(getComputedStyle(n, '::before').height) || 54) / 2, h: d };
    });
    if (pts.length === 3) {
      const a = toSeller > 0 ? pts[1] : pts[0];
      const b = toSeller > 0 ? pts[2] : pts[1];
      const m = toSeller > 0 ? toSeller : toHold;
      const cx = lerp(a.x, b.x, easeOut(m));
      const cy = lerp(a.y, b.y, m) - Math.sin(Math.PI * m) * 46;
      const size = coin.offsetWidth;
      coin.style.transform = `translate(${cx - size / 2}px, ${cy - size / 2}px)`;
    }
    nodes.forEach((n, i) => n.classList.toggle('is-hot', (i === 0 && toHold < 1) || (i === 1 && toHold >= 1 && toSeller <= 0) || (i === 2 && toSeller >= 1)));
    const done = [0.18, 0.4, 0.52, 0.64, 0.95];
    track.forEach((li, i) => li.classList.toggle('is-done', k >= done[i]));
    gain.classList.toggle('is-on', toSeller >= 1);
    const wide: Frame[] = [[0, { x: 0.44, y: -1.9, z: 0, rx: 0.12, ry: -0.5, rz: 0.05, s: 1.22 }], [0.5, {}], [0.6, { y: -0.02, rx: 0.05, ry: -0.34, rz: 0.02 }], [0.9, {}], [1, { y: 1.8 }]];
    const narrow: Frame[] = [[0, { x: 0, y: -1.9, z: 0, rx: 0.12, ry: -0.3, rz: 0, s: 0.95 }], [0.5, {}], [0.6, { y: -0.42, rx: 0.04, ry: -0.2 }], [0.9, {}], [1, { y: 1.8 }]];
    if (p > 0.48) {
      phonePose = keyframes(p, N() ? narrow : wide);
      screens = ['pay_verify', null, 0];
    }
    setBeat('payment', beatAt(p, [0.5]));
  }

  function together(p: number) {
    const w = innerWidth, h = innerHeight;
    const cx = N() ? w / 2 : w * 0.685;
    const cy = N() ? h * 0.66 : h * 0.54;
    const rx = N() ? w * 0.3 : Math.min(w * 0.22, 400);
    const ry = rx * (N() ? 0.62 : 0.62);
    const gather = span(p, 0.26, 0.38);
    const visible = p < 0.46;
    orbit.style.visibility = visible ? 'visible' : 'hidden';
    const spin = p * Math.PI * 1.4;
    orbitItems.forEach((li, i) => {
      const a = spin + (i / orbitItems.length) * Math.PI * 2;
      const depth = (Math.sin(a) + 1) / 2;
      const r = 1 - easeOut(gather);
      const x = cx + Math.cos(a) * rx * r - w / 2;
      const y = cy + Math.sin(a) * ry * r - h / 2;
      const s = (0.86 + depth * 0.3) * (1 - gather * 0.6);
      li.style.transform = `translate(${x}px, ${y - 40}px) scale(${s})`;
      li.style.opacity = String((0.62 + depth * 0.38) * (1 - gather) * span(p, 0, 0.05));
      li.style.zIndex = String(Math.round(depth * 10));
      li.classList.toggle('is-front', Math.sin(a) > Math.sin(Math.PI / 2 - Math.PI / orbitItems.length));
    });
    const coreS = 1 + easeOut(span(p, 0.28, 0.4)) * (N() ? 1.1 : 1.6);
    core.style.transform = `translate(${cx - w / 2}px, ${cy - h / 2}px) scale(${coreS})`;
    core.style.opacity = String(span(p, 0, 0.05) * (1 - span(p, 0.33, 0.39)));
    rings.forEach((r, i) => {
      const k = span(p, 0.3 + i * 0.018, 0.46 + i * 0.018);
      r.style.transform = `translate(${cx - w / 2}px, ${cy - h / 2}px) scale(${0.25 + k * k * 6})`;
      r.style.opacity = String(Math.sin(Math.PI * k) * 0.9);
    });
    const archOn = p >= 0.5 && p < 0.76;
    arch.classList.toggle('is-on', archOn);
    const draw = span(p, 0.52, 0.62);
    for (const path of wirePaths) {
      const len = path.getTotalLength();
      path.style.strokeDasharray = path.classList.contains('dash') ? '3 5' : `${len}`;
      path.style.strokeDashoffset = path.classList.contains('dash') ? '0' : `${len * (1 - draw)}`;
      path.style.opacity = path.classList.contains('dash') ? String(draw) : '1';
    }
    const statsOn = p >= 0.76;
    stats.classList.toggle('is-on', statsOn);
    if (statsOn && !statsCounted) { statsCounted = true; $$('.count', stats).forEach((c) => countUp(c)); }
    setBeat('together', beatAt(p, [0.32, 0.5, 0.76]));
  }

  function end(p: number) {
    const k = span(p, 0, 0.25);
    const base: Pose = N() ? { x: 0, y: 0.5, z: 0, rx: -0.98, ry: 0, rz: 0, s: 0.42 } : { x: 0, y: 0.46, z: 0, rx: -0.98, ry: 0, rz: 0, s: 0.36 };
    bookPose = { ...base, y: lerp(1.6, base.y!, easeOut(k)) };
    bookState = { open: 1 - span(p, 0.2, 0.62), turn: 1 };
  }

  /* ---------------- 每格更新 ---------------- */

  let lastChapter = -1;
  stage.onFrame((t, dt) => {
    const y = scrollY;
    phonePose = null;
    bookPose = null;
    cabinetPose = null;
    pops = {};
    screens = [null, null, 0];

    const pc = sticky('cover', y);
    const qEnd = flow('end', y);
    const pEnd = sticky('end', y);

    // 章節判定
    let idx = 0;
    list.forEach((c, i) => { if (metric.get(c.id)!.top <= y + vh * 0.4) idx = i; });
    if (idx !== lastChapter) { chrome.setCurrent(idx); lastChapter = idx; }

    // 背景色：封面與終章為石板藍
    const slate = Math.max(1 - span(pc, 0.5, 0.8), span(qEnd, 0.25, 0.5));
    const col = PAPER.clone().lerp(SLATE, slate);
    const css = `#${col.getHexString()}`;
    backdrop.style.backgroundColor = css;
    document.body.style.backgroundColor = css;
    root.style.setProperty('--bg', css);
    root.dataset.tone = slate > 0.5 ? 'dark' : 'light';

    const id = list[idx].id;
    const inRange = (key: string) => {
      const m = metric.get(key)!;
      return y >= m.top - vh && y <= m.top + m.height;
    };
    if (pc < 1) cover(pc);
    else { bookPose = null; coverExit(y); }
    if (inRange('listing') && y >= metric.get('listing')!.top - vh * 0.6) listing(sticky('listing', y));
    if (inRange('discover') && y >= metric.get('discover')!.top) discover(sticky('discover', y));
    if (inRange('chat') && y >= metric.get('chat')!.top) chat(sticky('chat', y));
    let cab = { xray: 0, fly: 0, door: 0 };
    if (inRange('cabinet') && y >= metric.get('cabinet')!.top - vh * 0.5) cab = cabinetScene(sticky('cabinet', y), t);
    if (inRange('payment') && y >= metric.get('payment')!.top) payment(sticky('payment', y));
    if (inRange('together')) together(sticky('together', y));
    if (inRange('end') && y >= metric.get('end')!.top - vh * 0.3) end(pEnd);

    // 指標微傾（平滑）
    tilt.x += (tilt.tx - tilt.x) * Math.min(1, dt * 4);
    tilt.y += (tilt.ty - tilt.y) * Math.min(1, dt * 4);

    // 手機
    phone.group.visible = !!phonePose;
    if (phonePose) {
      place(phone.group, phonePose);
      phone.body.rotation.set(tilt.y * 0.07 + Math.sin(t * 0.7) * 0.012, tilt.x * 0.11, Math.sin(t * 0.55) * 0.008);
      phone.body.position.y = Math.sin(t * 0.9) * 0.1;
      const [a, b, m] = screens;
      phone.setScreens(a ? want(a) : null, b ? want(b) : null, m);
      for (const [pid, card] of phone.pops) {
        card.setTexture(want(POPS[pid].screen));
        card.set(easeOut(pops[pid] || 0));
      }
    }

    // 書
    book.group.visible = !!bookPose;
    if (bookPose) {
      place(book.group, bookPose);
      book.group.rotation.y += tilt.x * 0.06;
      book.group.rotation.x += tilt.y * 0.03;
      book.set(bookState.open, bookState.turn);
    }

    // 書櫃
    cabinet.group.visible = !!cabinetPose;
    if (cabinetPose) {
      place(cabinet.group, cabinetPose);
      cabinet.group.rotation.y += tilt.x * 0.08;
      cabinet.group.rotation.x += tilt.y * 0.03;
      cabinet.group.position.y += Math.sin(t * 0.8) * 0.06;
    }
    updateCabinetDom(cab);
    updateBookEnd(pEnd, qEnd);
  });

  /* ---------------- 書櫃章節的 DOM ---------------- */

  function updateCabinetDom(cab: { xray: number; fly: number; door: number }) {
    const showLabels = cabinet.group.visible && cab.xray > 0.6;
    const center = cabinet.group.visible ? project(cabinet.group) : new THREE.Vector2();
    const scale = cabinet.group.scale.x;
    const halfPx = (3.1 * scale) / (stage.halfW * 2) * innerWidth;
    const placed: { li: HTMLElement; left: boolean; x: number; y: number; ax: number; edgeX: number }[] = [];
    for (const li of labels) {
      const key = li.dataset.part!;
      const anchor = cabinet.anchors[key];
      if (!showLabels || !anchor) { li.style.opacity = '0'; continue; }
      const a = project(anchor);
      const left = !N() && a.x < center.x;
      const edgeX = left ? center.x - halfPx - 26 : center.x + halfPx + 26;
      li.classList.toggle('is-left', left);
      placed.push({ li, left, x: left ? edgeX - li.offsetWidth : edgeX, y: a.y - 10, ax: a.x, edgeX });
    }
    // 同側標註依高度排序後往下推開，避免重疊
    for (const side of [true, false]) {
      const group = placed.filter((q) => q.left === side).sort((a, b) => a.y - b.y);
      for (let i = 1; i < group.length; i++) {
        const prev = group[i - 1];
        group[i].y = Math.max(group[i].y, prev.y + prev.li.offsetHeight + 8);
      }
    }
    for (const q of placed) {
      q.li.style.transform = `translate(${q.x}px, ${q.y}px)`;
      q.li.style.setProperty('--lead', `${Math.max(8, Math.abs(q.edgeX - q.ax))}px`);
      q.li.style.opacity = String(span(cab.xray, 0.6, 1));
    }
    // 比對數字飛進手機：兩個數字各自飛向對應的輸入格
    const flying = cabinet.group.visible && phone.group.visible && cab.fly > 0 && cab.fly < 1;
    flyers.forEach((el, i) => {
      if (!flying) { el.style.opacity = '0'; return; }
      const local = cabinet.anchors.digits.position.clone();
      local.x += (i === 0 ? -1 : 1) * 0.27;
      const from = stage.toScreen(cabinet.group.localToWorld(local), new THREE.Vector2());
      const to = stage.toScreen(phone.screenPoint(DIGIT_BOXES[i][0], DIGIT_BOXES[i][1]), new THREE.Vector2());
      const k = easeOut(span(cab.fly, i * 0.08, 0.92 + i * 0.08));
      const x = lerp(from.x, to.x, k);
      const yy = lerp(from.y, to.y, k) - Math.sin(Math.PI * k) * 90;
      const fromSize = (0.9 * cabinet.group.scale.x) / (stage.halfH * 2) * innerHeight;
      const toSize = (30 * 6.61 / 393 * phone.group.scale.x) / (stage.halfH * 2) * innerHeight;
      el.style.fontSize = `${lerp(fromSize, toSize, k)}px`;
      el.style.color = `rgb(${lerp(238, 21, span(k, 0.18, 0.4)).toFixed(0)}, ${lerp(242, 30, span(k, 0.18, 0.4)).toFixed(0)}, ${lerp(245, 39, span(k, 0.18, 0.4)).toFixed(0)})`;
      el.style.transform = `translate(${x}px, ${yy}px) translate(-50%, -50%)`;
      el.style.opacity = String(span(cab.fly, 0, 0.06) * (1 - span(k, 0.9, 1)));
    });
    // A01 已開鎖
    if (cabinet.group.visible && cab.door > 0.3) {
      const a = project(cabinet.anchors.cellA01);
      pill.style.transform = N() ? `translate(${Math.max(8, a.x)}px, ${a.y}px) translate(0, -150%)` : `translate(${a.x}px, ${a.y}px) translate(-100%, -130%)`;
      pill.classList.add('is-on');
    } else pill.classList.remove('is-on');
    // 存書完成通知
    const pc = sticky('cabinet', scrollY);
    const showNotice = phone.group.visible && pc > 0.85 && pc < 0.95;
    if (showNotice) {
      const top = stage.toScreen(phone.screenPoint(196, 64), new THREE.Vector2());
      const w = notice.offsetWidth;
      notice.style.left = `${clamp(top.x - w / 2, 12, innerWidth - w - 12)}px`;
      notice.style.top = `${top.y}px`;
    }
    notice.classList.toggle('is-on', showNotice);
  }

  function updateBookEnd(p: number, q: number) {
    $('.ch-end .stage').style.opacity = String(span(q, 0.3, 0.5));
    void p;
  }
}
