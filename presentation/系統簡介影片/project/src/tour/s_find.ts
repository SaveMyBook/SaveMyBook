import { type Pose } from '../lib/kf';
import { cue, fly } from '../lib/cues';
import { BUYER, SEQS, type World, type Pop } from '../world';
import { seq, stepCues, frameSteps, back, type Step } from '../scenes/kit';
import { line } from './kit2';
import { Title, ChapterWord, glide, soft } from './kit4';
import { onBeat, TapOn, spread } from './kit5';

const SEC = 'find';
const SIGMA = 0.42;

/**
 * 第 3 章 買家找書（旁白 08 搜尋與推薦、09 AI 書籍顧問、10 聊天室與防詐），分鏡見 ../分鏡v2.md。
 * 一支手機貫穿整段，換頁一律用 App 內推入，手機只在換頁時順勢小幅移位，不甩出畫面：
 * 搜尋列浮出 → 首頁兩張推薦書卡往手機右側展開 → 推入 AI 書籍顧問，逐字輸入後兩張推薦書卡往右展開
 * → 推入和賣家的聊天室，文字、照片、語音三則訊息依拍點往右展開成一列 → 推入陌生帳號的聊天，高風險訊息進來，防詐橫幅與該則訊息浮出 → 往下退場。
 * 旁白 09 與畫面標題一字不差，該句不燒入字幕（audio/subs_hide.json）。
 * 浮出規則（2026-10-09 使用者選定）：相鄰的一組元件往旁邊展開（手機往左讓位），單一元件原地放大浮出。
 */
