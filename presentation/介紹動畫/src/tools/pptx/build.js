'use strict';

// 把定格資料轉成可編輯的 PowerPoint：node tools/pptx/build.js <frames.json> <keys.json> <out.pptx>
// 每個 SVG 物件轉成原生形狀或文字方塊，並以相同名稱（!! 前綴）串起各張投影片，讓「變形」轉場補出動作。
const fs = require('fs');
const path = require('path');
const opentype = require('opentype.js');
const G = require('./geom');
const P = require('./package');
const C = require('../../lib/palette');

const [framesFile, keysFile, outArg] = process.argv.slice(2);
const OUT = path.resolve(outArg);

const PX = P.SLIDE_W / 1920;
const emu = (v) => Math.round(v * PX);
const FONT_DIR = path.resolve(__dirname, '../../../../../savemybook_app/assets/fonts');
const WEIGHTS = { 100: 'Thin', 200: 'ExtraLight', 300: 'Light', 400: 'Regular', 500: 'Medium', 600: 'SemiBold', 700: 'Bold', 800: 'ExtraBold', 900: 'Black' };
const FAMILY = (w) => (w === 400 || w === 700 ? 'Noto Sans TC' : `Noto Sans TC ${WEIGHTS[w]}`);
const ASCENT = 1.16;
const LINE = 1.448;

const fonts = new Map();
function advance(ch, weight) {
  if (!fonts.has(weight)) fonts.set(weight, opentype.loadSync(path.join(FONT_DIR, `NotoSansTC-${WEIGHTS[weight]}.ttf`)));
  return fonts.get(weight).charToGlyph(ch).advanceWidth / 1000;
}

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

function parseColor(v) {
  if (!v) return null;
  let m = /rgba?\(([\d.]+),\s*([\d.]+),\s*([\d.]+)(?:,\s*([\d.]+))?\)/.exec(v);
  if (m) return { hex: [m[1], m[2], m[3]].map((n) => Math.round(Number(n)).toString(16).padStart(2, '0')).join('').toUpperCase(), a: m[4] === undefined ? 1 : Number(m[4]) };
  m = /#([0-9a-f]{6})/i.exec(v);
  if (m) return { hex: m[1].toUpperCase(), a: 1 };
  return null;
}

const alphaXml = (a) => (a >= 0.999 ? '' : `<a:alpha val="${Math.max(0, Math.round(a * 100000))}"/>`);
const solid = (hex, a) => `<a:solidFill><a:srgbClr val="${hex}">${alphaXml(a)}</a:srgbClr></a:solidFill>`;

const lerp = (a, b, t) => a + (b - a) * t;
function stopAt(stops, o) {
  if (o <= stops[0].offset) return stops[0];
  const last = stops[stops.length - 1];
  if (o >= last.offset) return last;
  for (let i = 1; i < stops.length; i++) {
    const a = stops[i - 1];
    const b = stops[i];
    if (o <= b.offset) {
      const t = (o - a.offset) / (b.offset - a.offset || 1);
      const ca = parseColor(a.color);
      const cb = parseColor(b.color);
      const rgb = [0, 2, 4].map((k) => Math.round(lerp(parseInt(ca.hex.slice(k, k + 2), 16), parseInt(cb.hex.slice(k, k + 2), 16), t)).toString(16).padStart(2, '0'));
      return { offset: o, color: `#${rgb.join('')}`, opacity: lerp(a.opacity * ca.a, b.opacity * cb.a, t) };
    }
  }
  return last;
}

const num = (v, rel, base) => {
  if (v === undefined || v === null) return undefined;
  const s = String(v);
  return s.endsWith('%') ? (parseFloat(s) / 100) * (rel ? 1 : base) : parseFloat(s);
};

