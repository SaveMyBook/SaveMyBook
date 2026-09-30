'use strict';

const { el, g, fmt, T, anim, motion, clipPath, rrect, nextId, during } = require('./core');
const { text, measure } = require('./text');
const { qrMatrix, qrPath } = require('./qr');
const K = require('./palette').kiosk;

const KW = 240;
const KH = 320;
const top = (y, size) => y + size * 0.88;
const mid = (y, size) => y + size * 0.38;

function layer(t0, t1, content, { fadeIn = 0.14, fadeOut = 0.14 } = {}) {
  const o = [[t0, 0], [t0 + fadeIn, 1, 'out']];
  if (t1 !== undefined) o.push([t1 - fadeOut, 1, 'lin'], [t1, 0, 'in']);
  return motion({ o }, content);
}

function bar(x, y, w, h, color, frames) {
  return [
    el('rect', { x, y, width: w, height: h, fill: K.track }),
    el('rect', { x, y, width: frames[0][1] * w, height: h, fill: color }, anim('width', frames.map(([t, r, e]) => [t, r * w, e || 'lin']))),
  ];
}

function idle(state) {
  const { matrix, ratio } = state;
  const box = [20, 38, 200, 200];
  const m = Math.floor(box[2] / (matrix.size + 8));
  const ox = box[0] + Math.floor((box[2] - matrix.size * m) / 2);
  const oy = box[1] + Math.floor((box[3] - matrix.size * m) / 2);
  const id = nextId('kq');
  const reveal = state.reveal;
  const qr = [el('rect', { x: box[0], y: box[1], width: box[2], height: box[3], fill: '#FFFFFF' }), el('path', { d: qrPath(matrix, ox, oy, m), fill: '#000000' })];
  let qrLayer = g({}, qr);
  if (reveal) {
    const clip = clipPath(`${id}r`, el('rect', { x: 0, y: box[1], width: KW, height: 0 }, anim('height', [[reveal[0], 0], [reveal[1], box[3], 'inout']])));
    qrLayer = g({ 'clip-path': clip }, qr);
  }
  const pulse = state.pulse
    ? el('rect', { x: box[0] - 4, y: box[1] - 4, width: box[2] + 8, height: box[3] + 8, rx: 6, fill: 'none', stroke: K.accent, 'stroke-width': 4, opacity: 0 }, anim('opacity', [[state.pulse, 0], [state.pulse + 0.12, 1, 'out'], [state.pulse + 0.7, 0, 'soft']]))
    : '';
  return [
    qrLayer,
    pulse,
    bar(20, 246, 200, 4, K.accent, ratio),
    text('請使用 SaveMyBook App 掃描', { x: KW / 2, y: top(262, 14), size: 14, fill: K.text, anchor: 'middle' }),
  ];
}

function select() {
  return [
    text('書櫃使用中', { x: KW / 2, y: top(100, 20), size: 20, weight: 700, fill: K.text, anchor: 'middle' }),
    text('請於手機確認項目', { x: KW / 2, y: top(130, 14), size: 14, fill: K.muted, anchor: 'middle' }),
  ];
}

function secondsText(t0, t1, from, x, y, opts) {
  const out = [];
  for (let i = 0; ; i++) {
    const a = t0 + i;
    if (a >= t1) break;
    const b = Math.min(t1, a + 1);
    out.push(g({ display: 'none' }, during(a, b), text(opts.format(from - i), { x, y, ...opts })));
  }
  return out;
}

const CODE = { size: 72, weight: 700, cy: 150 };

// 比對數字各位數的中心（書櫃座標），供數字飛出動畫與畫面上的數字精準對位。
function codeCenters(code) {
  const opts = { weight: CODE.weight };
  let x = KW / 2 - measure(code, CODE.size, opts) / 2;
  return [...code].map((ch) => {
    const w = measure(ch, CODE.size, opts);
    const c = { ch, x: x + w / 2, y: CODE.cy };
    x += w;
    return c;
  });
}

function match(state) {
  const { code, t0, t1, seconds = 60, codeIn, codeHide } = state;
  let codeMarkup = text(code, { x: KW / 2, y: mid(CODE.cy, CODE.size), size: CODE.size, weight: CODE.weight, fill: K.text, anchor: 'middle' });
  if (codeHide) codeMarkup = motion({ o: [[codeHide[0], 1], [codeHide[0] + 0.01, 0, 'lin'], [codeHide[1], 0, 'lin'], [codeHide[1] + 0.4, 1, 'out']] }, codeMarkup);
  return [
    text('請於手機輸入下列數字', { x: KW / 2, y: top(64, 16), size: 16, weight: 700, fill: K.text, anchor: 'middle' }),
    codeIn !== undefined ? motion({ s: [[codeIn, 0.7], [codeIn + 0.45, 1, 'emph']], o: [[codeIn, 0], [codeIn + 0.25, 1, 'out']], origin: [KW / 2, CODE.cy] }, codeMarkup) : codeMarkup,
    secondsText(t0, t1, seconds, KW / 2, top(222, 14), { size: 14, fill: K.muted, anchor: 'middle', format: (s) => `剩餘 ${s} 秒` }),
    bar(20, 250, 200, 4, K.accent, [[t0, 1], [t1, 1 - (t1 - t0) / seconds, 'lin']]),
  ];
}

