'use strict';

const { el, g, fmt, T, anim, animT, motion, clipPath, nextId, ease, EASE } = require('./core');
const { text, measure } = require('./text');

function camera(keys, content, fps = 30) {
  const tr = [];
  const sc = [];
  const back = [];
  const push = (t, k, p, c) => {
    tr.push([t, c, 'lin']);
    sc.push([t, k, 'lin']);
    back.push([t, [-p[0], -p[1]], 'lin']);
  };
  push(keys[0].t, keys[0].k, keys[0].p, keys[0].c);
  for (let i = 1; i < keys.length; i++) {
    const a = keys[i - 1];
    const b = keys[i];
    const e = ease(b.ease || 'inout');
    const n = Math.max(2, Math.ceil((b.t - a.t) * fps));
    for (let j = 1; j <= n; j++) {
      const s = e(j / n);
      const t = a.t + ((b.t - a.t) * j) / n;
      const k = Math.exp(Math.log(a.k) + (Math.log(b.k) - Math.log(a.k)) * s);
      const lerp = (u, v) => [u[0] + (v[0] - u[0]) * s, u[1] + (v[1] - u[1]) * s];
      push(t, k, lerp(a.p, b.p), lerp(a.c, b.c));
    }
  }
  const k0 = keys[0];
  return g(
    { transform: `translate(${fmt(k0.c[0])} ${fmt(k0.c[1])})` },
    animT('translate', tr),
    g(
      { transform: `scale(${fmt(k0.k)})` },
      animT('scale', sc),
      g({ transform: `translate(${fmt(-k0.p[0])} ${fmt(-k0.p[1])})` }, animT('translate', back), content)
    )
  );
}

function project(keys, t, point) {
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
  if (b !== a) s = ease(b.ease || 'inout')((t - a.t) / (b.t - a.t));
  const k = Math.exp(Math.log(a.k) + (Math.log(b.k) - Math.log(a.k)) * s);
  const p = [a.p[0] + (b.p[0] - a.p[0]) * s, a.p[1] + (b.p[1] - a.p[1]) * s];
  const c = [a.c[0] + (b.c[0] - a.c[0]) * s, a.c[1] + (b.c[1] - a.c[1]) * s];
  return { x: c[0] + k * (point[0] - p[0]), y: c[1] + k * (point[1] - p[1]), k };
}

function curveTrack(t0, t1, p0, p1, p2, easeName = 'inout', fps = 30) {
  const e = ease(easeName);
  const n = Math.max(2, Math.ceil((t1 - t0) * fps));
  const out = [];
  for (let i = 1; i <= n; i++) {
    const s = e(i / n);
    const u = 1 - s;
    out.push([t0 + ((t1 - t0) * i) / n, [u * u * p0[0] + 2 * u * s * p1[0] + s * s * p2[0], u * u * p0[1] + 2 * u * s * p1[1] + s * s * p2[1]], 'lin']);
  }
  return out;
}

function slot(words, { x, y, size, weight = 700, fill, accent, end }) {
  const id = nextId('sl');
  const clip = clipPath(id, el('rect', { x: x - size * 0.2, y: y - size * 1.12, width: size * 9, height: size * 1.46 }));
  const layers = words.map((w, i) => {
    const next = words[i + 1];
    const rise = size * 0.62;
    const chars = [...w.str];
    const markup = text(w.str, {
      x,
      y,
      size,
      weight,
      fill,
      punct: 'tight',
      perChar: (n, ch) => {
        const d = n * 0.035;
        const t = [[w.t + d, [0, rise]], [w.t + d + 0.62, [0, 0], 'emph']];
        const o = [[w.t + d, 0], [w.t + d + 0.3, 1, 'out']];
        if (next) {
          const e = n * 0.02;
          t.push([next.t + e, [0, 0], 'lin'], [next.t + e + 0.42, [0, -rise], 'in']);
          o.push([next.t + e, 1, 'lin'], [next.t + e + 0.3, 0, 'in']);
        } else if (end !== undefined) {
          o.push([end, 1, 'lin'], [end + 0.4, 0, 'in']);
        }
        const spec = { t, o };
        if (accent && '。，'.includes(ch)) spec.fill = accent;
        return spec;
      },
    });
    return markup;
  });
  return g({ 'clip-path': clip }, layers);
}

