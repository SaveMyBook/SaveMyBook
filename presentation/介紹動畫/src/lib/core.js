'use strict';

const fmt = (v) => {
  if (typeof v === 'number') {
    if (!Number.isFinite(v)) throw new Error(`數值錯誤：${v}`);
    const r = Math.round(v * 1000) / 1000;
    return String(Object.is(r, -0) ? 0 : r);
  }
  return String(v);
};

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

// 動畫在 begin 之前會套用元素本身的屬性值；若元素沒有設定 opacity，淡入動畫開始前會以不透明顯示一瞬間，
// 因此元素沒有指定 opacity 時，改用第一個透明度動畫的起始值作為初始值。
function baseOpacity(attrs, kids) {
  if (attrs && attrs.opacity !== undefined) return attrs;
  for (const c of kids) {
    if (typeof c === 'string' && c.startsWith('<animate attributeName="opacity" values="')) {
      const v = c.slice(41, c.indexOf('"', 41)).split(';')[0];
      return { ...(attrs || {}), opacity: v };
    }
  }
  return attrs;
}

function el(tag, attrs, ...children) {
  const kids = children.flat(Infinity);
  attrs = baseOpacity(attrs, kids);
  let a = '';
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v === undefined || v === null || v === false) continue;
    a += ` ${k}="${esc(Array.isArray(v) ? v.map(fmt).join(' ') : fmt(v))}"`;
  }
  const inner = kids.filter((c) => c !== undefined && c !== null && c !== false && c !== '').join('');
  return inner ? `<${tag}${a}>${inner}</${tag}>` : `<${tag}${a}/>`;
}

const g = (attrs, ...children) => el('g', attrs, ...children);

const EASE = {
  lin: [0, 0, 1, 1],
  out: [0.16, 1, 0.3, 1],
  emph: [0.2, 0.9, 0.1, 1],
  inout: [0.65, 0, 0.35, 1],
  soft: [0.37, 0, 0.63, 1],
  std: [0.4, 0, 0.2, 1],
  in: [0.5, 0, 0.75, 0],
  gentle: [0.25, 0.1, 0.25, 1],
  decel: [0, 0, 0.2, 1],
};

function bezier([x1, y1, x2, y2]) {
  const cx = 3 * x1;
  const bx = 3 * (x2 - x1) - cx;
  const ax = 1 - cx - bx;
  const cy = 3 * y1;
  const by = 3 * (y2 - y1) - cy;
  const ay = 1 - cy - by;
  const sx = (t) => ((ax * t + bx) * t + cx) * t;
  const sy = (t) => ((ay * t + by) * t + cy) * t;
  const dx = (t) => (3 * ax * t + 2 * bx) * t + cx;
  return (x) => {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    let t = x;
    for (let i = 0; i < 8; i++) {
      const e = sx(t) - x;
      const d = dx(t);
      if (Math.abs(e) < 1e-7 || Math.abs(d) < 1e-6) break;
      t -= e / d;
    }
    t = Math.min(1, Math.max(0, t));
    return sy(t);
  };
}

const ease = (name) => bezier(EASE[name]);

function sample(t0, t1, fn, fps = 30) {
  const n = Math.max(2, Math.ceil((t1 - t0) * fps));
  const out = [];
  for (let i = 0; i <= n; i++) {
    const t = t0 + ((t1 - t0) * i) / n;
    out.push([t, fn((t - t0) / (t1 - t0))]);
  }
  return out;
}

const clock = { base: null, end: null };

const T = (t) => {
  if (!Number.isFinite(t)) throw new Error(`時間錯誤：${t}`);
  if (clock.end !== null && t > clock.end + 1e-6) throw new Error(`動畫時間 ${t} 超過片長 ${clock.end}`);
  return clock.base ? `${clock.base}.begin+${fmt(t)}s` : `${fmt(t)}s`;
};

let uid = 0;
const nextId = (prefix = 'i') => `${prefix}${(uid++).toString(36)}`;

const defs = [];
const addDef = (markup) => {
  defs.push(markup);
};

const valueStr = (v) => (Array.isArray(v) ? v.map(fmt).join(' ') : fmt(v));

