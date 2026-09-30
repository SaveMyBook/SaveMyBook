'use strict';

const { el, g, fmt, T, anim, motion, linearGradient, rrect, nextId } = require('./core');
const { text, measure } = require('./text');
const { icon } = require('./icons');
const { W, H, SAFE_TOP, SAFE_BOTTOM, statusBar, homeIndicator } = require('./iphone');
const C = require('./palette');

const HEADER = SAFE_TOP + 56;

function header(title, { iconName = 'qrScanner', back = true } = {}) {
  const d = `M0 0H${W}V${HEADER - 24}Q${W} ${HEADER} ${W - 24} ${HEADER}H24Q0 ${HEADER} 0 ${HEADER - 24}Z`;
  const size = 18;
  const tw = measure(title, size, { weight: 700 });
  const total = tw + (iconName ? 28 : 0);
  const left = W / 2 - total / 2;
  const mid = SAFE_TOP + 28;
  return g(
    {},
    el('path', { d, fill: C.brand }),
    statusBar('#FFFFFF'),
    back ? icon('back', 16, mid - 10, 20, '#FFFFFF') : '',
    iconName ? icon(iconName, left, mid - 10, 20, '#FFFFFF') : '',
    text(title, { x: left + (iconName ? 28 : 0), y: mid + 6.5, size, weight: 700, fill: '#FFFFFF' })
  );
}

const card = (x, y, w, h) => rrect(x, y, w, h, 16, { fill: C.card });

function primaryButton(x, y, w, label, { iconName, press, disabledUntil } = {}) {
  const tw = measure(label, 16, { weight: 700 });
  const total = tw + (iconName ? 26 : 0);
  const left = x + w / 2 - total / 2;
  const layers = [
    rrect(x, y, w, 48, 14, { fill: C.brand }),
    iconName ? icon(iconName, left, y + 14, 20, '#FFFFFF') : '',
    text(label, { x: left + (iconName ? 26 : 0), y: y + 30, size: 16, weight: 700, fill: '#FFFFFF' }),
  ];
  if (disabledUntil !== undefined) {
    layers.push(rrect(x, y, w, 48, 14, { fill: '#FFFFFF', opacity: 0.6 }, anim('opacity', [[disabledUntil, 0.6], [disabledUntil + 0.25, 0, 'out']])));
  }
  if (press === undefined) return g({}, layers);
  return motion(
    { s: [[press, 1], [press + 0.1, 0.97, 'out'], [press + 0.42, 1, 'out']], origin: [x + w / 2, y + 24] },
    layers,
    rrect(x, y, w, 48, 14, { fill: '#000000', opacity: 0 }, anim('opacity', [[press, 0], [press + 0.08, 0.12, 'out'], [press + 0.45, 0, 'out']]))
  );
}

function secondaryButton(x, y, w, label) {
  return g(
    {},
    rrect(x + 0.75, y + 0.75, w - 1.5, 46.5, 13.5, { fill: C.card, stroke: C.brand, 'stroke-width': 1.5 }),
    text(label, { x: x + w / 2, y: y + 30, size: 16, weight: 700, fill: C.brand, anchor: 'middle' })
  );
}

function bottomBar(top, children) {
  const d = `M0 ${top + 24}Q0 ${top} 24 ${top}H${W - 24}Q${W} ${top} ${W} ${top + 24}V${H}H0Z`;
  return g(
    {},
    [16, 10, 5].map((e) => el('path', { d, fill: '#0B1A26', 'fill-opacity': 0.022, transform: `translate(0 ${-e * 0.45})` })),
    el('path', { d, fill: C.card }),
    children
  );
}

function notice(x, y, w, lines, { tint = C.warning, iconName = 'info' } = {}) {
  const lh = 19.5;
  const h = 20 + lines.length * lh;
  return {
    h,
    markup: g(
      {},
      rrect(x, y, w, h, 12, { fill: tint, 'fill-opacity': 0.1 }),
      icon(iconName, x + 12, y + 11, 18, tint),
      lines.map((line, i) => text(line, { x: x + 38, y: y + 24.5 + i * lh, size: 13, fill: C.text }))
    ),
  };
}

function badge(x, y, label, color) {
  const tw = measure(label, 11, { weight: 600 });
  return g({}, rrect(x, y, tw + 16, 19, 6, { fill: color, 'fill-opacity': 0.14 }), text(label, { x: x + 8, y: y + 13.5, size: 11, weight: 600, fill: color }));
}

function shade(hex, amt) {
  const n = parseInt(hex.slice(1), 16);
  const ch = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((v) => Math.max(0, Math.min(255, Math.round(v + (amt < 0 ? v * amt : (255 - v) * amt)))));
  return `#${ch.map((v) => v.toString(16).padStart(2, '0')).join('')}`;
}

