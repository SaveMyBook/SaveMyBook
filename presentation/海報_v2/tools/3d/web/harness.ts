// 用官網的現行書櫃模型（savemybook_web/src/three/cabinet.ts）離線算圖。
// 參數由網址 ?cfg=<base64 JSON>：{ w, h, yaw, pitch, dist, fov, target:[x,y,z], doors:[0..1]×4, xray, exposure, kiosk:'qr'|'match'|..., glb }
import * as THREE from 'three';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';
import { GLTFExporter } from 'three/examples/jsm/exporters/GLTFExporter.js';
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
  if (cfg.seq) {
    // 存書／取書時間軸（簡報展示頁用）：時間點對齊手機錄影 savemybook_app/tool/deck_gifs 的 marks.txt。
    // window.__seqFrame(t) 依時間 t（秒）設定書櫃螢幕、A01 櫃門與書本，算一格並回傳 PNG data URL。
    const take = cfg.seq === 'pickup';
    const T = { scan: 2.517, match: 5.15, opening: 7.117, open: 7.433, done: 9.233 };
    const seg = (t: number, a: number, b: number) => Math.max(0, Math.min(1, (t - a) / (b - a)));
    const ease = (u: number) => u * u * (3 - 2 * u);
    renderer.setClearColor(new THREE.Color(cfg.bg ?? '#F5F5F7'), 1);
    (window as any).__seqFrame = (t: number) => {
      const refresh = ((t + 10) % 30) / 30;
      let k: any = { state: 'qr', refresh, seconds: 60, digits: 1, check: 1, take };
      if (t >= T.done) k = { ...k, state: 'done', check: seg(t, T.done, T.done + 0.6) };
      else if (t >= T.open) k = { ...k, state: 'open', seconds: Math.max(0, 30 - Math.floor(t - T.open)) };
      else if (t >= T.opening) k = { ...k, state: 'opening' };
      else if (t >= T.match) k = { ...k, state: 'match', seconds: 60 - Math.floor(t - T.match) };
      else if (t >= T.scan) k = { ...k, state: 'busy', seconds: 60 - Math.floor(t - T.scan) };
      cab.kiosk.draw(k);
      // 櫃門：開門 → 放入或取出書本 → 關門
      const door = t < 8.7 ? ease(seg(t, T.open, 7.9)) : 1 - ease(seg(t, 8.7, T.done));
      cab.setDoor(0, door);
      const book = ease(seg(t, 7.9, 8.6));
      cab.setDeposit(take ? 1 : book, take ? book : 0);
      renderer.render(scene, cam);
      return renderer.domElement.toDataURL('image/png');
    };
  }
  if (cfg.glb) {
    // 匯出 GLB（簡報的 3D 模型用）：透視用的邊線與全透明零件不匯出，模型中心移到原點
    cab.group.traverse((o: any) => {
      const mats = [o.material].flat().filter(Boolean);
      if (o.isLine || (mats.length && mats.every((m: any) => m.transparent && m.opacity === 0))) o.visible = false;
    });
    // 轉角 ay 直接放進模型（簡報端 am3d:rot 維持恆等）；只量匯出的（可見的）網格，Box3.setFromObject 會把隱藏零件一起算進去
    cab.group.rotation.y = cfg.ay ?? 0;
    const box = new THREE.Box3();
    const shown = (o: any) => { for (let x = o; x; x = x.parent) if (!x.visible) return false; return true; };
    cab.group.updateMatrixWorld(true);
    cab.group.traverse((o: any) => { if (o.isMesh && shown(o)) box.expandByObject(o, true); });
    const size = box.getSize(new THREE.Vector3()), center = box.getCenter(new THREE.Vector3());
    cab.group.position.sub(center);
    cab.group.updateMatrixWorld(true);
    const glb = (await new GLTFExporter().parseAsync(cab.group, { binary: true, onlyVisible: true })) as ArrayBuffer;
    let s = '';
    const bytes = new Uint8Array(glb);
    for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
    (window as any).__glb = btoa(s);

    // PowerPoint 的 3D 模型相機（am3d）：模型縮成最大邊 1 公尺，fov 45°，
    // 距離 = |半邊長| ÷ 最大邊 ÷ sin(22.5°)（PowerPoint 插入時的算法），相機仰角 pitch。
    // 算出模型投影範圍（占正方形視野的比例 fx、fy），並用同一個相機算替代圖。
    const maxExt = Math.max(size.x, size.y, size.z);
    const pivot = new THREE.Group();
    scene.add(pivot);
    pivot.add(cab.group);
    pivot.scale.setScalar(1 / maxExt);
    pivot.updateMatrixWorld(true);
    const dist = size.length() / 2 / maxExt / Math.sin(Math.PI / 8);
    const p = cfg.pitch ?? 0;
    const cam3d = new THREE.PerspectiveCamera(45, 1, 0.01, 100);
    cam3d.position.set(0, dist * Math.sin(p), dist * Math.cos(p));
    cam3d.lookAt(0, 0, 0);
    cam3d.updateMatrixWorld(true);
    let fx = 0, fy = 0;
    // 逐點投影可見網格的頂點，取緊貼模型的範圍（外框角點會高估）
    const v = new THREE.Vector3();
    cab.group.traverse((o: any) => {
      if (!o.isMesh || !shown(o)) return;
      const pos = o.geometry.attributes.position;
      for (let i = 0; i < pos.count; i++) {
        v.fromBufferAttribute(pos, i).applyMatrix4(o.matrixWorld).project(cam3d);
        fx = Math.max(fx, Math.abs(v.x));
        fy = Math.max(fy, Math.abs(v.y));
      }
    });
    renderer.setSize(W, W);
    renderer.render(scene, cam3d);
    renderer.render(scene, cam3d);
    (window as any).__model3d = { maxExt, size: size.toArray(), dist, pitch: p, ay: cfg.ay ?? 0, fx, fy };
  }
  (window as any).__info = { W: Cabinet.WIDTH, H: Cabinet.HEIGHT, D: Cabinet.DEPTH };
  (window as any).__done = true;
})().catch((e) => { (window as any).__error = String(e?.stack || e); console.error(e); });
