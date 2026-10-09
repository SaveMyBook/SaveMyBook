import * as THREE from 'three';
import { Stage, CAM_Z } from './stage';
import { Phone } from './three/phone';
import { Cabinet } from './three/cabinet';
import { parcel } from './three/props';
import { screenTexture, screenSpan, releaseScreen, cutTexture, releaseCut, type KioskParams } from './three/textures';
import type { Pose } from './lib/kf';

/** 手機螢幕：a 為目前畫面，b 為轉場中的下一個畫面；mode 見 phone.ts 的轉場說明；off 為長截圖的捲動量（以螢幕高為 1）。 */
export interface Scr { a: string | null; b?: string | null; k?: number; mode?: number; offA?: number; offB?: number }

/** 浮出元件：把螢幕上 rect 區塊（取自 screen 畫面）抬離螢幕，k 為 0～1。 */
/**
 * 浮出元件：把螢幕上 rect 區塊（取自 screen 畫面）抬離螢幕，k 為 0～1。
 * 第二版改用 cut：截圖工具單獨輸出的去背元件（public/v2/cuts），位置與圓角取自 cuts.json，不需要 screen 與 rect。
 */
export interface Pop { id: string; screen?: string; cut?: string; rect?: { x: number; y: number; w: number; h: number; r?: number }; k: number; grow?: number; dx?: number; dy?: number; dz?: number }

type CutRect = { screen: string; x: number; y: number; w: number; h: number; r?: number };
/** 去背元件在所屬畫面上的位置（App 邏輯座標），由截圖工具輸出。 */
export const CUTS: Record<string, CutRect> = {};
/** 要點擊的按鈕在所屬畫面上的位置（App 邏輯座標），由截圖工具輸出。 */
export const TAPS: Record<string, CutRect> = {};
/** 逐字輸入等連續畫面的名稱清單（截圖工具輸出），場景在播放時才讀。 */
export const SEQS: Record<string, string[]> = {};
const CUT = 'cut:';

export interface PhoneState {
  pose: Pose;
  scr: Scr;
  glow?: number;
  pops?: Pop[];
}

/** 每格由各場景寫入、最後統一套用到 3D 物件的狀態。 */
export interface Frame {
  phones: (PhoneState | null)[];
  cabinet: { pose: Pose; kiosk: KioskParams; door?: number; deposit?: number; withdraw?: number; xray?: number } | null;
  parcel: Pose | null;
  /** 鏡頭位移（世界單位）。 */
  cam: { x: number; y: number; z: number };
  /** 需要 3D 物件最終位置的 DOM 更新（標註、點擊、標示框），在套用 3D 之後執行。 */
  after: (() => void)[];
}

/** 手機編號：0 賣家（侖娥）、1 買家（海嫄）、2 管理員。 */
export const SELLER = 0;
export const BUYER = 1;
export const ADMIN = 2;
/** 品牌段背景環繞展示用的手機（編號 3 起）。 */
export const RING = [3, 4, 5, 6, 7, 8];
const PHONES = 3 + RING.length;

/** 捲動時固定不動的頂端高度（App 邏輯座標，含狀態列與標題列）。 */
const HEAD: Record<string, number> = { b_guide_long: 112 };

export class World {
  readonly phones = Array.from({ length: PHONES }, () => new Phone());
  readonly cabinet = new Cabinet('新北高工');
  readonly box = parcel();
  private textures = new Map<string, THREE.Texture>();
  /** 各畫面最後一次被用到的時間（秒），用來釋放久未使用的材質。 */
  private lastUse = new Map<string, number>();
  private loading = new Map<string, Promise<void>>();
  private missing = new Set<string>();
  frame!: Frame;

  constructor(readonly stage: Stage, private screens: string[]) {
    for (const p of this.phones) stage.scene.add(p.group);
    stage.scene.add(this.cabinet.group, this.box);
  }

  async load() {
    await document.fonts.ready;
    for (const [file, into] of [['/v2/cuts.json', CUTS], ['/v2/taps.json', TAPS], ['/v2/sequences.json', SEQS]] as const) {
      try {
        const r = await fetch(file);
        if (r.ok) Object.assign(into, await r.json());
      } catch {
        // 尚未產生第二版截圖
      }
    }
  }

  /**
   * 畫面材質按需載入：每張 4K 畫面約占 16MB 顯示記憶體，全部常駐時算圖分頁會當掉。
   * ensure 載入這一格用到的畫面，並釋放 KEEP 秒內沒用到的畫面。
   */
  async ensure(names: Iterable<string>, t: number) {
    const KEEP = 6;
    const want = [...names];
    for (const n of want) this.lastUse.set(n, t);
    await Promise.all(want.map((n) => this.loadOne(n)));
    for (const [n, last] of this.lastUse) {
      if (Math.abs(t - last) > KEEP && this.textures.has(n)) {
        this.textures.delete(n);
        this.lastUse.delete(n);
        if (n.startsWith(CUT)) releaseCut(n.slice(CUT.length));
        else releaseScreen(n, false);
      }
    }
  }

  private loadOne(n: string) {
    if (this.textures.has(n)) return Promise.resolve();
    if (!this.loading.has(n)) {
      this.loading.set(n, (async () => {
        try {
          const tex = n.startsWith(CUT) ? await cutTexture(n.slice(CUT.length)) : await screenTexture(n, false);
          this.stage.renderer.initTexture(tex);
          this.textures.set(n, tex);
        } catch {
          console.error(n.startsWith(CUT) ? `缺少去背元件：${n.slice(CUT.length)}` : `缺少 App 畫面：${n}`);
        } finally {
          this.loading.delete(n);
        }
      })());
    }
    return this.loading.get(n)!;
  }