function flyText(str, { from, to, t0, t1, weight = 700, fill, lift = -120 }) {
  const base = 100;
  const cx = (from.x + to.x) / 2;
  const cy = Math.min(from.y, to.y) + lift;
  const path = `M${fmt(from.x)} ${fmt(from.y)}Q${fmt(cx)} ${fmt(cy)} ${fmt(to.x)} ${fmt(to.y)}`;
  const s0 = from.size / base;
  const s1 = to.size / base;
  return g(
    { opacity: 0 },
    anim('opacity', [[t0, 0], [t0 + 0.08, 1, 'out'], [t1 - 0.06, 1, 'lin'], [t1 + 0.04, 0, 'lin']]),
    el('animateMotion', { path, begin: T(t0), dur: `${fmt(t1 - t0)}s`, fill: 'freeze', calcMode: 'spline', keyPoints: '0;1', keyTimes: '0;1', keySplines: EASE.inout.join(' ') }),
    g(
      { transform: `scale(${fmt(s0)})` },
      animT('scale', [[t0, s0], [t1, s1, 'inout']]),
      text(str, { x: 0, y: base * 0.36, size: base, weight, fill, anchor: 'middle' })
    )
  );
}

function lightArc(a, b, t0, dur, { color = '#627D8D', bend = -160 } = {}) {
  const mx = (a.x + b.x) / 2;
  const my = Math.min(a.y, b.y) + bend;
  const d = `M${fmt(a.x)} ${fmt(a.y)}Q${fmt(mx)} ${fmt(my)} ${fmt(b.x)} ${fmt(b.y)}`;
  return g(
    {},
    el('path', { d, fill: 'none', stroke: color, 'stroke-width': 2, 'stroke-dasharray': '2 7', 'stroke-linecap': 'round', opacity: 0 }, anim('opacity', [[t0, 0], [t0 + 0.2, 0.45, 'out'], [t0 + dur, 0.45, 'lin'], [t0 + dur + 0.4, 0, 'out']])),
    el(
      'path',
      { d, fill: 'none', stroke: color, 'stroke-width': 5, 'stroke-linecap': 'round', pathLength: 1, 'stroke-dasharray': '0.14 1.3', 'stroke-dashoffset': 0.14, opacity: 0 },
      anim('stroke-dashoffset', [[t0, 0.14], [t0 + dur, -1.0, 'inout']]),
      anim('opacity', [[t0, 0], [t0 + 0.1, 0.9, 'out'], [t0 + dur - 0.1, 0.9, 'lin'], [t0 + dur, 0, 'lin']])
    ),
    el('circle', { cx: b.x, cy: b.y, r: 6, fill: 'none', stroke: color, 'stroke-width': 2, opacity: 0 }, anim('r', [[t0 + dur - 0.05, 6], [t0 + dur + 0.6, 40, 'out']]), anim('opacity', [[t0 + dur - 0.05, 0.8], [t0 + dur + 0.6, 0, 'out']]))
  );
}

function rings(cx, cy, t, { count = 3, r0 = 30, r1 = 150, color = '#FFFFFF', width = 2.5, gap = 0.14, dur = 0.9, peak = 0.7 } = {}) {
  const out = [];
  for (let i = 0; i < count; i++) {
    const s = t + i * gap;
    out.push(el('circle', { cx, cy, r: r0, fill: 'none', stroke: color, 'stroke-width': width, opacity: 0 }, anim('r', [[s, r0], [s + dur, r1, 'out']]), anim('opacity', [[s, peak], [s + dur, 0, 'out']])));
  }
  return out;
}

module.exports = { camera, project, curveTrack, slot, flyText, lightArc, rings };
