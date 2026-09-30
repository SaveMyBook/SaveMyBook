'use strict';

const { el, g, fmt, T, EASE, anim, animT, motion, rrect, radialGradient, linearGradient, blurFilter, nextId, ease, drawPath } = require('./core');
const { text, measure } = require('./text');
const { icon } = require('./icons');
const W3 = require('./ui3');
const C = require('./palette');

function interp(keys, t) {
  let a = keys[0];
  let b = keys[0];
  for (let i = 1; i < keys.length; i++) {
    if (t <= keys[i].t) {
      a = keys[i - 1];
      b = keys[i];
      break;
    }
    a = keys[i];
    b = keys[i];
  }
  let s = 0;
  if (b !== a) s = ease(b.ease || 'inout')(Math.min(1, Math.max(0, (t - a.t) / (b.t - a.t))));
  const lerp = (u, v) => u + (v - u) * s;
  return {
    k: Math.exp(lerp(Math.log(a.k), Math.log(b.k))),
    p: [lerp(a.p[0], b.p[0]), lerp(a.p[1], b.p[1])],
    c: [lerp(a.c[0], b.c[0]), lerp(a.c[1], b.c[1])],
    r: lerp(a.r || 0, b.r || 0),
  };
}

function project(keys, t, pt) {
  const { k, p, c, r } = interp(keys, t);
  const th = (r * Math.PI) / 180;
  const dx = (pt[0] - p[0]) * k;
  const dy = (pt[1] - p[1]) * k;
  return { x: c[0] + dx * Math.cos(th) - dy * Math.sin(th), y: c[1] + dx * Math.sin(th) + dy * Math.cos(th), k };
}

function unproject(keys, t, pt) {
  const { k, p, c, r } = interp(keys, t);
  const th = (-r * Math.PI) / 180;
  const dx = pt[0] - c[0];
  const dy = pt[1] - c[1];
  return { x: p[0] + (dx * Math.cos(th) - dy * Math.sin(th)) / k, y: p[1] + (dx * Math.sin(th) + dy * Math.cos(th)) / k };
}

function camera(keys, content, { fps = 30 } = {}) {
  const tr = [];
  const rot = [];
  const sc = [];
  const back = [];
  const t0 = keys[0].t;
  const t1 = keys[keys.length - 1].t;
  const n = Math.max(2, Math.ceil((t1 - t0) * fps));
  for (let i = 0; i <= n; i++) {
    const t = t0 + ((t1 - t0) * i) / n;
    const v = interp(keys, t);
    tr.push([t, v.c, 'lin']);
    rot.push([t, v.r, 'lin']);
    sc.push([t, v.k, 'lin']);
    back.push([t, [-v.p[0], -v.p[1]], 'lin']);
  }
  const v0 = interp(keys, t0);
  const hasRot = keys.some((k) => k.r);
  const inner = g({ transform: `translate(${fmt(-v0.p[0])} ${fmt(-v0.p[1])})` }, animT('translate', back), content);
  const scaled = g({ transform: `scale(${fmt(v0.k)})` }, animT('scale', sc), inner);
  const rotated = hasRot ? g({ transform: `rotate(${fmt(v0.r)})` }, animT('rotate', rot), scaled) : scaled;
  return g({ transform: `translate(${fmt(v0.c[0])} ${fmt(v0.c[1])})` }, animT('translate', tr), rotated);
}

function parallax(keys, factor, content, anchor = [960, 540], { fps = 20 } = {}) {
  const t0 = keys[0].t;
  const t1 = keys[keys.length - 1].t;
  const n = Math.max(2, Math.ceil((t1 - t0) * fps));
  const base = project(keys, t0, anchor);
  const tr = [];
  for (let i = 0; i <= n; i++) {
    const t = t0 + ((t1 - t0) * i) / n;
    const q = project(keys, t, anchor);
    tr.push([t, [(q.x - base.x) * factor, (q.y - base.y) * factor], 'lin']);
  }
  return g({ transform: 'translate(0 0)' }, animT('translate', tr), content);
}

