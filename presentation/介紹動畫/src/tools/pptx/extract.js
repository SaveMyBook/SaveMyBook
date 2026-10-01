'use strict';

// 將動畫定格在指定時間，讀出每個可見物件當下的幾何、顏色與透明度：
// node tools/pptx/extract.js <帶文字標記的 svg> <times.json> <out.json>
// svg 需以 SVG_TAG_TEXT=1 建置，文字群組才會帶有原文與字重。
const path = require('path');
const fs = require('fs');
const puppeteer = require('puppeteer');

const [svg, timesFile, out] = process.argv.slice(2);

// 在瀏覽器內執行：走訪整棵 SVG，輸出依繪製順序排列的物件清單。
function snapshot() {
  const root = document.documentElement;
  const SKIP = new Set(['defs', 'clipPath', 'linearGradient', 'radialGradient', 'pattern', 'filter', 'animate', 'animateTransform', 'animateMotion', 'set', 'title', 'style', 'mask', 'stop']);
  const SHAPES = new Set(['rect', 'circle', 'ellipse', 'line', 'path', 'polyline', 'polygon']);
  const items = [];
  // 只露出一部分的字形，供判斷文字是否正從遮罩中滑入或滾動到一半。
  const partial = [];
  const mat = (m) => [m.a, m.b, m.c, m.d, m.e, m.f];
  const apply = (m, x, y) => [m.a * x + m.c * y + m.e, m.b * x + m.d * y + m.f];
  const boxOf = (m, b) => {
    const pts = [apply(m, b.x, b.y), apply(m, b.x + b.width, b.y), apply(m, b.x, b.y + b.height), apply(m, b.x + b.width, b.y + b.height)];
    const xs = pts.map((p) => p[0]);
    const ys = pts.map((p) => p[1]);
    return [Math.min(...xs), Math.min(...ys), Math.max(...xs), Math.max(...ys)];
  };
  // 裁切範圍為 [x0, y0, x1, y1, 圓角半徑]；交集後保留與結果邊界重合那一方的圓角。
  const meet = (a, b) => {
    if (!a) return b;
    if (!b) return a;
    const box = [Math.max(a[0], b[0]), Math.max(a[1], b[1]), Math.min(a[2], b[2]), Math.min(a[3], b[3])];
    const same = (c) => c.slice(0, 4).every((v, i) => Math.abs(v - box[i]) < 0.5);
    box.push(same(b) ? b[4] || 0 : same(a) ? a[4] || 0 : 0);
    return box;
  };
  const overlaps = (a, c) => !c || (a[2] > c[0] && a[0] < c[2] && a[3] > c[1] && a[1] < c[3]);
  const urlId = (v) => {
    const m = /url\("?#([^")]+)"?\)/.exec(v || '');
    return m ? m[1] : null;
  };
  const anim = (el, name) => {
    const a = el[name];
    return a && a.animVal !== undefined ? (typeof a.animVal === 'object' && 'value' in a.animVal ? a.animVal.value : a.animVal) : Number(el.getAttribute(name) || 0);
  };

  function paint(v, op) {
    if (!v || v === 'none') return null;
    const id = urlId(v);
    if (!id) return { color: v };
    const def = document.getElementById(id);
    if (!def) return null;
    const tag = def.tagName;
    if (tag === 'pattern') return { pattern: id };
    const attrs = {};
    for (const a of ['x1', 'y1', 'x2', 'y2', 'cx', 'cy', 'r', 'fx', 'fy', 'gradientUnits', 'gradientTransform']) if (def.hasAttribute(a)) attrs[a] = def.getAttribute(a);
    const stops = [...def.querySelectorAll('stop')].map((s) => {
      const cs = getComputedStyle(s);
      return { offset: parseFloat(s.getAttribute('offset')), color: cs.stopColor, opacity: parseFloat(cs.stopOpacity) };
    });
    return { gradient: tag === 'linearGradient' ? 'linear' : 'radial', attrs, stops };
  }

  function clipBox(el, url) {
    const id = urlId(url);
    if (!id) return null;
    const cp = document.getElementById(id);
    if (!cp) return null;
    const kids = [...cp.children];
    if (kids.some((k) => k.tagName === 'use')) return 'text';
    const m = el.getCTM();
    let box = null;
    for (const k of kids) {
      let full = m;
      if (k.transform) for (const tr of k.transform.animVal) full = full.multiply(tr.matrix);
      const b = boxOf(full, k.getBBox());
      box = box ? [Math.min(box[0], b[0]), Math.min(box[1], b[1]), Math.max(box[2], b[2]), Math.max(box[3], b[3])] : b;
    }
    const k = kids[0];
    const r = kids.length === 1 && k.tagName === 'rect' ? anim(k, 'rx') * Math.hypot(m.a, m.b) : 0;
    box.push(r || 0);
    return box;
  }

  function text(el, op, clip) {
    const chars = [];
    const visit = (node, o) => {
      for (const k of node.children) {
        if (SKIP.has(k.tagName)) continue;
        const cs = getComputedStyle(k);
        if (cs.display === 'none') continue;
        const ko = o * parseFloat(cs.opacity);
        if (k.tagName === 'use') {
          const m = k.getCTM();
          const x = anim(k, 'x');
          const [px, py] = apply(m, x, 0);
          const scale = Math.hypot(m.a, m.b);
          const size = scale * 1000;
          const box = [px, py - size * 0.88, px + size, py + size * 0.12];
          // 字形中心在裁切範圍內、且高度至少六成露出才算可見（數字滾動途中只留最接近定位的那一個）。
          const share = (lo, hi, a, b) => Math.max(0, Math.min(hi, b) - Math.max(lo, a)) / (hi - lo);
          const cx = (box[0] + box[2]) / 2;
          const v = clip ? share(box[1], box[3], clip[1], clip[3]) : 1;
          const inside = !clip || (cx > clip[0] - size * 0.25 && cx < clip[2] + size * 0.25 && v >= 0.6);
          if (ko > 0.3 && v > 0.15 && v < 0.97 && cx > clip[0] && cx < clip[2]) partial.push(`${el.getAttribute('data-k')}:${chars.length}:${py.toFixed(1)}`);
          chars.push({ c: k.getAttribute('data-c'), x: px, y: py, size, rot: (Math.atan2(m.b, m.a) * 180) / Math.PI, fill: cs.fill, op: inside && cs.visibility !== 'hidden' ? ko * parseFloat(cs.fillOpacity) : 0 });
        } else {
          let c = clip;
          const cpv = k.getAttribute('clip-path');
          if (cpv) {
            const b = clipBox(k, cpv);
            if (b === 'text') continue;
            c = meet(c, b);
          }
          visit(k, ko);
        }
      }
    };
    visit(el, op);
    if (!chars.some((c) => c.op > 0.01)) return null;
    return { type: 'text', k: el.getAttribute('data-k'), str: el.getAttribute('data-t'), weight: Number(el.getAttribute('data-w')), ls: Number(el.getAttribute('data-ls') || 0), chars };
  }

  function shape(el, op, clip) {
    const cs = getComputedStyle(el);
    if (cs.visibility === 'hidden') return null;
    const m = el.getCTM();
    let bb;
    try {
      bb = el.getBBox();
    } catch (e) {
      return null;
    }
    const box = boxOf(m, bb);
    if (!overlaps(box, clip)) return null;
    const tag = el.tagName;
    const geo = {};
    if (tag === 'rect') {
      for (const a of ['x', 'y', 'width', 'height']) geo[a] = anim(el, a);
      let rx = el.hasAttribute('rx') ? anim(el, 'rx') : null;
      let ry = el.hasAttribute('ry') ? anim(el, 'ry') : null;
      geo.rx = rx ?? ry ?? 0;
      geo.ry = ry ?? rx ?? 0;
    } else if (tag === 'circle') {
      for (const a of ['cx', 'cy', 'r']) geo[a] = anim(el, a);
    } else if (tag === 'ellipse') {
      for (const a of ['cx', 'cy', 'rx', 'ry']) geo[a] = anim(el, a);
    } else if (tag === 'line') {
      for (const a of ['x1', 'y1', 'x2', 'y2']) geo[a] = anim(el, a);
    } else if (tag === 'path') {
      geo.d = el.getAttribute('d');
    } else {
      geo.points = el.getAttribute('points');
    }
    const fill = paint(cs.fill, op);
    const stroke = paint(cs.stroke, op);
    const sw = parseFloat(cs.strokeWidth);
    if (!fill && !(stroke && sw > 0)) return null;
    const filt = urlId(cs.filter);
    let blur = 0;
    if (filt) {
      const fb = document.getElementById(filt)?.querySelector('feGaussianBlur');
      if (fb) blur = parseFloat(fb.getAttribute('stdDeviation'));
    }
    return {
      type: 'shape',
      k: el.getAttribute('data-k'),
      tag,
      geo,
      m: mat(m),
      box,
      bbox: [bb.x, bb.y, bb.width, bb.height],
      clip,
      op,
      fill,
      fillOpacity: parseFloat(cs.fillOpacity),
      fillRule: cs.fillRule,
      stroke: stroke && sw > 0 ? stroke : null,
      strokeOpacity: parseFloat(cs.strokeOpacity),
      strokeWidth: sw,
      cap: cs.strokeLinecap,
      join: cs.strokeLinejoin,
      dash: cs.strokeDasharray,
      dashOffset: parseFloat(cs.strokeDashoffset),
      pathLength: el.getAttribute('pathLength'),
      len: cs.strokeDasharray !== 'none' && el.getTotalLength ? el.getTotalLength() : null,
      blur,
    };
  }

  function walk(el, op, clip) {
    for (const k of el.children) {
      const tag = k.tagName;
      if (SKIP.has(tag)) continue;
      const cs = getComputedStyle(k);
      if (cs.display === 'none') continue;
      const o = op * parseFloat(cs.opacity);
      if (o < 0.004) continue;
      let c = clip;
      const cpv = k.getAttribute('clip-path');
      if (cpv) {
        const b = clipBox(k, cpv);
        if (b === 'text') continue;
        c = meet(c, b);
        if (c[2] <= c[0] || c[3] <= c[1]) continue;
      }
      if (k.classList.contains('tx')) {
        const t = text(k, o, c);
        if (t) items.push(t);
      } else if (SHAPES.has(tag)) {
        const s = shape(k, o, c);
        if (s) items.push(s);
      } else if (tag === 'g' || tag === 'svg') {
        walk(k, o, c);
      }
    }
  }

  walk(root, 1, [0, 0, 1920, 1080, 0]);
  return { items, partial };
}

