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

/* ---------------- 書櫃螢幕（橫向 320 × 240，版面同韌體 ui.cpp 的亮色畫面，以兩倍解析度繪製） ---------------- */

export type KioskState = 'qr' | 'busy' | 'match' | 'opening' | 'open' | 'done';
export interface KioskParams {
  state: KioskState; refresh: number; seconds: number; digits: number; check: number; take?: boolean;
  /** 比對數字，預設為 25。 */
  digitsText?: string;
}

// 韌體 pal 色票；淡色依韌體 mix() 先算好
const K = {
  bgTop: '#DFE7EC', bgBottom: '#F3F5F7', island: '#151E27', islandMuted: '#A9B6BF', primary: '#627D8D', primaryLight: '#B9C7CF',
  card: '#FFFFFF', text: '#151E27', muted: '#5F6673', track: '#E6EAED', success: '#2E9E5B', successHalo: '#E3F2E9', warn: '#D98613',
  onPrimary: '#EDF0F2', mapFrame: '#99ABB5', mapSlot: '#879CA8',
};
const KS = 2;
const TITLE = '救「舊」我的書';
const TOP = 44, BOTTOM = 228, M = 12, GAP = 10, RING_W = 100, WR = 22, TEXT_X = 16, HEAD_LH = 28, QR_BOX = 164;
const MATCH_Y = TOP + 2 + HEAD_LH + 10, MATCH_W = 320 - 2 * M - GAP - RING_W;
const RING_TOTAL: Partial<Record<KioskState, number>> = { busy: 60, match: 60, open: 30 };
const BADGE_IN = 420, CHECK_DELAY = 160, CHECK_MS = 340, ENTER = CHECK_DELAY + CHECK_MS + 60;
const kfont = (px: number, medium = false) => `${medium ? 500 : 400} ${px * KS}px "Noto Sans TC", sans-serif`;
const F = {
  small: kfont(13), body: kfont(15), title: kfont(16, true), head: kfont(20, true),
  label: kfont(44, true), labelSm: kfont(28, true), ring: kfont(34, true), huge: kfont(96, true),
};
const clamp01 = (t: number) => Math.max(0, Math.min(1, t));
const easeOutCubic = (t: number) => 1 - (1 - clamp01(t)) ** 3;
const easeOutBack = (t: number) => { const u = clamp01(t) - 1; return 1 + 2.4 * u ** 3 + 1.4 * u ** 2; };
const clockFormat = new Intl.DateTimeFormat('en-GB', { timeZone: 'Asia/Taipei', hour: '2-digit', minute: '2-digit', hour12: false });

/** 頁首標誌：裁去透明邊後縮成高 16，以淺霧藍上色（同韌體 make_logo.py 與 island()）。 */
function islandLogo(img: HTMLImageElement) {
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
  out.height = 16 * KS;
  out.width = Math.round(((x1 - x0 + 1) * out.height) / (y1 - y0 + 1));
  const g = out.getContext('2d')!;
  g.drawImage(src, x0, y0, x1 - x0 + 1, y1 - y0 + 1, 0, 0, out.width, out.height);
  g.globalCompositeOperation = 'source-in';
  g.fillStyle = K.primaryLight;
  g.fillRect(0, 0, out.width, out.height);
  return out;
}

export class Kiosk {
  /** 比對數字的字級（相對螢幕高）與兩字中心距的一半（相對螢幕寬；Noto Sans TC 數字等寬 0.57 em，字距 10）。 */
  static readonly DIGIT_EM = 96 / 240;
  static readonly DIGIT_GAP = (96 * 0.57 + 10) / 2 / 320;
  readonly canvas = document.createElement('canvas');
  readonly texture: THREE.CanvasTexture;
  /** 數字在螢幕上的中心（0–1），供飛行動畫對位。 */
  readonly digitsAt = { x: (M + MATCH_W / 2) / 320, y: (MATCH_Y + (BOTTOM - MATCH_Y) / 2 + 2) / 240 };
  private ctx: CanvasRenderingContext2D;
  private qr: boolean[][];
  private logo: HTMLCanvasElement | null = null;
  private params: KioskParams | null = null;
  private last = '';

  constructor() {
    this.canvas.width = 320 * KS;
    this.canvas.height = 240 * KS;
    this.ctx = this.canvas.getContext('2d')!;
    // 版本 4（33 格）加 4 格靜區、每格 4 像素，正好填滿 164 的卡片，與實機 QR Code 的密度相同
    const q = qrcode(4, 'M');
    q.addData('NMIXX HAEWON 0225');
    q.make();
    const n = q.getModuleCount();
    this.qr = Array.from({ length: n }, (_, r) => Array.from({ length: n }, (_, c) => q.isDark(r, c)));
    this.texture = canvasTexture(this.canvas);
    loadImage('/brand/book-slate-128.png').then((img) => { this.logo = islandLogo(img); this.redraw(); }).catch(() => { /* 沒有標誌時只顯示文字 */ });
    // 畫布不會等字型，字型晚到時要重畫一次
    Promise.all([F.title, F.head, F.huge].map((f) => document.fonts.load(f, `${TITLE}請使用掃描 0123456789`))).then(() => this.redraw()).catch(() => {});
  }

  private redraw() {
    this.last = '';
    if (this.params) this.draw(this.params);
  }

  private text(s: string, x: number, cy: number, font: string, color: string, align: CanvasTextAlign = 'center') {
    const g = this.ctx;
    g.font = font;
    g.fillStyle = color;
    g.textAlign = align;
    g.textBaseline = 'middle';
    g.fillText(s, x * KS, cy * KS);
  }

  private width(s: string, font: string) {
    this.ctx.font = font;
    return this.ctx.measureText(s).width / KS;
  }