// 將 SVG 漸層換算到形狀外框上：PowerPoint 的漸層位置以形狀外框為準，因此重新取樣色標。
function gradientXml(fill, item, box, alpha) {
  const { attrs, stops } = fill;
  const user = attrs.gradientUnits === 'userSpaceOnUse';
  const [bx, by, bw, bh] = item.bbox;
  const [a, b, c, d, e, f] = item.m;
  const map = (x, y) => (user ? [x, y] : [bx + x * bw, by + y * bh]);
  const root = ([x, y]) => [a * x + c * y + e, b * x + d * y + f];
  const pos = (q) => Math.min(100000, Math.max(0, Math.round(q * 100000)));
  const gs = (list) =>
    list
      .map(([q, s]) => {
        const col = parseColor(s.color);
        return `<a:gs pos="${pos(q)}"><a:srgbClr val="${col.hex}">${alphaXml(s.opacity * col.a * alpha)}</a:srgbClr></a:gs>`;
      })
      .join('');
  const [X0, Y0, X1, Y1] = box;
  if (fill.gradient === 'linear') {
    const p1 = root(map(num(attrs.x1 ?? '0', !user), num(attrs.y1 ?? '0', !user)));
    const p2 = root(map(num(attrs.x2 ?? '1', !user, 1), num(attrs.y2 ?? '0', !user)));
    const vx = p2[0] - p1[0];
    const vy = p2[1] - p1[1];
    const len = Math.hypot(vx, vy) || 1;
    const ux = vx / len;
    const uy = vy / len;
    const proj = ([x, y]) => (x - p1[0]) * ux + (y - p1[1]) * uy;
    const corners = [[X0, Y0], [X1, Y0], [X0, Y1], [X1, Y1]].map(proj);
    const lo = Math.min(...corners);
    const hi = Math.max(...corners);
    const qs = new Set([0, 1]);
    for (const s of stops) {
      const q = (s.offset * len - lo) / (hi - lo || 1);
      if (q > 0 && q < 1) qs.add(q);
    }
    const list = [...qs].sort((m, n) => m - n).map((q) => [q, stopAt(stops, (lo + q * (hi - lo)) / len)]);
    let ang = (Math.atan2(vy, vx) * 180) / Math.PI;
    if (ang < 0) ang += 360;
    return `<a:gradFill rotWithShape="1"><a:gsLst>${gs(list)}</a:gsLst><a:lin ang="${Math.round(ang * 60000) % 21600000}" scaled="0"/></a:gradFill>`;
  }
  const cx = num(attrs.cx ?? '0.5', !user, 0.5);
  const cy = num(attrs.cy ?? '0.5', !user, 0.5);
  const r = num(attrs.r ?? '0.5', !user, 0.5);
  const center = root(map(cx, cy));
  const edge = root(map(cx + r, cy));
  const edge2 = root(map(cx, cy + r));
  const rs = (Math.hypot(edge[0] - center[0], edge[1] - center[1]) + Math.hypot(edge2[0] - center[0], edge2[1] - center[1])) / 2 || 1;
  const w = X1 - X0 || 1;
  const h = Y1 - Y0 || 1;
  const fx = Math.min(1, Math.max(0, (center[0] - X0) / w));
  const fy = Math.min(1, Math.max(0, (center[1] - Y0) / h));
  // PowerPoint 的圓形漸層由中心延伸到外框最遠的角落。
  const rp = Math.max(...[[X0, Y0], [X1, Y0], [X0, Y1], [X1, Y1]].map(([x, y]) => Math.hypot(x - center[0], y - center[1])));
  const qs = new Set([0, 1]);
  for (const s of stops) {
    const q = (s.offset * rs) / rp;
    if (q > 0 && q < 1) qs.add(q);
  }
  const list = [...qs].sort((m, n) => m - n).map((q) => [q, stopAt(stops, (q * rp) / rs)]);
  const rect = `<a:fillToRect l="${pos(fx)}" t="${pos(fy)}" r="${pos(1 - fx)}" b="${pos(1 - fy)}"/>`;
  return `<a:gradFill rotWithShape="1"><a:gsLst>${gs(list)}</a:gsLst><a:path path="circle">${rect}</a:path></a:gradFill>`;
}

class Slide {
  constructor() {
    this.shapes = [];
    this.id = 2;
    this.images = [];
  }

  image(name) {
    let i = this.images.indexOf(name);
    if (i < 0) {
      this.images.push(name);
      i = this.images.length - 1;
    }
    return `rIdP${i + 1}`;
  }
}

