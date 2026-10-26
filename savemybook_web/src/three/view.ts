import * as THREE from 'three';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';
import { Cabinet } from './cabinet';

export function webglOK() {
  try {
    const c = document.createElement('canvas');
    return !!(c.getContext('webgl2') || c.getContext('webgl'));
  } catch { return false; }
}

function shadowTexture(): THREE.CanvasTexture {
  const c = document.createElement('canvas');
  c.width = c.height = 256;
  const g = c.getContext('2d')!;
  const grad = g.createRadialGradient(128, 128, 8, 128, 128, 128);
  grad.addColorStop(0, 'rgba(21,30,39,0.34)');
  grad.addColorStop(0.42, 'rgba(21,30,39,0.2)');
  grad.addColorStop(0.72, 'rgba(21,30,39,0.06)');
  grad.addColorStop(1, 'rgba(21,30,39,0)');
  g.fillStyle = grad;
  g.fillRect(0, 0, 256, 256);
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

export interface ViewOptions { fov?: number; dprMax?: number }

export class CabinetView {
  readonly renderer: THREE.WebGLRenderer;
  readonly scene = new THREE.Scene();
  readonly camera: THREE.PerspectiveCamera;
  readonly cabinet = new Cabinet();
  readonly rig = new THREE.Group();
  readonly canvas = document.createElement('canvas');
  w = 1;
  h = 1;
  visible = false;
  dirty = true;
  cx = 0.5;
  cy = 0.5;
  fill = 0.7;
  yaw = 0.4;
  pitch = 0.1;
  private dprMax: number;
  private screen: THREE.Mesh | null = null;
  private kioskVersion = -1;

  constructor(readonly host: HTMLElement, opts: ViewOptions = {}) {
    this.dprMax = opts.dprMax ?? 2;
    this.canvas.className = 'gl__canvas';
    this.canvas.setAttribute('aria-hidden', 'true');
    host.prepend(this.canvas);
    this.renderer = new THREE.WebGLRenderer({ canvas: this.canvas, antialias: true, alpha: true, powerPreference: 'high-performance' });
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.NeutralToneMapping;
    this.renderer.toneMappingExposure = 1.05;
    this.renderer.setClearColor(0x000000, 0);
    this.camera = new THREE.PerspectiveCamera(opts.fov ?? 22, 1, 4, 400);

    const pmrem = new THREE.PMREMGenerator(this.renderer);
    this.scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.035).texture;
    this.scene.environmentIntensity = 0.85;
    pmrem.dispose();
    const key = new THREE.DirectionalLight(0xffffff, 1.6);
    key.position.set(-18, 26, 34);
    const fill = new THREE.DirectionalLight(0xdfe8ee, 0.55);
    fill.position.set(22, -8, 18);
    this.scene.add(key, fill, new THREE.AmbientLight(0xffffff, 0.25));

    const shadow = new THREE.Mesh(new THREE.PlaneGeometry(15, 15), new THREE.MeshBasicMaterial({ map: shadowTexture(), transparent: true, depthWrite: false, toneMapped: false }));
    shadow.rotation.x = -Math.PI / 2;
    shadow.position.set(0.5, -Cabinet.HEIGHT / 2 + 0.005, -0.4);
    this.rig.add(this.cabinet.group, shadow);
    this.scene.add(this.rig);

    this.cabinet.group.traverse((o) => {
      const m = o as THREE.Mesh;
      if (m.isMesh && (m.material as THREE.MeshBasicMaterial).map === this.cabinet.kiosk.texture) this.screen = m;
    });

    new IntersectionObserver(([e]) => { this.visible = e.isIntersecting; if (this.visible) this.dirty = true; }, { rootMargin: '120px 0px' }).observe(host);
    new ResizeObserver(() => this.resize()).observe(host);
    this.resize();
  }

  resize() {
    const w = Math.max(1, this.host.clientWidth), h = Math.max(1, this.host.clientHeight);
    if (w === this.w && h === this.h && this.renderer.getPixelRatio() === Math.min(devicePixelRatio || 1, this.dprMax)) return;
    this.w = w;
    this.h = h;
    this.renderer.setPixelRatio(Math.min(devicePixelRatio || 1, this.dprMax));
    this.renderer.setSize(w, h, false);
    this.pose();
  }

  pose() {
    const fov = THREE.MathUtils.degToRad(this.camera.fov);
    const d = (Cabinet.HEIGHT / 2) / Math.tan(fov / 2) / this.fill;
    this.camera.aspect = this.w / this.h;
    this.camera.position.set(0, d * Math.sin(this.pitch), d * Math.cos(this.pitch));
    this.camera.lookAt(0, 0, 0);
    this.camera.setViewOffset(this.w, this.h, this.w * (0.5 - this.cx), this.h * (0.5 - this.cy), this.w, this.h);
    this.camera.updateProjectionMatrix();
    this.rig.rotation.y = this.yaw;
    this.rig.updateMatrixWorld(true);
    this.dirty = true;
  }

  static box(x0: number, x1: number, y0: number, y1: number, z0: number, z1: number) {
    const out: THREE.Vector3[] = [];
    for (const x of [x0, x1]) for (const y of [y0, y1]) for (const z of [z0, z1]) out.push(new THREE.Vector3(x, y, z));
    return out;
  }

  bounds(points: THREE.Vector3[]) {
    const b = { x0: Infinity, x1: -Infinity, y0: Infinity, y1: -Infinity };
    const q = { x: 0, y: 0 };
    for (const p of points) {
      this.project(p, q);
      b.x0 = Math.min(b.x0, q.x); b.x1 = Math.max(b.x1, q.x);
      b.y0 = Math.min(b.y0, q.y); b.y1 = Math.max(b.y1, q.y);
    }
    return b;
  }

  fit(points: THREE.Vector3[], m: { l: number; r: number; t: number; b: number }, maxFill = 0.95, alignY: 'center' | 'top' = 'center') {
    this.cx = 0.5;
    this.cy = 0.5;
    this.fill = 0.6;
    this.pose();
    const aw = Math.max(40, this.w - m.l - m.r), ah = Math.max(40, this.h - m.t - m.b);
    for (let k = 0; k < 3; k++) {
      const b = this.bounds(points);
      this.fill = Math.min(maxFill, this.fill * Math.min(aw / (b.x1 - b.x0), ah / (b.y1 - b.y0)));
      this.pose();
      const c = this.bounds(points);
      this.cx += (m.l + aw / 2 - (c.x0 + c.x1) / 2) / this.w;
      this.cy += (alignY === 'top' ? m.t - c.y0 : m.t + ah / 2 - (c.y0 + c.y1) / 2) / this.h;
      this.pose();
    }
  }

  render() {
    const ver = this.cabinet.kiosk.texture.version;
    if (ver !== this.kioskVersion) {
      this.kioskVersion = ver;
      this.dirty = true;
    }
    if (!this.visible || !this.dirty) return;
    this.dirty = false;
    this.renderer.render(this.scene, this.camera);
  }

  project(local: THREE.Vector3, out = { x: 0, y: 0 }) {
    const v = this.cabinet.group.localToWorld(local.clone()).project(this.camera);
    out.x = (v.x + 1) / 2 * this.w;
    out.y = (1 - v.y) / 2 * this.h;
    return out;
  }

  screenCorners() {
    if (!this.screen) return null;
    const g = this.screen.geometry as THREE.PlaneGeometry;
    const { width, height } = g.parameters;
    const p = this.screen.position;
    return [[-1, 1], [1, 1], [1, -1], [-1, -1]].map(([sx, sy]) => this.project(new THREE.Vector3(p.x + sx * width / 2, p.y + sy * height / 2, p.z)));
  }

}
