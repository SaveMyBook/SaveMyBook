import { span, easeOut, easeInOut, clamp } from './kf';
import { css } from './ui';

// logo 向量路徑（2048 座標，與 branding/Logo Design 原圖對齊；沿用第一版動畫描好的路徑）
const SPINE_X = 1037;
const PAGES = [
  { fill: 'M400 482L440 420C560 395 760 430 900 525C975 578 1015 640 1032 705L1032 1000L400 1000Z', edge: 'M1032 705C1015 640 975 578 900 525C760 430 560 395 440 420L400 482' },
  { fill: 'M338 565L370 487C520 455 730 490 880 580C960 628 1010 700 1032 765L1032 1000L338 1000Z', edge: 'M1032 765C1010 700 960 628 880 580C730 490 520 455 370 487L338 565' },
  { fill: 'M283 634L302 582C470 520 700 545 860 628C950 675 1005 735 1030 792L1030 1000L283 1000Z', edge: 'M1030 792C1005 735 950 675 860 628C700 545 470 520 302 582L283 634' },
  { fill: 'M1625 460L1592 392C1460 370 1250 420 1120 520C1065 565 1040 630 1033 700L1033 1000L1625 1000Z', edge: 'M1033 700C1040 630 1065 565 1120 520C1250 420 1460 370 1592 392L1625 460' },
  { fill: 'M1690 542L1660 460C1500 445 1300 500 1170 596C1100 648 1055 710 1034 765L1034 1000L1690 1000Z', edge: 'M1034 765C1055 710 1100 648 1170 596C1300 500 1500 445 1660 460L1690 542' },
  { fill: 'M1738 608L1724 558C1560 515 1350 540 1210 610C1120 655 1065 725 1036 792L1036 1000L1738 1000Z', edge: 'M1036 792C1065 725 1120 655 1210 610C1350 540 1560 515 1724 558L1738 608' },
];
const COVER = 'M210 675C300 610 520 590 700 638C850 680 960 740 1030 800C1110 730 1250 640 1420 598C1580 570 1740 585 1830 655L1828 1448C1650 1425 1300 1440 1036 1636Q1030 1642 1024 1636C760 1440 420 1425 240 1458Z';
const COVER_LEFT = 'M1030 1640C760 1440 420 1425 240 1458L210 675C300 610 520 590 700 638C850 680 960 740 1030 800';
const COVER_RIGHT = 'M1030 1640C1300 1440 1650 1425 1828 1448L1830 655C1740 585 1580 570 1420 598C1250 640 1110 730 1030 800';
const BOOKMARK = 'M1573 1258L1648 1245L1698 1428L1610 1432Z';
const SPINE = `M${SPINE_X} 1612L${SPINE_X} 856`;
const BRAND = '#627D8D';
const PAGE = '#E9EEF1';

const NS = 'http://www.w3.org/2000/svg';
function node<K extends keyof SVGElementTagNameMap>(tag: K, attrs: Record<string, string | number>, parent: Element) {
  const e = document.createElementNS(NS, tag);
  for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, String(v));
  parent.append(e);
  return e;
}

/** 依時間描出 logo：先描輪廓與書頁，再填色，最後掃過一道光澤。 */
let instances = 0;

export class LogoDraw {
  readonly root: HTMLElement;
  private strokes: { e: SVGPathElement; len: number; t0: number; dur: number }[] = [];
  private outline: SVGGElement;
  private fills: SVGElement[] = [];
  private pageFills: SVGPathElement[] = [];
  private shadow: SVGGElement;
  private mark: SVGPathElement;
  private shine: SVGRectElement;

