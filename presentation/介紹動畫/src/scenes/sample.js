'use strict';

const { el, g, fmt, T, anim, motion, clipPath, linearGradient, radialGradient, rrect, nextId, during, drawPath, addDef } = require('../lib/core');
const { text, riseLine, measure, textClip } = require('../lib/text');
const { animatedLogo, BOX } = require('../lib/logo');
const { cabinet, doorRect, screenRect, platePos, lockupMetrics, PLATE, GEO, DEPTH, SCREEN_SCALE, xrayAnchors } = require('../lib/cabinet');
const { kioskScreen, qrMatrix } = require('../lib/kiosk');
const { qrPath } = require('../lib/qr');
const { iphone } = require('../lib/iphone');
const U = require('../lib/appui');
const { camera, project, curveTrack, flyText, rings } = require('../lib/fx');
const V = require('../lib/ui2');
const { icon } = require('../lib/icons');
const C = require('../lib/palette');

const DURATION = 26.8;
const T_FADE = 26.0;
const QR = qrMatrix('SaveMyBook DEMO');
const BOOK = { color: '#4F7A63', accent: '#E7D9B8' };
const PHONE = { x: 1440, y: 160, s: 0.86 };
const K0 = 5;
const SWAP = 7.0;
const LEFT = 120;

const toScreen = (x, y) => ({ x: PHONE.x + x * PHONE.s, y: PHONE.y + y * PHONE.s });

const plate = platePos();
const FULL = { k: 1, p: [1012, 491], c: [965, 525] };
const SCREEN_VIEW = { p: [980, 299], c: [975, 420] };
const DOOR_VIEW = { p: [940, 420], c: [950, 520] };
const CAM = [
  { t: SWAP, k: K0, p: [plate.x, plate.y], c: [960, 540] },
  { t: 9.6, ...FULL, ease: 'inout' },
  { t: 12.9, k: 1.03, p: FULL.p, c: FULL.c, ease: 'soft' },
  { t: 13.9, k: 1.28, ...SCREEN_VIEW, ease: 'inout' },
  { t: 18.3, k: 1.3, ...SCREEN_VIEW, ease: 'soft' },
  { t: 19.3, k: 1.3, ...DOOR_VIEW, ease: 'inout' },
  { t: 22.9, k: 1.33, ...DOOR_VIEW, ease: 'soft' },
  { t: 24.4, ...FULL, ease: 'inout' },
  { t: DURATION, k: 0.98, p: FULL.p, c: FULL.c, ease: 'soft' },
];

const T_PHONE = 12.4;
const T_SCAN = 14.2;
const T_CONFIRM = 14.85;
const T_OPEN_TAP = 16.05;
const T_MATCH_PHONE = 16.45;
const T_MATCH_KIOSK = 16.75;
const T_DIGITS = [17.45, 17.75];
const T_OK_TAP = 18.1;
const T_OPENING = 18.35;
const T_OPEN = 18.8;
const DOOR = { unlatch: 18.82, swing: 18.95, settle: [19.85, 20.15], angle: 100, close: [21.4, 22.25] };
const T_DONE_TAP = 22.4;
const T_RESULT = 22.62;
const T_KIOSK_DONE = 22.6;
const STEPS = [13.3, 16.45, 18.8, 22.5];