  /** 數字逐字排列並加字距，同韌體 trackedText。 */
  private tracked(s: string, cx: number, cy: number, font: string, tracking: number, color: string) {
    const chars = [...s];
    const total = chars.reduce((w, ch, i) => w + this.width(ch, font) + (i + 1 < chars.length ? tracking : 0), 0);
    let x = cx - total / 2;
    for (const ch of chars) {
      this.text(ch, x, cy, font, color, 'left');
      x += this.width(ch, font) + tracking;
    }
  }

  /** 同韌體 balancedWrap：斷成同樣行數下最窄的寬度，各行長度接近。 */
  private wrap(s: string, width: number, font: string) {
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
    const g = this.ctx, i = stroke / 2;
    g.beginPath();
    g.roundRect((x + i) * KS, (y + i) * KS, (w - stroke) * KS, (h - stroke) * KS, Math.max(0, r - i) * KS);
    if (stroke) {
      g.lineWidth = stroke * KS;
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
    g.arc(cx * KS, cy * KS, r * KS, 0, Math.PI * 2);
    g.fill();
  }

  private line(x0: number, y0: number, x1: number, y1: number, w: number, color: string) {
    const g = this.ctx;
    g.strokeStyle = color;
    g.lineWidth = w * KS;
    g.lineCap = 'round';
    g.beginPath();
    g.moveTo(x0 * KS, y0 * KS);
    g.lineTo(x1 * KS, y1 * KS);
    g.stroke();
  }

  /** 圓弧，from／to 為圈數比例，0 在正上方、順時針，兩端圓頭。 */
  private arc(cx: number, cy: number, r: number, w: number, from: number, to: number, color: string) {
    const g = this.ctx, turn = Math.PI * 2;
    g.strokeStyle = color;
    g.lineWidth = w * KS;
    g.lineCap = 'round';
    g.beginPath();
    g.arc(cx * KS, cy * KS, r * KS, -Math.PI / 2 + from * turn, -Math.PI / 2 + to * turn);
    g.stroke();
  }

  private shadowed(blur: number, dy: number, alpha: number, paint: () => void) {
    const g = this.ctx;
    g.save();
    g.shadowColor = `rgba(28, 42, 53, ${((alpha / 255) * 0.6).toFixed(3)})`;
    g.shadowBlur = blur * KS;
    g.shadowOffsetY = dy * KS;
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
    const g = this.ctx;
    g.strokeStyle = color;
    g.lineWidth = 4 * KS;
    g.lineCap = 'round';
    g.lineJoin = 'round';
    g.beginPath();
    g.moveTo(x0 * KS, y0 * KS);
    const k1 = Math.min(1, len / l1);
    g.lineTo((x0 + (x1 - x0) * k1) * KS, (y0 + (y1 - y0) * k1) * KS);
    if (len > l1) {
      const k2 = (len - l1) / l2;
      g.lineTo((x1 + (x2 - x1) * k2) * KS, (y1 + (y2 - y1) * k2) * KS);
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

  private island(clock: string) {
    const padL = 12, padR = 14, logoGap = 7, clockGap = 18, cy = 20;
    const logoW = this.logo ? this.logo.width / KS : 0;
    const left = padL + (logoW ? logoW + logoGap : 0);
    const w = left + this.width(TITLE, F.title) + clockGap + this.width(clock, F.title) + padR;
    const x = (320 - w) / 2;
    this.rect(x, 6, w, 28, 14, K.island);
    if (this.logo) this.ctx.drawImage(this.logo, (x + padL) * KS, (cy - 8) * KS);
    this.text(TITLE, x + left, cy, F.title, K.card, 'left');
    this.text(clock, x + w - padR, cy, F.title, K.islandMuted, 'right');
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
    this.params = p;
    const clock = clockFormat.format(Date.now());
    const head = p.state === 'opening' ? Math.floor(performance.now() / 83) % 12 : 0;
    const sig = `${p.state}|${p.refresh.toFixed(2)}|${p.seconds}|${p.digits.toFixed(2)}|${p.check.toFixed(2)}|${p.take ? 1 : 0}|${p.digitsText ?? ''}|${clock}|${head}`;
    if (sig === this.last) return;
    this.last = sig;
    const g = this.ctx;
    const bg = g.createLinearGradient(0, 0, 0, this.canvas.height);
    bg.addColorStop(0, K.bgTop);
    bg.addColorStop(1, K.bgBottom);
    g.fillStyle = bg;
    g.fillRect(0, 0, this.canvas.width, this.canvas.height);
    this.island(clock);
    const ringX = 320 - M - RING_W, total = RING_TOTAL[p.state] ?? 60;

    if (p.state === 'qr') {
      // QR Code 在左側白色卡片，右側為 App 圖示、說明與更新進度
      const n = this.qr.length;
      let scale = 4;
      while (scale > 3 && (n + 8) * scale > QR_BOX) scale--;
      const side = (n + 8) * scale, box = Math.max(QR_BOX, side), qx = 10, qy = TOP - 2 + (240 - 6 - (TOP - 2) - box) / 2;
      this.widget(qx, qy, box, box, K.card, 30);
      const ox = qx + (box - side) / 2 + 4 * scale, oy = qy + (box - side) / 2 + 4 * scale;
      g.fillStyle = K.text;
      for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) if (this.qr[r][c]) g.fillRect((ox + c * scale) * KS, (oy + r * scale) * KS, scale * KS, scale * KS);
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
      this.tracked(p.digitsText ?? '25', M + MATCH_W / 2, y + h / 2 + 2, F.huge, 10, K.card);
      g.globalAlpha = 1;
      this.ring(ringX, y, RING_W, h, p.seconds, total);
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
