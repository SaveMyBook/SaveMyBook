import '@fontsource/noto-sans-tc/500.css';
import '@fontsource/noto-sans-tc/700.css';
import '@fontsource/noto-sans-tc/900.css';
import './cover.css';
import type { Pose } from './lib/kf';
import { Stage } from './stage';
import { World, SELLER } from './world';
import { LogoDraw } from './lib/logo';

/**
 * YouTube 封面（3840×2160）：左側品牌文字，右側為與動畫相同的書櫃與手機模型。
 * 由 tools/cover.mjs 以 2 倍像素密度截圖，輸出到 成品/YouTube封面_3840x2160.png。
 */
const CAB: Pose = { x: 0.262, y: -0.03, z: 0, rx: 0.05, ry: 0.17, rz: 0, s: 1.5 };
const PHONE: Pose = { x: 0.675, y: -0.05, z: 8, rx: 0.03, ry: -0.22, rz: 0, s: 1.0 };
/** 鏡頭飄移取 t = 0 的位置。 */
const T = 0;

declare global {
  interface Window { __ready: boolean }
}

const stage = new Stage(document.getElementById('gl') as HTMLCanvasElement, 2);
const world = new World(stage, []);
const logo = new LogoDraw(document.getElementById('logo')!);
logo.at(99, 0);
// LogoDraw 的原始尺寸為 1650×1300，縮到封面上約 173 寬
logo.root.style.transformOrigin = '0 0';
logo.root.style.transform = `scale(${173 / 1650})`;

function compose() {
  world.reset();
  const f = world.frame;
  f.cabinet = { pose: CAB, kiosk: { state: 'qr', refresh: 0.35, seconds: 60, digits: 1, check: 0 }, deposit: 1 };
  f.phones[SELLER] = { pose: PHONE, scr: { a: 's_cab_done' } };
  world.apply(T);
}

world.load().then(async () => {
  compose();
  await world.ensure(world.used, T);
  if (world.takeMissing().length) compose();
  stage.render();
  window.__ready = true;
});
