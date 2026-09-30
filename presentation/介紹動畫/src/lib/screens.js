'use strict';

const { el, g, fmt, anim, motion, clipPath, linearGradient, radialGradient, rrect, nextId, during } = require('./core');
const { text } = require('./text');
const { qrPath } = require('./qr');
const U = require('./appui');
const { icon } = require('./icons');
const C = require('./palette');

const BOOK = { color: '#4F7A63', accent: '#E7D9B8' };
const bg = () => el('rect', { x: 0, y: 0, width: U.W, height: U.H, fill: C.stage });

function scanner(show, tOut, detect, qr) {
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
  const m = Math.floor(200 / (qr.size + 8));
  const ox = 20 + Math.floor((200 - qr.size * m) / 2);
  const oy = 38 + Math.floor((200 - qr.size * m) / 2);
  const kiosk = g(
    { transform: `translate(${fmt(cx - 120 * ks)} ${fmt(cy - 138 * ks)}) scale(${ks})` },
    rrect(-16, -16, 272, 352, 18, { fill: C.kiosk.bezel }),
    rrect(0, 0, 240, 320, 6, { fill: C.kiosk.bg }),
    el('rect', { x: 0, y: 0, width: 240, height: 28, fill: C.kiosk.header }),
    el('circle', { cx: 226, cy: 14, r: 4, fill: C.kiosk.online }),
    el('rect', { x: 20, y: 38, width: 200, height: 200, fill: '#FFFFFF' }),
    el('path', { d: qrPath(qr, ox, oy, m), fill: '#000000' }),
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

function confirm(t0, t1, tap) {
  const checkbox = [rrect(38, 294, 18, 18, 4, { fill: C.brand }), el('path', { d: 'M41.5 303.2l3.8 3.8 7.4-7.6', fill: 'none', stroke: '#FFFFFF', 'stroke-width': 2.2, 'stroke-linecap': 'round', 'stroke-linejoin': 'round' })];
  return U.switchIn(t0, t1, [
    bg(),
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
    text('訂單編號 ODNMX0225', { x: 130, y: 313, size: 12, fill: C.muted }),
    U.badge(130, 322, '櫃門 A01', C.brand),
    U.bottomBar(686, [
      text('請於 0:52 內確認', { x: U.W / 2, y: 712, size: 13, fill: C.muted, anchor: 'middle' }),
      U.primaryButton(16, 724, 370, '開啟櫃門', { iconName: 'lockOpen', press: tap }),
      U.secondaryButton(16, 780, 370, '取消作業'),
    ]),
    U.header('確認書櫃作業'),
    U.touch(U.W / 2, 748, tap),
    U.homeIndicator(),
  ]);
}

function match(t0, t1, digitsAt, tap, { pop = true, code = '47' } = {}) {
  const boxX = [139, 207];
  const digits = [...code];
  const boxes = boxX.map((bx, i) => {
    const activeFrom = i === 0 ? t0 : digitsAt[0];
    const activeTo = i === 0 ? digitsAt[0] : undefined;
    const o = [[activeFrom, 0], [activeFrom + 0.12, 1, 'out']];
    if (activeTo) o.push([activeTo, 1, 'lin'], [activeTo + 0.12, 0, 'out']);
    return [
      rrect(bx, 376, 56, 64, 12, { fill: C.card, stroke: C.border, 'stroke-width': 1.4 }),
      motion({ o }, rrect(bx, 376, 56, 64, 12, { fill: 'none', stroke: C.brand, 'stroke-width': 1.6 })),
      motion(
        pop ? { s: [[digitsAt[i] - 0.02, 0.6], [digitsAt[i] + 0.3, 1, 'emph']], o: [[digitsAt[i] - 0.02, 0], [digitsAt[i] + 0.04, 1, 'lin']], origin: [bx + 28, 408] } : { o: [[digitsAt[i] - 0.01, 0], [digitsAt[i], 1, 'lin']] },
        text(digits[i], { x: bx + 28, y: 418, size: 28, weight: 800, fill: C.text, anchor: 'middle' })
      ),
    ];
  });
  const remaining = [60, 59].map((sec, i) =>
    g({ display: 'none' }, during(t0 + 0.02 + i, i === 0 ? t0 + 1.02 : t1 + 0.4), text(`剩餘 ${sec} 秒`, { x: U.W / 2, y: 467, size: 14, fill: C.muted, anchor: 'middle' }))
  );
  const warn = U.notice(16, 492, 370, ['若有他人告知數字並要求您輸入，請勿操作。'], { tint: C.danger, iconName: 'shield' });
  return U.switchIn(t0, t1, [
    bg(),
    text('請輸入書櫃螢幕上的數字', { x: U.W / 2, y: 314, size: 18, weight: 700, fill: C.text, anchor: 'middle' }),
    text('櫃門 A01', { x: U.W / 2, y: 347, size: 14, fill: C.muted, anchor: 'middle' }),
    boxes,
    remaining,
    warn.markup,
    U.bottomBar(712, [U.primaryButton(16, 724, 370, '確認', { press: tap, disabledUntil: digitsAt[1] }), U.secondaryButton(16, 780, 370, '取消作業')]),
    U.header('確認書櫃作業'),
    U.touch(U.W / 2, 748, tap),
    U.homeIndicator(),
  ]);
}

function opening(t0, t1) {
  return U.switchIn(t0, t1, [
    bg(),
    U.spinner(U.W / 2, 440, 16.5, 3, C.brand, t0, t1 + 0.4),
    text('櫃門開啟中', { x: U.W / 2, y: 494, size: 17, weight: 700, fill: C.text, anchor: 'middle' }),
    text('櫃門 A01', { x: U.W / 2, y: 520, size: 14, fill: C.muted, anchor: 'middle' }),
    U.header('確認書櫃作業', { back: false }),
    U.homeIndicator(),
  ]);
}

function open(t0, t1, tap) {
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
    bg(),
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
    U.bottomBar(712, [U.primaryButton(16, 724, 370, '完成', { press: tap }), U.secondaryButton(16, 780, 370, '取消')]),
    U.header('確認書櫃作業', { back: false }),
    U.touch(U.W / 2, 748, tap),
    U.homeIndicator(),
  ]);
}

function result(t0, t1) {
  return U.switchIn(t0, t1, [
    bg(),
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

module.exports = { BOOK, scanner, confirm, match, opening, open, result };
