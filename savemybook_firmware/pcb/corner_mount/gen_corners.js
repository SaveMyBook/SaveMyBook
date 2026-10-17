// DoorLock_ESP32S3 PCB 四角固定座 STL 產生器（機甲裝甲版）
// 用法：node gen_corners.js [--res 0.2] [--assembly <資料夾>]
//   --res       網格解析度 (mm)，越小越細緻、檔案越大
//   --assembly  另外輸出「裝在板子上位置」的 STL，給預覽渲染用
//
// 造型：多面切削的裝甲側牆、45° 切角轉角、刀鋒狀斜切臂端、斜向散熱格柵；
// 轉角立一片後掠鯊魚鰭（中間鏤空三角窗）。
// 列印：底面朝下、免支撐；所有向外伸的斜面都 ≤ 45°，鰭最薄處 ≥ 1 mm，鰭頂是 1 mm 平台不是尖點。
// 夾板槽上方不做平頂（懸空會塌），改成從槽底 45° 往板內上升的壓簷。
// 不鎖螺絲，底面全平，用雙面膠或熱熔膠固定。
// 板子 133.05 × 81.00 × 1.6 mm，沒有固定孔，靠四角溝槽夾住。
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const P = {
  gap: 0.25,      // 板邊與側牆的水平間隙
  depth: 2.0,     // 夾片伸進板內的深度（不可超過 2.5，左上角會壓到 J5 焊盤）
  boardZ: 4.5,    // 板子底面離安裝面高度（板底焊點需 ≥ 3 mm）
  pcbT: 1.6,      // 板厚
  lipGap: 0.15,   // 板邊上緣與 45° 壓簷之間的間隙
  top: 8.0,       // 側牆頂高（要跟 armor 最後一點一致）
  ramp: 3.0,      // 臂端斜削：底部比頂部長出多少
  blade: 0.8,     // 臂端平面斜切：越外側越短（刀鋒感）
  // 側牆外輪廓 [離板邊距離 s, 高度 z]，由下往上；最後一點是頂部外緣
  armor: [[5.5, 0], [5.5, 1.0], [4.4, 3.0], [2.6, 7.2], [1.8, 8.0]],
  topChamfer: 0.6, // 內側上緣倒角
  // 鯊魚鰭輪廓 [沿對角線往外 u, 高度 z]
  // 後掠鯊魚鰭：前緣往外上掃、後緣內凹再外翻（後緣外翻斜率 < 45°，免支撐）
  fin: [[0.5, 0], [13, 0], [13, 1.2], [11.2, 6], [10.8, 10], [11.2, 14], [12.2, 17.5], [13.4, 20.0],
        [12.4, 20.0], [9.5, 18.2], [6.0, 15.0], [3.4, 11.4], [1.5, 8], [0.5, 8]],
  finWindow: [[5.6, 10.0], [8.8, 10.0], [9.4, 15.6]], // 窗左緣斜率 34°，免支撐
  finHalfBase: 1.6, // 鰭底部半厚
  finHalfTop: 1.0,  // 鰭頂部半厚
  finChamfer: 0.5,
  vent: { z0: 4.0, z1: 6.4, start: 4.0, margin: 3.5, pitch: 2.4, r: 0.6, depth: 0.7, slant: 0.6 }, // 斜槽：高度範圍、起點、離臂端距離、間距、半寬、深度、傾斜
  res: 0.15,
};

// la/lb：夾片（含側牆）沿上下邊 / 左右邊的長度，從板角量起，避開接頭
// laW/lbW：只有外側牆（不壓到板面）的延伸長度
// mx/my：鏡像方向，本地座標中板子永遠位於 +x、+y
const CORNERS = {
  BL: { mx: 1, my: 1, la: 4, lb: 15, laW: 15, lbW: 15 },  // 左下：下邊 X 5.6 起是 J7 排針
  BR: { mx: -1, my: 1, la: 15, lb: 7, laW: 15, lbW: 7 },  // 右下：右邊 Y 8.5 起是 J4 端子台
  TL: { mx: 1, my: -1, la: 15, lb: 2, laW: 15, lbW: 2 },  // 左上：左邊 Y 68–78 是 DC 插座
  TR: { mx: -1, my: -1, la: 15, lb: 6, laW: 15, lbW: 6 }, // 右上：右邊 Y 64–74 是 J1 端子台
};
const BOARD = { w: 133.05, h: 81.0 };

const args = process.argv.slice(2);
const argVal = (k) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : null; };
if (argVal('--res')) P.res = +argVal('--res');

