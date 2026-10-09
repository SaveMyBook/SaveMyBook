import { type Pose } from '../lib/kf';
import { cue, fly } from '../lib/cues';
import { SELLER, BUYER, SEQS, type World, type Pop } from '../world';
import type { KioskParams, KioskPop } from '../three/textures';
import { seq, stepCues, frameSteps, back, type Step } from '../scenes/kit';
import { line } from './kit2';
import { Title, ChapterWord, glide, soft } from './kit4';
import { onBeat, TapOn, spread } from './kit5';
import { PartLabel, PopBox, DigitFly, popAt, POP_Z } from './x_cabinet';

const SEC = 'cabinet';
const SIGMA = 0.42;

/**
 * 第 5 章 智慧書櫃（旁白 12 硬體、13 定位與 QR Code、14 比對數字開門、15 關門存書並通知、16 交通開放資料）。
 * 12：書櫃由下方升起並緩慢轉動，櫃體透視，ESP32-S3、電磁鎖 ×4、螢幕依旁白順序轉藍並標名。
 * 13：書櫃退到遠方，賣家手機升起：在捷運海山站出口掃描被拒（App 顯示距離書櫃約 310 公尺）→ 走到書櫃前（書櫃推近），
 *     書櫃螢幕浮出到左側放大（之後一路顯示到作業完成），QR Code 倒數歸零後更新、手機掃描 → 正在確認書櫃 → 確認存書項目。
 * 14：比對數字由浮出的螢幕飛進手機的輸入格 → 確認 → A01 開鎖開門，手機上「請將下列書籍放入櫃門 A01」浮出，書放進櫃內。
 * 15：關門，螢幕「作業完成」、手機「存書完成，已通知買家取書」→ 書櫃往左退出、賣家手機退到左後方，
 *     買家手機沿同一道弧線從右側滑入，App 在前景收到存書通知（橫幅）並浮出。
 * 16：點通知進入前往書櫃，捲到交通資訊，捷運海山站、票價、最近的公車站牌依拍點往右展開 → 往下退場。
 * 書櫃規格依實機：木作櫃體＋壓克力正面、右上角 2.8 吋橫向螢幕（純顯示）、A01–A04 由上而下、右側鉸鏈。
 * 交通資料為新北高工附近的 data.taipei 實際資料（截圖工具 cabinet_admin_test.dart 的 _transitJson）；
 * 新北高工位於新北市，臺北市 YouBike 2.0 資料在 500 公尺內沒有站點，App 該區塊只顯示「沒有站點」，所以不浮出。
 */
