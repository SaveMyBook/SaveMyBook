'use strict';

// SVG 幾何 → 絕對座標的線段／貝茲曲線，供轉成 PowerPoint 自訂圖形。

function tokenize(d) {
  return d.match(/[a-zA-Z]|[-+]?(?:\d*\.\d+|\d+\.?\d*)(?:[eE][-+]?\d+)?/g) || [];
}

function arcToCubics(x1, y1, rx, ry, phi, large, sweep, x2, y2) {
  if (x1 === x2 && y1 === y2) return [];
  rx = Math.abs(rx);
  ry = Math.abs(ry);
  if (!rx || !ry) return [[x1, y1, x2, y2, x2, y2]];
  const rad = (phi * Math.PI) / 180;
  const cos = Math.cos(rad);
  const sin = Math.sin(rad);
  const dx = (x1 - x2) / 2;
  const dy = (y1 - y2) / 2;
  const xp = cos * dx + sin * dy;
  const yp = -sin * dx + cos * dy;
  const lam = (xp * xp) / (rx * rx) + (yp * yp) / (ry * ry);
  if (lam > 1) {
    rx *= Math.sqrt(lam);
    ry *= Math.sqrt(lam);
  }
  const num = rx * rx * ry * ry - rx * rx * yp * yp - ry * ry * xp * xp;
  const den = rx * rx * yp * yp + ry * ry * xp * xp;
  let co = Math.sqrt(Math.max(0, num / den));
  if (large === sweep) co = -co;
  const cxp = (co * rx * yp) / ry;
  const cyp = (-co * ry * xp) / rx;
  const cx = cos * cxp - sin * cyp + (x1 + x2) / 2;
  const cy = sin * cxp + cos * cyp + (y1 + y2) / 2;
  const ang = (ux, uy, vx, vy) => {
    const a = Math.atan2(ux * vy - uy * vx, ux * vx + uy * vy);
    return a;
  };
  const t1 = ang(1, 0, (xp - cxp) / rx, (yp - cyp) / ry);
  let dt = ang((xp - cxp) / rx, (yp - cyp) / ry, (-xp - cxp) / rx, (-yp - cyp) / ry);
  if (!sweep && dt > 0) dt -= 2 * Math.PI;
  if (sweep && dt < 0) dt += 2 * Math.PI;
  const n = Math.ceil(Math.abs(dt) / (Math.PI / 2) - 1e-9);
  const out = [];
  const step = dt / n;
  const k = (4 / 3) * Math.tan(step / 4);
  const pt = (t) => [cx + rx * Math.cos(t) * cos - ry * Math.sin(t) * sin, cy + rx * Math.cos(t) * sin + ry * Math.sin(t) * cos];
  const dv = (t) => [-rx * Math.sin(t) * cos - ry * Math.cos(t) * sin, -rx * Math.sin(t) * sin + ry * Math.cos(t) * cos];
  for (let i = 0; i < n; i++) {
    const a = t1 + i * step;
    const b = a + step;
    const [ax, ay] = pt(a);
    const [bx, by] = pt(b);
    const [dax, day] = dv(a);
    const [dbx, dby] = dv(b);
    out.push([ax + k * dax, ay + k * day, bx - k * dbx, by - k * dby, bx, by]);
  }
  return out;
}

