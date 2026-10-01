import * as THREE from 'three';
import qrcode from 'qrcode-generator';

const loaded = new Map<string, Promise<HTMLImageElement>>();

export function loadImage(src: string): Promise<HTMLImageElement> {
  if (!loaded.has(src)) {
    loaded.set(src, new Promise((resolve, reject) => {
      const img = new Image();
      img.decoding = 'async';
      img.onload = () => resolve(img);
      img.onerror = reject;
      img.src = src;
    }));
  }
  return loaded.get(src)!;
}

function canvasTexture(canvas: HTMLCanvasElement) {
  const tex = new THREE.CanvasTexture(canvas);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 8;
  return tex;
}

/* ---------------- App 畫面（加上狀態列） ---------------- */

const LOGICAL_W = 393;
const LOGICAL_H = 852;

function statusBar(ctx: CanvasRenderingContext2D, k: number, dark: boolean) {
  const c = dark ? '#F3F5F7' : '#151E27';
  ctx.save();
  ctx.fillStyle = c;
  ctx.strokeStyle = c;
  ctx.font = `600 ${17 * k}px -apple-system, "SF Pro Text", "Helvetica Neue", Arial, sans-serif`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('2:25', 64 * k, 31 * k);
  // 訊號
  for (let i = 0; i < 4; i++) {
    const h = (4 + i * 2.6) * k;
    ctx.beginPath();
    ctx.roundRect((292 + i * 4.6) * k, 36 * k - h, 3 * k, h, 0.8 * k);
    ctx.fill();
  }
  // Wi-Fi
  ctx.lineWidth = 2.1 * k;
  ctx.lineCap = 'round';
  const wx = 324 * k, wy = 37.5 * k;
  for (let i = 0; i < 3; i++) {
    const r = (3.2 + i * 3.9) * k;
    ctx.beginPath();
    if (i === 0) {
      ctx.arc(wx, wy - 1.2 * k, 1.6 * k, 0, Math.PI * 2);
      ctx.fill();
    } else {
      ctx.arc(wx, wy, r, Math.PI * 1.25, Math.PI * 1.75);
      ctx.stroke();
    }
  }
  // 電池
  ctx.globalAlpha = 0.4;
  ctx.lineWidth = 1.1 * k;
  ctx.beginPath();
  ctx.roundRect(343 * k, 25 * k, 25 * k, 12.5 * k, 3.6 * k);
  ctx.stroke();
  ctx.beginPath();
  ctx.roundRect(369.4 * k, 29 * k, 1.6 * k, 4.6 * k, 0.8 * k);
  ctx.fill();
  ctx.globalAlpha = 1;
  ctx.beginPath();
  ctx.roundRect(345 * k, 27 * k, 17 * k, 8.5 * k, 2.2 * k);
  ctx.fill();
  ctx.restore();
}

function topIsDark(img: HTMLImageElement) {
  const c = document.createElement('canvas');
  c.width = 40;
  c.height = 4;
  const g = c.getContext('2d')!;
  g.drawImage(img, 0, 0, img.width, img.height * 0.06, 0, 0, 40, 4);
  const d = g.getImageData(0, 0, 40, 4).data;
  let sum = 0;
  for (let i = 0; i < d.length; i += 4) sum += 0.2126 * d[i] + 0.7152 * d[i + 1] + 0.0722 * d[i + 2];
  return sum / (d.length / 4) < 128;
}

const screenCache = new Map<string, Promise<THREE.Texture>>();

export function screenTexture(name: string, small: boolean): Promise<THREE.Texture> {
  const key = `${name}:${small}`;
  if (!screenCache.has(key)) {
    screenCache.set(key, (async () => {
      const img = await loadImage(`/screens/${name}${small ? '-s' : ''}.webp`);
      const canvas = document.createElement('canvas');
      canvas.width = img.width;
      canvas.height = Math.round(img.width * LOGICAL_H / LOGICAL_W);
      const ctx = canvas.getContext('2d')!;
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
      statusBar(ctx, canvas.width / LOGICAL_W, topIsDark(img));
      const tex = canvasTexture(canvas);
      tex.generateMipmaps = true;
      tex.minFilter = THREE.LinearMipmapLinearFilter;
      return tex;
    })());
  }
  return screenCache.get(key)!;
}

