'use strict';

const { el, g, fmt, anim, animT, motion, clipPath, linearGradient, radialGradient, rrect, rrectPath, drawPath, penDot, nextId, ease, addDef } = require('./core');
const { text, measure } = require('./text');
const { staticLogo } = require('./logo');
const { bookCover } = require('./appui');
const C = require('./palette');

const GEO = { fx: 780, fy: 150, w: 400, h: 720, dx: 64, dy: -38 };
const HEAD = 330;
const SIDE = 18;
const GAP_X = 16;
const GAP_Y = 14;
const BASE = 24;
const DEPTH = 0.78;
const SCREEN_SCALE = 0.72;

function doorRect(i) {
  const { fx, fy, w, h } = GEO;
  const dw = (w - SIDE * 2 - GAP_X) / 2;
  const dh = (h - HEAD - BASE - GAP_Y) / 2;
  const col = i % 2;
  const row = Math.floor(i / 2);
  return { x: fx + SIDE + col * (dw + GAP_X), y: fy + HEAD + row * (dh + GAP_Y), w: dw, h: dh, col, row };
}

function screenRect() {
  const w = 240 * SCREEN_SCALE;
  const h = 320 * SCREEN_SCALE;
  return { x: GEO.fx + (GEO.w - w) / 2, y: GEO.fy + 34, w, h };
}

function lockupMetrics(size) {
  const logoH = size * 1.18;
  const s = logoH / 1258;
  const logoW = 1620 * s;
  const gap = size * 0.36;
  const textW = measure('救「舊」我的書', size, { weight: 700 });
  return { logoH, logoW, s, gap, textW, width: logoW + gap + textW };
}

function lockup(cx, cy, size, { textFill = C.text } = {}) {
  const m = lockupMetrics(size);
  const left = cx - m.width / 2;
  const logo = g({ transform: `translate(${fmt(left)} ${fmt(cy - m.logoH / 2)}) scale(${fmt(m.s)}) translate(-210 -382)` }, staticLogo());
  const word = text('救「舊」我的書', { x: left + m.logoW + m.gap, y: cy + size * 0.38, size, weight: 700, fill: textFill, perChar: (n) => (n >= 1 && n <= 3 ? { fill: C.brand } : null) });
  return { markup: [logo, word], metrics: m };
}

const PLATE = { size: 17 };
function platePos() {
  const sr = screenRect();
  return { x: GEO.fx + GEO.w / 2, y: sr.y + sr.h + 12 + 34 };
}

function doorAngles(spec) {
  const { unlatch, swing, settle, angle = 100, close } = spec;
  const pts = [[unlatch - 0.001, 0]];
  const unl = ease('out');
  for (let i = 1; i <= 4; i++) pts.push([unlatch + (0.12 * i) / 4, 5 * unl(i / 4)]);
  pts.push([swing, 4.2]);
  const sw = ease('emph');
  const n = Math.ceil((settle[0] - swing) * 40);
  for (let i = 1; i <= n; i++) pts.push([swing + ((settle[0] - swing) * i) / n, 4.2 + (angle + 4 - 4.2) * sw(i / n)]);
  const st = ease('soft');
  const m = Math.ceil((settle[1] - settle[0]) * 30);
  for (let i = 1; i <= m; i++) pts.push([settle[0] + ((settle[1] - settle[0]) * i) / m, angle + 4 - 4 * st(i / m)]);
  if (close) {
    const [c0, c1] = close;
    pts.push([c0, angle]);
    const ce = ease('inout');
    const k = Math.ceil((c1 - c0) * 40);
    for (let i = 1; i <= k; i++) pts.push([c0 + ((c1 - c0) * i) / k, angle * (1 - ce(i / k))]);
    pts.push([c1 + 0.08, -1.2], [c1 + 0.2, 0]);
  }
  return pts;
}

