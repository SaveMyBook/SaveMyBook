'use strict';

const { el, g, fmt, T, anim, motion, linearGradient, rrect, during } = require('../lib/core');
const { text } = require('../lib/text');
const { cabinet, doorRect, screenRect, GEO, DEPTH, SCREEN_SCALE } = require('../lib/cabinet');
const { kioskScreen, qrMatrix } = require('../lib/kiosk');
const { iphone } = require('../lib/iphone');
const U = require('../lib/appui');
const S = require('../lib/screens');
const { camera, project, flyText, rings } = require('../lib/fx');
const V = require('../lib/ui2');
const W3 = require('../lib/ui3');
const C = require('../lib/palette');

const QR = qrMatrix('SaveMyBook DEMO');
const PHONE = { x: 1372, y: 96, s: 1.0 };
const LEFT = 120;

function times(F) {
  return {
    F,
    phoneIn: F + 0.2,
    detect: F + 3.0,
    confirm: F + 3.8,
    openTap: F + 5.6,
    matchPhone: F + 7.1,
    matchKiosk: F + 7.4,
    digits: [F + 9.1, F + 9.5],
    okTap: F + 11.1,
    opening: F + 11.45,
    open: F + 12.0,
    door: { unlatch: F + 12.05, swing: F + 12.2, settle: [F + 13.1, F + 13.4], angle: 100, close: [F + 16.3, F + 17.2] },
    book: [F + 13.6, F + 14.2, F + 14.65],
    doneTap: F + 17.55,
    kioskDone: F + 17.5,
    result: F + 17.8,
    steps: [F + 0.5, F + 7.3, F + 12.0, F + 18.9],
    end: F + 26.5,
  };
}

function cameraKeys(t) {
  const F = t.F;
  return [
    { t: F, k: 2.1, p: [980, 299], c: [1100, 520] },
    { t: F + 6.8, k: 2.16, p: [980, 299], c: [1100, 520], ease: 'soft' },
    { t: F + 7.6, k: 2.5, p: [980, 292], c: [1110, 520], ease: 'inout' },
    { t: F + 11.6, k: 2.56, p: [980, 292], c: [1110, 520], ease: 'soft' },
    { t: F + 12.8, k: 1.7, p: [885, 568], c: [1080, 600], ease: 'inout' },
    { t: F + 17.9, k: 1.76, p: [885, 568], c: [1080, 600], ease: 'soft' },
    { t: F + 19.4, k: 1.12, p: [1012, 470], c: [1060, 540], ease: 'inout' },
    { t: t.end, k: 1.15, p: [1012, 470], c: [1060, 540], ease: 'soft' },
  ];
}

function kioskStates(t) {
  return [
    { kind: 'idle', t0: Math.max(0, t.F - 0.5), t1: t.confirm, matrix: QR, ratio: [[Math.max(0, t.F - 0.5), 0.95], [t.confirm, 0.7, 'lin']], pulse: t.detect + 0.55, fade: { fadeIn: 0.05 } },
    { kind: 'select', t0: t.confirm, t1: t.matchKiosk },
    { kind: 'match', t0: t.matchKiosk, t1: t.opening, code: '47', seconds: 60, codeIn: t.matchKiosk + 0.02 },
    { kind: 'opening', t0: t.opening, t1: t.open },
    { kind: 'open', t0: t.open, t1: t.kioskDone, label: 'A01', message: '請將書籍放入 A01 後關上櫃門', total: 30 },
    { kind: 'result', t0: t.kioskDone, t1: undefined, message: '作業完成' },
  ];
}

function bookInsertion(r, [tA, tC, tB]) {
  const bw = 70;
  const bh = 98;
  const px = r.x + 0.42 * r.w;
  const py = r.y + r.h - 4 - bh;
  const dx = GEO.dx * DEPTH * 0.55;
  const dy = GEO.dy * DEPTH * 0.55;
  const book = [el('ellipse', { cx: px + bw / 2 + 4, cy: py + bh + 1, rx: bw * 0.62, ry: 5, fill: '#0B1A26', 'fill-opacity': 0.16 }), U.bookCover(px, py, bw, bh, 3, S.BOOK)];
  const outside = g({ display: 'none' }, during(tA, tC), motion({ t: [[tA, [110, 200]], [tC, [0, 0], 'emph']], s: [[tA, 1.3], [tC, 1, 'emph']], o: [[tA, 0], [tA + 0.18, 1, 'out']], origin: [px + bw / 2, py + bh] }, book));
  const inside = g(
    { display: 'none' },
    el('set', { attributeName: 'display', to: 'inline', begin: T(tC), fill: 'freeze' }),
    motion({ t: [[tC, [0, 0]], [tB, [dx, dy], 'out']], s: [[tC, 1], [tB, 0.92, 'out']], origin: [px + bw / 2, py + bh] }, book)
  );
  return { outside, inside };
}

