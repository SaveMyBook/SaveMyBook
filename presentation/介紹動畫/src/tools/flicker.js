'use strict';

// 逐幀檢查輸出影片：解碼每一格的縮圖，找出與前後格落差異常的畫面（閃爍、跳格、物件突然出現或消失）。
const { spawn } = require('child_process');
const ffmpeg = require('ffmpeg-static');

const [video, fpsArg = '60'] = process.argv.slice(2);
const FPS = Number(fpsArg);
const W = 192;
const H = 108;
const N = W * H;

const p = spawn(ffmpeg, ['-i', video, '-vf', `scale=${W}:${H},format=gray`, '-f', 'rawvideo', '-'], { stdio: ['ignore', 'pipe', 'ignore'] });
const frames = [];
let buf = Buffer.alloc(0);
p.stdout.on('data', (d) => {
  buf = Buffer.concat([buf, d]);
  while (buf.length >= N) {
    frames.push(Buffer.from(buf.subarray(0, N)));
    buf = buf.subarray(N);
  }
});
p.on('close', () => {
  const diff = (a, b) => {
    let s = 0;
    for (let i = 0; i < N; i++) s += Math.abs(a[i] - b[i]);
    return s / N;
  };
  const d = frames.map((f, i) => (i ? diff(f, frames[i - 1]) : 0));
  const blips = [];
  for (let i = 1; i < frames.length - 1; i++) {
    const skip = diff(frames[i + 1], frames[i - 1]);
    if (d[i] > 1.5 && d[i + 1] > 1.5 && skip < Math.min(d[i], d[i + 1]) * 0.35) blips.push({ frame: i, t: +(i / FPS).toFixed(3), in: +d[i].toFixed(2), out: +d[i + 1].toFixed(2), skip: +skip.toFixed(2) });
  }
  const jumps = d
    .map((v, i) => ({ frame: i, t: +(i / FPS).toFixed(3), d: +v.toFixed(2) }))
    .filter((x, i) => {
      if (i < 3) return false;
      const around = [d[i - 3], d[i - 2], d[i + 2] || 0, d[i + 3] || 0].sort((a, b) => a - b);
      const base = (around[1] + around[2]) / 2;
      return x.d > 2.5 && x.d > base * 4;
    });
  console.log(JSON.stringify({ frames: frames.length, seconds: frames.length / FPS, blips, jumps }, null, 1));
});
