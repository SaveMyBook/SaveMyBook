'use strict';

const { el, g, anim, motion, rrect, during } = require('./core');
const { text, measure } = require('./text');
const U = require('./appui');
const { icon } = require('./icons');
const { statusBar } = require('./iphone');
const C = require('./palette');

const bg = () => el('rect', { x: 0, y: 0, width: U.W, height: U.H, fill: C.stage });
const BOOK = { color: '#4F7A63', accent: '#E7D9B8' };

function fadeSlide(t, content, { dy = 12, dur = 0.38 } = {}) {
  return motion({ o: [[t, 0], [t + dur, 1, 'out']], t: [[t, [0, dy]], [t + dur + 0.1, [0, 0], 'emph']] }, content);
}

function cartPage(tm) {
  const check = [rrect(32, 170, 20, 20, 5, { fill: C.brand }), el('path', { d: 'M36 180.5l4 4 8-8.2', fill: 'none', stroke: '#FFFFFF', 'stroke-width': 2.2, 'stroke-linecap': 'round', 'stroke-linejoin': 'round' })];
  return [
    bg(),
    U.card(16, 135, 370, 104),
    check,
    U.bookCover(66, 151, 52, 72, 6, BOOK),
    text('統計學概論', { x: 132, y: 172, size: 15, weight: 700, fill: C.text }),
    icon('person', 132, 183, 15, C.muted),
    text('海嫄', { x: 151, y: 196, size: 12.5, fill: C.muted }),
    text('$280', { x: 132, y: 224, size: 16, weight: 800, fill: C.brand }),
    U.badge(300, 158, '已在書櫃', C.success),
    U.bottomBar(740, [
      text('合計', { x: 24, y: 781, size: 13, fill: C.muted }),
      text('280 代幣', { x: 24, y: 806, size: 20, weight: 800, fill: C.text }),
      U.primaryButton(206, 758, 180, '結帳', { press: tm.checkout }),
    ]),
    U.header('購物車', { iconName: 'cart' }),
    U.touch(296, 782, tm.checkout),
    U.homeIndicator(),
  ];
}

// 依 App 的交易密碼面板（lib/widgets/pin_pad.dart）排版：6 個圓點、3×4 數字鍵盤。
function pinSheet(tm) {
  const top = 262;
  const cx = U.W / 2;
  const dots = [0, 1, 2, 3, 4, 5].map((i) => {
    const x = cx - 70 + i * 28;
    const y = top + 206;
    return [
      el('circle', { cx: x, cy: y, r: 7, fill: 'none', stroke: C.iconInactive, 'stroke-width': 2 }),
      motion({ o: [[tm.pin[i], 0], [tm.pin[i] + 0.08, 1, 'out']], s: [[tm.pin[i], 0.4], [tm.pin[i] + 0.25, 1, 'emph']], origin: [x, y] }, el('circle', { cx: x, cy: y, r: 8, fill: C.brand })),
    ];
  });
  const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del'];
  const keyPos = (k) => {
    const i = keys.indexOf(k);
    return { x: 30 + (i % 3) * 114 + 57, y: top + 244 + Math.floor(i / 3) * 60 + 30 };
  };
  const pad = keys.map((k) => {
    if (!k) return '';
    const p = keyPos(k);
    return k === 'del' ? icon('backspace', p.x - 12, p.y - 12, 24, C.muted) : text(k, { x: p.x, y: p.y + 9.5, size: 26, weight: 500, fill: C.text, anchor: 'middle' });
  });
  const presses = ['3', '8', '1', '6', '4', '9'].map((k, i) => {
    const p = keyPos(k);
    return [el('circle', { cx: p.x, cy: p.y, r: 30, fill: C.brand, opacity: 0 }, anim('opacity', [[tm.pin[i] - 0.04, 0], [tm.pin[i], 0.12, 'out'], [tm.pin[i] + 0.25, 0, 'out']])), U.touch(p.x, p.y, tm.pin[i], { hold: 0.08 })];
  });
  const sheet = [
    el('path', { d: `M0 ${top + 24}Q0 ${top} 24 ${top}H${U.W - 24}Q${U.W} ${top} ${U.W} ${top + 24}V${U.H}H0Z`, fill: C.card }),
    rrect(cx - 20, top + 12, 40, 4, 2, { fill: C.divider }),
    text('付款金額', { x: cx, y: top + 48, size: 13, fill: C.muted, anchor: 'middle' }),
    text('280 代幣', { x: cx, y: top + 88, size: 30, weight: 800, fill: C.text, anchor: 'middle' }),
    text('輸入交易密碼', { x: cx, y: top + 128, size: 18, weight: 700, fill: C.text, anchor: 'middle' }),
    text('共 1 本書，總金額 280 代幣。', { x: cx, y: top + 154, size: 13, fill: C.muted, anchor: 'middle' }),
    text('扣款後餘額為 920 代幣。', { x: cx, y: top + 173, size: 13, fill: C.muted, anchor: 'middle' }),
    dots,
    pad,
    presses,
    text('忘記交易密碼', { x: cx, y: top + 504, size: 14, weight: 600, fill: C.accent || C.brand, anchor: 'middle' }),
  ];
  return motion(
    { t: [[tm.sheet, [0, U.H - top]], [tm.sheet + 0.5, [0, 0], 'emph'], [tm.done, [0, 0], 'lin'], [tm.done + 0.4, [0, U.H - top], 'in']] },
    sheet
  );
}