function world(t, { build }) {
  const insert = bookInsertion(doorRect(0), t.book);
  const cab = cabinet({
    build,
    screen: kioskScreen(kioskStates(t), {}),
    doors: [
      { open: t.door, lock: [t.open, t.end - 6], inside: insert.inside, front: insert.outside },
      { books: [{ color: '#A45F4B', accent: '#F1E3C8', at: 0.38 }] },
      { books: [{ color: '#3E6A9E', accent: '#E9EEF1', at: 0.3 }] },
      { books: [{ color: '#75689C', accent: '#EDE7F6', at: 0.46, h: 92 }] },
    ],
  });
  return camera(cameraKeys(t), cab.markup);
}

function phone(t, { digitPop = true, code = '47' } = {}) {
  const screens = [
    S.scanner(t.phoneIn, t.confirm, t.detect, QR),
    S.confirm(t.confirm, t.matchPhone, t.openTap),
    S.match(t.matchPhone, t.opening, t.digits, t.okTap, { pop: digitPop, code }),
    S.opening(t.opening, t.open),
    S.open(t.open, t.result, t.doneTap),
    S.result(t.result, undefined),
  ];
  return motion(
    {
      x: PHONE.x,
      y: PHONE.y,
      t: [[t.phoneIn, [30, 820]], [t.phoneIn + 1.1, [0, 0], 'emph']],
      r: [[t.phoneIn, 5], [t.phoneIn + 1.1, 0, 'emph']],
      o: [[t.phoneIn, 0], [t.phoneIn + 0.25, 1, 'out']],
      origin: [(U.W * PHONE.s) / 2, (U.H * PHONE.s) / 2],
    },
    g({ transform: `scale(${PHONE.s})` }, iphone(screens, { glint: t.phoneIn + 0.95 }))
  );
}

const toScreen = (x, y) => ({ x: PHONE.x + x * PHONE.s, y: PHONE.y + y * PHONE.s });

function overlays(t) {
  const keys = cameraKeys(t);
  const sr = screenRect();
  const scanCenter = toScreen(U.W / 2, 458.6);
  const digitWorld = (i) => [sr.x + (120 + (i === 0 ? -21.2 : 21.2)) * SCREEN_SCALE, sr.y + 150 * SCREEN_SCALE];
  const fly = [0, 1].map((i) => {
    const t1 = t.digits[i];
    const t0 = t1 - 0.6;
    const from = project(keys, t0, digitWorld(i));
    const to = toScreen(i === 0 ? 167 : 235, 408);
    return flyText(['4', '7'][i], { from: { x: from.x, y: from.y, size: 72 * SCREEN_SCALE * from.k }, to: { x: to.x, y: to.y, size: 28 * PHONE.s }, t0, t1, weight: 700, fill: C.text, lift: -120 });
  });
  const server = { x: 1180, y: 64 };
  const phoneTop = toScreen(40, 30);
  const kioskTop = (tt) => {
    const p = project(keys, tt, [980, 172]);
    return { x: p.x, y: Math.max(p.y - 8, 120) };
  };
  const flow = (a, b, t0, dur) => V.packet(a, b, t0, dur, '', { bend: -40, hold: 0.4 });
  return g(
    {},
    motion({ o: [[t.F + 11.6, 1], [t.F + 12.0, 0, 'in'], [t.F + 18.9, 0, 'lin'], [t.F + 19.4, 1, 'out']] }, V.node(server.x, server.y, '伺服器', 'server', { tIn: t.F + 0.8, tOut: t.end - 0.6 })),
    rings(scanCenter.x, scanCenter.y, t.detect + 0.02, { color: C.brand, r0: 70, r1: 260, peak: 0.45, width: 2.5 }),
    flow(phoneTop, { x: server.x + 75, y: server.y }, t.detect + 0.05, 0.5),
    flow(phoneTop, { x: server.x + 75, y: server.y }, t.openTap + 0.05, 0.45),
    flow({ x: server.x, y: server.y + 24 }, kioskTop(t.matchKiosk), t.openTap + 0.55, 0.45),
    fly,
    flow(phoneTop, { x: server.x + 75, y: server.y }, t.okTap + 0.05, 0.3),
    flow({ x: server.x, y: server.y + 24 }, kioskTop(t.open), t.okTap + 0.4, 0.45),
    flow(kioskTop(t.F + 19.6), { x: server.x, y: server.y + 24 }, t.F + 19.6, 0.4),
    flow({ x: server.x - 75, y: server.y }, { x: LEFT + 300, y: 752 }, t.result + 0.4, 0.55),
    W3.pill(1100, 214, 'QR Code 驗證成功', { iconName: 'checkCircle', iconColor: C.success, anchor: 'middle', t0: t.detect + 0.3, t1: t.confirm + 1.4 }).markup,
    W3.pill(1110, 196, '定位確認：書櫃 200 公尺內', { iconName: 'location', anchor: 'middle', t0: t.digits[0] + 0.2, t1: t.okTap + 0.5 }).markup,
    W3.pill(880, 362, 'A01 已開鎖', { iconName: 'lockOpen', iconColor: C.success, anchor: 'start', t0: t.door.unlatch + 0.1, t1: t.door.close[0] }).markup
  );
}

