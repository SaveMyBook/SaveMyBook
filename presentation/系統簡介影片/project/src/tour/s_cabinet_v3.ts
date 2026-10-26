import * as THREE from 'three';
import { cue, fly } from '../lib/cues';
import { SELLER, BUYER, ADMIN, SEQS, type World, type Pop } from '../world';
import { Cabinet } from '../three/cabinet';
import type { KioskParams } from '../three/textures';
import type { Pose } from '../lib/kf';
import { seq, frameSteps, type Step } from '../scenes/kit';
import { line, section } from './kit2';
import { glide, soft } from './kit4';
import { onBeat, TapOn } from './kit5';
import { PopBox, DigitFly } from './x_cabinet';
import { TitleV3 } from '../v3/title';
import { LabelV3 } from '../v3/label';
import { CameraPath, orbit, sequence, sectionPans, type CamKey } from '../v3/camera';
import { fit } from '../v3/frame';
import { lift, slotColor, preloadSlots, float } from '../v3/pop';
import { kioskPop } from '../v3/kiosk';

const SEC = 'cabinet';

/**
 * v3 智慧書櫃（旁白 12 硬體、13 掃碼、14 比對開門與放書、15 完成並通知買家、16 交通資訊）。規則見 DESIGN.md「v3 規則」。
 * - 12：書櫃完整入鏡並俯視轉動、透視；ESP32-S3（主控板上）、電磁鎖 ×4、2.8 吋螢幕依旁白轉藍並標名。
 * - 平移（鏡頭向左）：賣家手機在遠處（約七成高、轉 20°），「距離書櫃約 310 公尺」提示卡往左上浮出，手機略往右下退；點「重新掃描」。
 * - 甩鏡到書櫃（向左）：手機隨後由右側移入書櫃右前方，掃描螢幕上的 QR Code（QR Code 更新）→ 正在確認書櫃 → 確認存書項目。
 * - 14：書櫃螢幕從原位朝鏡頭浮起，比對數字飛進手機 → A01 開門、放書、關門 → 作業完成後螢幕落回。
 * - 平移（鏡頭向左）：買家手機在畫面中央偏左，存書通知滑入後往右上浮出並輕微漂浮。
 * - 16：點通知進入前往書櫃，捲到交通資訊，捷運海山站一列浮出 → 段落結束時鏡頭向左移出。
 * 每句旁白只浮出一個元素：13 提示卡、14 書櫃螢幕、15 存書通知、16 捷運站。12 為透視標名。
 * 甩鏡與平移都向左：舊畫面往右出畫、新畫面由左側進入，高的手機不必橫越標題，也不經過字幕帶。
 */