  constructor(parent: HTMLElement) {
    // 片頭與片尾各有一個 logo：漸層 id 重複時 url(#…) 會指到隱藏圖層裡的那份，填色變淡
    const u = ++instances;
    this.root = document.createElement('div');
    this.root.className = 'logo-draw';
    parent.append(this.root);
    const svg = node('svg', { viewBox: '200 370 1650 1300', width: 1650, height: 1300 }, this.root);
    const defs = node('defs', {}, svg);
    const grad = node('linearGradient', { id: `lgc${u}`, x1: 0.2, y1: 0.25, x2: 0.95, y2: 1 }, defs);
    node('stop', { offset: 0, 'stop-color': BRAND }, grad);
    node('stop', { offset: 0.45, 'stop-color': BRAND }, grad);
    node('stop', { offset: 1, 'stop-color': '#98ABB7' }, grad);
    const glow = node('radialGradient', { id: `lgg${u}`, cx: 1560, cy: 1420, r: 760, gradientUnits: 'userSpaceOnUse' }, defs);
    node('stop', { offset: 0, 'stop-color': '#FFFFFF', 'stop-opacity': 0.3 }, glow);
    node('stop', { offset: 1, 'stop-color': '#FFFFFF', 'stop-opacity': 0 }, glow);
    const spine = node('linearGradient', { id: `lgs${u}`, x1: 0, y1: 856, x2: 0, y2: 1612, gradientUnits: 'userSpaceOnUse' }, defs);
    node('stop', { offset: 0, 'stop-color': '#C9D3D9' }, spine);
    node('stop', { offset: 1, 'stop-color': '#B3C0C8' }, spine);
    const shine = node('linearGradient', { id: `lgh${u}`, x1: 0, y1: 0, x2: 1, y2: 0 }, defs);
    node('stop', { offset: 0, 'stop-color': '#FFFFFF', 'stop-opacity': 0 }, shine);
    node('stop', { offset: 0.5, 'stop-color': '#FFFFFF', 'stop-opacity': 0.55 }, shine);
    node('stop', { offset: 1, 'stop-color': '#FFFFFF', 'stop-opacity': 0 }, shine);
    const clip = node('clipPath', { id: `lgk${u}` }, defs);
    node('path', { d: COVER }, clip);
    for (const p of PAGES) node('path', { d: p.fill }, clip);

    this.shadow = node('g', {}, svg);
    for (const dy of [8, 16, 24, 32, 40, 48, 56, 64]) node('path', { d: COVER, fill: '#46606F', 'fill-opacity': 0.034, transform: `translate(0 ${dy})` }, this.shadow);

    const order = [2, 5, 1, 4, 0, 3];
    // 每頁先畫底色再畫邊線，順序與 logo 原圖相同
    PAGES.forEach((p, i) => {
      this.pageFills.push(node('path', { d: p.fill, fill: PAGE, opacity: 0 }, svg));
      const e = node('path', { d: p.edge, fill: 'none', stroke: BRAND, 'stroke-width': 24, 'stroke-linejoin': 'round', 'stroke-linecap': 'round' }, svg);
      this.strokes.push({ e, len: 0, t0: 0.32 + Math.floor(order.indexOf(i) / 2) * 0.14, dur: 0.85 });
    });
    this.outline = node('g', {}, svg);
    for (const d of [COVER_LEFT, COVER_RIGHT]) {
      const e = node('path', { d, fill: 'none', stroke: BRAND, 'stroke-width': 22, 'stroke-linejoin': 'round', 'stroke-linecap': 'round' }, this.outline);
      this.strokes.push({ e, len: 0, t0: 0.08, dur: 1.15 });
    }
    this.fills.push(node('path', { d: COVER, fill: `url(#lgc${u})`, opacity: 0 }, svg));
    this.fills.push(node('path', { d: COVER, fill: `url(#lgg${u})`, opacity: 0 }, svg));
    const sp = node('path', { d: SPINE, fill: 'none', stroke: `url(#lgs${u})`, 'stroke-width': 34, 'stroke-linecap': 'round' }, svg);
    this.strokes.push({ e: sp, len: 0, t0: 0.55, dur: 0.9 });
    this.mark = node('path', { d: BOOKMARK, fill: '#FFFFFF', 'fill-opacity': 0.14, stroke: '#FFFFFF', 'stroke-opacity': 0.55, 'stroke-width': 5, 'stroke-linejoin': 'round', opacity: 0 }, svg);
    const g = node('g', { 'clip-path': `url(#lgk${u})` }, svg);
    this.shine = node('rect', { x: -700, y: 300, width: 560, height: 1500, fill: `url(#lgh${u})`, transform: 'rotate(18 1020 1000)' }, g);
    for (const s of this.strokes) {
      s.len = s.e.getTotalLength();
      s.e.setAttribute('stroke-dasharray', `${s.len} ${s.len}`);
    }
  }

  /** t0 起開始描繪；回傳完成度供外部安排後續動作。 */
  at(t: number, t0: number) {
    const k = t - t0;
    css(this.root, 'visibility', k < 0 ? 'hidden' : 'visible');
    for (const s of this.strokes) {
      const p = easeInOut(span(k, s.t0, s.t0 + s.dur));
      s.e.setAttribute('stroke-dashoffset', String(s.len * (1 - p)));
    }
    const fill = 1.15;
    this.fills[0].setAttribute('opacity', easeOut(span(k, fill - 0.05, fill + 0.45)).toFixed(3));
    this.fills[1].setAttribute('opacity', easeOut(span(k, fill + 0.5, fill + 1.3)).toFixed(3));
    this.pageFills.forEach((p, i) => p.setAttribute('opacity', easeOut(span(k, fill + 0.3 + i * 0.05, fill + 0.85 + i * 0.05)).toFixed(3)));
    this.outline.setAttribute('opacity', (1 - span(k, fill + 0.7, fill + 1.3)).toFixed(3));
    this.shadow.setAttribute('opacity', easeOut(span(k, fill + 0.2, fill + 1.0)).toFixed(3));
    this.mark.setAttribute('opacity', easeOut(span(k, fill + 0.8, fill + 1.3)).toFixed(3));
    this.shine.setAttribute('x', String(-700 + 3000 * easeInOut(span(k, 1.9, 3.1))));
    return clamp(k / 3.1);
  }
}