function leftText(t) {
  const steps = [
    ['01', '掃碼', ['QR Code 約每 30 秒更新，', '每組只能使用一次。']],
    ['02', '比對', ['輸入書櫃螢幕上的兩位數字，', '並確認您在書櫃 200 公尺內。']],
    ['03', '開門', ['只開啟指定的櫃門，', '倒數 30 秒內放入書籍。']],
    ['04', '完成', ['櫃門關上才登記存書，', '買家同步收到取書通知。']],
  ];
  const out = [];
  out.push(W3.progressBar(LEFT, 232, 4, t.steps, { t0: t.F + 0.3, t1: t.end - 0.6 }));
  out.push(motion(W3.fadeRise(t.F + 0.35, t.end - 0.6, { dy: 10 }), text('存書流程', { x: LEFT, y: 300, size: 24, weight: 600, fill: C.brand, ls: 0.12 })));
  steps.forEach(([num, title, body], i) => {
    const t0 = t.steps[i] + 0.05;
    const t1 = i < 3 ? t.steps[i + 1] - 0.45 : t.end - 0.6;
    out.push(W3.leftBlock({ x: LEFT, y: 412, number: num, title: [title], body, t0, t1, titleSize: 84, bodySize: 34, numberSize: 96 }).markup);
  });
  out.push(
    V.notification(LEFT, 742, 680, {
      title: '書籍已存入書櫃',
      lines: ['訂單 OD7KQ2M9X 的書籍已存入「圖書館大廳」書櫃，', '請於營業時間內至書櫃以 App 掃描 QR Code 取書。'],
      t0: t.result + 0.95,
      tOut: t.end - 0.6,
    })
  );
  return g({}, out);
}

function scrim() {
  const grad = linearGradient('flowScrim', [
    [0, C.stage, 1],
    [0.55, C.stage, 0.92],
    [1, C.stage, 0],
  ], { x1: 0, y1: 0, x2: 1, y2: 0 });
  return el('rect', { x: 0, y: 0, width: 900, height: 1080, fill: grad });
}

function build(F, { withWorld = true, build: buildAt } = {}) {
  const t = times(F);
  return {
    t,
    end: t.end,
    markup: g(
      {},
      withWorld ? world(t, { build: buildAt === undefined ? null : buildAt }) : '',
      scrim(),
      overlays(t),
      phone(t),
      leftText(t)
    ),
  };
}

function worldContent(t, { build: buildAt = null } = {}) {
  const insert = bookInsertion(doorRect(0), t.book);
  return cabinet({
    build: buildAt,
    screen: kioskScreen(kioskStates(t), {}),
    doors: [
      { open: t.door, lock: [t.open, t.end - 6], inside: insert.inside, front: insert.outside },
      { books: [{ color: '#A45F4B', accent: '#F1E3C8', at: 0.38 }] },
      { books: [{ color: '#3E6A9E', accent: '#E9EEF1', at: 0.3 }] },
      { books: [{ color: '#75689C', accent: '#EDE7F6', at: 0.46, h: 92 }] },
    ],
  }).markup;
}

module.exports = { build, times, cameraKeys, worldContent, phone, PHONE, QR };
