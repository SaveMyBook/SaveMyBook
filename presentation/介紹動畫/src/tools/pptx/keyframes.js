'use strict';

// 依畫面變化量挑選投影片時間點：node tools/pptx/keyframes.js <motion.json> <out.json>
// 每一張投影片取在一段動作結束、畫面最靜止的時刻；相鄰兩張之間的動作交給「變形」轉場補間。
const fs = require('fs');

const [motionFile, out] = process.argv.slice(2);
const { fps, duration, diff } = JSON.parse(fs.readFileSync(motionFile, 'utf8'));

const MIN_GAP = 0.9;
const MAX_GAP = 3.2;
const SMOOTH = Math.round(0.25 * fps);

const smooth = diff.map((_, i) => {
  let sum = 0;
  let n = 0;
  for (let j = Math.max(1, i - SMOOTH); j <= Math.min(diff.length - 1, i + SMOOTH); j++) {
    sum += diff[j];
    n++;
  }
  return n ? sum / n : 0;
});

// 區域最小值：在前後 0.5 秒內最小，且前後都有明顯的動作（避免在一段平移中途取點）。
const W = Math.round(0.5 * fps);
const minima = [];
for (let i = 1; i < smooth.length - 1; i++) {
  let isMin = true;
  for (let j = Math.max(0, i - W); j <= Math.min(smooth.length - 1, i + W); j++) {
    if (smooth[j] < smooth[i] || (smooth[j] === smooth[i] && j < i)) {
      isMin = false;
      break;
    }
  }
  if (!isMin) continue;
  const around = (from, to) => Math.max(...smooth.slice(Math.max(0, from), Math.min(smooth.length, to)));
  const rise = Math.min(around(i - 2 * fps, i), around(i, i + 2 * fps));
  if (rise - smooth[i] > 0.4 || smooth[i] < 0.1) minima.push(i);
}

// 間距太近的取較靜止者；間距太長的在中間補上較靜止的點。
let picks = [0];
for (const i of minima) {
  const last = picks[picks.length - 1];
  if ((i - last) / fps < MIN_GAP) {
    if (last !== 0 && smooth[i] < smooth[last]) picks[picks.length - 1] = i;
    continue;
  }
  picks.push(i);
}
const end = diff.length - 1;
if ((end - picks[picks.length - 1]) / fps > 0.5) picks.push(end);
const filled = [picks[0]];
for (let p = 1; p < picks.length; p++) {
  const a = filled[filled.length - 1];
  const b = picks[p];
  const n = Math.ceil((b - a) / fps / MAX_GAP);
  for (let k = 1; k < n; k++) {
    const center = Math.round(a + ((b - a) * k) / n);
    let best = center;
    for (let j = center - Math.round(0.4 * fps); j <= center + Math.round(0.4 * fps); j++) if (smooth[j] < smooth[best]) best = j;
    filled.push(best);
  }
  filled.push(b);
}
picks = filled;

// 每段轉場的開始點：前一張之後畫面開始明顯變化的時刻，之前的時間讓前一張停留。
const slides = picks.map((i, n) => {
  const t = i / fps;
  if (n === 0) return { t, start: 0 };
  const a = picks[n - 1];
  let peak = 0;
  for (let j = a + 1; j <= i; j++) peak = Math.max(peak, smooth[j]);
  const thresh = smooth[a] + 0.2 * (peak - smooth[a]);
  let s = a + 1;
  while (s < i && smooth[s] < thresh) s++;
  const start = Math.max(a / fps, Math.min((s - 1) / fps, t - 0.3));
  return { t, start };
});

fs.writeFileSync(out, JSON.stringify({ duration, slides }, null, 1));
console.log(`${slides.length} 張投影片`);
