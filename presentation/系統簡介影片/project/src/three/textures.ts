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
      // 第二版畫面（v_ 開頭）由 savemybook_app/tool/video_shots 以真實資料產生，只有全尺寸
      const img = await loadImage(name.startsWith('v_') ? `/v2/screens/${name}.webp` : `/screens/${name}${small ? '-s' : ''}.webp`);
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

/* ---------------- 去背元件（第二版浮出元件，透明背景 PNG） ---------------- */

const cutCache = new Map<string, Promise<THREE.Texture>>();

/** 去背元件材質：以預乘 alpha 上傳，線性濾波與 mipmap 時邊緣不會混入透明像素的黑色。 */
export function cutTexture(name: string): Promise<THREE.Texture> {
  if (!cutCache.has(name)) {
    cutCache.set(name, (async () => {
      const img = await loadImage(`/v2/cuts/${name}.png`);
      const tex = new THREE.Texture(img);
      tex.colorSpace = THREE.SRGBColorSpace;
      tex.premultiplyAlpha = true;
      tex.anisotropy = 16;
      tex.generateMipmaps = true;
      tex.minFilter = THREE.LinearMipmapLinearFilter;
      tex.needsUpdate = true;
      return tex;
    })());
  }
  return cutCache.get(name)!;
}

export function releaseCut(name: string) {
  const p = cutCache.get(name);
  if (!p) return;
  cutCache.delete(name);
  p.then((t) => t.dispose()).catch(() => {});
}

/* ---------------- 書櫃螢幕（橫向 320 × 240，版面同韌體 ui.cpp 的亮色畫面，預設以兩倍解析度繪製） ---------------- */

export type KioskState = 'qr' | 'busy' | 'match' | 'opening' | 'open' | 'done' | 'pair';
/**
 * header：動態島文字，預設同韌體 messages.h 的 TITLE（「救「舊」我的書」），配對畫面也相同。
 * qr：QR Code 版本序號（每 30 秒換一組，換成不同序號即換一張 QR Code）；flash：換碼瞬間 QR Code 卡片的白光（0～1）。
 * code、total：配對碼與配對碼有效總秒數（state 'pair'，seconds 為剩餘秒數）。
 * clock：動態島右側的時間（韌體顯示臺灣時間，預覽固定 14:25）；未指定時同韌體不顯示時間。
 * tick：「櫃門開啟中」轉圈的時間（秒）；未指定時停在固定的一格。
 * pop：螢幕浮出（Cabinet 的 screenPop），每格隨 kiosk 一起寫入，沒寫就收回，不會殘留到其他段落。
 */
export interface KioskParams {
  state: KioskState; refresh: number; seconds: number; digits: number; check: number; take?: boolean;
  header?: string; qr?: number; flash?: number; code?: string; total?: number;
  clock?: string; tick?: number; pop?: KioskPop;
}

/**
 * 螢幕浮出：k 為 0～1；dx、dy、dz 為完全浮出時相對螢幕中心的位移（書櫃本體座標），s 為完全浮出時相對螢幕的放大倍率。
 * 浮出時轉成正對鏡頭（不跟著書櫃的轉角），文字才讀得清楚；look 為鏡頭的世界座標（鏡頭會移動時，轉向實際的鏡頭）。
 * slot：浮出時書櫃上的螢幕窗改為空位（深灰內凹），落回時恢復。turn：轉向鏡頭的程度（0～1，預設 1；小於 1 時保留一點書櫃的角度，看得出透視）。
 */
export interface KioskPop { k: number; dx: number; dy: number; dz: number; s: number; look?: [number, number, number]; slot?: boolean; turn?: number }

/** Cabinet 使用的螢幕介面；簡報素材（src/deck）沿用舊版畫面時以另一個類別實作。 */
export interface KioskSurface {
  readonly canvas: HTMLCanvasElement;
  readonly texture: THREE.CanvasTexture;
  readonly digitsAt: { x: number; y: number };
  onPop: ((pop: KioskPop | null) => void) | null;
  draw(p: KioskParams): void;
  setScale(k: number): void;
}

