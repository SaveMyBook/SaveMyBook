import * as THREE from 'three';
import type { Pose } from '../lib/kf';
import type { World } from '../world';
import { Cabinet } from '../three/cabinet';
import { PHONE } from '../three/phone';
import { toCamera, type CamKey } from './camera';

/**
 * 取景工具：指定物件在畫面上的位置與高度（1920×1080 像素），反推世界座標的位置與縮放。
 * 以「先決定構圖、再擺物件」的方式工作：手機、書櫃的大小與位置都由這裡算，場景不要手調世界座標。
 */
export type Kind = 'phone' | 'cabinet';
const DIMS: Record<Kind, [number, number, number]> = {
  phone: [PHONE.W, PHONE.H, PHONE.D + 0.5],
  cabinet: [Cabinet.WIDTH, Cabinet.HEIGHT, Cabinet.DEPTH],
};

export interface FitSpec {
  /** 畫面上外框的中心與高度（像素） */
  cx: number;
  cy: number;
  h: number;
  /** 轉角（弧度）：rx 俯仰、rz 滾轉為世界座標；yaw 為相對「正對鏡頭」的水平轉角 */
  rx?: number;
  yaw?: number;
  rz?: number;
  /** 與鏡頭的距離（沿視線，世界單位）；預設為鏡頭到注視點的距離。近則透視強、遠則平 */
  depth?: number;
}

/** 物件八個角點投影後的外框（像素）。 */
export function projectedBox(cam: THREE.Camera, kind: Kind, p: THREE.Vector3, rot: THREE.Euler, s: number) {
  const [w, h, d] = DIMS[kind];
  const xs: number[] = [], ys: number[] = [];
  for (const sx of [-1, 1]) for (const sy of [-1, 1]) for (const sz of [-1, 1]) {
    const v = new THREE.Vector3(sx * w / 2, sy * h / 2, sz * d / 2).multiplyScalar(s).applyEuler(rot).add(p).project(cam);
    xs.push((v.x + 1) / 2 * 1920);
    ys.push((1 - v.y) / 2 * 1080);
  }
  return { x0: Math.min(...xs), x1: Math.max(...xs), y0: Math.min(...ys), y1: Math.max(...ys) };
}

/** 反推姿態：回傳 world.place 用的 Pose（x、y 以 z=0 平面的半寬、半高為 1）。 */
export function fit(world: World, key: CamKey, kind: Kind, f: FitSpec): Pose {
  const cam = toCamera(key);
  const eye = new THREE.Vector3(...key.pos);
  const fwd = new THREE.Vector3(...key.look).sub(eye).normalize();
  const right = new THREE.Vector3().crossVectors(fwd, cam.up).normalize();
  const up = new THREE.Vector3().crossVectors(right, fwd).normalize();
  const depth = f.depth ?? new THREE.Vector3(...key.look).distanceTo(eye);
  const perPx = (2 * depth * Math.tan(THREE.MathUtils.degToRad((key.fov ?? 26) / 2))) / 1080;
  const ndc = new THREE.Vector3(f.cx / 960 - 1, 1 - f.cy / 540, 0.5).unproject(cam).sub(eye).normalize();
  const p = eye.clone().add(ndc.multiplyScalar(depth / ndc.dot(fwd)));
  let s = f.h * perPx / DIMS[kind][1];
  const rot = new THREE.Euler();
  for (let i = 0; i < 8; i++) {
    const face = Math.atan2(eye.x - p.x, eye.z - p.z);
    rot.set(f.rx ?? 0, face + (f.yaw ?? 0), f.rz ?? 0);
    const b = projectedBox(cam, kind, p, rot, s);
    s *= f.h / (b.y1 - b.y0);
    p.addScaledVector(right, (f.cx - (b.x0 + b.x1) / 2) * perPx).addScaledVector(up, -(f.cy - (b.y0 + b.y1) / 2) * perPx);
  }
  return { x: p.x / world.stage.halfW, y: p.y / world.stage.halfH, z: p.z, rx: rot.x, ry: rot.y, rz: rot.z, s };
}

/** Pose 換回世界座標（例如把浮出目標或空間中的點放在物件旁邊）。 */
export function worldOf(world: World, pose: Pose) {
  return new THREE.Vector3((pose.x ?? 0) * world.stage.halfW, (pose.y ?? 0) * world.stage.halfH, pose.z ?? 0);
}
