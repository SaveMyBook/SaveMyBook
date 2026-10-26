import { cue, fly } from '../lib/cues';
import { SELLER, BUYER, ADMIN, type World } from '../world';
import type { KioskParams } from '../three/textures';
import { PHONE } from '../three/phone';
import type { Pose } from '../lib/kf';
import { line, section } from './kit2';
import { glide, soft } from './kit4';
import { onBeat } from './kit5';
import { TitleV3 } from '../v3/title';
import { LabelV3 } from '../v3/label';
import { CameraPath, orbit, sequence, sectionPans, type CamKey } from '../v3/camera';
import { fit } from '../v3/frame';
import { lift } from '../v3/pop';
import { DevBoardV3 } from './x_tech_v3';
import './tech_v3.css';

const SEC = 'tech';
/** 扇形排開的中間那支（品牌段環繞展示用的手機，本段借用） */
const FAN_MID = 3;

/**
 * v3 技術架構（旁白 24 四項技術、24b API 與測試數量）。規則見 DESIGN.md「v3 規則」。
 * - 24：App 手機在左、書櫃在右，鏡頭由略俯視慢慢升高。旁白念到 Flutter 時手機左側標名；
 *   念到 MariaDB 時書櫃轉為透視，頂列右後方主控板上的 ESP32-S3 開發板轉藍，接著朝鏡頭抬出到兩者之間並標名，停留後落回。
 *   Node.js 與 MariaDB 沒有對應的實體物件（不畫伺服器），寫在標題與副標。四個名稱同時在畫面上，旁白 24 維持不上字幕。
 * - 平移（鏡頭向左）：三支手機（賣家上架、書籍詳情、管理後台）由疊在一起扇形排開，鏡頭仰拍並緩慢環繞。
 * - 24b：304 與「超過四千項」寫在標題，不做數字滾動。段落結束時鏡頭向左移出。
 * 每句旁白只浮出一個元素：24 為開發板；24b 沒有對應的 App 元件，不浮出。
 *
 * 出處（複評版手冊；頁碼為 PDF 頁，括號內為頁面印刷頁碼）：
 * - p38（23）3-1 表現層：Flutter 行動應用客戶端；ESP32-S3 物聯網控制終端（四組電磁鎖與書櫃螢幕）。
 * - p38–39（23–24）業務邏輯層：Node.js、Express.js 的 RESTful API；資料持久層：「採用 MariaDB 作為核心資料庫」。
 * - p133（118）7-3 元件圖：「App 與智慧書櫃終端（ESP32-S3）皆經 API 元件存取後端」。
 * - 2026-10-26 實測：API 端點 304 個（npm run docs:check）、後端測試 1,567 項、App 測試 2,830 項，全數通過
 *   （合計 4,397 項，即旁白的「超過四千項」）。複評版手冊 p231 的 1,558／2,571 項與 301 個 API 為較早的數字。
 */
