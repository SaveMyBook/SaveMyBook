import { cue, fly } from '../lib/cues';
import { BUYER, RING, type World, type Pop } from '../world';
import type { Pose } from '../lib/kf';
import { seq, type Step } from '../scenes/kit';
import { line, section } from './kit2';
import { glide } from './kit4';
import { onBeat } from './kit5';
import { TitleV3 } from '../v3/title';
import { CameraPath, orbit, sectionPans } from '../v3/camera';
import { fit } from '../v3/frame';
import { lift, float, under } from '../v3/pop';

const SEC = 'pay';
const FACE = RING[0];
type V = [number, number, number];

/**
 * v3 付款暫管（旁白 11）。浮出：付款成功對話框（整張不透明元件）；交易密碼圓點列的去背元件帶到白底，曾被退件，不浮出。
 * 物件放在世界座標 x≈-900 一帶，段落交界前後 0.05 秒和相鄰段落同時寫入時不會出現在別段的畫面裡。
 */
export default function sPayV3(world: World, ui: HTMLElement, _fx: HTMLElement) {
  const L11 = line('11');
  const LEN = section(SEC).end - section(SEC).start;

  // 旁白實際發聲（段落內秒數，量自 audio/out/旁白.wav）：「付款以交易密碼或生物辨識驗證」1.2–4.3、「款項先由平台暫管」4.55–6.35
  const D0 = onBeat(SEC, L11.at + 0.4);
  const HALF = (onBeat(SEC, 2.0) - onBeat(SEC, 1.6)) / 2;
  const DIGITS = [0, 1, 2, 3, 4, 5].map((i) => D0 + i * HALF);
  const DIG_END = DIGITS[5];
  const FOCUS = DIG_END + 0.15;
  const DONE = D0 + 9 * HALF;
  const POP = onBeat(SEC, DONE + 0.2);
  const EXIT = LEN - 0.9;
  // 浮出時間不能延到段落結束：完全浮出的元件隨鏡頭移出時會超出 56px 安全邊界（reelcheck 會報錯），要在移出的緩起段落回
  const POP_OUT = POP + 0.5 + 1.55;

  // 出處：複評版手冊 PDF 第 250 頁（頁碼 235）表 12-2-7；第 260 頁（頁碼 245）表 12-6-1
  const title = new TitleV3(ui, ['付款後如何保障買家？', '款項先由平台暫管'], '以交易密碼或生物辨識驗證，交易完成後才撥給賣家');

  const FP: V = [-900, 0, 0];
  const K0 = orbit(FP, 0.04, -0.09, 57, [0, 1.0, 0]);
  const K1 = orbit(FP, -0.035, -0.075, 56, [0, 1.0, 0]);
  const cam = new CameraPath([[0, K0], [LEN, K1]]);

  // 鏡頭全段推近：各姿態要用「到位時」的鏡頭取景，否則推近後手機會碰到標題或字幕帶
  const KF = cam.at(FOCUS + 0.6), KS = cam.at(POP + 0.55);
  const PIN0 = fit(world, K0, 'phone', { cx: 670, cy: 636, h: 672, yaw: 0.3, rz: 0.02 });
  const PINb = fit(world, KF, 'phone', { cx: 690, cy: 636, h: 664, yaw: 0.36, rz: 0.02, depth: 59 });
  const PIN1 = fit(world, KS, 'phone', { cx: 500, cy: 630, h: 680, yaw: 0.38, rz: 0.03 });
  const FACE0 = fit(world, K0, 'phone', { cx: 1260, cy: 638, h: 656, yaw: -0.3, rz: -0.02, depth: 62 });
  const FACEf = fit(world, KF, 'phone', { cx: 1240, cy: 632, h: 684, yaw: -0.2, rz: -0.01, depth: 58 });
  const FACE1 = fit(world, KS, 'phone', { cx: 1430, cy: 636, h: 656, yaw: -0.36, rz: -0.02, depth: 62 });
  const drift = (p: Pose, d: Partial<Pose>): Pose => ({ ...p, ...Object.fromEntries(Object.entries(d).map(([k, v]) => [k, (p[k] ?? 0) + (v ?? 0)])) });

  const pinKeys: [number, Pose][] = [
    [0, PIN0],
    [DIG_END, drift(PIN0, { ry: -0.02 })],
    [FOCUS + 0.6, PINb],
    [DONE, drift(PINb, { ry: -0.02 })],
    [POP + 0.55, PIN1],
    [LEN, drift(PIN1, { ry: -0.04 })],
  ];
  const faceKeys: [number, Pose][] = [
    [0, FACE0],
    [FOCUS, drift(FACE0, { ry: 0.02 })],
    [FOCUS + 0.6, FACEf],
    [DONE, drift(FACEf, { ry: 0.02 })],
    [POP + 0.55, FACE1],
    [LEN, drift(FACE1, { ry: 0.04 })],
  ];

  const pin: Step[] = [
    [-9, 'v_pay_pin_0'],
    ...DIGITS.map((t, i) => [t, `v_pay_pin_${i + 1}`, 0, 0.001] as Step),
    [DONE, 'v_pay_done', 0, 0.001],
  ];


  fly(0, 0.9, 0.5, 0.2);
  DIGITS.forEach((t) => cue('key', t, { gain: 0.45, pan: -0.3 }));
  cue('success', DONE + 0.05, { gain: 0.8, pan: -0.3 });
  cue('pop', POP, { gain: 0.5, pan: 0 });
  fly(EXIT, LEN, 0.5, 0.3);

  return (t: number) => {
    // 標題在提早返回之前更新：段落前後 1 秒這一層仍會顯示，沒更新的標題會停在預設的不透明狀態
    title.at(t, 1.0, EXIT - 0.45);
    if (t < -0.05 || t > LEN + 0.05) return;
    world.frame.camera = sectionPans(cam.at(t), t, LEN, { sec: SEC });

    const k = lift(t, POP, POP_OUT), f = float(t, k);
    const ps: Pop[] = [{ id: 'pay3_done', cut: 'cut_pay_done', k, grow: 0.3, dx: 700 + f.dx, dy: -60 + f.dy, dz: 2.4 + f.dz, }];
    // 對話框浮起後，原位顯示遮罩下的商品詳情頁（tools/under.py 由 v_pay_done 與 v_ov_detail 合成），不留單色空位
    world.frame.phones[BUYER] = { pose: glide(t, pinKeys, 0.42), scr: under(seq(t, pin), k, 'v_pay_done_under'), pops: ps };
    world.frame.phones[FACE] = { pose: glide(t, faceKeys, 0.42), scr: { a: 'v_pay_faceid' } };
  };
}
