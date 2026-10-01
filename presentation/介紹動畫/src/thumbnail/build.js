'use strict';

// YouTube 封面（3840×2160）：從動畫 SVG 擷取書櫃與手機畫面，套進 cover.html 後以 2 倍像素密度截圖。
// 用法：在 src 目錄執行 node thumbnail/build.js；輸出到 ../成品/YouTube封面_3840x2160.png
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const puppeteer = require('puppeteer');
const ffmpeg = require('ffmpeg-static');
const core = require('../lib/core');
const { staticLogo } = require('../lib/logo');

const HERE = __dirname;
const CACHE = path.join(HERE, '.cache');
const SVG = path.resolve(HERE, '../../四技第115414組-救「舊」我的書-介紹動畫.svg');
const OUT = path.resolve(HERE, '../../成品/YouTube封面_3840x2160.png');

// 擷取時間點與裁切範圍（3840×2160 畫面座標）
const SHOTS = [
  { t: 22.15, file: 'cabinet.png', crop: '1400:1760:1240:200' }, // 書櫃全景：藍圖輔助線已淡出、X 光透視尚未開始
  { t: 48.6, file: 'phone.png', crop: '1000:2000:2660:100' },    // 手機：存書完成
];

async function grab(browser) {
  const page = await browser.newPage();
  await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 2 });
  await page.goto(`file://${SVG}`, { waitUntil: 'load' });
  await page.evaluate(() => document.documentElement.pauseAnimations());
  for (const s of SHOTS) {
    await page.evaluate((tt) => document.documentElement.setCurrentTime(tt), s.t);
    await page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))));
    const full = path.join(CACHE, `frame_${s.t}.png`);
    await page.screenshot({ path: full });
    execFileSync(ffmpeg, ['-hide_banner', '-loglevel', 'error', '-y', '-i', full, '-vf', `crop=${s.crop}`, path.join(CACHE, s.file)]);
  }
  await page.close();
}

function logo() {
  core.resetDefs();
  const body = staticLogo();
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="200 370 1650 1300"><defs>${core.defs.join('')}</defs>${body}</svg>`;
  fs.writeFileSync(path.join(CACHE, 'logo.svg'), svg);
}

async function shoot(browser) {
  const page = await browser.newPage();
  await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 2 });
  await page.goto(`file:///${path.join(HERE, 'cover.html').replace(/\\/g, '/')}`, { waitUntil: 'networkidle0' });
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: OUT, type: 'png' });
  await page.close();
}

(async () => {
  fs.mkdirSync(CACHE, { recursive: true });
  logo();
  const browser = await puppeteer.launch({ headless: 'shell', args: ['--allow-file-access-from-files'] });
  await grab(browser);
  await shoot(browser);
  await browser.close();
  console.log(`封面已輸出：${OUT}`);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