function doorTracks(pts, hinge) {
  const kx = GEO.dx / GEO.w;
  const ky = -GEO.dy / GEO.w;
  const sx = [];
  const sk = [];
  const shadeT = [];
  const facing = [];
  for (const [t, deg] of pts) {
    const th = (deg * Math.PI) / 180;
    let s = hinge === 'left' ? Math.cos(th) - kx * Math.sin(th) : Math.cos(th) + kx * Math.sin(th);
    facing.push([t, s > 0]);
    if (Math.abs(s) < 0.004) s = s < 0 ? -0.004 : 0.004;
    const phi = (Math.atan(ky * Math.sin(th)) * 180) / Math.PI;
    sx.push([t, [s, 1], 'lin']);
    sk.push([t, hinge === 'left' ? phi : -phi, 'lin']);
    shadeT.push([t, Math.min(0.2, Math.max(0, Math.sin(th)) * 0.2), 'lin']);
  }
  return { sx, sk, shadeT, facing };
}

function facingTrack(facing) {
  const track = [[facing[0][0], 1]];
  let state = true;
  for (const [t, f] of facing) {
    if (f !== state) {
      const last = track[track.length - 1][0];
      if (t - 0.05 > last) track.push([t - 0.05, state ? 1 : 0, 'lin']);
      track.push([Math.max(t, last + 0.01), f ? 1 : 0, 'lin']);
      state = f;
    }
  }
  return track;
}

function interior(r, id, { books = [], inside } = {}) {
  const dx = GEO.dx * DEPTH;
  const dy = GEO.dy * DEPTH;
  const clip = clipPath(`${id}o`, rrect(r.x, r.y, r.w, r.h, 7));
  const back = el('rect', { x: r.x + dx, y: r.y + dy, width: r.w, height: r.h, fill: '#D5DDE2' });
  const left = el('path', { d: `M${fmt(r.x)} ${fmt(r.y)}L${fmt(r.x + dx)} ${fmt(r.y + dy)}L${fmt(r.x + dx)} ${fmt(r.y + r.h + dy)}L${fmt(r.x)} ${fmt(r.y + r.h)}Z`, fill: '#C4CED5' });
  const floor = el('path', {
    d: `M${fmt(r.x)} ${fmt(r.y + r.h)}L${fmt(r.x + r.w)} ${fmt(r.y + r.h)}L${fmt(r.x + r.w + dx)} ${fmt(r.y + r.h + dy)}L${fmt(r.x + dx)} ${fmt(r.y + r.h + dy)}Z`,
    fill: '#E8EDF0',
  });
  const topShade = linearGradient(`${id}s`, [
    [0, '#0B1A26', 0.2],
    [1, '#0B1A26', 0],
  ]);
  const content = books.map((b) => {
    const bw = b.w || 70;
    const bh = b.h || 98;
    const bx = r.x + (b.at || 0.42) * r.w + dx * 0.55;
    const by = r.y + r.h + dy * 0.55 - bh;
    return [el('ellipse', { cx: bx + bw / 2 + 4, cy: by + bh + 1, rx: bw * 0.62, ry: 5, fill: '#0B1A26', 'fill-opacity': 0.14 }), bookCover(bx, by, bw, bh, 3, b)];
  });
  return g({ 'clip-path': clip }, back, left, floor, content, inside || '', el('rect', { x: r.x, y: r.y, width: r.w, height: r.h * 0.5, fill: topShade }));
}