function successPage(t) {
  return [
    bg(),
    U.drawnCheck(U.W / 2, 360, 96, C.success, t + 0.1),
    text('付款成功', { x: U.W / 2, y: 446, size: 20, weight: 700, fill: C.text, anchor: 'middle' }),
    text('書籍已在書櫃，可立即取書', { x: U.W / 2, y: 474, size: 14, fill: C.muted, anchor: 'middle' }),
    U.card(16, 506, 370, 80),
    U.bookCover(32, 522, 36, 48, 6, BOOK),
    text('統計學概論', { x: 80, y: 542, size: 14, weight: 600, fill: C.text }),
    text('圖書館大廳・櫃門 A01', { x: 80, y: 563, size: 12.5, fill: C.muted }),
    U.header('付款成功', { iconName: null, back: false }),
    U.homeIndicator(),
  ];
}

function payScreen(t0, t1, tm) {
  const scrim = el('rect', { x: 0, y: 0, width: U.W, height: U.H, fill: '#000000', opacity: 0 }, anim('opacity', [[tm.sheet, 0], [tm.sheet + 0.3, 0.42, 'out'], [tm.done, 0.42, 'lin'], [tm.done + 0.35, 0, 'in']]));
  return [
    U.switchIn(t0, tm.success, [cartPage(tm), scrim, statusBar('#FFFFFF'), pinSheet(tm)], { dur: 0.3 }),
    U.switchIn(tm.success, t1, successPage(tm.success), { dur: 0.3 }),
  ];
}

function bubbleThem(y, lines, t) {
  const w = Math.max(...lines.map((l) => measure(l, 15))) + 28;
  const h = 18 + lines.length * 22;
  return fadeSlide(t, [el('circle', { cx: 31, cy: y + 16, r: 15, fill: '#8FA0AB' }), text('林', { x: 31, y: y + 21.5, size: 14, weight: 700, fill: '#FFFFFF', anchor: 'middle' }), rrect(54, y, w, h, 18, { fill: C.card }), lines.map((l, i) => text(l, { x: 68, y: y + 26 + i * 22, size: 15, fill: C.text }))]);
}

function bubbleMe(y, lines, t) {
  const w = Math.max(...lines.map((l) => measure(l, 15))) + 28;
  const h = 18 + lines.length * 22;
  const x = U.W - 16 - w;
  return fadeSlide(t, [rrect(x, y, w, h, 18, { fill: C.brand }), lines.map((l, i) => text(l, { x: x + 14, y: y + 26 + i * 22, size: 15, fill: '#FFFFFF' }))]);
}

// 依 App 聊天室防詐提醒（lib/features/chat/chat_risk.dart）：高風險訊息下方的提醒與頂部橫幅。
function chatScreen(t0, t1, tm) {
  const note = fadeSlide(tm.note, [
    icon('gppMaybe', 56, 664, 14, C.danger),
    text('請勿私下匯款或轉帳，站外付款不受平台保障', { x: 74, y: 676, size: 11.5, weight: 500, fill: C.danger }),
    text('防詐須知・檢舉', { x: 74, y: 693, size: 11.5, weight: 600, fill: C.danger }),
  ], { dy: 6 });
  const bannerY = U.HEADER;
  const banner = motion(
    { o: [[tm.banner, 0], [tm.banner + 0.3, 1, 'out']], t: [[tm.banner, [0, -16]], [tm.banner + 0.5, [0, 0], 'emph']] },
    el('rect', { x: 0, y: bannerY, width: U.W, height: 78, fill: C.danger, 'fill-opacity': 0.08 }),
    icon('gppMaybe', 14, bannerY + 11, 20, C.danger),
    text('此聊天室有高風險訊息，請勿提供驗證碼或私下付款', { x: 44, y: bannerY + 27, size: 13, weight: 600, fill: C.text }),
    text('防詐須知', { x: 44, y: bannerY + 60, size: 13, weight: 700, fill: C.danger }),
    text('檢舉', { x: 44 + measure('防詐須知', 13, { weight: 700 }) + 22, y: bannerY + 60, size: 13, weight: 700, fill: C.danger })
  );
  const y = U.H - 34 - 8 - 48;
  return U.switchIn(t0, t1, [
    bg(),
    bubbleThem(430, ['請問《統計學概論》還在嗎？'], tm.m1),
    bubbleMe(492, ['在的，已存放在圖書館大廳書櫃。'], tm.m2),
    bubbleThem(584, ['可以加 LINE 私下轉帳嗎？', '這樣比較便宜'], tm.m3),
    note,
    el('rect', { x: 0, y: y - 10, width: U.W, height: U.H - y + 10, fill: C.card }),
    rrect(16, y, 318, 48, 24, { fill: C.inputFill }),
    text('輸入訊息', { x: 34, y: y + 30, size: 15, fill: C.hint }),
    el('circle', { cx: 362, cy: y + 24, r: 22, fill: C.brand }),
    icon('send', 351, y + 13, 22, '#FFFFFF'),
    U.header('小林', { iconName: null }),
    banner,
    U.homeIndicator(),
  ], { dur: 0.35 });
}

module.exports = { payScreen, chatScreen };