  /** 上一次 apply 時用到、但材質尚未載入的畫面。 */
  takeMissing() {
    const m = [...this.missing];
    this.missing.clear();
    return m;
  }

  /** 上一次 apply 時用到的畫面（含已載入者），供 ensure 更新使用時間。 */
  used = new Set<string>();

  tex(name: string | null | undefined) {
    if (!name) return null;
    this.used.add(name);
    const t = this.textures.get(name);
    if (!t) this.missing.add(name);
    return t ?? null;
  }

  reset() {
    this.frame = { phones: Array(PHONES).fill(null), cabinet: null, parcel: null, cam: { x: 0, y: 0, z: 0 }, after: [] };
    this.used.clear();
  }

  private place(obj: THREE.Object3D, p: Pose) {
    obj.position.set((p.x ?? 0) * this.stage.halfW, (p.y ?? 0) * this.stage.halfH, p.z ?? 0);
    obj.rotation.set(p.rx ?? 0, p.ry ?? 0, p.rz ?? 0);
    obj.scale.setScalar(p.s ?? 1);
  }

  /** 物件（或其上的點）在畫面上的像素位置；需在 apply 之後呼叫。 */
  project(obj: THREE.Object3D, local?: THREE.Vector3) {
    obj.updateWorldMatrix(true, false);
    const v = local ? obj.localToWorld(local.clone()) : obj.getWorldPosition(new THREE.Vector3());
    return this.stage.toScreen(v);
  }

  /** 手機螢幕上的點（App 邏輯座標）在畫面上的像素位置。 */
  point(phone: number, x: number, y: number) {
    const p = this.phones[phone];
    p.body.updateMatrixWorld(true);
    return this.stage.toScreen(p.screenPoint(x, y));
  }

  /** 手機邊緣上的點：u、v 為 -1～1（左右、下上），用於標籤與通知的位置。 */
  edge(phone: number, u: number, v: number) {
    const p = this.phones[phone];
    p.body.updateMatrixWorld(true);
    return this.stage.toScreen(p.body.localToWorld(new THREE.Vector3(u * 7.15 / 2, v * 14.96 / 2, 0.45)));
  }

  /** 套用到 3D 物件。t 用於漂浮的微幅擺動。 */
  apply(t: number) {
    const f = this.frame;
    const cam = this.stage.camera;
    cam.position.set(Math.sin(t * 0.21) * 0.6 + f.cam.x, Math.cos(t * 0.17) * 0.4 + f.cam.y, CAM_Z + f.cam.z);
    cam.lookAt(f.cam.x * 0.6, f.cam.y * 0.6, 0);

    this.phones.forEach((phone, i) => {
      const st = f.phones[i];
      phone.group.visible = !!st;
      if (!st) { for (const card of phone.pops.values()) card.set(0); return; }
      this.place(phone.group, st.pose);
      // 放大特寫時減少漂浮，避免文字晃動
      const calm = Math.min(1, Math.max(0, ((st.pose.s ?? 1) - 1.3) / 0.6));
      const amp = 1 - 0.8 * calm;
      phone.body.rotation.set(Math.sin(t * 0.7 + i) * 0.012 * amp, Math.sin(t * 0.43 + i * 2) * 0.02 * amp, Math.sin(t * 0.55 + i) * 0.008 * amp);
      phone.body.position.y = Math.sin(t * 0.9 + i * 1.3) * 0.12 * amp;
      const s = st.scr;
      const head = (n: string | null | undefined) => (n && HEAD[n] ? HEAD[n] / 852 : 0);
      phone.setScreens(this.tex(s.a), this.tex(s.b), s.k ?? 0, {
        mode: s.mode ?? 0,
        spanA: (s.a && screenSpan.get(s.a)) || 1,
        spanB: (s.b && screenSpan.get(s.b)) || 1,
        offA: s.offA ?? 0,
        offB: s.offB ?? 0,
        headA: head(s.a),
        headB: head(s.b),
      });
      phone.setGlow(st.glow ?? 1);
      const live = new Set<string>();
      // 鏡頭在手機本體座標中的位置：浮出元件沿視線抬起，畫面上才會留在原位（第二版去背元件使用）
      phone.body.updateMatrixWorld(true);
      const eye = phone.body.worldToLocal(cam.position.clone());
      for (const pp of st.pops ?? []) {
        const rect = pp.cut ? CUTS[pp.cut] : pp.rect;
        if (!rect) { console.error(`去背元件沒有座標：${pp.cut}`); continue; }
        const card = phone.pops.get(pp.id) ?? phone.addPop(pp.id, rect, !!pp.cut);
        card.setTexture(pp.cut ? this.tex(CUT + pp.cut) : this.tex(pp.screen));
        card.set(pp.k, pp.grow, pp.dy, pp.dz, pp.cut ? eye : undefined, pp.dx);
        live.add(pp.id);
      }
      for (const [id, card] of phone.pops) if (!live.has(id)) card.set(0);
    });

    this.box.visible = !!f.parcel;
    if (f.parcel) this.place(this.box, f.parcel);

    this.cabinet.group.visible = !!f.cabinet;
    if (f.cabinet) {
      this.place(this.cabinet.group, f.cabinet.pose);
      this.cabinet.kiosk.draw(f.cabinet.kiosk);
      this.cabinet.setDoor(0, f.cabinet.door ?? 0);
      this.cabinet.setDeposit(f.cabinet.deposit ?? 0, f.cabinet.withdraw ?? 0);
      this.cabinet.setXray(f.cabinet.xray ?? 0);
    }
  }
}