export default function sTechV3(world: World, ui: HTMLElement, _fx: HTMLElement) {
  const L24 = line('24');
  const LEN = section(SEC).end - section(SEC).start;

  // ── 時間（段落內秒數）。tts/24.wav 的停頓：Flutter 約 L24.at+0.5、Node.js +1.42、MariaDB +2.58、ESP32-S3 約 +3.4～+4.66
  const T_FL = L24.at + 0.5;
  const XRAY = onBeat(SEC, L24.at + 2.6);
  const F_BOARD = onBeat(SEC, L24.at + 3.2);
  // 開發板抬出：半拍後開始，完全抬出後停 1.5 秒以上再落回
  const LIFT = F_BOARD + 0.243;
  const T_ESP = LIFT + 0.3;
  const DROP = onBeat(SEC, LIFT + 0.5 + 1.6);
  const XRAY_OFF = DROP + 0.15;
  // 開發板落回後鏡頭向左平移到三支手機
  const MOVE0 = onBeat(SEC, DROP + 0.45), MOVE1 = MOVE0 + 0.95;
  const FAN0 = MOVE0 + 0.45, FAN1 = FAN0 + 1.1;
  const EXIT = LEN - 0.9;

  // ── 標題（情境＋解法）。第一行不放有下伸筆畫的英文字（App 的 p）：行高 1.27 的兩行之間，overlap 檢查會把下伸部分算成壓到第二行
  const t24 = new TitleV3(ui, ['訂單與櫃門狀態如何同步？', 'App 與書櫃共用 Node.js 後端'], '核心資料庫採用 MariaDB');
  const t24b = new TitleV3(ui, ['如何確保 304 個 API 正確運作？', '前後端超過四千項自動化測試全數通過'], '後端 1,567 項、App 2,830 項');
  const lbFlutter = new LabelV3(ui, 'Flutter', 'left');
  const lbEsp = new LabelV3(ui, 'ESP32-S3', 'left');
  [lbFlutter, lbEsp].forEach((l) => l.root.classList.add('tech-v3-label'));
  const dev = new DevBoardV3(world);

  // ── 場景配置：先定鏡頭，再用取景工具依畫面位置擺物件
  // A：手機與書櫃在原點附近，鏡頭由略俯視升高（透視時看得到平放在頂列底板的主控板）；B：三支手機在 A 的左方（向左平移）
  const CA: [number, number, number] = [0, 0.4, 0];
  const KA0 = orbit(CA, 0.14, 0.13, 60);
  const KA1 = orbit(CA, 0.04, 0.25, 58.5);
  const KA2 = orbit(CA, -0.02, 0.27, 58);
  // 平移 46 單位：手機還沒完全出畫，三支手機就由左側進入，中段不會只剩背景
  const CB: [number, number, number] = [-46, 0.4, 0];
  const KB0 = orbit(CB, -0.13, -0.09, 60);
  const KB1 = orbit(CB, -0.03, -0.11, 59);
  const KB2 = orbit(CB, 0.07, -0.12, 58);
  const camA = new CameraPath([[0, KA0], [XRAY, KA1], [MOVE0, KA2]]);
  const camB = new CameraPath([[MOVE1 - 0.3, KB0], [FAN1 + 0.4, KB1], [LEN, KB2]]);

  // App 手機：畫面左側、約七成高、轉向畫面中央並略往後仰。開場時兩者靠近中間，開發板抬出前往兩側讓出中間
  const PP0 = fit(world, KA1, 'phone', { cx: 530, cy: 600, h: 712, yaw: 0.3, rx: -0.1, rz: 0.03 });
  const PC0 = fit(world, KA1, 'cabinet', { cx: 1320, cy: 646, h: 612, yaw: -0.33 });
  const PP = fit(world, KA1, 'phone', { cx: 440, cy: 600, h: 712, yaw: 0.32, rx: -0.1, rz: 0.03 });
  // 書櫃：完整入鏡，畫面右側、櫃門朝畫面中央
  const PC = fit(world, KA1, 'cabinet', { cx: 1410, cy: 646, h: 612, yaw: -0.36 });
  // 三支手機扇形排開：中間那支在標題正下方（最高約 690px），兩側較遠、往外轉
  const FM = fit(world, KB1, 'phone', { cx: 960, cy: 630, h: 668, yaw: 0 });
  const FL = fit(world, KB1, 'phone', { cx: 650, cy: 638, h: 650, yaw: 0.44, rz: 0.11, depth: 67 });
  const FR = fit(world, KB1, 'phone', { cx: 1270, cy: 638, h: 650, yaw: -0.44, rz: -0.11, depth: 67 });
  // 排開前兩側那兩支疊在中間那支的正後方（前後錯開，不互相穿透）
  const FL0 = fit(world, KB1, 'phone', { cx: 930, cy: 640, h: 600, yaw: 0.1, rz: 0.02, depth: 68 });
  const FR0 = fit(world, KB1, 'phone', { cx: 990, cy: 640, h: 600, yaw: -0.1, rz: -0.02, depth: 73 });
  const drift = (p: Pose, d: Partial<Pose>): Pose => ({ ...p, ...Object.fromEntries(Object.entries(d).map(([k, v]) => [k, (p[k] ?? 0) + (v ?? 0)])) });

  const PART0 = XRAY - 0.5, PART1 = LIFT + 0.3;
  const phoneA: [number, Pose][] = [[0, drift(PP0, { ry: -0.05 })], [PART0, PP0], [PART1, PP], [MOVE0, drift(PP, { ry: 0.04 })]];
  const cabA: [number, Pose][] = [[0, drift(PC0, { ry: 0.06 })], [PART0, PC0], [PART1, PC], [MOVE0, drift(PC, { ry: -0.04 })]];
  // 平移途中鏡頭比定位時高，三支手機先略高一些，平移結束時落到定位，途中不進入字幕帶
  const UP = { y: 0.6 / world.stage.halfH };
  const fanL: [number, Pose][] = [[MOVE0, drift(FL0, UP)], [FAN0, FL0], [FAN1, FL], [LEN, drift(FL, { ry: 0.03 })]];
  const fanR: [number, Pose][] = [[MOVE0, drift(FR0, UP)], [FAN0, FR0], [FAN1, FR], [LEN, drift(FR, { ry: -0.03 })]];
  const fanM: [number, Pose][] = [[MOVE0, drift(FM, UP)], [MOVE1, FM], [FAN1, drift(FM, { ry: -0.02 })], [LEN, drift(FM, { ry: 0.03 })]];


  // ── 音效：只對應本段畫面上的動作
  fly(0, 0.9, 0.5, 0.2);
  cue('tick', T_FL + 0.05, { gain: 0.6, pan: -0.5 });
  cue('power', XRAY + 0.1, { gain: 0.5, pan: 0.4 });
  cue('lift', LIFT, { gain: 0.7, pan: 0.3 });
  cue('tick', T_ESP + 0.05, { gain: 0.6, pan: 0.1 });
  cue('pop', DROP + 0.3, { gain: 0.35, pan: 0.4 });
  fly(MOVE0, MOVE1, 0.5, 0.3);
  fly(FAN0, FAN1, 0.3, 0);
  fly(EXIT, LEN, 0.5, 0.3);

  const kiosk = (t: number): KioskParams => ({ state: 'qr', refresh: (t / 30) % 1, seconds: 60, digits: 1, check: 0, clock: '14:25', tick: t });
  const phoneHalf: [number, number, number] = [PHONE.W / 2, PHONE.H / 2, PHONE.D / 2];

  return (t: number) => {
    if (t < -0.05 || t > LEN + 0.05) return;

    t24.at(t, onBeat(SEC, 1.0), DROP - 0.2);
    t24b.at(t, MOVE1 + 0.05, EXIT - 0.05);

    const cam = sectionPans(sequence(t, [camA, camB], [{ at: MOVE0, kind: 'move' }]), t, LEN, { sec: SEC });
    world.frame.camera = cam;

    if (t < MOVE1 + 0.05) {
      const pose = glide(t, cabA, 0.42);
      const xray = soft(t, XRAY, XRAY + 0.6) * (1 - soft(t, XRAY_OFF, XRAY_OFF + 0.6));
      world.frame.cabinet = { pose, xray, kiosk: kiosk(t) };
      const fb = soft(t, F_BOARD, F_BOARD + 0.4) * (1 - soft(t, XRAY_OFF, XRAY_OFF + 0.5));
      world.frame.after.push(() => {
        world.cabinet.setFocus('board', fb);
        world.cabinet.setFocus('locks', 0);
      });
      world.frame.phones[BUYER] = { pose: glide(t, phoneA, 0.42), scr: { a: 'v_home' } };
    }
    // 開發板：從主控板朝鏡頭抬出到書櫃左前方，伸進手機與書櫃之間，長邊約 330px
    const kb = lift(t, LIFT, DROP);
    dev.at(world.frame.cabinet ? kb : 0, cam, { x: 1060, y: 640, depth: 50, len: 330, turn: 0.88, arc: 0.8 });

    const ph = t < MOVE0 && world.frame.phones[BUYER] ? world.phones[BUYER] : null;
    lbFlutter.at(world, t, T_FL, DROP - 0.2, ph?.body ?? null, phoneHalf, ph?.group ?? null);
    lbEsp.at(world, t, T_ESP, DROP - 0.2, kb > 0.01 ? dev.wrap : null, dev.half, kb > 0.01 ? dev.wrap : null);

    if (t > MOVE0 - 0.05) {
      world.frame.phones[SELLER] = { pose: glide(t, fanL, 0.3), scr: { a: 'v_sell_form_filled' } };
      world.frame.phones[ADMIN] = { pose: glide(t, fanR, 0.3), scr: { a: 'v_adm_home' } };
      world.frame.phones[FAN_MID] = { pose: glide(t, fanM, 0.3), scr: { a: 'v_ov_detail' } };
    }
  };
}
