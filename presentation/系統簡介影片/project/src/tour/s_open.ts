import { type Pose, lerp, easeOut, span } from '../lib/kf';
import { el, fade, place, css } from '../lib/ui';
import { cue, fly, roll } from '../lib/cues';
import { SELLER, BUYER, type World, type Pop } from '../world';
import { seq, back, type Step } from '../scenes/kit';
import { line } from './kit2';
import { Title, ChapterWord, glide, soft } from './kit4';
import { onBeat } from './kit5';
import { Lockup, BigNum } from './x_open';

const SEC = 'open';
const SIGMA = 0.42;

/**
 * 開場（旁白 01 痛點、02 問卷 57.4%、03 品牌）。無章名，分鏡見 ../分鏡v2.md 的原則。
 * 01：「二手書交易」大字 → 手機升起，畫面是約好面交的訊息對話（模擬的 iOS 訊息，不是本系統 App），
 *     買家依拍點傳出「我到了」「快到了嗎」「？」三則訊息，全部已讀未回 → 手機往左讓位，紙箱由右側翻滾落下（寄送又麻煩）
 *     → 手機往左、紙箱往右出畫。
 * 02：57.4% 放在上方當大標並滾動，同時 3D 書櫃由下方升起、緩慢轉台；唸到「24 小時自助」時書櫃螢幕換一組 QR Code（無人值守、自助運作）。
 * 03：書櫃下沉的同時 logo 在中央開始描線（上方的 57.4% 留到描線之後才退）、名稱展開 → 品牌組移到上方，書櫃與賣家、買家兩支手機升起，
 *     賣家畫面「請將下列書籍放入櫃門 A01」、買家畫面「請取出櫃門 A01 內的書籍」依拍點各自原地浮出（同一櫃門，各自前往）
 *     → 往下退場，品牌組縮到左上角，與固定標誌（Corner）逐像素重合後交接。
 *
 * 畫面文字出處（複評版系統手冊，印刷頁碼）：
 * - 「交易安全，是面交最受關注的問題」「需自行包裝、跑超商寄貨」：p4（圖 1-2-5、1-2-6 說明）。
 * - 「498 份有效問卷」：p1（1-2 動機）。
 * - 「57.4%」「24 小時自助」：p4（圖 1-2-8 說明）。
 * 手機畫面由 savemybook_app/tool/video_shots/open_test.dart 產生：書為正式站 book_id 150、新北高工書櫃 A01。
 */
