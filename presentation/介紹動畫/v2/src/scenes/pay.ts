import { span, lerp, easeInOut, type Pose } from '../lib/kf';
import { BUYER, type World } from '../world';
import { Headline, Caption, Mark, Tap, at, frame, seq, stepCues, track, mix, easeIn, type Step } from './kit';
import { R, KEYPAD, PIN } from './story';

/**
 * 付款（買家海嫄）：交易密碼鍵盤由下展開 → 逐格輸入 → 付款成功 → 款項進入平台暫管（硬幣由 escrow.ts 處理）。
 * 旁白（段落內秒數）：sec2 0.6、hold 6.0。
 */
export function pay(world: World, ui: HTMLElement) {
  const tH = at('hold');
  // 一開始就推近到鍵盤，付款驗證的說明放在旁邊的說明文字；標題留給暫管
  const headHold = new Headline(ui, '款項先由平台暫管', '交易完成後才撥給賣家');
  const TAP0 = 1.2, GAP = 0.32;
  const steps: Step[] = [[-1, 'b_chat_4'], [0.0, 'b_pay_0', 3, 0.5]];
  PIN.forEach((_, i) => steps.push([TAP0 + i * GAP + 0.3, `b_pay_${i + 1}`, 0, 0.08]));
  steps.push([TAP0 + PIN.length * GAP + 0.5, 'b_pay_done', 0, 0.35]);
  stepCues(steps);
  const taps = PIN.map((d, i) => new Tap(ui, BUYER, KEYPAD[d][0], KEYPAD[d][1], TAP0 + i * GAP));
  const doneAt = TAP0 + PIN.length * GAP + 0.5;
  const markDone = new Mark(ui, BUYER, R.payDone).register(doneAt + 0.4);
  const capPin = new Caption(ui, '交易密碼', '輸入 6 位交易密碼', '也可改用生物辨識', 120);
  const capDone = new Caption(ui, '付款完成', '等待賣家存書', '付款明細可在訂單中查看', 120);

  const CENTER: Pose = { x: 0, y: -0.12, z: 0, rx: 0.03, ry: 0, rz: 0, s: 1.15 };
  // 金額、圓點與鍵盤都在底部單內：取景整張底部單，讓圓點與按鍵同時清楚
  const sheetF = frame({ x: 0, y: 250, w: 393, h: 520 }, 1130, 600, 560);
  const doneF = frame(R.payDone, 1120, 560, 560);
  const AWAY: Pose = { x: 1.3, y: -0.2, z: -6, rx: 0.05, ry: -0.7, rz: 0, s: 1.0 };

  return (t: number) => {
    headHold.at(t, tH + 0.1, 9.5);
    if (t > -0.5 && t < 11.2) {
      let pose = track(t, [[-0.5, CENTER], [0.2, CENTER], [0.9, sheetF], [doneAt, sheetF], [doneAt + 0.5, doneF], [5.6, doneF], [6.2, CENTER]]);
      pose = mix(pose, AWAY, easeIn(span(t, 9.6, 10.8)));
      world.frame.phones[BUYER] = { pose, scr: seq(t, steps) };
    }
    taps.forEach((tp) => tp.at(world, t));
    markDone.at(world, t, doneAt + 0.5, 5.6);
    capPin.at(t, 1.0, doneAt + 0.2, 540);
    capDone.at(t, doneAt + 0.65, 5.6, 540);
    void lerp; void easeInOut;
  };
}
