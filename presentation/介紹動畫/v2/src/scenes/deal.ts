import { type Pose } from '../lib/kf';
import { cue } from '../lib/cues';
import { BUYER, type World } from '../world';
import { Headline, Caption, Chips, Mark, Tap, at, frame, seq, stepCues, track, type Step } from './kit';
import { R } from './story';

/**
 * 預約與防詐（買家海嫄）：書籍頁 → 聊聊 → 訊息往來與預約保留 → 另一則可疑訊息的提醒 → 回到聊天室按立即購買。
 * 旁白（段落內秒數）：deal1 0.8、sec3 6.2。
 */
export function deal(world: World, ui: HTMLElement) {
  const t1 = at('deal1'), t3 = at('sec3');
  const head1 = new Headline(ui, '詢問與預約，在聊天室完成', '賣家接受預約後即保留，期間他人無法購買');
  const head3 = new Headline(ui, '可疑訊息，即時提醒', '偵測站外聯絡、私下付款與常見詐騙話術');

  const steps: Step[] = [
    [-0.5, 'b_advisor'],
    [0.0, 'b_book_detail', 1, 0.45],
    [1.7, 'b_chat_1', 1, 0.45],
    [2.6, 'b_chat_2', 0, 0.3],
    [3.4, 'b_chat_3', 0, 0.3],
    [4.2, 'b_chat_4', 0, 0.3],
    [6.0, 'b_chat_warn', 2, 0.45],
    [10.9, 'b_chat_4', 2, 0.45],
  ];
  stepCues(steps);
  [2.6, 3.4, 4.2].forEach((s) => cue('bubble', s + 0.05, { pan: 0.2, gain: 0.7 }));
  cue('alert', 6.9, { pan: 0.1 });
  cue('banner', 9.7, { pan: 0.1 });
  const taps = [
    new Tap(ui, BUYER, R.detailChat.x + R.detailChat.w / 2, R.detailChat.y + R.detailChat.h / 2, 1.0),
    new Tap(ui, BUYER, R.chatBuy.x + R.chatBuy.w / 2, R.chatBuy.y + R.chatBuy.h / 2, 11.55),
  ];
  const markRes = new Mark(ui, BUYER, R.chatReserve).register(5.2);
  const markWarn = new Mark(ui, BUYER, R.warnMsg).register(8.3);
  const markBanner = new Mark(ui, BUYER, R.warnBanner).register(9.75);
  const capRes = new Caption(ui, '預約保留', '賣家接受即保留', '保留期間他人無法購買', 120);
  const capWarn = new Caption(ui, '防詐提醒', '偵測私下交易話術', '提醒雙方留在平台完成交易', 120);
  const items = new Chips(ui, ['聯絡方式', '付款資訊', '平台外交易', '可疑連結', '索取驗證資料', '詐騙話術']);
  const capBanner = new Caption(ui, '高風險橫幅', '聊天室顯示警示', '24 小時內累積 3 則高風險訊息，自動通知管理員', 120);

  const CENTER: Pose = { x: 0, y: -0.12, z: 0, rx: 0.03, ry: 0, rz: 0, s: 1.15 };
  const resF = frame(R.chatReserve, 1150, 560, 560);
  const warnF = frame(R.warnMsg, 1150, 600, 640);
  const bannerF = frame(R.warnBanner, 1150, 460, 700);

  return (t: number) => {
    head1.at(t, t1 - 0.2, 4.2);
    head3.at(t, t3 - 0.1, 7.3);
    if (t > -0.5 && t < 12.6) {
      const pose = track(t, [
        [-0.5, CENTER], [4.65, CENTER], [5.2, resF], [5.85, resF], [6.4, CENTER], [7.75, CENTER],
        [8.3, warnF], [9.25, warnF], [9.75, bannerF], [10.6, bannerF], [11.2, CENTER],
      ]);
      world.frame.phones[BUYER] = { pose, scr: seq(t, steps) };
    }
    taps.forEach((tp) => tp.at(world, t));
    markRes.at(world, t, 5.25, 5.85);
    markWarn.at(world, t, 8.35, 9.25);
    markBanner.at(world, t, 9.8, 10.6);
    capRes.at(t, 5.25, 5.85, 520);
    capWarn.at(t, 8.35, 9.2, 420);
    items.at(t, 8.5, 9.2, 120, 560);
    capBanner.at(t, 9.8, 10.6, 520);
  };
}