const smin = (a, b, k) => { const h = Math.max(k - Math.abs(a - b), 0) / k; return Math.min(a, b) - (h * h * k) / 4; };
const smax = (a, b, k) => -smin(-a, -b, k);
const clamp = (v, a, b) => Math.min(Math.max(v, a), b);

// 2D 多邊形有號距離（內部為負）
function sdPoly(v, px, py) {
  let d = (px - v[0][0]) ** 2 + (py - v[0][1]) ** 2, s = 1;
  for (let i = 0, j = v.length - 1; i < v.length; j = i, i++) {
    const ex = v[j][0] - v[i][0], ey = v[j][1] - v[i][1], wx = px - v[i][0], wy = py - v[i][1];
    const t = clamp((wx * ex + wy * ey) / (ex * ex + ey * ey), 0, 1);
    d = Math.min(d, (wx - ex * t) ** 2 + (wy - ey * t) ** 2);
    const c1 = py >= v[i][1], c2 = py < v[j][1], c3 = ex * wy > ey * wx;
    if ((c1 && c2 && c3) || (!c1 && !c2 && !c3)) s = -s;
  }
  return s * Math.sqrt(d);
}
const sdSeg = (px, py, ax, ay, bx, by) => {
  const ex = bx - ax, ey = by - ay, t = clamp(((px - ax) * ex + (py - ay) * ey) / (ex * ex + ey * ey), 0, 1);
  return Math.hypot(px - ax - ex * t, py - ay - ey * t);
};

// 本地座標的有號距離場：< 0 為實體
function makeSdf(c) {
  const { gap: g, depth: d, boardZ, pcbT, lipGap, top, ramp, blade, armor, topChamfer: tc } = P;
  const ti = -(d + g); // 夾片尖端的 s
  const bodyProfile = [[ti, 0], ...armor, [ti + tc, top], [ti, top - tc]];
  const extProfile = [[0, 0], ...armor, [tc, top], [0, top - tc]];
  // 外輪廓在高度 z 的 s 值（給格柵用）
  const outerAt = (z) => {
    for (let i = 1; i < armor.length; i++) if (z <= armor[i][1]) { const [s0, z0] = armor[i - 1], [s1, z1] = armor[i]; return s0 + (s1 - s0) * (z - z0) / (z1 - z0 || 1); }
    return armor[armor.length - 1][0];
  };
  const endAt = (L, z, s) => L + ramp * (1 - clamp(z, 0, top) / top) - blade * Math.max(s, 0);
  const finTop = Math.max(...P.fin.map((p) => p[1]));
  const halfFin = (z) => P.finHalfBase + (P.finHalfTop - P.finHalfBase) * clamp(z / finTop, 0, 1);
  const K = 0.3; // 稜線小圓角，順便消除網格鋸齒
  const smax3 = (a, b, c) => smax(smax(a, b, K), c, K);
  const V = P.vent;

  return (x, y, z) => {
    const qx = x + g, qy = y + g;
    // s：到「板子 + 間隙」區域的距離，轉角用 45° 切角（八角形距離）
    const s = Math.max(-qx, -qy, (-qx - qy) * Math.SQRT1_2);

    // 主體：裝甲側牆 + 伸進板內的夾片
    let body = smax3(sdPoly(bodyProfile, s, z), x - endAt(c.la, z, s), y - endAt(c.lb, z, s));
    // 夾板溝槽：底面平（從床上長起來）；上方不是平頂，而是從槽底往板內 45° 上升的壓簷，
    // 每層都疊在前一層上，免支撐。壓簷在板邊（離槽底 gap）處比板面高 lipGap。
    const inward = Math.min(qx, qy); // 離槽底牆的水平距離
    const ceil = boardZ + pcbT + lipGap + (inward - g);
    const slab = Math.max(-qx, -qy, boardZ - z, (z - ceil) * Math.SQRT1_2);
    body = smax(body, -slab, 0.35);
    // 只在板外的延伸側牆
    const ext = smax3(sdPoly(extProfile, s, z), x - endAt(c.laW, z, s), y - endAt(c.lbW, z, s));

    // 鯊魚鰭：對角線平面上的輪廓，厚度往上收、側緣倒角，中間鏤空三角窗
    const u = (-qx - qy) * Math.SQRT1_2, v = (qx - qy) * Math.SQRT1_2;
    const hf = halfFin(z);
    const fp = sdPoly(P.fin, u, z);
    let fin = smax3(fp, Math.abs(v) - hf, (Math.abs(v) + fp - (hf - P.finChamfer)) * Math.SQRT1_2);
    fin = smax(fin, -sdPoly(P.finWindow, u, z), K);

    let f = Math.min(body, ext, fin);

    // 斜向散熱格柵：只刻在側牆外側上斜面，離轉角與臂端各留一段
    const alongX = -qy > -qx; // 在下/上邊那條臂
    const along = alongX ? x : y;
    const armEnd = alongX ? Math.max(c.la, c.laW) : Math.max(c.lb, c.lbW);
    const run = V.slant * (V.z1 - V.z0);
    const n = Math.floor((armEnd - V.margin - run - V.start) / V.pitch) + 1;
    if (n > 0 && s > 0 && z > V.z0 - 1.5 && z < V.z1 + 1.5) {
      // 圓角膠囊形斜槽
      const k0 = Math.round((along - V.slant * (z - V.z0) - V.start) / V.pitch);
      let cd = Infinity;
      for (let k = Math.max(0, k0 - 1); k <= Math.min(n - 1, k0 + 1); k++) {
        const a0 = V.start + k * V.pitch;
        cd = Math.min(cd, sdSeg(along, z, a0, V.z0, a0 + run, V.z1));
      }
      const cut = Math.max(cd - V.r, outerAt(z) - V.depth - s);
      f = smax(f, -cut, 0.2);
    }

    return Math.max(f, -z); // 平底
  };
}

