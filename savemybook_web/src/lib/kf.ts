export type Pose = Record<string, number>;
export type Frame = [number, Pose];

export const clamp = (v: number, a = 0, b = 1) => Math.min(b, Math.max(a, v));
export const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
export const smooth = (t: number) => t * t * (3 - 2 * t);
export const easeOut = (t: number) => 1 - Math.pow(1 - t, 3);
export const easeInOut = (t: number) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);

/** 區段內進度：p 在 [a, b] 之間時 0→1，之外夾住。 */
export const span = (p: number, a: number, b: number) => clamp((p - a) / (b - a));

/** 依進度在關鍵影格之間平滑插值；未在某影格出現的屬性沿用前一影格的值。 */
export function keyframes(p: number, frames: Frame[], ease = easeInOut): Pose {
  const filled: Frame[] = [];
  let carry: Pose = {};
  for (const [t, pose] of frames) {
    carry = { ...carry, ...pose };
    filled.push([t, carry]);
  }
  if (p <= filled[0][0]) return { ...filled[0][1] };
  const last = filled[filled.length - 1];
  if (p >= last[0]) return { ...last[1] };
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