function paintXml(slide, fill, item, box, alpha, patterns, media) {
  if (!fill) return '<a:noFill/>';
  if (fill.color) {
    const c = parseColor(fill.color);
    if (!c) return '<a:noFill/>';
    return solid(c.hex, c.a * alpha);
  }
  if (fill.gradient) return gradientXml(fill, item, box, alpha);
  if (fill.pattern) {
    const p = patterns[fill.pattern];
    const name = `${fill.pattern}.png`;
    media[name] = Buffer.from(p.png, 'base64');
    const scale = Math.sqrt(Math.abs(item.m[0] * item.m[3] - item.m[1] * item.m[2]));
    const native = p.w * 4 * 9525;
    const target = p.w * scale * PX;
    const s = Math.round((target / native) * 100000);
    const tile = p.w * scale;
    const mod = (v) => ((v % tile) + tile) % tile;
    const tx = emu(mod(item.m[4] - box[0]));
    const ty = emu(mod(item.m[5] - box[1]));
    return `<a:blipFill dpi="0" rotWithShape="1"><a:blip r:embed="${slide.image(name)}">${alpha < 0.999 ? `<a:alphaModFix amt="${Math.round(alpha * 100000)}"/>` : ''}</a:blip><a:srcRect/><a:tile tx="${tx}" ty="${ty}" sx="${s}" sy="${s}" flip="none" algn="tl"/></a:blipFill>`;
  }
  return '<a:noFill/>';
}

function dashXml(item, sw) {
  const dash = item.dash;
  if (!dash || dash === 'none') return { xml: '', visible: true };
  const vals = dash.split(/[\s,]+/).map((v) => parseFloat(v)).filter((v) => Number.isFinite(v));
  if (!vals.length) return { xml: '', visible: true };
  const pl = item.pathLength ? Number(item.pathLength) : null;
  // drawPath 以 pathLength=1 的虛線做「描繪」動畫：依已描繪的比例決定整條顯示或隱藏。
  if (pl && vals.length === 2 && vals[0] >= pl * 0.99 && vals[1] >= pl) {
    const shown = 1 - item.dashOffset / pl;
    return { xml: '', visible: shown >= 0.5 };
  }
  const scale = pl && item.len ? item.len / pl : 1;
  const k = Math.sqrt(Math.abs(item.m[0] * item.m[3] - item.m[1] * item.m[2]));
  const list = vals.length % 2 ? [...vals, ...vals] : vals;
  const pct = (v) => Math.max(1, Math.round(((v * scale * k) / sw) * 100000));
  let ds = '';
  for (let i = 0; i < list.length; i += 2) ds += `<a:ds d="${pct(list[i])}" sp="${pct(list[i + 1])}"/>`;
  return { xml: `<a:custDash>${ds}</a:custDash>`, visible: true };
}

// 以根座標的路徑建立自訂圖形，座標換算成相對於外框左上角的 EMU。
function custGeom(cmds, filled) {
  const box = G.bounds(cmds);
  const W = Math.max(1, emu(box[2] - box[0]));
  const H = Math.max(1, emu(box[3] - box[1]));
  const pt = (x, y) => `<a:pt x="${emu(x - box[0])}" y="${emu(y - box[1])}"/>`;
  let body = '';
  for (const cmd of cmds) {
    if (cmd[0] === 'M') body += `<a:moveTo>${pt(cmd[1], cmd[2])}</a:moveTo>`;
    else if (cmd[0] === 'L') body += `<a:lnTo>${pt(cmd[1], cmd[2])}</a:lnTo>`;
    else if (cmd[0] === 'C') body += `<a:cubicBezTo>${pt(cmd[1], cmd[2])}${pt(cmd[3], cmd[4])}${pt(cmd[5], cmd[6])}</a:cubicBezTo>`;
    else if (cmd[0] === 'Q') body += `<a:quadBezTo>${pt(cmd[1], cmd[2])}${pt(cmd[3], cmd[4])}</a:quadBezTo>`;
    else body += '<a:close/>';
  }
  const xml = `<a:custGeom><a:avLst/><a:gdLst/><a:ahLst/><a:cxnLst/><a:rect l="l" t="t" r="r" b="b"/><a:pathLst><a:path w="${W}" h="${H}"${filled ? '' : ' fill="none"'}>${body}</a:path></a:pathLst></a:custGeom>`;
  return { box, xml };
}

