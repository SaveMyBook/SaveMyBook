import { type Pose } from '../lib/kf';
import { cue, fly } from '../lib/cues';
import { ADMIN, SEQS, type World, type Pop } from '../world';
import type { KioskParams, KioskPop } from '../three/textures';
import { seq, stepCues, frameSteps, back, type Step } from '../scenes/kit';
import { line } from './kit2';
import { Title, ChapterWord, glide, soft } from './kit4';
import { onBeat, TapOn, spread } from './kit5';
import { PopBox, popAt, POP_Z } from './x_cabinet';

const SEC = 'admin';
const SIGMA = 0.42;

/**
 * 第 8 章 管理後台（旁白 22 後台模組、23 配對新書櫃）。
 * 22：管理員手機由下方升起（管理後台首頁），往下捲到四個模組都在畫面上，
 *     內容審核、訂單管理、交易爭議、系統公告依旁白順序往手機右側展開。
 * 23：手機往右讓位、App 內推入新北高工的書櫃裝置頁；書櫃由左下升起，螢幕浮出放大顯示八位數配對碼 0151-7752，
 *     管理員點配對裝置、在數字鍵盤上逐字輸入同一組配對碼 → 等待裝置連線 → 完成配對，
 *     書櫃螢幕同時改為書櫃名稱與 QR Code（配對後的閒置畫面）→ 往下退場。
 * 配對碼效期 10 分鐘、配對後閒置時顯示 QR Code：複評版手冊 PDF 第 127 頁（書櫃裝置配對）；
 * 配對碼畫面版面同韌體 ui.cpp 的 drawPairing（textures.ts 的 pair 狀態）。
 */
