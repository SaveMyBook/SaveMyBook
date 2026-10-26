import { cue, fly } from '../lib/cues';
import { RING, type World, type Pop } from '../world';
import type { Pose } from '../lib/kf';
import { seq, type Step } from '../scenes/kit';
import { line, section } from './kit2';
import { glide, soft } from './kit4';
import { onBeat } from './kit5';
import { TitleV3 } from '../v3/title';
import { CameraPath, orbit, sequence, sectionPans, type CamKey } from '../v3/camera';
import { fit } from '../v3/frame';
import { lift, slotColor, preloadSlots, float } from '../v3/pop';

const SEC = 'account';

/** 手機編號：登入頁（翻面後為會員等級頁）與三支設定頁；用品牌段的手機，避免和前後段落交界時共用同一支。 */
const MAIN = RING[0], FAN_L = RING[2], FAN_C = RING[4], FAN_R = RING[5];

/**
 * v3 帳號會員（旁白 20 登入方式、21 點數等級與語言主題）。規則見 DESIGN.md「v3 規則」，寫法照 s_cabinet_v3.ts。
 * - 20：登入頁手機在標題正下方、略為仰拍，螢幕轉向右側；「使用通行密鑰登入」按鈕往右浮出，手機略往左退。
 * - 翻面：手機快轉一圈並移到中央偏右，轉到背面時換成會員等級頁，改向左側。
 * - 21 前半：等級進度卡（再 90 點即可解鎖「活躍書友」，10 / 100）往左浮出。
 * - 甩鏡（向左）：三支設定頁手機扇形排開，中間為淺色繁體中文、兩側為深色英文與日文，
 *   念到「五種語言」時兩側直接切換成韓文與簡體中文，五種語言與兩種主題都在畫面上出現過。
 * 每句旁白只浮出一個元素：20 通行密鑰按鈕、21 等級進度卡；語言與主題由三支手機的排列呈現，不浮出。
 */
