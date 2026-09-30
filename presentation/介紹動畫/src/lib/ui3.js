'use strict';

const { el, g, fmt, T, EASE, anim, animT, motion, rrect, radialGradient, linearGradient, blurFilter, nextId, drawPath } = require('./core');
const { text, measure } = require('./text');
const { icon } = require('./icons');
const C = require('./palette');

const BODY_FILL = '#3F4A54';
// 全片字級：畫面上實際呈現的像素大小，場景內的文字一律取自這裡。
const TY = { eyebrow: 24, title: 72, body: 30, callout: 26, cardTitle: 26, card: 24, meta: 22 };

function fadeRise(t0, t1, { dy = 18, dur = 0.7, outDur = 0.35 } = {}) {
  const o = [[t0, 0], [t0 + dur * 0.7, 1, 'out']];
  const t = [[t0, [0, dy]], [t0 + dur, [0, 0], 'emph']];
  if (t1 !== undefined) {
    o.push([t1, 1, 'lin'], [t1 + outDur, 0, 'in']);
    t.push([t1, [0, 0], 'lin'], [t1 + outDur, [0, -dy * 0.8], 'in']);
  }
  return { o, t };
}

function maskedLine(str, { x, y, size, weight = 700, fill = C.text, t0, t1, stagger = 0.03, punct = 'tight' }) {
  const rise = size * 1.1;
  const id = nextId('ml');
  const w = measure(str, size, { weight, punct });
  require('./core').addDef(el('clipPath', { id }, el('rect', { x: x - 12, y: y - size * 1.12, width: w + 60, height: size * 1.5 })));
  return g(
    { 'clip-path': `url(#${id})` },
    text(str, {
      x,
      y,
      size,
      weight,
      fill,
      punct,
      perChar: (n) => {
        const d = n * stagger;
        const tt = [[t0 + d, [0, rise]], [t0 + d + 0.75, [0, 0], 'emph']];
        const o = [[t0 + d, 0], [t0 + d + 0.35, 1, 'out']];
        if (t1 !== undefined) {
          tt.push([t1 + n * 0.015, [0, 0], 'lin'], [t1 + n * 0.015 + 0.35, [0, -rise], 'in']);
          o.push([t1 + n * 0.015, 1, 'lin'], [t1 + n * 0.015 + 0.25, 0, 'in']);
        }
        return { t: tt, o };
      },
    })
  );
}

function leftBlock({ x = 120, y, eyebrow, number, title = [], body = [], t0, t1, titleSize = TY.title, bodySize = TY.body, numberSize = 96 }) {
  const out = [];
  let cy = y;
  if (eyebrow) {
    out.push(motion(fadeRise(t0, t1, { dy: 10 }), text(eyebrow, { x, y: cy, size: TY.eyebrow, weight: 700, fill: C.brand, ls: 0.12 })));
    cy += number ? 112 : titleSize + 26;
  }
  if (number) {
    out.push(maskedLine(number, { x: x - 4, y: cy, size: numberSize, weight: 200, fill: C.brand, t0: t0 + 0.05, t1 }));
    cy += titleSize + 20;
  }
  title.forEach((line, i) => {
    if (i) cy += titleSize * 1.2;
    out.push(maskedLine(line, { x, y: cy, size: titleSize, weight: 800, t0: t0 + 0.12 + i * 0.1, t1: t1 === undefined ? undefined : t1 + i * 0.03 }));
  });
  if (title.length) cy += Math.round(titleSize * 0.89);
  body.forEach((line, i) => {
    out.push(motion(fadeRise(t0 + 0.4 + i * 0.08, t1 === undefined ? undefined : t1 + 0.05 + i * 0.03, { dy: 14 }), text(line, { x, y: cy, size: bodySize, weight: 500, fill: BODY_FILL })));
    cy += Math.round(bodySize * 1.53);
  });
  return { markup: g({}, out), bottom: cy };
}

