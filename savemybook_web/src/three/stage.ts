import * as THREE from 'three';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';

export const FOV = 26;
export const CAM_Z = 62;

export class Stage {
  readonly renderer: THREE.WebGLRenderer;
  readonly scene = new THREE.Scene();
  readonly camera = new THREE.PerspectiveCamera(FOV, 1, 8, 160);
  readonly key: THREE.DirectionalLight;
  width = 1;
  height = 1;
  narrow = false;
  private tasks: ((t: number, dt: number) => void)[] = [];
  private last = performance.now();

  constructor(canvas: HTMLCanvasElement) {
    this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true, powerPreference: 'high-performance' });
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.NeutralToneMapping;
    this.renderer.toneMappingExposure = 1.05;
    this.renderer.setClearColor(0x000000, 0);

    const pmrem = new THREE.PMREMGenerator(this.renderer);
    this.scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.035).texture;
    this.scene.environmentIntensity = 0.85;
    pmrem.dispose();

    this.key = new THREE.DirectionalLight(0xffffff, 1.6);
    this.key.position.set(-18, 26, 34);
    this.scene.add(this.key);
    const fill = new THREE.DirectionalLight(0xdfe8ee, 0.55);
    fill.position.set(22, -8, 18);
    this.scene.add(fill);
    this.scene.add(new THREE.AmbientLight(0xffffff, 0.25));

    this.camera.position.set(0, 0, CAM_Z);
    this.resize();
    addEventListener('resize', () => this.resize());
    this.renderer.setAnimationLoop((now) => this.frame(now));
  }

  resize() {
    this.width = innerWidth;
    this.height = innerHeight;
    this.narrow = this.width < 820 || this.width / this.height < 0.9;
    const dpr = Math.min(devicePixelRatio || 1, this.narrow ? 1.6 : 2);
    this.renderer.setPixelRatio(dpr);
    this.renderer.setSize(this.width, this.height, false);
    this.camera.aspect = this.width / this.height;
    this.camera.updateProjectionMatrix();
  }

  /** 鏡頭距離 z=0 平面上可見的半高與半寬（世界單位）。 */
  get halfH() { return Math.tan(THREE.MathUtils.degToRad(FOV / 2)) * CAM_Z; }
  get halfW() { return this.halfH * this.camera.aspect; }

  onFrame(fn: (t: number, dt: number) => void) { this.tasks.push(fn); }

  private frame(now: number) {
    const dt = Math.min(0.05, (now - this.last) / 1000);
    this.last = now;
    for (const fn of this.tasks) fn(now / 1000, dt);
    this.renderer.render(this.scene, this.camera);
  }

  /** 世界座標 → 視窗像素座標。 */
  toScreen(v: THREE.Vector3, out = new THREE.Vector2()) {
    const p = v.clone().project(this.camera);
    out.set((p.x + 1) / 2 * this.width, (1 - p.y) / 2 * this.height);
    return out;
  }
}
