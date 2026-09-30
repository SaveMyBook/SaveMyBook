'use strict';

const { el, g, anim, animT, drawPath, penDot, clipPath, linearGradient, radialGradient, nextId } = require('./core');
const C = require('./palette');

const SPINE_X = 1037;

const PAGES = [
  { fill: 'M400 482L440 420C560 395 760 430 900 525C975 578 1015 640 1032 705L1032 1000L400 1000Z', edge: 'M1032 705C1015 640 975 578 900 525C760 430 560 395 440 420L400 482' },
  { fill: 'M338 565L370 487C520 455 730 490 880 580C960 628 1010 700 1032 765L1032 1000L338 1000Z', edge: 'M1032 765C1010 700 960 628 880 580C730 490 520 455 370 487L338 565' },
  { fill: 'M283 634L302 582C470 520 700 545 860 628C950 675 1005 735 1030 792L1030 1000L283 1000Z', edge: 'M1030 792C1005 735 950 675 860 628C700 545 470 520 302 582L283 634' },
  { fill: 'M1625 460L1592 392C1460 370 1250 420 1120 520C1065 565 1040 630 1033 700L1033 1000L1625 1000Z', edge: 'M1033 700C1040 630 1065 565 1120 520C1250 420 1460 370 1592 392L1625 460' },
  { fill: 'M1690 542L1660 460C1500 445 1300 500 1170 596C1100 648 1055 710 1034 765L1034 1000L1690 1000Z', edge: 'M1034 765C1055 710 1100 648 1170 596C1300 500 1500 445 1660 460L1690 542' },
  { fill: 'M1738 608L1724 558C1560 515 1350 540 1210 610C1120 655 1065 725 1036 792L1036 1000L1738 1000Z', edge: 'M1036 792C1065 725 1120 655 1210 610C1350 540 1560 515 1724 558L1738 608' },
];

const COVER =
  'M210 675C300 610 520 590 700 638C850 680 960 740 1030 800C1110 730 1250 640 1420 598C1580 570 1740 585 1830 655L1828 1448C1650 1425 1300 1440 1036 1636Q1030 1642 1024 1636C760 1440 420 1425 240 1458Z';

const COVER_LEFT = 'M1030 1640C760 1440 420 1425 240 1458L210 675C300 610 520 590 700 638C850 680 960 740 1030 800';
const COVER_RIGHT = 'M1030 1640C1300 1440 1650 1425 1828 1448L1830 655C1740 585 1580 570 1420 598C1250 640 1110 730 1030 800';

const BOOKMARK = 'M1573 1258L1648 1245L1698 1428L1610 1432Z';

const BOX = { x: 200, y: 370, w: 1650, h: 1300, cx: 1020, cy: 1010 };

function gradients() {
  const id = nextId('lg');
  const coverFill = linearGradient(`${id}c`, [
    [0, C.brand],
    [0.45, C.brand],
    [1, '#98ABB7'],
  ], { x1: 0.2, y1: 0.25, x2: 0.95, y2: 1 });
  const glow = radialGradient(`${id}g`, [
    [0, '#FFFFFF', 0.3],
    [1, '#FFFFFF', 0],
  ], { cx: 1560, cy: 1420, r: 760, units: 'userSpaceOnUse' });
  const spine = linearGradient(`${id}s`, [
    [0, '#C9D3D9'],
    [1, '#B3C0C8'],
  ], { x1: 0, y1: 856, x2: 0, y2: 1612, units: 'userSpaceOnUse' });
  const shine = linearGradient(`${id}h`, [
    [0, '#FFFFFF', 0],
    [0.5, '#FFFFFF', 0.55],
    [1, '#FFFFFF', 0],
  ], { x1: 0, y1: 0, x2: 1, y2: 0 });
  return { coverFill, glow, spine, shine, id };
}

function staticLogo() {
  const gr = gradients();
  return g(
    {},
    shadow(),
    PAGES.map((p) => [el('path', { d: p.fill, fill: C.page }), el('path', { d: p.edge, fill: 'none', stroke: C.brand, 'stroke-width': 24, 'stroke-linejoin': 'round', 'stroke-linecap': 'round' })]),
    el('path', { d: COVER, fill: gr.coverFill }),
    el('path', { d: COVER, fill: gr.glow }),
    el('line', { x1: SPINE_X, y1: 856, x2: SPINE_X, y2: 1612, stroke: gr.spine, 'stroke-width': 34, 'stroke-linecap': 'round' }),
    el('path', { d: BOOKMARK, fill: '#FFFFFF', 'fill-opacity': 0.14, stroke: '#FFFFFF', 'stroke-opacity': 0.55, 'stroke-width': 5, 'stroke-linejoin': 'round' })
  );
}

