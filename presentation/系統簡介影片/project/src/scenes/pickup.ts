import { span, lerp, easeOut, easeInOut, type Pose } from '../lib/kf';
import { cue, fly } from '../lib/cues';
import { SELLER, BUYER, type World } from '../world';
import { Headline, Caption, Mark, Tag, Tap, at, frame, seq, stepCues, track, mix, easeIn, type Step } from './kit';
import { DigitFly, CabBadge } from './rig';
import { DIGITS, WALLET } from './story';

/**
 * 取書與撥款：買家海嫄在書櫃掃碼、比對、A01 開門取出書 → 時間快轉 24 小時 → 款項飛進賣家侖娥的錢包。
 * 旁白（段落內秒數）：pick 0.8。時間快轉與硬幣由 escrow.ts 處理。
 */
export function pickup(world: World, ui: HTMLElement) {
  const head = new Headline(ui, '取書後 24 小時，自動撥款', '申請爭議時暫停撥款，由管理員裁決');
  const digits = new DigitFly(ui, BUYER, DIGITS);
  const buyerTag = new Tag(ui, BUYER, '買家', '海嫄');
  const sellerTag = new Tag(ui, SELLER, '賣家', '侖娥');
  const SCAN = 0.4, MATCH = 1.45, FLY0 = 1.6, FLY1 = 2.35, OPEN = 2.6, TAKE0 = 3.0, TAKE1 = 3.8, CLOSE = 3.9, DONE = 4.4;
  const steps: Step[] = [[0, 'b_pickup_scan'], [SCAN + 0.55, 'b_cab_select', 1, 0.35], [MATCH, 'b_cab_match_empty', 1, 0.35], [FLY1 - 0.05, 'b_cab_match', 0, 0.1], [OPEN, 'b_pickup_open', 1, 0.35], [DONE, 'b_pickup_done', 0, 0.3]];
  stepCues(steps);
  const tapConfirm = new Tap(ui, BUYER, 196.5, 726, MATCH - 0.15);
  const badgeQr = new CabBadge(ui, 'QR Code 驗證成功', 'topCenter');
  const badgeLoc = new CabBadge(ui, '定位確認：書櫃 200 公尺內', 'topCenter', 'center', 'pin');
  const badgeOpen = new CabBadge(ui, 'A01 已開鎖', 'cellA01', 'left', 'lock');
  const markWallet = new Mark(ui, SELLER, WALLET.entry).register(7.55);
  const capWallet = new Caption(ui, '撥款入帳', '款項撥入賣家錢包', '交易紀錄列出每筆收入與對應的書', 120);
  cue('scan', SCAN, { dur: 0.8, pan: 0.4 }); cue('beep', MATCH - 0.1, { pan: 0.4 });
  cue('zip', FLY0, { dur: 0.4 }); cue('key', FLY1 - 0.05, { pan: 0.4 });
  cue('unlock', OPEN, { pan: -0.3 }); cue('door_open', OPEN + 0.05, { dur: 0.5, pan: -0.3 }); cue('slide', TAKE0, { dur: 0.8, pan: -0.3 });
  cue('slam', CLOSE + 0.4, { pan: -0.3, gain: 0.7 }); cue('success', DONE + 0.05, { pan: 0.3 });
  fly(-0.6, 0.6, 0.5); fly(4.8, 5.8, 0.6, -0.3); fly(9.3, 10.2, 0.5, -0.4);

  const CAB: Pose = { x: -0.27, y: -0.19, z: 0, rx: 0.05, ry: 0.28, rz: 0, s: 1.42 };
  // 櫃門以右側鉸鏈向右打開，開門期間手機再往右讓出空間
  const doorRoom = (t: number) => easeInOut(span(t, OPEN - 0.3, OPEN + 0.15)) * (1 - easeInOut(span(t, CLOSE + 0.1, CLOSE + 0.6)));
  const PHONE: Pose = { x: 0.23, y: -0.25, z: 0, rx: 0.03, ry: -0.16, rz: 0, s: 1.32 };
  // 餘額到第一筆入帳一起看
  const walletF = frame({ x: 20, y: 250, w: 353, h: 472 }, 1150, 560, 560);

  return (t: number) => {
    const f = world.frame;
    // 書櫃與手機並排時（未放大）顯示，計時器出現前收起
    head.at(t, 0.6, 4.2);
    if (t > -0.7 && t < 6.0) {
      let pose = track(t, [[-0.6, { ...CAB, x: -1.5, ry: 1.0 }], [0.6, CAB]]);
      pose.x = (pose.x ?? 0) - doorRoom(t) * 0.03;
      pose = mix(pose, { ...CAB, x: -1.7, ry: 0.8 }, easeIn(span(t, 4.8, 5.8)));
      f.cabinet = {
        pose,
        kiosk: { state: t < SCAN + 0.55 ? 'qr' : t < MATCH ? 'busy' : t < FLY1 + 0.1 ? 'match' : t < OPEN ? 'opening' : t < DONE ? 'open' : 'done', refresh: (t / 30) % 1, seconds: t < OPEN ? 52 : 29, digits: t >= FLY0 ? 0.3 : 1, check: easeOut(span(t, DONE, DONE + 0.5)), take: true },
        door: easeInOut(span(t, OPEN + 0.05, OPEN + 0.5)) * (1 - easeInOut(span(t, CLOSE, CLOSE + 0.5))),
        deposit: 1,
        withdraw: easeInOut(span(t, TAKE0, TAKE1)),
      };
    }
    if (t > -0.7 && t < 6.0) {
      let pose = track(t, [[-0.6, { ...PHONE, x: 0.6, y: -0.15, ry: -0.3, s: 1.15 }], [0.5, PHONE]]);
      pose.x = (pose.x ?? 0) + doorRoom(t) * 0.11;
      pose = mix(pose, { ...PHONE, x: 1.6, ry: -0.7 }, easeIn(span(t, 4.8, 5.8)));
      f.phones[BUYER] = { pose, scr: seq(t, steps) };
    }
    buyerTag.at(world, t, 0.3, 4.7);
    tapConfirm.at(world, t);
    badgeQr.at(world, t, SCAN + 0.6, MATCH - 0.1);
    badgeLoc.at(world, t, MATCH + 0.05, OPEN - 0.12);
    badgeOpen.at(world, t, OPEN + 0.1, CLOSE);
    digits.at(world, t, FLY0, FLY1);
    if (t > 5.1 && t < 10.3) {
      let pose = track(t, [[5.2, { x: 0.2, y: -2.2, z: 0, rx: 0.45, ry: 0, rz: 0, s: 1.15 }], [6.1, { x: 0.2, y: -0.12, z: 0, rx: 0.03, ry: 0, rz: 0, s: 1.15 }], [6.75, { x: 0.2, y: -0.12, z: 0, rx: 0.03, ry: 0, rz: 0, s: 1.15 }], [7.5, walletF], [9.2, walletF]]);
      pose = mix(pose, { ...pose, x: -1.6, ry: 0.7 }, easeIn(span(t, 9.3, 10.2)));
      f.phones[SELLER] = { pose, scr: { a: 's_wallet' } };
    }
    sellerTag.at(world, t, 5.9, 6.6);
    markWallet.at(world, t, 7.6, 9.2);
    capWallet.at(t, 7.6, 9.2, 540);
    void lerp;
  };
}
