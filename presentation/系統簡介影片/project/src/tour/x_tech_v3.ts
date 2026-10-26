import * as THREE from 'three';
import { createPcb, pcbData, PCB_SCALE } from '../deck/pcb';
import type { World } from '../world';
import { toCamera, type CamKey } from '../v3/camera';

/**
 * 書櫃透視時抬出的 ESP32-S3 開發板（v3）：取自主控板模型（src/deck/pcb.ts）插在排母上的 ESP32-S3-DevKitC-1，單獨拿出來。
 * 掛在書櫃群組下，由主控板上開發板的位置（cabinet.ts 的 board 錨點）抬出到指定的畫面位置（取景方式同 v3/frame.ts 的 fit），
 * 完全抬出時元件面轉向鏡頭（turn 小於 1 時保留一點角度）。
 * 不經過 world.frame：可見與否綁定在本段寫入的那一格 frame 上，本段沒有執行的格（其他段落、跳轉播放）一律隱藏。
 */
export interface BoardLift {
  /** 完全抬出時開發板中心在畫面上的位置（1920×1080 像素）與離鏡頭的距離（沿視線，世界單位） */
  x: number;
  y: number;
  depth: number;
  /** 完全抬出時長邊在畫面上的長度（像素，未計轉角） */
  len: number;
  /** 轉向鏡頭的程度（0～1） */
  turn?: number;
  /** 抬出途中往上拱的高度（書櫃本體座標） */
  arc?: number;
}

export class DevBoardV3 {
  readonly wrap = new THREE.Group();
  /** 開發板本體半尺寸（wrap 本體座標、未放大時），給 LabelV3 取外框。 */
  readonly half: [number, number, number];
  private frame: object | null = null;
  private show = false;
  /** 主控板上的姿態：模型長邊沿 x、USB 朝 +x；轉 -90° 後與主控板上一樣長邊朝前、USB 朝前 */
  private q0 = new THREE.Quaternion().setFromEuler(new THREE.Euler(0, -Math.PI / 2, 0));
  private qW = new THREE.Quaternion();
  private qCab = new THREE.Quaternion();
  private m = new THREE.Matrix4();

  constructor(private world: World) {
    const root = createPcb({ esp32: true, scale: 1 });
    const data = pcbData(root);
    const dev = data.devkit;
    dev.removeFromParent();
    dev.position.set(0, 0, 0);
    dev.visible = true;
    // 開發板模型的原點在排針塑膠座底面：先置中，再縮成書櫃單位（4 公分）
    const box = new THREE.Box3().setFromObject(dev);
    const c = box.getCenter(new THREE.Vector3());
    const size = box.getSize(new THREE.Vector3()).multiplyScalar(PCB_SCALE.cabinet / 2);
    this.half = [size.x, size.y, size.z];
    dev.position.sub(c);
    const inner = new THREE.Group();
    inner.scale.setScalar(PCB_SCALE.cabinet);
    inner.add(dev);
    this.wrap.add(inner);
    Object.defineProperty(this.wrap, 'visible', {
      get: () => this.show && this.frame === this.world.frame,
      set: () => {},
    });
    world.cabinet.group.add(this.wrap);
    // 絲印字型載入後才重畫板面貼圖，算圖前要等它完成
    world.later.push(() => data.ready);
  }

  /** k：0 在主控板上，1 完全抬出（lift() 的結果）；本段每格呼叫，k ≤ 0 時隱藏。 */
  at(k: number, cam: CamKey, o: BoardLift) {
    this.frame = this.world.frame;
    this.show = k > 0.001;
    if (!this.show) return;
    const e = Math.max(0, k);
    const cab = this.world.cabinet.group;
    cab.updateMatrixWorld(true);
    // 錨點在開發板前端（cabinet.ts 的 part 把錨點放在 z + 深度 / 2），開發板長 66 公釐
    const a = this.world.cabinet.anchors.board.position;
    const from = new THREE.Vector3(a.x, a.y, a.z - 66 / 40 / 2);
    const P = cab.localToWorld(from.clone());
    const eye = new THREE.Vector3(...cam.pos);
    const camera = toCamera(cam);
    const fwd = new THREE.Vector3(...cam.look).sub(eye).normalize();
    const right = new THREE.Vector3().crossVectors(fwd, new THREE.Vector3(0, 1, 0)).normalize();
    const ray = new THREE.Vector3(o.x / 960 - 1, 1 - o.y / 540, 0.5).unproject(camera).sub(eye).normalize();
    const target = eye.clone().addScaledVector(ray, o.depth / ray.dot(fwd));
    const n = eye.clone().sub(target).normalize();
    const to = cab.worldToLocal(target.clone());
    // 放大倍率由畫面上的長度反推：開發板長邊（本體 x）× 書櫃縮放 × 每單位像素
    const perPx = (2 * o.depth * Math.tan(THREE.MathUtils.degToRad((cam.fov ?? 26) / 2))) / 1080;
    const scale = (o.len * perPx) / (2 * this.half[0] * (cab.scale.x || 1));
    // 完全抬出時：元件面（模型 +y）朝鏡頭、長邊（模型 +x）沿畫面水平
    const bx = right.clone().addScaledVector(n, -right.dot(n)).normalize();
    const bz = new THREE.Vector3().crossVectors(bx, n).normalize();
    this.m.makeBasis(bx, n, bz);
    this.qW.setFromRotationMatrix(this.m);
    cab.getWorldQuaternion(this.qCab);
    const qL = this.qCab.invert().multiply(this.qW);
    this.wrap.position.lerpVectors(from, to, e);
    this.wrap.position.y += Math.sin(Math.PI * Math.min(1, e)) * (o.arc ?? 0);
    this.wrap.quaternion.copy(this.q0).slerp(qL, Math.min(1, e) * (o.turn ?? 0.85));
    this.wrap.scale.setScalar(1 + (scale - 1) * e);
  }
}
