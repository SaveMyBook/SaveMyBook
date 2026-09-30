'use strict';

const { el, g, fmt, T, EASE, anim, motion, rrect, linearGradient, radialGradient, blurFilter, nextId, rng, drawPath } = require('./core');
const { text, measure } = require('./text');
const { staticLogo } = require('./logo');
const C = require('./palette');

const TYPE = {
  eyebrow: { size: 22, weight: 600, ls: 0.12 },
  headline: { size: 64, weight: 700 },
  body: { size: 26, weight: 400, lh: 1.62 },
  caption: { size: 18, weight: 400 },
};

function brandBadge(x, y, tIn, tOut, { logoH = 40, size = 28 } = {}) {
  const s = logoH / 1258;
  const o = [[tIn, 0], [tIn + 0.6, 1, 'out']];
  if (tOut !== undefined) o.push([tOut, 1, 'lin'], [tOut + 0.5, 0, 'in']);
  return motion(
    { o, t: [[tIn, [-14, 0]], [tIn + 0.8, [0, 0], 'emph']] },
    g({ transform: `translate(${fmt(x)} ${fmt(y - logoH / 2)}) scale(${fmt(s)}) translate(-210 -382)` }, staticLogo()),
    text('救「舊」我的書', { x: x + 1620 * s + size * 0.55, y: y + size * 0.36, size, weight: 700, fill: C.text, perChar: (n) => (n >= 1 && n <= 3 ? { fill: C.brand } : null) })
  );
}

function lines(strs, { x, y, t0, tOut, size = TYPE.body.size, weight = TYPE.body.weight, lh = TYPE.body.lh, fill = C.muted, stagger = 0.08, anchor = 'start' }) {
  return strs.map((str, i) => {
    const a = t0 + i * stagger;
    const o = [[a, 0], [a + 0.5, 1, 'out']];
    const t = [[a, [0, 16]], [a + 0.75, [0, 0], 'emph']];
    if (tOut !== undefined) {
      o.push([tOut + i * 0.03, 1, 'lin'], [tOut + i * 0.03 + 0.3, 0, 'in']);
      t.push([tOut + i * 0.03, [0, 0], 'lin'], [tOut + i * 0.03 + 0.3, [0, -10], 'in']);
    }
    return motion({ o, t }, text(str, { x, y: y + i * size * lh, size, weight, fill, anchor }));
  });
}

function headline(str, { x, y, t0, tOut, size = TYPE.headline.size, weight = TYPE.headline.weight, fill = C.text }) {
  const rise = size * 1.1;
  return g(
    { 'clip-path': clipRect(x - 10, y - size * 1.1, measure(str, size, { weight, punct: 'tight' }) + 40, size * 1.45) },
    text(str, {
      x,
      y,
      size,
      weight,
      fill,
      punct: 'tight',
      perChar: (n) => {
        const d = n * 0.035;
        const t = [[t0 + d, [0, rise]], [t0 + d + 0.7, [0, 0], 'emph']];
        const o = [[t0 + d, 0], [t0 + d + 0.35, 1, 'out']];
        if (tOut !== undefined) {
          t.push([tOut + n * 0.02, [0, 0], 'lin'], [tOut + n * 0.02 + 0.35, [0, -rise], 'in']);
          o.push([tOut + n * 0.02, 1, 'lin'], [tOut + n * 0.02 + 0.25, 0, 'in']);
        }
        return { t, o };
      },
    })
  );
}

function clipRect(x, y, w, h) {
  const id = nextId('cr');
  require('./core').addDef(el('clipPath', { id }, el('rect', { x, y, width: w, height: h })));
  return `url(#${id})`;
}

function eyebrow(str, { x, y, t0, tOut, fill = C.brand }) {
  const o = [[t0, 0], [t0 + 0.5, 1, 'out']];
  if (tOut !== undefined) o.push([tOut, 1, 'lin'], [tOut + 0.35, 0, 'in']);
  return motion({ o, t: [[t0, [0, 10]], [t0 + 0.7, [0, 0], 'emph']] }, text(str, { x, y, ...TYPE.eyebrow, fill }));
}

