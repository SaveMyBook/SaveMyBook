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
  tex.anisotropy = 16;
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

/** 釋放畫面材質（按需載入時，用不到的畫面不留在顯示記憶體裡）。 */
export function releaseScreen(name: string, small: boolean) {
  const key = `${name}:${small}`;
  const p = screenCache.get(key);
  if (!p) return;
  screenCache.delete(key);
  p.then((t) => t.dispose()).catch(() => {});
}

/** 畫面圖檔的高度（以螢幕高度為 1）；長截圖大於 1，可在手機上捲動。 */
export const screenSpan = new Map<string, number>();

/**
 * App 畫面材質：保留整張圖（長截圖不裁切），狀態列另外畫在固定的頂端區域（由手機著色器處理捲動時的固定列）。
 * 狀態列畫在圖片頂端，捲動時頂端固定區會一直顯示這一段。
 */
export function screenTexture(name: string, small: boolean): Promise<THREE.Texture> {
  const key = `${name}:${small}`;
  if (!screenCache.has(key)) {
    screenCache.set(key, (async () => {
      const img = await loadImage(`/screens/${name}${small ? '-s' : ''}.webp`);
      const canvas = document.createElement('canvas');
      canvas.width = img.width;
      canvas.height = Math.max(Math.round(img.width * LOGICAL_H / LOGICAL_W), img.height);
      screenSpan.set(name, canvas.height / (img.width * LOGICAL_H / LOGICAL_W));
      const ctx = canvas.getContext('2d')!;
      ctx.drawImage(img, 0, 0, img.width, img.height);
      statusBar(ctx, canvas.width / LOGICAL_W, topIsDark(img));
      const tex = canvasTexture(canvas);
      tex.generateMipmaps = true;
      tex.minFilter = THREE.LinearMipmapLinearFilter;
      return tex;
    })());
  }
  return screenCache.get(key)!;
}

/* ---------------- 書櫃螢幕（橫向 320 × 240，版面同韌體 ui.cpp，以兩倍解析度繪製） ---------------- */

export type KioskState = 'qr' | 'busy' | 'match' | 'opening' | 'open' | 'done' | 'pair';
/**
 * header：頂列文字（預設為書櫃名稱；配對畫面依韌體固定為「智慧書櫃」）。
 * qr：QR Code 版本序號（每 30 秒換一組，換成不同序號即換一張 QR Code）；flash：換碼瞬間的白光（0～1）。
 * code、total：配對碼與配對碼有效總秒數（state 'pair'，seconds 為剩餘秒數）。
 */
export interface KioskParams {
  state: KioskState; refresh: number; seconds: number; digits: number; check: number; take?: boolean;
  header?: string; qr?: number; flash?: number; code?: string; total?: number;
}

const K = {
  bg: '#0E1318', header: '#18212A', text: '#EEF2F5', muted: '#93A2AD', track: '#2A3540', online: '#3CCF8E', accent: '#46B59C',
};
const KS = 2;
const kfont = (px: number, medium = false) => `${medium ? 500 : 400} ${px * KS}px "Noto Sans TC", sans-serif`;

export class Kiosk {
  /** 比對數字的字級（相對螢幕高）與兩字中心距的一半（相對螢幕寬）。 */
  static readonly DIGIT_EM = 96 / 240;
  static readonly DIGIT_GAP = 26 / 320;
  readonly canvas = document.createElement('canvas');
  readonly texture: THREE.CanvasTexture;
  private ctx: CanvasRenderingContext2D;
  private qrs = new Map<number, boolean[][]>();
  private last = '';

  /** name：頂列顯示的書櫃名稱。 */
  constructor(readonly name: string) {
    this.canvas.width = 320 * KS;
    this.canvas.height = 240 * KS;
    this.ctx = this.canvas.getContext('2d')!;
    this.texture = canvasTexture(this.canvas);
  }