function doorPanel(r, label, labelTrack) {
  const glare = `M${fmt(r.x + r.w * 0.5)} ${fmt(r.y)}L${fmt(r.x + r.w * 0.66)} ${fmt(r.y)}L${fmt(r.x + r.w * 0.38)} ${fmt(r.y + r.h)}L${fmt(r.x + r.w * 0.22)} ${fmt(r.y + r.h)}Z`;
  const glare2 = `M${fmt(r.x + r.w * 0.71)} ${fmt(r.y)}L${fmt(r.x + r.w * 0.75)} ${fmt(r.y)}L${fmt(r.x + r.w * 0.47)} ${fmt(r.y + r.h)}L${fmt(r.x + r.w * 0.43)} ${fmt(r.y + r.h)}Z`;
  const labelText = text(label, { x: r.x + 36, y: r.y + 28, size: 13.5, weight: 700, fill: '#FFFFFF', anchor: 'middle' });
  return g(
    {},
    rrect(r.x, r.y, r.w, r.h, 7, { fill: '#F4F8FA', 'fill-opacity': 0.4 }),
    el('path', { d: glare, fill: '#FFFFFF', 'fill-opacity': 0.34 }),
    el('path', { d: glare2, fill: '#FFFFFF', 'fill-opacity': 0.28 }),
    rrect(r.x + 0.8, r.y + 0.8, r.w - 1.6, r.h - 1.6, 6.5, { fill: 'none', stroke: '#FFFFFF', 'stroke-opacity': 0.95, 'stroke-width': 1.6 }),
    rrect(r.x, r.y, r.w, r.h, 7, { fill: 'none', stroke: '#8FA0AB', 'stroke-opacity': 0.5, 'stroke-width': 1 }),
    rrect(r.x + 11, r.y + 11, 50, 24, 7, { fill: C.brand }),
    labelTrack ? motion({ o: labelTrack }, labelText) : labelText
  );
}

function lockLed(r, lock) {
  const cx = r.col === 0 ? r.x + r.w + GAP_X / 2 : r.x - GAP_X / 2;
  const cy = r.y + r.h / 2 + (r.col === 0 ? -9 : 9);
  const led = [el('circle', { cx, cy, r: 3.4, fill: '#AEB9C1' })];
  if (lock) {
    const [on, off] = lock;
    const o = [[on, 0], [on + 0.15, 1, 'out']];
    const halo = [[on, 0], [on + 0.2, 0.35, 'out'], [on + 1.2, 0.2, 'soft']];
    if (off) {
      o.push([off, 1, 'lin'], [off + 0.3, 0, 'out']);
      halo.push([off, 0.2, 'lin'], [off + 0.3, 0, 'out']);
    }
    led.push(el('circle', { cx, cy, r: 8, fill: C.kiosk.online, opacity: 0 }, anim('opacity', halo)), el('circle', { cx, cy, r: 3.4, fill: C.kiosk.online, opacity: 0 }, anim('opacity', o)));
  }
  return led;
}

function hinged(r, spec, content) {
  const hinge = r.col === 0 ? 'left' : 'right';
  const { sx, sk, shadeT } = doorTracks(doorAngles(spec), hinge);
  const hx = hinge === 'left' ? r.x : r.x + r.w;
  return g(
    { transform: `translate(${fmt(hx)} ${fmt(r.y)})` },
    g(
      { transform: 'scale(1 1)' },
      animT('scale', sx),
      g({ transform: 'skewY(0)' }, animT('skewY', sk), g({ transform: `translate(${fmt(-hx)} ${fmt(-r.y)})` }, content, rrect(r.x, r.y, r.w, r.h, 7, { fill: '#2B3B47', opacity: 0 }, anim('opacity', shadeT))))
    )
  );
}

const XRAY = {
  relay: { x: 798, y: 196, w: 64, h: 46 },
  esp: { x: 1096, y: 196, w: 66, h: 42 },
  psu: { x: 930, y: 806, w: 100, h: 40 },
  buck: { x: 1044, y: 816, w: 36, h: 22 },
};

function xrayAnchors() {
  const lockY = [0, 2].map((i) => doorRect(i).y + doorRect(i).h / 2);
  return {
    relay: { x: XRAY.relay.x + XRAY.relay.w / 2, y: XRAY.relay.y + XRAY.relay.h / 2 },
    esp: { x: XRAY.esp.x + XRAY.esp.w / 2, y: XRAY.esp.y + XRAY.esp.h / 2 },
    screen: { x: screenRect().x + screenRect().w + 12, y: screenRect().y + 110 },
    lock: { x: 980, y: lockY[0] },
    psu: { x: XRAY.psu.x + XRAY.psu.w / 2, y: XRAY.psu.y + XRAY.psu.h / 2 },
  };
}