export function sCabinet(world: World, ui: HTMLElement, fx: HTMLElement) {
  // 書櫃螢幕放大浮出時，材質需要較高解析度
  world.cabinet.kiosk.setScale(4);
  const L12 = line('12'), L13 = line('13'), L14 = line('14'), L15 = line('15'), L16 = line('16');
  const OUT = L16.end;

  const word = new ChapterWord(fx, '智慧書櫃');
  // 旁白 12；「2.8 吋」出自複評版手冊 PDF 第 40 頁 表3-2-4（2.8 吋 320×240 TFT 顯示模組，橫向，僅供顯示）
  const tA = new Title(ui, '一片 [ESP32-S3]　控制書櫃', '四扇電磁鎖櫃門與螢幕');
  const lbBoard = new PartLabel(ui, 'ESP32-S3', 'board', 'right');
  const lbLocks = new PartLabel(ui, '電磁鎖 ×4', 'locks', 'left');
  const lbScreen = new PartLabel(ui, '2.8 吋螢幕', 'screen', 'right');
  // 旁白 13；200 公尺（policy.js CABINET_GEOFENCE_M）、QR Code 每 30 秒更新（CABINET_QR_REFRESH_SECONDS），手冊 PDF 第 50、102 頁
  const tB = new Title(ui, '[200 公尺] 內　掃描 QR Code', 'QR Code 每 30 秒更新');
  const tC = new Title(ui, '[60 秒] 內　輸入兩位數字', '數字相符，指定的櫃門才會開啟');
  const tD = new Title(ui, '關上櫃門　[登記存書]', '並通知買家取書');
  const tE = new Title(ui, '整合 [臺北市開放資料]', '前往書櫃的捷運、公車與 YouBike 資訊');
  const popBox = new PopBox(ui);
  const digits = new DigitFly(ui, SELLER);

  const WORD_OUT = 1.0;
  // 12：硬體透視
  const X0 = onBeat(SEC, 2.4), X1 = onBeat(SEC, 7.3);
  const F_BOARD = onBeat(SEC, 3.1), F_LOCKS = onBeat(SEC, 4.5), F_SCREEN = onBeat(SEC, 5.9);
  // 13：遠處被拒 → 走到書櫃前 → 螢幕浮出 → QR Code 更新 → 掃描 → 確認
  const FAR = X1 + 0.1;
  const S_UP = 7.4;
  const ERR = onBeat(SEC, S_UP + 1.25), ERR_OUT = ERR + 1.7;
  const TAP_RESCAN = ERR_OUT - 0.1;
  const SCAN0 = onBeat(SEC, TAP_RESCAN + 0.4);
  const NEAR0 = ERR_OUT + 0.15, NEAR1 = NEAR0 + 1.2;
  const POP_UP = onBeat(SEC, NEAR1);
  const QR_SWAP = onBeat(SEC, POP_UP + 1.0);
  const SCAN = onBeat(SEC, QR_SWAP + 0.35);
  const CONFIRM = onBeat(SEC, SCAN + 0.7);
  const MATCH = onBeat(SEC, CONFIRM + 0.7);
  // 14：倒數每秒換一張手機畫面，與書櫃螢幕同步；數字抵達時手機剛好換成 57 秒
  const TICK = MATCH - 0.17;
  const FLY0 = onBeat(SEC, MATCH + 1.1), FLY1 = FLY0 + 0.8;
  const OPENING = onBeat(SEC, FLY1 + 0.6);
  const UNLOCK = onBeat(SEC, OPENING + 0.7);
  const DOORCARD = onBeat(SEC, UNLOCK + 0.6);
  const PUT0 = UNLOCK + 1.3, PUT1 = PUT0 + 0.85;
  // 15：關門 → 作業完成 → 交棒給買家 → 存書通知
  const CLOSE = onBeat(SEC, L15.at - 0.15);
  const DONE = CLOSE + 0.55;
  // 書櫃與浮出的螢幕留在左側（作業完成），右側的賣家手機往右下後方退開、買家手機從右側接力滑入同一位置
  const RELAY = DONE + 0.65;
  const BANNER0 = RELAY + 0.85, BANNER1 = BANNER0 + 0.36;
  const BPOP = onBeat(SEC, BANNER1);
  // 16：前往書櫃 → 捲到交通資訊 → 三項依拍點往右展開
  const GUIDE = onBeat(SEC, L16.at + 0.25);
  const POP_DOWN = GUIDE - 1.05;
  const CAB_OUT = POP_DOWN + 0.35;
  const SCROLL0 = GUIDE + 0.55, SCROLL1 = SCROLL0 + 0.45;
  const SP0 = onBeat(SEC, SCROLL1 + 0.05);
  const HALF = (onBeat(SEC, SP0 + 0.55) - SP0) / 2;
  const EXIT0 = OUT - 0.95, EXIT1 = OUT - 0.05;
  // 手機往下退場前，展開的三列必須完全收回（否則會被帶進字幕區）
  const SP_OUT = EXIT0 - 0.75;

  const seller: Step[] = [
    [-9, 'v_cab_far'],
    [SCAN0, 'v_cab_scan_0', 0, 0.3],
    [QR_SWAP, 'v_cab_scan_1', 0, 0.12],
    [SCAN, 'v_cab_checking', 0, 0.25],
    [CONFIRM, 'v_cab_confirm', 0, 0.3],
    [MATCH, 'v_cab_match_59', 0, 0.25],
    [TICK + 1, 'v_cab_match_58', 0, 0.05],
    [FLY1 - 0.04, 'v_cab_match_25', 0, 0.1],
    [OPENING, 'v_cab_opening', 0, 0.25],
    [UNLOCK, 'v_cab_open_30', 0, 0.3],
    [UNLOCK + 1, 'v_cab_open_29', 0, 0.05],
    [UNLOCK + 2, 'v_cab_open_28', 0, 0.05],
    [UNLOCK + 3, 'v_cab_open_27', 0, 0.05],
    [DONE, 'v_cab_done', 0, 0.35],
  ];
  // 橫幅動畫與捲動的連續畫面由截圖工具輸出（public/v2/sequences.json），world.load() 之後才有，所以播放時才組
  let buyer: Step[] | null = null;
  const buildBuyer = (): Step[] => [
    [-9, 'v_cab_home'],
    ...frameSteps(SEQS.cab_banner ?? [], BANNER0, BANNER1),
    [GUIDE, 'v_cab_guide', 1, 0.5],
    ...frameSteps((SEQS.cab_guide_scroll ?? []).slice(1), SCROLL0, SCROLL1),
  ];
  stepCues([[-9, ''], [GUIDE, '', 1]]);
  cue('swipe', SCROLL0, { gain: 0.4 });

  const taps = [
    new TapOn(ui, SELLER, 'tap_cab_rescan', TAP_RESCAN),
    new TapOn(ui, SELLER, 'tap_cab_open', MATCH - 0.62),
    new TapOn(ui, SELLER, 'tap_cab_confirm', OPENING - 0.6),
    new TapOn(ui, BUYER, 'tap_cab_banner', GUIDE - 0.45),
  ];

  // 音效：只對應畫面上的動作
  cue('power', X0 + 0.1, { gain: 0.5 });
  [F_BOARD, F_LOCKS, F_SCREEN].forEach((t) => cue('tick', t, { gain: 0.6 }));
  cue('alert', ERR, { gain: 0.6, pan: 0.2 });
  cue('lift', POP_UP, { gain: 0.7, pan: -0.4 });
  cue('digital', QR_SWAP, { gain: 0.5, pan: -0.4 });
  cue('scan', SCAN - 0.7, { dur: 0.7, pan: 0.3 });
  cue('beep', SCAN, { pan: 0.3 });
  cue('select', CONFIRM, { gain: 0.5, pan: 0.3 });
  cue('zip', FLY0, { dur: 0.8, pan: 0 });
  cue('key', FLY1 - 0.06, { pan: 0.3, gain: 0.5 }); cue('key', FLY1 + 0.02, { pan: 0.3, gain: 0.5 });
  cue('unlock', UNLOCK, { pan: -0.2 });
  cue('door_open', UNLOCK + 0.05, { dur: 0.6, pan: -0.2 });
  cue('pop', DOORCARD, { gain: 0.6, pan: 0.3 });
  cue('book', PUT1, { pan: -0.2 });
  cue('door_close', CLOSE, { dur: 0.55, pan: -0.2 });
  cue('slam', CLOSE + 0.55, { pan: -0.2, gain: 0.8 });
  cue('success', DONE + 0.05, { pan: 0 });
  cue('banner', BANNER0, { gain: 0.8, pan: 0.2 });
  cue('notify', BANNER0 + 0.05, { gain: 0.9, pan: 0.2 });
  cue('pop', BPOP, { gain: 0.5, pan: 0.2 });
  [0, 1, 2].forEach((i) => cue('pop', SP0 + i * HALF, { gain: 0.55, pan: 0.3 }));

  const P = (x: number, y: number, z: number, rx: number, ry: number, rz: number, s: number): Pose => ({ x, y, z, rx, ry, rz, s });
  // 書櫃：由下方升起 → 緩慢轉動（透視） → 退到左後方的遠處（賣家還在捷運站） → 推近到畫面中央偏左（走到書櫃前） → 開門時略微推近 → 往左退出
  const NEAR = P(-0.17, -0.1, 0, 0.05, 0.3, 0, 1.55);
  const cab: [number, Pose][] = [
    [WORD_OUT + 0.05, P(0.0, -2.5, 0, -0.3, 0.95, 0.04, 1.75)],
    [WORD_OUT + 1.3, P(0.0, -0.15, 0, 0.07, 0.55, 0, 1.75)],
    [X1 - 0.3, P(0.0, -0.15, 0, 0.05, -0.2, 0, 1.78)],
    [FAR + 1.2, P(-0.62, -0.02, -55, 0.07, 0.42, 0, 1.6)],
    [NEAR0, P(-0.6, -0.03, -55, 0.07, 0.38, 0, 1.6)],
    [NEAR1, NEAR],
    [UNLOCK - 0.3, { ...NEAR, ry: 0.28, s: 1.57 }],
    [UNLOCK + 0.7, { ...NEAR, x: -0.18, y: -0.12, ry: 0.27, s: 1.62 }],
    [CAB_OUT, { ...NEAR, x: -0.18, y: -0.12, ry: 0.24, s: 1.64 }],
    [CAB_OUT + 0.8, P(-2.4, -0.15, 0, 0.06, 0.7, 0.03, 1.6)],
  ];
  // 賣家手機：由右下升起（App 顯示距離太遠）→ 重新掃描時移到右側（書櫃推近） → 作業完成後往右下後方退場
  const SIDE = P(0.6, -0.31, 0, 0.04, -0.26, 0.01, 1.32);
  const sel: [number, Pose][] = [
    [S_UP, P(0.62, -2.3, 0, 0.5, -0.55, 0.1, 1.38)],
    [S_UP + 1.2, P(0.22, -0.33, 0, 0.05, -0.16, 0.01, 1.42)],
    [NEAR0, P(0.21, -0.32, 0, 0.03, -0.12, 0, 1.43)],
    [NEAR1, SIDE],
    [UNLOCK, { ...SIDE, ry: -0.21, s: 1.33 }],
    [RELAY, { ...SIDE, x: 0.59, ry: -0.21, s: 1.34 }],
    [RELAY + 0.9, P(0.92, -2.3, -14, -0.25, -0.5, 0.06, 1.28)],
  ];
  // 買家手機：從右側滑入賣家手機讓出的位置 → 書櫃往左退出後跟著往左 → 展開交通資訊時再往左讓位 → 往下退場
  const buy: [number, Pose][] = [
    [RELAY + 0.2, P(1.75, -0.36, 0, 0.04, -0.6, -0.04, 1.34)],
    [RELAY + 1.0, { ...SIDE, ry: -0.2, s: 1.34 }],
    [CAB_OUT, { ...SIDE, x: 0.58, ry: -0.17, s: 1.35 }],
    [GUIDE + 0.9, P(0.06, -0.33, 0, 0.03, -0.08, -0.01, 1.4)],
    [SP0 + 0.55, P(-0.27, -0.32, 0, 0.03, 0.13, 0, 1.41)],
    [EXIT0, P(-0.29, -0.32, 0, 0.02, 0.1, 0, 1.42)],
    [EXIT1, P(-0.29, -2.8, 0, -0.3, 0.12, 0.04, 1.4)],
  ];
  fly(WORD_OUT + 0.05, WORD_OUT + 1.3, 0.6, 0);
  fly(FAR, FAR + 1.2, 0.4, -0.4);
  fly(S_UP, S_UP + 1.2, 0.5, 0.3);
  fly(NEAR0, NEAR1, 0.5, -0.2);
  fly(RELAY, RELAY + 0.9, 0.4, 0.4);
  fly(RELAY + 0.2, RELAY + 1.0, 0.5, 0.5);
  fly(CAB_OUT, CAB_OUT + 0.8, 0.6, -0.5);
  fly(EXIT0, EXIT1, 0.5, 0);

  /** 浮出程度：t0 起 0.5 秒浮出（帶一點回彈），t1 起 0.35 秒收回。 */
  const k = (t: number, t0: number, t1: number) => back(soft(t, t0, t0 + 0.5) * (1 - soft(t, t1, t1 + 0.35)));
  const dim = (ps: Pop[]) => 1 - 0.4 * Math.max(0, ...ps.map((p) => Math.min(1, p.k)));

  const kiosk = (t: number, pose: Pose): KioskParams => {
    // QR Code：換碼前倒數條逐漸歸零，換碼瞬間閃白換成下一組（每 30 秒更新）
    const refresh = t < QR_SWAP ? Math.min(1, 0.8 + 0.2 * Math.max(0, t - NEAR0) / (QR_SWAP - NEAR0)) : (t - QR_SWAP) / 30;
    const flash = Math.max(0, 1 - Math.abs(t - QR_SWAP) / 0.22);
    // 浮出的螢幕停在書櫃左側（外框寬 450px），書櫃推近、開門時的微小移動不會帶動它；
    // 不用回彈：回彈會把它往外多推約 40px 而超出畫面左緣
    const pop: KioskPop = { ...popAt(world, pose, 300, 545, 450, POP_Z), k: soft(t, POP_UP, POP_UP + 0.55) * (1 - soft(t, POP_DOWN, POP_DOWN + 0.35)) };
    const base = { refresh, seconds: 60, digits: 1, check: 0, qr: t < QR_SWAP ? 0 : 1, flash, clock: '14:25', pop };
    if (t < CONFIRM) return { ...base, state: 'qr' };
    if (t < MATCH) return { ...base, state: 'busy', seconds: 59 };
    if (t < OPENING) return { ...base, state: 'match', seconds: Math.max(56, 59 - Math.floor(t - TICK)), digits: 1 - 0.7 * soft(t, FLY0, FLY0 + 0.15) };
    if (t < UNLOCK) return { ...base, state: 'opening' };
    if (t < DONE) return { ...base, state: 'open', seconds: 30 - Math.floor(t - UNLOCK) };
    return { ...base, state: 'done', check: soft(t, DONE, DONE + 0.5) };
  };

  return (t: number) => {
    word.at(t, 0.1, WORD_OUT);
    tA.at(t, WORD_OUT + 0.45, X1);
    tB.at(t, FAR + 0.5, MATCH - 0.45);
    tC.at(t, MATCH + 0.2, CLOSE - 0.45);
    tD.at(t, CLOSE + 0.2, GUIDE - 0.45);
    tE.at(t, GUIDE + 0.2, OUT - 0.75);

    const xray = soft(t, X0, X0 + 0.6) * (1 - soft(t, X1, X1 + 0.6));
    if (t > WORD_OUT && t < CAB_OUT + 0.85) {
      const pose = glide(t, cab, SIGMA);
      world.frame.cabinet = {
        pose, xray, kiosk: kiosk(t, pose),
        door: soft(t, UNLOCK + 0.05, UNLOCK + 0.65) * (1 - soft(t, CLOSE, CLOSE + 0.55)),
        deposit: soft(t, PUT0, PUT1),
      };
      const fb = soft(t, F_BOARD, F_BOARD + 0.4) * (1 - soft(t, F_SCREEN - 0.4, F_SCREEN));
      const fl = soft(t, F_LOCKS, F_LOCKS + 0.4) * (1 - 0.6 * soft(t, F_SCREEN, F_SCREEN + 0.4)) * (1 - soft(t, X1, X1 + 0.4));
      world.frame.after.push(() => {
        world.cabinet.setFocus('board', fb);
        world.cabinet.setFocus('locks', fl);
      });
    }
    // 標名依旁白順序輪替：ESP32-S3 與螢幕都在頂列、高度相近，前者收起後後者才出現
    lbBoard.at(world, t, F_BOARD + 0.1, F_SCREEN - 0.4);
    lbLocks.at(world, t, F_LOCKS + 0.1, X1 - 0.2);
    lbScreen.at(world, t, F_SCREEN + 0.1, X1 - 0.2);
    popBox.at(world);

    if (t > S_UP && t < RELAY + 0.95) {
      const ps: Pop[] = [
        { id: 'cab_far', cut: 'cut_cab_far', k: k(t, ERR, ERR_OUT), grow: 0.12 },
        { id: 'cab_door', cut: 'cut_cab_open_door', k: k(t, DOORCARD, CLOSE - 0.35), grow: 0.15 },
      ];
      world.frame.phones[SELLER] = { pose: glide(t, sel, SIGMA), scr: seq(t, seller), glow: dim(ps), pops: ps };
    }
    if (t > RELAY + 0.15 && t < OUT) {
      buyer ??= SEQS.cab_banner ? buildBuyer() : null;
      const rows = ['cut_cab_mrt_row', 'cut_cab_fare', 'cut_cab_bus_stop'];
      const out = spread(rows, 0.5, 'col');
      const ps: Pop[] = [
        { id: 'cab_banner', cut: 'cut_cab_banner', k: k(t, BPOP, GUIDE - 0.85), grow: 0.15 },
        ...rows.map((cut, i) => ({ id: `cab_tr${i}`, cut, k: k(t, SP0 + i * HALF, SP_OUT), grow: 0.5, ...out[i], dz: i * 0.1 })),
      ];
      world.frame.phones[BUYER] = { pose: glide(t, buy, SIGMA), scr: buyer ? seq(t, buyer) : { a: 'v_cab_home' }, glow: dim(ps), pops: ps };
    }
    taps.forEach((tp) => tp.at(world, t));
    digits.at(world, t, FLY0, FLY1);
  };
}