  /** 第 i 組 QR Code（版本 4、錯誤修正 M，同韌體）；序號不同內容就不同。 */
  private qrOf(i: number) {
    if (!this.qrs.has(i)) {
      const q = qrcode(4, 'M');
      q.addData(i === 0 ? 'NMIXX HAEWON 0225' : `NMIXX HAEWON 0225 #${i}`);
      q.make();
      const n = q.getModuleCount();
      this.qrs.set(i, Array.from({ length: n }, (_, r) => Array.from({ length: n }, (_, c) => q.isDark(r, c))));
    }
    return this.qrs.get(i)!;
  }

  /** 數字在螢幕上的中心（0–1），供飛行動畫對位。 */
  readonly digitsAt = { x: 0.5, y: 126 / 240 };

  private text(s: string, x: number, y: number, font: string, color: string, align: CanvasTextAlign = 'center') {
    const g = this.ctx;
    g.font = font;
    g.fillStyle = color;
    g.textAlign = align;
    g.textBaseline = 'middle';
    g.fillText(s, x * KS, y * KS);
  }

  /** 同韌體 balancedWrap：斷成同樣行數下最窄的寬度，各行長度接近。 */
  private wrap(s: string, width: number, font: string) {
    const g = this.ctx;
    g.font = font;
    const tokens = s.match(/[A-Za-z0-9-]+|./gu) ?? [];
    const lines = (w: number) => {
      const out: string[] = [];
      let line = '';
      for (const tk of tokens) {
        if (line && g.measureText(line + tk).width > w * KS) { out.push(line); line = tk.trim() ? tk : ''; } else line += tk;
      }
      if (line) out.push(line);
      return out;
    };
    const first = lines(width);
    if (first.length < 2) return first;
    let lo = width / 2, hi = width;
    while (hi - lo > 1) {
      const mid = (lo + hi) / 2;
      if (lines(mid).length === first.length) hi = mid; else lo = mid;
    }
    return lines(hi);
  }

  private bar(x: number, y: number, w: number, ratio: number) {
    const g = this.ctx;
    g.fillStyle = K.track;
    g.fillRect(x * KS, y * KS, w * KS, 4 * KS);
    g.fillStyle = K.accent;
    g.fillRect(x * KS, y * KS, w * KS * Math.max(0, Math.min(1, ratio)), 4 * KS);
  }