function xrayLayer(t0, t1, frontPath, sideFace, topFace) {
  const id = nextId('xr');
  const B = C.brand;
  const o = [[t0, 0], [t0 + 0.35, 1, 'out'], [t1 - 0.4, 1, 'lin'], [t1, 0, 'in']];
  addDef(
    el(
      'pattern',
      { id: `${id}p`, width: 20, height: 20, patternUnits: 'userSpaceOnUse' },
      el('path', { d: 'M20 0H0V20', fill: 'none', stroke: B, 'stroke-opacity': 0.14, 'stroke-width': 1 })
    )
  );
  const comp = (r, t, extra = []) => [
    el('rect', { x: r.x, y: r.y, width: r.w, height: r.h, rx: 4, fill: B, opacity: 0 }, anim('opacity', [[t + 0.35, 0], [t + 0.7, 0.12, 'out']])),
    drawPath(rrectPath(r.x, r.y, r.w, r.h, 4), t, 0.5, { stroke: B, width: 2 }),
    extra,
  ];
  const tc = t0 + 0.25;
  const relayCubes = [0, 1, 2, 3].map((i) => drawPath(rrectPath(XRAY.relay.x + 5 + i * 14.5, XRAY.relay.y + 6, 11, 16, 2), tc + 0.3 + i * 0.05, 0.3, { stroke: B, width: 1.5 }));
  const espChip = drawPath(rrectPath(XRAY.esp.x + 12, XRAY.esp.y + 8, 30, 24, 2), tc + 0.45, 0.35, { stroke: B, width: 1.6 });
  const espAntenna = drawPath(`M${XRAY.esp.x + 48} ${XRAY.esp.y + 30}V${XRAY.esp.y + 10}h5v14h5V${XRAY.esp.y + 10}`, tc + 0.55, 0.35, { stroke: B, width: 1.4 });
  const vents = [0, 1, 2, 3, 4].map((i) => drawPath(`M${XRAY.psu.x + 14 + i * 16} ${XRAY.psu.y + 10}v20`, tc + 0.9 + i * 0.04, 0.25, { stroke: B, width: 1.4 }));
  const locks = [0, 1, 2, 3].map((i) => {
    const r = doorRect(i);
    const x = r.col === 0 ? 973 : 981;
    return comp({ x, y: r.y + r.h / 2 - 20, w: 7, h: 40 }, tc + 0.6 + i * 0.07);
  });
  const wires = [
    ['M1104 196V164H830V196', tc + 0.55, 0.8],
    ['M830 242V494H980V760', tc + 0.8, 1.0],
    ['M1010 806V494H1150V238', tc + 0.95, 1.0],
    [`M1096 300H${screenRect().x + screenRect().w + 12}`, tc + 0.7, 0.3],
    [`M1096 308H${screenRect().x + screenRect().w + 12}`, tc + 0.72, 0.3],
    [`M1096 316H${screenRect().x + screenRect().w + 12}`, tc + 0.74, 0.3],
  ];
  const glow = radialGradient(`${id}g`, [
    [0, '#FFFFFF', 1],
    [0.35, B, 0.85],
    [1, B, 0],
  ]);
  const sr = screenRect();
  const hole = rrectPath(sr.x - 14, sr.y - 14, sr.w + 28, sr.h + 28, 15);
  const pp = platePos();
  const pm = lockupMetrics(PLATE.size);
  const plateHole = rrectPath(pp.x - pm.width / 2 - 10, pp.y - 18, pm.width + 20, 36, 8);
  const clip = clipPath(`${id}c`, el('path', { d: `${frontPath}${hole}${plateHole}`, 'clip-rule': 'evenodd' }), el('path', { d: sideFace }), el('path', { d: topFace }));
  const badges = [0, 1, 2, 3].map((i) => {
    const r = doorRect(i);
    return [rrect(r.x + 11, r.y + 11, 50, 24, 7, { fill: C.brand }), text(`A0${i + 1}`, { x: r.x + 36, y: r.y + 28, size: 13.5, weight: 700, fill: '#FFFFFF', anchor: 'middle' })];
  });
  return motion(
    { o },
    g(
      { 'clip-path': clip },
      el('path', { d: `${frontPath}${hole}${plateHole}`, 'fill-rule': 'evenodd', fill: '#F7FAFC', 'fill-opacity': 0.72 }),
      el('path', { d: sideFace, fill: '#EEF3F6', 'fill-opacity': 0.72 }),
      el('path', { d: topFace, fill: '#F7FAFC', 'fill-opacity': 0.72 }),
      el('rect', { x: GEO.fx - 100, y: GEO.fy - 100, width: GEO.w + 300, height: GEO.h + 200, fill: `url(#${id}p)` })
    ),
    drawPath(frontPath, t0 + 0.1, 0.8, { stroke: B, width: 1.4 }),
    drawPath(rrectPath(screenRect().x - 12, screenRect().y - 12, screenRect().w + 24, screenRect().h + 24, 14), t0 + 0.2, 0.6, { stroke: B, width: 1.6 }),
    [0, 1, 2, 3].map((i) => {
      const r = doorRect(i);
      return el('path', { d: rrectPath(r.x, r.y, r.w, r.h, 7), fill: 'none', stroke: B, 'stroke-opacity': 0.35, 'stroke-width': 1.2, 'stroke-dasharray': '5 5' });
    }),
    wires.map(([d, t, dur]) => [drawPath(d, t, dur, { stroke: B, width: 1.8 }), penDot(d, t, dur, { r: 7, fill: glow })]),
    comp(XRAY.relay, tc, relayCubes),
    comp(XRAY.esp, tc + 0.15, [espChip, espAntenna]),
    comp(XRAY.psu, tc + 0.5, vents),
    comp(XRAY.buck, tc + 0.6),
    locks,
    badges
  );
}

