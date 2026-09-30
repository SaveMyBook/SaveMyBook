'use strict';

const { el, g, fmt, T, anim, motion, linearGradient, radialGradient, addDef, during, drawPath, penDot, nextId, blurFilter, rng, rrect } = require('../lib/core');
const { text, measure, riseLine, textClip } = require('../lib/text');
const { animatedLogo, staticLogo, BOX } = require('../lib/logo');
const { cabinet, doorRect, screenRect, platePos, lockupMetrics, PLATE, GEO, SCREEN_SCALE, xrayAnchors } = require('../lib/cabinet');
const { kioskScreen, qrMatrix, codeCenters, CODE } = require('../lib/kiosk');
const { curveTrack, rings } = require('../lib/fx');
const { iphone } = require('../lib/iphone');
const U = require('../lib/appui');
const V = require('../lib/ui2');
const W3 = require('../lib/ui3');
const Wd = require('../lib/world');
const SS = require('../lib/secscreens');
const { icon } = require('../lib/icons');
const C = require('../lib/palette');
const flow = require('./flow');
const ai = require('./ai');

const TY = W3.TY;
const DURATION = 177.0;
const QR = qrMatrix('NMIXX HAEWON 0225');

// ── 時間軸 ──────────────────────────────────────────────
const R0 = 12.2;
const SWAP = R0 + 7.0;
const FULL_AT = SWAP + 2.6;
const XR = [SWAP + 3.0, SWAP + 10.4];
const F = SWAP + 10.8;
const OUT = F + 24.0;
const A = OUT + 2.3;

const t = { ...flow.times(F), end: OUT, matchPhone: F + 6.35, matchKiosk: F + 6.45, digits: [F + 9.1, F + 9.1] };
t.steps = [F + 0.5, F + 6.7, F + 12.0, F + 18.9];
const LIFT = t.digits[0] - 0.95;

// ── 世界座標：書櫃、AI 核心與後段各站 ────────────────────
const CORE = { x: 4300, y: 560 };
const RX = 2000;
const RY = 1250;
const PHONE_C = [725, 640];
const WIDE_C = [960, 640];

const ISL_SPEC = [
  ['assist', [1085, 530], true, '上架輔助', 'wand', '依 ISBN 查詢書目與網路資料，附上建議售價區間與資料來源。', 8.4],
  ['review', [1310, 545], false, '上架審核', 'verified', '規則即時攔截售價異常，AI 再判讀照片，必要時交由管理員複核。', 7.0],
  ['enrich', [1320, 535], false, '資料補齊', 'doc', '上架後於背景依 ISBN 查詢書目，由 AI 整理成繁體中文簡介。', 5.6],
  ['rec', [1060, 540], true, '個人化推薦', 'star', '分析收藏與瀏覽紀錄，以語意向量找出相近書籍並寫下推薦理由。', 7.8],
  ['advisor', [1060, 530], true, 'AI 書籍顧問', 'sparkle', '理解分類、預算與書況條件，只推薦站內可購買的書籍。', 7.0],
  ['support', [1065, 530], true, 'AI 客服', 'headset', '以關鍵字與語意混合檢索作答，複雜問題一鍵轉接客服人員。', 5.8],
  ['dispute', [1300, 595], false, '爭議分析', 'gavel', '比對上架資料、照片與爭議說明，整理摘要與建議，僅供管理員參考。', 7.6],
];
const ISLANDS = {};
ISL_SPEC.forEach(([key, orig, phone, label, ic, body, beat], i) => {
  const th = ((-90 - 360 / 7 + (360 / 7) * i) * Math.PI) / 180;
  ISLANDS[key] = { key, i, orig, phone, label, icon: ic, body, beat, x: Math.round(CORE.x + RX * Math.cos(th)), y: Math.round(CORE.y + RY * Math.sin(th)) };
});
const ORDER = ISL_SPEC.map((s) => s[0]);
const frameC = (isl) => (isl.phone ? PHONE_C : WIDE_C);

const STATIONS = {
  escrow: { x: 8300, y: 560, phone: false, beat: 7.2, fly: 2.0, midK: 0.3 },
  pay: { x: 9700, y: 560, phone: true, beat: 7.0, fly: 1.3, midK: 0.5 },
  chat: { x: 11100, y: 560, phone: true, beat: 7.2, fly: 1.3, midK: 0.5 },
  arch: { x: 12700, y: 560, phone: false, beat: 8.8, fly: 1.5, midK: 0.45 },
  nums: { x: 14300, y: 560, phone: false, beat: 7.0, fly: 1.3, midK: 0.5 },
  fee: { x: 15900, y: 560, phone: false, beat: 8.2, fly: 1.3, midK: 0.5 },
};
const ST_ORDER = Object.keys(STATIONS);

function timeline() {
  const win = {};
  let travel = A + 4.6;
  for (const key of ORDER) {
    const arrive = travel + 1.3;
    const t0 = arrive - 0.6;
    const t1 = t0 + ISLANDS[key].beat;
    win[key] = { travel, arrive, t0, t1 };
    travel = t1 - 0.4;
  }
  win.gov = { travel, arrive: travel + 1.5, t0: travel + 0.9, t1: travel + 0.9 + 5.0 };
  travel = win.gov.t1 - 0.3;
  for (const key of ST_ORDER) {
    const st = STATIONS[key];
    const arrive = travel + st.fly;
    const t0 = arrive - 0.6;
    const t1 = t0 + st.beat;
    win[key] = { travel, arrive, t0, t1 };
    travel = t1 - 0.4;
  }
  return win;
}
const WIN = timeline();
const CLOSE = WIN.fee.t1 - 0.2;
const CARD = Math.max(CLOSE + 4.2, DURATION - 6.4);