function bookCover(x, y, w, h, r, { color = '#4F7A63', accent = '#E7D9B8' } = {}) {
  const id = nextId('bk');
  const grad = linearGradient(`${id}g`, [
    [0, shade(color, 0.08)],
    [1, shade(color, -0.2)],
  ], { x1: 0, y1: 0, x2: 1, y2: 1 });
  return g(
    {},
    rrect(x, y, w, h, r, { fill: grad }),
    el('rect', { x: x + w * 0.09, y, width: w * 0.05, height: h, fill: '#000000', 'fill-opacity': 0.14 }),
    rrect(x + w * 0.25, y + h * 0.18, w * 0.56, h * 0.07, h * 0.02, { fill: accent }),
    rrect(x + w * 0.25, y + h * 0.3, w * 0.38, h * 0.045, h * 0.02, { fill: accent, 'fill-opacity': 0.72 }),
    rrect(x + w * 0.25, y + h * 0.8, w * 0.28, h * 0.04, h * 0.02, { fill: accent, 'fill-opacity': 0.55 })
  );
}

function spinner(cx, cy, r, stroke, color, t0, t1) {
  const circ = 2 * Math.PI * r;
  return g(
    { transform: `translate(${fmt(cx)} ${fmt(cy)})` },
    el('circle', { r, fill: 'none', stroke: color, 'stroke-opacity': 0.14, 'stroke-width': stroke }),
    g(
      {},
      el('animateTransform', { attributeName: 'transform', type: 'rotate', from: '0', to: '360', dur: '0.9s', begin: T(t0), end: T(t1), repeatCount: 'indefinite' }),
      el('circle', { r, fill: 'none', stroke: color, 'stroke-width': stroke, 'stroke-linecap': 'round', 'stroke-dasharray': `${fmt(circ * 0.28)} ${fmt(circ)}`, transform: 'rotate(-90)' })
    )
  );
}

// 新畫面疊在舊畫面上淡入，舊畫面等新畫面完全不透明才移除，避免兩層半透明時透出底色。
function switchIn(tIn, tOut, content, { dur = 0.3, hold = 0.34, slide = 0 } = {}) {
  const o = [[tIn, 0], [tIn + dur, 1, 'out']];
  if (tOut !== undefined) o.push([tOut + hold, 1, 'lin'], [tOut + hold + 0.04, 0, 'lin']);
  return motion(slide ? { o, t: [[tIn, [0, slide]], [tIn + dur, [0, 0], 'out']] } : { o }, content);
}

function touch(x, y, t, { hold = 0.16, light = false } = {}) {
  const base = light ? '#FFFFFF' : '#FFFFFF';
  return g(
    { transform: `translate(${fmt(x)} ${fmt(y)})` },
    motion(
      { s: [[t - 0.18, 0.6], [t, 1, 'out'], [t + hold, 1, 'lin'], [t + hold + 0.35, 1.25, 'out']], o: [[t - 0.18, 0], [t, 1, 'out'], [t + hold, 1, 'lin'], [t + hold + 0.35, 0, 'out']] },
      el('circle', { r: 22, fill: base, 'fill-opacity': 0.42, stroke: '#0B1A26', 'stroke-opacity': 0.14, 'stroke-width': 1.5 })
    ),
    el('circle', { r: 22, fill: 'none', stroke: base, 'stroke-width': 2, opacity: 0 }, anim('r', [[t, 22], [t + 0.55, 48, 'out']]), anim('opacity', [[t, 0.7], [t + 0.55, 0, 'out']]))
  );
}

function drawnCheck(cx, cy, size, color, t0) {
  const radius = size / 2 - 4;
  const circ = 2 * Math.PI * radius;
  const a = [cx - radius * 0.34, cy + radius * 0.02];
  const b = [cx - radius * 0.08, cy + radius * 0.28];
  const c = [cx + radius * 0.38, cy - radius * 0.26];
  return g(
    {},
    el('circle', { cx, cy, r: radius, fill: color, 'fill-opacity': 0.1 }),
    el(
      'circle',
      { cx, cy, r: radius, fill: 'none', stroke: color, 'stroke-width': 3.2, 'stroke-linecap': 'round', 'stroke-dasharray': `${fmt(circ)} ${fmt(circ)}`, 'stroke-dashoffset': fmt(circ), transform: `rotate(-90 ${fmt(cx)} ${fmt(cy)})` },
      anim('stroke-dashoffset', [[t0, circ], [t0 + 0.5, 0, 'out']])
    ),
    el(
      'path',
      { d: `M${fmt(a[0])} ${fmt(a[1])}L${fmt(b[0])} ${fmt(b[1])}L${fmt(c[0])} ${fmt(c[1])}`, fill: 'none', stroke: color, 'stroke-width': 4, 'stroke-linecap': 'round', 'stroke-linejoin': 'round', pathLength: 1, 'stroke-dasharray': '1 1.02', 'stroke-dashoffset': 1.01 },
      anim('stroke-dashoffset', [[t0 + 0.38, 1.01], [t0 + 0.9, 0, 'out']])
    )
  );
}

module.exports = { W, H, HEADER, SAFE_TOP, SAFE_BOTTOM, header, card, primaryButton, secondaryButton, bottomBar, notice, badge, bookCover, spinner, switchIn, touch, drawnCheck, shade, homeIndicator };
