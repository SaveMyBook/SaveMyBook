'use strict';

const { el, g, fmt, T, anim, motion, linearGradient, radialGradient, addDef, during, drawPath, penDot, nextId, blurFilter, rng } = require('../lib/core');
const { text, measure } = require('../lib/text');
const { screenRect, doorRect, SCREEN_SCALE } = require('../lib/cabinet');
const { rings } = require('../lib/fx');
const U = require('../lib/appui');
const V = require('../lib/ui2');
const W3 = require('../lib/ui3');
const Wd = require('../lib/world');
const { icon } = require('../lib/icons');
const C = require('../lib/palette');
const flow = require('./flow');
const ai = require('./ai');

const F = 0.6;
const OUT = F + 24.0;
const t = { ...flow.times(F), end: OUT, matchPhone: F + 6.35, matchKiosk: F + 6.45 };
t.steps = [F + 0.5, F + 6.7, F + 12.0, F + 18.9];
const A = OUT + 2.3;
const CORE = { x: 4300, y: 560 };
const RX = 2000;
const RY = 1250;

// [key, 視覺原點, 是否搭配手機, 節點標籤, 圖示, 說明, 停留秒數]
const SPEC = [
  ['assist', [1085, 530], true, '上架輔助', 'wand', '依 ISBN 查詢書目與網路資料，附上建議售價區間與資料來源。', 8.8],
  ['review', [1310, 545], false, '上架審核', 'verified', '規則即時攔截售價異常，AI 再判讀照片，必要時交由管理員複核。', 7.2],
  ['enrich', [1320, 535], false, '資料補齊', 'doc', '上架後於背景依 ISBN 查詢書目，由 AI 整理成繁體中文簡介。', 6.0],
  ['rec', [1060, 540], true, '個人化推薦', 'star', '分析收藏與瀏覽紀錄，以語意向量找出相近書籍並寫下推薦理由。', 8.2],
  ['advisor', [1060, 530], true, 'AI 書籍顧問', 'sparkle', '理解分類、預算與書況條件，只推薦站內可購買的書籍。', 7.2],
  ['support', [1065, 530], true, 'AI 客服', 'headset', '以關鍵字與語意混合檢索作答，複雜問題一鍵轉接客服人員。', 6.2],
  ['dispute', [1300, 595], false, '爭議分析', 'gavel', '比對上架資料、照片與爭議說明，整理摘要與建議，僅供管理員參考。', 7.6],
];
const ISLANDS = {};
SPEC.forEach(([key, orig, phone, label, ic, body, beat], i) => {
  const th = ((-90 - 360 / 7 + (360 / 7) * i) * Math.PI) / 180;
  ISLANDS[key] = { key, i, orig, phone, label, icon: ic, body, beat, x: Math.round(CORE.x + RX * Math.cos(th)), y: Math.round(CORE.y + RY * Math.sin(th)) };
});
const ORDER = SPEC.map((s) => s[0]);
const frameC = (isl) => (isl.phone ? [725, 640] : [960, 640]);

function aiTimes() {
  const win = {};
  let travel = A + 5.3;
  for (const key of ORDER) {
    const arrive = travel + 1.3;
    const t0 = arrive - 0.6;
    const t1 = t0 + ISLANDS[key].beat;
    win[key] = { travel, arrive, t0, t1 };
    travel = t1 - 0.4;
  }
  win.gov = { travel, arrive: travel + 1.5, t0: travel + 0.9, t1: travel + 0.9 + 5.6 };
  return win;
}
const WIN = aiTimes();
const DURATION = Math.round((WIN.gov.t1 + 1.0) * 10) / 10;