// 韌體 pal 色票；淡色依韌體 mix() 先算好
const K = {
  bgTop: '#DFE7EC', bgBottom: '#F3F5F7', island: '#151E27', islandMuted: '#A9B6BF', primary: '#627D8D', primaryLight: '#B9C7CF',
  card: '#FFFFFF', text: '#151E27', muted: '#5F6673', track: '#E6EAED', success: '#2E9E5B', successHalo: '#E3F2E9', warn: '#D98613',
  onPrimary: '#EDF0F2', pairLabel: '#E6EAED', mapFrame: '#99ABB5', mapSlot: '#879CA8',
};
const TITLE = '救「舊」我的書';
const TOP = 44, BOTTOM = 228, M = 12, GAP = 10, RING_W = 100, WR = 22, TEXT_X = 16, HEAD_LH = 28, QR_BOX = 164;
const MATCH_Y = TOP + 2 + HEAD_LH + 10, MATCH_W = 320 - 2 * M - GAP - RING_W;
const RING_TOTAL: Partial<Record<KioskState, number>> = { busy: 60, match: 60, open: 30 };
const BADGE_IN = 420, CHECK_DELAY = 160, CHECK_MS = 340, ENTER = CHECK_DELAY + CHECK_MS + 60;
/** 字級（韌體像素）與字重，同韌體 fonts.h。 */
const F = {
  small: [13, false], body: [15, false], title: [16, true], head: [20, true],
  label: [44, true], labelSm: [28, true], ring: [34, true], huge: [96, true],
} as const satisfies Record<string, readonly [number, boolean]>;
type Font = (typeof F)[keyof typeof F];
/** 畫面上會出現的字，先載入字型（Noto Sans TC 依字元分批），第一格就不會用到替代字型。 */
const GLYPHS = `${TITLE}請使用 SaveMyBook App 掃描書櫃使用中請於手機確認項目輸入下列數字櫃門開啟中將書籍放入取出內的後關上作業完成配對碼管理後台此剩餘時間秒 A01 0123456789:`;
const clamp01 = (t: number) => Math.max(0, Math.min(1, t));
const easeOutCubic = (t: number) => 1 - (1 - clamp01(t)) ** 3;
const easeOutBack = (t: number) => { const u = clamp01(t) - 1; return 1 + 2.4 * u ** 3 + 1.4 * u ** 2; };

/** 動態島標誌：裁去透明邊後縮成高 16（韌體像素），以淺霧藍上色（同韌體 make_logo.py 與 island()）。 */
function islandLogo(img: HTMLImageElement, k: number) {
  const src = document.createElement('canvas');
  src.width = img.naturalWidth;
  src.height = img.naturalHeight;
  const s = src.getContext('2d', { willReadFrequently: true })!;
  s.drawImage(img, 0, 0);
  const { data } = s.getImageData(0, 0, src.width, src.height);
  let x0 = src.width, y0 = src.height, x1 = 0, y1 = 0;
  for (let y = 0; y < src.height; y++) {
    for (let x = 0; x < src.width; x++) {
      if (data[(y * src.width + x) * 4 + 3] < 8) continue;
      x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y);
    }
  }
  const out = document.createElement('canvas');
  out.height = 16 * k;
  out.width = Math.round(((x1 - x0 + 1) * out.height) / (y1 - y0 + 1));
  const g = out.getContext('2d')!;
  g.drawImage(src, x0, y0, x1 - x0 + 1, y1 - y0 + 1, 0, 0, out.width, out.height);
  g.globalCompositeOperation = 'source-in';
  g.fillStyle = K.primaryLight;
  g.fillRect(0, 0, out.width, out.height);
  return out;
}

export class Kiosk implements KioskSurface {
  /** 比對數字的字級（相對螢幕高）與兩字中心距的一半（相對螢幕寬；Noto Sans TC 數字等寬 0.57 em，字距 10）。 */
  static readonly DIGIT_EM = 96 / 240;
  static readonly DIGIT_GAP = (96 * 0.57 + 10) / 2 / 320;
  readonly canvas = document.createElement('canvas');
  readonly texture: THREE.CanvasTexture;
  /** 數字在螢幕上的中心（0–1），供飛行動畫對位：霧藍卡片的中心，同韌體 drawMatch。 */
  readonly digitsAt = { x: (M + MATCH_W / 2) / 320, y: (MATCH_Y + (BOTTOM - MATCH_Y) / 2 + 2) / 240 };
  /** 字型與標誌都載入後完成（Cabinet.ready 會等它）。 */
  readonly ready: Promise<void>;
  private ctx: CanvasRenderingContext2D;
  private qrs = new Map<number, boolean[][]>();
  private img: HTMLImageElement | null = null;
  private logo: HTMLCanvasElement | null = null;
  private last = '';
  /** 每個韌體像素畫成幾個材質像素。 */
  private k = 2;
  /** 由 Cabinet 接上：每次 draw 都回報螢幕浮出狀態。 */
  onPop: ((pop: KioskPop | null) => void) | null = null;

