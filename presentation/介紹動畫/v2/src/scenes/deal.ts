import { span, easeInOut, type Pose } from '../lib/kf';
import { cue, fly } from '../lib/cues';
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
    // 另一個聊天室：可疑訊息傳來並附上防詐提醒，接著聊天室頂端出現高風險橫幅
    [6.57, 'b_chat_warn_0', 0, 0.02],
    [7.55, 'b_chat_warn_1', 0, 0.25],
    [9.5, 'b_chat_warn', 0, 0.3],
    [11.12, 'b_chat_4', 0, 0.02],
  ];
  stepCues(steps);
  [2.6, 3.4, 4.2].forEach((s) => cue('bubble', s + 0.05, { pan: 0.2, gain: 0.7 }));
  const FLIP1 = 6.15, FLIP2 = 10.7, FLIP = 0.85;
  fly(FLIP1, FLIP1 + FLIP, 0.5);
  fly(FLIP2, FLIP2 + FLIP, 0.5);
  cue('bubble', 7.55, { pan: 0.1, gain: 0.7 });
  cue('alert', 7.75, { pan: 0.1 });
  cue('banner', 9.52, { pan: 0.1 });
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
        [-0.5, CENTER], [4.65, CENTER], [5.2, resF], [5.85, resF], [6.6, CENTER], [7.75, CENTER],
        [8.3, warnF], [9.25, warnF], [9.75, bannerF], [10.45, bannerF], [11.3, CENTER],
      ]);
      // 翻轉時往後退一些，側面朝鏡頭時不會顯得太大
      for (const [t0, dir] of [[FLIP1, 1], [FLIP2, -1]] as const) {
        const k = easeInOut(span(t, t0, t0 + FLIP));
        if (k > 0 && k < 1) {
          pose.ry = (pose.ry ?? 0) + dir * k * Math.PI * 2;
          pose.z = (pose.z ?? 0) - Math.sin(k * Math.PI) * 9;
          pose.rx = (pose.rx ?? 0) + Math.sin(k * Math.PI) * 0.12;
        }
      }
      world.frame.phones[BUYER] = { pose, scr: seq(t, steps) };
    }
    taps.forEach((tp) => tp.at(world, t));
    markRes.at(world, t, 5.25, 5.85);
    markWarn.at(world, t, 8.35, 9.25);
    markBanner.at(world, t, 9.8, 10.6);
    capRes.at(t, 5.25, 5.85, 520);
    capWarn.at(t, 8.35, 9.2, 420);
    items.at(t, 8.5, 9.2, 120, 560);
    // 這則訊息命中的三類：聯絡方式、付款資訊、平台外交易
    items.root.querySelectorAll<HTMLElement>('.chip').forEach((c, i) => c.classList.toggle('is-hit', i < 3 && t > 8.9 + i * 0.12));
    capBanner.at(t, 9.8, 10.6, 520);
  };
}
