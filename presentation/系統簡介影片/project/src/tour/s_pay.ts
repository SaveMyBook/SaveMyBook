import { type Pose } from '../lib/kf';
import { cue, fly } from '../lib/cues';
import { SELLER, BUYER, RING, type World, type Pop } from '../world';
import { seq, back, type Step } from '../scenes/kit';
import { line } from './kit2';
import { Title, ChapterWord, glide, soft } from './kit4';
import { onBeat } from './kit5';

const SEC = 'pay';
const SIGMA = 0.42;
/** Face ID 付款的買家手機（與交易密碼那支並列，表示兩種驗證方式擇一）。 */
const FACE = RING[0];

/**
 * 第 4 章 付款暫管（旁白 11），畫面全部由 savemybook_app/tool/video_shots/pay_after_test.dart 產生。
 * 兩支買家手機一起升起（右邊稍後方）：左邊在《HTML & CSS》的付款面板輸入交易密碼，六個點逐一填滿；右邊是系統的 Face ID 驗證。
 * 左邊付款成功時，右邊往下退場、賣家手機沿右側滑入，「待撥款金額 250」整張卡片浮出 → 一起往下退場。
 * 旁白音檔的停頓在 L11 + 3.08～3.38：前半句講驗證（交易密碼、生物辨識），後半句「款項先由平台暫管」。
 * 出處：付款僅接受生物辨識或交易密碼【手冊 p97】；款項由平台暫管，買家完成訂單或取書滿 24 小時後撥付賣家【手冊 p6、p13】。
 */
export function sPay(world: World, ui: HTMLElement, fx: HTMLElement) {
  const L11 = line('11');
  const OUT = L11.end;

  const word = new ChapterWord(fx, '付款暫管');
  const tA = new Title(ui, '交易密碼或[生物辨識]', '付款前先驗證身分');
  const tB = new Title(ui, '款項先由[平台暫管]', '買家取書滿 24 小時後，才撥給賣家');

  const WORD_OUT = 1.0;
  const RISE = WORD_OUT + 0.05;
  const BEAT = onBeat(SEC, 2.0) - onBeat(SEC, 1.6);
  const HALF = BEAT / 2;
  // 六碼對齊半拍，落在旁白「交易密碼」到「生物辨識」之間
  const D0 = onBeat(SEC, 1.85);
  const DIGITS = [0, 1, 2, 3, 4, 5].map((i) => D0 + i * HALF);
  const DONE = DIGITS[5] + HALF;
  // 同一時間最多兩支手機：Face ID 那支先往下退場，賣家手機再沿右側弧線滑入同一個位置；待撥款項卡片浮出、停 1.2 秒後收回，最後 0.7 秒退場
  const FACE_OUT = DONE - 0.6;
  const HAND0 = FACE_OUT + 0.35, HAND1 = HAND0 + 0.8;
  const P0 = onBeat(SEC, HAND1 - 0.05);
  const P1 = P0 + 0.5 + 1.2;
  // 卡片須在手機開始退場前完全收回，否則會被帶進字幕區
  const EXIT0 = Math.max(OUT - 0.7, P1 + 0.37), EXIT1 = OUT - 0.02;
  const TB = P0 - 0.3;

  const pin: Step[] = [
    [-9, 'v_pay_pin_0'],
    ...DIGITS.map((t, i) => [t, `v_pay_pin_${i + 1}`, 0, 0.05] as Step),
    [DONE, 'v_pay_done', 0, 0.3],
  ];
  DIGITS.forEach((t) => cue('key', t, { gain: 0.45 }));
  cue('success', DONE + 0.05, { gain: 0.8 });
  cue('scan', RISE + 0.9, { dur: 0.6, gain: 0.5, pan: 0.3 });
  cue('check', RISE + 1.55, { gain: 0.5, pan: 0.3 });
  fly(FACE_OUT, FACE_OUT + 0.7, 0.4, 0.3);
  fly(HAND0, HAND1, 0.5, 0.4);
  cue('lift', P0, { gain: 0.8 });

  const P = (x: number, y: number, z: number, rx: number, ry: number, rz: number, s: number): Pose => ({ x, y, z, rx, ry, rz, s });
  // 交易密碼：由左下升起 → 正面慢推 → 往下退場（全程留在左側，不被其他手機遮住）
  const pinKeys: [number, Pose][] = [
    [RISE, P(-0.34, -2.0, 0, 0.5, 0.4, -0.08, 1.38)],
    [RISE + 1.05, P(-0.23, -0.28, 0, 0.05, 0.13, -0.01, 1.38)],
    [DONE, P(-0.22, -0.27, 0, 0.03, 0.09, 0, 1.4)],
    [P0 + 0.5, P(-0.24, -0.27, 0, 0.03, 0.12, 0, 1.39)],
    [EXIT0, P(-0.24, -0.27, 0, 0.02, 0.1, 0, 1.4)],
    [EXIT1, P(-0.24, -2.1, 0, -0.3, 0.14, 0.04, 1.38)],
  ];
  // Face ID：同時由右下升起、在稍後方 → 旁白說到「生物辨識」後往下退場，讓出右側
  const faceKeys: [number, Pose][] = [
    [RISE + 0.05, P(0.42, -2.0, -4, 0.5, -0.45, 0.08, 1.28)],
    [RISE + 1.05, P(0.29, -0.29, -4, 0.05, -0.16, 0.01, 1.28)],
    [FACE_OUT, P(0.28, -0.29, -4, 0.03, -0.12, 0, 1.29)],
    [FACE_OUT + 0.7, P(0.3, -2.2, -4, -0.3, -0.1, 0.04, 1.28)],
  ];
  // 賣家：沿右側弧線滑入 Face ID 手機讓出的位置 → 正面慢推 → 往下退場
  const sellerKeys: [number, Pose][] = [
    [HAND0, P(1.7, -0.31, 0, 0.04, -0.6, -0.04, 1.36)],
    [HAND1, P(0.27, -0.27, 0, 0.03, -0.12, 0, 1.36)],
    [EXIT0, P(0.26, -0.27, 0, 0.02, -0.08, 0, 1.38)],
    [EXIT1, P(0.26, -2.1, 0, -0.3, -0.06, -0.04, 1.36)],
  ];

  fly(RISE, RISE + 1.05, 0.6, 0);
  fly(EXIT0, EXIT1, 0.5, 0);

  const k = (t: number, t0: number, t1: number) => back(soft(t, t0, t0 + 0.5) * (1 - soft(t, t1, t1 + 0.35)));
  const dim = (ps: Pop[]) => 1 - 0.4 * Math.max(0, ...ps.map((p) => Math.min(1, p.k)));

  return (t: number) => {
    word.at(t, 0.1, WORD_OUT);
    tA.at(t, WORD_OUT + 0.45, TB - 0.05);
    tB.at(t, TB + 0.55, OUT - 0.75);

    if (t <= WORD_OUT || t >= OUT) return;
    world.frame.phones[BUYER] = { pose: glide(t, pinKeys, SIGMA), scr: seq(t, pin) };
    if (t < FACE_OUT + 1.3) world.frame.phones[FACE] = { pose: glide(t, faceKeys, SIGMA), scr: { a: 'v_pay_faceid' } };
    if (t > HAND0) {
      const ps: Pop[] = [{ id: 'pay_pending', cut: 'cut_pay_pending', k: k(t, P0, P1), grow: 0.08 }];
      world.frame.phones[SELLER] = { pose: glide(t, sellerKeys, SIGMA), scr: { a: 'v_pay_pending' }, glow: dim(ps), pops: ps };
    }
  };
}