function cameraKeys() {
  const plate = platePos();
  const keys = [
    { t: 0, k: 5, p: [plate.x - 60, plate.y - 16], c: [960, 540] },
    { t: SWAP, k: 5, p: [plate.x, plate.y], c: [960, 540], ease: 'soft' },
    { t: FULL_AT, k: 1, p: [1012, 491], c: [965, 525], ease: 'inout' },
    { t: XR[1], k: 1.05, p: [1012, 491], c: [985, 530], ease: 'soft' },
    { t: F + 0.9, k: 1.9, p: [980, 299], c: [760, 680], ease: 'inout' },
    { t: F + 6.6, k: 1.97, p: [982, 298], c: [760, 680], ease: 'soft' },
    { t: F + 7.5, k: 2.15, p: [980, 292], c: [760, 690], ease: 'inout' },
    { t: F + 11.6, k: 2.2, p: [979, 292], c: [760, 690], ease: 'soft' },
    { t: F + 12.8, k: 1.6, p: [885, 548], c: [740, 660], ease: 'inout' },
    { t: F + 17.9, k: 1.66, p: [888, 546], c: [740, 660], ease: 'soft' },
    { t: F + 19.4, k: 0.88, p: [1016, 474], c: [1060, 670], ease: 'inout' },
    { t: OUT - 0.3, k: 0.9, p: [1018, 476], c: [1060, 670], ease: 'soft' },
    { t: OUT + 1.1, k: 0.27, p: [2650, 480], c: [960, 540], r: -1.5, ease: 'in' },
    { t: A, k: 0.62, p: [CORE.x, CORE.y], c: [1240, 560], r: -0.4, ease: 'out' },
    { t: A + 2.5, k: 0.66, p: [CORE.x, CORE.y], c: [1240, 560], r: 0, ease: 'soft' },
    { t: A + 3.6, k: 0.33, p: [CORE.x, CORE.y + 63], c: [960, 560], r: 0, ease: 'inout' },
    { t: A + 4.6, k: 0.345, p: [CORE.x, CORE.y + 63], c: [960, 560], r: 0.8, ease: 'soft' },
  ];
  let prev = { x: CORE.x, y: CORE.y + 63 };
  const hop = (w, target, fc, midK, rot) => {
    const last = keys[keys.length - 1];
    if (w.travel > last.t + 0.05) keys.push({ ...last, t: w.travel, k: last.k * 1.02, ease: 'soft' });
    const flyDur = w.arrive - w.travel;
    keys.push({ t: w.travel + flyDur * 0.5, k: midK, p: [(prev.x + target.x) / 2, (prev.y + target.y) / 2], c: [960, 560], r: rot, ease: 'in' });
    keys.push({ t: w.arrive, k: 1, p: [target.x, target.y], c: fc, r: 0, ease: 'out' });
    prev = target;
  };
  for (const key of ORDER) hop(WIN[key], ISLANDS[key], frameC(ISLANDS[key]), 0.5, prev.x < ISLANDS[key].x ? 1.4 : -1.4);
  const gw = WIN.gov;
  let last = keys[keys.length - 1];
  keys.push({ ...last, t: gw.travel, k: last.k * 1.02, ease: 'soft' });
  keys.push({ t: gw.travel + 0.75, k: 0.45, p: [(prev.x + CORE.x) / 2, (prev.y + CORE.y) / 2], c: [960, 560], r: 1.2, ease: 'in' });
  keys.push({ t: gw.arrive, k: 0.7, p: [CORE.x, CORE.y + 30], c: [1260, 540], r: 0, ease: 'out' });
  prev = { x: CORE.x, y: CORE.y + 30 };
  for (const key of ST_ORDER) {
    const st = STATIONS[key];
    hop(WIN[key], st, st.phone ? PHONE_C : WIDE_C, st.midK, key === 'escrow' ? -1.2 : 0.8);
  }
  last = keys[keys.length - 1];
  keys.push({ ...last, t: CLOSE, k: 1.02, ease: 'soft' });
  keys.push({ t: CARD, k: 0.72, p: [prev.x, prev.y], c: [960, 560], r: 0, ease: 'inout' });
  keys.push({ t: DURATION, k: 0.7, p: [prev.x, prev.y], c: [960, 560], r: 0, ease: 'soft' });
  return keys;
}
const KEYS = cameraKeys();

// ── 共用 ────────────────────────────────────────────────
function odometer(str, { x, y, size, weight = 200, fill = C.text, t0, dur = 1.3, anchor = 'middle', tOut }) {
  const chars = [...str];
  const widths = chars.map((ch) => measure(ch, size, { weight }));
  const total = widths.reduce((a, b) => a + b, 0);
  let cx = anchor === 'middle' ? x - total / 2 : anchor === 'end' ? x - total : x;
  const lh = size * 1.15;
  const digits = chars.filter((c) => /\d/.test(c)).length;
  let di = 0;
  const parts = chars.map((ch, i) => {
    const w = widths[i];
    const left = cx;
    cx += w;
    if (!/\d/.test(ch)) return motion({ o: [[t0 + 0.25, 0], [t0 + 0.7, 1, 'out']] }, text(ch, { x: left, y, size, weight, fill }));
    const d = Number(ch);
    const steps = 10 + d;
    const strip = [];
    for (let k = 0; k <= steps; k++) strip.push(text(String(k % 10), { x: left + w / 2, y: y + k * lh, size, weight, fill, anchor: 'middle' }));
    const id = nextId('od');
    addDef(el('clipPath', { id }, el('rect', { x: fmt(left - 6), y: fmt(y - size * 0.98), width: fmt(w + 12), height: fmt(size * 1.28) })));
    const end = t0 + dur + (digits - 1 - di++) * 0.1;
    return g({ 'clip-path': `url(#${id})` }, motion({ t: [[t0, [0, 0]], [end, [0, -steps * lh], 'emph']] }, strip));
  });
  const o = [[t0, 0], [t0 + 0.2, 1, 'out']];
  const tr = [];
  if (tOut !== undefined) {
    o.push([tOut, 1, 'lin'], [tOut + 0.4, 0, 'in']);
    tr.push([tOut, [0, 0]], [tOut + 0.45, [0, -36], 'in']);
  }
  return motion(tr.length ? { o, t: tr } : { o }, parts);
}

function centerTitle(str, { y, t0, t1, size = TY.title }) {
  const w = measure(str, size, { weight: 800, punct: 'tight' });
  return W3.maskedLine(str, { x: 960 - w / 2, y, size, weight: 800, t0, t1 });
}

function fadeText(str, opts, t0, t1, dy = 12) {
  return motion(W3.fadeRise(t0, t1, { dy }), text(str, opts));
}

function worldCaption(st, fc, spec, t0, t1) {
  return Wd.caption({ x: st.x + (112 - fc[0]), y: st.y + (226 - fc[1]), eyebrow: spec[0], title: spec[1], body: spec[2], t0, t1 });
}

// 以進站時的畫面座標繪製，再平移到世界座標。
function atStation(st, fc, content) {
  return g({ transform: `translate(${fmt(st.x - fc[0])} ${fmt(st.y - fc[1])})` }, content);
}

function card(x, y, w, h, r = 22) {
  return W3.card(x, y, w, h, { r });
}

function iconDisc(cx, cy, r, name, { fill = C.brand, bg = C.brand, bgOpacity = 0.12 } = {}) {
  return [el('circle', { cx, cy, r, fill: bg, 'fill-opacity': bgOpacity }), icon(name, cx - r * 0.55, cy - r * 0.55, r * 1.1, fill)];
}

// ── 1. 開場：問卷數據 ────────────────────────────────────
function opening() {
  const out = [];
  const Y = { head: 290, icon: 390, label: 490, num: 680, line: 760, note: 1010 };
  out.push(centerTitle('二手書交易，難在哪裡？', { y: 520, t0: 0.6, t1: 2.95 }));
  out.push(fadeText('本專題回收 498 份有效問卷，整理出使用者真正的困擾。', { x: 960, y: 604, size: TY.body, weight: 500, fill: W3.BODY_FILL, anchor: 'middle' }, 1.1, 2.9));

  const icons = (name, x, t0, t1) => motion({ o: [[t0, 0], [t0 + 0.4, 1, 'out'], [t1, 1, 'lin'], [t1 + 0.35, 0, 'in']], s: [[t0, 0.7], [t0 + 0.7, 1, 'emph']], origin: [x, Y.icon] }, iconDisc(x, Y.icon, 40, name));
  const scene = (t0, t1, head, items) => {
    out.push(fadeText(head, { x: 960, y: Y.head, size: TY.body, weight: 700, fill: C.text, anchor: 'middle' }, t0, t1, 10));
    items.forEach(([label, num, line, ic], i) => {
      const x = i === 0 ? 620 : 1300;
      const ti = t0 + 0.15 + i * 0.15;
      out.push(icons(ic, x, ti, t1));
      out.push(fadeText(label, { x, y: Y.label, size: TY.eyebrow, weight: 700, fill: C.brand, anchor: 'middle', ls: 0.12 }, ti, t1, 10));
      out.push(odometer(num, { x, y: Y.num, size: 180, t0: ti + 0.15, dur: 1.2, tOut: t1 }));
      out.push(fadeText(line, { x, y: Y.line, size: TY.body, weight: 500, fill: W3.BODY_FILL, anchor: 'middle' }, ti + 0.6, t1));
    });
  };
  scene(3.25, 6.4, '受訪者對兩種交易方式最大的困擾', [
    ['面交', '43.2%', '擔心對方失約或遭遇詐騙', 'gppMaybe'],
    ['寄送', '57.9%', '須自行包裝並至超商寄件', 'shipping'],
  ]);
  scene(6.75, 9.8, '受訪者期待的解決方式', [
    ['交易方式', '51.4%', '傾向使用實體儲物櫃', 'storage'],
    ['書櫃功能', '57.4%', '最看重 24 小時自助存取', 'clock'],
  ]);
  out.push(fadeText('資料來源：本專題「二手書籍交易行為與市場需求調查」，498 份有效問卷。', { x: 960, y: Y.note, size: TY.meta, fill: C.muted, anchor: 'middle' }, 3.4, 9.8, 6));
  out.push(centerTitle('二手書交易，需要更好的方式。', { y: 566, t0: 10.1, t1: 11.9 }));
  return g({ display: 'none' }, during(0, R0 + 0.4), motion({ s: [[0, 1], [R0, 1.035, 'soft']], origin: [960, 560] }, out));
}