export function sAdmin(world: World, ui: HTMLElement, fx: HTMLElement) {
  world.cabinet.kiosk.setScale(4);
  const L22 = line('22'), L23 = line('23');
  const OUT = L23.end;

  const word = new ChapterWord(fx, '管理後台');
  // 旁白 22
  const tA = new Title(ui, '管理後台　[整合在 App]', '上架審核、訂單、爭議與公告');
  // 旁白 23
  const tB = new Title(ui, '輸入 [配對碼]　連線新書櫃', '書櫃螢幕顯示八位數配對碼');
  const popBox = new PopBox(ui);

  const WORD_OUT = 1.0;
  const RISE = WORD_OUT + 0.05;
  // 22：捲到四個模組都在畫面上 → 依旁白順序往右展開（旁白「可以處理上架審核」之前開始，四列完全浮出後停 1.5 秒以上）
  const SCROLL0 = RISE + 1.3, SCROLL1 = SCROLL0 + 0.45;
  const SP0 = onBeat(SEC, L22.at + 1.8);
  const HALF = (onBeat(SEC, SP0 + 0.5) - SP0) / 2;
  const SP_OUT = onBeat(SEC, L22.at + 4.6);
  // 23：推入書櫃裝置頁 → 點配對裝置 → 對話框與數字鍵盤 → 逐字輸入 → 配對 → 等待 → 完成
  // 四列由上往下依序收回（前三列都是往上回到原位，上面的先走，路徑不會疊到），全部收完（SP_OUT + 0.59）之後手機才往右移，書櫃再從左下升起
  const HOLD = SP_OUT + 1.1;
  const PUSH = SP_OUT + 0.9;
  const CAB_IN = HOLD + 0.25;
  // 推入完成後才點「配對裝置」（點擊動畫 0.32 秒後按下）
  const TAP_OPEN = PUSH + 0.82;
  const DIALOG = TAP_OPEN + 0.13;
  const POP_UP = onBeat(SEC, CAB_IN + 1.1);
  const TYPE0 = Math.max(DIALOG + 0.45, L23.at + 0.35), TYPE1 = TYPE0 + 1.15;
  const WAIT = onBeat(SEC, TYPE1 + 0.7);
  const FIELD_UP = DIALOG + 0.15;
  const DONE = onBeat(SEC, WAIT + 0.45);
  const EXIT0 = OUT - 0.95, EXIT1 = OUT - 0.05;

  let steps: Step[] | null = null;
  const build = (): Step[] => [
    [-9, 'v_adm_home'],
    ...frameSteps((SEQS.adm_scroll ?? []).slice(1), SCROLL0, SCROLL1),
    [PUSH, 'v_adm_device', 1, 0.5],
    [DIALOG, 'v_adm_pair_t00', 0, 0.25],
    ...frameSteps((SEQS.adm_pair_type ?? []).slice(1), TYPE0, TYPE1),
    [WAIT, 'v_adm_pair_wait', 0, 0.2],
    [DONE, 'v_adm_pair_done', 0, 0.25],
  ];
  stepCues([[-9, ''], [PUSH, '', 1]]);
  cue('swipe', SCROLL0, { gain: 0.4 });
  [0, 1, 2, 3].forEach((i) => cue('pop', SP0 + i * HALF, { gain: 0.55, pan: 0.3 }));
  cue('lift', POP_UP, { gain: 0.7, pan: -0.4 });
  cue('sheet', DIALOG, { gain: 0.5, pan: 0.3 });
  cue('pop', FIELD_UP, { gain: 0.5, pan: 0.3 });
  for (let i = 0; i < 8; i++) cue('key', TYPE0 + (i / 7) * (TYPE1 - TYPE0), { gain: 0.35, pan: 0.3 });
  cue('success', DONE + 0.05, { gain: 0.9 });
  cue('digital', DONE + 0.1, { pan: -0.4, gain: 0.6 });
  const taps = [
    new TapOn(ui, ADMIN, 'tap_adm_pair_open', TAP_OPEN - 0.32),
    new TapOn(ui, ADMIN, 'tap_adm_pair', WAIT - 0.36),
  ];

  const P = (x: number, y: number, z: number, rx: number, ry: number, rz: number, s: number): Pose => ({ x, y, z, rx, ry, rz, s });
  // 管理員手機：由下方升起 → 捲動後往左讓位給展開的模組 → 往右讓位給書櫃 → 往下退場
  const SIDE = P(0.6, -0.31, 0, 0.04, -0.26, 0.01, 1.32);
  const phone: [number, Pose][] = [
    [RISE, P(-0.1, -2.0, 0, 0.55, -0.45, 0.1, 1.4)],
    [RISE + 1.15, P(-0.02, -0.33, 0, 0.06, -0.12, 0.02, 1.4)],
    [SCROLL1, P(0.0, -0.32, 0, 0.03, -0.04, 0, 1.41)],
    [SP0 + 0.5, P(-0.27, -0.32, 0, 0.03, 0.13, 0, 1.41)],
    [SP_OUT, P(-0.29, -0.32, 0, 0.02, 0.1, 0, 1.42)],
    [HOLD, P(-0.29, -0.32, 0, 0.02, 0.09, 0, 1.42)],
    [HOLD + 1.0, SIDE],
    [EXIT0, { ...SIDE, ry: -0.22, s: 1.33 }],
    [EXIT1, P(0.6, -2.8, 0, -0.35, -0.2, 0.04, 1.3)],
  ];
  // 書櫃：由左下升起（姿態同智慧書櫃段） → 慢慢轉動 → 往下退場
  const NEAR = P(-0.17, -0.1, 0, 0.05, 0.3, 0, 1.55);
  const cab: [number, Pose][] = [
    [CAB_IN, P(-0.35, -2.6, 0, -0.35, 0.55, 0.03, 1.55)],
    [CAB_IN + 1.1, NEAR],
    [EXIT0, { ...NEAR, ry: 0.26, s: 1.58 }],
    [EXIT1, P(-0.25, -2.9, 0, -0.25, 0.3, 0.02, 1.55)],
  ];
  fly(RISE, RISE + 1.15, 0.6, 0);
  fly(SP0, SP0 + 0.5, 0.3, -0.3);
  fly(HOLD, HOLD + 1.0, 0.5, 0.5);
  fly(CAB_IN, CAB_IN + 1.1, 0.6, -0.4);
  fly(EXIT0, EXIT1, 0.5, 0);

  const k = (t: number, t0: number, t1: number) => back(soft(t, t0, t0 + 0.5) * (1 - soft(t, t1, t1 + 0.35)));
  const dim = (ps: Pop[]) => 1 - 0.4 * Math.max(0, ...ps.map((p) => Math.min(1, p.k)));

  const kiosk = (t: number, pose: Pose): KioskParams => {
    // 浮出的螢幕停在書櫃左側；退場前收回螢幕上（浮出元件不可跟著進入字幕區）
    const pop: KioskPop = { ...popAt(world, pose, 300, 548, 440, POP_Z), k: soft(t, POP_UP, POP_UP + 0.55) * (1 - soft(t, EXIT0 - 0.3, EXIT0 + 0.05)) };
    // 配對碼與剩餘時間（效期 10 分鐘）；配對完成後改為書櫃名稱與 QR Code
    if (t < DONE) return { state: 'pair', refresh: 0, seconds: 582 - Math.floor(t - CAB_IN), digits: 1, check: 0, code: '0151-7752', total: 600, clock: '14:25', pop };
    return { state: 'qr', refresh: (t - DONE) / 30, seconds: 60, digits: 1, check: 0, qr: 2, header: '新北高工', clock: '14:25', flash: Math.max(0, 1 - Math.abs(t - DONE - 0.12) / 0.2), pop };
  };

  return (t: number) => {
    word.at(t, 0.1, WORD_OUT);
    tA.at(t, WORD_OUT + 0.45, HOLD - 0.15);
    tB.at(t, HOLD + 0.5, OUT - 0.75);

    if (t > WORD_OUT && t < OUT) {
      steps ??= SEQS.adm_scroll && SEQS.adm_pair_type ? build() : null;
      // 直欄依畫面上的上下順序排（浮出與收回的路徑不交錯），浮出順序依旁白：審核、訂單、爭議、公告
      const rows = ['cut_adm_orders', 'cut_adm_disputes', 'cut_adm_review', 'cut_adm_notice'];
      const order = [1, 2, 0, 3];
      // 間距 40pt（浮出時往鏡頭抬起，透視會放大，24pt 會黏在一起），整欄上移 90pt，最下面一列不進字幕區
      const out = spread(rows, 0.5, 'col', 40).map((o) => ({ ...o, dy: o.dy - 90 }));
      // 配對碼輸入框原地放大浮出，內容跟著逐字輸入換成同一時刻的去背元件（t00～t08，時間同 frameSteps）
      const typed = Math.max(0, Math.min(8, Math.floor(1 + 7 * (t - TYPE0) / (TYPE1 - TYPE0) + 1e-6)));
      const field = `cut_adm_field_t${String(t < TYPE0 ? 0 : typed).padStart(2, '0')}`;
      const ps: Pop[] = [
        ...rows.map((cut, i) => ({ id: `adm_row${i}`, cut, k: k(t, SP0 + order[i] * HALF, SP_OUT + i * 0.08), grow: 0.5, ...out[i], dz: i * 0.1 })),
        { id: 'adm_field', cut: field, k: k(t, FIELD_UP, WAIT - 0.4), grow: 0.35 },
      ];
      world.frame.phones[ADMIN] = { pose: glide(t, phone, SIGMA), scr: steps ? seq(t, steps) : { a: 'v_adm_home' }, glow: dim(ps), pops: ps };
    }
    if (t > CAB_IN && t < OUT) {
      const pose = glide(t, cab, SIGMA);
      world.frame.cabinet = { pose, kiosk: kiosk(t, pose) };
    }
    popBox.at(world);
    taps.forEach((tp) => tp.at(world, t));
  };
}
