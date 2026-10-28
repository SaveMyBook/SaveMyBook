// 用官網的現行書櫃模型（savemybook_web/src/three/cabinet.ts）離線算圖。
// 參數由網址 ?cfg=<base64 JSON>：{ w, h, yaw, pitch, dist, fov, target:[x,y,z], doors:[0..1]×4, xray, exposure, kiosk:'qr'|'match'|... }
import * as THREE from 'three';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';
import { Cabinet } from '../../../../../savemybook_web/src/three/cabinet';

(async () => {
  const cfg = JSON.parse(atob(new URLSearchParams(location.search).get('cfg')!));
  const W = cfg.w ?? 2000, H = cfg.h ?? 2000;
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
  renderer.setPixelRatio(1); renderer.setSize(W, H);
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.NeutralToneMapping;
  renderer.toneMappingExposure = cfg.exposure ?? 1.05;
  renderer.setClearColor(0x000000, 0);
  document.body.append(renderer.domElement);

  const scene = new THREE.Scene();
  const pmrem = new THREE.PMREMGenerator(renderer);
  scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.035).texture;
  scene.environmentIntensity = 0.85;
  const key = new THREE.DirectionalLight(0xffffff, 1.6); key.position.set(-18, 26, 34);
  const fill = new THREE.DirectionalLight(0xdfe8ee, 0.55); fill.position.set(22, -8, 18);
  scene.add(key, fill, new THREE.AmbientLight(0xffffff, 0.25));

  await document.fonts.load('700 78px "Noto Sans TC"', '救「舊」我的書');
  await document.fonts.load('500 40px "Noto Sans TC"', '請使用掃描 0123456789');
  const cab = new Cabinet();
  await cab.ready;
  scene.add(cab.group);
  (cfg.doors ?? []).forEach((v: number, i: number) => cab.setDoor(i, v));
  if (cfg.xray) cab.setXray(cfg.xray);
  cab.kiosk.draw({ state: cfg.kiosk ?? 'qr', refresh: 0.35, seconds: 60, digits: 1, check: 1 });
  await new Promise((r) => setTimeout(r, 300));
  cab.kiosk.draw({ state: cfg.kiosk ?? 'qr', refresh: 0.35, seconds: 60, digits: 1, check: 1 });

  const cam = new THREE.PerspectiveCamera(cfg.fov ?? 22, W / H, 1, 400);
  const d = cfg.dist ?? 40, yaw = cfg.yaw ?? 0.4, pitch = cfg.pitch ?? 0.1;
  const t = new THREE.Vector3(...(cfg.target ?? [0, 0, 0]));
  cam.position.set(t.x + d * Math.cos(pitch) * Math.sin(yaw), t.y + d * Math.sin(pitch), t.z + d * Math.cos(pitch) * Math.cos(yaw));
  cam.lookAt(t);
  renderer.render(scene, cam);
  renderer.render(scene, cam);
  (window as any).__info = { W: Cabinet.WIDTH, H: Cabinet.HEIGHT, D: Cabinet.DEPTH };
  (window as any).__done = true;
})().catch((e) => { (window as any).__error = String(e?.stack || e); console.error(e); });