function cabinet(opts) {
  const { build, screen, doors = [], plate = true, xray } = opts;
  const { fx, fy, w, h, dx, dy } = GEO;
  const id = nextId('cb');
  const t0 = build;
  const frontGrad = linearGradient(`${id}f`, [
    [0, '#FFFFFF'],
    [0.55, '#F8FAFB'],
    [1, '#ECF0F3'],
  ]);
  const sideGrad = linearGradient(`${id}s`, [
    [0, '#DCE3E8'],
    [1, '#C3CDD4'],
  ]);
  const topGrad = linearGradient(`${id}t`, [
    [0, '#F9FAFB'],
    [1, '#E7ECEF'],
  ]);
  const floorShadow = radialGradient(`${id}fs`, [
    [0, '#0B1A26', 0.22],
    [0.5, '#0B1A26', 0.09],
    [1, '#0B1A26', 0],
  ]);

  const topFace = `M${fx} ${fy}L${fx + w} ${fy}L${fx + w + dx} ${fy + dy}L${fx + dx} ${fy + dy}Z`;
  const sideFace = `M${fx + w} ${fy}L${fx + w + dx} ${fy + dy}L${fx + w + dx} ${fy + h + dy}L${fx + w} ${fy + h}Z`;
  const frontPath = rrectPath(fx, fy, w, h, 5);
  const sr = screenRect();
  const bezel = { x: sr.x - 12, y: sr.y - 12, w: sr.w + 24, h: sr.h + 24 };
  const instant = t0 === null;
  const fadeFill = (a, b) => (instant ? {} : { o: [[t0 + a, 0], [t0 + b, 1, 'out']] });

  const outlines = instant ? '' : g(
    {},
    anim('opacity', [[t0 + 1.55, 1], [t0 + 2.2, 0, 'soft']]),
    drawPath(rrectPath(bezel.x, bezel.y, bezel.w, bezel.h, 14), t0, 0.8, { stroke: C.brand, width: 1.8 }),
    drawPath(frontPath, t0 + 0.2, 1.0, { stroke: C.brand, width: 2 }),
    drawPath(topFace, t0 + 0.42, 0.7, { stroke: C.brand, width: 1.8 }),
    drawPath(sideFace, t0 + 0.46, 0.8, { stroke: C.brand, width: 1.8 }),
    [0, 1, 2, 3].map((i) => {
      const r = doorRect(i);
      return drawPath(rrectPath(r.x, r.y, r.w, r.h, 7), t0 + 0.5 + i * 0.07, 0.62, { stroke: C.brand, width: 1.6 });
    })
  );

  const bodyFill = motion(
    fadeFill(1.0, 1.7),
    el('ellipse', { cx: fx + w / 2 + dx / 2, cy: fy + h + 2, rx: 330, ry: 34, fill: floorShadow }),
    el('path', { d: sideFace, fill: sideGrad }),
    el('path', { d: topFace, fill: topGrad }),
    el('path', { d: frontPath, fill: frontGrad }),
    el('path', { d: frontPath, fill: 'none', stroke: '#D3DBE0', 'stroke-width': 1 }),
    el('rect', { x: fx, y: fy + h - 14, width: w, height: 14, fill: '#E1E7EB' }),
    el('path', { d: `M${fx + w} ${fy}L${fx + w + dx} ${fy + dy}`, stroke: '#FFFFFF', 'stroke-width': 1.4 })
  );

  const bezelFill = motion(fadeFill(0.9, 1.35), rrect(bezel.x, bezel.y, bezel.w, bezel.h, 14, { fill: C.kiosk.bezel }), rrect(bezel.x + 1, bezel.y + 1, bezel.w - 2, bezel.h - 2, 13, { fill: 'none', stroke: '#FFFFFF', 'stroke-opacity': 0.12, 'stroke-width': 1 }));

  const screenGroup = motion(instant ? {} : { o: [[t0 + 1.45, 0], [t0 + 1.8, 1, 'out']] }, g({ transform: `translate(${fmt(sr.x)} ${fmt(sr.y)}) scale(${fmt(SCREEN_SCALE)})` }, screen));

  const pp = platePos();
  const plateMarkup = plate ? lockup(pp.x, pp.y, PLATE.size).markup : '';

  const doorLayers = [0, 1, 2, 3].map((i) => {
    const r = doorRect(i);
    const spec = doors[i] || {};
    const did = `${id}d${i}`;
    const inner = interior(r, did, { books: spec.books || [], inside: spec.inside });
    const labelTrack = spec.open ? facingTrack(doorTracks(doorAngles(spec.open), r.col === 0 ? 'left' : 'right').facing) : undefined;
    const panel = doorPanel(r, `A0${i + 1}`, labelTrack);
    return motion(fadeFill(1.2 + i * 0.06, 1.75 + i * 0.06), inner, lockLed(r, spec.lock), spec.open ? hinged(r, spec.open, panel) : panel, spec.front || '');
  });

  const sheenGrad = linearGradient(`${id}sh`, [
    [0, '#FFFFFF', 0],
    [0.5, '#FFFFFF', 0.55],
    [1, '#FFFFFF', 0],
  ], { x1: 0, y1: 0, x2: 1, y2: 0 });
  const sheenClip = clipPath(`${id}sc`, el('path', { d: frontPath }), el('path', { d: sideFace }), el('path', { d: topFace }));
  const sheen = instant
    ? ''
    : g(
        { 'clip-path': sheenClip },
        el('rect', { x: fx - 500, y: fy - 300, width: 200, height: h + 600, fill: sheenGrad, transform: `rotate(18 ${fx + w / 2} ${fy + h / 2})` }, anim('x', [[t0 + 2.1, fx - 500], [t0 + 3.3, fx + w + dx + 300, 'inout']]))
      );

  return {
    markup: g({}, bodyFill, outlines, bezelFill, screenGroup, plateMarkup, doorLayers, xray ? xrayLayer(xray[0], xray[1], frontPath, sideFace, topFace) : '', sheen),
    screen: { cx: sr.x + sr.w / 2, cy: sr.y + sr.h / 2, ...sr },
  };
}

module.exports = { GEO, DEPTH, SCREEN_SCALE, cabinet, doorRect, screenRect, platePos, lockup, lockupMetrics, PLATE, xrayAnchors };
