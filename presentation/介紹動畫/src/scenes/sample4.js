'use strict';

const { el, g, motion, linearGradient, radialGradient, addDef, during } = require('../lib/core');
const V = require('../lib/ui2');
const C = require('../lib/palette');
const flow = require('./flow');
const ai = require('./ai');

function stage(duration) {
  const glow = radialGradient('stageGlow', [
    [0, '#FFFFFF', 0.95],
    [0.6, '#FFFFFF', 0.35],
    [1, '#FFFFFF', 0],
  ]);
  const fog = radialGradient('stageFog', [
    [0.25, C.stage, 0],
    [0.95, C.stage, 1],
  ]);
  const floor = linearGradient('stageFloor', [
    [0, C.stage, 0],
    [1, '#E6EBEF', 1],
  ]);
  addDef(el('pattern', { id: 'dotGrid', width: 34, height: 34, patternUnits: 'userSpaceOnUse' }, el('circle', { cx: 17, cy: 17, r: 1.15, fill: C.brand, 'fill-opacity': 0.2 })));
  return [
    el('rect', { width: 1920, height: 1080, fill: C.stage }),
    el('ellipse', { cx: 960, cy: 470, rx: 1100, ry: 620, fill: glow }),
    el('rect', { width: 1920, height: 1080, fill: 'url(#dotGrid)' }),
    el('rect', { width: 1920, height: 1080, fill: fog }),
    el('rect', { y: 760, width: 1920, height: 320, fill: floor }),
    V.particles(28, 7, { t0: 0, t1: duration }),
  ];
}

function build() {
  const F = 0.6;
  const f = flow.build(F);
  const S0 = f.end - 0.3;
  const a = ai.build(S0);
  const duration = Math.round((a.end + 1.2) * 10) / 10;
  return {
    duration,
    title: '救「舊」我的書｜介紹動畫樣片',
    body: [
      stage(duration),
      g({ display: 'none' }, during(0.1, f.end + 0.1), motion({ o: [[0.1, 0], [0.6, 1, 'out'], [f.end - 0.6, 1, 'lin'], [f.end, 0, 'in']] }, f.markup)),
      a.markup,
      motion({ o: [[a.end, 1], [duration, 0, 'in']] }, V.brandBadge(56, 58, 0.3)),
    ],
  };
}

module.exports = { build };
