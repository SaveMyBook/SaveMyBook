// 簡報用圖檔：從易拉展、海報與複評素材產生到 build/assets/（可重跑，輸出不進版控）。
//   hero-cabinet.png、hero-phone.png  易拉展主視覺（書櫃＋手機）裁掉底色後，左右拆成兩張（封面用）
//   xray.png        書櫃透視圖（官網現行模型），裁掉透明邊
//   cabinet-open.png  A01 櫃門打開的書櫃（存書／取書展示頁）
//   cabinet3d-preview.png  封面 3D 模型的替代圖（舊版 PowerPoint 顯示這張）
//   logo.png、qr.png
const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

sharp.cache(false);
const ROOT = path.join(__dirname, '..');
const PRES = path.join(ROOT, '..');
const OUT = path.join(ROOT, 'build', 'assets');

async function hero() {
  // 易拉展 300 dpi 原檔：主視覺（含手機底部與陰影）約在 y 3,600–11,300 px 之間，trim 掉 #F5F5F7 底色後縮到 2,400 px 寬
  const src = path.join(PRES, '海報_v2', '易拉展', '救舊我的書－易拉展.png');
  sharp.concurrency(1);
  const crop = await sharp(src, { limitInputPixels: false })
    .extract({ left: 0, top: 3600, width: 10630, height: 7700 })
    .png().toBuffer();
  const trimmed = await sharp(crop).trim({ background: '#F5F5F7', threshold: 6 }).png().toBuffer();
  const hero = await sharp(trimmed).resize({ width: 2400 }).png().toBuffer();
  // 縮成 2,400 px 寬後，書櫃在 x 0–1,660；手機在 x 1,700 以後、y 340 以下（實測範圍）
  const { height } = await sharp(hero).metadata();
  await sharp(hero).extract({ left: 0, top: 0, width: 1660, height }).png().toFile(path.join(OUT, 'hero-cabinet.png'));
  await sharp(hero).extract({ left: 1700, top: 340, width: 700, height: height - 340 }).png().toFile(path.join(OUT, 'hero-phone.png'));
}

async function xray() {
  // 素材/cabinet_xray.png、cabinet_open.png 是官網現行書櫃模型的算圖（透視、A01 櫃門打開；見 README），這裡只裁掉透明邊
  await sharp(path.join(ROOT, '素材', 'cabinet_xray.png')).trim({ threshold: 1 }).png().toFile(path.join(OUT, 'xray.png'));
  await sharp(path.join(ROOT, '素材', 'cabinet_open.png')).trim({ threshold: 1 }).png().toFile(path.join(OUT, 'cabinet-open.png'));
}

async function model3dPreview() {
  // 素材/cabinet-preview.png 是 PowerPoint 同相機的正方形視野；依 cabinet.json 的投影範圍（fx、fy）從中心裁出畫框
  const { fx, fy } = JSON.parse(fs.readFileSync(path.join(ROOT, '素材', 'cabinet.json'), 'utf8'));
  const src = path.join(ROOT, '素材', 'cabinet-preview.png');
  const { width: S } = await sharp(src).metadata();
  const w = Math.round(fx * S), h = Math.round(fy * S);
  await sharp(src).extract({ left: Math.round((S - w) / 2), top: Math.round((S - h) / 2), width: w, height: h }).png().toFile(path.join(OUT, 'cabinet3d-preview.png'));
}

async function main() {
  fs.mkdirSync(OUT, { recursive: true });
  const brand = path.join(PRES, '海報_v2', 'src', 'assets', 'brand');
  await sharp(path.join(brand, 'logo.svg'), { density: 600 }).resize({ width: 400 }).png().toFile(path.join(OUT, 'logo.png'));
  await sharp(path.join(brand, 'qr-site-ink.svg'), { density: 600 }).resize({ width: 800 }).png().toFile(path.join(OUT, 'qr.png'));
  await xray();
  await model3dPreview();
  await hero();
  console.log('assets →', OUT);
}

main().catch((e) => { console.error(e); process.exit(1); });
