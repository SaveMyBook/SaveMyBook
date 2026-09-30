'use strict';

const { el, g, fmt, anim, clipPath, linearGradient, rrect, nextId, blurFilter } = require('./core');
const { text } = require('./text');

const W = 402;
const H = 874;
const SAFE_TOP = 59;
const SAFE_BOTTOM = 34;
const R = 55;
const BODY = { x: -16, y: -16, w: W + 32, h: H + 32, r: 71 };

const GLACIER = {
  rim: [
    [0, '#FBFCFD'],
    [0.18, '#DDE5EB'],
    [0.46, '#B4C2CC'],
    [0.62, '#D3DCE3'],
    [0.84, '#A9B8C3'],
    [1, '#E8EEF2'],
  ],
  button: [
    [0, '#D5DEE5'],
    [0.5, '#A8B7C2'],
    [1, '#C7D2DA'],
  ],
  control: '#8795A0',
};

function statusBar(color, battery = 0.82) {
  const cy = 30;
  const rx = W - 30;
  const bars = [0, 1, 2, 3].map((i) => {
    const h = 4.2 + i * 2.6;
    return el('rect', { x: rx - 78 + i * 5.2, y: cy + 5.6 - h, width: 3.4, height: h, rx: 1, fill: color });
  });
  const wx = rx - 50;
  const wifi = el('path', {
    d: `M${fmt(wx + 8.5)} ${fmt(cy + 5.4)}l-2.6-3.1a4.1 4.1 0 0 1 5.2 0z M${fmt(wx + 1)} ${fmt(cy - 2)}a11.4 11.4 0 0 1 15 0l-1.8 2.1a8.7 8.7 0 0 0-11.4 0z M${fmt(wx + 3.6)} ${fmt(cy + 1.1)}a7.5 7.5 0 0 1 9.8 0l-1.8 2.1a4.8 4.8 0 0 0-6.2 0z`,
    fill: color,
  });
  const bx = rx - 27;
  const batteryShape = [
    el('rect', { x: bx, y: cy - 6.2, width: 25.5, height: 12.4, rx: 4, fill: 'none', stroke: color, 'stroke-opacity': 0.38, 'stroke-width': 1.1 }),
    el('rect', { x: bx + 2.1, y: cy - 4.1, width: 21.3 * battery, height: 8.2, rx: 2.2, fill: color }),
    el('path', { d: `M${fmt(bx + 27)} ${fmt(cy - 2.2)}v4.4a2.3 2.3 0 0 0 0-4.4z`, fill: color, 'fill-opacity': 0.45 }),
  ];
  return [text('2:25', { x: 66, y: cy + 6.3, size: 17, weight: 600, fill: color, anchor: 'middle' }), bars, wifi, batteryShape];
}

function homeIndicator(color = '#000000') {
  return rrect(W / 2 - 72, H - 13, 144, 5, 2.5, { fill: color, 'fill-opacity': 0.9 });
}

function iphone(content, { shadow = true, reflection = true, glint } = {}) {
  const id = nextId('ip');
  const screenClip = clipPath(`${id}c`, rrect(0, 0, W, H, R));
  const rim = linearGradient(`${id}r`, GLACIER.rim, { x1: 0, y1: 0, x2: 1, y2: 1 });
  const btn = linearGradient(`${id}b`, GLACIER.button, { x1: 0, y1: 0, x2: 1, y2: 0 });
  const glass = linearGradient(`${id}g`, [
    [0, '#FFFFFF', 0.1],
    [0.32, '#FFFFFF', 0.02],
    [0.33, '#FFFFFF', 0],
    [1, '#FFFFFF', 0],
  ], { x1: 0, y1: 0, x2: 0.7, y2: 1 });
  const b = BODY;
  return g(
    {},
    shadow
      ? [
          rrect(b.x + 20, b.y + 58, b.w - 40, b.h - 10, b.r, { fill: '#0B1A26', 'fill-opacity': 0.3, filter: blurFilter(`${id}s1`, 34, { region: '-30%', size: '160%', regionY: '-14%', sizeY: '128%' }) }),
          rrect(b.x + 6, b.y + 12, b.w - 12, b.h - 6, b.r, { fill: '#0B1A26', 'fill-opacity': 0.16, filter: blurFilter(`${id}s2`, 9, { region: '-8%', size: '116%', regionY: '-4%', sizeY: '108%' }) }),
        ]
      : '',
    rrect(b.x - 3.2, 168, 5, 34, 2.5, { fill: btn }),
    rrect(b.x - 3.2, 236, 5, 64, 2.5, { fill: btn }),
    rrect(b.x - 3.2, 314, 5, 64, 2.5, { fill: btn }),
    rrect(b.x + b.w - 1.8, 260, 5, 100, 2.5, { fill: btn }),
    rrect(b.x + b.w - 1.4, 552, 4, 66, 2, { fill: GLACIER.control }),
    rrect(b.x, b.y, b.w, b.h, b.r, { fill: rim }),
    rrect(b.x + 0.6, b.y + 0.6, b.w - 1.2, b.h - 1.2, b.r - 0.6, { fill: 'none', stroke: '#7F8F9B', 'stroke-opacity': 0.55, 'stroke-width': 1.2 }),
    rrect(b.x + 4.2, b.y + 4.2, b.w - 8.4, b.h - 8.4, b.r - 4.2, { fill: 'none', stroke: '#FFFFFF', 'stroke-opacity': 0.75, 'stroke-width': 1.4 }),
    rrect(-7.5, -7.5, W + 15, H + 15, R + 7.5, { fill: '#050608' }),
    g(
      { 'clip-path': screenClip },
      el('rect', { x: 0, y: 0, width: W, height: H, fill: '#F3F5F7' }),
      content,
      reflection ? el('rect', { x: 0, y: 0, width: W, height: H, fill: glass }) : '',
      glint !== undefined
        ? el(
            'rect',
            { x: -420, y: -200, width: 220, height: H + 400, fill: linearGradient(`${id}l`, [[0, '#FFFFFF', 0], [0.5, '#FFFFFF', 0.28], [1, '#FFFFFF', 0]], { x1: 0, y1: 0, x2: 1, y2: 0 }), transform: `rotate(22 ${W / 2} ${H / 2})` },
            anim('x', [[glint, -420], [glint + 1.1, W + 260, 'inout']])
          )
        : ''
    ),
    rrect(W / 2 - 41, 11, 82, 37, 18.5, { fill: '#000000' }),
    el('circle', { cx: W / 2 + 22, cy: 29.5, r: 6.2, fill: '#0A0F16' }),
    el('circle', { cx: W / 2 + 22, cy: 29.5, r: 3.2, fill: '#111B28' }),
    el('circle', { cx: W / 2 + 23.4, cy: 28.2, r: 1.1, fill: '#3A5070', 'fill-opacity': 0.8 })
  );
}

module.exports = { W, H, SAFE_TOP, SAFE_BOTTOM, BODY, iphone, statusBar, homeIndicator };