function track(frames) {
  const out = [];
  for (const f of frames) {
    const [t, v, ease = 'emph'] = f;
    if (ease === 'step') {
      const prev = out[out.length - 1];
      if (!prev) throw new Error('step 不能是第一個影格');
      out.push([t - 0.001, prev[1], 'lin']);
      out.push([t, v, 'lin']);
    } else {
      out.push([t, v, ease]);
    }
  }
  for (let i = 1; i < out.length; i++) {
    if (!(out[i][0] > out[i - 1][0])) throw new Error(`影格時間必須遞增：${out[i - 1][0]} → ${out[i][0]}`);
  }
  return out;
}

function anim(attr, frames, { tag = 'animate', type } = {}) {
  const f = track(frames);
  if (f.length === 1) {
    return el('set', { attributeName: attr, to: valueStr(f[0][1]), begin: T(f[0][0]), fill: 'freeze' });
  }
  const t0 = f[0][0];
  const dur = f[f.length - 1][0] - t0;
  const keyTimes = f.map((x, i) => (i === f.length - 1 ? 1 : Math.round(((x[0] - t0) / dur) * 1e6) / 1e6));
  const splines = f.slice(1).map((x) => {
    const e = EASE[x[2]];
    if (!e) throw new Error(`未知緩動：${x[2]}`);
    return e.join(' ');
  });
  return el(tag, {
    attributeName: attr,
    type,
    values: f.map((x) => valueStr(x[1])).join(';'),
    keyTimes: keyTimes.join(';'),
    keySplines: splines.join(';'),
    calcMode: 'spline',
    begin: T(t0),
    dur: `${fmt(dur)}s`,
    fill: 'freeze',
  });
}

const animT = (type, frames) => anim('transform', frames, { tag: 'animateTransform', type });

const first = (frames) => frames[0][1];

function during(start, end) {
  return el('set', { attributeName: 'display', to: 'inline', begin: T(start), end: T(end) });
}

function scene(start, end, ...children) {
  return g({ display: 'none' }, during(start, end), ...children);
}

function motion(opts, ...children) {
  const { x = 0, y = 0, t, s, r, o, origin = [0, 0], attrs = {}, fill } = opts;
  let inner = children;
  const [ox, oy] = origin;
  const pivot = s || r;
  if (pivot && (ox || oy)) inner = [g({ transform: `translate(${fmt(-ox)} ${fmt(-oy)})` }, inner)];
  if (s) {
    const sv = first(s);
    inner = [g({ transform: `scale(${valueStr(sv)})` }, animT('scale', s), inner)];
  }
  if (r) inner = [g({ transform: `rotate(${valueStr(first(r))})` }, animT('rotate', r), inner)];
  if (pivot && (ox || oy)) inner = [g({ transform: `translate(${fmt(ox)} ${fmt(oy)})` }, inner)];
  if (t) inner = [g({ transform: `translate(${valueStr(first(t))})` }, animT('translate', t), inner)];
  const outer = { ...attrs };
  if (x || y) outer.transform = `translate(${fmt(x)} ${fmt(y)})`;
  if (o) outer.opacity = first(o);
  if (fill) outer.fill = typeof fill === 'string' ? fill : first(fill);
  return g(outer, o ? anim('opacity', o) : '', fill && typeof fill !== 'string' ? anim('fill', fill) : '', inner);
}

const fade = (t0, t1, from = 0, to = 1, ease = 'out') => [[t0, from], [t1, to, ease]];

function fadeInOut(tIn, dIn, tOut, dOut, easeIn = 'out', easeOut = 'in') {
  return [[tIn, 0], [tIn + dIn, 1, easeIn], [tOut, 1, 'lin'], [tOut + dOut, 0, easeOut]];
}

function linearGradient(id, stops, { x1 = 0, y1 = 0, x2 = 0, y2 = 1, units, transform } = {}) {
  addDef(
    el(
      'linearGradient',
      { id, x1, y1, x2, y2, gradientUnits: units, gradientTransform: transform },
      stops.map(([offset, color, opacity = 1]) => el('stop', { offset, 'stop-color': color, 'stop-opacity': opacity === 1 ? undefined : opacity }))
    )
  );
  return `url(#${id})`;
}

function radialGradient(id, stops, { cx = 0.5, cy = 0.5, r = 0.5, fx, fy, units, transform } = {}) {
  addDef(
    el(
      'radialGradient',
      { id, cx, cy, r, fx, fy, gradientUnits: units, gradientTransform: transform },
      stops.map(([offset, color, opacity = 1]) => el('stop', { offset, 'stop-color': color, 'stop-opacity': opacity === 1 ? undefined : opacity }))
    )
  );
  return `url(#${id})`;
}