// 只由一條線段路徑構成的圖樣（例如透視圖的格線）直接展開成向量線條，比磁磚圖更清晰也能編輯。
function patternLines(item, pattern) {
  const kids = pattern.kids || [];
  if (kids.length !== 1 || kids[0].tag !== 'path' || (kids[0].fill || 'none') !== 'none' || !kids[0].stroke) return null;
  const [a, b, c, d, e, f] = item.m;
  if (Math.abs(b) > 1e-6 || Math.abs(c) > 1e-6 || a <= 0 || d <= 0) return null;
  const cl = item.clip || [0, 0, 1920, 1080];
  const reg = [Math.max(item.box[0], cl[0], 0), Math.max(item.box[1], cl[1], 0), Math.min(item.box[2], cl[2], 1920), Math.min(item.box[3], cl[3], 1080)];
  if (reg[2] <= reg[0] || reg[3] <= reg[1]) return null;
  const { w, h } = pattern;
  const i0 = Math.floor((reg[0] - e) / a / w) - 1;
  const i1 = Math.ceil((reg[2] - e) / a / w) + 1;
  const j0 = Math.floor((reg[1] - f) / d / h) - 1;
  const j1 = Math.ceil((reg[3] - f) / d / h) + 1;
  if ((i1 - i0) * (j1 - j0) > 4000) return null;
  const base = G.parsePath(kids[0].d);
  if (base.some((cmd) => cmd[0] !== 'M' && cmd[0] !== 'L')) return null;
  // 落在磁磚邊界上的線只會畫出一半寬度。
  const onEdge = base.every((cmd) => cmd.length < 3 || [0, w].includes(cmd[1]) || [0, h].includes(cmd[2]));
  const segs = [];
  for (let i = i0; i <= i1; i++) {
    for (let j = j0; j <= j1; j++) {
      let prev = null;
      for (const cmd of base) {
        const pt = [a * (cmd[1] + i * w) + e, d * (cmd[2] + j * h) + f];
        if (cmd[0] === 'L' && prev) segs.push([prev, pt]);
        prev = pt;
      }
    }
  }
  const cmds = [];
  const seen = new Set();
  for (const [p, q] of segs) {
    const x0 = Math.max(reg[0], Math.min(p[0], q[0]));
    const x1 = Math.min(reg[2], Math.max(p[0], q[0]));
    const y0 = Math.max(reg[1], Math.min(p[1], q[1]));
    const y1 = Math.min(reg[3], Math.max(p[1], q[1]));
    if (x1 < x0 || y1 < y0) continue;
    const key = [x0, y0, x1, y1].map((v) => v.toFixed(2)).join();
    if (seen.has(key)) continue;
    seen.add(key);
    cmds.push(['M', x0, y0], ['L', x1, y1]);
  }
  if (!cmds.length) return null;
  const color = parseColor(kids[0].stroke);
  const alpha = Number(kids[0]['stroke-opacity'] ?? 1) * color.a * item.op * item.fillOpacity;
  const sw = Number(kids[0]['stroke-width'] ?? 1) * a * (onEdge ? 0.5 : 1);
  return { cmds, ln: `<a:ln w="${Math.max(1, emu(sw))}" cap="flat">${solid(color.hex, alpha)}<a:prstDash val="solid"/><a:miter lim="800000"/></a:ln>` };
}