function pill(x, y, label, { size = 24, weight = 600, fill = '#FFFFFF', color = C.text, stroke = C.border, iconName, iconColor = C.brand, anchor = 'start', t0, t1, pop = true } = {}) {
  const tw = measure(label, size, { weight });
  const padX = size * 0.8;
  const ic = iconName ? size * 1.05 : 0;
  const w = tw + padX * 2 + (iconName ? ic + size * 0.35 : 0);
  const h = size * 2;
  const left = anchor === 'middle' ? x - w / 2 : anchor === 'end' ? x - w : x;
  const id = nextId('pl');
  const content = [
    rrect(left + 3, y - h / 2 + 8, w - 6, h, h / 2, { fill: '#0B1A26', 'fill-opacity': 0.1, filter: blurFilter(`${id}b`, 7) }),
    rrect(left, y - h / 2, w, h, h / 2, { fill, stroke, 'stroke-width': 1.2 }),
    iconName ? icon(iconName, left + padX, y - ic / 2, ic, iconColor) : '',
    text(label, { x: left + padX + (iconName ? ic + size * 0.35 : 0), y: y + size * 0.36, size, weight, fill: color }),
  ];
  if (t0 === undefined) return { markup: g({}, content), w, h, left };
  const o = [[t0, 0], [t0 + 0.3, 1, 'out']];
  if (t1 !== undefined) o.push([t1, 1, 'lin'], [t1 + 0.3, 0, 'in']);
  const s = pop ? [[t0, 0.86], [t0 + 0.55, 1, 'emph']] : undefined;
  return { markup: motion({ o, s, origin: [left + w / 2, y] }, content), w, h, left };
}

function progressBar(x, y, count, times, { segW = 118, gap = 10, t0, t1 } = {}) {
  const items = [];
  for (let i = 0; i < count; i++) {
    const sx = x + i * (segW + gap);
    items.push(rrect(sx, y, segW, 6, 3, { fill: C.border }));
    items.push(el('rect', { x: sx, y, width: 0, height: 6, rx: 3, fill: C.brand }, anim('width', [[times[i], 0], [times[i] + 0.6, segW, 'inout']])));
  }
  const o = [[t0, 0], [t0 + 0.4, 1, 'out']];
  if (t1 !== undefined) o.push([t1, 1, 'lin'], [t1 + 0.4, 0, 'in']);
  return motion({ o }, items);
}

function aiCore(cx, cy, { r = 90, t0, t1, rings = true } = {}) {
  const id = nextId('ac');
  const orb = radialGradient(`${id}o`, [
    [0, '#FFFFFF', 1],
    [0.35, '#DCE8EE', 1],
    [0.7, C.brand, 0.55],
    [1, C.brand, 0],
  ]);
  const halo = radialGradient(`${id}h`, [
    [0, C.brand, 0.22],
    [1, C.brand, 0],
  ]);
  const ringEls = rings
    ? [1.45, 1.95, 2.5].map((k, i) => {
        const rr = r * k;
        const dash = i === 1 ? '2 10' : i === 2 ? '40 18 4 18' : '90 30';
        return g(
          { transform: `translate(${fmt(cx)} ${fmt(cy)})` },
          g(
            {},
            el('animateTransform', { attributeName: 'transform', type: 'rotate', from: i % 2 ? '360' : '0', to: i % 2 ? '0' : '360', dur: `${18 + i * 8}s`, begin: T(t0), repeatCount: 'indefinite' }),
            el('circle', { r: rr, fill: 'none', stroke: C.brand, 'stroke-opacity': 0.34 - i * 0.07, 'stroke-width': i === 0 ? 2 : 1.4, 'stroke-dasharray': dash, 'stroke-linecap': 'round' })
          )
        );
      })
    : [];
  const o = [[t0, 0], [t0 + 0.6, 1, 'out']];
  if (t1 !== undefined) o.push([t1, 1, 'lin'], [t1 + 0.5, 0, 'in']);
  return motion(
    { o, s: [[t0, 0.6], [t0 + 1.0, 1, 'emph']], origin: [cx, cy] },
    el('circle', { cx, cy, r: r * 3.2, fill: halo }),
    ringEls,
    g({ transform: `translate(${fmt(cx)} ${fmt(cy)})` }, motion({ s: [[t0, 1], [t0 + 1.6, 1.07, 'soft'], [t0 + 3.2, 1, 'soft'], [t0 + 4.8, 1.07, 'soft'], [t0 + 6.4, 1, 'soft']] }, el('circle', { r, fill: orb }))),
    icon('sparkle', cx - r * 0.42, cy - r * 0.42, r * 0.84, C.brand)
  );
}

function card(x, y, w, h, { r = 22, shadow = true, fill = '#FFFFFF' } = {}) {
  const id = nextId('cd');
  return [
    shadow ? rrect(x + 6, y + 14, w - 12, h - 4, r, { fill: '#0B1A26', 'fill-opacity': 0.12, filter: blurFilter(`${id}b`, 16) }) : '',
    rrect(x, y, w, h, r, { fill, stroke: C.border, 'stroke-width': 1 }),
  ];
}

module.exports = { BODY_FILL, TY, fadeRise, maskedLine, leftBlock, pill, progressBar, aiCore, card };