function shadow(opacity) {
  const layers = [8, 16, 24, 32, 40, 48, 56, 64].map((dy) => [dy, 0.034]);
  return g(
    { opacity },
    layers.map(([dy, o]) => el('path', { d: COVER, fill: '#46606F', 'fill-opacity': o, transform: `translate(0 ${dy})` }))
  );
}

function animatedLogo(t0, { pen = false } = {}) {
  const gr = gradients();
  const glow = radialGradient(`${gr.id}p`, [
    [0, '#FFFFFF', 1],
    [0.35, '#E3EEF4', 0.9],
    [1, C.brand, 0],
  ]);
  const clipId = `${gr.id}k`;
  const clip = clipPath(clipId, el('path', { d: COVER }), PAGES.map((p) => el('path', { d: p.fill })));
  const pageOrder = [2, 5, 1, 4, 0, 3];
  const pageStart = (i) => t0 + 0.32 + Math.floor(pageOrder.indexOf(i) / 2) * 0.14;
  const fillStart = t0 + 1.15;
  return g(
    {},
    g({ opacity: 0 }, anim('opacity', [[fillStart + 0.2, 0], [fillStart + 1.0, 1, 'out']]), shadow()),
    PAGES.map((p, i) => [
      el('path', { d: p.fill, fill: C.page, opacity: 0 }, anim('opacity', [[fillStart + 0.3 + i * 0.05, 0], [fillStart + 0.3 + i * 0.05 + 0.55, 1, 'out']])),
      drawPath(p.edge, pageStart(i), 0.85, { stroke: C.brand, width: 24, ease: 'inout' }),
      pen ? penDot(p.edge, pageStart(i), 0.85, { r: 30, fill: glow }) : '',
    ]),
    pen ? [penDot(COVER_LEFT, t0 + 0.08, 1.15, { r: 38, fill: glow }), penDot(COVER_RIGHT, t0 + 0.08, 1.15, { r: 38, fill: glow }), penDot(`M${SPINE_X} 1612L${SPINE_X} 856`, t0 + 0.55, 0.9, { r: 34, fill: glow, ease: 'emph' })] : '',
    g(
      {},
      anim('opacity', [[fillStart + 0.7, 1], [fillStart + 1.3, 0, 'soft']]),
      drawPath(COVER_LEFT, t0 + 0.08, 1.15, { stroke: C.brand, width: 22, ease: 'inout' }),
      drawPath(COVER_RIGHT, t0 + 0.08, 1.15, { stroke: C.brand, width: 22, ease: 'inout' })
    ),
    el('path', { d: COVER, fill: gr.coverFill, opacity: 0 }, anim('opacity', [[fillStart - 0.05, 0], [fillStart + 0.45, 1, 'out']])),
    el('path', { d: COVER, fill: gr.glow, opacity: 0 }, anim('opacity', [[fillStart + 0.5, 0], [fillStart + 1.3, 1, 'out']])),
    drawPath(`M${SPINE_X} 1612L${SPINE_X} 856`, t0 + 0.55, 0.9, { stroke: gr.spine, width: 34, ease: 'emph' }),
    el('path', { d: BOOKMARK, fill: '#FFFFFF', 'fill-opacity': 0.14, stroke: '#FFFFFF', 'stroke-opacity': 0.55, 'stroke-width': 5, 'stroke-linejoin': 'round', opacity: 0 }, anim('opacity', [[fillStart + 0.8, 0], [fillStart + 1.3, 1, 'out']])),
    g(
      { 'clip-path': clip },
      el(
        'rect',
        { x: -700, y: 300, width: 560, height: 1500, fill: gr.shine, transform: 'rotate(18 1020 1000)' },
        anim('x', [[t0 + 1.9, -700], [t0 + 3.1, 2300, 'inout']])
      )
    )
  );
}

module.exports = { staticLogo, animatedLogo, BOX, COVER, PAGES };
