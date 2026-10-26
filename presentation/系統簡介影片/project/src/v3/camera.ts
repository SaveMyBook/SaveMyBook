import * as THREE from 'three';
import { span, type Pose } from '../lib/kf';
import { glide } from '../tour/kit4';
import { V3 } from './spec';

/**
 * 3D 鏡頭：位置、注視點（世界座標）、視角（度）與滾轉（弧度）。場景每格把結果寫入 world.frame.camera。
 * 換鏡頭一律移動鏡頭：同一個鏡位內用 CameraPath 平滑移動；鏡位之間用 whip（原地甩向下一個主體）或 move（平移或推移到下一個主體）。
 * 背景不畫同心圓或漣漪，轉場只靠鏡頭本身的移動與輸出時的動態模糊。
 */
export interface CamKey { pos: [number, number, number]; look: [number, number, number]; fov?: number; roll?: number }

type V = [number, number, number];

/** 以 glide（高斯卷積的直線路徑，無限次可微）平滑鏡頭的位置、注視點與視角。 */
export class CameraPath {
  private pos: [number, Pose][];
  private look: [number, Pose][];
  private lens: [number, Pose][];
  constructor(readonly keys: [number, CamKey][], readonly sigma = 0.42) {
    this.pos = keys.map(([t, k]) => [t, { x: k.pos[0], y: k.pos[1], z: k.pos[2] }]);
    this.look = keys.map(([t, k]) => [t, { x: k.look[0], y: k.look[1], z: k.look[2] }]);
    this.lens = keys.map(([t, k]) => [t, { s: k.fov ?? 26, rz: k.roll ?? 0 }]);
  }
  at(t: number): CamKey {
    const p = glide(t, this.pos, this.sigma), l = glide(t, this.look, this.sigma), f = glide(t, this.lens, this.sigma);
    return { pos: [p.x, p.y, p.z], look: [l.x, l.y, l.z], fov: f.s, roll: f.rz };
  }
}

/** 以 center 為中心的環繞鏡位：yaw 為水平方位（0 在 +z 方向）、pitch 為仰角（正值由上往下看）、dist 為距離。 */
export function orbit(center: V, yaw: number, pitch: number, dist: number, look: V = [0, 0, 0], fov = 26, roll = 0): CamKey {
  const [cx, cy, cz] = center;
  return {
    pos: [cx + dist * Math.sin(yaw) * Math.cos(pitch), cy + dist * Math.sin(pitch), cz + dist * Math.cos(yaw) * Math.cos(pitch)],
    look: [cx + look[0], cy + look[1], cz + look[2]],
    fov,
    roll,
  };
}

/** 五次平滑（smootherstep）：中段最快，兩端與中段的加速度都連續；inOutCubic 在中點加速度會跳變。 */
const inOutCubic = (x: number) => x * x * x * (x * (x * 6 - 15) + 10);
const lerp3 = (a: V, b: V, e: number): V => [a[0] + (b[0] - a[0]) * e, a[1] + (b[1] - a[1]) * e, a[2] + (b[2] - a[2]) * e];

/** 甩鏡：鏡頭位置漸移、視線方向球面插值，中段最快（輸出時由 180° 快門的動態模糊做成方向性模糊）。 */
export function whip(a: CamKey, b: CamKey, q: number): CamKey {
  const e = inOutCubic(Math.min(1, Math.max(0, q)));
  const pos = lerp3(a.pos, b.pos, e);
  const da = new THREE.Vector3(...a.look).sub(new THREE.Vector3(...a.pos)).normalize();
  const db = new THREE.Vector3(...b.look).sub(new THREE.Vector3(...b.pos)).normalize();
  const dir = da.clone().applyQuaternion(new THREE.Quaternion().slerp(new THREE.Quaternion().setFromUnitVectors(da, db), e));
  // 不加滾轉：滾轉會讓畫面邊緣的手機在甩鏡途中往下掉進字幕帶
  return { pos, look: [pos[0] + dir.x * 50, pos[1] + dir.y * 50, pos[2] + dir.z * 50], fov: 26, roll: 0 };
}

/** 平移／推移：鏡頭與注視點一起移到下一個主體（物件都不經過上方的標題時用橫移；距離不同時同時推近或拉遠）。 */
export function move(a: CamKey, b: CamKey, q: number): CamKey {
  const e = inOutCubic(Math.min(1, Math.max(0, q)));
  return { pos: lerp3(a.pos, b.pos, e), look: lerp3(a.look, b.look, e), fov: (a.fov ?? 26) + ((b.fov ?? 26) - (a.fov ?? 26)) * e, roll: 0 };
}