function shapeXml(slide, item, patterns, media) {
  if (item.fill && item.fill.pattern && !item.stroke) {
    const lines = patternLines(item, patterns[item.fill.pattern]);
    if (lines) {
      const out = custGeom(lines.cmds, false);
      const id = slide.id++;
      const xfrm = `<a:xfrm><a:off x="${emu(out.box[0])}" y="${emu(out.box[1])}"/><a:ext cx="${Math.max(1, emu(out.box[2] - out.box[0]))}" cy="${Math.max(1, emu(out.box[3] - out.box[1]))}"/></a:xfrm>`;
      return `<p:sp><p:nvSpPr><p:cNvPr id="${id}" name="!!grid-${item.k}"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr>${xfrm}${out.xml}<a:noFill/>${lines.ln}</p:spPr></p:sp>`;
    }
  }
  const op = item.op;
  const [a, b, c, d] = item.m;
  const k = Math.sqrt(Math.abs(a * d - b * c));
  const sw = item.strokeWidth * k;
  let stroke = item.stroke;
  let dash = { xml: '', visible: true };
  if (stroke) {
    dash = dashXml(item, sw);
    if (!dash.visible) stroke = null;
  }
  const fillAlpha = op * item.fillOpacity;
  const strokeAlpha = op * item.strokeOpacity;
  const hasFill = item.fill && fillAlpha > 0.004 && !(item.fill.color && parseColor(item.fill.color)?.a === 0);
  const hasStroke = stroke && strokeAlpha > 0.004;
  if (!hasFill && !hasStroke) return null;

  const axis = Math.abs(b) < 1e-6 && Math.abs(c) < 1e-6 && a > 0 && d > 0;
  const blur = item.blur * k;
  let geomXml;
  let box;
  const plain = axis && !dash.xml;
  if (plain && item.tag === 'rect' && Math.abs(item.geo.rx - item.geo.ry) < 1e-6) {
    const g = item.geo;
    box = [a * g.x + item.m[4], d * g.y + item.m[5], a * (g.x + g.width) + item.m[4], d * (g.y + g.height) + item.m[5]];
    const r = Math.min(g.rx * a, (box[2] - box[0]) / 2, (box[3] - box[1]) / 2);
    // 只有直角矩形才依裁切範圍截掉超出的部分（例如手機畫面內捲動的內容）。
    let corners = null;
    if (!r && item.clip) {
      const cl = item.clip;
      box = [Math.max(box[0], cl[0]), Math.max(box[1], cl[1]), Math.min(box[2], cl[2]), Math.min(box[3], cl[3])];
      // 貼齊圓角裁切範圍（例如手機螢幕）角落的矩形，該角改為相同的圓角。
      if (cl[4] > 0.5) {
        const near = (u, v) => Math.abs(u - v) < 1;
        corners = [near(box[0], cl[0]) && near(box[1], cl[1]), near(box[2], cl[2]) && near(box[1], cl[1]), near(box[2], cl[2]) && near(box[3], cl[3]), near(box[0], cl[0]) && near(box[3], cl[3])].map((on) => (on ? cl[4] : 0));
        if (!corners.some(Boolean)) corners = null;
      }
    }
    if (box[2] <= box[0] || box[3] <= box[1]) return null;
    const short = Math.min(box[2] - box[0], box[3] - box[1]);
    if (corners) {
      const out = custGeom(G.cornerPath(box, corners), hasFill);
      geomXml = out.xml;
    } else {
      geomXml = r > 0.01 ? `<a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val ${Math.min(50000, Math.round((r / short) * 100000))}"/></a:avLst></a:prstGeom>` : '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>';
    }
  } else if (plain && (item.tag === 'circle' || item.tag === 'ellipse')) {
    const g = item.geo;
    const rx = item.tag === 'circle' ? g.r : g.rx;
    const ry = item.tag === 'circle' ? g.r : g.ry;
    if (rx <= 0 || ry <= 0) return null;
    box = [a * (g.cx - rx) + item.m[4], d * (g.cy - ry) + item.m[5], a * (g.cx + rx) + item.m[4], d * (g.cy + ry) + item.m[5]];
    geomXml = '<a:prstGeom prst="ellipse"><a:avLst/></a:prstGeom>';
  } else {
    let cmds;
    try {
      cmds = G.transform(G.toPath(item.tag, item.geo), item.m);
    } catch (e) {
      console.warn(`略過無法解析的路徑 ${item.k}：${e.message}`);
      return null;
    }
    // 填色且無外框的路徑若超出裁切範圍（例如手機螢幕圓角外的標題列），實際裁掉超出的部分。
    if (item.clip && hasFill && !hasStroke && !item.blur) {
      const [x0, y0, x1, y1] = G.bounds(cmds);
      const corners = [[x0, y0], [x1, y0], [x0, y1], [x1, y1]];
      if (!corners.every(([x, y]) => G.insideClip(item.clip, x, y))) cmds = G.clipFilled(cmds, item.clip);
    }
    if (!cmds.length) return null;
    const out = custGeom(cmds, hasFill);
    box = out.box;
    geomXml = out.xml;
  }
  if (blur > 0) box = [box[0] - blur, box[1] - blur, box[2] + blur, box[3] + blur];
  const fillXml = hasFill ? paintXml(slide, item.fill, item, box, fillAlpha, patterns, media) : '<a:noFill/>';
  let lnXml = '<a:ln><a:noFill/></a:ln>';
  if (hasStroke) {
    const cap = { round: 'rnd', square: 'sq', butt: 'flat' }[item.cap] || 'flat';
    const join = { round: '<a:round/>', bevel: '<a:bevel/>' }[item.join] || '<a:miter lim="800000"/>';
    const sp = stroke.gradient ? { color: stroke.stops[0].color } : stroke;
    const strokePaint = sp.color ? paintXml(slide, sp, item, box, strokeAlpha * (stroke.gradient ? stroke.stops[0].opacity : 1), patterns, media) : '<a:noFill/>';
    lnXml = `<a:ln w="${Math.max(1, emu(sw))}" cap="${cap}">${strokePaint}${dash.xml || '<a:prstDash val="solid"/>'}${join}</a:ln>`;
  }
  const effect = blur > 0 ? `<a:effectLst><a:softEdge rad="${emu(blur * 2.2)}"/></a:effectLst>` : '';
  const id = slide.id++;
  const xfrm = `<a:xfrm><a:off x="${emu(box[0])}" y="${emu(box[1])}"/><a:ext cx="${Math.max(1, emu(box[2] - box[0]))}" cy="${Math.max(1, emu(box[3] - box[1]))}"/></a:xfrm>`;
  return `<p:sp><p:nvSpPr><p:cNvPr id="${id}" name="!!${item.tag}-${item.k}"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr>${xfrm}${geomXml}${fillXml}${lnXml}${effect}</p:spPr></p:sp>`;
}

