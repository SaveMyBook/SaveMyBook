import * as THREE from 'three';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';

/** 畫面固定為 1920×1080 的邏輯尺寸；輸出 4K 時以 pixelRatio 2 算圖。 */
export const W = 1920;
export const H = 1080;
export const FOV = 26;
export const CAM_Z = 62;

export class Stage {
  readonly renderer: THREE.WebGLRenderer;
  readonly scene = new THREE.Scene();
  readonly camera = new THREE.PerspectiveCamera(FOV, W / H, 4, 400);

  constructor(canvas: HTMLCanvasElement, pixelRatio: number) {
    this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true, preserveDrawingBuffer: true });
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.NeutralToneMapping;
    this.renderer.toneMappingExposure = 1.05;
    this.renderer.setClearColor(0x000000, 0);
    this.renderer.setPixelRatio(pixelRatio);
    this.renderer.setSize(W, H, false);

    const pmrem = new THREE.PMREMGenerator(this.renderer);
    this.scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.035).texture;
    this.scene.environmentIntensity = 0.85;
    pmrem.dispose();

    const key = new THREE.DirectionalLight(0xffffff, 1.6);
    key.position.set(-18, 26, 34);
    const fill = new THREE.DirectionalLight(0xdfe8ee, 0.55);
    fill.position.set(22, -8, 18);
    this.scene.add(key, fill, new THREE.AmbientLight(0xffffff, 0.25));
    this.camera.position.set(0, 0, CAM_Z);
    // 遠處物件淡入背景色，畫面主體以外保持安靜
    this.scene.fog = new THREE.Fog(0xf2f5f7, 80, 175);
  }

  /** z=0 平面上可見的半高與半寬（世界單位）。 */
  get halfH() { return Math.tan(THREE.MathUtils.degToRad(FOV / 2)) * CAM_Z; }
  get halfW() { return this.halfH * W / H; }

  render() { this.renderer.render(this.scene, this.camera); }

  /** 世界座標 → 畫面像素座標（1920×1080）。 */
  toScreen(v: THREE.Vector3, out = new THREE.Vector2()) {
    const p = v.clone().project(this.camera);
    return out.set((p.x + 1) / 2 * W, (1 - p.y) / 2 * H);
  }
}