// Kuhn 六面體分割的 marching tetrahedra，相鄰格子共用邊 → 網格封閉
const CUBE = [[0, 0, 0], [1, 0, 0], [1, 1, 0], [0, 1, 0], [0, 0, 1], [1, 0, 1], [1, 1, 1], [0, 1, 1]];
const TETS = [[0, 5, 1, 6], [0, 1, 2, 6], [0, 2, 3, 6], [0, 3, 7, 6], [0, 7, 4, 6], [0, 4, 5, 6]];

function polygonize(f, lo, hi, h) {
  const nx = Math.ceil((hi[0] - lo[0]) / h) + 1, ny = Math.ceil((hi[1] - lo[1]) / h) + 1, nz = Math.ceil((hi[2] - lo[2]) / h) + 1;
  const val = new Float64Array(nx * ny * nz);
  const id = (i, j, k) => (k * ny + j) * nx + i;
  const pos = (n) => { const i = n % nx, j = Math.floor(n / nx) % ny, k = Math.floor(n / (nx * ny)); return [lo[0] + i * h, lo[1] + j * h, lo[2] + k * h]; };
  for (let k = 0; k < nz; k++)
    for (let j = 0; j < ny; j++)
      for (let i = 0; i < nx; i++) {
        let v = (i === 0 || j === 0 || k === 0 || i === nx - 1 || j === ny - 1 || k === nz - 1) ? 1 : f(lo[0] + i * h, lo[1] + j * h, lo[2] + k * h);
        if (v === 0) v = 1e-9;
        val[id(i, j, k)] = v;
      }
  const verts = [];
  const ends = [];
  const vmap = new Map();
  const edgeVert = (a, b) => {
    if (a > b) [a, b] = [b, a];
    const key = a * 8 + (b - a === 1 ? 0 : b - a === nx ? 1 : b - a === nx * ny ? 2 : 3 + [nx + 1, nx * ny + 1, nx * ny + nx, nx * ny + nx + 1].indexOf(b - a));
    let v = vmap.get(key);
    if (v === undefined) {
      const pa = pos(a), pb = pos(b), t = val[a] / (val[a] - val[b]);
      v = verts.length;
      verts.push([pa[0] + (pb[0] - pa[0]) * t, pa[1] + (pb[1] - pa[1]) * t, pa[2] + (pb[2] - pa[2]) * t]);
      ends.push([a, b]);
      vmap.set(key, v);
    }
    return v;
  };
  const faces = [];
  const emit = (tri, insideIds, outsideIds) => {
    const mid = (v) => { const [p, q] = ends[v].map(pos); return [(p[0] + q[0]) / 2, (p[1] + q[1]) / 2, (p[2] + q[2]) / 2]; };
    const [a, b, c] = tri.map(mid);
    const n = [(b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1]), (b[2] - a[2]) * (c[0] - a[0]) - (b[0] - a[0]) * (c[2] - a[2]), (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])];
    const ci = [0, 1, 2].map((q) => insideIds.reduce((s, g) => s + pos(g)[q], 0) / insideIds.length);
    const co = [0, 1, 2].map((q) => outsideIds.reduce((s, g) => s + pos(g)[q], 0) / outsideIds.length);
    const dir = n[0] * (co[0] - ci[0]) + n[1] * (co[1] - ci[1]) + n[2] * (co[2] - ci[2]);
    faces.push(dir >= 0 ? tri : [tri[0], tri[2], tri[1]]);
  };
  for (let k = 0; k < nz - 1; k++)
    for (let j = 0; j < ny - 1; j++)
      for (let i = 0; i < nx - 1; i++) {
        const g = CUBE.map(([a, b, c]) => id(i + a, j + b, k + c));
        let any = 0, all = 1;
        for (const n of g) { const ins = val[n] < 0; any |= ins; all &= ins; }
        if (!any || all) continue;
        for (const T of TETS) {
          const ids = T.map((t) => g[t]);
          const ins = ids.filter((n) => val[n] < 0), out = ids.filter((n) => val[n] >= 0);
          if (ins.length === 0 || out.length === 0) continue;
          if (ins.length === 1 || out.length === 1) {
            const lone = ins.length === 1 ? ins[0] : out[0];
            const others = ins.length === 1 ? out : ins;
            emit(others.map((o) => edgeVert(lone, o)), ins, out);
          } else {
            const [a, b] = ins, [c, d] = out;
            const ac = edgeVert(a, c), ad = edgeVert(a, d), bc = edgeVert(b, c), bd = edgeVert(b, d);
            emit([ac, ad, bd], ins, out);
            emit([ac, bd, bc], ins, out);
          }
        }
      }
  return { verts, faces };
}