export function sOpen(world: World, ui: HTMLElement, fx: HTMLElement) {
  const L1 = line('01'), L2 = line('02'), L3 = line('03');
  const END = L3.end;

  const root = el('div', 'open-root', ui);
  const word = new ChapterWord(fx, '二手書交易');
  const tA = new Title(ui, '面交　怕[被放鳥]', '交易安全，是面交最受關注的問題');
  const tB = new Title(ui, '寄送　[又麻煩]', '需自行包裝、跑超商寄貨');
  const num = new BigNum(root);
  num.root.classList.add('open-num--top');
  const subN = el('p', 'sub promo__sub open-sub', root, '498 份有效問卷');
  const subStat = el('p', 'sub promo__sub open-sub', root, '認為書櫃最吸引人的是「<b>24 小時自助</b>」');
  const sub1 = el('p', 'sub promo__sub open-sub', root, '結合 <b>App</b> 與<b>智慧書櫃</b>');
  const sub2 = el('p', 'sub promo__sub open-sub', root, '買賣雙方　<b>不必約時間見面</b>');
  const lock = new Lockup(root);

  // 旁白斷句（tts 音檔靜音量測，段落內秒數）：01「二手書交易」0.80–1.86、「最怕面交被放鳥」2.16–3.66、「寄送又麻煩」3.96–5.17；
  // 02「問卷中」5.67–6.43、「57.4% 的人認為」6.73–8.99、「書櫃最吸引人的是」9.29–10.93、「24 小時自助」11.01–12.40；
  // 03「救舊我的書」12.90–13.88、「結合 App 與智慧書櫃」14.18–15.88、「買賣雙方不必約時間見面」16.18–18.48。
  // 01：大字 → 手機升起 → 三則訊息依拍點出現 → 紙箱落下 → 出畫
  const WORD0 = 0.15, WORD1 = 1.0;
  const RISE = WORD1 + 0.05;
  const MSG = [1.9, 2.5, 3.15].map((x) => onBeat(SEC, x));
  const BOX = onBeat(SEC, L1.at + 3.1);
  const OUT1 = L2.at - 0.45, OUT1E = OUT1 + 0.9;
  // 02：數字在上方滾動，書櫃升起；唸到「24 小時自助」時換一組 QR Code
  // 數字在旁白唸到「57.4%」時才出現，出現的同時開始滾動（不停在 0.0%）
  const NUM0 = L2.at + 0.9, COUNT0 = NUM0, COUNT1 = COUNT0 + 1.9;
  const STAT = L2.at + 3.65;
  const CAB0 = OUT1 + 0.35;
  const FLASH = onBeat(SEC, L2.at + 5.5);
  const STAT_OUT = L2.end - 0.15;
  // 數字與副標留到 logo 開始描線之後才退，書櫃下沉與描線之間畫面不會全空
  const NUM_OUT = L2.end + 0.25;
  // 03：logo 描線 → 名稱展開 → 品牌組移到上方，書櫃與兩支手機升起 → 兩張卡片依拍點浮出 → 退場與交接
  const DRAW = L3.at - 0.4;
  const NAME0 = L3.at + 0.4, NAME1 = NAME0 + 0.7;
  const LIFT0 = L3.at + 1.45, LIFT1 = LIFT0 + 0.8;
  const OUT0 = END - 0.95;
  const LAND0 = END - 0.95, LAND1 = END - 0.14;
  // 兩張卡片要在手機退場前收完（退場的平滑會讓手機提早約 0.4 秒開始往下），又要完全浮出後停 1.2 秒以上：
  // 手機提早升起、卡片提早浮出，收回時刻 POP_OUT 比退場關鍵影格早 0.5 秒
  const POP0 = onBeat(SEC, LIFT0 + 0.7);
  const HALF = (onBeat(SEC, POP0 + 0.5) - POP0) / 2;
  const POP_OUT = OUT0 - 0.5;

  const P = (x: number, y: number, z: number, rx: number, ry: number, rz: number, s: number): Pose => ({ x, y, z, rx, ry, rz, s });

  // 01：訊息手機由下方升起 → 訊息出現時慢慢推近 → 紙箱落下前往左讓位 → 往左出畫
  const meet: [number, Pose][] = [
    [RISE, P(0.1, -2.0, 0, 0.5, 0.45, -0.1, 1.4)],
    [RISE + 1.15, P(0.02, -0.33, 0, 0.06, 0.12, -0.02, 1.4)],
    [MSG[2], P(0.0, -0.32, 0, 0.03, 0.03, 0, 1.43)],
    [BOX + 0.6, P(-0.2, -0.32, 0, 0.03, 0.16, 0, 1.41)],
    [OUT1, P(-0.22, -0.32, 0, 0.02, 0.14, 0, 1.42)],
    [OUT1E, P(-1.75, -0.36, 0, 0.05, 0.6, 0.04, 1.4)],
  ];
  // 新訊息出現時對話往上捲：淡化會讓前後兩張畫面的泡泡疊成兩層，改用極短的切換
  const meetSteps: Step[] = [[-9, 'v_open_meet_0'], ...MSG.map((t, i) => [t, `v_open_meet_${i + 1}`, 0, 0.04] as Step)];
  // 寄送：紙箱由右側翻滾落到手機右邊，停留後往右出畫
  const box: [number, Pose][] = [
    [BOX - 0.15, P(1.6, -0.2, 0, 1.2, -2.4, 0.9, 1.6)],
    [BOX + 0.65, P(0.34, -0.14, 0, 0.38, -0.6, 0.05, 1.6)],
    [OUT1, P(0.33, -0.14, 0, 0.34, -0.5, 0.03, 1.62)],
    [OUT1E, P(1.7, -0.2, 0, 0.9, -1.8, 0.5, 1.6)],
  ];
  // 24 小時自助：書櫃由下方旋轉升起，緩慢轉台展示，之後下沉讓位給 logo
  const cab1: [number, Pose][] = [
    [CAB0, P(0, -1.9, 0, 0.14, 1.1, 0, 1.6)],
    [CAB0 + 1.2, P(0, -0.23, 0, 0.07, 0.45, 0, 1.6)],
    [STAT_OUT - 0.55, P(0, -0.22, 0, 0.06, -0.2, 0, 1.64)],
    [STAT_OUT + 0.2, P(0, -2.0, 0, 0.12, -0.45, 0, 1.6)],
  ];
  // 結合 App 與智慧書櫃：書櫃在中央、賣家手機在左、買家手機在右，依序升起，最後一起往下退場
  const cab2: [number, Pose][] = [
    [LIFT0, P(0, -1.95, -2, 0.14, 0.9, 0, 1.3)],
    [LIFT0 + 1.0, P(0, -0.12, -2, 0.07, 0.25, 0, 1.3)],
    [OUT0, P(0, -0.12, -2, 0.06, 0.05, 0, 1.32)],
    [END - 0.08, P(0, -2.15, -2, 0.12, -0.1, 0, 1.3)],
  ];
  const seller: [number, Pose][] = [
    [LIFT0 - 0.15, P(-0.47, -1.9, 2, 0.4, 0.6, -0.05, 1.12)],
    [LIFT0 + 0.75, P(-0.46, -0.14, 2, 0.05, 0.3, 0, 1.12)],
    [OUT0, P(-0.45, -0.14, 2, 0.04, 0.22, 0, 1.14)],
    [END - 0.06, P(-0.46, -2.2, 2, -0.3, 0.15, 0, 1.12)],
  ];
  const buyer: [number, Pose][] = [
    [LIFT0 - 0.05, P(0.47, -1.9, 2, 0.4, -0.6, 0.05, 1.12)],
    [LIFT0 + 0.85, P(0.46, -0.14, 2, 0.05, -0.3, 0, 1.12)],
    [OUT0, P(0.45, -0.14, 2, 0.04, -0.22, 0, 1.14)],
    [END - 0.04, P(0.46, -2.2, 2, -0.3, -0.15, 0, 1.12)],
  ];

  fly(RISE, RISE + 1.15, 0.6, 0.1);
  MSG.forEach((t) => cue('send', t, { gain: 0.6 }));
  fly(BOX - 0.15, BOX + 0.65, 0.6, 0.5);
  cue('box', BOX + 0.6, { gain: 0.7, pan: 0.3 });
  fly(OUT1, OUT1E, 0.45, 0);
  fly(CAB0, CAB0 + 1.2, 0.6, 0);
  roll(COUNT0, COUNT1 - COUNT0, 0, 0.6);
  cue('scan', FLASH, { gain: 0.5 });
  fly(STAT_OUT - 0.55, STAT_OUT + 0.2, 0.4, 0);
  cue('line', DRAW + 0.08, { dur: 1.15, pan: -0.3 });
  cue('line', DRAW + 0.08, { dur: 1.15, pan: 0.3 });
  cue('textin', NAME0 + 0.35, { gain: 0.8 });
  cue('shimmer', DRAW + 2.5, { gain: 0.6 });
  fly(LIFT0 - 0.15, LIFT0 + 0.95, 0.6, 0);
  cue('pop', POP0, { gain: 0.6, pan: -0.4 });
  cue('pop', POP0 + HALF, { gain: 0.6, pan: 0.4 });
  fly(OUT0, END - 0.08, 0.5, 0);
  fly(LAND0, LAND1, 0.3, -0.4);

  const k = (t: number, t0: number, t1: number) => back(soft(t, t0, t0 + 0.5) * (1 - soft(t, t1, t1 + 0.35)));
  const dim = (ps: Pop[]) => 1 - 0.4 * Math.max(0, ...ps.map((p) => Math.min(1, p.k)));

  return (t: number) => {
    const f = world.frame;
    word.at(t, WORD0, WORD1);
    tA.at(t, RISE + 0.45, BOX - 0.25);
    tB.at(t, BOX + 0.35, OUT1 - 0.05);

    // 57.4%：在上方當大標滾動；唸到「書櫃最吸引人的是」時副標換成統計內容
    num.set(easeOut(span(t, COUNT0, COUNT1)) * 57.4);
    fade(num.root, t, NUM0, NUM_OUT, 24, 16);
    place(num.root, 960, 112, ` scale(${(1 + 0.03 * span(t, NUM0, NUM_OUT)).toFixed(4)})`);
    fade(subN, t, NUM0 + 0.35, STAT - 0.4, 16, 0);
    place(subN, 960, 214);
    fade(subStat, t, STAT, NUM_OUT, 16, 0);
    place(subStat, 960, 214);

    // 品牌組：logo 在中央描線 → 名稱展開、整組置中 → 移到上方 → 縮到左上角交接（與第一版相同，已逐像素對齊 Corner）
    const cx0 = lock.cx0;
    const pose = glide(t, [
      [DRAW, { x: 960 + (cx0 - 72) * 4.4, y: 470, s: 4.4 }],
      [NAME0, { x: 960 + (cx0 - 72) * 4.45, y: 470, s: 4.45 }],
      [NAME1, { x: 960, y: 470, s: 4.5 }],
      [LIFT0, { x: 960, y: 466, s: 4.52 }],
      [LIFT1, { x: 960, y: 112, s: 2.6 }],
      [LAND0 - 0.1, { x: 960, y: 112, s: 2.64 }],
    ]);
    const land = soft(t, LAND0, LAND1);
    lock.at(t, t >= DRAW - 0.01 && t < END, DRAW, span(t, NAME0 + 0.35, NAME1 + 0.3),
      lerp(pose.x, cx0, land), lerp(pose.y, 58, land), lerp(pose.s, 1, land));
    fade(sub1, t, LIFT1 + 0.15, L3.at + 3.05, 16, 0);
    place(sub1, 960, 214);
    fade(sub2, t, L3.at + 3.55, OUT0 + 0.1, 16, 0);
    place(sub2, 960, 214);
    css(root, 'visibility', t < END + 0.5 ? 'visible' : 'hidden');

    if (t < 0 || t > END) return;
    if (t > RISE - 0.1 && t < OUT1E + 0.6) f.phones[BUYER] = { pose: glide(t, meet, SIGMA), scr: seq(t, meetSteps) };
    if (t > BOX - 0.3 && t < OUT1E + 0.6) f.parcel = glide(t, box, SIGMA);
    // QR Code 每 30 秒換一組：倒數條在 FLASH 歸零，換碼瞬間閃白
    const kiosk = {
      state: 'qr' as const,
      refresh: ((t - FLASH) / 30 + 1) % 1,
      seconds: 30,
      digits: 1,
      check: 0,
      qr: t >= FLASH ? 1 : 0,
      flash: Math.max(0, 1 - Math.abs(t - FLASH) / 0.18),
    };
    if (t > CAB0 - 0.1 && t < STAT_OUT + 1.2) f.cabinet = { pose: glide(t, cab1, SIGMA), kiosk };
    if (t > LIFT0 - 0.1) {
      f.cabinet = { pose: glide(t, cab2, SIGMA), kiosk: { ...kiosk, flash: 0 } };
      const put: Pop[] = [{ id: 'open_put', cut: 'cut_open_put', k: k(t, POP0, POP_OUT), grow: 0.25 }];
      const take: Pop[] = [{ id: 'open_take', cut: 'cut_open_take', k: k(t, POP0 + HALF, POP_OUT), grow: 0.25 }];
      f.phones[SELLER] = { pose: glide(t, seller, SIGMA), scr: { a: 'v_open_deposit' }, glow: dim(put), pops: put };
      f.phones[BUYER] = { pose: glide(t, buyer, SIGMA), scr: { a: 'v_open_pickup' }, glow: dim(take), pops: take };
    }
  };
}
