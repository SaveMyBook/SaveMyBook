'use strict';

// 將 check.js 的逐格結果依「文字＋遮擋物」合併成連續時段，方便逐項處理。
const fs = require('fs');

const files = process.argv.slice(2);
const rows = files.flatMap((f) => JSON.parse(fs.readFileSync(f, 'utf8')));
const groups = new Map();
for (const r of rows) {
  for (const c of r.covered) {
    const key = `遮擋｜${c.text}｜${c.cover}`;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push({ t: r.t, x: Math.round(c.x), y: Math.round(c.y), n: c.n });
  }
  for (const o of r.overlaps) {
    if (/^\d$/.test(o.a) || /^\d$/.test(o.b)) continue;
    const key = `重疊｜${o.a}｜${o.b}`;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push({ t: r.t, ratio: o.ratio });
  }
}
const spans = (list) => {
  const ts = [...new Set(list.map((x) => x.t))].sort((a, b) => a - b);
  const out = [];
  for (const t of ts) {
    const last = out[out.length - 1];
    if (last && t - last[1] <= 0.15) last[1] = t;
    else out.push([t, t]);
  }
  return out.map(([a, b]) => (a === b ? `${a}` : `${a}–${b}`)).join(', ');
};
const summary = [...groups.entries()]
  .map(([key, list]) => ({ key, samples: list.length, spans: spans(list), at: list[0].x !== undefined ? `(${list[0].x},${list[0].y})` : '' }))
  .sort((a, b) => b.samples - a.samples);
for (const s of summary) console.log(`${String(s.samples).padStart(4)}  ${s.key} ${s.at}\n      ${s.spans}`);