function cameraKeys() {
  const keys = [
    { t: 0, k: 1.9, p: [980, 299], c: [760, 680] },
    { t: F + 6.6, k: 1.97, p: [982, 298], c: [760, 680], ease: 'soft' },
    { t: F + 7.5, k: 2.15, p: [980, 292], c: [760, 690], ease: 'inout' },
    { t: F + 11.6, k: 2.22, p: [978, 292], c: [760, 690], ease: 'soft' },
    { t: F + 12.8, k: 1.6, p: [885, 548], c: [740, 660], ease: 'inout' },
    { t: F + 17.9, k: 1.66, p: [888, 546], c: [740, 660], ease: 'soft' },
    { t: F + 19.4, k: 0.88, p: [1016, 474], c: [1060, 670], ease: 'inout' },
    { t: OUT - 0.3, k: 0.9, p: [1018, 476], c: [1060, 670], ease: 'soft' },
    { t: OUT + 1.1, k: 0.27, p: [2650, 480], c: [960, 540], r: -1.5, ease: 'in' },
    { t: A, k: 0.62, p: [CORE.x, CORE.y], c: [1240, 560], r: -0.4, ease: 'out' },
    { t: A + 2.5, k: 0.66, p: [CORE.x, CORE.y], c: [1240, 560], r: 0, ease: 'soft' },
    { t: A + 3.9, k: 0.33, p: [CORE.x, CORE.y + 63], c: [960, 560], r: 0, ease: 'inout' },
    { t: A + 5.3, k: 0.345, p: [CORE.x, CORE.y + 63], c: [960, 560], r: 0.8, ease: 'soft' },
  ];
  let prev = { x: CORE.x, y: CORE.y + 63 };
  for (const key of ORDER) {
    const w = WIN[key];
    const isl = ISLANDS[key];
    const last = keys[keys.length - 1];
    if (w.travel > last.t + 0.05) keys.push({ ...last, t: w.travel, k: last.k * 1.02, ease: 'soft' });
    keys.push({ t: w.travel + 0.65, k: 0.5, p: [(prev.x + isl.x) / 2, (prev.y + isl.y) / 2], c: [960, 560], r: prev.x < isl.x ? 1.4 : -1.4, ease: 'in' });
    keys.push({ t: w.arrive, k: 1, p: [isl.x, isl.y], c: frameC(isl), r: 0, ease: 'out' });
    prev = isl;
  }
  const gw = WIN.gov;
  const last = keys[keys.length - 1];
  keys.push({ ...last, t: gw.travel, k: last.k * 1.02, ease: 'soft' });
  keys.push({ t: gw.travel + 0.75, k: 0.45, p: [(prev.x + CORE.x) / 2, (prev.y + CORE.y) / 2], c: [960, 560], r: 1.2, ease: 'in' });
  keys.push({ t: gw.arrive, k: 0.7, p: [CORE.x, CORE.y + 30], c: [1260, 540], r: 0, ease: 'out' });
  keys.push({ t: DURATION, k: 0.73, p: [CORE.x, CORE.y + 30], c: [1260, 540], r: -0.6, ease: 'soft' });
  return keys;
}
const KEYS = cameraKeys();

function beamPath(isl) {
  const dx = isl.x - CORE.x;
  const dy = isl.y - CORE.y;
  const L = Math.hypot(dx, dy);
  const ux = dx / L;
  const uy = dy / L;
  const a = [CORE.x + ux * 250, CORE.y + uy * 250];
  const b = [isl.x - ux * 175, isl.y - uy * 175];
  const m = [(a[0] + b[0]) / 2 - uy * L * 0.12, (a[1] + b[1]) / 2 + ux * L * 0.12];
  return `M${fmt(a[0])} ${fmt(a[1])}Q${fmt(m[0])} ${fmt(m[1])} ${fmt(b[0])} ${fmt(b[1])}`;
}

function loopDot(d, begin, dur, { r, fill }) {
  return el(
    'circle',
    { r, fill, opacity: 0 },
    el('animateMotion', { path: d, begin: T(begin), dur: `${fmt(dur)}s`, repeatCount: 'indefinite' }),
    el('animate', { attributeName: 'opacity', values: '0;0.9;0.9;0', keyTimes: '0;0.15;0.8;1', begin: T(begin), dur: `${fmt(dur)}s`, repeatCount: 'indefinite' })
  );
}