// ── 2. 揭幕：Logo 化為書櫃銘牌 ────────────────────────────
function reveal() {
  const K0 = 5;
  const s = 430 / BOX.w;
  const m = lockupMetrics(PLATE.size * K0);
  const left = 960 - m.width / 2;
  const logoTarget = [left + m.logoW / 2, 540];
  const logoScale = m.logoH / (1258 * s);
  const r = (d) => R0 + d;
  const bloom = radialGradient('logoBloom', [
    [0, C.brand, 0.22],
    [0.5, C.brand, 0.08],
    [1, C.brand, 0],
  ]);
  const glow = el('ellipse', { cx: 960, cy: 470, rx: 520, ry: 420, fill: bloom, opacity: 0 }, anim('opacity', [[r(0.4), 0], [r(2.4), 1, 'out'], [r(3.4), 0.55, 'soft'], [r(5.9), 0.55, 'lin'], [r(6.6), 0, 'in']]));
  const logo = motion(
    {
      x: 960,
      y: 470,
      t: [[r(2.75), [0, 0]], [r(3.75), [0, -92], 'emph'], [r(5.9), [0, -92], 'lin'], ...curveTrack(r(5.9), r(7.0), [0, -92], [logoTarget[0] - 960 - 120, -92], [logoTarget[0] - 960, logoTarget[1] - 470])],
      s: [[r(0.35), 0.94], [r(2.7), 1, 'out'], [r(2.75), 1, 'lin'], [r(3.75), 0.78, 'emph'], [r(5.9), 0.78, 'lin'], [r(7.0), logoScale, 'inout']],
    },
    g({ transform: `scale(${fmt(s)}) translate(${-BOX.cx} ${-BOX.cy})` }, animatedLogo(r(0.35), { pen: true }))
  );
  const wordSize = 112;
  const wordY = 664;
  const wordCenterY = wordY - wordSize * 0.38;
  const targetSize = PLATE.size * K0;
  const targetCx = left + m.logoW + m.gap + m.textW / 2;
  const clip = textClip(nextId('wc'), '救「舊」我的書', { x: 960, y: wordY, size: wordSize, weight: 700, anchor: 'middle' });
  const sheenGrad = linearGradient('wordSheen', [
    [0, '#FFFFFF', 0],
    [0.5, '#FFFFFF', 0.75],
    [1, '#FFFFFF', 0],
  ], { x1: 0, y1: 0, x2: 1, y2: 0 });
  const sheen = g({ 'clip-path': clip.url }, el('rect', { x: clip.left - 260, y: wordY - wordSize, width: 180, height: wordSize * 1.3, fill: sheenGrad, transform: 'skewX(-18)' }, anim('x', [[r(4.35), clip.left - 260], [r(5.25), clip.left + clip.width + 260, 'inout']])));
  const wordmark = motion(
    { t: [[r(5.9), [0, 0]], [r(7.0), [targetCx - 960, 540 - wordCenterY], 'inout']], s: [[r(5.9), 1], [r(7.0), targetSize / wordSize, 'inout']], origin: [960, wordCenterY] },
    riseLine('救「舊」我的書', { x: 960, y: wordY, size: wordSize, weight: 700, anchor: 'middle', t0: r(3.0), stagger: 0.05, dur: 0.9, rise: 1.05, fill: C.text, charFill: (n) => (n >= 1 && n <= 3 ? C.brand : undefined) }),
    sheen
  );
  const tagline = motion(
    { o: [[r(3.9), 0], [r(4.6), 1, 'out'], [r(5.5), 1, 'lin'], [r(5.9), 0, 'in']], t: [[r(3.9), [0, 16]], [r(4.8), [0, 0], 'emph'], [r(5.5), [0, 0], 'lin'], [r(5.9), [0, 10], 'in']] },
    text('結合智慧書櫃的二手書交易平台', { x: 960, y: 752, size: 36, weight: 500, fill: C.muted, anchor: 'middle', ls: 0.04 })
  );
  const labels = ['掃碼存取', '款項暫管', 'AI 輔助'];
  const pills = labels.map((label) => W3.pill(0, 0, label, { size: TY.callout, weight: 700 }));
  const gap = 18;
  const total = pills.reduce((a, p) => a + p.w, 0) + gap * (pills.length - 1);
  let px = 960 - total / 2;
  const chips = labels.map((label, i) => {
    const x = px;
    px += pills[i].w + gap;
    const t0 = r(4.35 + i * 0.1);
    return W3.pill(x, 838, label, { size: TY.callout, weight: 700, t0, t1: r(5.45 + i * 0.03) }).markup;
  });
  return g({ display: 'none' }, during(R0, SWAP), glow, motion({ s: [[r(4.7), 1], [r(5.9), 1.012, 'soft'], [r(7.0), 1, 'inout']], origin: [960, 540] }, logo, wordmark, tagline, chips));
}

function guides() {
  const t0 = SWAP + 0.45;
  const { fx, fy, w, h, dx, dy } = GEO;
  const L = [
    [`M${fx - 260} ${fy}H${fx + w + dx + 260}`, 0],
    [`M${fx - 260} ${fy + h}H${fx + w + dx + 260}`, 0.08],
    [`M${fx} ${fy + dy - 160}V${fy + h + 160}`, 0.12],
    [`M${fx + w} ${fy + dy - 160}V${fy + h + 160}`, 0.18],
    [`M${fx + dx - 120} ${fy + dy}H${fx + w + dx + 200}`, 0.24],
    [`M${fx + w + dx} ${fy + dy - 120}V${fy + h + dy + 140}`, 0.3],
  ];
  const ticks = [
    [fx, fy],
    [fx + w, fy],
    [fx, fy + h],
    [fx + w, fy + h],
    [fx + w + dx, fy + dy],
  ].map(([x, y], i) => el('path', { d: `M${x - 9} ${y}H${x + 9}M${x} ${y - 9}V${y + 9}`, stroke: C.brand, 'stroke-width': 1.6, opacity: 0 }, anim('opacity', [[t0 + 0.5 + i * 0.05, 0], [t0 + 0.7 + i * 0.05, 0.8, 'out']])));
  return g({}, anim('opacity', [[SWAP + 2.2, 1], [SWAP + 2.9, 0, 'soft']]), L.map(([d, dt]) => drawPath(d, t0 + dt, 0.9, { stroke: C.brand, width: 1, attrs: { 'stroke-opacity': 0.4 } })), ticks);
}

