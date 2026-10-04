export type Pose = Record<string, number>;
export type Frame = [number, Pose];

export const clamp = (v: number, a = 0, b = 1) => Math.min(b, Math.max(a, v));
export const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
export const smooth = (t: number) => t * t * (3 - 2 * t);
export const easeOut = (t: number) => 1 - Math.pow(1 - t, 3);
export const easeInOut = (t: number) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);

/** 區段內進度：p 在 [a, b] 之間時 0→1，之外夾住。 */
export const span = (p: number, a: number, b: number) => clamp((p - a) / (b - a));

/**
 * 單調三次插值：通過中間影格時速度連續、不會停頓；相鄰影格數值相同（停留）或方向反轉處速度為零，不會衝過頭。
 * 頭尾兩端速度為零（平滑起步與停止）。
 */
export function monotone(ts: number[], vs: number[], p: number): number {
  const n = ts.length;
  if (p <= ts[0]) return vs[0];
  if (p >= ts[n - 1]) return vs[n - 1];
  let i = 0;
  while (p > ts[i + 1]) i++;
  const slope = (k: number) => (vs[k + 1] - vs[k]) / Math.max(1e-6, ts[k + 1] - ts[k]);
  const tangent = (k: number) => {
    if (k === 0 || k === n - 1) return 0;
    const a = slope(k - 1), b = slope(k);
    if (a * b <= 0) return 0;
    const h0 = ts[k] - ts[k - 1], h1 = ts[k + 1] - ts[k];
    const w1 = 2 * h1 + h0, w2 = h1 + 2 * h0;
    return (w1 + w2) / (w1 / a + w2 / b);
  };
  const h = ts[i + 1] - ts[i], s = (p - ts[i]) / h;
  const m0 = tangent(i), m1 = tangent(i + 1);
  // 兩端都停住的一段（停留→移動→停留）維持原本的緩動曲線
  if (m0 === 0 && m1 === 0) return vs[i] + (vs[i + 1] - vs[i]) * easeInOut(s);
  const s2 = s * s, s3 = s2 * s;
  return (2 * s3 - 3 * s2 + 1) * vs[i] + (s3 - 2 * s2 + s) * h * m0 + (-2 * s3 + 3 * s2) * vs[i + 1] + (s3 - s2) * h * m1;
}

/**
 * 依進度在關鍵影格之間平滑插值；未在某影格出現的屬性沿用前一影格的值。
 * 未指定緩動且有三個以上影格時，以單調三次插值讓中間影格速度連續。
 */
export function keyframes(p: number, frames: Frame[], ease?: (t: number) => number): Pose {
  const filled: Frame[] = [];
  let carry: Pose = {};
  for (const [t, pose] of frames) {
    carry = { ...carry, ...pose };
    filled.push([t, carry]);
  }
  if (p <= filled[0][0]) return { ...filled[0][1] };
  const last = filled[filled.length - 1];
  if (p >= last[0]) return { ...last[1] };
  if (!ease && filled.length > 2) {
    const ts = filled.map((f) => f[0]);
    const out: Pose = {};
    for (const key of Object.keys(last[1])) out[key] = monotone(ts, filled.map((f) => f[1][key] ?? last[1][key]), p);
    return out;
  }
  ease ??= easeInOut;
  for (let i = 0; i < filled.length - 1; i++) {
    const [t0, a] = filled[i];
    const [t1, b] = filled[i + 1];
    if (p >= t0 && p <= t1) {
      const k = ease(t1 === t0 ? 1 : (p - t0) / (t1 - t0));
      const out: Pose = {};
      for (const key of Object.keys(b)) out[key] = lerp(a[key] ?? b[key], b[key], k);
      return out;
    }
  }
  return { ...last[1] };
}

/** 以臨界值決定目前段落。 */
export function beatAt(p: number, cuts: number[]): number {
  let i = 0;
  while (i < cuts.length && p >= cuts[i]) i++;
  return i;
}