function stepper(steps, { x, y, times, tIn, tOut }) {
  const gap = 34;
  let cx = x;
  const items = [];
  const dotR = 6;
  const positions = steps.map((label) => {
    const w = measure(label, 20, { weight: 600 });
    const pos = { dot: cx + dotR, label: cx + dotR * 2 + 10, w };
    cx += dotR * 2 + 10 + w + gap;
    return pos;
  });
  const lineY = y - 7;
  steps.forEach((label, i) => {
    const p = positions[i];
    const on = times[i];
    const next = positions[i + 1];
    if (next) {
      const x0 = p.label + p.w + 8;
      const x1 = next.dot - dotR - 8;
      items.push(el('line', { x1: x0, y1: lineY, x2: x1, y2: lineY, stroke: C.border, 'stroke-width': 2, 'stroke-linecap': 'round' }));
      if (times[i + 1] !== undefined) {
        items.push(el('line', { x1: x0, y1: lineY, x2: x0, y2: lineY, stroke: C.brand, 'stroke-width': 2, 'stroke-linecap': 'round' }, anim('x2', [[times[i + 1] - 0.45, x0], [times[i + 1], x1, 'inout']])));
      }
    }
    items.push(el('circle', { cx: p.dot, cy: lineY, r: dotR, fill: '#FFFFFF', stroke: C.border, 'stroke-width': 2 }));
    items.push(el('circle', { cx: p.dot, cy: lineY, r: dotR, fill: C.brand, opacity: 0 }, anim('opacity', [[on, 0], [on + 0.25, 1, 'out']])));
    items.push(el('circle', { cx: p.dot, cy: lineY, r: dotR, fill: 'none', stroke: C.brand, 'stroke-width': 2, opacity: 0 }, anim('r', [[on, dotR], [on + 0.7, dotR * 3, 'out']]), anim('opacity', [[on, 0.8], [on + 0.7, 0, 'out']])));
    const fillT = [[tIn, C.faint], [on, C.faint, 'lin'], [on + 0.3, C.brand, 'out']];
    if (times[i + 1] !== undefined) fillT.push([times[i + 1], C.brand, 'lin'], [times[i + 1] + 0.3, C.text, 'out']);
    items.push(motion({ fill: fillT }, text(label, { x: p.label, y, size: 20, weight: 600, fill: null })));
  });
  const o = [[tIn, 0], [tIn + 0.5, 1, 'out']];
  if (tOut !== undefined) o.push([tOut, 1, 'lin'], [tOut + 0.4, 0, 'in']);
  return motion({ o, t: [[tIn, [0, 12]], [tIn + 0.7, [0, 0], 'emph']] }, items);
}

function node(x, y, label, iconKind, { tIn, tOut, w = 150 } = {}) {
  const id = nextId('nd');
  const h = 48;
  const o = [[tIn, 0], [tIn + 0.3, 1, 'out']];
  if (tOut !== undefined) o.push([tOut, 1, 'lin'], [tOut + 0.4, 0, 'in']);
  const iconX = x - w / 2 + 16;
  const icon =
    iconKind === 'server'
      ? [0, 1, 2].map((i) => [rrect(iconX, y - 11 + i * 8, 20, 6, 2, { fill: C.brand }), el('circle', { cx: iconX + 16, cy: y - 8 + i * 8, r: 1.3, fill: '#FFFFFF' })])
      : [el('circle', { cx: iconX + 10, cy: y - 5, r: 5, fill: C.brand }), el('path', { d: `M${iconX} ${y + 10}a10 8 0 0 1 20 0z`, fill: C.brand })];
  return motion(
    { o, s: [[tIn, 0.85], [tIn + 0.5, 1, 'emph']], origin: [x, y] },
    rrect(x - w / 2 + 2, y - h / 2 + 8, w - 4, h, h / 2, { fill: '#0B1A26', 'fill-opacity': 0.12, filter: blurFilter(`${id}b`, 8) }),
    rrect(x - w / 2, y - h / 2, w, h, h / 2, { fill: '#FFFFFF', stroke: C.border, 'stroke-width': 1 }),
    icon,
    text(label, { x: iconX + 30, y: y + 7, size: 18, weight: 700, fill: C.text })
  );
}

