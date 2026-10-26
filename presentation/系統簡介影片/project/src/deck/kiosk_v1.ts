import * as THREE from 'three';
import qrcode from 'qrcode-generator';
import type { KioskParams, KioskPop, KioskSurface } from '../three/textures';

/**
 * 舊版（深色）書櫃螢幕，只給簡報素材（src/deck.ts）使用：複評簡報的書櫃圖與動畫維持原樣。
 * 影片與網站的書櫃螢幕已改為韌體的亮色畫面（three/textures.ts 的 Kiosk）。
 */
function canvasTexture(canvas: HTMLCanvasElement) {
  const tex = new THREE.CanvasTexture(canvas);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 16;
  return tex;
}

const K = {
  bg: '#0E1318', header: '#18212A', text: '#EEF2F5', muted: '#93A2AD', track: '#2A3540', online: '#3CCF8E', accent: '#46B59C',
};

export class KioskV1 implements KioskSurface {
  readonly canvas = document.createElement('canvas');
  readonly texture: THREE.CanvasTexture;
  private ctx: CanvasRenderingContext2D;
  private qrs = new Map<number, boolean[][]>();
  private last = '';
  /** 每個韌體像素畫成幾個材質像素。 */
  private k = 2;
  /** 由 Cabinet 接上：每次 draw 都回報螢幕浮出狀態。 */
  onPop: ((pop: KioskPop | null) => void) | null = null;

  /** name：頂列顯示的書櫃名稱。 */
  constructor(readonly name: string) {
    this.canvas.width = 320 * this.k;
    this.canvas.height = 240 * this.k;
    this.ctx = this.canvas.getContext('2d')!;
    this.texture = canvasTexture(this.canvas);
  }

  /** 螢幕放大浮出時改用較高解析度（4K 成品中浮出的螢幕寬約 1000 像素）；改變大小後材質需重新上傳。 */
  setScale(k: number) {
    if (k === this.k) return;
    this.k = k;
    this.canvas.width = 320 * k;
    this.canvas.height = 240 * k;
    this.last = '';
    this.texture.dispose();
    this.texture.needsUpdate = true;
  }