function check({ verts, faces }) {
  const edges = new Map();
  for (const t of faces) for (let e = 0; e < 3; e++) { const k = t[e] + ',' + t[(e + 1) % 3]; edges.set(k, (edges.get(k) || 0) + 1); }
  let bad = 0;
  for (const [k, n] of edges) { const [a, b] = k.split(','); if (n !== 1 || edges.get(b + ',' + a) !== 1) bad++; }
  let vol = 0;
  for (const [a, b, c] of faces) {
    const [p, q, r] = [verts[a], verts[b], verts[c]];
    vol += (p[0] * (q[1] * r[2] - q[2] * r[1]) - p[1] * (q[0] * r[2] - q[2] * r[0]) + p[2] * (q[0] * r[1] - q[1] * r[0])) / 6;
  }
  return { bad, vol };
}

function writeStl(file, meshes) {
  const total = meshes.reduce((s, m) => s + m.faces.length, 0);
  const buf = Buffer.alloc(84 + total * 50);
  buf.write('DoorLock_ESP32S3 corner mount', 0);
  buf.writeUInt32LE(total, 80);
  let o = 84;
  for (const { verts, faces, tf } of meshes)
    for (const t of faces) {
      const [a, b, c] = t.map((v) => tf(verts[v]));
      const n = [(b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1]), (b[2] - a[2]) * (c[0] - a[0]) - (b[0] - a[0]) * (c[2] - a[2]), (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])];
      const l = Math.hypot(...n) || 1;
      for (const v of [n[0] / l, n[1] / l, n[2] / l, ...a, ...b, ...c]) { buf.writeFloatLE(v, o); o += 4; }
      buf.writeUInt16LE(0, o); o += 2;
    }
  fs.writeFileSync(file, buf);
}

