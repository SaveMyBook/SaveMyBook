'use strict';

// 逐格檢查文字是否被其他物件遮住：每個取樣時間各截一張完整畫面與「只顯示文字」的畫面，
// 文字實心像素若在完整畫面中顏色不同，代表上方有物件蓋住；另以外框檢查文字彼此重疊。
const path = require('path');
const fs = require('fs');
const puppeteer = require('puppeteer');
const { PNG } = require('pngjs');

const [file, from = '0', to = '177', step = '0.1', out = 'check-report.json'] = process.argv.slice(2);
const SCALE = 1;
const CELL = 24;

const TEXT_ONLY = 'svg{background:transparent!important}svg > :not(defs),svg > :not(defs) *{visibility:hidden!important}svg .tx,svg .tx *{visibility:visible!important}';

async function settle(page) {
  await page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))));
}

async function main() {
  const browser = await puppeteer.launch({ headless: 'shell', args: ['--hide-scrollbars'] });
  const page = await browser.newPage();
  await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: SCALE });
  await page.goto(`file://${path.resolve(file)}`, { waitUntil: 'load' });
  await page.evaluate((css) => {
    const s = document.documentElement;
    s.pauseAnimations();
    const st = document.createElementNS('http://www.w3.org/2000/svg', 'style');
    st.id = '__tx';
    st.setAttribute('media', 'not all');
    st.textContent = css;
    s.appendChild(st);
  }, TEXT_ONLY);

  const findings = [];
  const t0 = Number(from);
  const t1 = Number(to);
  const dt = Number(step);
  for (let i = 0; t0 + i * dt <= t1 + 1e-9; i++) {
    const t = Math.round((t0 + i * dt) * 1000) / 1000;
    await page.evaluate((tt) => document.documentElement.setCurrentTime(tt), t);
    await page.evaluate(() => document.getElementById('__tx').setAttribute('media', 'not all'));
    await settle(page);
    const full = PNG.sync.read(await page.screenshot({ type: 'png' }));
    await page.evaluate(() => document.getElementById('__tx').setAttribute('media', 'all'));
    await settle(page);
    const txt = PNG.sync.read(await page.screenshot({ type: 'png', omitBackground: true }));
    await page.evaluate(() => document.getElementById('__tx').setAttribute('media', 'not all'));
    await settle(page);

    const W = full.width;
    const H = full.height;
    const cells = new Map();
    for (let y = 0; y < H; y++) {
      for (let x = 0; x < W; x++) {
        const k = (y * W + x) * 4;
        if (txt.data[k + 3] < 250) continue;
        const d = Math.abs(full.data[k] - txt.data[k]) + Math.abs(full.data[k + 1] - txt.data[k + 1]) + Math.abs(full.data[k + 2] - txt.data[k + 2]);
        if (d < 120) continue;
        const key = `${Math.floor(x / CELL)},${Math.floor(y / CELL)}`;
        cells.set(key, (cells.get(key) || 0) + 1);
      }
    }
    const hot = [...cells.entries()].filter(([, n]) => n >= 24).map(([key, n]) => {
      const [cx, cy] = key.split(',').map(Number);
      return { x: ((cx + 0.5) * CELL) / SCALE, y: ((cy + 0.5) * CELL) / SCALE, n };
    });
    const info = await page.evaluate((pts) => {
      const eff = (el) => {
        let o = 1;
        for (let n = el; n && n.nodeType === 1; n = n.parentNode) {
          const cs = getComputedStyle(n);
          if (cs.display === 'none' || cs.visibility === 'hidden') return 0;
          o *= Number(cs.opacity);
        }
        return o;
      };
      const label = (el) => {
        const tx = el.closest('.tx');
        if (tx) return `text「${tx.getAttribute('data-t')}」`;
        const bits = [el.tagName];
        for (const a of ['id', 'fill', 'stroke', 'd', 'width', 'r', 'href']) {
          const v = el.getAttribute(a);
          if (v) bits.push(`${a}=${v.slice(0, 40)}`);
        }
        return bits.join(' ');
      };
      return pts.map((p) => {
        const stack = document.elementsFromPoint(p.x, p.y);
        const ti = stack.findIndex((e) => e.closest && e.closest('.tx') && eff(e) > 0.5);
        if (ti < 0) return { ...p, text: null, cover: null };
        const textEl = stack[ti].closest('.tx');
        const glass = (e) => e.tagName === 'rect' && Number(e.getAttribute('width')) === 402 && /url\(#.*g\)/.test(e.getAttribute('fill') || '');
        const above = stack.slice(0, ti).filter((e) => !textEl.contains(e) && !e.contains(textEl) && eff(e) > 0.05 && !glass(e));
        if (!above.length) return { ...p, text: null, cover: null };
        return { ...p, text: textEl.getAttribute('data-t'), cover: label(above[0]) };
      });
    }, hot);
    const overlaps = await page.evaluate(() => {
      const eff = (el) => {
        let o = 1;
        for (let n = el; n && n.nodeType === 1; n = n.parentNode) {
          const cs = getComputedStyle(n);
          if (cs.display === 'none' || cs.visibility === 'hidden') return 0;
          o *= Number(cs.opacity);
        }
        return o;
      };
      const items = [];
      document.querySelectorAll('.tx').forEach((el) => {
        if (/^\d$/.test(el.getAttribute('data-t'))) return;
        const uses = [...el.querySelectorAll('use')].filter((u) => eff(u) > 0.5);
        if (!uses.length) return;
        const rs = uses.map((u) => u.getBoundingClientRect());
        const r = { left: Math.min(...rs.map((q) => q.left)), top: Math.min(...rs.map((q) => q.top)), right: Math.max(...rs.map((q) => q.right)), bottom: Math.max(...rs.map((q) => q.bottom)) };
        if (r.right - r.left < 2 || r.bottom - r.top < 2 || r.right < 0 || r.bottom < 0 || r.left > 1920 || r.top > 1080) return;
        items.push({ t: el.getAttribute('data-t'), r: [r.left, r.top, r.right, r.bottom], el });
      });
      const res = [];
      for (let i = 0; i < items.length; i++) {
        for (let j = i + 1; j < items.length; j++) {
          const a = items[i].r;
          const b = items[j].r;
          const w = Math.min(a[2], b[2]) - Math.max(a[0], b[0]);
          const h = Math.min(a[3], b[3]) - Math.max(a[1], b[1]);
          if (w <= 3 || h <= 3) continue;
          if (items[i].el.contains(items[j].el) || items[j].el.contains(items[i].el)) continue;
          const area = w * h;
          const small = Math.min((a[2] - a[0]) * (a[3] - a[1]), (b[2] - b[0]) * (b[3] - b[1]));
          if (area / small < 0.08) continue;
          res.push({ a: items[i].t, b: items[j].t, ratio: Math.round((area / small) * 100) / 100 });
        }
      }
      return res;
    });
    const covered = info.filter((c) => c.text);
    if (covered.length || overlaps.length) findings.push({ t, covered, overlaps });
    if (i % 50 === 0) process.stderr.write(`t=${t} findings=${findings.length}\n`);
  }
  fs.writeFileSync(out, JSON.stringify(findings, null, 1));
  await browser.close();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
