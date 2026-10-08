import * as THREE from 'three';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';
import { FullScreenQuad } from 'three/examples/jsm/postprocessing/Pass.js';

/** 畫面固定為 1920×1080 的邏輯尺寸；輸出 4K 時以 pixelRatio 2 算圖。 */
export const W = 1920;
export const H = 1080;
export const FOV = 26;
export const CAM_Z = 62;

const quadVert = /* glsl */`
  varying vec2 vUv;
  void main() { vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }
`;

export class Stage {
  readonly renderer: THREE.WebGLRenderer;
  readonly scene = new THREE.Scene();
  readonly camera = new THREE.PerspectiveCamera(FOV, W / H, 4, 400);
  private blurState?: { frame: THREE.FramebufferTexture; sum: THREE.WebGLRenderTarget; add: FullScreenQuad; copy: FullScreenQuad; w: number; h: number };

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
    // 背光：從後上方打亮機身金屬邊緣，物件輪廓與背景分開
    const rim = new THREE.DirectionalLight(0xf4f8ff, 1.35);
    rim.position.set(14, 22, -40);
    const rim2 = new THREE.DirectionalLight(0xdbe7f0, 0.8);
    rim2.position.set(-26, -6, -30);
    this.scene.add(key, fill, rim, rim2, new THREE.AmbientLight(0xffffff, 0.25));
    this.camera.position.set(0, 0, CAM_Z);
    // 遠處物件淡入背景色，畫面主體以外保持安靜
    this.scene.fog = new THREE.Fog(0xf2f5f7, 80, 175);
  }

  /** z=0 平面上可見的半高與半寬（世界單位）。 */
  get halfH() { return Math.tan(THREE.MathUtils.degToRad(FOV / 2)) * CAM_Z; }
  get halfW() { return this.halfH * W / H; }

  render() { this.renderer.render(this.scene, this.camera); }

  /**
   * 動態模糊（只用於輸出成品）：快門時間內取 n 個時間點，各自以一般方式算圖到畫布後複製出來，以浮點緩衝平均。
   * 在畫布上算圖再複製，色調對應與色彩空間和一般算圖完全相同（App 畫面不會因後製而變灰）。
   */
  renderBlurred(n: number, step: (i: number) => void) {
    const r = this.renderer;
    const size = r.getDrawingBufferSize(new THREE.Vector2());
    let b = this.blurState;
    if (!b || b.w !== size.x || b.h !== size.y) {
      b?.frame.dispose();
      b?.sum.dispose();
      const frame = new THREE.FramebufferTexture(size.x, size.y);
      const sum = new THREE.WebGLRenderTarget(size.x, size.y, { type: THREE.HalfFloatType, depthBuffer: false });
      const add = new FullScreenQuad(new THREE.ShaderMaterial({
        uniforms: { map: { value: frame }, weight: { value: 1 } },
        vertexShader: quadVert,
        fragmentShader: 'uniform sampler2D map; uniform float weight; varying vec2 vUv; void main() { gl_FragColor = texture2D(map, vUv) * weight; }',
        blending: THREE.CustomBlending, blendSrc: THREE.OneFactor, blendDst: THREE.OneFactor, blendEquation: THREE.AddEquation,
        depthTest: false, depthWrite: false, transparent: true,
      }));
      const copy = new FullScreenQuad(new THREE.ShaderMaterial({
        uniforms: { map: { value: sum.texture } },
        vertexShader: quadVert,
        fragmentShader: 'uniform sampler2D map; varying vec2 vUv; void main() { gl_FragColor = texture2D(map, vUv); }',
        blending: THREE.NoBlending, depthTest: false, depthWrite: false,
      }));
      b = this.blurState = { frame, sum, add, copy, w: size.x, h: size.y };
    }
    (b.add.material as THREE.ShaderMaterial).uniforms.weight.value = 1 / n;
    // 累加時不可自動清除，否則每次只留下最後一個取樣
    const auto = r.autoClear;
    r.autoClear = false;
    r.setRenderTarget(b.sum);
    r.clear();
    for (let i = 0; i < n; i++) {
      step(i);
      r.setRenderTarget(null);
      r.clear();
      r.render(this.scene, this.camera);
      r.copyFramebufferToTexture(b.frame);
      r.setRenderTarget(b.sum);
      b.add.render(r);
    }
    r.setRenderTarget(null);
    r.clear();
    b.copy.render(r);
    r.autoClear = auto;
  }

  /** 世界座標 → 畫面像素座標（1920×1080）。 */
  toScreen(v: THREE.Vector3, out = new THREE.Vector2()) {
    const p = v.clone().project(this.camera);
    return out.set((p.x + 1) / 2 * W, (1 - p.y) / 2 * H);
  }
}