// 回傳指令陣列：['M',x,y] ['L',x,y] ['C',x1,y1,x2,y2,x,y] ['Q',x1,y1,x,y] ['Z']
function parsePath(d) {
  const toks = tokenize(d);
  const out = [];
  let i = 0;
  let cmd = null;
  let x = 0;
  let y = 0;
  let sx = 0;
  let sy = 0;
  let lastC = null;
  let lastQ = null;
  const num = () => parseFloat(toks[i++]);
  const flag = () => {
    const t = toks[i];
    if (t.length > 1) {
      toks[i] = t.slice(1);
      return t[0] === '1' ? 1 : 0;
    }
    i++;
    return t === '1' ? 1 : 0;
  };
  while (i < toks.length) {
    if (/[a-zA-Z]/.test(toks[i])) cmd = toks[i++];
    else if (!cmd) break;
    const rel = cmd === cmd.toLowerCase();
    const C = cmd.toUpperCase();
    const ox = rel ? x : 0;
    const oy = rel ? y : 0;
    if (C === 'Z') {
      out.push(['Z']);
      x = sx;
      y = sy;
      lastC = lastQ = null;
      cmd = null;
      continue;
    }
    if (C === 'M') {
      x = ox + num();
      y = oy + num();
      sx = x;
      sy = y;
      out.push(['M', x, y]);
      cmd = rel ? 'l' : 'L';
      lastC = lastQ = null;
    } else if (C === 'L') {
      x = ox + num();
      y = oy + num();
      out.push(['L', x, y]);
      lastC = lastQ = null;
    } else if (C === 'H') {
      x = ox + num();
      out.push(['L', x, y]);
      lastC = lastQ = null;
    } else if (C === 'V') {
      y = oy + num();
      out.push(['L', x, y]);
      lastC = lastQ = null;
    } else if (C === 'C') {
      const c = [ox + num(), oy + num(), ox + num(), oy + num(), ox + num(), oy + num()];
      out.push(['C', ...c]);
      lastC = [c[2], c[3]];
      lastQ = null;
      x = c[4];
      y = c[5];
    } else if (C === 'S') {
      const r1 = lastC ? [2 * x - lastC[0], 2 * y - lastC[1]] : [x, y];
      const c = [ox + num(), oy + num(), ox + num(), oy + num()];
      out.push(['C', r1[0], r1[1], ...c]);
      lastC = [c[0], c[1]];
      lastQ = null;
      x = c[2];
      y = c[3];
    } else if (C === 'Q') {
      const c = [ox + num(), oy + num(), ox + num(), oy + num()];
      out.push(['Q', ...c]);
      lastQ = [c[0], c[1]];
      lastC = null;
      x = c[2];
      y = c[3];
    } else if (C === 'T') {
      const q = lastQ ? [2 * x - lastQ[0], 2 * y - lastQ[1]] : [x, y];
      const c = [ox + num(), oy + num()];
      out.push(['Q', q[0], q[1], ...c]);
      lastQ = q;
      lastC = null;
      x = c[0];
      y = c[1];
    } else if (C === 'A') {
      const rx = num();
      const ry = num();
      const phi = num();
      const large = flag();
      const sweep = flag();
      const ex = ox + num();
      const ey = oy + num();
      for (const c of arcToCubics(x, y, rx, ry, phi, large, sweep, ex, ey)) out.push(['C', ...c]);
      x = ex;
      y = ey;
      lastC = lastQ = null;
    } else {
      throw new Error(`不支援的路徑指令：${cmd}`);
    }
  }
  return out;
}

const K = 0.5522847498;

function ellipsePath(cx, cy, rx, ry) {
  // 與 SVG 相同：從 3 點鐘方向開始，順時針（y 軸向下）。
  return [
    ['M', cx + rx, cy],
    ['C', cx + rx, cy + ry * K, cx + rx * K, cy + ry, cx, cy + ry],
    ['C', cx - rx * K, cy + ry, cx - rx, cy + ry * K, cx - rx, cy],
    ['C', cx - rx, cy - ry * K, cx - rx * K, cy - ry, cx, cy - ry],
    ['C', cx + rx * K, cy - ry, cx + rx, cy - ry * K, cx + rx, cy],
    ['Z'],
  ];
}

