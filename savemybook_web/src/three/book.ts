import * as THREE from 'three';
import { paperTexture } from './textures';

const N = 40;
const PW = 8.6;
const PH = 11.6;

/** 靜止頁面的剖面斜率：靠書脊處隆起、外緣略垂。 */
function restSlope(s: number) {
  return 0.82 * Math.pow(1 - s, 1.7) - 0.06 * s * s;
}

class Leaf {
  readonly mesh: THREE.Mesh<THREE.PlaneGeometry, THREE.MeshStandardMaterial>;
  readonly edge: THREE.Line<THREE.BufferGeometry, THREE.LineBasicMaterial>;
  private last = NaN;
  constructor(mat: THREE.MeshStandardMaterial, edgeMat: THREE.LineBasicMaterial, readonly width: number, readonly lift: number) {
    const geo = new THREE.PlaneGeometry(1, PH, N, 1);
    // 書溝陰影：靠書脊處較暗，外緣微暗
    const colors = new Float32Array((N + 1) * 2 * 3);
    for (let row = 0; row < 2; row++) {
      for (let i = 0; i <= N; i++) {
        const s = i / N;
        const gutter = 0.7 + 0.3 * Math.min(1, Math.pow(s / 0.22, 0.8));
        const edge = 1 - 0.06 * Math.pow(s, 3);
        const v = gutter * edge;
        colors.set([v, v, v], (row * (N + 1) + i) * 3);
      }
    }
    geo.setAttribute('color', new THREE.BufferAttribute(colors, 3));
    this.mesh = new THREE.Mesh(geo, mat);
    const pts = new Float32Array((N + 1) * 3);
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(pts, 3));
    this.edge = new THREE.Line(g, edgeMat);
  }

  /** f：0 在右側，1 翻到左側。 */
  set(f: number, curl: number) {
    const key = f * 1000 + curl;
    if (key === this.last) return;
    this.last = key;
    const pos = this.mesh.geometry.attributes.position as THREE.BufferAttribute;
    const edge = this.edge.geometry.attributes.position as THREE.BufferAttribute;
    const ds = this.width / N;
    let x = 0, z = this.lift;
    const xs: number[] = [x], zs: number[] = [z];
    for (let i = 0; i < N; i++) {
      const s = (i + 0.5) / N;
      const base = restSlope(s);
      const phi = (1 - f) * base + f * (Math.PI - base) - curl * Math.sin(Math.PI * f) * Math.pow(s, 1.3);
      x += Math.cos(phi) * ds;
      z += Math.sin(phi) * ds;
      xs.push(x);
      zs.push(z);
    }
    // PlaneGeometry 頂點順序：上排 0..N、下排 N+1..2N+1
    for (let i = 0; i <= N; i++) {
      pos.setXYZ(i, xs[i], PH / 2, zs[i]);
      pos.setXYZ(i + N + 1, xs[i], -PH / 2, zs[i]);
      edge.setXYZ(i, xs[i], PH / 2 + 0.001, zs[i]);
    }
    pos.needsUpdate = true;
    edge.needsUpdate = true;
    this.mesh.geometry.computeVertexNormals();
    this.mesh.geometry.computeBoundingSphere();
  }
}

export class Book {
  readonly group = new THREE.Group();
  private right: Leaf[] = [];
  private left: Leaf[] = [];
  private flips: Leaf[] = [];
  private ribbon: THREE.Mesh;

  constructor() {
    const paper = new THREE.MeshStandardMaterial({ color: 0xedf1f4, roughness: 0.9, metalness: 0, side: THREE.DoubleSide, map: paperTexture(), envMapIntensity: 0.28, vertexColors: true });
    const shade = new THREE.MeshStandardMaterial({ color: 0xc9d3da, roughness: 0.95, side: THREE.DoubleSide, envMapIntensity: 0.2, vertexColors: true });
    const edgeMat = new THREE.LineBasicMaterial({ color: 0xaab8c2, transparent: true, opacity: 0.9 });
    // 兩側書頁堆疊：最上層之外，下方幾層只露出邊緣，形成厚度
    for (let i = 0; i < 6; i++) {
      const w = PW - i * 0.05;
      const r = new Leaf(i === 0 ? paper : shade, edgeMat, w, -i * 0.06);
      const l = new Leaf(i === 0 ? paper : shade, edgeMat, w, -i * 0.06);
      this.right.push(r);
      this.left.push(l);
      this.group.add(r.mesh, l.mesh);
      if (i === 0) this.group.add(r.edge, l.edge);
    }
    // 會翻動的頁
    for (let i = 0; i < 4; i++) {
      const leaf = new Leaf(paper, edgeMat, PW - 0.02, 0.01 + i * 0.012);
      this.flips.push(leaf);
      this.group.add(leaf.mesh, leaf.edge);
    }
    const ribbon = new THREE.Mesh(
      new THREE.PlaneGeometry(0.42, 3.4),
      new THREE.MeshStandardMaterial({ color: 0x627d8d, roughness: 0.6, side: THREE.DoubleSide }),
    );
    ribbon.position.set(PW * 0.62, -PH / 2 - 1.2, 0.3);
    const shadowCanvas = document.createElement('canvas');
    shadowCanvas.width = shadowCanvas.height = 128;
    const sg = shadowCanvas.getContext('2d')!;
    const grad = sg.createRadialGradient(64, 64, 4, 64, 64, 64);
    grad.addColorStop(0, 'rgba(20,32,40,.55)');
    grad.addColorStop(1, 'rgba(20,32,40,0)');
    sg.fillStyle = grad;
    sg.fillRect(0, 0, 128, 128);
    const shadow = new THREE.Mesh(new THREE.PlaneGeometry(PW * 2.6, PH * 1.5), new THREE.MeshBasicMaterial({ map: new THREE.CanvasTexture(shadowCanvas), transparent: true, depthWrite: false, opacity: 0.55 }));
    shadow.position.set(0, -0.2, -0.9);
    this.group.add(shadow);
    ribbon.rotation.z = 0.18;
    this.ribbon = ribbon;
    this.group.add(ribbon);
    this.set(0, 0);
  }

  /** open：0 闔上、1 攤開；turn：0–1 依序翻過的頁數比例。 */
  set(open: number, turn: number) {
    const fan = [0.012, 0.026, 0.04, 0.054];
    this.right.forEach((leaf, i) => leaf.set(Math.max(0, 0.002 * i), 0));
    this.left.forEach((leaf, i) => {
      const target = 1 - 0.002 * i;
      leaf.set(target * Math.min(1, open * 1.1 - i * 0.02), 1.1 * (1 - open));
    });
    const n = this.flips.length;
    this.flips.forEach((leaf, i) => {
      const restR = fan[i % fan.length];
      const restL = 1 - fan[(n - 1 - i) % fan.length];
      const k = Math.min(1, Math.max(0, turn * n - (n - 1 - i)));
      const opened = restR * open;
      const f = opened + (restL - opened) * k;
      leaf.set(f, 1.5 * Math.sin(Math.PI * k) + 0.4 * (1 - open));
    });
    this.ribbon.visible = open > 0.6;
  }
}