function kioskSpinner(cx, cy, r, t0, t1) {
  const circ = 2 * Math.PI * r;
  return g(
    { transform: `translate(${fmt(cx)} ${fmt(cy)})` },
    el('circle', { r, fill: 'none', stroke: K.track, 'stroke-width': 4 }),
    g(
      {},
      el('animateTransform', { attributeName: 'transform', type: 'rotate', from: '0', to: '360', dur: '1s', begin: T(t0), end: T(t1), repeatCount: 'indefinite' }),
      el('circle', { r, fill: 'none', stroke: K.accent, 'stroke-width': 4, 'stroke-linecap': 'round', 'stroke-dasharray': `${fmt(circ * 0.3)} ${fmt(circ)}` })
    )
  );
}

function opening(state) {
  return [kioskSpinner(KW / 2, 130, 24, state.t0, state.t1), text('櫃門開啟中', { x: KW / 2, y: top(180, 16), size: 16, weight: 700, fill: K.text, anchor: 'middle' })];
}

function open(state) {
  const { label, message, t0, t1, total = 30 } = state;
  const r = 34;
  const cy = 240;
  const circ = 2 * Math.PI * r;
  const elapsed = t1 - t0;
  return [
    text(label, { x: KW / 2, y: top(52, 40), size: 40, weight: 700, fill: K.text, anchor: 'middle' }),
    text(message, { x: KW / 2, y: top(112, 14), size: 14, fill: K.text, anchor: 'middle' }),
    el('circle', { cx: KW / 2, cy, r, fill: 'none', stroke: K.track, 'stroke-width': 4 }),
    el(
      'circle',
      {
        cx: KW / 2,
        cy,
        r,
        fill: 'none',
        stroke: K.accent,
        'stroke-width': 4,
        'stroke-linecap': 'round',
        'stroke-dasharray': `${fmt(circ)} ${fmt(circ)}`,
        'stroke-dashoffset': 0,
        transform: `rotate(-90 ${KW / 2} ${cy})`,
      },
      anim('stroke-dashoffset', [[t0, 0], [t1, circ * (elapsed / total), 'lin']])
    ),
    secondsText(t0, t1, total, KW / 2, mid(cy + 2, 40), { size: 40, weight: 700, fill: K.text, anchor: 'middle', format: (s) => String(s) }),
  ];
}

function result(state) {
  const cx = KW / 2;
  const cy = 90;
  const draw = state.t0 + 0.1;
  return [
    el('circle', { cx, cy, r: 26, fill: 'none', stroke: K.online, 'stroke-width': 4 }),
    el(
      'path',
      { d: `M${cx - 12} ${cy + 1}L${cx - 3} ${cy + 10}L${cx + 13} ${cy - 9}`, fill: 'none', stroke: K.online, 'stroke-width': 4, 'stroke-linecap': 'round', 'stroke-linejoin': 'round', pathLength: 1, 'stroke-dasharray': '1 1.02', 'stroke-dashoffset': 1.01 },
      anim('stroke-dashoffset', [[draw, 1.01], [draw + 0.4, 0, 'out']])
    ),
    text(state.message || '作業完成', { x: KW / 2, y: top(160, 16), size: 16, weight: 700, fill: K.text, anchor: 'middle' }),
  ];
}

const RENDER = { idle, select, match, opening, open, result };

function kioskScreen(states, { powerOn } = {}) {
  const id = nextId('ks');
  const clip = clipPath(`${id}c`, rrect(0, 0, KW, KH, 6));
  const layers = states.map((st) => layer(st.t0, st.t1, RENDER[st.kind](st), st.fade || {}));
  const headerBar = [
    el('rect', { x: 0, y: 0, width: KW, height: 28, fill: K.header }),
    text('智慧書櫃', { x: 10, y: 14 + 1 + 14 * 0.38, size: 14, weight: 700, fill: K.text }),
    el('circle', { cx: KW - 14, cy: 14, r: 4, fill: K.online }),
  ];
  const content = [el('rect', { x: 0, y: 0, width: KW, height: KH, fill: K.bg }), powerOn ? motion({ o: [[powerOn, 0], [powerOn + 0.25, 1, 'out']] }, headerBar) : headerBar, layers];
  return g({ 'clip-path': clip }, content);
}

module.exports = { KW, KH, CODE, codeCenters, kioskScreen, qrMatrix };