// 3MF（zip + XML，比 STL 小很多，Bambu / Prusa / Cura 都能開），每個角座是獨立物件
const CRC = (() => { const t = new Uint32Array(256); for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; } return t; })();
const crc32 = (b) => { let c = 0xffffffff; for (let i = 0; i < b.length; i++) c = CRC[(c ^ b[i]) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
function zip(file, entries) {
  const locals = [], centrals = [];
  let offset = 0;
  for (const [name, text] of entries) {
    const raw = Buffer.from(text, 'utf8'), comp = zlib.deflateRawSync(raw, { level: 9 }), nb = Buffer.from(name);
    const h = Buffer.alloc(30);
    h.writeUInt32LE(0x04034b50, 0); h.writeUInt16LE(20, 4); h.writeUInt16LE(8, 8);
    h.writeUInt32LE(crc32(raw), 14); h.writeUInt32LE(comp.length, 18); h.writeUInt32LE(raw.length, 22); h.writeUInt16LE(nb.length, 26);
    const c = Buffer.alloc(46);
    c.writeUInt32LE(0x02014b50, 0); c.writeUInt16LE(20, 4); c.writeUInt16LE(20, 6); c.writeUInt16LE(8, 10);
    c.writeUInt32LE(crc32(raw), 16); c.writeUInt32LE(comp.length, 20); c.writeUInt32LE(raw.length, 24); c.writeUInt16LE(nb.length, 28); c.writeUInt32LE(offset, 42);
    locals.push(h, nb, comp); centrals.push(c, nb);
    offset += 30 + nb.length + comp.length;
  }
  const cd = Buffer.concat(centrals), end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0); end.writeUInt16LE(entries.length, 8); end.writeUInt16LE(entries.length, 10);
  end.writeUInt32LE(cd.length, 12); end.writeUInt32LE(offset, 16);
  fs.writeFileSync(file, Buffer.concat([...locals, cd, end]));
}
function write3mf(file, objects) {
  const NL = '\n';
  const parts = ['<?xml version="1.0" encoding="UTF-8"?>' + NL + '<model unit="millimeter" xml:lang="en-US" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02">' + NL + '<resources>' + NL];
  objects.forEach(({ name, verts, faces, tf }, i) => {
    parts.push(`<object id="${i + 1}" name="${name}" type="model"><mesh><vertices>` + NL);
    parts.push(verts.map((v) => { const p = tf(v); return `<vertex x="${p[0].toFixed(4)}" y="${p[1].toFixed(4)}" z="${p[2].toFixed(4)}"/>`; }).join(NL));
    parts.push(NL + '</vertices><triangles>' + NL);
    parts.push(faces.map(([a, b, c]) => `<triangle v1="${a}" v2="${b}" v3="${c}"/>`).join(NL));
    parts.push(NL + '</triangles></mesh></object>' + NL);
  });
  parts.push('</resources>' + NL + '<build>' + NL + objects.map((_, i) => `<item objectid="${i + 1}"/>`).join(NL) + NL + '</build>' + NL + '</model>' + NL);
  zip(file, [
    ['[Content_Types].xml', '<?xml version="1.0" encoding="UTF-8"?>' + NL + '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/></Types>'],
    ['_rels/.rels', '<?xml version="1.0" encoding="UTF-8"?>' + NL + '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Target="/3D/3dmodel.model" Id="rel0" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/></Relationships>'],
    ['3D/3dmodel.model', parts.join('')],
  ]);
}

function buildCorner(name) {
  const c = CORNERS[name];
  const g = P.gap, m = 1.0;
  const finU = Math.max(...P.fin.map((p) => p[0])), finZ = Math.max(...P.fin.map((p) => p[1]));
  const outer = -(g + finU * Math.SQRT1_2 + P.finHalfBase) - m;
  const lo = [outer, outer, -0.5];
  const hi = [Math.max(c.la, c.laW) + P.ramp + m, Math.max(c.lb, c.lbW) + P.ramp + m, finZ + m];
  const mesh = polygonize(makeSdf(c), lo, hi, P.res);
  // 鏡像後若行列式為負需翻轉法向
  mesh.verts = mesh.verts.map(([x, y, z]) => [x * c.mx, y * c.my, z]);
  if (c.mx * c.my < 0) mesh.faces = mesh.faces.map(([a, b, d]) => [a, d, b]);
  return mesh;
}

const outDir = __dirname;
const asmDir = argVal('--assembly');
const plate = [];
const layout = { TL: [0, 1], TR: [1, 1], BL: [0, 0], BR: [1, 0] };
const SPACING = 36;
for (const name of Object.keys(CORNERS)) {
  const t0 = Date.now();
  const mesh = buildCorner(name);
  const { bad, vol } = check(mesh);
  const mn = [Infinity, Infinity, Infinity], mx = [-Infinity, -Infinity, -Infinity];
  for (const p of mesh.verts) for (let i = 0; i < 3; i++) { mn[i] = Math.min(mn[i], p[i]); mx[i] = Math.max(mx[i], p[i]); }
  const size = mx.map((v, i) => (v - mn[i]).toFixed(1)).join(' x ');
  console.log(`${name}: ${mesh.faces.length} tris, ${size} mm, vol ${vol.toFixed(0)} mm3, bad edges ${bad}, ${Date.now() - t0} ms`);
  if (bad) process.exitCode = 1;
  const toOrigin = (p) => [p[0] - mn[0], p[1] - mn[1], p[2] - mn[2]];
  writeStl(path.join(outDir, `corner_${name}.stl`), [{ ...mesh, tf: toOrigin }]);
  const [lx, ly] = layout[name];
  plate.push({ ...mesh, name: `corner_${name}`, tf: (v) => { const p = toOrigin(v); return [p[0] + lx * SPACING, p[1] + ly * SPACING, p[2]]; } });
  if (asmDir) {
    const ox = CORNERS[name].mx < 0 ? BOARD.w : 0, oy = CORNERS[name].my < 0 ? BOARD.h : 0;
    writeStl(path.join(asmDir, `asm_${name}.stl`), [{ ...mesh, tf: (p) => [p[0] + ox, p[1] + oy, p[2]] }]);
  }
}
write3mf(path.join(outDir, 'corner_all_4.3mf'), plate);