async function main() {
  const spec = JSON.parse(fs.readFileSync(timesFile, 'utf8'));
  const times = Array.isArray(spec) ? spec : spec.slides.map((s) => s.t);
  const browser = await puppeteer.launch({ headless: 'shell', args: ['--hide-scrollbars'] });
  const page = await browser.newPage();
  await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 1 });
  await page.goto(`file://${path.resolve(svg)}`, { waitUntil: 'load' });
  await page.evaluate(() => {
    const root = document.documentElement;
    root.pauseAnimations();
    let n = 0;
    for (const el of root.querySelectorAll('*')) el.setAttribute('data-k', (n++).toString(36));
  });
  const patterns = await page.evaluate(() =>
    Object.fromEntries(
      [...document.querySelectorAll('pattern')].map((p) => [
        p.id,
        {
          w: Number(p.getAttribute('width')),
          h: Number(p.getAttribute('height')),
          markup: p.innerHTML,
          kids: [...p.children].map((k) => Object.fromEntries([...k.attributes].map((a) => [a.name, a.value]).concat([['tag', k.tagName]]))),
        },
      ])
    )
  );
  // 圖樣填色先算成 4 倍解析度的磁磚圖，轉換時以圖片並排填滿。
  for (const [id, p] of Object.entries(patterns)) {
    const tile = await browser.newPage();
    await tile.setViewport({ width: p.w * 4, height: p.h * 4, deviceScaleFactor: 1 });
    await tile.setContent(`<html><body style="margin:0;background:transparent"><svg xmlns="http://www.w3.org/2000/svg" width="${p.w * 4}" height="${p.h * 4}" viewBox="0 0 ${p.w} ${p.h}">${p.markup}</svg></body></html>`);
    p.png = (await tile.screenshot({ type: 'png', omitBackground: true })).toString('base64');
    delete p.markup;
    await tile.close();
  }
  const frames = [];
  for (const t of times) {
    // 與 0.15 秒前比較：只露出一部分的字形若還在移動，代表文字動作進行中，轉換時略過這一格。
    await page.evaluate((tt) => document.documentElement.setCurrentTime(tt), Math.max(0, t - 0.15));
    const before = new Map((await page.evaluate(snapshot)).partial.map((p) => [p.slice(0, p.lastIndexOf(':')), Number(p.slice(p.lastIndexOf(':') + 1))]));
    await page.evaluate((tt) => document.documentElement.setCurrentTime(tt), t);
    const snap = await page.evaluate(snapshot);
    const { items } = snap;
    const moved = (p) => {
      const key = p.slice(0, p.lastIndexOf(':'));
      return !before.has(key) || Math.abs(before.get(key) - Number(p.slice(p.lastIndexOf(':') + 1))) > 3;
    };
    const partial = snap.partial.some(moved);
    frames.push({ t, items, partial });
    process.stderr.write(`${t.toFixed(2)}s ${items.length} 個物件${partial ? '（文字動作進行中）' : ''}\n`);
  }
  await browser.close();
  fs.writeFileSync(out, JSON.stringify({ patterns, frames }));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