export default function sAccountV3(world: World, ui: HTMLElement, _fx: HTMLElement) {
  const L20 = line('20'), L21 = line('21');
  const LEN = section(SEC).end - section(SEC).start;

  // ── 時間（段落內秒數）
  // 20：tts/20.wav 的停頓為 Google 約 1.2、Apple 1.85、LINE 2.35，「手機簡訊與通行密鑰」約 2.5–4.3（皆為句內秒數）
  const KP0 = onBeat(SEC, L20.at + 3.0), KP1 = KP0 + 0.5 + 1.51;
  const FLIP0 = KP1 + 0.36, FLIP1 = FLIP0 + 0.86;
  const SWAP = (FLIP0 + FLIP1) / 2;
  // 21：tts/21.wav「完成交易可以累積點數、升級會員，」約 0–3.45、「介面支援五種語言與深淺色主題」約 3.75 起（句內秒數）
  const LV0 = onBeat(SEC, L21.at + 0.3), LV1 = LV0 + 0.5 + 1.51;
  const WHIP0 = LV1 + 0.4, WHIP1 = WHIP0 + 0.5;
  const LANG = onBeat(SEC, L21.at + 4.5);
  const EXIT = LEN - 0.9;

  // ── 標題（情境＋解法）
  // 登入方式：旁白 20
  const tA = new TitleV3(ui, ['慣用的帳號各不相同？', '提供多種登入方式'], 'Google、Apple、LINE、手機簡訊與通行密鑰');
  // 每筆購買訂單 10 點、100 點升級：複評版手冊 p260（PDF 第 275 頁）表 12-16-1、12-16-2
  const tB = new TitleV3(ui, ['完成交易有什麼回饋？', '累積點數，升級會員'], '每完成一筆購買訂單累積 10 點，滿 100 點即可升級');
  // 五種語言與深淺色主題：旁白 21；語言名稱見複評版手冊 p37（PDF 第 52 頁）表 5-1-1
  const tC = new TitleV3(ui, ['介面可以依習慣調整？', '五種語言與深淺色主題'], '繁體中文、簡體中文、英文、日文、韓文');
  world.later.push(() => preloadSlots(['cut_acc_passkey', 'cut_acc_level_card']));
  // 段落外（前後各 1 秒，圖層仍顯示）場景不更新，標題要先藏起來，否則會以初始狀態疊在相鄰段落上
  [tA, tB, tC].forEach((x) => x.at(-99, 0, 1));

  // ── 鏡頭：A 登入（略為仰拍）→ 翻面後 B 會員等級（同一鏡位微推）→ 甩鏡向左 70° 到 C 三支設定頁
  const KA: CamKey = { pos: [0.8, -6.2, 60], look: [0.3, 0.4, 0] };
  const KA2: CamKey = { pos: [0.2, -5.6, 59], look: [0.4, 0.5, 0] };
  const KB: CamKey = { pos: [-0.6, -4.0, 58], look: [0.4, 0.7, 0] };
  const th = (-70 * Math.PI) / 180;
  const C: [number, number, number] = [KB.pos[0] + Math.sin(th) * 58, 0, KB.pos[2] - Math.cos(th) * 58];
  const PHI = Math.atan2(KB.pos[0] - C[0], KB.pos[2] - C[2]);
  const KC1 = orbit(C, PHI + 0.05, 0.06, 58, [0, 0.6, 0]);
  const KC2 = orbit(C, PHI - 0.03, 0.04, 56.5, [0, 0.6, 0]);
  const camA = new CameraPath([[0, KA], [FLIP0, KA2], [FLIP1 + 0.3, KB], [WHIP0, { ...KB, pos: [KB.pos[0] - 0.4, KB.pos[1], KB.pos[2] - 0.6] }]]);
  const camC = new CameraPath([[WHIP1 - 0.2, KC1], [LEN, KC2]]);

  // 登入頁：標題正下方、螢幕轉向右側；按鈕往右浮出，手機同時略往左退
  const PA = fit(world, KA, 'phone', { cx: 960, cy: 628, h: 668, yaw: 0.3, rx: -0.05, rz: -0.04 });
  const PA2 = fit(world, KA, 'phone', { cx: 900, cy: 632, h: 656, yaw: 0.36, rx: -0.05, rz: -0.04 });
  // 會員等級頁：翻面時回到中央偏右、改向左側，等級卡往左浮出
  const PB = fit(world, KB, 'phone', { cx: 1020, cy: 628, h: 668, yaw: -0.3, rx: 0.02, rz: 0.04 });
  // 三支設定頁：中間在標題正下方（上緣在標題下方 40px 以下），兩側在後方向外轉、向外傾，扇形排開
  const FC = fit(world, KC1, 'phone', { cx: 960, cy: 630, h: 666, yaw: 0.0, rx: -0.03 });
  const FL = fit(world, KC1, 'phone', { cx: 560, cy: 628, h: 640, yaw: 0.55, rz: 0.11, depth: 64 });
  const FR = fit(world, KC1, 'phone', { cx: 1360, cy: 628, h: 640, yaw: -0.55, rz: -0.11, depth: 64 });
  const drift = (p: Pose, d: Partial<Pose>): Pose => ({ ...p, ...Object.fromEntries(Object.entries(d).map(([k, v]) => [k, (p[k] ?? 0) + (v ?? 0)])) });

  const main: [number, Pose][] = [
    // 等待浮出前緩慢轉向，畫面不完全靜止
    [0, drift(PA, { ry: 0.09, rz: 0.01 })],
    [KP0, PA],
    [KP0 + 0.6, PA2],
    [FLIP0, drift(PA2, { ry: 0.03 })],
    [FLIP1, PB],
    // 甩鏡會帶一點滾轉，手機先略縮小，出畫途中不進入字幕帶
    [WHIP0, { ...drift(PB, { ry: -0.04 }), s: (PB.s ?? 1) * 0.965 }],
  ];
  const fanKeys = (p: Pose, d: Partial<Pose>): [number, Pose][] => [[WHIP0, p], [LEN, drift(p, d)]];
  const fanC = fanKeys(FC, { ry: -0.04 });
  const fanL = fanKeys(FL, { ry: -0.05, rz: -0.01 });
  const fanR = fanKeys(FR, { ry: 0.03, rz: 0.01 });
  const spin = (t: number) => -2 * Math.PI * soft(t, FLIP0, FLIP1);

  const mainSteps: Step[] = [[-9, 'v_acc_login'], [SWAP, 'v_acc_level', 0, 0.001]];
  // 換語言直接切換（App 換語言也是整頁重畫），不淡化
  const leftSteps: Step[] = [[-9, 'v_acc_settings_en_dark'], [LANG, 'v_acc_settings_ko_dark', 0, 0.001]];
  const rightSteps: Step[] = [[-9, 'v_acc_settings_ja_dark'], [LANG, 'v_acc_settings_hans_dark', 0, 0.001]];


  fly(0, 0.9, 0.5, 0.2);
  cue('pop', KP0 + 0.05, { gain: 0.5, pan: 0.1 });
  fly(FLIP0, FLIP1, 0.55, 0.3);
  cue('pop', LV0 + 0.05, { gain: 0.5, pan: 0.1 });
  fly(WHIP0, WHIP1, 0.7, 0);
  cue('swap', LANG, { gain: 0.7 });
  fly(EXIT, LEN, 0.5, 0.3);

  return (t: number) => {
    tA.at(t, 1.0, KP1 - 0.2);
    tB.at(t, SWAP + 0.1, LV1);
    tC.at(t, WHIP1 + 0.1, EXIT - 0.45);
    if (t < -0.05 || t > LEN + 0.05) return;

    const cam = sectionPans(sequence(t, [camA, camC], [{ at: WHIP0, kind: 'whip' }]), t, LEN, { sec: SEC });
    world.frame.camera = cam;

    if (t < WHIP1 + 0.05) {
      const kp = lift(t, KP0, KP1), kl = lift(t, LV0, LV1);
      const fp = float(t, kp), fl = float(t, kl, 1.1);
      const pose = glide(t, main, 0.42);
      // 轉到側面時機身厚度與傾斜會讓外框變大：翻面途中略縮小、略上移，不進入字幕帶
      const bump = Math.sin(Math.PI * soft(t, FLIP0, FLIP1));
      pose.ry = (pose.ry ?? 0) + spin(t);
      pose.s = (pose.s ?? 1) * (1 - 0.04 * bump);
      pose.y = (pose.y ?? 0) + (0.3 * bump) / world.stage.halfH;
      const ps: Pop[] = [
        { id: 'acc3_passkey', cut: 'cut_acc_passkey', k: kp, grow: 0.36, dx: 530 + fp.dx, dy: -110 + fp.dy, dz: 2.4 + fp.dz, slot: slotColor('cut_acc_passkey') },
        { id: 'acc3_level', cut: 'cut_acc_level_card', k: kl, grow: 0.32, dx: -580 + fl.dx, dy: 40 + fl.dy, dz: 2.4 + fl.dz, slot: slotColor('cut_acc_level_card') },
      ];
      world.frame.phones[MAIN] = { pose, scr: seq(t, mainSteps), pops: ps };
    }
    if (t > WHIP0 - 0.05) {
      world.frame.phones[FAN_L] = { pose: glide(t, fanL, 0.42), scr: seq(t, leftSteps) };
      world.frame.phones[FAN_R] = { pose: glide(t, fanR, 0.42), scr: seq(t, rightSteps) };
      world.frame.phones[FAN_C] = { pose: glide(t, fanC, 0.42), scr: { a: 'v_acc_settings_hant' } };
    }
  };
}