/* ---------------- 書櫃螢幕（240 × 320） ---------------- */

export type KioskState = 'qr' | 'busy' | 'match' | 'open' | 'done';
export interface KioskParams { state: KioskState; refresh: number; seconds: number; digits: number; check: number }

const K = {
  bg: '#0E1318', header: '#18212A', text: '#EEF2F5', muted: '#93A2AD', track: '#2A3540', online: '#3CCF8E', accent: '#46B59C',
};

export class Kiosk {
  readonly canvas = document.createElement('canvas');
  readonly texture: THREE.CanvasTexture;
  private ctx: CanvasRenderingContext2D;
  private qr: boolean[][];
  private last = '';

  constructor() {
    this.canvas.width = 480;
    this.canvas.height = 640;
    this.ctx = this.canvas.getContext('2d')!;
    const q = qrcode(0, 'M');
    q.addData('NMIXX HAEWON 0225');
    q.make();
    const n = q.getModuleCount();
    this.qr = Array.from({ length: n }, (_, r) => Array.from({ length: n }, (_, c) => q.isDark(r, c)));
    this.texture = canvasTexture(this.canvas);
  }

  /** 數字在螢幕上的中心（0–1），供飛行動畫對位。 */
  readonly digitsAt = { x: 0.5, y: 0.54 };

  draw(p: KioskParams) {
    const sig = `${p.state}|${p.refresh.toFixed(2)}|${p.seconds}|${p.digits.toFixed(2)}|${p.check.toFixed(2)}`;
    if (sig === this.last) return;
    this.last = sig;
    const g = this.ctx;
    const W = 480, H = 640;
    g.fillStyle = K.bg;
    g.fillRect(0, 0, W, H);
    // 頂列
    g.fillStyle = K.header;
    g.fillRect(0, 0, W, 54);
    g.fillStyle = K.text;
    g.font = '500 20px "Noto Sans TC", sans-serif';
    g.textBaseline = 'middle';
    g.textAlign = 'left';
    g.fillText('智慧書櫃', 22, 28);
    g.fillStyle = K.online;
    g.beginPath();
    g.arc(W - 24, 28, 6, 0, Math.PI * 2);
    g.fill();

    g.textAlign = 'center';
    if (p.state === 'qr' || p.state === 'busy') {
      const s = 288, x = (W - s) / 2, y = 112;
      g.fillStyle = '#FFFFFF';
      g.beginPath();
      g.roundRect(x - 14, y - 14, s + 28, s + 28, 18);
      g.fill();
      const n = this.qr.length, cell = s / n;
      g.fillStyle = '#0E1318';
      for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) if (this.qr[r][c]) g.fillRect(x + c * cell, y + r * cell, cell + 0.4, cell + 0.4);
      if (p.state === 'busy') {
        g.fillStyle = 'rgba(14,19,24,.82)';
        g.fillRect(x - 14, y - 14, s + 28, s + 28);
      }
      g.fillStyle = K.text;
      g.font = '400 21px "Noto Sans TC", sans-serif';
      g.fillText(p.state === 'busy' ? '書櫃使用中｜請於手機確認項目' : '請使用 SaveMyBook App 掃描', W / 2, 500);
      g.fillStyle = K.track;
      g.fillRect(60, 446, W - 120, 5);
      g.fillStyle = K.accent;
      g.fillRect(60, 446, (W - 120) * (1 - p.refresh), 5);
    } else if (p.state === 'match') {
      g.fillStyle = K.text;
      g.font = '500 25px "Noto Sans TC", sans-serif';
      g.fillText('請於手機輸入下列數字', W / 2, 170);
      g.globalAlpha = p.digits;
      g.font = '500 150px "IBM Plex Mono", monospace';
      g.fillText('25', W / 2, this.digitsAt.y * H);
      g.globalAlpha = 1;
      g.fillStyle = K.muted;
      g.font = '400 19px "Noto Sans TC", sans-serif';
      g.fillText(`剩餘 ${p.seconds} 秒`, W / 2, 520);
    } else if (p.state === 'open') {
      g.fillStyle = K.text;
      g.font = '500 92px "IBM Plex Mono", monospace';
      g.fillText('A01', W / 2, 168);
      g.font = '400 21px "Noto Sans TC", sans-serif';
      g.fillText('請將書籍放入 A01 後關上櫃門', W / 2, 252);
      const cx = W / 2, cy = 440, r = 66;
      g.strokeStyle = K.track;
      g.lineWidth = 10;
      g.beginPath();
      g.arc(cx, cy, r, 0, Math.PI * 2);
      g.stroke();
      g.strokeStyle = K.accent;
      g.lineCap = 'round';
      g.beginPath();
      g.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * (p.seconds / 30));
      g.stroke();
      g.fillStyle = K.text;
      g.font = '500 48px "IBM Plex Mono", monospace';
      g.fillText(String(p.seconds), cx, cy + 3);
    } else {
      const cx = W / 2, cy = 280;
      g.strokeStyle = K.online;
      g.lineWidth = 9;
      g.beginPath();
      g.arc(cx, cy, 70, 0, Math.PI * 2);
      g.stroke();
      g.lineCap = 'round';
      g.lineJoin = 'round';
      g.beginPath();
      const t = p.check;
      g.moveTo(cx - 32, cy + 2);
      g.lineTo(cx - 32 + 22 * Math.min(1, t * 2), cy + 2 + 22 * Math.min(1, t * 2));
      if (t > 0.5) g.lineTo(cx - 10 + 46 * (t - 0.5) * 2, cy + 24 - 50 * (t - 0.5) * 2);
      g.stroke();
      g.fillStyle = K.text;
      g.font = '500 28px "Noto Sans TC", sans-serif';
      g.fillText('作業完成', W / 2, 420);
    }
    this.texture.needsUpdate = true;
  }
}

