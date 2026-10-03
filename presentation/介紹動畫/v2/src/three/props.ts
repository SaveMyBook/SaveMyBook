import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/examples/jsm/geometries/RoundedBoxGeometry.js';

function canvasTex(c: HTMLCanvasElement) {
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 8;
  return t;
}

/** 寄件包裹：牛皮紙箱、封箱膠帶與託運單。 */
export function parcel() {
  const face = (w: number, h: number, tapeAlong: 'x' | 'y' | 'none', label = false) => {
    const c = document.createElement('canvas');
    c.width = Math.round(w * 100);
    c.height = Math.round(h * 100);
    const g = c.getContext('2d')!;
    g.fillStyle = '#C9A97B';
    g.fillRect(0, 0, c.width, c.height);
    g.fillStyle = 'rgba(120,86,46,.08)';
    for (let i = 0; i < 40; i++) g.fillRect(0, (i * 37) % c.height, c.width, 2);
    g.fillStyle = 'rgba(232,222,200,.85)';
    if (tapeAlong === 'x') g.fillRect(0, c.height / 2 - 34, c.width, 68);
    if (tapeAlong === 'y') g.fillRect(c.width / 2 - 34, 0, 68, c.height);
    if (label) {
      g.fillStyle = '#FFFFFF';
      g.fillRect(c.width * 0.08, c.height * 0.56, c.width * 0.42, c.height * 0.32);
      g.fillStyle = '#16222B';
      for (let i = 0; i < 4; i++) g.fillRect(c.width * 0.11, c.height * (0.61 + i * 0.065), c.width * (0.3 - (i % 2) * 0.08), 6);
    }
    return new THREE.MeshStandardMaterial({ map: canvasTex(c), roughness: 0.92 });
  };
  const W = 6, H = 4.2, D = 4.6;
  const mats = [face(D, H, 'none'), face(D, H, 'none'), face(W, D, 'y'), face(W, D, 'y'), face(W, H, 'y', true), face(W, H, 'none')];
  return new THREE.Mesh(new RoundedBoxGeometry(W, H, D, 3, 0.12), mats);
}