// ── 3. 書櫃透視 ─────────────────────────────────────────
function xrayOverlay() {
  const out = [];
  out.push(W3.leftBlock({ x: 112, y: 330, eyebrow: '智慧書櫃', title: ['一片 ESP32，', '控制四扇櫃門'], body: ['以 HTTPS 定時與伺服器同步，', '接收開鎖指令並回報開關門。'], t0: XR[0] + 0.2, t1: XR[1] - 0.6 }).markup);
  const a = xrayAnchors();
  const at = (w) => Wd.project(KEYS, XR[0] + 1.2, [w.x, w.y]);
  const tIn = (i) => XR[0] + 0.9 + i * 0.22;
  const callouts = [
    [at(a.esp), 'ESP32 控制板', 'Wi-Fi 連線・HTTPS 同步', 1, 1330, 262],
    [at(a.screen), '2.4 吋 TFT 螢幕', '240 × 320，顯示 QR Code 與數字', 1, 1330, 392],
    [at(a.lock), '電磁鎖 ×4', 'A01–A04，逐一開鎖', 1, 1330, 622],
    [at(a.psu), '12V 電源', '降壓 5V 供應控制板', 1, 1330, 846],
    [at(a.relay), '四路繼電器', '驅動電磁鎖', -1, 690, 214],
  ];
  out.push(callouts.map(([anchor, label, sub, side, lx, ly], i) => V.callout(anchor, label, sub, { tIn: tIn(i), tOut: XR[1] - 0.7, side, labelX: lx, labelY: ly })));
  return g({ display: 'none' }, during(XR[0], XR[1] + 0.2), out);
}

// ── 4. 存書流程 ─────────────────────────────────────────
function kioskStates() {
  return [
    { kind: 'idle', t0: SWAP + 1.8, t1: t.confirm, matrix: QR, ratio: [[SWAP + 1.8, 0.95], [t.confirm, 0.45, 'lin']], reveal: [SWAP + 1.95, SWAP + 2.45], pulse: t.detect + 0.55, fade: { fadeIn: 0.05 } },
    { kind: 'select', t0: t.confirm, t1: t.matchKiosk },
    { kind: 'match', t0: t.matchKiosk, t1: t.opening, code: '25', seconds: 60, codeIn: t.matchKiosk + 0.02, codeHide: [LIFT, t.digits[1] + 0.1] },
    { kind: 'opening', t0: t.opening, t1: t.open },
    { kind: 'open', t0: t.open, t1: t.kioskDone, label: 'A01', message: '請將書籍放入 A01 後關上櫃門', total: 30 },
    { kind: 'result', t0: t.kioskDone, t1: undefined, message: '作業完成' },
  ];
}

function bookInsertion(r, [tA, tC, tB]) {
  const { DEPTH } = require('../lib/cabinet');
  const bw = 70;
  const bh = 98;
  const px = r.x + 0.42 * r.w;
  const py = r.y + r.h - 4 - bh;
  const dx = GEO.dx * DEPTH * 0.55;
  const dy = GEO.dy * DEPTH * 0.55;
  const book = [el('ellipse', { cx: px + bw / 2 + 4, cy: py + bh + 1, rx: bw * 0.62, ry: 5, fill: '#0B1A26', 'fill-opacity': 0.16 }), U.bookCover(px, py, bw, bh, 3, { color: '#4F7A63', accent: '#E7D9B8' })];
  const outside = g({ display: 'none' }, during(tA, tC), motion({ t: [[tA, [110, 200]], [tC, [0, 0], 'emph']], s: [[tA, 1.3], [tC, 1, 'emph']], o: [[tA, 0], [tA + 0.18, 1, 'out']], origin: [px + bw / 2, py + bh] }, book));
  const inside = g({ display: 'none' }, el('set', { attributeName: 'display', to: 'inline', begin: T(tC), fill: 'freeze' }), motion({ t: [[tC, [0, 0]], [tB, [dx, dy], 'out']], s: [[tC, 1], [tB, 0.92, 'out']], origin: [px + bw / 2, py + bh] }, book));
  return { outside, inside };
}

