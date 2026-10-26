import * as THREE from 'three';
import type { Pose } from '../lib/kf';
import type { World } from '../world';
import { Cabinet } from '../three/cabinet';
import type { KioskPop } from '../three/textures';
import type { CamKey } from './camera';
import { V3 } from './spec';

/**
 * 書櫃螢幕浮出：從螢幕原位朝鏡頭浮起，放大 1.6–2.2 倍，原位留下深灰內凹的空位。
 * 位移以鏡頭為準（世界單位）：toward 沿「螢幕 → 鏡頭」靠近鏡頭、left／up 為畫面上的左與上。
 * 書櫃轉角時，書櫃自己的正面方向會偏向畫面一側，所以不用書櫃本體座標指定方向。
 * turn 為轉向鏡頭的程度（預設 0.8，保留一點書櫃的角度，看得出透視）。
 */
export interface KioskLift { toward: number; left: number; up: number; scale: number; turn?: number }

export function kioskPop(world: World, k: number, cam: CamKey, cab: Pose, o: KioskLift): KioskPop {
  const [lo, hi] = V3.pop.kioskScale;
  if (o.scale < lo || o.scale > hi) console.error(`書櫃螢幕浮出倍率 ${o.scale} 不在 ${lo}–${hi}`);
  const S = Cabinet.SCREEN;
  const s = cab.s ?? 1;
  const rot = new THREE.Euler(cab.rx ?? 0, cab.ry ?? 0, cab.rz ?? 0);
  const P = new THREE.Vector3((cab.x ?? 0) * world.stage.halfW, (cab.y ?? 0) * world.stage.halfH, cab.z ?? 0);
  const screen = new THREE.Vector3(S.x, S.y, S.z).multiplyScalar(s).applyEuler(rot).add(P);
  const eye = new THREE.Vector3(...cam.pos);
  const fwd = new THREE.Vector3(...cam.look).sub(eye).normalize();
  const right = new THREE.Vector3().crossVectors(fwd, new THREE.Vector3(0, 1, 0)).normalize();
  const up = new THREE.Vector3().crossVectors(right, fwd).normalize();
  const target = screen.clone()
    .addScaledVector(eye.clone().sub(screen).normalize(), o.toward)
    .addScaledVector(right, -o.left)
    .addScaledVector(up, o.up);
  const local = target.sub(P).applyQuaternion(new THREE.Quaternion().setFromEuler(rot).invert()).divideScalar(s);
  return { k, dx: local.x - S.x, dy: local.y - S.y, dz: local.z - S.z, s: o.scale, look: cam.pos, slot: true, turn: o.turn ?? 0.8 };
}