function coreLayer() {
  const glow = radialGradient(nextId('cg'), [
    [0, '#FFFFFF', 1],
    [0.35, C.brand, 0.9],
    [1, C.brand, 0],
  ]);
  const soft = radialGradient(nextId('cs'), [
    [0, '#FFFFFF', 0.9],
    [0.4, C.brand, 0.45],
    [1, C.brand, 0],
  ]);
  const beams = ORDER.map((key, i) => {
    const isl = ISLANDS[key];
    const w = WIN[key];
    const d = beamPath(isl);
    const t0 = A - 0.5 + i * 0.08;
    return [
      g(
        {},
        anim('opacity', [[w.arrive - 0.3, 1], [w.arrive + 0.2, 0.3, 'out'], [w.t1 - 0.2, 0.3, 'lin'], [w.t1 + 0.4, 1, 'out']]),
        drawPath(d, t0, 1.1, { stroke: C.brand, width: 5, attrs: { 'stroke-opacity': 0.26 } }),
        [0, 1, 2].map((j) => loopDot(d, A + 0.7 + j * 1.1 + i * 0.13, 3.3, { r: 16, fill: soft }))
      ),
      penDot(d, t0, 1.1, { r: 30, fill: glow }),
      penDot(d, w.travel - 0.1, 1.2, { r: 34, fill: glow }),
    ];
  });
  const gw = WIN.gov;
  return g(
    {},
    beams,
    rings(CORE.x, CORE.y, A - 0.7, { color: C.brand, r0: 220, r1: 760, width: 6, peak: 0.5 }),
    rings(CORE.x, CORE.y, gw.arrive - 0.3, { color: C.brand, r0: 220, r1: 760, width: 6, peak: 0.5 }),
    g({ transform: `translate(${CORE.x} ${CORE.y}) scale(2.4) translate(${-CORE.x} ${-CORE.y})` }, W3.aiCore(CORE.x, CORE.y, { r: 90, t0: A - 0.9 }))
  );
}

function node(isl) {
  const w = WIN[isl.key];
  const { x, y, i } = isl;
  const tIn = A + 2.7 + i * 0.1;
  const halo = radialGradient(nextId('nh'), [
    [0, C.brand, 0.2],
    [1, C.brand, 0],
  ]);
  const check = g(
    { opacity: 0 },
    anim('opacity', [[w.t1 + 0.35, 0], [w.t1 + 0.6, 1, 'out']]),
    el('circle', { cx: x + 92, cy: y - 92, r: 36, fill: C.success, stroke: '#FFFFFF', 'stroke-width': 6 }),
    el('path', { d: `M${x + 76} ${y - 92}l11 11 22-22`, fill: 'none', stroke: '#FFFFFF', 'stroke-width': 7, 'stroke-linecap': 'round', 'stroke-linejoin': 'round' })
  );
  const label = g(
    { opacity: 0 },
    anim('opacity', [[tIn + 0.2, 0], [tIn + 0.5, 1, 'out'], [A + 5.6, 1, 'lin'], [A + 6.0, 0, 'in']]),
    g({ transform: `translate(${x} ${y + 236}) scale(3.2)` }, W3.pill(0, 0, isl.label, { anchor: 'middle', size: 24, weight: 700 }).markup)
  );
  const s = [[tIn, 0.3], [tIn + 0.7, 1, 'emph'], [w.arrive - 1.0, 1, 'lin'], [w.arrive - 0.3, 2.2, 'in'], [w.t1 - 0.1, 0.4, 'lin'], [w.t1 + 0.6, 1, 'emph']];
  const o = [[tIn, 0], [tIn + 0.3, 1, 'out'], [w.arrive - 1.0, 1, 'lin'], [w.arrive - 0.3, 0, 'in'], [w.t1 - 0.1, 0, 'lin'], [w.t1 + 0.4, 1, 'out']];
  return motion(
    { s, o, origin: [x, y] },
    el('circle', { cx: x, cy: y, r: 270, fill: halo }),
    g(
      {},
      el('animateTransform', { attributeName: 'transform', type: 'rotate', from: `0 ${x} ${y}`, to: `${i % 2 ? -360 : 360} ${x} ${y}`, dur: `${26 + i * 3}s`, begin: T(A), repeatCount: 'indefinite' }),
      el('circle', { cx: x, cy: y, r: 160, fill: 'none', stroke: C.brand, 'stroke-opacity': 0.35, 'stroke-width': 4, 'stroke-dasharray': '4 22', 'stroke-linecap': 'round' })
    ),
    el('circle', { cx: x + 8, cy: y + 20, r: 118, fill: '#0B1A26', 'fill-opacity': 0.12, filter: blurFilter(nextId('nb'), 22) }),
    el('circle', { cx: x, cy: y, r: 120, fill: '#FFFFFF', stroke: C.brand, 'stroke-opacity': 0.22, 'stroke-width': 4 }),
    icon(isl.icon, x - 50, y - 50, 100, C.brand),
    label,
    check
  );
}