  private font(px: number, medium = false) {
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

  /** 數字在螢幕上的中心（0–1），供飛行動畫對位。 */
  readonly digitsAt = { x: 0.5, y: 126 / 240 };

  private text(s: string, x: number, y: number, font: string, color: string, align: CanvasTextAlign = 'center') {
    const g = this.ctx;
    g.font = font;
    g.fillStyle = color;
    g.textAlign = align;
    g.textBaseline = 'middle';
    g.fillText(s, x * this.k, y * this.k);
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
        if (line && g.measureText(line + tk).width > w * this.k) { out.push(line); line = tk.trim() ? tk : ''; } else line += tk;
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
    g.fillRect(x * this.k, y * this.k, w * this.k, 4 * this.k);
    g.fillStyle = K.accent;
    g.fillRect(x * this.k, y * this.k, w * this.k * Math.max(0, Math.min(1, ratio)), 4 * this.k);
  }

  draw(p: KioskParams) {
    this.onPop?.(p.pop ?? null);
    const sig = `${p.state}|${p.refresh.toFixed(3)}|${p.seconds}|${p.digits.toFixed(2)}|${p.check.toFixed(2)}|${p.take ? 1 : 0}|${p.header ?? ''}|${p.qr ?? 0}|${(p.flash ?? 0).toFixed(2)}|${p.code ?? ''}|${p.total ?? 0}|${p.clock ?? ''}`;
    if (sig === this.last) return;
    this.last = sig;
    const g = this.ctx;
    g.fillStyle = K.bg;
    g.fillRect(0, 0, this.canvas.width, this.canvas.height);
    g.fillStyle = K.header;
    g.fillRect(0, 0, 320 * this.k, 28 * this.k);
    this.text(p.header ?? (p.state === 'pair' ? '智慧書櫃' : this.name), 10, 14, this.font(16, true), K.text, 'left');
    if (p.clock) {
      this.text(p.clock, 320 - 10, 14, this.font(16, true), K.text, 'right');
    } else {
      g.fillStyle = K.online;
      g.beginPath();
      g.arc((320 - 14) * this.k, 14 * this.k, 4 * this.k, 0, Math.PI * 2);
      g.fill();
    }

    if (p.state === 'qr') {
      // QR Code 在左（版本 4 含靜區 41 格、每格 4 像素），說明在右
      const side = 164, qx = 16, qy = 40;
      g.fillStyle = '#FFFFFF';
      g.fillRect(qx * this.k, qy * this.k, side * this.k, side * this.k);
      const qr = this.qrOf(p.qr ?? 0);
      const n = qr.length, cell = (side - 32) / n;
      g.fillStyle = '#0E1318';
      for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) if (qr[r][c]) g.fillRect((qx + 16 + c * cell) * this.k, (qy + 16 + r * cell) * this.k, cell * this.k + 0.6, cell * this.k + 0.6);
      if ((p.flash ?? 0) > 0.005) {
        // 換碼瞬間：QR Code 區塊閃白後顯示新的一組
        g.globalAlpha = Math.min(1, p.flash ?? 0);
        g.fillStyle = '#FFFFFF';
        g.fillRect(qx * this.k, qy * this.k, side * this.k, side * this.k);
        g.globalAlpha = 1;
      }
      this.bar(qx, qy + side + 8, side, 1 - p.refresh);
      const left = qx + side + 12, width = 320 - 8 - left, cx = left + width / 2;
      const lines = this.wrap('請使用 SaveMyBook App 掃描', width, this.font(15));
      let y = qy + side / 2 - (lines.length * 24) / 2 + 12;
      for (const l of lines) { this.text(l, cx, y, this.font(15), K.text); y += 24; }
    } else if (p.state === 'busy') {
      this.text('書櫃使用中', 160, 84, this.font(16, true), K.text);
      this.text('請於手機確認項目', 160, 118, this.font(15), K.text);
      this.text(`剩餘 ${p.seconds} 秒`, 160, 154, this.font(13), K.muted);
      this.bar(40, 174, 240, p.seconds / 60);
    } else if (p.state === 'match') {
      this.text('請於手機輸入下列數字', 160, 56, this.font(16, true), K.text);
      g.globalAlpha = p.digits;
      this.text('25', 160, 126, this.font(96, true), K.text);
      g.globalAlpha = 1;
      this.text(`剩餘 ${p.seconds} 秒`, 160, 194, this.font(13), K.muted);
      this.bar(40, 214, 240, p.seconds / 60);
    } else if (p.state === 'pair') {
      // 同韌體 ui.cpp drawPairing 與 messages.h（PAIRING_TITLE／PAIRING_PROMPT／PAIRING_REMAINING）
      const total = p.total ?? 600, s = Math.max(0, p.seconds);
      this.text('配對碼', 160, 60, this.font(16, true), K.muted);
      this.text(p.code ?? '0151-7752', 160, 100, this.font(38, true), K.text);
      this.text('請於管理後台輸入此配對碼', 160, 146, this.font(15), K.text);
      this.text(`剩餘時間 ${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`, 160, 172, this.font(13), K.muted);
      this.bar(40, 192, 240, s / total);
    } else if (p.state === 'opening') {
      this.text('櫃門開啟中', 160, (28 + 240) / 2, this.font(16, true), K.text);
    } else if (p.state === 'open') {
      // 櫃門編號與說明在左，倒數在右
      this.text('A01', 18, 66, this.font(44, true), K.text, 'left');
      const msg = p.take ? '請取出 A01 內的書籍後關上櫃門' : '請將書籍放入 A01 後關上櫃門';
      const lines = this.wrap(msg, 184, this.font(15));
      let y = 132 - (lines.length - 1) * 12;
      for (const l of lines) { this.text(l, 18, y, this.font(15), K.text, 'left'); y += 24; }
      const cx = 255 * this.k, cy = 131 * this.k, r = 44 * this.k;
      g.lineWidth = 5 * this.k;
      g.strokeStyle = K.track;
      g.beginPath();
      g.arc(cx, cy, r, 0, Math.PI * 2);
      g.stroke();
      g.strokeStyle = K.accent;
      g.lineCap = 'round';
      g.beginPath();
      g.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * (p.seconds / 30));
      g.stroke();
      this.text(String(p.seconds), 255, 131, this.font(34, true), K.text);
    } else {
      const cx = 160 * this.k, cy = 88 * this.k;
      g.strokeStyle = K.accent;
      g.lineWidth = 3 * this.k;
      g.beginPath();
      g.arc(cx, cy, 24 * this.k, 0, Math.PI * 2);
      g.stroke();
      g.lineCap = 'round';
      g.lineJoin = 'round';
      const t = p.check;
      g.beginPath();
      g.moveTo(cx - 10 * this.k, cy + 1 * this.k);
      const a = Math.min(1, t * 2);
      g.lineTo(cx + (-10 + 7 * a) * this.k, cy + (1 + 7 * a) * this.k);
      if (t > 0.5) {
        const b = (t - 0.5) * 2;
        g.lineTo(cx + (-3 + 14 * b) * this.k, cy + (8 - 15 * b) * this.k);
      }
      g.stroke();
      this.text('作業完成', 160, 146, this.font(16, true), K.text);
    }
    this.texture.needsUpdate = true;
  }
}