function median(list) {
  const s = [...list].sort((m, n) => m - n);
  return s[Math.floor(s.length / 2)];
}

function textXml(slide, item) {
  const glyphs = item.chars;
  const chars = [...item.str];
  // 每個非空白字元依序對應一個字形；空白沿用前一個字的樣式。
  const seq = [];
  let gi = 0;
  for (const ch of chars) {
    if (ch === ' ') seq.push({ c: ' ', glyph: null });
    else seq.push({ c: ch, glyph: glyphs[gi++] || null });
  }
  const visible = glyphs.filter((g) => g.op > 0.01);
  if (!visible.length) return null;
  const size = median(visible.map((g) => g.size));
  const rot = median(visible.map((g) => g.rot));
  const rad = (rot * Math.PI) / 180;
  const ux = Math.cos(rad);
  const uy = Math.sin(rad);
  const first = seq.find((s) => s.glyph).glyph;
  // 基線取多數字元所在的位置（逐字浮現的動畫進行中時，少數字元可能還沒到位）。
  const along = (g) => (g.x - first.x) * ux + (g.y - first.y) * uy;
  const across = (g) => -(g.x - first.x) * uy + (g.y - first.y) * ux;
  const base = median(visible.map(across));
  const ox = first.x - uy * base;
  const oy = first.y + ux * base;
  const weight = item.weight || 400;

  const pos = seq.map((s) => (s.glyph ? along(s.glyph) : null));
  for (let i = 0; i < seq.length; i++) {
    if (pos[i] === null) pos[i] = i ? pos[i - 1] + advance(seq[i - 1].c, weight) * size : 0;
  }
  const runs = [];
  let lastStyle = { hex: '151E27', a: 0 };
  seq.forEach((s, i) => {
    const adv = advance(s.c, weight) * size;
    const next = i + 1 < seq.length ? pos[i + 1] : pos[i] + adv;
    const spc = i + 1 < seq.length ? Math.round((next - pos[i] - adv) * 50) : 0;
    let style = lastStyle;
    if (s.glyph) {
      const col = parseColor(s.glyph.fill) || { hex: '151E27', a: 1 };
      style = { hex: col.hex, a: col.a * s.glyph.op };
    }
    lastStyle = style;
    const key = `${style.hex}|${Math.round(style.a * 1000)}|${spc}`;
    const prev = runs[runs.length - 1];
    if (prev && prev.key === key) prev.text += s.c;
    else runs.push({ key, text: s.c, style, spc });
  });
  const width = pos[pos.length - 1] + advance(seq[seq.length - 1].c, weight) * size - pos[0];
  const W = width + size * 0.3;
  const H = size * LINE;
  // 外框中心：從基線起點沿文字方向與法線方向換算，旋轉時以中心為軸。
  const cxl = W / 2;
  const cyl = H / 2 - size * ASCENT;
  const cx = ox + cxl * ux - cyl * uy;
  const cy = oy + cxl * uy + cyl * ux;
  const family = FAMILY(weight);
  const bold = weight === 700 ? ' b="1"' : '';
  const sz = Math.max(100, Math.round(size * 50));
  const rPr = (r) =>
    `<a:rPr lang="zh-TW" altLang="en-US" sz="${sz}"${bold} kern="0"${r.spc ? ` spc="${Math.max(-400000, Math.min(400000, r.spc))}"` : ''} dirty="0">${solid(r.style.hex, r.style.a)}<a:latin typeface="${family}"/><a:ea typeface="${family}"/><a:cs typeface="${family}"/></a:rPr>`;
  const body = runs.map((r) => `<a:r>${rPr(r)}<a:t>${esc(r.text)}</a:t></a:r>`).join('');
  const id = slide.id++;
  const rotAttr = Math.abs(rot) > 0.05 ? ` rot="${Math.round(((rot % 360) + 360) % 360 * 60000)}"` : '';
  const xfrm = `<a:xfrm${rotAttr}><a:off x="${emu(cx - W / 2)}" y="${emu(cy - H / 2)}"/><a:ext cx="${emu(W)}" cy="${emu(H)}"/></a:xfrm>`;
  return (
    `<p:sp><p:nvSpPr><p:cNvPr id="${id}" name="!!text-${item.k}" descr="${esc(item.str)}"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>` +
    `<p:spPr>${xfrm}<a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/></p:spPr>` +
    `<p:txBody><a:bodyPr wrap="none" lIns="0" tIns="0" rIns="0" bIns="0" rtlCol="0" anchor="t"><a:noAutofit/></a:bodyPr><a:lstStyle/>` +
    `<a:p><a:pPr algn="l"><a:lnSpc><a:spcPct val="100000"/></a:lnSpc><a:spcBef><a:spcPts val="0"/></a:spcBef><a:spcAft><a:spcPts val="0"/></a:spcAft></a:pPr>${body}<a:endParaRPr lang="zh-TW" sz="${sz}"/></a:p></p:txBody></p:sp>`
  );
}