/* ---------------- 其他材質 ---------------- */

export function paperTexture(): THREE.CanvasTexture {
  const c = document.createElement('canvas');
  c.width = c.height = 256;
  const g = c.getContext('2d')!;
  const img = g.createImageData(256, 256);
  let seed = 11;
  const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  for (let i = 0; i < img.data.length; i += 4) {
    const v = 236 + (rnd() - 0.5) * 22;
    img.data[i] = v - 3;
    img.data[i + 1] = v;
    img.data[i + 2] = v + 3;
    img.data[i + 3] = 255;
  }
  g.putImageData(img, 0, 0);
  const tex = canvasTexture(c);
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.repeat.set(3, 3);
  return tex;
}

export async function labelTexture(): Promise<THREE.CanvasTexture> {
  const c = document.createElement('canvas');
  c.width = 640;
  c.height = 96;
  const g = c.getContext('2d')!;
  g.fillStyle = '#EEF1F3';
  g.fillRect(0, 0, c.width, c.height);
  try {
    const mark = await loadImage('/brand/book-slate-128.png');
    g.drawImage(mark, 168, 20, 56, 56);
  } catch { /* 標誌載入失敗時只顯示文字 */ }
  g.fillStyle = '#3B505C';
  g.font = '700 34px "Noto Serif TC", serif';
  g.textBaseline = 'middle';
  g.fillText('救「舊」我的書', 236, 50);
  return canvasTexture(c);
}

export function doorPlate(text: string): THREE.CanvasTexture {
  const c = document.createElement('canvas');
  c.width = 128;
  c.height = 56;
  const g = c.getContext('2d')!;
  g.fillStyle = '#627D8D';
  g.beginPath();
  g.roundRect(0, 0, 128, 56, 12);
  g.fill();
  g.fillStyle = '#FFFFFF';
  g.font = '500 32px "IBM Plex Mono", monospace';
  g.textAlign = 'center';
  g.textBaseline = 'middle';
  g.fillText(text, 64, 30);
  return canvasTexture(c);
}

export function coverTexture(color: string, title: string, band: string): THREE.CanvasTexture {
  const c = document.createElement('canvas');
  c.width = 256;
  c.height = 360;
  const g = c.getContext('2d')!;
  g.fillStyle = color;
  g.fillRect(0, 0, 256, 360);
  g.fillStyle = band;
  g.fillRect(28, 170, 210, 80);
  g.fillStyle = 'rgba(255,255,255,.92)';
  g.font = '700 30px "Noto Serif TC", serif';
  g.fillText(title, 32, 70);
  return canvasTexture(c);
}