function islandContent(isl, extra) {
  const w = WIN[isl.key];
  const win = [w.t0, w.t1];
  const [ox, oy] = isl.orig;
  let visual;
  switch (isl.key) {
    case 'assist':
      visual = ai.assist(win);
      break;
    case 'review':
      visual = ai.review(win);
      break;
    case 'enrich':
      visual = ai.enrich(win);
      break;
    case 'rec':
      visual = ai.recommend(win, extra.rowsAt, { targets: extra.targets });
      break;
    case 'advisor':
      visual = ai.advisorVisual(win, extra.adv);
      break;
    case 'support':
      visual = ai.supportVisual(win, extra.sup);
      break;
    case 'dispute':
      visual = ai.disputeVisual(win);
      break;
    default:
      visual = '';
  }
  const [cx, cy] = frameC(isl);
  const [eyebrow, title] = ai.COPY[isl.key];
  const block = Wd.caption({ x: isl.x + (112 - cx), y: isl.y + (226 - cy), eyebrow, title: title.join(''), body: [isl.body], t0: w.t0 + 0.4, t1: w.t1 - 0.5 });
  const content = motion(
    { s: [[w.t0 - 0.1, 0.92], [w.t0 + 0.8, 1, 'out'], [w.t1 - 0.4, 1, 'lin'], [w.t1 + 0.3, 0.9, 'in']], origin: [isl.x, isl.y] },
    g({ transform: `translate(${fmt(isl.x - ox)} ${fmt(isl.y - oy)})` }, visual)
  );
  return [content, block];
}

function flowLayers() {
  const sr = screenRect();
  const P = flow.PHONE;
  const toScreen = (x, y) => ({ x: P.x + x * P.s, y: P.y + y * P.s });
  const proj = (tt, pt) => Wd.project(KEYS, tt, pt);
  const kioskTop = (tt) => {
    const p = proj(tt, [sr.x + sr.w / 2, sr.y - 16]);
    return { x: p.x, y: p.y - 46 };
  };
  const kioskSide = (tt) => proj(tt, [sr.x + sr.w + 12, sr.y + sr.h * 0.42]);
  const button = toScreen(U.W / 2, 752);
  const phoneEdge = toScreen(-2, 437);
  const dr = doorRect(0);
  const doorSide = proj(t.door.close[1], [dr.x + dr.w, dr.y + dr.h / 2]);
  const digitWorld = (i) => [sr.x + (120 + (i === 0 ? -21.2 : 21.2)) * SCREEN_SCALE, sr.y + 150 * SCREEN_SCALE];
  const digits = [0, 1].map((i) => {
    const t1 = t.digits[i];
    const t0 = t1 - 0.85;
    const a = proj(t0, digitWorld(i));
    const b = toScreen(i === 0 ? 167 : 235, 408);
    return Wd.flyChip(['4', '7'][i], { from: { x: a.x, y: a.y }, to: { x: b.x, y: b.y }, t0, t1, w: 56 * P.s, h: 64 * P.s, r: 12 * P.s, size: 28 * P.s });
  });
  const lift = [0, 1].map((i) => {
    const t0 = t.digits[i] - 0.85;
    const p = proj(t0, digitWorld(i));
    return el('circle', { cx: fmt(p.x), cy: fmt(p.y), r: 30, fill: 'none', stroke: C.kiosk.accent, 'stroke-width': 3, opacity: 0 }, anim('r', [[t0 - 0.1, 30], [t0 + 0.45, 90, 'out']]), anim('opacity', [[t0 - 0.1, 0.8], [t0 + 0.45, 0, 'out']]));
  });
  const scanCenter = toScreen(U.W / 2, 458.6);
  const qr = kioskTop(t.detect);
  const loc = kioskTop(t.digits[0] + 0.2);
  const lock = proj(F + 13.0, [dr.x + 30, dr.y - 34]);
  const under = g(
    {},
    W3.pill(qr.x, qr.y, 'QR Code 驗證成功', { iconName: 'checkCircle', iconColor: C.success, anchor: 'middle', size: W3.TY.callout, t0: t.detect + 0.3, t1: t.confirm + 1.4 }).markup,
    W3.pill(loc.x, loc.y, '定位確認：書櫃 200 公尺內', { iconName: 'location', anchor: 'middle', size: W3.TY.callout, t0: t.digits[0] + 0.2, t1: t.okTap + 0.5 }).markup,
    W3.pill(lock.x, lock.y, 'A01 已開鎖', { iconName: 'lockOpen', iconColor: C.success, anchor: 'end', size: W3.TY.callout, t0: t.door.unlatch + 0.1, t1: t.door.close[0] }).markup
  );
  const over = g(
    {},
    rings(scanCenter.x, scanCenter.y, t.detect + 0.02, { color: C.brand, r0: 70, r1: 260, peak: 0.45, width: 2.5 }),
    Wd.link(button, kioskSide(t.openTap + 0.8), t.openTap + 0.1, 0.7),
    lift,
    digits,
    Wd.link(button, kioskSide(t.okTap + 0.42), t.okTap + 0.08, 0.34),
    Wd.link(doorSide, phoneEdge, t.door.close[1] + 0.05, 0.5)
  );
  return { under, over };
}