function rectPath(x, y, w, h, rx, ry) {
  rx = Math.min(rx, w / 2);
  ry = Math.min(ry, h / 2);
  if (!rx || !ry) return [['M', x, y], ['L', x + w, y], ['L', x + w, y + h], ['L', x, y + h], ['Z']];
  const kx = rx * K;
  const ky = ry * K;
  return [
    ['M', x + rx, y],
    ['L', x + w - rx, y],
    ['C', x + w - rx + kx, y, x + w, y + ry - ky, x + w, y + ry],
    ['L', x + w, y + h - ry],
    ['C', x + w, y + h - ry + ky, x + w - rx + kx, y + h, x + w - rx, y + h],
    ['L', x + rx, y + h],
    ['C', x + rx - kx, y + h, x, y + h - ry + ky, x, y + h - ry],
    ['L', x, y + ry],
    ['C', x, y + ry - ky, x + rx - kx, y, x + rx, y],
    ['Z'],
  ];
}

// 四個角各自指定圓角半徑（左上、右上、右下、左下）的矩形。
function cornerPath([x0, y0, x1, y1], [tl, tr, br, bl]) {
  const lim = Math.min(x1 - x0, y1 - y0) / 2;
  [tl, tr, br, bl] = [tl, tr, br, bl].map((r) => Math.min(r, lim));
  const out = [['M', x0 + tl, y0], ['L', x1 - tr, y0]];
  if (tr) out.push(['C', x1 - tr + tr * K, y0, x1, y0 + tr - tr * K, x1, y0 + tr]);
  out.push(['L', x1, y1 - br]);
  if (br) out.push(['C', x1, y1 - br + br * K, x1 - br + br * K, y1, x1 - br, y1]);
  out.push(['L', x0 + bl, y1]);
  if (bl) out.push(['C', x0 + bl - bl * K, y1, x0, y1 - bl + bl * K, x0, y1 - bl]);
  out.push(['L', x0, y0 + tl]);
  if (tl) out.push(['C', x0, y0 + tl - tl * K, x0 + tl - tl * K, y0, x0 + tl, y0]);
  out.push(['Z']);
  return out;
}

function toPath(tag, geo) {
  if (tag === 'path') return parsePath(geo.d);
  if (tag === 'rect') return rectPath(geo.x, geo.y, geo.width, geo.height, geo.rx, geo.ry);
  if (tag === 'circle') return ellipsePath(geo.cx, geo.cy, geo.r, geo.r);
  if (tag === 'ellipse') return ellipsePath(geo.cx, geo.cy, geo.rx, geo.ry);
  if (tag === 'line') return [['M', geo.x1, geo.y1], ['L', geo.x2, geo.y2]];
  const nums = (geo.points || '').trim().split(/[\s,]+/).map(Number);
  const out = [];
  for (let i = 0; i + 1 < nums.length; i += 2) out.push([i ? 'L' : 'M', nums[i], nums[i + 1]]);
  if (tag === 'polygon') out.push(['Z']);
  return out;
}

function transform(cmds, [a, b, c, d, e, f]) {
  return cmds.map((cmd) => {
    if (cmd[0] === 'Z') return cmd;
    const out = [cmd[0]];
    for (let i = 1; i < cmd.length; i += 2) {
      const x = cmd[i];
      const y = cmd[i + 1];
      out.push(a * x + c * y + e, b * x + d * y + f);
    }
    return out;
  });
}

function bounds(cmds) {
  let x0 = Infinity;
  let y0 = Infinity;
  let x1 = -Infinity;
  let y1 = -Infinity;
  for (const cmd of cmds) {
    for (let i = 1; i < cmd.length; i += 2) {
      x0 = Math.min(x0, cmd[i]);
      x1 = Math.max(x1, cmd[i]);
      y0 = Math.min(y0, cmd[i + 1]);
      y1 = Math.max(y1, cmd[i + 1]);
    }
  }
  return [x0, y0, x1, y1];
}