/** 鏡頭時間表：依序的鏡位，鏡位之間的轉場種類與起點。 */
export interface Cut { at: number; kind: 'whip' | 'move'; dur?: number }
export function sequence(t: number, shots: CameraPath[], cuts: Cut[]): CamKey {
  for (let i = 0; i < cuts.length; i++) {
    const c = cuts[i], d = c.dur ?? (c.kind === 'whip' ? V3.trans.whip : V3.trans.move);
    if (t < c.at) return shots[i].at(t);
    if (t < c.at + d) {
      const q = span(t, c.at, c.at + d);
      return c.kind === 'whip' ? whip(shots[i].at(c.at), shots[i + 1].at(c.at + d), q) : move(shots[i].at(t), shots[i + 1].at(t), q);
    }
  }
  return shots[shots.length - 1].at(t);
}

/** CamKey 換成 three 的鏡頭（取景工具、版面檢查用）。 */
export function toCamera(k: CamKey) {
  const cam = new THREE.PerspectiveCamera(k.fov ?? 26, 1920 / 1080, 4, 400);
  cam.position.set(...k.pos);
  cam.lookAt(...k.look);
  if (k.roll) cam.rotateZ(k.roll);
  cam.updateMatrixWorld(true);
  return cam;
}

/**
 * 段落交界的鏡頭橫移：全片一律「鏡頭向左移、畫面內容往右移」。
 * 段落開始的 inDur 秒，鏡頭由右側 dist 處移回定位（主體由畫面左側移入）；最後 outDur 秒，鏡頭再往左移 dist（主體由右側出畫）。
 * 離場加速、進場減速，交界那一格移動最快，上一段剛出畫、下一段就進場，看起來是同一個橫移（不畫漣漪）。
 * 移動距離依段落而定（PANS，由 tools/bounds.mjs 量測校正）：剛好讓主體在交界前後一兩格出畫、入畫，畫面不會停在空背景。
 * len 為段落長度（秒）；out 為 false 時不做離場（片尾）、in 為 false 時不做進場（片頭）。
 */
/** 各段進場（in）與離場（out）的橫移距離（世界單位，預設 48）；2026-10-26 依 tools/bounds.mjs 的出畫／入畫時間反推，目標為交界前後各約 0.02 秒。 */
export const PANS: Record<string, { in?: number; out?: number }> = {
  open: { out: 39.0 },
  overview: { in: 49.9, out: 39.5 },
  list: { in: 30.7, out: 37.2 },
  find: { in: 39.5, out: 25.0 },
  pay: { in: 39.5, out: 42.5 },
  cabinet: { in: 30.7, out: 39.5 },
  after: { in: 30.7, out: 46.5 },
  account: { in: 32.8, out: 42.0 },
  admin: { in: 30.7, out: 42.0 },
  tech: { in: 44.5, out: 44.0 },
};

export function sectionPans(k: CamKey, t: number, len: number, o: { sec?: string; inDur?: number; outDur?: number; distIn?: number; distOut?: number; in?: boolean; out?: boolean } = {}): CamKey {
  const pan = (o.sec && PANS[o.sec]) || {};
  const inDur = o.inDur ?? 0.9, outDur = o.outDur ?? 0.9, distIn = o.distIn ?? pan.in ?? 48, distOut = o.distOut ?? pan.out ?? 48;
  const easeOut = (x: number) => 1 - (1 - Math.min(1, Math.max(0, x))) ** 3;
  const easeIn = (x: number) => Math.min(1, Math.max(0, x)) ** 3;
  const a = o.in === false ? 0 : distIn * (1 - easeOut(t / inDur));
  const b = o.out === false ? 0 : -distOut * easeIn((t - (len - outDur)) / outDur);
  const d = a + b;
  if (Math.abs(d) < 1e-6) return k;
  const fwd = new THREE.Vector3(...k.look).sub(new THREE.Vector3(...k.pos)).normalize();
  const right = new THREE.Vector3().crossVectors(fwd, new THREE.Vector3(0, 1, 0)).normalize().multiplyScalar(d);
  return {
    ...k,
    pos: [k.pos[0] + right.x, k.pos[1], k.pos[2] + right.z],
    look: [k.look[0] + right.x, k.look[1], k.look[2] + right.z],
  };
}