function flowCaptions() {
  const steps = [
    ['01', '掃碼', ['QR Code 約每 30 秒更新，每組只能使用一次。']],
    ['02', '比對', ['輸入書櫃螢幕上的兩位數字，', '並確認您在書櫃 200 公尺內。']],
    ['03', '開門', ['只開啟指定的櫃門，倒數 30 秒內放入書籍。']],
    ['04', '完成', ['櫃門關上才登記存書，', '買家同步收到取書通知。']],
  ];
  const out = [];
  out.push(motion(W3.fadeRise(F + 0.3, OUT - 0.5, { dy: 8 }), text('存書流程', { x: 112, y: 128, size: 24, weight: 700, fill: C.brand, ls: 0.12 })));
  out.push(Wd.stepDots(252, 120, t.steps, { tIn: F + 0.3, tOut: OUT - 0.5 }));
  steps.forEach(([num, title, body], i) => {
    const t0 = t.steps[i] + 0.05;
    const t1 = i < 3 ? t.steps[i + 1] - 0.45 : OUT - 0.6;
    out.push(Wd.caption({ x: 110, y: 226, number: num, title, body, t0, t1 }));
  });
  const lines = ['訂單 ODNMX0225 的書籍已存入「圖書館大廳」書櫃，', '請於營業時間內至書櫃以 App 掃描 QR Code 取書。'];
  const NS = 1.52;
  const nw = (68 + Math.max(...lines.map((l) => measure(l, 14.5))) + 22) * NS;
  out.push(V.notification(112, 410, nw, { title: '書籍已存入書櫃', lines, t0: t.result + 2.1, tOut: OUT - 0.6, scale: NS }));
  return g({}, out);
}

function sideScrim(id, t0, t1, width = 820) {
  const grad = linearGradient(id, [
    [0, C.stage, 0.97],
    [0.62, C.stage, 0.88],
    [1, C.stage, 0],
  ], { x1: 0, y1: 0, x2: 1, y2: 0 });
  const o = [[t0, 0], [t0 + 0.6, 1, 'out']];
  if (t1 !== undefined) o.push([t1, 1, 'lin'], [t1 + 0.6, 0, 'in']);
  return motion({ o }, el('rect', { x: 0, y: 0, width, height: 1080, fill: grad }));
}

function introCaption() {
  const [eyebrow, title, body] = ai.COPY.intro;
  const t0 = A - 0.3;
  const t1 = A + 2.5;
  return g({}, sideScrim('introScrim', t0 - 0.4, t1 + 0.2), W3.leftBlock({ x: 112, y: 330, eyebrow, title, body, t0, t1 }).markup);
}

function govCaption() {
  const [eyebrow, title, body] = ai.COPY.gov;
  const w = WIN.gov;
  return g({}, sideScrim('govScrim', w.travel + 0.4, undefined, 760), W3.leftBlock({ x: 112, y: 300, eyebrow, title, body, t0: w.arrive - 0.3 }).markup);
}