function lockupMorph() {
  const s = 430 / BOX.w;
  const m = lockupMetrics(PLATE.size * K0);
  const left = 960 - m.width / 2;
  const logoTarget = [left + m.logoW / 2, 540];
  const logoScale = m.logoH / (1258 * s);
  const bloom = radialGradient('logoBloom', [
    [0, C.brand, 0.22],
    [0.5, C.brand, 0.08],
    [1, C.brand, 0],
  ]);
  const glow = el('ellipse', { cx: 960, cy: 470, rx: 520, ry: 420, fill: bloom, opacity: 0 }, anim('opacity', [[0.4, 0], [2.4, 1, 'out'], [3.4, 0.55, 'soft'], [5.9, 0.55, 'lin'], [6.6, 0, 'in']]));

  const logo = motion(
    {
      x: 960,
      y: 470,
      t: [[2.75, [0, 0]], [3.75, [0, -92], 'emph'], [5.9, [0, -92], 'lin'], ...curveTrack(5.9, 7.0, [0, -92], [logoTarget[0] - 960 - 120, -92], [logoTarget[0] - 960, logoTarget[1] - 470])],
      s: [[0.35, 0.94], [2.7, 1, 'out'], [2.75, 1, 'lin'], [3.75, 0.78, 'emph'], [5.9, 0.78, 'lin'], [7.0, logoScale, 'inout']],
    },
    g({ transform: `scale(${fmt(s)}) translate(${-BOX.cx} ${-BOX.cy})` }, animatedLogo(0.35, { pen: true }))
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
  const sheen = g({ 'clip-path': clip.url }, el('rect', { x: clip.left - 260, y: wordY - wordSize, width: 180, height: wordSize * 1.3, fill: sheenGrad, transform: `skewX(-18)` }, anim('x', [[4.35, clip.left - 260], [5.25, clip.left + clip.width + 260, 'inout']])));
  const wordmark = motion(
    {
      t: [[5.9, [0, 0]], [7.0, [targetCx - 960, 540 - wordCenterY], 'inout']],
      s: [[5.9, 1], [7.0, targetSize / wordSize, 'inout']],
      origin: [960, wordCenterY],
    },
    riseLine('救「舊」我的書', { x: 960, y: wordY, size: wordSize, weight: 700, anchor: 'middle', t0: 3.0, stagger: 0.05, dur: 0.9, rise: 1.05, fill: C.text, charFill: (n) => (n >= 1 && n <= 3 ? C.brand : undefined) }),
    sheen
  );

  const tagline = motion(
    { o: [[3.9, 0], [4.6, 1, 'out'], [5.5, 1, 'lin'], [5.9, 0, 'in']], t: [[3.9, [0, 16]], [4.8, [0, 0], 'emph'], [5.5, [0, 0], 'lin'], [5.9, [0, 10], 'in']] },
    text('二手書交易，交給智慧書櫃。', { x: 960, y: 750, size: 36, weight: 400, fill: C.muted, anchor: 'middle', ls: 0.04 })
  );

  const chipLabels = ['掃碼存取', '款項保管', 'AI 輔助'];
  const chipW = chipLabels.map((c) => measure(c, 19, { weight: 600 }) + 40);
  const gap = 14;
  const total = chipW.reduce((a, b) => a + b, 0) + gap * (chipLabels.length - 1);
  let cx = 960 - total / 2;
  const chips = chipLabels.map((label, i) => {
    const w = chipW[i];
    const x = cx;
    cx += w + gap;
    const t0 = 4.35 + i * 0.1;
    return motion(
      { o: [[t0, 0], [t0 + 0.4, 1, 'out'], [5.45 + i * 0.03, 1, 'lin'], [5.8 + i * 0.03, 0, 'in']], s: [[t0, 0.88], [t0 + 0.6, 1, 'emph']], origin: [x + w / 2, 814] },
      rrect(x, 794, w, 40, 20, { fill: '#FFFFFF', stroke: C.border, 'stroke-width': 1 }),
      el('circle', { cx: x + 18, cy: 814, r: 3.5, fill: C.brand }),
      text(label, { x: x + 28, y: 821, size: 19, weight: 600, fill: C.text })
    );
  });

  return g({ display: 'none' }, during(0, SWAP), glow, motion({ s: [[4.7, 1], [5.9, 1.012, 'soft'], [7.0, 1, 'inout']], origin: [960, 540] }, logo, wordmark, tagline, chips));
}

function kioskStates() {
  return [
    { kind: 'idle', t0: SWAP + 1.8, t1: T_CONFIRM, matrix: QR, ratio: [[SWAP + 1.8, 0.95], [T_CONFIRM, 0.72, 'lin']], reveal: [SWAP + 1.95, SWAP + 2.45], pulse: T_SCAN + 0.55, fade: { fadeIn: 0.05 } },
    { kind: 'select', t0: T_CONFIRM, t1: T_MATCH_KIOSK },
    { kind: 'match', t0: T_MATCH_KIOSK, t1: T_OPENING, code: '47', seconds: 60, codeIn: T_MATCH_KIOSK + 0.02 },
    { kind: 'opening', t0: T_OPENING, t1: T_OPEN },
    { kind: 'open', t0: T_OPEN, t1: T_KIOSK_DONE, label: 'A01', message: '請將書籍放入 A01 後關上櫃門', total: 30 },
    { kind: 'result', t0: T_KIOSK_DONE, t1: undefined, message: '作業完成' },
  ];
}

function bookInsertion(r) {
  const bw = 70;
  const bh = 98;
  const px = r.x + 0.42 * r.w;
  const py = r.y + r.h - 4 - bh;
  const dx = GEO.dx * DEPTH * 0.55;
  const dy = GEO.dy * DEPTH * 0.55;
  const tA = 20.15;
  const tC = 20.72;
  const tB = 21.15;
  const book = [el('ellipse', { cx: px + bw / 2 + 4, cy: py + bh + 1, rx: bw * 0.62, ry: 5, fill: '#0B1A26', 'fill-opacity': 0.16 }), U.bookCover(px, py, bw, bh, 3, BOOK)];
  const outside = g(
    { display: 'none' },
    during(tA, tC),
    motion({ t: [[tA, [120, 230]], [tC, [0, 0], 'emph']], s: [[tA, 1.32], [tC, 1, 'emph']], o: [[tA, 0], [tA + 0.18, 1, 'out']], origin: [px + bw / 2, py + bh] }, book)
  );
  const inside = g(
    { display: 'none' },
    el('set', { attributeName: 'display', to: 'inline', begin: T(tC), fill: 'freeze' }),
    motion({ t: [[tC, [0, 0]], [tB, [dx, dy], 'out']], s: [[tC, 1], [tB, 0.92, 'out']], origin: [px + bw / 2, py + bh] }, book)
  );
  return { outside, inside };
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
  return g({}, anim('opacity', [[9.2, 1], [9.9, 0, 'soft']]), L.map(([d, dt]) => drawPath(d, t0 + dt, 0.9, { stroke: C.brand, width: 1, attrs: { 'stroke-opacity': 0.4 } })), ticks);
}

function world() {
  const insert = bookInsertion(doorRect(0));
  const cab = cabinet({
    build: SWAP + 0.35,
    screen: kioskScreen(kioskStates(), { powerOn: SWAP + 1.8 }),
    xray: [10.0, 12.9],
    doors: [
      { open: DOOR, lock: [T_OPEN, T_KIOSK_DONE], inside: insert.inside, front: insert.outside },
      { books: [{ color: '#A45F4B', accent: '#F1E3C8', at: 0.38 }] },
      { books: [{ color: '#3E6A9E', accent: '#E9EEF1', at: 0.3 }] },
      { books: [{ color: '#75689C', accent: '#EDE7F6', at: 0.46, h: 92 }] },
    ],
  });
  return g({ display: 'none' }, during(SWAP, DURATION), camera(CAM, [guides(), cab.markup]));
}

function scanner(show, tOut, detect) {
  const id = nextId('sc');
  const frame = 260;
  const fx = (U.W - frame) / 2;
  const fy = 328.6;
  const cx = U.W / 2;
  const cy = fy + frame / 2;
  const ks = 1.1;
  const clip = clipPath(`${id}b`, el('rect', { x: 0, y: U.HEADER - 30, width: U.W, height: U.H }));
  const vignette = radialGradient(`${id}v`, [
    [0.42, '#000000', 0],
    [1, '#000000', 0.5],
  ]);
  const face = linearGradient(`${id}f`, [
    [0, '#F2F5F7'],
    [1, '#D8DFE4'],
  ]);
  const m = Math.floor(200 / (QR.size + 8));
  const ox = 20 + Math.floor((200 - QR.size * m) / 2);
  const oy = 38 + Math.floor((200 - QR.size * m) / 2);
  const kiosk = g(
    { transform: `translate(${fmt(cx - 120 * ks)} ${fmt(cy - 138 * ks)}) scale(${ks})` },
    rrect(-16, -16, 272, 352, 18, { fill: C.kiosk.bezel }),
    rrect(0, 0, 240, 320, 6, { fill: C.kiosk.bg }),
    el('rect', { x: 0, y: 0, width: 240, height: 28, fill: C.kiosk.header }),
    el('circle', { cx: 226, cy: 14, r: 4, fill: C.kiosk.online }),
    el('rect', { x: 20, y: 38, width: 200, height: 200, fill: '#FFFFFF' }),
    el('path', { d: qrPath(QR, ox, oy, m), fill: '#000000' }),
    el('rect', { x: 20, y: 246, width: 200, height: 4, fill: C.kiosk.track }),
    el('rect', { x: 20, y: 246, width: 160, height: 4, fill: C.kiosk.accent })
  );
  const feed = motion(
    {
      t: [[show, [26, 34]], [detect - 1.0, [14, 18], 'soft'], [detect - 0.5, [-5, 7], 'soft'], [detect, [0, 0], 'soft']],
      r: [[show, -4], [detect, 0, 'soft']],
      s: [[show, 1.12], [detect, 1, 'soft']],
      origin: [cx, cy],
    },
    rrect(-60, 40, U.W + 120, U.H, 0, { fill: face }),
    kiosk
  );
  const corner = (sx, sy) => {
    const L = frame * 0.23;
    const r = 16;
    const x0 = sx < 0 ? fx : fx + frame;
    const y0 = sy < 0 ? fy : fy + frame;
    const dx = sx < 0 ? 1 : -1;
    const dy = sy < 0 ? 1 : -1;
    return `M${fmt(x0)} ${fmt(y0 + dy * L)}V${fmt(y0 + dy * r)}Q${fmt(x0)} ${fmt(y0)} ${fmt(x0 + dx * r)} ${fmt(y0)}H${fmt(x0 + dx * L)}`;
  };
  const corners = motion(
    { s: [[detect, 1], [detect + 0.16, 0.9, 'out'], [detect + 0.5, 0.93, 'soft']], origin: [cx, cy] },
    el('path', { d: [corner(-1, -1), corner(1, -1), corner(-1, 1), corner(1, 1)].join(''), fill: 'none', stroke: '#FFFFFF', 'stroke-opacity': 0.9, 'stroke-width': 5, 'stroke-linecap': 'round' })
  );
  const flash = rrect(fx + 10, fy + 10, frame - 20, frame - 20, 12, { fill: '#FFFFFF', opacity: 0 }, anim('opacity', [[detect, 0], [detect + 0.07, 0.55, 'out'], [detect + 0.45, 0, 'out']]));
  return U.switchIn(
    show,
    tOut,
    [
      el('rect', { x: 0, y: 0, width: U.W, height: U.H, fill: '#000000' }),
      g({ 'clip-path': clip }, feed, el('rect', { x: 0, y: 0, width: U.W, height: U.H, fill: vignette })),
      text('請對準書櫃螢幕上的 QR Code', { x: cx, y: 303, size: 18, weight: 700, fill: '#FFFFFF', anchor: 'middle', opacity: 0.92 }),
      corners,
      flash,
      U.header('掃描書櫃 QR Code'),
      U.homeIndicator('#FFFFFF'),
    ],
    { dur: 0.01, slide: 0 }
  );
}

function confirmScreen(t0, t1) {
  const checkbox = [rrect(38, 294, 18, 18, 4, { fill: C.brand }), el('path', { d: 'M41.5 303.2l3.8 3.8 7.4-7.6', fill: 'none', stroke: '#FFFFFF', 'stroke-width': 2.2, 'stroke-linecap': 'round', 'stroke-linejoin': 'round' })];
  return U.switchIn(t0, t1, [
    el('rect', { x: 0, y: 0, width: U.W, height: U.H, fill: C.stage }),
    U.card(16, 131, 370, 74),
    rrect(32, 147, 42, 42, 12, { fill: C.brand, 'fill-opacity': 0.12 }),
    icon('storage', 42, 157, 22, C.brand),
    text('圖書館大廳', { x: 86, y: 165, size: 16, weight: 700, fill: C.text }),
    text('圖書館一樓', { x: 86, y: 186, size: 12.5, fill: C.muted }),
    U.card(16, 219, 370, 142),
    text('依訂單存書', { x: 32, y: 248, size: 16, weight: 700, fill: C.text }),
    el('rect', { x: 32, y: 262, width: 338, height: 1, fill: C.divider }),
    checkbox,
    U.bookCover(74, 275, 44, 60, 8, BOOK),
    text('統計學概論', { x: 130, y: 293, size: 14, weight: 600, fill: C.text }),
    text('訂單編號 OD7KQ2M9X', { x: 130, y: 313, size: 12, fill: C.muted }),
    U.badge(130, 322, '櫃門 A01', C.brand),
    U.bottomBar(686, [
      text('請於 0:52 內確認', { x: U.W / 2, y: 712, size: 13, fill: C.muted, anchor: 'middle' }),
      U.primaryButton(16, 724, 370, '開啟櫃門', { iconName: 'lockOpen', press: T_OPEN_TAP }),
      U.secondaryButton(16, 780, 370, '取消作業'),
    ]),
    U.header('確認書櫃作業'),
    U.touch(U.W / 2, 748, T_OPEN_TAP),
    U.homeIndicator(),
  ]);
}

function matchScreen(t0, t1) {
  const boxX = [139, 207];
  const digits = ['4', '7'];
  const boxes = boxX.map((bx, i) => {
    const activeFrom = i === 0 ? t0 : T_DIGITS[0];
    const activeTo = i === 0 ? T_DIGITS[0] : undefined;
    const o = [[activeFrom, 0], [activeFrom + 0.12, 1, 'out']];
    if (activeTo) o.push([activeTo, 1, 'lin'], [activeTo + 0.12, 0, 'out']);
    return [
      rrect(bx, 376, 56, 64, 12, { fill: C.card, stroke: C.border, 'stroke-width': 1.4 }),
      motion({ o }, rrect(bx, 376, 56, 64, 12, { fill: 'none', stroke: C.brand, 'stroke-width': 1.6 })),
      motion(
        { s: [[T_DIGITS[i] - 0.02, 0.6], [T_DIGITS[i] + 0.3, 1, 'emph']], o: [[T_DIGITS[i] - 0.02, 0], [T_DIGITS[i] + 0.04, 1, 'lin']], origin: [bx + 28, 408] },
        text(digits[i], { x: bx + 28, y: 418, size: 28, weight: 800, fill: C.text, anchor: 'middle' })
      ),
    ];
  });
  const remaining = [60, 59].map((sec, i) =>
    g({ display: 'none' }, during(t0 + 0.02 + i, i === 0 ? t0 + 1.02 : t1 + 0.4), text(`剩餘 ${sec} 秒`, { x: U.W / 2, y: 467, size: 14, fill: C.muted, anchor: 'middle' }))
  );
  const warn = U.notice(16, 492, 370, ['若有他人告知數字並要求您輸入，請勿操作。'], { tint: C.danger, iconName: 'shield' });
  return U.switchIn(t0, t1, [
    el('rect', { x: 0, y: 0, width: U.W, height: U.H, fill: C.stage }),
    text('請輸入書櫃螢幕上的數字', { x: U.W / 2, y: 314, size: 18, weight: 700, fill: C.text, anchor: 'middle' }),
    text('櫃門 A01', { x: U.W / 2, y: 347, size: 14, fill: C.muted, anchor: 'middle' }),
    boxes,
    remaining,
    warn.markup,
    U.bottomBar(712, [U.primaryButton(16, 724, 370, '確認', { press: T_OK_TAP, disabledUntil: T_DIGITS[1] }), U.secondaryButton(16, 780, 370, '取消作業')]),
    U.header('確認書櫃作業'),
    U.touch(U.W / 2, 748, T_OK_TAP),
    U.homeIndicator(),
  ]);
}

function openingScreen(t0, t1) {
  return U.switchIn(t0, t1, [
    el('rect', { x: 0, y: 0, width: U.W, height: U.H, fill: C.stage }),
    U.spinner(U.W / 2, 440, 16.5, 3, C.brand, t0, t1 + 0.4),
    text('櫃門開啟中', { x: U.W / 2, y: 494, size: 17, weight: 700, fill: C.text, anchor: 'middle' }),
    text('櫃門 A01', { x: U.W / 2, y: 520, size: 14, fill: C.muted, anchor: 'middle' }),
    U.header('確認書櫃作業', { back: false }),
    U.homeIndicator(),
  ]);
}

function openScreen(t0, t1) {
  const r = 60;
  const cy = 203;
  const circ = 2 * Math.PI * r;
  const total = 30;
  const clock = [];
  for (let i = 0; t0 + i < t1; i++) {
    clock.push(g({ display: 'none' }, during(t0 + i, Math.min(t1 + 0.4, t0 + i + 1)), text(`0:${String(total - i).padStart(2, '0')}`, { x: U.W / 2, y: cy + 11, size: 32, weight: 800, fill: C.text, anchor: 'middle' })));
  }
  const tip = U.notice(16, 461, 370, ['如需取消，請於關上櫃門前按「取消」。', '倒數結束時將自動完成。'], { tint: C.brand, iconName: 'info' });
  return U.switchIn(t0, t1, [
    el('rect', { x: 0, y: 0, width: U.W, height: U.H, fill: C.stage }),
    el('circle', { cx: U.W / 2, cy, r, fill: 'none', stroke: C.brand, 'stroke-opacity': 0.14, 'stroke-width': 8 }),
    el(
      'circle',
      { cx: U.W / 2, cy, r, fill: 'none', stroke: C.brand, 'stroke-width': 8, 'stroke-dasharray': `${fmt(circ)} ${fmt(circ)}`, 'stroke-dashoffset': 0, transform: `rotate(-90 ${U.W / 2} ${cy})` },
      anim('stroke-dashoffset', [[t0, 0], [t1, (circ * (t1 - t0)) / total, 'lin']])
    ),
    clock,
    text('櫃門已開啟', { x: U.W / 2, y: 307, size: 20, weight: 700, fill: C.text, anchor: 'middle' }),
    U.card(16, 327, 370, 122),
    text('請將下列書籍放入櫃門 A01', { x: 32, y: 356, size: 16, weight: 700, fill: C.text }),
    el('rect', { x: 32, y: 370, width: 338, height: 1, fill: C.divider }),
    U.bookCover(32, 381, 40, 54, 8, BOOK),
    text('統計學概論', { x: 84, y: 413, size: 14, weight: 600, fill: C.text }),
    tip.markup,
    U.bottomBar(712, [U.primaryButton(16, 724, 370, '完成', { press: T_DONE_TAP }), U.secondaryButton(16, 780, 370, '取消')]),
    U.header('確認書櫃作業', { back: false }),
    U.touch(U.W / 2, 748, T_DONE_TAP),
    U.homeIndicator(),
  ]);
}

function resultScreen(t0) {
  return U.switchIn(t0, undefined, [
    el('rect', { x: 0, y: 0, width: U.W, height: U.H, fill: C.stage }),
    U.drawnCheck(U.W / 2, 372, 96, C.success, t0 + 0.1),
    text('存書完成，已通知買家取書', { x: U.W / 2, y: 456, size: 20, weight: 700, fill: C.text, anchor: 'middle' }),
    U.card(16, 484, 370, 80),
    U.bookCover(32, 500, 36, 48, 6, BOOK),
    text('統計學概論', { x: 80, y: 520, size: 14, weight: 600, fill: C.text }),
    text('已完成', { x: 80, y: 541, size: 12.5, fill: C.success }),
    U.bottomBar(768, [U.primaryButton(16, 780, 370, '完成')]),
    U.header('確認書櫃作業', { back: false }),
    U.homeIndicator(),
  ]);
}

function phone() {
  const screens = [
    scanner(T_PHONE, T_CONFIRM, T_SCAN),
    confirmScreen(T_CONFIRM, T_MATCH_PHONE),
    matchScreen(T_MATCH_PHONE, T_OPENING),
    openingScreen(T_OPENING, T_OPEN),
    openScreen(T_OPEN, T_RESULT),
    resultScreen(T_RESULT),
  ];
  return g(
    { display: 'none' },
    during(T_PHONE - 0.05, DURATION),
    motion(
      {
        x: PHONE.x,
        y: PHONE.y,
        t: [[T_PHONE, [40, 760]], [T_PHONE + 1.05, [0, 0], 'emph']],
        r: [[T_PHONE, 6], [T_PHONE + 1.05, 0, 'emph']],
        o: [[T_PHONE, 0], [T_PHONE + 0.25, 1, 'out']],
        origin: [(U.W * PHONE.s) / 2, (U.H * PHONE.s) / 2],
      },
      g({ transform: `scale(${PHONE.s})` }, iphone(screens, { glint: T_PHONE + 0.85 }))
    )
  );
}

function flows() {
  const S = { x: 960, y: 72 };
  const right = { x: S.x + 75, y: S.y };
  const bottom = { x: S.x, y: S.y + 24 };
  const leftEdge = { x: S.x - 75, y: S.y };
  const phoneAnchor = toScreen(28, 40);
  const cabTop = (t) => {
    const p = project(CAM, t, [980, 172]);
    return { x: p.x, y: p.y - 6 };
  };
  const scanCenter = toScreen(U.W / 2, 458.6);
  const sr = screenRect();
  const digitWorld = (i) => [sr.x + (120 + (i === 0 ? -21.2 : 21.2)) * SCREEN_SCALE, sr.y + 150 * SCREEN_SCALE];
  const fly = [0, 1].map((i) => {
    const t1 = T_DIGITS[i];
    const t0 = t1 - 0.5;
    const from = project(CAM, t0, digitWorld(i));
    const to = toScreen(i === 0 ? 167 : 235, 408);
    return flyText(['4', '7'][i], { from: { x: from.x, y: from.y, size: 72 * SCREEN_SCALE * from.k }, to: { x: to.x, y: to.y, size: 28 * PHONE.s }, t0, t1, weight: 700, fill: C.text, lift: -90 });
  });
  return g(
    {},
    V.node(S.x, S.y, '伺服器', 'server', { tIn: T_SCAN - 0.1, tOut: T_FADE - 0.4 }),
    rings(scanCenter.x, scanCenter.y, T_SCAN + 0.02, { color: C.brand, r0: 60, r1: 210, peak: 0.45, width: 2 }),
    V.packet(phoneAnchor, right, T_SCAN + 0.05, 0.55, '驗證 QR Code', { bend: -70, labelOffset: [0, -30] }),
    V.packet(phoneAnchor, right, T_OPEN_TAP + 0.05, 0.35, '開啟櫃門', { bend: -70, labelOffset: [0, -30], hold: 0.5 }),
    V.packet(bottom, cabTop(16.8), T_OPEN_TAP + 0.4, 0.3, '顯示比對數字', { bend: 0, labelOffset: [118, 0], hold: 0.9 }),
    fly,
    V.packet(phoneAnchor, right, T_OK_TAP + 0.05, 0.3, '數字＋定位', { bend: -70, labelOffset: [0, -30], hold: 0.5 }),
    V.packet(bottom, cabTop(18.8), T_OK_TAP + 0.35, 0.35, '開鎖指令', { bend: 0, labelOffset: [98, 0], hold: 0.9 }),
    V.packet(cabTop(22.3), bottom, DOOR.close[1], 0.35, '關門回報', { bend: 0, labelOffset: [98, 0], hold: 0.9 }),
    V.packet(leftEdge, { x: LEFT + 240, y: 604 }, T_RESULT + 0.05, 0.5, '通知買家', { bend: -40, labelOffset: [-10, -34], hold: 1.2 })
  );
}

const XR = { t0: 10.0, t1: 12.9 };

function titles() {
  const out = [];
  out.push(V.eyebrow('智慧書櫃', { x: LEFT, y: 378, t0: XR.t0 + 0.1, tOut: XR.t1 - 0.3 }));
  out.push(V.headline('一塊 ESP32', { x: LEFT, y: 456, t0: XR.t0 + 0.2, tOut: XR.t1 - 0.35 }));
  out.push(V.headline('四扇櫃門', { x: LEFT, y: 534, t0: XR.t0 + 0.32, tOut: XR.t1 - 0.3 }));
  out.push(V.lines(['ESP32 控制四組電磁鎖與顯示螢幕，', '並以 HTTPS 與伺服器同步狀態。'], { x: LEFT, y: 600, t0: XR.t0 + 0.55, tOut: XR.t1 - 0.3 }));

  const a = xrayAnchors();
  const at = (w) => project(CAM, XR.t0 + 1.0, [w.x, w.y]);
  const labelX = 1300;
  const callouts = [
    [at(a.esp), 'ESP32 控制板', 'Wi-Fi 連線・HTTPS 同步', 1, labelX, 236],
    [at(a.screen), '2.4 吋 TFT 螢幕', '240 × 320，顯示 QR Code 與數字', 1, labelX, 346],
    [at(a.lock), '電磁鎖 ×4', 'A01–A04，逐一開鎖', 1, labelX, 604],
    [at(a.psu), '12V 電源', '降壓 5V 供應控制板', 1, labelX, 842],
    [at(a.relay), '四路繼電器', '驅動電磁鎖', -1, 700, 236],
  ];
  out.push(callouts.map(([anchor, label, sub, side, lx, ly], i) => V.callout(anchor, label, sub, { tIn: XR.t0 + 0.75 + i * 0.14, tOut: XR.t1 - 0.45, side, labelX: lx, labelY: ly })));

  out.push(V.stepper(['掃碼', '比對', '開門', '完成'], { x: LEFT, y: 318, times: STEPS, tIn: 13.0, tOut: T_FADE - 0.3 }));
  const steps = [
    ['掃碼', ['QR Code 約每 30 秒更新，', '每組只能使用一次。'], STEPS[0] + 0.05, STEPS[1] - 0.32],
    ['比對', ['輸入書櫃螢幕上的兩位數字，', '並確認您在書櫃 200 公尺內。'], STEPS[1] + 0.08, STEPS[2] - 0.32],
    ['開門', ['只開啟指定的櫃門，', '倒數 30 秒內放入書籍。'], STEPS[2] + 0.08, STEPS[3] - 0.32],
    ['完成', ['櫃門關上才登記存書，', '買家同步收到取書通知。'], STEPS[3] + 0.08, T_FADE - 0.3],
  ];
  for (const [h, body, t0, t1] of steps) {
    out.push(V.headline(h, { x: LEFT, y: 432, t0, tOut: t1 }));
    out.push(V.lines(body, { x: LEFT, y: 494, t0: t0 + 0.25, tOut: t1 }));
  }
  out.push(
    V.notification(LEFT, 604, 520, {
      title: '書籍已存入書櫃',
      lines: ['訂單 OD7KQ2M9X 的書籍已存入「圖書館大廳」書櫃，', '請於營業時間內至書櫃以 App 掃描 QR Code 取書。'],
      t0: T_RESULT + 0.5,
      tOut: T_FADE - 0.3,
    })
  );
  return g({}, out);
}

function stage() {
  const glow = radialGradient('stageGlow', [
    [0, '#FFFFFF', 0.95],
    [0.6, '#FFFFFF', 0.35],
    [1, '#FFFFFF', 0],
  ]);
  const fog = radialGradient('stageFog', [
    [0.25, C.stage, 0],
    [0.95, C.stage, 1],
  ]);
  const floor = linearGradient('stageFloor', [
    [0, C.stage, 0],
    [1, '#E6EBEF', 1],
  ]);
  addDef(el('pattern', { id: 'dotGrid', width: 34, height: 34, patternUnits: 'userSpaceOnUse' }, el('circle', { cx: 17, cy: 17, r: 1.15, fill: C.brand, 'fill-opacity': 0.2 })));
  return [
    el('rect', { width: 1920, height: 1080, fill: C.stage }),
    el('ellipse', { cx: 960, cy: 470, rx: 1100, ry: 620, fill: glow }),
    el('rect', { width: 1920, height: 1080, fill: 'url(#dotGrid)' }),
    el('rect', { width: 1920, height: 1080, fill: fog }),
    el('rect', { y: 760, width: 1920, height: 320, fill: floor }),
    V.particles(28, 7, { t0: 0, t1: DURATION }),
  ];
}

function build() {
  return {
    duration: DURATION,
    title: '救「舊」我的書｜介紹動畫樣片',
    body: [
      stage(),
      lockupMorph(),
      motion({ o: [[T_FADE, 1], [DURATION, 0, 'in']] }, world(), phone(), flows(), titles(), V.brandBadge(56, 58, 9.3)),
    ],
  };
}

module.exports = { build };