function cabinetWorld() {
  const insert = bookInsertion(doorRect(0), t.book);
  const cab = cabinet({
    build: SWAP + 0.35,
    screen: kioskScreen(kioskStates(), { powerOn: SWAP + 1.8 }),
    xray: XR,
    doors: [
      { open: t.door, lock: [t.open, t.door.close[1] + 0.8], inside: insert.inside, front: insert.outside },
      { books: [{ color: '#A45F4B', accent: '#F1E3C8', at: 0.38 }] },
      { books: [{ color: '#3E6A9E', accent: '#E9EEF1', at: 0.3 }] },
      { books: [{ color: '#75689C', accent: '#EDE7F6', at: 0.46, h: 92 }] },
    ],
  });
  return g({}, guides(), cab.markup);
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
  const kioskSide = (tt) => proj(tt, [sr.x + sr.w + 14, sr.y + sr.h * 0.42]);
  const phoneEdge = (y) => toScreen(-6, y);
  const dr = doorRect(0);
  const doorSide = proj(t.door.close[1], [dr.x + dr.w, dr.y + dr.h / 2]);

  const centers = codeCenters('25');
  const tl = proj(LIFT, [sr.x - 4, sr.y - 4]);
  const br = proj(LIFT, [sr.x + sr.w + 4, sr.y + sr.h + 4]);
  const exitRect = { x: tl.x, y: tl.y, w: br.x - tl.x, h: br.y - tl.y };
  const boxes = [167, 235];
  const digits = centers.map((c, i) => {
    const a = proj(LIFT, [sr.x + c.x * SCREEN_SCALE, sr.y + c.y * SCREEN_SCALE]);
    const b = toScreen(boxes[i], 408 - (0.38 - 0.357) * 28);
    const from = { x: a.x, y: a.y, size: CODE.size * SCREEN_SCALE * a.k };
    const to = { x: b.x, y: b.y, size: 28 * P.s };
    return Wd.flyDigit(c.ch, { from, to, p1: { x: from.x + 300, y: from.y - 30 }, p2: { x: to.x - 250, y: to.y - 150 }, t0: LIFT, t1: t.digits[i], exitRect, light: C.kiosk.text }).markup;
  });

  const scanCenter = toScreen(U.W / 2, 458.6);
  const qr = kioskTop(t.detect);
  const loc = kioskTop(t.digits[1] + 0.25);
  const lock = proj(F + 13.0, [dr.x + 30, dr.y - 34]);
  const under = g(
    {},
    W3.pill(qr.x, qr.y, 'QR Code 驗證成功', { iconName: 'checkCircle', iconColor: C.success, anchor: 'middle', size: TY.callout, t0: t.detect + 0.3, t1: t.confirm + 1.4 }).markup,
    W3.pill(loc.x, loc.y, '定位確認：書櫃 200 公尺內', { iconName: 'location', anchor: 'middle', size: TY.callout, t0: t.digits[1] + 0.25, t1: t.okTap + 0.5 }).markup,
    W3.pill(lock.x, lock.y, 'A01 已開鎖', { iconName: 'lockOpen', iconColor: C.success, anchor: 'end', size: TY.callout, t0: t.door.unlatch + 0.1, t1: t.door.close[0] }).markup
  );
  const over = g(
    {},
    rings(scanCenter.x, scanCenter.y, t.detect + 0.02, { color: C.brand, r0: 70, r1: 260, peak: 0.45, width: 2.5 }),
    Wd.link(phoneEdge(752), kioskSide(t.openTap + 0.8), t.openTap + 0.1, 0.7),
    digits,
    Wd.link(phoneEdge(752), kioskSide(t.okTap + 0.42), t.okTap + 0.08, 0.34),
    Wd.link(doorSide, phoneEdge(437), t.door.close[1] + 0.05, 0.5)
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
  out.push(motion(W3.fadeRise(F + 0.3, OUT - 0.5, { dy: 8 }), text('存書流程', { x: 112, y: 128, size: TY.eyebrow, weight: 700, fill: C.brand, ls: 0.12 })));
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

// ── 5. AI ───────────────────────────────────────────────
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
  return g(
    {},
    beams,
    rings(CORE.x, CORE.y, A - 0.7, { color: C.brand, r0: 220, r1: 760, width: 6, peak: 0.5 }),
    rings(CORE.x, CORE.y, WIN.gov.arrive - 0.3, { color: C.brand, r0: 220, r1: 760, width: 6, peak: 0.5 }),
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
    anim('opacity', [[tIn + 0.35, 0], [tIn + 0.65, 1, 'out'], [A + 4.9, 1, 'lin'], [A + 5.3, 0, 'in']]),
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
  const visual = {
    assist: () => ai.assist(win),
    review: () => ai.review(win),
    enrich: () => ai.enrich(win),
    rec: () => ai.recommend(win, extra.rowsAt, { targets: extra.targets }),
    advisor: () => ai.advisorVisual(win, extra.adv),
    support: () => ai.supportVisual(win, extra.sup),
    dispute: () => ai.disputeVisual(win),
  }[isl.key]();
  const [cx, cy] = frameC(isl);
  const [eyebrow, title] = ai.COPY[isl.key];
  const block = Wd.caption({ x: isl.x + (112 - cx), y: isl.y + (226 - cy), eyebrow, title: title.join(''), body: [isl.body], t0: w.t0 + 0.4, t1: w.t1 - 0.5 });
  const content = motion(
    { s: [[w.t0 - 0.1, 0.92], [w.t0 + 0.8, 1, 'out'], [w.t1 - 0.4, 1, 'lin'], [w.t1 + 0.3, 0.9, 'in']], origin: [isl.x, isl.y] },
    g({ transform: `translate(${fmt(isl.x - ox)} ${fmt(isl.y - oy)})` }, visual)
  );
  return [content, block];
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
  const t1 = A + 2.4;
  return g({ display: 'none' }, during(t0 - 0.5, t1 + 1.0), sideScrim('introScrim', t0 - 0.4, t1 - 0.25), W3.leftBlock({ x: 112, y: 330, eyebrow, title, body, t0, t1 }).markup);
}

function govCaption() {
  const [eyebrow, title, body] = ai.COPY.gov;
  const w = WIN.gov;
  return g({ display: 'none' }, during(w.travel, w.t1 + 1.2), sideScrim('govScrim', w.travel + 0.4, w.t1 - 0.2, 760), W3.leftBlock({ x: 112, y: 300, eyebrow, title, body, t0: w.arrive - 0.3, t1: w.t1 - 0.3 }).markup);
}

// ── 6. 交易安全 ─────────────────────────────────────────
function escrowVisual(t0, t1) {
  const fadeOut = [[t1 - 0.6, 1], [t1 - 0.2, 0, 'in']];
  const nodes = [
    { x: 520, label: '買家', sub: '結帳付款', ic: 'person' },
    { x: 960, label: '平台暫管', sub: '款項保管中', ic: 'shield' },
    { x: 1400, label: '賣家錢包', sub: '撥款入帳', ic: 'wallet' },
  ];
  const ny = 520;
  const nodeEls = nodes.map((n, i) => {
    const tIn = t0 + 0.3 + i * 0.15;
    return motion(
      { o: [[tIn, 0], [tIn + 0.35, 1, 'out'], ...fadeOut], s: [[tIn, 0.8], [tIn + 0.6, 1, 'emph']], origin: [n.x, ny] },
      el('circle', { cx: n.x + 6, cy: ny + 14, r: 70, fill: '#0B1A26', 'fill-opacity': 0.1, filter: blurFilter(nextId('eb'), 16) }),
      el('circle', { cx: n.x, cy: ny, r: 70, fill: '#FFFFFF', stroke: C.border, 'stroke-width': 1.5 }),
      icon(n.ic, n.x - 30, ny - 30, 60, C.brand),
      text(n.label, { x: n.x, y: ny + 122, size: TY.callout, weight: 700, fill: C.text, anchor: 'middle' }),
      text(n.sub, { x: n.x, y: ny + 156, size: TY.meta, fill: C.muted, anchor: 'middle' })
    );
  });
  const links = [0, 1].map((i) => g({}, anim('opacity', fadeOut), drawPath(`M${nodes[i].x + 86} ${ny}H${nodes[i + 1].x - 86}`, t0 + 0.7 + i * 0.1, 0.4, { stroke: C.brand, width: 2.5, attrs: { 'stroke-dasharray': '2 10', 'stroke-opacity': 0.6 } })));
  const pay = t0 + 1.3;
  const release = t0 + 4.9;
  const coinPath1 = `M${nodes[0].x} ${ny - 96}Q${(nodes[0].x + nodes[1].x) / 2} ${ny - 190} ${nodes[1].x} ${ny - 96}`;
  const coinPath2 = `M${nodes[1].x} ${ny - 96}Q${(nodes[1].x + nodes[2].x) / 2} ${ny - 190} ${nodes[2].x} ${ny - 96}`;
  const coinFace = [el('circle', { r: 36, fill: C.brand }), el('circle', { r: 30, fill: 'none', stroke: '#FFFFFF', 'stroke-opacity': 0.45, 'stroke-width': 2 }), text('280', { x: 0, y: 7.5, size: 21, weight: 800, fill: '#FFFFFF', anchor: 'middle' })];
  const coin = g(
    { opacity: 0 },
    anim('opacity', [[pay - 0.3, 0], [pay, 1, 'out'], ...fadeOut]),
    g({ transform: `translate(${nodes[0].x} ${ny - 96})` }),
    el('g', {}, el('animateMotion', { path: coinPath1, begin: T(pay), dur: '0.8s', fill: 'freeze', calcMode: 'spline', keyPoints: '0;1', keyTimes: '0;1', keySplines: '0.65 0 0.35 1' }), g({ opacity: 1 }, anim('opacity', [[release - 0.01, 1], [release, 0, 'lin']]), coinFace)),
    el('g', { opacity: 0 }, anim('opacity', [[release - 0.01, 0], [release, 1, 'lin']]), el('animateMotion', { path: coinPath2, begin: T(release), dur: '0.8s', fill: 'freeze', calcMode: 'spline', keyPoints: '0;1', keyTimes: '0;1', keySplines: '0.65 0 0.35 1' }), coinFace)
  );
  const hold = el('circle', { cx: nodes[1].x, cy: ny, r: 82, fill: 'none', stroke: C.brand, 'stroke-width': 3, opacity: 0 }, anim('opacity', [[pay + 0.8, 0], [pay + 1.0, 0.6, 'out'], [release, 0.6, 'lin'], [release + 0.2, 0, 'out']]), el('animate', { attributeName: 'r', values: '80;90;80', dur: '1.4s', begin: T(pay + 0.8), repeatCount: 'indefinite' }));
  const plus = W3.pill(nodes[2].x, ny - 190, '+280 代幣', { anchor: 'middle', size: TY.callout, weight: 700, color: C.success, iconName: 'checkCircle', iconColor: C.success, t0: release + 0.8, t1: t1 - 0.6 });
  const steps = [
    ['付款', ''],
    ['賣家存書', ''],
    ['買家取書', ''],
    ['完成訂單', '或取書滿 24 小時'],
    ['撥款', ''],
  ];
  const sx0 = 480;
  const gapX = 240;
  const sy = 810;
  const stepAt = [pay + 0.2, pay + 1.0, pay + 1.8, pay + 2.8, release + 0.4];
  const stepEls = steps.map(([label, sub], i) => {
    const x = sx0 + i * gapX;
    const on = stepAt[i];
    return [
      i < steps.length - 1 ? g({}, el('line', { x1: x + 14, y1: sy, x2: x + gapX - 14, y2: sy, stroke: C.border, 'stroke-width': 3 }), el('line', { x1: x + 14, y1: sy, x2: x + 14, y2: sy, stroke: C.brand, 'stroke-width': 3 }, anim('x2', [[on, x + 14], [stepAt[i + 1], x + gapX - 14, 'inout']]))) : '',
      el('circle', { cx: x, cy: sy, r: 12, fill: '#FFFFFF', stroke: C.border, 'stroke-width': 3 }),
      motion({ o: [[on, 0], [on + 0.15, 1, 'out']], s: [[on, 0.3], [on + 0.4, 1, 'emph']], origin: [x, sy] }, el('circle', { cx: x, cy: sy, r: 12, fill: C.brand })),
      text(label, { x, y: sy + 50, size: TY.card, weight: 700, fill: C.text, anchor: 'middle' }),
      sub ? text(sub, { x, y: sy + 82, size: TY.meta, fill: C.muted, anchor: 'middle' }) : '',
    ];
  });
  const timelineGroup = motion({ o: [[t0 + 0.6, 0], [t0 + 1.0, 1, 'out'], ...fadeOut] }, stepEls);
  return g({ display: 'none' }, during(t0, t1 + 0.2), links, nodeEls, hold, coin, plus.markup, timelineGroup);
}

function methodsVisual(t0, t1, tm) {
  const fadeOut = [[t1 - 0.6, 1], [t1 - 0.2, 0, 'in']];
  const rows = [
    ['lock', '交易密碼', '結帳時輸入 6 位數字'],
    ['fingerprint', '生物辨識付款', '辨識失敗時改用交易密碼'],
    ['key', '通行密鑰登入', '海嫄的 iPhone・免輸入密碼'],
  ];
  const x = 250;
  const w = 600;
  return g(
    { display: 'none' },
    during(t0, t1 + 0.2),
    rows.map(([ic, label, sub], i) => {
      const y = 372 + i * 150;
      const tIn = t0 + 0.4 + i * 0.15;
      const active = i === 0 ? rrect(x, y, w, 120, 24, { fill: 'none', stroke: C.brand, 'stroke-width': 3, opacity: 0 }, anim('opacity', [[tm.sheet + 0.2, 0], [tm.sheet + 0.45, 1, 'out'], [tm.done, 1, 'lin'], [tm.done + 0.3, 0, 'out']])) : '';
      return motion(
        { o: [[tIn, 0], [tIn + 0.35, 1, 'out'], ...fadeOut], t: [[tIn, [0, 18]], [tIn + 0.7, [0, 0], 'emph']] },
        card(x, y, w, 120, 24),
        iconDisc(x + 66, y + 60, 34, ic),
        text(label, { x: x + 124, y: y + 52, size: TY.callout, weight: 700, fill: C.text }),
        text(sub, { x: x + 124, y: y + 88, size: TY.meta, fill: C.muted }),
        active
      );
    }),
    W3.pill(x, 850, '付款成功，書籍已在書櫃', { iconName: 'checkCircle', iconColor: C.success, color: C.success, weight: 700, size: TY.callout, t0: tm.success + 0.3, t1: t1 - 0.6 }).markup
  );
}

function riskVisual(t0, t1, tm) {
  const fadeOut = [[t1 - 0.6, 1], [t1 - 0.2, 0, 'in']];
  const x = 230;
  const w = 640;
  const cats = ['聯絡方式', '付款資訊', '平台外交易', '可疑連結', '索取驗證資料', '詐騙話術'];
  const hit = [0, 1, 2];
  const chipEls = cats.map((label, i) => {
    const col = i % 3;
    const row = Math.floor(i / 3);
    const cw = 186;
    const cxp = x + 32 + col * (cw + 12);
    const cy = 468 + row * 62;
    const on = hit.includes(i);
    const tHit = tm.m3 + 0.35 + hit.indexOf(i) * 0.12;
    const base = text(label, { x: cxp + cw / 2, y: cy + 8, size: TY.meta, weight: 600, fill: C.text, anchor: 'middle' });
    return [
      rrect(cxp, cy - 22, cw, 44, 22, { fill: '#FFFFFF', stroke: C.border, 'stroke-width': 1.5 }),
      on ? motion({ o: [[tHit, 1], [tHit + 0.2, 0, 'out']] }, base) : base,
      on
        ? motion({ o: [[tHit, 0], [tHit + 0.2, 1, 'out']] }, rrect(cxp, cy - 22, cw, 44, 22, { fill: C.danger, 'fill-opacity': 0.1, stroke: C.danger, 'stroke-width': 2 }), text(label, { x: cxp + cw / 2, y: cy + 8, size: TY.meta, weight: 700, fill: C.danger, anchor: 'middle' }))
        : '',
    ];
  });
  const flowRows = [
    ['gppMaybe', '收訊方看到防詐提醒', tm.note],
    ['chat', '聊天室顯示高風險橫幅', tm.banner],
    ['person', '24 小時內 3 則高風險訊息，通知管理員', tm.banner + 0.6],
  ];
  const flowEls = flowRows.map(([ic, label, tt], i) => {
    const y = 700 + i * 64;
    return motion({ o: [[tt, 0], [tt + 0.3, 1, 'out'], ...fadeOut], t: [[tt, [0, 12]], [tt + 0.6, [0, 0], 'emph']] }, iconDisc(x + 26, y - 8, 22, ic, { fill: C.danger, bg: C.danger, bgOpacity: 0.1 }), text(label, { x: x + 64, y: y, size: TY.card, weight: 600, fill: C.text }));
  });
  const scan = el('rect', { x: x + 20, y: 440, width: 0, height: 4, rx: 2, fill: C.danger, opacity: 0 }, anim('width', [[tm.m3 + 0.05, 0], [tm.m3 + 0.6, w - 40, 'inout']]), anim('opacity', [[tm.m3 + 0.05, 0.8], [tm.m3 + 0.65, 0.8, 'lin'], [tm.m3 + 0.9, 0, 'out']]));
  return g(
    { display: 'none' },
    during(t0, t1 + 0.2),
    motion(
      { o: [[t0 + 0.4, 0], [t0 + 0.8, 1, 'out'], ...fadeOut], t: [[t0 + 0.4, [0, 20]], [t0 + 1.1, [0, 0], 'emph']] },
      card(x, 350, w, 270, 24),
      iconDisc(x + 52, 400, 24, 'search'),
      text('規則式比對', { x: x + 92, y: 409, size: TY.cardTitle, weight: 700, fill: C.text }),
      chipEls,
      scan
    ),
    flowEls
  );
}

const SEC_COPY = {
  escrow: ['交易安全', '款項由平台暫管', ['買家完成訂單或取書滿 24 小時後，款項才撥入賣家錢包。']],
  pay: ['交易安全', '付款前，再驗證一次', ['結帳須輸入交易密碼或通過生物辨識，登入可用通行密鑰。']],
  chat: ['交易安全', '可疑訊息，即時提醒', ['偵測站外聯絡、私下付款與常見詐騙話術，提醒雙方留在平台交易。']],
  arch: ['系統架構', '從手機到書櫃，一套系統串起', ['App 與書櫃經 Cloudflare、NGINX 連到 Node.js 服務，資料存於 MariaDB。']],
  nums: ['開發成果', '完整實作，逐項驗證', ['後端 10 組測試群組與 App 測試全數通過。']],
  fee: ['交易服務費', '低抽成，快速撥款', ['規劃收取 10% 交易服務費，遠低於委託寄賣的 35%。']],
};

// ── 7. 系統架構與數字 ────────────────────────────────────
function archVisual(t0, t1) {
  const fadeOut = [[t1 - 0.6, 1], [t1 - 0.2, 0, 'in']];
  const H = 100;
  const box = (x, y, w, ic, label, sub, tIn) =>
    motion(
      { o: [[tIn, 0], [tIn + 0.35, 1, 'out'], ...fadeOut], t: [[tIn, [0, 26]], [tIn + 0.7, [0, 0], 'emph']] },
      card(x, y, w, H, 22),
      iconDisc(x + 54, y + H / 2, 28, ic),
      text(label, { x: x + 100, y: y + 44, size: TY.callout, weight: 700, fill: C.text }),
      text(sub, { x: x + 100, y: y + 78, size: TY.meta, fill: C.muted })
    );
  const L = 250;
  const W2 = 430;
  const GAP = 40;
  const WIDE = W2 * 2 + GAP;
  const R2 = L + W2 + GAP;
  const ys = [370, 510, 650, 790];
  const tiers = [
    { y: ys[3], t: t0 + 0.4, items: [[L, WIDE, 'storage', 'MariaDB', '關聯式資料庫・Prisma ORM 存取']] },
    { y: ys[2], t: t0 + 0.9, items: [[L, W2, 'bolt', 'Socket.IO', '聊天與書櫃狀態即時推送'], [R2, W2, 'code', 'Node.js・Express', 'RESTful API 與排程作業']] },
    { y: ys[1], t: t0 + 1.4, items: [[L, WIDE, 'cloud', 'Cloudflare・NGINX', 'DNS、WAF 與反向代理']] },
    { y: ys[0], t: t0 + 1.9, items: [[L, W2, 'smartphone', 'Flutter App', '跨平台行動應用'], [R2, W2, 'memory', 'ESP32 智慧書櫃', 'HTTPS 定時查詢狀態']] },
  ];
  const tierEls = tiers.map((r) => r.items.map(([x, w, ic, label, sub], i) => box(x, r.y, w, ic, label, sub, r.t + i * 0.1)));
  const ext = [
    ['sparkle', 'OpenAI', 'AI 功能'],
    ['bell', 'Firebase', '推播與登入驗證'],
    ['menuBook', 'Google Books', '書目資料'],
  ];
  const ex = 1390;
  const EW = 380;
  const extEls = ext.map(([ic, label, sub], i) => box(ex, ys[0] + i * 140, EW, ic, label, sub, t0 + 2.6 + i * 0.12));
  const extHead = fadeText('外部服務', { x: ex, y: ys[0] - 26, size: TY.eyebrow, weight: 700, fill: C.brand, ls: 0.12 }, t0 + 2.5, t1 - 0.6);
  const glow = radialGradient(nextId('ag'), [
    [0, '#FFFFFF', 1],
    [0.35, C.brand, 0.9],
    [1, C.brand, 0],
  ]);
  const cxL = L + W2 / 2;
  const cxR = R2 + W2 / 2;
  const gapLine = (x, yTop) => `M${x} ${yTop + H}V${yTop + 140}`;
  const lines = [
    [gapLine(cxL, ys[0]), t0 + 2.2],
    [gapLine(cxR, ys[0]), t0 + 2.25],
    [gapLine(cxL, ys[1]), t0 + 2.3],
    [gapLine(cxR, ys[1]), t0 + 2.35],
    [gapLine(cxL, ys[2]), t0 + 2.4],
    [gapLine(cxR, ys[2]), t0 + 2.45],
    [`M${R2 + W2} ${ys[2] + H / 2}H${ex - 60}V${ys[0] + H / 2}H${ex}M${ex - 60} ${ys[0] + 140 + H / 2}H${ex}M${ex - 60} ${ys[0] + 280 + H / 2}H${ex}`, t0 + 2.9],
  ];
  const lineEls = lines.map(([d, tt], i) => [drawPath(d, tt, i === 6 ? 0.6 : 0.3, { stroke: C.brand, width: 3, attrs: { 'stroke-opacity': 0.55 } }), i < 6 ? [0, 1].map((k) => loopDot(d, tt + 0.5 + k * 0.6, 1.2, { r: 8, fill: glow })) : '']);
  return g({ display: 'none' }, during(t0, t1 + 0.2), g({}, anim('opacity', fadeOut), lineEls), tierEls, extHead, extEls);
}

function numsVisual(t0, t1) {
  const items = [
    ['296', '個 API 端點', 'RESTful API'],
    ['1,497', '項後端測試', '10 組測試群組全數通過'],
    ['2,504', '項 App 測試', '44 個測試檔全數通過'],
    ['5', '種介面語言', '繁中・簡中・英・日・韓'],
  ];
  const xs = [330, 750, 1170, 1590];
  return g(
    { display: 'none' },
    during(t0, t1 + 0.2),
    items.map(([num, label, sub], i) => {
      const x = xs[i];
      const tIn = t0 + 0.5 + i * 0.18;
      return [
        odometer(num, { x, y: 640, size: 150, weight: 200, fill: C.brand, t0: tIn, dur: 1.4, tOut: t1 - 0.6 }),
        fadeText(label, { x, y: 728, size: TY.callout, weight: 700, fill: C.text, anchor: 'middle' }, tIn + 0.5, t1 - 0.55),
        fadeText(sub, { x, y: 768, size: TY.meta, fill: C.muted, anchor: 'middle' }, tIn + 0.6, t1 - 0.5),
      ];
    })
  );
}

function feeVisual(t0, t1) {
  const fadeOut = [[t1 - 0.6, 1], [t1 - 0.2, 0, 'in']];
  const x0 = 300;
  const perPct = 20;
  const colX = 1240;
  const bars = [
    { y: 470, label: '救「舊」我的書', tag: '規劃', pct: 10, color: C.brand, gets: '賣家實得 99 元', getsColor: C.success },
    { y: 650, label: '委託寄賣', tag: '', pct: 35, color: '#9AA5AE', gets: '賣家實得 71 元', getsColor: C.muted },
  ];
  const barEls = bars.map((b, i) => {
    const tIn = t0 + 0.5 + i * 0.25;
    const w = b.pct * perPct;
    const labelW = measure(b.label, TY.callout, { weight: 700 });
    return motion(
      { o: [[tIn, 0], [tIn + 0.3, 1, 'out'], ...fadeOut] },
      text(b.label, { x: x0, y: b.y, size: TY.callout, weight: 700, fill: C.text }),
      b.tag ? [rrect(x0 + labelW + 14, b.y - 25, 64, 34, 17, { fill: C.brand, 'fill-opacity': 0.14 }), text(b.tag, { x: x0 + labelW + 46, y: b.y - 1, size: TY.meta, weight: 700, fill: C.brand, anchor: 'middle' })] : '',
      el('rect', { x: x0, y: b.y + 24, width: 0, height: 52, rx: 14, fill: b.color }, anim('width', [[tIn + 0.2, 0], [tIn + 1.1, w, 'emph']])),
      motion({ o: [[tIn + 0.9, 0], [tIn + 1.2, 1, 'out']] }, text(`${b.pct}%`, { x: x0 + w + 24, y: b.y + 66, size: 44, weight: 800, fill: b.color })),
      motion({ o: [[tIn + 1.4, 0], [tIn + 1.7, 1, 'out']] }, text(b.gets, { x: colX, y: b.y + 62, size: TY.callout, weight: 700, fill: b.getsColor }))
    );
  });
  const head = fadeText('以售價 110 元為例', { x: colX, y: 440, size: TY.meta, weight: 700, fill: C.brand, ls: 0.06 }, t0 + 1.6, t1 - 0.6);
  const note = [
    fadeText('委託寄賣以 TAAZE 讀冊生活二手書代售服務條款（2025 年 8 月版）為例；', { x: x0, y: 850, size: TY.meta, fill: C.muted }, t0 + 1.9, t1 - 0.6),
    fadeText('本系統之交易服務費為規劃，目前未收取。', { x: x0, y: 884, size: TY.meta, fill: C.muted }, t0 + 2.0, t1 - 0.6),
  ];
  return g({ display: 'none' }, during(t0, t1 + 0.2), head, barEls, note);
}

// ── 8. 片尾 ─────────────────────────────────────────────
function ending() {
  const closeLine = centerTitle('讓閒置的書，重新流動。', { y: 560, t0: CLOSE + 0.5, t1: CARD - 0.6 });
  const size = 88;
  const m = lockupMetrics(size);
  const left = 960 - m.width / 2;
  const logo = motion(
    { o: [[CARD + 0.1, 0], [CARD + 0.6, 1, 'out']], s: [[CARD + 0.1, 0.86], [CARD + 1.1, 1, 'emph']], origin: [left + m.logoW / 2, 540] },
    g({ transform: `translate(${fmt(left)} ${fmt(540 - m.logoH / 2)}) scale(${fmt(m.s)}) translate(-210 -382)` }, staticLogo())
  );
  const word = riseLine('救「舊」我的書', { x: left + m.logoW + m.gap, y: 540 + size * 0.38, size, weight: 700, t0: CARD + 0.35, stagger: 0.05, dur: 0.9, rise: 1.05, fill: C.text, charFill: (n) => (n >= 1 && n <= 3 ? C.brand : undefined) });
  const veil = el('rect', { x: 0, y: 0, width: 1920, height: 1080, fill: C.stage, opacity: 0 }, anim('opacity', [[CLOSE, 0], [CLOSE + 0.8, 0.94, 'inout']]));
  return g({ display: 'none' }, during(CLOSE, DURATION), veil, closeLine, logo, word);
}

// ── 舞台與組裝 ───────────────────────────────────────────
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
    [0, C.brand, 0.06],
    [0.55, C.brand, 0.025],
    [1, C.brand, 0],
  ]);
  const r = rng(11);
  const bokeh = [];
  for (let i = 0; i < 80; i++) bokeh.push(el('circle', { cx: fmt(-400 + r() * 9400), cy: fmt(-1400 + r() * 4200), r: fmt(70 + r() * 150), fill: bokehFill }));
  addDef(el('pattern', { id: 'dotGrid', width: 34, height: 34, patternUnits: 'userSpaceOnUse' }, el('circle', { cx: 17, cy: 17, r: 1.15, fill: C.brand, 'fill-opacity': 0.2 })));
  return [
    el('rect', { width: 1920, height: 1080, fill: C.stage }),
    el('ellipse', { cx: 960, cy: 470, rx: 1100, ry: 620, fill: glow }),
    Wd.parallax(KEYS, 0.18, el('rect', { x: -3000, y: -3000, width: 9000, height: 7080, fill: 'url(#dotGrid)' })),
    Wd.parallax(KEYS, 0.5, g({}, bokeh)),
    el('rect', { width: 1920, height: 1080, fill: fog }),
    V.particles(40, 7, { t0: 0, t1: DURATION }),
  ];
}