function clipPath(id, ...shapes) {
  addDef(el('clipPath', { id }, ...shapes));
  return `url(#${id})`;
}

const rrect = (x, y, w, h, r, attrs = {}, ...children) => el('rect', { x, y, width: w, height: h, rx: r || undefined, ...attrs }, ...children);

function rrectPath(x, y, w, h, r) {
  const k = 0.5523 * r;
  return [
    `M${fmt(x + r)} ${fmt(y)}`,
    `H${fmt(x + w - r)}`,
    `C${fmt(x + w - r + k)} ${fmt(y)} ${fmt(x + w)} ${fmt(y + r - k)} ${fmt(x + w)} ${fmt(y + r)}`,
    `V${fmt(y + h - r)}`,
    `C${fmt(x + w)} ${fmt(y + h - r + k)} ${fmt(x + w - r + k)} ${fmt(y + h)} ${fmt(x + w - r)} ${fmt(y + h)}`,
    `H${fmt(x + r)}`,
    `C${fmt(x + r - k)} ${fmt(y + h)} ${fmt(x)} ${fmt(y + h - r + k)} ${fmt(x)} ${fmt(y + h - r)}`,
    `V${fmt(y + r)}`,
    `C${fmt(x)} ${fmt(y + r - k)} ${fmt(x + r - k)} ${fmt(y)} ${fmt(x + r)} ${fmt(y)}`,
    'Z',
  ].join('');
}

function drawPath(d, t0, dur, { stroke, width = 2, ease = 'inout', attrs = {} } = {}) {
  return el(
    'path',
    {
      d,
      fill: 'none',
      stroke,
      'stroke-width': width,
      'stroke-linecap': 'round',
      'stroke-linejoin': 'round',
      pathLength: 1,
      'stroke-dasharray': '1 1.02',
      'stroke-dashoffset': 1.01,
      opacity: 0,
      ...attrs,
    },
    anim('stroke-dashoffset', [[t0, 1.01], [t0 + dur, 0, ease]]),
    anim('opacity', [[t0, 0], [t0 + 0.05, 1, 'lin']])
  );
}

function penDot(d, t0, dur, { ease = 'inout', r = 8, fill } = {}) {
  return el(
    'circle',
    { r, fill, opacity: 0 },
    el('animateMotion', { path: d, begin: T(t0), dur: `${fmt(dur)}s`, fill: 'freeze', calcMode: 'spline', keyPoints: '0;1', keyTimes: '0;1', keySplines: EASE[ease].join(' ') }),
    anim('opacity', [[t0, 0], [t0 + Math.min(0.12, dur * 0.2), 1, 'out'], [t0 + dur - Math.min(0.1, dur * 0.2), 1, 'lin'], [t0 + dur + 0.18, 0, 'out']])
  );
}

function shadowStack(x, y, w, h, r, { layers = 7, spread = 3, opacity = 0.022, dy = 6, color = '#0B1A26' } = {}) {
  const out = [];
  for (let i = layers; i >= 1; i--) {
    const e = i * spread;
    out.push(rrect(x - e, y - e + dy, w + e * 2, h + e * 2, r + e, { fill: color, 'fill-opacity': opacity }));
  }
  return out;
}

function blurFilter(id, std, { region = '-40%', size = '180%', regionY, sizeY } = {}) {
  addDef(el('filter', { id, x: region, y: regionY || region, width: size, height: sizeY || size, 'color-interpolation-filters': 'sRGB' }, el('feGaussianBlur', { stdDeviation: std })));
  return `url(#${id})`;
}

function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function resetDefs() {
  defs.length = 0;
  uid = 0;
}

module.exports = {
  bezier,
  ease,
  sample,
  fmt,
  esc,
  el,
  g,
  EASE,
  clock,
  T,
  nextId,
  defs,
  addDef,
  anim,
  animT,
  track,
  during,
  scene,
  motion,
  fade,
  fadeInOut,
  linearGradient,
  radialGradient,
  clipPath,
  rrect,
  rrectPath,
  drawPath,
  shadowStack,
  penDot,
  blurFilter,
  rng,
  resetDefs,
  valueStr,
};