  draw(p: KioskParams) {
    const sig = `${p.state}|${p.refresh.toFixed(2)}|${p.seconds}|${p.digits.toFixed(2)}|${p.check.toFixed(2)}|${p.take ? 1 : 0}|${p.header ?? ''}|${p.qr ?? 0}|${(p.flash ?? 0).toFixed(2)}|${p.code ?? ''}|${p.total ?? 0}`;
    if (sig === this.last) return;
    this.last = sig;
    const g = this.ctx;
    g.fillStyle = K.bg;
    g.fillRect(0, 0, this.canvas.width, this.canvas.height);
    g.fillStyle = K.header;
    g.fillRect(0, 0, 320 * KS, 28 * KS);
    this.text(p.header ?? (p.state === 'pair' ? '智慧書櫃' : this.name), 10, 14, kfont(16, true), K.text, 'left');
    g.fillStyle = K.online;
    g.beginPath();
    g.arc((320 - 14) * KS, 14 * KS, 4 * KS, 0, Math.PI * 2);
    g.fill();

    if (p.state === 'qr') {
      // QR Code 在左（版本 4 含靜區 41 格、每格 4 像素），說明在右
      const side = 164, qx = 16, qy = 40;
      g.fillStyle = '#FFFFFF';
      g.fillRect(qx * KS, qy * KS, side * KS, side * KS);
      const qr = this.qrOf(p.qr ?? 0);
      const n = qr.length, cell = (side - 32) / n;
      g.fillStyle = '#0E1318';
      for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) if (qr[r][c]) g.fillRect((qx + 16 + c * cell) * KS, (qy + 16 + r * cell) * KS, cell * KS + 0.6, cell * KS + 0.6);
      if ((p.flash ?? 0) > 0.005) {
        // 換碼瞬間：QR Code 區塊閃白後顯示新的一組
        g.globalAlpha = Math.min(1, p.flash ?? 0);
        g.fillStyle = '#FFFFFF';
        g.fillRect(qx * KS, qy * KS, side * KS, side * KS);
        g.globalAlpha = 1;
      }
      this.bar(qx, qy + side + 8, side, 1 - p.refresh);
      const left = qx + side + 12, width = 320 - 8 - left, cx = left + width / 2;
      const lines = this.wrap('請使用 SaveMyBook App 掃描', width, kfont(15));
      let y = qy + side / 2 - (lines.length * 24) / 2 + 12;
      for (const l of lines) { this.text(l, cx, y, kfont(15), K.text); y += 24; }
    } else if (p.state === 'busy') {
      this.text('書櫃使用中', 160, 84, kfont(16, true), K.text);
      this.text('請於手機確認項目', 160, 118, kfont(15), K.text);
      this.text(`剩餘 ${p.seconds} 秒`, 160, 154, kfont(13), K.muted);
      this.bar(40, 174, 240, p.seconds / 60);
    } else if (p.state === 'match') {
      this.text('請於手機輸入下列數字', 160, 56, kfont(16, true), K.text);
      g.globalAlpha = p.digits;
      this.text('25', 160, 126, kfont(96, true), K.text);
      g.globalAlpha = 1;
      this.text(`剩餘 ${p.seconds} 秒`, 160, 194, kfont(13), K.muted);
      this.bar(40, 214, 240, p.seconds / 60);
    } else if (p.state === 'pair') {
      // 同韌體 ui.cpp drawPairing 與 messages.h（PAIRING_TITLE／PAIRING_PROMPT／PAIRING_REMAINING）
      const total = p.total ?? 600, s = Math.max(0, p.seconds);
      this.text('配對碼', 160, 60, kfont(16, true), K.muted);
      this.text(p.code ?? '0151-7752', 160, 100, kfont(38, true), K.text);
      this.text('請於管理後台輸入此配對碼', 160, 146, kfont(15), K.text);
      this.text(`剩餘時間 ${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`, 160, 172, kfont(13), K.muted);
      this.bar(40, 192, 240, s / total);
    } else if (p.state === 'opening') {
      this.text('櫃門開啟中', 160, (28 + 240) / 2, kfont(16, true), K.text);
    } else if (p.state === 'open') {
      // 櫃門編號與說明在左，倒數在右
      this.text('A01', 18, 66, kfont(44, true), K.text, 'left');
      const msg = p.take ? '請取出 A01 內的書籍後關上櫃門' : '請將書籍放入 A01 後關上櫃門';
      const lines = this.wrap(msg, 184, kfont(15));
      let y = 132 - (lines.length - 1) * 12;
      for (const l of lines) { this.text(l, 18, y, kfont(15), K.text, 'left'); y += 24; }
      const cx = 255 * KS, cy = 131 * KS, r = 44 * KS;
      g.lineWidth = 5 * KS;
      g.strokeStyle = K.track;
      g.beginPath();
      g.arc(cx, cy, r, 0, Math.PI * 2);
      g.stroke();
      g.strokeStyle = K.accent;
      g.lineCap = 'round';
      g.beginPath();
      g.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * (p.seconds / 30));
      g.stroke();
      this.text(String(p.seconds), 255, 131, kfont(34, true), K.text);
    } else {
      const cx = 160 * KS, cy = 88 * KS;
      g.strokeStyle = K.accent;
      g.lineWidth = 3 * KS;
      g.beginPath();
      g.arc(cx, cy, 24 * KS, 0, Math.PI * 2);
      g.stroke();
      g.lineCap = 'round';
      g.lineJoin = 'round';
      const t = p.check;
      g.beginPath();
      g.moveTo(cx - 10 * KS, cy + 1 * KS);
      const a = Math.min(1, t * 2);
      g.lineTo(cx + (-10 + 7 * a) * KS, cy + (1 + 7 * a) * KS);
      if (t > 0.5) {
        const b = (t - 0.5) * 2;
        g.lineTo(cx + (-3 + 14 * b) * KS, cy + (8 - 15 * b) * KS);
      }
      g.stroke();
      this.text('作業完成', 160, 146, kfont(16, true), K.text);
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