function secPhone() {
  const P = { x: 1372, y: 96 };
  const pw = WIN.pay;
  const cw = WIN.chat;
  const tmPay = { checkout: pw.t0 + 1.0, sheet: pw.t0 + 1.35, pin: [0, 1, 2, 3, 4, 5].map((i) => pw.t0 + 2.1 + i * 0.26), done: pw.t0 + 4.05, success: pw.t0 + 4.3 };
  const tmChat = { m1: cw.t0 + 0.6, m2: cw.t0 + 1.3, m3: cw.t0 + 2.2, note: cw.t0 + 2.75, banner: cw.t0 + 3.6 };
  const screens = [SS.payScreen(pw.t0 - 0.3, cw.t0 - 0.2, tmPay), SS.chatScreen(cw.t0 - 0.2, undefined, tmChat)];
  const inT = pw.t0 - 0.2;
  const outT = cw.t1 - 0.2;
  const mv = motion(
    {
      x: P.x,
      y: P.y,
      t: [[inT, [40, 840]], [inT + 1.0, [0, 0], 'emph'], [outT, [0, 0], 'lin'], [outT + 0.7, [720, 40], 'in']],
      r: [[inT, 5], [inT + 1.0, 0, 'emph'], [outT, 0, 'lin'], [outT + 0.7, 8, 'in']],
      origin: [U.W / 2, U.H / 2],
    },
    iphone(screens, { glint: inT + 0.8 })
  );
  return { markup: g({ display: 'none' }, during(inT, outT + 0.8), mv), tmPay, tmChat };
}

