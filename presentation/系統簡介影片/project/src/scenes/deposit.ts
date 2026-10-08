import { span, lerp, easeOut, easeInOut, type Pose } from '../lib/kf';
import { cue, fly } from '../lib/cues';
import { SELLER, BUYER, type World } from '../world';
import { Headline, Banner, Tag, Tap, at, seq, stepCues, track, mix, easeIn, type Step } from './kit';
import { XrayLabels, DigitFly, StepBar, CabBadge, PART_COUNT, partSide } from './rig';
import { DIGITS } from './story';

/**
 * 存書（賣家侖娥）：書櫃升起並透視 ESP32 → 掃碼 → 數字飛進手機 → A01 開門放書 → 關門完成 → 買家收到通知。
 * 旁白（段落內秒數）：esp 0.8、dep1 8.4、dep2 16.4。
 */
export function deposit(world: World, ui: HTMLElement, fx: HTMLElement) {
  const tE = at('esp'), t1 = at('dep1'), t2 = at('dep2');
  const head = new Headline(ui, '一片 ESP32，控制四扇櫃門', '以 HTTPS 定時與伺服器同步，接收開鎖指令並回報開關門');
  const bar = new StepBar(ui, ['掃碼', '比對', '開門', '完成']);
  const labels = new XrayLabels(fx);
  const digits = new DigitFly(ui, SELLER, DIGITS);
  const tag = new Tag(ui, SELLER, '賣家', '侖娥');
  // 書櫃旁的狀態標記：掃碼驗證、定位確認、櫃門已開鎖
  const badgeQr = new CabBadge(ui, 'QR Code 驗證成功', 'topCenter');
  const badgeLoc = new CabBadge(ui, '定位確認：書櫃 200 公尺內', 'topCenter', 'center', 'pin');
  const badgeOpen = new CabBadge(ui, 'A01 已開鎖', 'cellA01', 'left', 'lock');
  const banner = new Banner(ui, BUYER, '書籍已存入書櫃', '訂單 ODNMX0225 的書籍已存入「圖書館總館一樓」書櫃，請於營業時間內至書櫃以 App 掃描 QR Code 取書。');

  // 時間點（段落內）
  const SCAN = 8.6, BUSY = 9.9, MATCH = 10.7, FLY0 = 11.05, FLY1 = 11.95, OPEN = 12.6, PUT0 = 13.3, PUT1 = 14.5, CLOSE = 16.4, DONE = 17.0;
  const steps: Step[] = [
    [0, 's_cab_scan'],
    // 掃碼成功後先在手機確認要存入的書，書櫃螢幕同時顯示「書櫃使用中」
    [BUSY, 's_cab_select', 1, 0.4],
    [MATCH, 's_cab_match_empty', 1, 0.4],
    [FLY1 - 0.05, 's_cab_match', 0, 0.12],
    [OPEN, 's_cab_open', 1, 0.4],
    [DONE, 's_cab_done', 0, 0.35],
  ];
  stepCues(steps);
  const tapConfirm = new Tap(ui, SELLER, 196.5, 726, MATCH - 0.18);
  fly(-0.9, 0.9, 0.6, -0.3);
  cue('power', 1.0, { gain: 0.7 });
  cue('sweep', 2.2, { dur: 0.7, gain: 0.6 });
  for (let i = 0; i < PART_COUNT; i++) cue('tick', 3.0 + i * 0.12, { pan: partSide(i) === 'left' ? -0.5 : 0.5, gain: 0.6 });
  cue('sweep', 7.0, { dur: 0.6, gain: 0.4 });
  fly(7.4, 8.6, 0.5, 0.4);
  cue('scan', SCAN + 0.2, { dur: 1.2, pan: 0.4 }); cue('beep', BUSY, { pan: 0.4 });
  cue('zip', FLY0, { dur: 0.4, pan: 0.1 });
  cue('key', FLY1 - 0.05, { pan: 0.4 }); cue('key', FLY1 + 0.05, { pan: 0.45 });
  cue('unlock', OPEN, { pan: -0.3 }); cue('door_open', OPEN + 0.1, { dur: 0.6, pan: -0.3 }); cue('book', PUT1, { pan: -0.3 });
  cue('door_close', CLOSE, { dur: 0.6, pan: -0.3 }); cue('slam', CLOSE + 0.6, { pan: -0.3, gain: 0.8 }); cue('success', DONE + 0.05, { pan: 0.3 });
  // 結尾：書櫃先退場，賣家手機移到左側，買家手機從右側進來收到通知（兩支並排，不互相遮住）
  const CAB_OUT = 17.6, SHIFT = 18.2, BUYER_IN = 18.3, NOTIFY = 19.0, OUT = 20.0;
  fly(CAB_OUT, CAB_OUT + 0.9, 0.4, -0.6);
  cue('notify', NOTIFY, { pan: 0.4 });
  fly(OUT, OUT + 1.2, 0.5);

  const CAB_SOLO: Pose = { x: 0, y: -0.12, z: 0, rx: 0.06, ry: 0.32, rz: 0, s: 1.6 };
  const CAB_SIDE: Pose = { x: -0.27, y: -0.19, z: 0, rx: 0.05, ry: 0.28, rz: 0, s: 1.42 };
  const PHONE: Pose = { x: 0.23, y: -0.25, z: 0, rx: 0.03, ry: -0.16, rz: 0, s: 1.32 };
  // 每一步的主角往前：掃碼與開門看書櫃，比對與完成看手機
  const lean = (t: number) => {
    const on = (a: number, b: number) => easeInOut(span(t, a, a + 0.6)) * (1 - easeInOut(span(t, b, b + 0.6)));
    return on(SCAN - 0.2, MATCH - 0.4) + on(OPEN - 0.3, CLOSE + 0.8) - on(MATCH - 0.3, OPEN - 0.4) - on(DONE - 0.2, 99);
  };
  // 櫃門以右側鉸鏈向右打開，開門期間手機再往右讓出空間
  const doorRoom = (t: number) => easeInOut(span(t, OPEN - 0.4, OPEN + 0.2)) * (1 - easeInOut(span(t, CLOSE + 0.2, CLOSE + 0.8)));

  return (t: number) => {
    const f = world.frame;
    head.at(t, tE - 0.3, 7.0);
    bar.at(t, t1 - 0.4, 19.4, [SCAN, MATCH, OPEN, DONE]);

    let xray = 0;
    if (t > -1.0 && t < CAB_OUT + 1.0) {
      let pose = track(t, [
        [-0.9, { ...CAB_SOLO, x: -1.4, ry: 1.2 }], [0.9, CAB_SOLO], [7.2, { ...CAB_SOLO, ry: -0.2 }], [8.6, CAB_SIDE],
      ]);
      const ld = lean(t);
      pose.z = (pose.z ?? 0) + ld * 2.0;
      pose.x = (pose.x ?? 0) - doorRoom(t) * 0.03;
      pose = mix(pose, { ...pose, x: -1.7, ry: 0.8 }, easeIn(span(t, CAB_OUT, CAB_OUT + 0.9)));
      xray = easeInOut(span(t, 2.2, 2.9)) * (1 - easeInOut(span(t, 7.0, 7.6)));
      let state: 'qr' | 'busy' | 'match' | 'opening' | 'open' | 'done' = 'qr';
      let seconds = 60;
      if (t >= BUSY && t < MATCH) state = 'busy';
      else if (t >= MATCH && t < FLY1 + 0.15) { state = 'match'; seconds = 52; }
      else if (t >= FLY1 + 0.15 && t < OPEN) state = 'opening';
      else if (t >= OPEN && t < DONE) { state = 'open'; seconds = Math.round(lerp(30, 26, span(t, OPEN, DONE))); }
      else if (t >= DONE) state = 'done';
      const flyK = span(t, FLY0, FLY1);
      f.cabinet = {
        pose, xray,
        kiosk: { state, refresh: (t / 30) % 1, seconds, digits: state === 'match' ? 1 - 0.7 * span(flyK, 0, 0.25) : 1, check: easeOut(span(t, DONE, DONE + 0.5)) },
        door: easeInOut(span(t, OPEN + 0.1, OPEN + 0.7)) * (1 - easeInOut(span(t, CLOSE, CLOSE + 0.6))),
        deposit: easeOut(span(t, PUT0, PUT1)),
      };
    }
    labels.at(world, xray);
    tapConfirm.at(world, t);
    badgeQr.at(world, t, BUSY + 0.05, MATCH - 0.1);
    badgeLoc.at(world, t, MATCH + 0.1, OPEN - 0.15);
    badgeOpen.at(world, t, OPEN + 0.15, CLOSE);

    if (t > 7.3 && t < 21.4) {
      let pose = track(t, [[7.4, { ...PHONE, y: -2.1, rx: 0.5, ry: -0.6 }], [8.7, PHONE]]);
      pose.ry = (pose.ry ?? 0) + Math.sin((t - 8.7) * 0.4) * 0.04;
      pose.z = (pose.z ?? 0) - lean(t) * 2.0;
      pose.x = (pose.x ?? 0) + doorRoom(t) * 0.11;
      // 與買家手機同尺寸並排，底邊高於字幕卡
      pose = mix(pose, { ...pose, x: -0.3, y: -0.12, s: 1.15, ry: 0.12, z: 0 }, easeInOut(span(t, SHIFT, SHIFT + 0.8)));
      pose = mix(pose, { ...pose, x: -1.4, ry: 0.6 }, easeIn(span(t, OUT, OUT + 1.1)));
      f.phones[SELLER] = { pose, scr: seq(t, steps) };
    }
    tag.at(world, t, 8.6, OUT - 0.2);
    digits.at(world, t, FLY0, FLY1);

    // 買家手機自右側進入，收到存書通知
    if (t > BUYER_IN - 0.1) {
      const SIDE: Pose = { x: 0.3, y: -0.15, z: 0, rx: 0.04, ry: -0.18, rz: 0, s: 1.15 };
      const pose = track(t, [[BUYER_IN, { ...SIDE, x: 1.5, ry: -0.7 }], [BUYER_IN + 0.8, SIDE], [OUT + 0.4, SIDE], [21.6, { x: 0, y: -0.12, z: 0, rx: 0.03, ry: 0, rz: 0, s: 1.15 }]]);
      f.phones[BUYER] = { pose, scr: { a: 'b_home' } };
    }
    banner.at(world, t, NOTIFY, 22.1);
  };
}