  /** name：書櫃名稱（實機畫面不顯示，保留給呼叫端相容）。 */
  constructor(readonly name: string) {
    this.canvas.width = 320 * this.k;
    this.canvas.height = 240 * this.k;
    this.ctx = this.canvas.getContext('2d')!;
    this.texture = canvasTexture(this.canvas);
    const fonts = Promise.all([400, 500].map((w) => document.fonts.load(`${w} 20px "Noto Sans TC"`, GLYPHS))).catch(() => {});
    const logo = loadImage('/brand/book-slate-128.png').then((img) => { this.img = img; this.logo = islandLogo(img, this.k); }).catch(() => { /* 沒有標誌時只顯示文字 */ });
    // 畫布不會等字型與標誌，晚到時下一格要整張重畫
    this.ready = Promise.all([fonts, logo]).then(() => { this.last = ''; });
  }

  /** 螢幕放大浮出時改用較高解析度（4K 成品中浮出的螢幕寬約 1000 像素）；改變大小後材質需重新上傳。 */
  setScale(k: number) {
    if (k === this.k) return;
    this.k = k;
    this.canvas.width = 320 * k;
    this.canvas.height = 240 * k;
    if (this.img) this.logo = islandLogo(this.img, k);
    this.last = '';
    this.texture.dispose();
    this.texture.needsUpdate = true;
  }