function packet(a, b, t0, dur, label, { bend = -120, labelAt = 0.5, labelOffset = [0, -26], hold = 1.1, color = C.brand } = {}) {
  const mx = (a.x + b.x) / 2;
  const my = (a.y + b.y) / 2 + bend;
  const d = `M${fmt(a.x)} ${fmt(a.y)}Q${fmt(mx)} ${fmt(my)} ${fmt(b.x)} ${fmt(b.y)}`;
  const q = (s) => ({ x: (1 - s) * (1 - s) * a.x + 2 * (1 - s) * s * mx + s * s * b.x, y: (1 - s) * (1 - s) * a.y + 2 * (1 - s) * s * my + s * s * b.y });
  const id = nextId('pk');
  const glow = radialGradient(`${id}g`, [
    [0, '#FFFFFF', 1],
    [0.3, color, 0.9],
    [1, color, 0],
  ]);
  const lp = q(labelAt);
  const tw = measure(label, 16, { weight: 600 });
  const lw = tw + 26;
  const lcx = lp.x + labelOffset[0];
  const lx = lcx - lw / 2;
  const ly = lp.y + labelOffset[1] - 15;
  const tLabel = t0 + dur * labelAt * 0.8;
  return g(
    {},
    el('path', { d, fill: 'none', stroke: color, 'stroke-width': 1.6, 'stroke-dasharray': '1 6', 'stroke-linecap': 'round', opacity: 0 }, anim('opacity', [[t0 - 0.1, 0], [t0 + 0.1, 0.55, 'out'], [t0 + dur + hold, 0.55, 'lin'], [t0 + dur + hold + 0.4, 0, 'out']])),
    el(
      'path',
      { d, fill: 'none', stroke: color, 'stroke-width': 3, 'stroke-linecap': 'round', pathLength: 1, 'stroke-dasharray': '0.18 1.4', 'stroke-dashoffset': 0.18, opacity: 0 },
      anim('stroke-dashoffset', [[t0, 0.18], [t0 + dur, -1, 'inout']]),
      anim('opacity', [[t0, 0], [t0 + 0.08, 0.85, 'out'], [t0 + dur - 0.08, 0.85, 'lin'], [t0 + dur, 0, 'lin']])
    ),
    el(
      'circle',
      { r: 9, fill: glow, opacity: 0 },
      el('animateMotion', { path: d, begin: T(t0), dur: `${fmt(dur)}s`, fill: 'freeze', calcMode: 'spline', keyPoints: '0;1', keyTimes: '0;1', keySplines: EASE.inout.join(' ') }),
      anim('opacity', [[t0, 0], [t0 + 0.08, 1, 'out'], [t0 + dur, 1, 'lin'], [t0 + dur + 0.15, 0, 'out']])
    ),
    el('circle', { cx: b.x, cy: b.y, r: 5, fill: 'none', stroke: color, 'stroke-width': 2, opacity: 0 }, anim('r', [[t0 + dur, 5], [t0 + dur + 0.55, 26, 'out']]), anim('opacity', [[t0 + dur, 0.8], [t0 + dur + 0.55, 0, 'out']])),
    !label ? '' : motion(
      { o: [[tLabel, 0], [tLabel + 0.25, 1, 'out'], [t0 + dur + hold, 1, 'lin'], [t0 + dur + hold + 0.35, 0, 'in']], s: [[tLabel, 0.9], [tLabel + 0.4, 1, 'emph']], origin: [lcx, ly + 15] },
      rrect(lx, ly, lw, 30, 15, { fill: '#FFFFFF', stroke: color, 'stroke-opacity': 0.35, 'stroke-width': 1 }),
      text(label, { x: lcx, y: ly + 20.5, size: 16, weight: 600, fill: color, anchor: 'middle' })
    )
  );
}

function particles(count, seed, { x0 = 0, y0 = 0, w = 1920, h = 1080, t0 = 0, t1 = 30, color = C.brand } = {}) {
  const r = rng(seed);
  const out = [];
  for (let i = 0; i < count; i++) {
    const x = x0 + r() * w;
    const y = y0 + r() * h;
    const rad = 1.4 + r() * 2.6;
    const op = 0.1 + r() * 0.22;
    const dy = -(40 + r() * 120);
    const dx = (r() - 0.5) * 60;
    out.push(
      g(
        { transform: `translate(${fmt(x)} ${fmt(y)})` },
        el('circle', { r: rad, fill: color, 'fill-opacity': op }, el('animateTransform', { attributeName: 'transform', type: 'translate', values: `0 0;${fmt(dx)} ${fmt(dy)}`, keyTimes: '0;1', calcMode: 'spline', keySplines: EASE.soft.join(' '), begin: T(t0), dur: `${fmt(t1 - t0)}s`, fill: 'freeze' }))
      )
    );
  }
  return out;
}