function stage() {
  const glow = radialGradient('stageGlow', [
    [0, '#FFFFFF', 0.95],
    [0.6, '#FFFFFF', 0.35],
    [1, '#FFFFFF', 0],
  ]);
  const fog = radialGradient('stageFog', [
    [0.3, C.stage, 0],
    [0.98, C.stage, 1],
  ]);
  const bokehFill = radialGradient('bokeh', [
    [0, C.brand, 0.09],
    [0.55, C.brand, 0.035],
    [1, C.brand, 0],
  ]);
  const r = rng(11);
  const bokeh = [];
  for (let i = 0; i < 30; i++) bokeh.push(el('circle', { cx: fmt(-300 + r() * 5200), cy: fmt(-900 + r() * 2900), r: fmt(70 + r() * 150), fill: bokehFill }));
  addDef(el('pattern', { id: 'dotGrid', width: 34, height: 34, patternUnits: 'userSpaceOnUse' }, el('circle', { cx: 17, cy: 17, r: 1.15, fill: C.brand, 'fill-opacity': 0.2 })));
  return [
    el('rect', { width: 1920, height: 1080, fill: C.stage }),
    el('ellipse', { cx: 960, cy: 470, rx: 1100, ry: 620, fill: glow }),
    Wd.parallax(KEYS, 0.18, el('rect', { x: -3000, y: -3000, width: 7920, height: 7080, fill: 'url(#dotGrid)' })),
    Wd.parallax(KEYS, 0.5, g({}, bokeh)),
    el('rect', { width: 1920, height: 1080, fill: fog }),
    V.particles(34, 7, { t0: 0, t1: DURATION }),
  ];
}

function build() {
  ai.MODE.text = false;
  const aiT = {
    S0: A,
    intro: [A, A + 4.2],
    ...Object.fromEntries(ORDER.map((key) => [key, [WIN[key].t0, WIN[key].t1]])),
    gov: [WIN.dispute.t0 + 0.2, WIN.gov.t1],
    end: DURATION,
  };
  const ph = ai.phone(aiT);
  const P = ai.toScreen;
  const rowY = 59 + 8 + 30 + 20 + 44 + 20 + 76 + 28 + 12 + 55;
  const recIsl = ISLANDS.rec;
  const recDx = recIsl.x - recIsl.orig[0];
  const recDy = recIsl.y - recIsl.orig[1];
  const targets = (i) => {
    const scr = P(16 + i * 127 + 58, rowY);
    const w = Wd.unproject(KEYS, ph.rowsAt - 0.1, [scr.x, scr.y]);
    return { x: w.x - recDx, y: w.y - recDy };
  };
  const extra = { rowsAt: ph.rowsAt, targets, adv: ph.adv, sup: ph.sup };
  const nodes = ORDER.map((key) => node(ISLANDS[key]));
  const islands = ORDER.map((key) => islandContent(ISLANDS[key], extra));
  const GS = (2.2 * 0.45) / 0.7;
  const govVisual = g({ transform: `translate(${CORE.x} ${CORE.y}) scale(${fmt(GS)}) translate(${-1310} ${-520})` }, ai.governance([WIN.gov.t0, WIN.gov.t1], { core: false, lineStart: 160 }));

  const world = g(
    {},
    g({ display: 'none' }, during(0, A + 0.5), flow.worldContent(t)),
    g({ display: 'none' }, during(OUT - 0.5, DURATION), coreLayer(), nodes, islands, govVisual)
  );

  const flowPhone = g({ display: 'none' }, during(0, OUT + 0.6), motion({ t: [[OUT - 0.6, [0, 0]], [OUT + 0.4, [760, 80], 'in']], o: [[OUT - 0.1, 1], [OUT + 0.5, 0, 'lin']] }, flow.phone(t, { digitPop: false })));
  const layers = flowLayers();

  return {
    duration: DURATION,
    title: '救「舊」我的書｜介紹動畫樣片',
    body: [
      stage(),
      Wd.camera(KEYS, world),
      g({ display: 'none' }, during(0, OUT + 0.2), layers.under, flowCaptions()),
      flowPhone,
      g({ display: 'none' }, during(0, OUT + 0.2), layers.over),
      ph.markup,
      introCaption(),
      govCaption(),
      motion({ o: [[DURATION - 0.8, 1], [DURATION, 0, 'in']] }, V.brandBadge(56, 58, 0.3)),
    ],
  };
}

module.exports = { build, WIN, ISLANDS, KEYS };