function build() {
  ai.MODE.text = false;
  const aiT = {
    S0: A,
    intro: [A, A + 4.2],
    ...Object.fromEntries(ORDER.map((key) => [key, [WIN[key].t0, WIN[key].t1]])),
    gov: [WIN.dispute.t0 + 0.2, WIN.gov.t1],
    end: WIN.dispute.t1 + 1.0,
  };
  const ph = ai.phone(aiT);
  const P = ai.toScreen;
  const rowY = 59 + 8 + 30 + 20 + 44 + 20 + 76 + 28 + 12 + 55;
  const recIsl = ISLANDS.rec;
  const targets = (i) => {
    const scr = P(16 + i * 127 + 58, rowY);
    const w = Wd.unproject(KEYS, ph.rowsAt - 0.1, [scr.x, scr.y]);
    return { x: w.x - (recIsl.x - recIsl.orig[0]), y: w.y - (recIsl.y - recIsl.orig[1]) };
  };
  const extra = { rowsAt: ph.rowsAt, targets, adv: ph.adv, sup: ph.sup };
  const nodes = ORDER.map((key) => node(ISLANDS[key]));
  const islands = ORDER.map((key) => islandContent(ISLANDS[key], extra));
  const GS = (2.2 * 0.45) / 0.7;
  const govVisual = g({ transform: `translate(${CORE.x} ${CORE.y}) scale(${fmt(GS)}) translate(${-1310} ${-520})` }, ai.governance([WIN.gov.t0, WIN.gov.t1], { core: false, lineStart: 160 }));

  const sp = secPhone();
  const station = (key, visual) => {
    const st = STATIONS[key];
    const w = WIN[key];
    const fc = st.phone ? PHONE_C : WIDE_C;
    const copy = SEC_COPY[key];
    return g({ display: 'none' }, during(w.travel - 0.5, w.t1 + 1.2), worldCaption(st, fc, copy, w.t0 + 0.4, w.t1 - 0.5), atStation(st, fc, visual(w.t0, w.t1)));
  };
  const later = [
    station('escrow', escrowVisual),
    station('pay', (a, b) => methodsVisual(a, b, sp.tmPay)),
    station('chat', (a, b) => riskVisual(a, b, sp.tmChat)),
    station('arch', archVisual),
    station('nums', numsVisual),
    station('fee', feeVisual),
  ];

  const world = g(
    {},
    g({ display: 'none' }, during(SWAP, A + 0.5), cabinetWorld()),
    g({ display: 'none' }, during(OUT - 0.5, WIN.escrow.arrive + 1.0), coreLayer(), nodes, islands, govVisual),
    later
  );

  const flowPhone = g({ display: 'none' }, during(F, OUT + 0.6), motion({ t: [[OUT - 0.6, [0, 0]], [OUT + 0.4, [760, 80], 'in']], o: [[OUT - 0.1, 1], [OUT + 0.5, 0, 'lin']] }, flow.phone(t, { digitPop: false, code: '25' })));
  const layers = flowLayers();
  const fadeIn = el('rect', { width: 1920, height: 1080, fill: '#000000' }, anim('opacity', [[0, 1], [0.8, 0, 'out']]));
  const fadeOut = el('rect', { width: 1920, height: 1080, fill: '#000000', opacity: 0 }, anim('opacity', [[DURATION - 1.0, 0], [DURATION, 1, 'in']]));

  return {
    duration: DURATION,
    title: '救「舊」我的書｜介紹動畫',
    body: [
      stage(),
      opening(),
      reveal(),
      Wd.camera(KEYS, world),
      xrayOverlay(),
      g({ display: 'none' }, during(F, OUT + 0.2), layers.under, flowCaptions()),
      flowPhone,
      g({ display: 'none' }, during(F, OUT + 0.2), layers.over),
      ph.markup,
      sp.markup,
      introCaption(),
      govCaption(),
      ending(),
      V.brandBadge(60, 62, FULL_AT - 0.4, CLOSE),
      fadeIn,
      fadeOut,
    ],
  };
}

module.exports = { build, WIN, KEYS, CLOSE, CARD, DURATION };