export default function sCabinetV3(world: World, ui: HTMLElement, _fx: HTMLElement) {
  world.cabinet.kiosk.setScale(4);
  const L12 = line('12'), L15 = line('15'), L16 = line('16');
  const LEN = section(SEC).end - section(SEC).start;

  // ── 時間（段落內秒數）
  // 12：透視
  const X0 = onBeat(SEC, 2.4), X1 = onBeat(SEC, 7.0);
  const F_BOARD = onBeat(SEC, 3.1), F_LOCKS = onBeat(SEC, 4.5), F_SCREEN = onBeat(SEC, 5.9);
  // 透視收起後，鏡頭向左平移到遠處的賣家手機
  const MOVE0 = L12.end - 0.15, MOVE1 = MOVE0 + 0.95;
  // 13：提示卡浮出（停 1.5 秒）→ 點重新掃描 → 甩鏡到書櫃 → QR Code 更新 → 掃描 → 確認
  const FAR0 = MOVE1 + 0.12, FAR1 = FAR0 + 0.5 + 1.52;
  const TAP_RESCAN = FAR1 + 0.05;
  const WHIP0 = TAP_RESCAN + 0.7, WHIP1 = WHIP0 + 0.5;
  const IN2 = WHIP1 + 0.05, IN2_DUR = 0.7;
  const QR_SWAP = onBeat(SEC, Math.max(12.8, IN2 + IN2_DUR + 0.05));
  const SCAN = onBeat(SEC, QR_SWAP + 0.35);
  const CONFIRM = onBeat(SEC, SCAN + 0.7);
  const MATCH = onBeat(SEC, CONFIRM + 0.7);
  const TICK = MATCH - 0.17;
  // 14：螢幕浮出 → 數字飛進手機 → 開門 → 放書
  const KPOP = MATCH + 0.1;
  const FLY0 = onBeat(SEC, MATCH + 1.1), FLY1 = FLY0 + 0.8;
  const OPENING = onBeat(SEC, FLY1 + 0.6);
  const UNLOCK = onBeat(SEC, OPENING + 0.7);
  const PUT0 = UNLOCK + 1.3, PUT1 = PUT0 + 0.85;
  // 15：關門 → 作業完成 → 螢幕落回 → 平移到買家手機 → 通知滑入、浮出
  const CLOSE = onBeat(SEC, L15.at - 0.15);
  const DONE = CLOSE + 0.55;
  const KDOWN = DONE + 0.15;
  const RIP0 = KDOWN + 0.4, RIP1 = RIP0 + 0.95;
  const BANNER0 = RIP1 - 0.25, BANNER1 = BANNER0 + 0.36;
  const BPOP = BANNER1, BPOP_OUT = BPOP + 0.5 + 1.52;
  // 16：點通知 → 推入前往書櫃 → 捲到交通資訊 → 捷運站浮出 → 段落結束前收回、鏡頭移出
  const TAP_BANNER = BPOP_OUT + 0.3;
  const GUIDE = Math.max(onBeat(SEC, L16.at + 0.25), TAP_BANNER + 0.4);
  const SCROLL0 = GUIDE + 0.6, SCROLL1 = SCROLL0 + 0.45;
  const MPOP = onBeat(SEC, SCROLL1 + 0.15);
  const EXIT = LEN - 0.9;
  const MPOP_OUT = Math.min(EXIT - 0.45, MPOP + 0.5 + 2.4);

  // ── 標題（情境＋解法；數字出自旁白、複評版手冊與 BRIEF）
  // 「2.8 吋」：複評版手冊 PDF 第 40 頁 表3-2-4
  const t12 = new TitleV3(ui, ['四扇櫃門由誰控制？', '一片 ESP32-S3 統一控制'], '電磁鎖櫃門 ×4 與 2.8 吋螢幕');
  const tA = new TitleV3(ui, ['如何確認人在書櫃前？', '掃描書櫃上的 QR Code'], '需在書櫃 200 公尺內，QR Code 約每 30 秒更新');
  const tB = new TitleV3(ui, ['如何避免開錯櫃門？', '輸入螢幕上的兩位數字'], '60 秒內比對相符，才開啟指定的櫃門');
  const tC = new TitleV3(ui, ['買家何時可以取書？', '關上櫃門即登記存書'], '系統同時通知買家前往取書');
  const tD = new TitleV3(ui, ['怎麼前往書櫃？', 'App 整合臺北市開放資料'], '捷運、公車與 YouBike 資訊');
  const lbBoard = new LabelV3(ui, 'ESP32-S3', 'right');
  const lbLocks = new LabelV3(ui, '電磁鎖 ×4', 'left');
  const lbScreen = new LabelV3(ui, '2.8 吋螢幕', 'left');
  const popBox = new PopBox(ui);
  const SELL2 = ADMIN;
  const digits = new DigitFly(ui, SELL2);
  const taps = [
    new TapOn(ui, SELLER, 'tap_cab_rescan', TAP_RESCAN),
    new TapOn(ui, SELL2, 'tap_cab_open', MATCH - 0.62),
    new TapOn(ui, SELL2, 'tap_cab_confirm', OPENING - 0.6),
    new TapOn(ui, BUYER, 'tap_cab_banner', TAP_BANNER),
  ];
  world.later.push(() => preloadSlots(['cut_cab_far', 'cut_cab_banner', 'cut_cab_mrt_row']));

  // ── 場景配置：先定鏡頭，再用取景工具依畫面位置擺物件
  // A：遠處的賣家手機在原點；X：透視時的書櫃在 A 的右方（向左平移到 A）；C：書櫃在 A 的左前方 70°（向左甩鏡）；D：買家手機在 C 的左方
  const KA: CamKey = { pos: [-0.4, -4.4, 60], look: [0, 0.8, 0] };
  const KA2: CamKey = { pos: [-1.2, -4.0, 57.5], look: [0.2, 0.9, 0] };
  const R: [number, number, number] = [64, 0, 0];
  const KX0 = orbit(R, 0.5, 0.3, 58, [0, 0.4, 0]);
  const KX1 = orbit(R, -0.2, 0.28, 57, [0, 0.4, 0]);
  const KX2 = orbit(R, -0.3, 0.2, 58, [0, 0.4, 0]);
  const th = (-70 * Math.PI) / 180;
  const C: [number, number, number] = [KA2.pos[0] + Math.sin(th) * 58, 0, KA2.pos[2] - Math.cos(th) * 58];
  const PHI = Math.atan2(KA2.pos[0] - C[0], KA2.pos[2] - C[2]);
  const r = new THREE.Vector3(Math.cos(PHI), 0, -Math.sin(PHI));
  const KC1 = orbit(C, PHI, 0.035, 57, [r.x * 1.5, 1.2, r.z * 1.5]);
  const KC2 = orbit(C, PHI + 0.035, 0.0, 56, [r.x * 1.4, 1.1, r.z * 1.4]);
  const KC3 = orbit(C, PHI + 0.04, 0.02, 56.5, [r.x * 1.5, 1.2, r.z * 1.5]);
  const shiftD = (k: CamKey, d: number): CamKey => ({ ...k, pos: [k.pos[0] + r.x * d, k.pos[1], k.pos[2] + r.z * d], look: [k.look[0] + r.x * d, k.look[1], k.look[2] + r.z * d] });
  // 平移 44 單位：舊畫面還沒完全出畫，買家手機就由左側進入，中段不會整格空白
  const KD = shiftD(KC3, -44);
  const KD2 = shiftD(orbit(C, PHI + 0.01, 0.02, 56.5, [r.x * 1.5, 1.2, r.z * 1.5]), -44);
  const KD3 = shiftD(orbit(C, PHI - 0.02, 0.025, 56.5, [r.x * 1.5, 1.2, r.z * 1.5]), -44);

  const camX = new CameraPath([[0, KX0], [X1 - 0.3, KX1], [MOVE0, KX2]]);
  const camA = new CameraPath([[MOVE1 - 0.3, KA], [WHIP0, KA2]]);
  const camC = new CameraPath([[WHIP1 - 0.2, KC1], [MATCH, KC1], [FLY1, KC2], [RIP0, KC3]]);
  const camD = new CameraPath([[RIP1 - 0.3, KD], [GUIDE, KD2], [LEN, KD3]]);

  // 書櫃（透視）：完整入鏡，鏡頭繞著它轉
  const PX = fit(world, KX0, 'cabinet', { cx: 960, cy: 616, h: 590, yaw: 0.25 });
  // 賣家手機（遠處）：畫面右側、約七成高、轉 20°；提示卡浮出時略往右下退
  const PA = fit(world, KA, 'phone', { cx: 1562, cy: 556, h: 756, yaw: -0.36, rx: -0.05, rz: 0.035 });
  const PA2 = fit(world, KA, 'phone', { cx: 1600, cy: 590, h: 700, yaw: -0.4, rx: -0.05, rz: 0.035 });
  // 書櫃（存書）：完整入鏡，在標題下方 40px 與字幕帶之間
  const PC = fit(world, KC1, 'cabinet', { cx: 770, cy: 630, h: 640, yaw: 0.42 });
  // 書櫃旁的賣家手機：書櫃右前方、離鏡頭更近、轉向書櫃，不遮住標誌與螢幕；櫃門開啟時門板在手機後方
  const P2 = fit(world, KC1, 'phone', { cx: 1570, cy: 566, h: 752, yaw: -0.3, rx: 0.02, rz: -0.025, depth: 40 });
  // 買家手機：畫面中央偏左、約七成高、轉 18°，右側留給浮出的通知。右緣在標題副標左側 40px 外，才能高過副標下緣
  const PD = fit(world, KD, 'phone', { cx: 560, cy: 616, h: 706, yaw: 0.31, rx: -0.04, rz: 0.03 });
  const drift = (p: Pose, d: Partial<Pose>): Pose => ({ ...p, ...Object.fromEntries(Object.entries(d).map(([k, v]) => [k, (p[k] ?? 0) + (v ?? 0)])) });

  // 平移途中鏡頭比定位時高，手機先略高一些，平移結束時落到定位，途中不進入字幕帶
  const sel0: [number, Pose][] = [
    [MOVE0, drift(PA, { y: 2.5 / world.stage.halfH })],
    [MOVE1, PA],
    [FAR0, drift(PA, { ry: 0.02 })],
    [FAR0 + 0.6, PA2],
    [WHIP0 + 0.3, drift(PA2, { ry: 0.04, rz: -0.01 })],
  ];
  // 甩鏡時不顯示（否則會橫越整個畫面），甩鏡後由畫面右側外移入
  const sel2: [number, Pose][] = [
    [IN2, { ...P2, x: (P2.x ?? 0) + (r.x * 26) / world.stage.halfW, z: (P2.z ?? 0) + r.z * 26, ry: (P2.ry ?? 0) - 0.35 }],
    [IN2 + IN2_DUR, P2],
    [SCAN + 0.3, drift(P2, { ry: 0.03 })],
    [FLY1, drift(P2, { ry: 0.06, rz: 0.005 })],
    [RIP0, drift(P2, { ry: 0.04 })],
  ];
  const buy: [number, Pose][] = [[RIP1 - 0.3, PD], [GUIDE, drift(PD, { ry: -0.03 })], [LEN, drift(PD, { ry: -0.07, rz: -0.01 })]];
  const cabX: [number, Pose][] = [[0, PX], [X1, drift(PX, { ry: -0.25 })], [MOVE1, drift(PX, { ry: -0.3 })]];

  const sellSteps: Step[] = [
    [-9, 'v_cab_scan_0'],
    [QR_SWAP, 'v_cab_scan_1', 0, 0.001],
    [SCAN, 'v_cab_checking', 0, 0.001],
    [CONFIRM, 'v_cab_confirm', 0, 0.001],
    [MATCH, 'v_cab_match_59', 0, 0.001],
    [TICK + 1, 'v_cab_match_58', 0, 0.001],
    [FLY1 - 0.04, 'v_cab_match_25', 0, 0.001],
    [OPENING, 'v_cab_opening', 0, 0.001],
    [UNLOCK, 'v_cab_open_30', 0, 0.001],
    [UNLOCK + 1, 'v_cab_open_29', 0, 0.001],
    [UNLOCK + 2, 'v_cab_open_28', 0, 0.001],
    [UNLOCK + 3, 'v_cab_open_27', 0, 0.001],
    [DONE, 'v_cab_done', 0, 0.001],
  ];
  // 橫幅與捲動的連續畫面由截圖工具輸出（sequences.json），world.load() 之後才有，所以播放時才組
  let buySteps: Step[] | null = null;
  const buildBuyer = (): Step[] => [
    [-9, 'v_cab_home'],
    ...frameSteps(SEQS.cab_banner ?? [], BANNER0, BANNER1),
    [GUIDE, 'v_cab_guide', 1, 0.5],
    ...frameSteps((SEQS.cab_guide_scroll ?? []).slice(1), SCROLL0, SCROLL1),
  ];

  // ── 書櫃螢幕：旁白 14 從原位朝鏡頭浮起（靠近鏡頭 9 單位、往畫面左上，放大 1.65 倍；加上透視約為原本的兩倍）
  const kiosk = (t: number, cam: CamKey, cab: Pose): KioskParams => {
    const t0 = WHIP1;
    const refresh = t < QR_SWAP ? Math.min(1, 0.8 + 0.2 * Math.max(0, t - t0) / Math.max(0.1, QR_SWAP - t0)) : (t - QR_SWAP) / 30;
    const flash = Math.max(0, 1 - Math.abs(t - QR_SWAP) / 0.22);
    const pop = t > WHIP0 ? kioskPop(world, lift(t, KPOP, KDOWN), cam, cab, { toward: 9, left: 2.4, up: -0.35, scale: 1.65 }) : undefined;
    const base = { refresh: t < WHIP0 ? (t / 30) % 1 : refresh, seconds: 60, digits: 1, check: 0, qr: t < QR_SWAP ? 0 : 1, flash, clock: '14:25', tick: t, pop };
    if (t < CONFIRM) return { ...base, state: 'qr' };
    if (t < MATCH) return { ...base, state: 'busy', seconds: 59 };
    if (t < OPENING) return { ...base, state: 'match', seconds: Math.max(56, 59 - Math.floor(t - TICK)), digits: 1 - 0.7 * soft(t, FLY0, FLY0 + 0.15) };
    if (t < UNLOCK) return { ...base, state: 'opening' };
    if (t < DONE) return { ...base, state: 'open', seconds: 30 - Math.floor(t - UNLOCK) };
    return { ...base, state: 'done', check: soft(t, DONE, DONE + 0.5) };
  };


  // ── 音效：只對應本段畫面上的動作
  fly(0, 0.9, 0.5, 0.2);
  cue('power', X0 + 0.1, { gain: 0.5 });
  [F_BOARD, F_LOCKS, F_SCREEN].forEach((t) => cue('tick', t, { gain: 0.6 }));
  fly(MOVE0, MOVE1, 0.5, 0.3);
  cue('alert', FAR0, { gain: 0.6, pan: 0.5 });
  cue('pop', FAR0 + 0.05, { gain: 0.5, pan: 0.2 });
  fly(WHIP0, WHIP1, 0.7, 0);
  fly(IN2, IN2 + IN2_DUR, 0.4, 0.6);
  cue('digital', QR_SWAP, { gain: 0.5, pan: -0.3 });
  cue('scan', SCAN - 0.7, { dur: 0.7, pan: 0.4 });
  cue('beep', SCAN, { pan: 0.4 });
  cue('select', CONFIRM, { gain: 0.5, pan: 0.4 });
  cue('lift', KPOP, { gain: 0.7, pan: -0.5 });
  cue('zip', FLY0, { dur: 0.8, pan: 0 });
  cue('key', FLY1 - 0.06, { pan: 0.4, gain: 0.5 });
  cue('key', FLY1 + 0.02, { pan: 0.4, gain: 0.5 });
  cue('unlock', UNLOCK, { pan: -0.2 });
  cue('door_open', UNLOCK + 0.05, { dur: 0.6, pan: -0.1 });
  cue('book', PUT1, { pan: -0.2 });
  cue('door_close', CLOSE, { dur: 0.55, pan: -0.1 });
  cue('slam', CLOSE + 0.55, { pan: -0.1, gain: 0.8 });
  cue('success', DONE + 0.05, { pan: -0.3 });
  cue('pop', KDOWN + 0.25, { gain: 0.35, pan: -0.5 });
  fly(RIP0, RIP1, 0.5, 0.3);
  cue('banner', BANNER0, { gain: 0.8, pan: -0.2 });
  cue('notify', BANNER0 + 0.05, { gain: 0.9, pan: -0.2 });
  cue('pop', BPOP, { gain: 0.5, pan: 0.2 });
  cue('swipe', SCROLL0, { gain: 0.4, pan: -0.2 });
  cue('pop', MPOP, { gain: 0.5, pan: 0.2 });
  fly(EXIT, LEN, 0.5, 0.3);

  return (t: number) => {
    // 標題、標籤、點擊等畫面元件在段落外也要每格更新（各自會隱藏），再提早返回
    t12.at(t, 1.0, MOVE0 - 0.45);
    tA.at(t, MOVE1 + 0.05, MATCH - 0.5);
    tB.at(t, MATCH + 0.05, L15.at - 0.45);
    tC.at(t, L15.at - 0.05, L16.at - 0.3);
    tD.at(t, L16.at + 0.1, EXIT - 0.45);
    if (t < -0.05 || t > LEN + 0.05) {
      for (const lb of [lbBoard, lbLocks, lbScreen]) lb.at(world, t, 0, 0, null, [0, 0, 0], null);
      popBox.at(world);
      taps.forEach((tp) => tp.at(world, t));
      digits.at(world, t, FLY0, FLY1);
      return;
    }

    const cam = sectionPans(sequence(t, [camX, camA, camC, camD], [
      { at: MOVE0, kind: 'move' }, { at: WHIP0, kind: 'whip' }, { at: RIP0, kind: 'move' },
    ]), t, LEN, { sec: SEC });
    world.frame.camera = cam;

    // 12：透視與標名（元件依旁白順序轉藍）
    if (t < MOVE1 + 0.05) {
      const pose = glide(t, cabX, 0.42);
      const xray = soft(t, X0, X0 + 0.6) * (1 - soft(t, X1, X1 + 0.6));
      world.frame.cabinet = { pose, xray, kiosk: kiosk(t, cam, pose) };
      const fb = soft(t, F_BOARD, F_BOARD + 0.4) * (1 - soft(t, F_SCREEN - 0.4, F_SCREEN));
      const fl = soft(t, F_LOCKS, F_LOCKS + 0.4) * (1 - 0.6 * soft(t, F_SCREEN, F_SCREEN + 0.4)) * (1 - soft(t, X1, X1 + 0.4));
      world.frame.after.push(() => {
        world.cabinet.setFocus('board', fb);
        world.cabinet.setFocus('locks', fl);
      });
    }
    const g = world.frame.cabinet && t < MOVE0 ? world.cabinet.group : null;
    const half: [number, number, number] = [Cabinet.WIDTH / 2, Cabinet.HEIGHT / 2, Cabinet.DEPTH / 2];
    lbBoard.at(world, t, F_BOARD + 0.1, F_SCREEN - 0.4, g, half, world.cabinet.anchors.board);
    lbLocks.at(world, t, F_LOCKS + 0.1, X1 - 0.2, g, half, world.cabinet.anchors.locks);
    lbScreen.at(world, t, F_SCREEN + 0.1, X1 - 0.2, g, half, world.cabinet.anchors.screen);

    // 甩鏡進行到一半手機已出畫，之後轉到鏡頭側後方，不再寫入（檢查工具會把鏡頭後方的投影算成整個畫面）
    if (t > MOVE0 - 0.05 && t < WHIP0 + 0.3) {
      const k = lift(t, FAR0, FAR1);
      const ps: Pop[] = [{ id: 'v3_far', cut: 'cut_cab_far', k, grow: 1.0, dx: -1420, dy: -110, dz: 3.0, slot: slotColor('cut_cab_far') }];
      world.frame.phones[SELLER] = { pose: glide(t, sel0, 0.42), scr: { a: 'v_cab_far' }, pops: ps };
    }
    if (t > WHIP0 - 0.05 && t < RIP1 + 0.1) {
      if (t > IN2) world.frame.phones[SELL2] = { pose: glide(t, sel2, 0.3), scr: seq(t, sellSteps) };
      world.frame.cabinet = {
        pose: PC,
        kiosk: kiosk(t, cam, PC),
        door: soft(t, UNLOCK + 0.05, UNLOCK + 0.65) * (1 - soft(t, CLOSE, CLOSE + 0.55)),
        deposit: soft(t, PUT0, PUT1),
      };
    }
    if (t > RIP0 + 0.1) {
      buySteps ??= SEQS.cab_banner ? buildBuyer() : null;
      const kb = lift(t, BPOP, BPOP_OUT), km = lift(t, MPOP, MPOP_OUT);
      const fb = float(t, kb), fm = float(t, km, 1.3);
      const ps: Pop[] = [
        { id: 'v3_banner', cut: 'cut_cab_banner', k: kb, grow: 0.6, dx: 980 + fb.dx, dy: 90 + fb.dy, dz: 2.2 + fb.dz, slot: slotColor('cut_cab_banner') },
        { id: 'v3_mrt', cut: 'cut_cab_mrt_row', k: km, grow: 0.6, dx: 980 + fm.dx, dy: 40 + fm.dy, dz: 2.2 + fm.dz, slot: slotColor('cut_cab_mrt_row') },
      ];
      world.frame.phones[BUYER] = { pose: glide(t, buy, 0.42), scr: buySteps ? seq(t, buySteps) : { a: 'v_cab_home' }, pops: ps };
    }
    popBox.at(world);
    taps.forEach((tp) => tp.at(world, t));
    digits.at(world, t, FLY0, FLY1);
  };
}