export function sFind(world: World, ui: HTMLElement, fx: HTMLElement) {
  const L8 = line('08'), L9 = line('09'), L10 = line('10');
  const OUT = L10.end;

  const word = new ChapterWord(fx, '買家找書');
  const tA = new Title(ui, '書名、作者、[ISBN]　都能搜', '也會收到個人化推薦');
  // 這一句很長、沒有副標：放低一點，左端才不會碰到左上角的品牌名稱
  const tB = new Title(ui, '說出需求與預算，[AI 書籍顧問]幫你挑書', '', 140);
  const tC = new Title(ui, '聊天室　[即時防詐]', '支援文字、圖片與語音，高風險訊息即時提醒');

  const WORD_OUT = 1.0;
  const RISE = WORD_OUT + 0.05;
  // 08：搜尋列浮出 → 首頁推薦書卡浮出（只用 v_home 一張，不在捲動位置不同的兩張畫面間淡化，以免殘影）
  const S0 = onBeat(SEC, Math.max(L8.at + 0.9, RISE + 1.4));
  const REC = onBeat(SEC, L8.at + 3.0);
  const C0 = onBeat(SEC, REC + 0.55);
  const BEAT = onBeat(SEC, C0 + 0.45) - C0;
  // 09、10 的時間由段落結尾往回排：每組元件完全浮出後至少停 HOLD 秒才收回（浮出動畫本身 RISE_K 秒另計）。
  // 只對齊拍點（約 0.43 秒），不對齊小節：這段配樂一小節 1.7 秒，對齊小節會把停留時間吃掉
  const HOLD = 1.2, RISE_K = 0.5, HALF = BEAT / 2;
  const EXIT0 = OUT - 0.95, EXIT1 = OUT - 0.05;
  const W0 = EXIT0 - HOLD - RISE_K;
  const MSG = W0 - 0.45;
  const SC = MSG - 0.55;
  const M0 = SC - 0.4 - HOLD - RISE_K - 2 * HALF;
  const TC = M0 - 0.75;
  // 09：推入顧問 → 逐字輸入 → 送出 → 回覆 → 推薦書卡往右展開
  const TB = onBeat(SEC, L9.at - 0.3);
  const TYPE0 = TB + 0.55;
  const P0 = TC - 0.4 - HOLD - RISE_K - HALF;
  const ANS = P0 - 0.35;
  const SEND = ANS - 0.5;
  const TYPE1 = SEND - 0.2;

  // 逐字輸入的畫面清單由截圖工具輸出（public/v2/sequences.json），world.load() 之後才有，所以播放時才組
  let steps: Step[] | null = null;
  const build = (): Step[] => [
    [-9, 'v_home'],
    [TB, 'v_advisor_empty', 1, 0.5],
    ...frameSteps((SEQS.advisor_type ?? []).filter((n) => /_t\d+$/.test(n)), TYPE0, TYPE1),
    [SEND, 'v_advisor_wait', 0, 0.1],
    [ANS, 'v_advisor_answer', 0, 0.35],
    [TC, 'v_chat_seller', 1, 0.5],
    [SC, 'v_chat_scam_0', 1, 0.5],
    [MSG, 'v_chat_scam', 0, 0.3],
  ];
  stepCues([[-9, ''], [TB, '', 1], [TC, '', 1], [SC, '', 1]]);
  for (let tk = TYPE0; tk < TYPE1; tk += 0.16) cue('key', tk, { gain: 0.3 });
  cue('pop', S0, { gain: 0.6 });
  [0, 1].forEach((i) => cue('pop', C0 + i * BEAT, { gain: 0.55 }));
  [0, 1].forEach((i) => cue('pop', P0 + i * HALF, { gain: 0.55 }));
  [0, 1, 2].forEach((i) => cue('pop', M0 + i * HALF, { gain: 0.55 }));
  cue('notify', MSG + 0.05, { gain: 0.8 });
  cue('lift', W0, { gain: 0.8 });
  const send = new TapOn(ui, BUYER, 'tap_advisor_send', SEND - 0.32);

  const P = (x: number, y: number, z: number, rx: number, ry: number, rz: number, s: number): Pose => ({ x, y, z, rx, ry, rz, s });
  // 每次換頁，手機順著推入的方向輕移一點並微轉；元件往右展開時手機往左讓位、微轉向右；全程不出畫
  const phone: [number, Pose][] = [
    [RISE, P(-0.12, -2.0, 0, 0.5, -0.45, 0.1, 1.4)],
    [RISE + 1.15, P(-0.03, -0.33, 0, 0.06, -0.14, 0.02, 1.4)],
    [S0, P(0.0, -0.32, 0, 0.03, -0.04, 0, 1.41)],
    [REC, P(0.02, -0.32, 0, 0.02, 0.0, 0, 1.42)],
    [C0 + 0.5, P(-0.3, -0.32, 0, 0.03, 0.13, 0, 1.41)],
    [TB - 0.5, P(-0.31, -0.32, 0, 0.02, 0.1, 0, 1.42)],
    [TB + 0.9, P(-0.04, -0.33, 0, 0.03, 0.08, -0.01, 1.41)],
    [ANS, P(-0.02, -0.32, 0, 0.02, 0.03, 0, 1.43)],
    [P0 + 0.5, P(-0.25, -0.32, 0, 0.03, 0.13, 0, 1.41)],
    [TC - 0.45, P(-0.26, -0.32, 0, 0.02, 0.1, 0, 1.42)],
    // 進聊天室後訊息也往右展開，手機留在左側，只隨推入微轉
    [M0 + 0.5, P(-0.27, -0.32, 0, 0.03, 0.14, 0, 1.41)],
    [SC - 0.5, P(-0.27, -0.32, 0, 0.02, 0.1, 0, 1.42)],
    [SC + 0.9, P(-0.03, -0.33, 0, 0.03, 0.06, -0.01, 1.41)],
    [EXIT0, P(-0.01, -0.32, 0, 0.02, 0.02, 0, 1.43)],
    [EXIT1, P(-0.01, -2.1, 0, -0.3, 0.06, 0.04, 1.4)],
  ];

  fly(RISE, RISE + 1.15, 0.6, -0.1);
  fly(EXIT0, EXIT1, 0.5, 0);

  const k = (t: number, t0: number, t1: number) => back(soft(t, t0, t0 + 0.5) * (1 - soft(t, t1, t1 + 0.35)));
  const dim = (ps: Pop[]) => 1 - 0.4 * Math.max(0, ...ps.map((p) => Math.min(1, p.k)));

  return (t: number) => {
    word.at(t, 0.1, WORD_OUT);
    tA.at(t, WORD_OUT + 0.45, TB - 0.05);
    tB.at(t, TB + 0.6, TC - 0.05);
    tC.at(t, TC + 0.6, OUT - 0.75);

    if (t > WORD_OUT && t < OUT) {
      steps ??= SEQS.advisor_type ? build() : null;
      const recs = [1, 2].map((n) => `cut_home_rec_card_${n}`);
      const picks = [1, 2].map((n) => `cut_advisor_pick_${n}`);
      const msgs = (['text', 'image', 'voice'] as const).map((m) => `cut_msg_${m}`);
      const recOut = spread(recs, 0.6, 'row'), pickOut = spread(picks, 0.3, 'row'), msgOut = spread(msgs, 0.3, 'col');
      const ps: Pop[] = [
        { id: 'find_search', cut: 'cut_search_bar', k: k(t, S0, REC - 0.45), grow: 0.15 },
        // 往右排開時由目的地最遠的那張先出發，後出發的不必從已就位的卡片前方穿過；整排上移，下緣不進字幕區
        ...recs.map((cut, i) => ({ id: `find_rec${i}`, cut, k: k(t, C0 + (recs.length - 1 - i) * BEAT, TB - 0.4), grow: 0.6, ...recOut[i], dy: -60, dz: i * 0.1 })),
        ...picks.map((cut, i) => ({ id: `find_pick${i}`, cut, k: k(t, P0 + (picks.length - 1 - i) * HALF, TC - 0.4), grow: 0.3, ...pickOut[i], dz: i * 0.1 })),
        ...msgs.map((cut, i) => ({ id: `find_msg${i}`, cut, k: k(t, M0 + i * HALF, SC - 0.4), grow: 0.3, ...msgOut[i], dy: msgOut[i].dy - 110, dz: i * 0.1 })),
        // 防詐橫幅在頂端、詐騙訊息在下方，相距很遠，各自原地放大浮出
        { id: 'find_warn', cut: 'cut_warn_banner', k: k(t, W0, EXIT0), grow: 0.04 },
        // 詐騙訊息在螢幕下緣，原地浮出會被字幕蓋住：往上抬到聊天室上方的空白處
        { id: 'find_scam', cut: 'cut_msg_scam', k: k(t, W0, EXIT0), grow: 0.25, dy: -230, dz: 0.15 },
      ];
      world.frame.phones[BUYER] = { pose: glide(t, phone, SIGMA), scr: steps ? seq(t, steps) : { a: 'v_home' }, glow: dim(ps), pops: ps };
    }
    send.at(world, t);
  };
}