function link(a, b, t0, dur, { bend = -140, hold = 0.35, color = C.brand } = {}) {
  const mx = (a.x + b.x) / 2;
  const my = Math.min(a.y, b.y) + bend;
  const d = `M${fmt(a.x)} ${fmt(a.y)}Q${fmt(mx)} ${fmt(my)} ${fmt(b.x)} ${fmt(b.y)}`;
  const id = nextId('lk');
  const glow = radialGradient(`${id}g`, [
    [0, '#FFFFFF', 1],
    [0.3, color, 0.95],
    [1, color, 0],
  ]);
  const endT = t0 + dur + hold;
  const ripple = (p, t) => el('circle', { cx: fmt(p.x), cy: fmt(p.y), r: 8, fill: 'none', stroke: color, 'stroke-width': 2.5, opacity: 0 }, anim('r', [[t, 8], [t + 0.55, 40, 'out']]), anim('opacity', [[t, 0.75], [t + 0.55, 0, 'out']]));
  return g(
    {},
    el('path', { d, fill: 'none', stroke: color, 'stroke-width': 2.5, 'stroke-dasharray': '1 9', 'stroke-linecap': 'round', opacity: 0 }, anim('opacity', [[t0 - 0.1, 0], [t0 + 0.15, 0.55, 'out'], [endT, 0.55, 'lin'], [endT + 0.4, 0, 'out']])),
    el(
      'path',
      { d, fill: 'none', stroke: color, 'stroke-width': 4, 'stroke-linecap': 'round', pathLength: 1, 'stroke-dasharray': '0.2 1.3', 'stroke-dashoffset': 0.2, opacity: 0 },
      anim('stroke-dashoffset', [[t0, 0.2], [t0 + dur, -1, 'inout']]),
      anim('opacity', [[t0, 0], [t0 + 0.06, 0.85, 'out'], [t0 + dur - 0.06, 0.85, 'lin'], [t0 + dur, 0, 'lin']])
    ),
    el(
      'circle',
      { r: 13, fill: glow, opacity: 0 },
      el('animateMotion', { path: d, begin: T(t0), dur: `${fmt(dur)}s`, fill: 'freeze', calcMode: 'spline', keyPoints: '0;1', keyTimes: '0;1', keySplines: EASE.inout.join(' ') }),
      anim('opacity', [[t0, 0], [t0 + 0.06, 1, 'out'], [t0 + dur, 1, 'lin'], [t0 + dur + 0.15, 0, 'out']])
    ),
    ripple(a, t0),
    ripple(b, t0 + dur)
  );
}

// 起點與書櫃螢幕上的數字完全重合，位移與縮放取同一組取樣點，避免路徑與大小不同步而抖動。
// 離開深色螢幕時由淺色字換成深色字；base 為字身中心到基線的比例，需與起訖兩端的排版一致。
function flyDigit(ch, { from, to, p1, p2, t0, t1, exitRect, light = '#FFFFFF', dark = C.text, lightWeight = 700, darkWeight = 800, base = 0.38, fps = 60 }) {
  const e = ease('inout');
  const at = (tt) => {
    const u = e(Math.min(1, Math.max(0, (tt - t0) / (t1 - t0))));
    const v = 1 - u;
    const b0 = v * v * v;
    const b1 = 3 * v * v * u;
    const b2 = 3 * v * u * u;
    const b3 = u * u * u;
    return {
      x: b0 * from.x + b1 * p1.x + b2 * p2.x + b3 * to.x,
      y: b0 * from.y + b1 * p1.y + b2 * p2.y + b3 * to.y,
      s: Math.exp(Math.log(from.size) + (Math.log(to.size) - Math.log(from.size)) * u) / 100,
    };
  };
  let exitAt = t0 + (t1 - t0) * 0.3;
  if (exitRect) {
    for (let i = 0; i <= 400; i++) {
      const tt = t0 + ((t1 - t0) * i) / 400;
      const p = at(tt);
      if (p.x < exitRect.x || p.x > exitRect.x + exitRect.w || p.y < exitRect.y || p.y > exitRect.y + exitRect.h) {
        exitAt = tt;
        break;
      }
    }
  }
  exitAt = Math.min(Math.max(exitAt, t0 + 0.08), t1 - 0.2);
  const n = Math.max(2, Math.ceil((t1 - t0) * fps));
  const tk = [];
  const sk = [];
  for (let i = 0; i <= n; i++) {
    const tt = t0 + ((t1 - t0) * i) / n;
    const p = at(tt);
    tk.push([tt, [p.x, p.y], 'lin']);
    sk.push([tt, p.s, 'lin']);
  }
  const glyph = (fill, weight) => text(ch, { x: 0, y: base * 100, size: 100, weight, fill, anchor: 'middle' });
  return {
    exitAt,
    markup: motion(
      { t: tk, o: [[t0 - 0.01, 0], [t0, 1, 'lin'], [t1, 1, 'lin'], [t1 + 0.02, 0, 'lin']] },
      motion({ s: sk }, motion({ o: [[exitAt - 0.05, 1], [exitAt + 0.07, 0, 'lin']] }, glyph(light, lightWeight)), motion({ o: [[exitAt - 0.05, 0], [exitAt + 0.07, 1, 'lin']] }, glyph(dark, darkWeight)))
    ),
  };
}

