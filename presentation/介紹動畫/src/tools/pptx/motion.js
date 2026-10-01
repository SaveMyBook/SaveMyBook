'use strict';

// 量測每個時間點的畫面變化量：node tools/pptx/motion.js <svg> <out.json> [fps] [片長秒數]
// 以低解析度逐格截圖，計算相鄰兩格的平均像素差，供挑選投影片時間點使用。
const path = require('path');
const fs = require('fs');
const puppeteer = require('puppeteer');
const { PNG } = require('pngjs');

const [svg, out, fpsArg = '10', durArg = '177'] = process.argv.slice(2);
const FPS = Number(fpsArg);
const W = 480;
const H = 270;

async function main() {
  const browser = await puppeteer.launch({ headless: 'shell', args: ['--hide-scrollbars'] });
  const page = await browser.newPage();
  await page.setViewport({ width: W, height: H, deviceScaleFactor: 1 });
  await page.goto(`file://${path.resolve(svg)}`, { waitUntil: 'load' });
  await page.evaluate(() => document.documentElement.pauseAnimations());
  const duration = Number(durArg);
  const n = Math.round(duration * FPS);
  let prev = null;
  const diff = [];
  for (let i = 0; i <= n; i++) {
    const t = i / FPS;
    await page.evaluate((tt) => document.documentElement.setCurrentTime(tt), t);
    const png = PNG.sync.read(await page.screenshot({ type: 'png' }));
    if (prev) {
      let sum = 0;
      for (let k = 0; k < png.data.length; k += 4) {
        sum += Math.abs(png.data[k] - prev.data[k]) + Math.abs(png.data[k + 1] - prev.data[k + 1]) + Math.abs(png.data[k + 2] - prev.data[k + 2]);
      }
      diff.push(Math.round((sum / (W * H)) * 1000) / 1000);
    } else {
      diff.push(0);
    }
    prev = png;
    if (i % 100 === 0) process.stderr.write(`${t.toFixed(1)}s\n`);
  }
  await browser.close();
  fs.writeFileSync(out, JSON.stringify({ fps: FPS, duration, diff }));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