// 圓角矩形裁切範圍內的點。
function insideClip([x0, y0, x1, y1, r = 0], x, y, eps = 0.5) {
  if (x < x0 - eps || x > x1 + eps || y < y0 - eps || y > y1 + eps) return false;
  if (!r) return true;
  const cx = Math.min(Math.max(x, x0 + r), x1 - r);
  const cy = Math.min(Math.max(y, y0 + r), y1 - r);
  return Math.hypot(x - cx, y - cy) <= r + eps;
}

function clipPolygon([x0, y0, x1, y1, r = 0]) {
  if (!r) return [[x0, y0], [x1, y0], [x1, y1], [x0, y1]];
  const pts = [];
  const arc = (cx, cy, a0) => {
    for (let i = 0; i <= 8; i++) {
      const a = a0 + (i / 8) * (Math.PI / 2);
      pts.push([cx + r * Math.cos(a), cy + r * Math.sin(a)]);
    }
  };
  arc(x1 - r, y0 + r, -Math.PI / 2);
  arc(x1 - r, y1 - r, 0);
  arc(x0 + r, y1 - r, Math.PI / 2);
  arc(x0 + r, y0 + r, Math.PI);
  return pts;
}

// 以凸多邊形（矩形或圓角矩形）裁切填色路徑：完全在範圍內的子路徑保留曲線，其餘攤平成折線後裁切。
function clipFilled(cmds, clip) {
  const subs = [];
  for (const c of cmds) {
    if (c[0] === 'M' || !subs.length) subs.push([]);
    subs[subs.length - 1].push(c);
  }
  const poly = clipPolygon(clip);
  const out = [];
  for (const sub of subs) {
    const pts = [];
    for (const c of sub) for (let i = 1; i < c.length; i += 2) pts.push([c[i], c[i + 1]]);
    if (pts.every(([x, y]) => insideClip(clip, x, y))) {
      out.push(...sub);
      continue;
    }
    let ring = [];
    let px = 0;
    let py = 0;
    for (const c of sub) {
      if (c[0] === 'M' || c[0] === 'L') ring.push([c[1], c[2]]);
      else if (c[0] === 'C' || c[0] === 'Q') {
        const n = 12;
        for (let i = 1; i <= n; i++) {
          const t = i / n;
          const u = 1 - t;
          if (c[0] === 'C') ring.push([u * u * u * px + 3 * u * u * t * c[1] + 3 * u * t * t * c[3] + t * t * t * c[5], u * u * u * py + 3 * u * u * t * c[2] + 3 * u * t * t * c[4] + t * t * t * c[6]]);
          else ring.push([u * u * px + 2 * u * t * c[1] + t * t * c[3], u * u * py + 2 * u * t * c[2] + t * t * c[4]]);
        }
      }
      if (c[0] !== 'Z') [px, py] = [c[c.length - 2], c[c.length - 1]];
    }
    for (let i = 0; i < poly.length && ring.length; i++) {
      const [ax, ay] = poly[i];
      const [bx, by] = poly[(i + 1) % poly.length];
      const side = ([x, y]) => (bx - ax) * (y - ay) - (by - ay) * (x - ax);
      const cut = (p, q) => {
        const sp = side(p);
        const sq = side(q);
        const t = sp / (sp - sq);
        return [p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t];
      };
      const next = [];
      for (let j = 0; j < ring.length; j++) {
        const cur = ring[j];
        const prev = ring[(j + ring.length - 1) % ring.length];
        const inCur = side(cur) >= 0;
        const inPrev = side(prev) >= 0;
        if (inCur) {
          if (!inPrev) next.push(cut(prev, cur));
          next.push(cur);
        } else if (inPrev) next.push(cut(prev, cur));
      }
      ring = next;
    }
    if (ring.length < 3) continue;
    ring.forEach(([x, y], j) => out.push([j ? 'L' : 'M', x, y]));
    out.push(['Z']);
  }
  return out;
}

module.exports = { parsePath, toPath, cornerPath, transform, bounds, insideClip, clipFilled };