function caption({ x, y, eyebrow, number, title, body = [], t0, t1 }) {
  const rise = 90;
  const id = nextId('cp');
  const numW = number ? measure(number, 72, { weight: 200 }) + 22 : 0;
  const tightTitle = { punct: 'tight' };
  require('./core').addDef(el('clipPath', { id }, el('rect', { x: x - 20, y: y - 90, width: 1300, height: 116 })));
  const head = g(
    { 'clip-path': `url(#${id})` },
    motion(
      {
        t: [[t0, [0, rise]], [t0 + 0.75, [0, 0], 'emph'], ...(t1 !== undefined ? [[t1, [0, 0], 'lin'], [t1 + 0.4, [0, -rise], 'in']] : [])],
        o: [[t0, 0], [t0 + 0.3, 1, 'out'], ...(t1 !== undefined ? [[t1, 1, 'lin'], [t1 + 0.35, 0, 'in']] : [])],
      },
      number ? text(number, { x, y, size: 72, weight: 200, fill: C.brand }) : '',
      text(title, { x: x + numW, y, size: 72, weight: 800, fill: C.text, ...tightTitle })
    )
  );
  const top = eyebrow ? motion(W3.fadeRise(t0, t1, { dy: 10 }), text(eyebrow, { x, y: y - 98, size: 24, weight: 700, fill: C.brand, ls: 0.12 })) : '';
  const lines = body.map((line, i) =>
    motion(W3.fadeRise(t0 + 0.3 + i * 0.08, t1 === undefined ? undefined : t1 + i * 0.03, { dy: 12 }), text(line, { x, y: y + 64 + i * 46, size: 30, weight: 500, fill: W3.BODY_FILL }))
  );
  return g({}, top, head, lines);
}

function stepDots(x, y, times, { tIn, tOut }) {
  const items = times.map((t, i) => {
    const cx = x + i * 26;
    return [
      el('circle', { cx, cy: y, r: 5, fill: C.border }),
      el('circle', { cx, cy: y, r: 5, fill: C.brand, opacity: 0 }, anim('opacity', [[t, 0], [t + 0.3, 1, 'out']])),
      el('circle', { cx, cy: y, r: 5, fill: 'none', stroke: C.brand, 'stroke-width': 2, opacity: 0 }, anim('r', [[t, 5], [t + 0.7, 15, 'out']]), anim('opacity', [[t, 0.8], [t + 0.7, 0, 'out']])),
    ];
  });
  const o = [[tIn, 0], [tIn + 0.4, 1, 'out']];
  if (tOut !== undefined) o.push([tOut, 1, 'lin'], [tOut + 0.4, 0, 'in']);
  return motion({ o }, items);
}

module.exports = { interp, project, unproject, camera, parallax, link, flyDigit, caption, stepDots };