function callout(anchor, label, sub, { tIn, tOut, side = 1, labelX, labelY }) {
  const lx = labelX;
  const ly = labelY;
  const elbow = side > 0 ? lx - 14 : lx + 14;
  const d = `M${fmt(anchor.x)} ${fmt(anchor.y)}L${fmt(elbow - side * 26)} ${fmt(ly - 9)}L${fmt(elbow)} ${fmt(ly - 9)}`;
  const o = [[tIn, 0], [tIn + 0.2, 1, 'out']];
  if (tOut !== undefined) o.push([tOut, 1, 'lin'], [tOut + 0.35, 0, 'in']);
  const anchorText = side > 0 ? 'start' : 'end';
  return motion(
    { o },
    el('circle', { cx: anchor.x, cy: anchor.y, r: 4.5, fill: C.brand }),
    el('circle', { cx: anchor.x, cy: anchor.y, r: 10, fill: 'none', stroke: C.brand, 'stroke-width': 1.5, opacity: 0.5 }),
    drawPath(d, tIn + 0.05, 0.45, { stroke: C.brand, width: 1.6, ease: 'inout' }),
    motion({ o: [[tIn + 0.35, 0], [tIn + 0.7, 1, 'out']], t: [[tIn + 0.35, [side * -10, 0]], [tIn + 0.8, [0, 0], 'emph']] }, text(label, { x: lx, y: ly, size: 26, weight: 700, fill: C.text, anchor: anchorText }), sub ? text(sub, { x: lx, y: ly + 34, size: 22, weight: 500, fill: C.muted, anchor: anchorText }) : '')
  );
}

function notification(x, y, w, { title, lines: body, t0, tOut, scale = 1.25 }) {
  return g({ transform: `translate(${fmt(x)} ${fmt(y)}) scale(${fmt(scale)}) translate(${fmt(-x)} ${fmt(-y)})` }, notificationBase(x, y, w / scale, { title, lines: body, t0, tOut }));
}

function notificationBase(x, y, w, { title, lines: body, t0, tOut }) {
  const id = nextId('nt');
  const h = 44 + 24 + body.length * 21 + 14;
  const iconS = 40;
  const o = [[t0, 0], [t0 + 0.3, 1, 'out']];
  if (tOut !== undefined) o.push([tOut, 1, 'lin'], [tOut + 0.35, 0, 'in']);
  const s = (iconS * 0.62) / 1258;
  return motion(
    { o, t: [[t0, [0, -24]], [t0 + 0.7, [0, 0], 'emph']], s: [[t0, 0.96], [t0 + 0.7, 1, 'emph']], origin: [x + w / 2, y] },
    rrect(x + 10, y + 16, w - 20, h - 6, 24, { fill: '#0B1A26', 'fill-opacity': 0.16, filter: blurFilter(`${id}b`, 16) }),
    rrect(x, y, w, h, 24, { fill: '#FFFFFF', 'fill-opacity': 0.96, stroke: '#FFFFFF', 'stroke-width': 1 }),
    rrect(x + 16, y + 16, iconS, iconS, 10, { fill: '#F3F5F7', stroke: C.border, 'stroke-width': 1 }),
    g({ transform: `translate(${fmt(x + 16 + iconS * 0.16)} ${fmt(y + 16 + (iconS - 1258 * s) / 2)}) scale(${fmt(s)}) translate(-210 -382)` }, staticLogo()),
    text('救「舊」我的書', { x: x + 16 + iconS + 12, y: y + 31, size: 14, weight: 600, fill: C.muted }),
    text('現在', { x: x + w - 18, y: y + 31, size: 14, fill: C.faint, anchor: 'end' }),
    text(title, { x: x + 16 + iconS + 12, y: y + 54, size: 16, weight: 700, fill: C.text }),
    body.map((line, i) => text(line, { x: x + 16 + iconS + 12, y: y + 77 + i * 21, size: 14.5, fill: C.text }))
  );
}

module.exports = { TYPE, brandBadge, lines, headline, eyebrow, stepper, node, packet, particles, callout, notification, clipRect };