  private font([px, medium]: Font) {
    return `${medium ? 500 : 400} ${px * this.k}px "Noto Sans TC", sans-serif`;
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

  private text(s: string, x: number, cy: number, font: Font, color: string, align: CanvasTextAlign = 'center') {
    const g = this.ctx;
    g.font = this.font(font);
    g.fillStyle = color;
    g.textAlign = align;
    g.textBaseline = 'middle';
    g.fillText(s, x * this.k, cy * this.k);
  }

  private width(s: string, font: Font) {
    this.ctx.font = this.font(font);
    return this.ctx.measureText(s).width / this.k;
  }

  /** 數字逐字排列並加字距，同韌體 trackedText。 */
  private tracked(s: string, cx: number, cy: number, font: Font, tracking: number, color: string) {
    const chars = [...s];
    const total = chars.reduce((w, ch, i) => w + this.width(ch, font) + (i + 1 < chars.length ? tracking : 0), 0);
    let x = cx - total / 2;
    for (const ch of chars) {
      this.text(ch, x, cy, font, color, 'left');
      x += this.width(ch, font) + tracking;
    }
  }

  /** 同韌體 balancedWrap：斷成同樣行數下最窄的寬度，各行長度接近。 */
  private wrap(s: string, width: number, font: Font) {
    const tokens = s.match(/[A-Za-z0-9-]+|./gu) ?? [];
    const lines = (w: number) => {
      const out: string[] = [];
      let line = '';
      for (const tk of tokens) {
        if (line && this.width(line + tk, font) > w) { out.push(line.trim()); line = tk.trim() ? tk : ''; } else line += tk;
      }
      if (line) out.push(line.trim());
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

  /** 圓角矩形；stroke 為框線粗細（畫在範圍內），0 為填滿。 */
  private rect(x: number, y: number, w: number, h: number, r: number, color: string, stroke = 0) {
    const g = this.ctx, i = stroke / 2, k = this.k;
    g.beginPath();
    g.roundRect((x + i) * k, (y + i) * k, (w - stroke) * k, (h - stroke) * k, Math.max(0, r - i) * k);
    if (stroke) {
      g.lineWidth = stroke * k;
      g.strokeStyle = color;
      g.stroke();
    } else {
      g.fillStyle = color;
      g.fill();
    }
  }

  private disc(cx: number, cy: number, r: number, color: string) {
    const g = this.ctx;
    g.fillStyle = color;
    g.beginPath();
    g.arc(cx * this.k, cy * this.k, r * this.k, 0, Math.PI * 2);
    g.fill();
  }

  private line(x0: number, y0: number, x1: number, y1: number, w: number, color: string) {
    const g = this.ctx, k = this.k;
    g.strokeStyle = color;
    g.lineWidth = w * k;
    g.lineCap = 'round';
    g.beginPath();
    g.moveTo(x0 * k, y0 * k);
    g.lineTo(x1 * k, y1 * k);
    g.stroke();
  }

  /** 圓弧，from／to 為圈數比例，0 在正上方、順時針，兩端圓頭。 */
  private arc(cx: number, cy: number, r: number, w: number, from: number, to: number, color: string) {
    const g = this.ctx, turn = Math.PI * 2, k = this.k;
    g.strokeStyle = color;
    g.lineWidth = w * k;
    g.lineCap = 'round';
    g.beginPath();
    g.arc(cx * k, cy * k, r * k, -Math.PI / 2 + from * turn, -Math.PI / 2 + to * turn);
    g.stroke();
  }

  private shadowed(blur: number, dy: number, alpha: number, paint: () => void) {
    const g = this.ctx;
    g.save();
    g.shadowColor = `rgba(28, 42, 53, ${((alpha / 255) * 0.6).toFixed(3)})`;
    g.shadowBlur = blur * this.k;
    g.shadowOffsetY = dy * this.k;
    paint();
    g.restore();
  }

  private widget(x: number, y: number, w: number, h: number, fill: string, shadow = 26) {
    this.shadowed(12, 4, shadow, () => this.rect(x, y, w, h, WR, fill));
  }

  private capsule(x: number, y: number, w: number, h: number, ratio: number, color: string) {
    this.rect(x, y, w, h, h / 2, K.track);
    const filled = Math.round(w * clamp01(ratio));
    if (filled > 0) this.rect(x, y, Math.max(filled, h), h, h / 2, color);
  }

  private phone(cx: number, cy: number, color: string) {
    this.rect(cx - 9, cy - 14, 18, 28, 4, color, 2.5);
    this.line(cx - 3, cy + 8, cx + 3, cy + 8, 2.5, color);
  }

  private check(cx: number, cy: number, progress: number, color: string) {
    const x0 = cx - 11, y0 = cy + 1, x1 = cx - 3.5, y1 = cy + 8.5, x2 = cx + 11.5, y2 = cy - 7.5;
    const l1 = Math.hypot(x1 - x0, y1 - y0), l2 = Math.hypot(x2 - x1, y2 - y1), len = (l1 + l2) * clamp01(progress);
    if (len <= 0) return;
    const g = this.ctx, k = this.k;
    g.strokeStyle = color;
    g.lineWidth = 4 * k;
    g.lineCap = 'round';
    g.lineJoin = 'round';
    g.beginPath();
    g.moveTo(x0 * k, y0 * k);
    const k1 = Math.min(1, len / l1);
    g.lineTo((x0 + (x1 - x0) * k1) * k, (y0 + (y1 - y0) * k1) * k);
    if (len > l1) {
      const k2 = (len - l1) / l2;
      g.lineTo((x1 + (x2 - x1) * k2) * k, (y1 + (y2 - y1) * k2) * k);
    }
    g.stroke();
  }

  /** iOS 樣式的轉圈：12 根輻條依序變亮，每秒一圈。 */
  private spinner(cx: number, cy: number, head: number) {
    for (let i = 0; i < 12; i++) {
      const age = (head - i + 12) % 12, a = (i / 12) * Math.PI * 2, sx = Math.sin(a), sy = -Math.cos(a);
      this.line(cx + sx * 8, cy + sy * 8, cx + sx * 16, cy + sy * 16, 3.4, `rgba(77, 98, 111, ${((255 - age * 18) / 255).toFixed(3)})`);
    }
  }

  /** 動態島：標誌、名稱與時間（沒有時間時同韌體只放標誌與名稱）。 */
  private island(title: string, clock: string) {
    const padL = 12, padR = 14, logoGap = 7, clockGap = 18, cy = 20;
    const logoW = this.logo ? this.logo.width / this.k : 0;
    const left = padL + (logoW ? logoW + logoGap : 0);
    const clockW = clock ? this.width(clock, F.title) : 0;
    const w = left + this.width(title, F.title) + (clockW ? clockGap + clockW : 0) + padR;
    const x = (320 - w) / 2;
    this.rect(x, 6, w, 28, 14, K.island);
    if (this.logo) this.ctx.drawImage(this.logo, (x + padL) * this.k, (cy - 8) * this.k);
    this.text(title, x + left, cy, F.title, K.card, 'left');
    if (clockW) this.text(clock, x + w - padR, cy, F.title, K.islandMuted, 'right');
  }

  /** 計時畫面上方的說明（最多兩行，靠左）；回傳下方卡片的上緣。 */
  private headline(s: string) {
    const lines = this.wrap(s, 320 - 2 * TEXT_X, F.head).slice(0, 2), y = TOP + 2;
    lines.forEach((l, i) => this.text(l, TEXT_X, y + HEAD_LH / 2 + i * HEAD_LH, F.head, K.text, 'left'));
    return y + lines.length * HEAD_LH + 10;
  }

  /** 右側倒數：白色卡片中的圓環與秒數。 */
  private ring(x: number, y: number, w: number, h: number, seconds: number, total: number) {
    const ratio = clamp01(seconds / total), cx = x + w / 2, cy = y + h / 2, r = Math.min(35, Math.min(w, h) / 2 - 14);
    this.widget(x, y, w, h, K.card);
    this.arc(cx, cy, r, 7, 0, 1, K.track);
    if (ratio > 0) this.arc(cx, cy, r, 7, 0, ratio, ratio < 0.2 ? K.warn : K.primary);
    this.text(String(seconds), cx, cy - 5, seconds >= 100 ? F.labelSm : F.ring, K.text);
    this.text('秒', cx, cy + 18, F.small, K.muted);
  }

  draw(p: KioskParams) {
    this.onPop?.(p.pop ?? null);
    const head = p.state === 'opening' && p.tick !== undefined ? Math.floor((p.tick * 1000) / 83) % 12 : 0;
    const sig = `${p.state}|${p.refresh.toFixed(3)}|${p.seconds}|${p.digits.toFixed(2)}|${p.check.toFixed(2)}|${p.take ? 1 : 0}|${p.header ?? ''}|${p.qr ?? 0}|${(p.flash ?? 0).toFixed(2)}|${p.code ?? ''}|${p.total ?? 0}|${p.clock ?? ''}|${head}`;
    if (sig === this.last) return;
    this.last = sig;
    const g = this.ctx;
    const bg = g.createLinearGradient(0, 0, 0, this.canvas.height);
    bg.addColorStop(0, K.bgTop);
    bg.addColorStop(1, K.bgBottom);
    g.fillStyle = bg;
    g.fillRect(0, 0, this.canvas.width, this.canvas.height);
    this.island(p.header ?? TITLE, p.clock ?? '');
    const ringX = 320 - M - RING_W, total = RING_TOTAL[p.state] ?? 60;

    if (p.state === 'qr') {
      // QR Code 在左側白色卡片，右側為 App 圖示、說明與更新進度
      const qr = this.qrOf(p.qr ?? 0), n = qr.length;
      let scale = 4;
      while (scale > 3 && (n + 8) * scale > QR_BOX) scale--;
      const side = (n + 8) * scale, box = Math.max(QR_BOX, side), qx = 10, qy = TOP - 2 + (240 - 6 - (TOP - 2) - box) / 2;
      this.widget(qx, qy, box, box, K.card, 30);
      const ox = qx + (box - side) / 2 + 4 * scale, oy = qy + (box - side) / 2 + 4 * scale;
      g.fillStyle = K.text;
      for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) if (qr[r][c]) g.fillRect((ox + c * scale) * this.k, (oy + r * scale) * this.k, scale * this.k, scale * this.k);
      if ((p.flash ?? 0) > 0.005) {
        // 換碼瞬間：QR Code 卡片閃白後顯示新的一組
        g.globalAlpha = Math.min(1, p.flash ?? 0);
        this.rect(qx, qy, box, box, WR, K.card);
        g.globalAlpha = 1;
      }
      const left = qx + box + 12, width = 320 - 10 - left, lh = 26;
      const lines = this.wrap('請使用 SaveMyBook App 掃描', width, F.head);
      let y = qy + box / 2 - (40 + 14 + lines.length * lh + 22) / 2;
      this.rect(left, y, 40, 40, 12, K.primary);
      this.phone(left + 20, y + 20, K.card);
      y += 54;
      lines.forEach((l, i) => this.text(l, left, y + lh / 2 + i * lh, F.head, K.text, 'left'));
      y += lines.length * lh;
      const remain = 1 - p.refresh;
      this.capsule(left, y + 16, Math.min(width, 118), 6, remain, remain < 0.2 ? K.warn : K.primary);
    } else if (p.state === 'busy') {
      // 霧藍卡片放圖示與說明，右側倒數
      const y = TOP + 2, h = BOTTOM - y, w = MATCH_W;
      this.widget(M, y, w, h, K.primary, 34);
      this.disc(M + 38, y + 38, 20, K.card);
      this.phone(M + 38, y + 38, K.primary);
      const ty = y + h - 18 - 21 - HEAD_LH - 4;
      this.text('書櫃使用中', M + 18, ty + HEAD_LH / 2, F.head, K.card, 'left');
      this.text('請於手機確認項目', M + 18, ty + HEAD_LH + 4 + 10.5, F.body, K.onPrimary, 'left');
      this.ring(ringX, y, RING_W, h, p.seconds, total);
    } else if (p.state === 'match') {
      const y = this.headline('請於手機輸入下列數字'), h = BOTTOM - y;
      this.widget(M, y, MATCH_W, h, K.primary, 34);
      g.globalAlpha = clamp01(p.digits);
      this.tracked('25', M + MATCH_W / 2, y + h / 2 + 2, F.huge, 10, K.card);
      g.globalAlpha = 1;
      this.ring(ringX, y, RING_W, h, p.seconds, total);
    } else if (p.state === 'pair') {
      // 同韌體 drawPairing 與 messages.h（PAIRING_TITLE／PAIRING_PROMPT／PAIRING_REMAINING）：8 碼等距一列，不分組、不加短線
      const y = TOP + 2, h = 108, w = 320 - 2 * M, s = Math.max(0, p.seconds), ratio = clamp01(s / (p.total ?? 600));
      this.widget(M, y, w, h, K.primary, 34);
      this.text('配對碼', M + 18, y + 22, F.title, K.pairLabel, 'left');
      this.tracked((p.code ?? '0151-7752').replace(/\D/g, ''), M + w / 2, y + 66, F.label, 9, K.card);
      this.text('請於管理後台輸入此配對碼', TEXT_X, y + h + 26, F.head, K.text, 'left');
      const remain = `剩餘時間 ${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
      const tw = this.width(remain, F.body), barY = BOTTOM - 10;
      this.capsule(TEXT_X, barY - 3, 320 - 2 * TEXT_X - tw - 14, 6, ratio, ratio < 0.2 ? K.warn : K.primary);
      this.text(remain, 320 - TEXT_X, barY, F.body, K.muted, 'right');
    } else if (p.state === 'open') {
      // 櫃門編號在霧藍卡片左側，右側書櫃示意亮起開啟的櫃門（A01–A04 由上而下）
      const y = this.headline(p.take ? '請取出 A01 內的書籍後關上櫃門' : '請將書籍放入 A01 後關上櫃門'), h = BOTTOM - y, w = MATCH_W;
      this.widget(M, y, w, h, K.primary, 34);
      const mx = M + w - 16 - 36, my = y + (h - 62) / 2;
      this.rect(mx, my, 36, 62, 7, K.mapFrame, 1.5);
      for (let i = 0; i < 4; i++) this.rect(mx + 5, my + 5 + i * 14, 26, 10, 3, i === 0 ? K.card : K.mapSlot);
      this.text('A01', M + 18, y + h / 2, F.label, K.card, 'left');
      this.ring(ringX, y, RING_W, h, p.seconds, total);
    } else if (p.state === 'opening') {
      const y = TOP - 2 + (240 - 6 - (TOP - 2) - (60 + 16 + HEAD_LH)) / 2;
      this.shadowed(10, 3, 22, () => this.disc(160, y + 30, 30, K.card));
      this.spinner(160, y + 30, head);
      this.text('櫃門開啟中', 160, y + 60 + 16 + HEAD_LH / 2, F.head, K.text);
    } else {
      // 結果圖示：實心圓加淡色光暈，彈性放大後畫出勾勾；p.check 對應進場動畫的時間
      const y = TOP - 2 + (240 - 6 - (TOP - 2) - (64 + 16 + HEAD_LH)) / 2, cy = y + 32, t = p.check * ENTER;
      const scale = easeOutBack(t / BADGE_IN);
      if (scale > 0) {
        this.disc(160, cy, 40 * scale, K.successHalo);
        this.disc(160, cy, 30 * scale, K.success);
        this.check(160, cy, easeOutCubic((t - CHECK_DELAY) / CHECK_MS), K.card);
      }
      this.text('作業完成', 160, y + 64 + 16 + HEAD_LH / 2, F.head, K.text);
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
  g.font = '700 30px "Noto Sans TC", sans-serif';
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