function transitionXml(trans, hold, first) {
  const adv = hold === null ? '' : ` advTm="${Math.max(0, Math.round(hold * 1000))}"`;
  if (first) return adv ? `<p:transition${adv}/>` : '';
  const dur = Math.max(10, Math.min(59990, Math.round(trans * 1000)));
  return (
    '<mc:AlternateContent xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006">' +
    `<mc:Choice xmlns:p159="http://schemas.microsoft.com/office/powerpoint/2015/09/main" Requires="p159"><p:transition spd="fast" p14:dur="${dur}"${adv}><p159:morph option="byObject"/></p:transition></mc:Choice>` +
    `<mc:Fallback><p:transition spd="fast"${adv}><p:fade/></p:transition></mc:Fallback>` +
    '</mc:AlternateContent>'
  );
}

function main() {
  const data = JSON.parse(fs.readFileSync(framesFile, 'utf8'));
  const { patterns } = data;
  const { slides: allKeys } = JSON.parse(fs.readFileSync(keysFile, 'utf8'));
  // 略過文字動作進行到一半的畫面，下一張的轉場改從被略過那張的轉場起點開始。
  const frames = [];
  const keys = [];
  let carry = null;
  data.frames.forEach((frame, i) => {
    const key = allKeys[i];
    if (frame.partial && i > 0 && i < data.frames.length - 1) {
      if (carry === null) carry = key.start;
      return;
    }
    frames.push(frame);
    keys.push({ t: key.t, start: carry ?? key.start });
    carry = null;
  });
  const media = {};
  const slides = frames.map((frame, i) => {
    const slide = new Slide();
    const parts = [];
    for (const item of frame.items) {
      const xml = item.type === 'text' ? textXml(slide, item) : shapeXml(slide, item, patterns, media);
      if (xml) parts.push(xml);
    }
    const key = keys[i];
    const next = keys[i + 1];
    const hold = next ? Math.max(0, next.start - key.t) : null;
    const tree =
      '<p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>' +
      parts.join('') +
      '</p:spTree>';
    const xml =
      P.HEAD +
      `<p:sld xmlns:a="${P.NS_A}" xmlns:r="${P.NS_R}" xmlns:p="${P.NS_P}" xmlns:p14="http://schemas.microsoft.com/office/powerpoint/2010/main">` +
      `<p:cSld name="${(frame.t).toFixed(1)}s">${tree}</p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>` +
      transitionXml(key.t - key.start, hold, i === 0) +
      '</p:sld>';
    process.stderr.write(`第 ${i + 1} 張（${frame.t.toFixed(1)} 秒）：${parts.length} 個物件\n`);
    return { xml, images: slide.images };
  });
  P.write({ out: OUT, slides, media, title: '救「舊」我的書｜介紹動畫', bg: C.stage.slice(1).toUpperCase(), font: 'Noto Sans TC' });
  console.log(`已輸出 ${OUT}（${slides.length} 張投影片）`);
}

main();
