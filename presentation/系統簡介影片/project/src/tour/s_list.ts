import { type Pose } from '../lib/kf';
import { cue, fly } from '../lib/cues';
import { SELLER, ADMIN, type World, type Pop } from '../world';
import { seq, stepCues, back, type Step } from '../scenes/kit';
import { line } from './kit2';
import { Title, ChapterWord, glide, soft } from './kit4';
import { onBar, onBeat, TapOn, spread } from './kit5';

const SEC = 'list';
/** 移動的平滑程度（秒）：第二版放慢轉場，比第一版的 0.3 柔和。 */
const SIGMA = 0.42;

/**
 * 第 2 章 賣家上架（旁白 05 掃描 ISBN、06 AI 書況與售價、07 雙層審核），分鏡見 ../分鏡v2.md。
 * 每句只做一件事：條碼掃描 → 三個書目欄位依拍點往手機右側展開（手機往左讓位）；App 內推入照片頁 → AI 書況卡與售價卡一起往右展開；
 * 賣家手機退到左後方、管理員手機沿同一道弧線從右側接力滑入 → 整張待審卡片浮出 → 兩支手機一起往下退場。
 * 換場時刻對齊配樂小節線（kit5.onBar），浮出對齊拍點。
 * 浮出規則（2026-10-09 使用者選定）：相鄰的一組元件往旁邊展開，單一元件依旁白一次浮一個並放大。
 */
export function sList(world: World, ui: HTMLElement, fx: HTMLElement) {
  const L5 = line('05'), L6 = line('06'), L7 = line('07');
  const OUT = L7.end;

  const word = new ChapterWord(fx, '賣家上架');
  const tA = new Title(ui, '掃一下 [ISBN]', '書名、作者、出版社　自動帶入');
  const tB = new Title(ui, '拍張照片　[AI] 判斷書況', '依照片與定價，建議售價區間');
  const tC = new Title(ui, '規則＋AI　[雙層把關]', '售價異常或需人工複核，送交審核');

  const WORD_OUT = 1.0;
  const RISE = WORD_OUT + 0.05;
  // 05：掃描成功 → 推入填好的表單 → 三個欄位依拍點浮出
  const SCAN_OK = onBeat(SEC, L5.at + 1.3);
  const FORM = onBar(SEC, SCAN_OK + 0.75);
  const F0 = onBeat(SEC, FORM + 0.6);
  const BEAT = onBeat(SEC, F0 + 0.5) - F0;
  // 06：推入照片頁 → 點 AI 帶入 → 結果卡浮出
  const TB = onBar(SEC, L6.at - 0.3);
  const AI = onBeat(SEC, TB + 1.3);
  // 結果要等「分析中」面板展開（0.4 秒）並停留一下才出現；不對齊小節線：前一條小節線太近，會把展開切斷成跳格
  const RES = AI + 1.05;
  const R0 = RES + 0.4;
  // 07：接力換手機 → 兩個審核區塊浮出
  const TC = onBar(SEC, L7.at - 0.35);
  const HAND = 1.1;
  const V0 = onBeat(SEC, TC + HAND + 0.2);
  const EXIT0 = OUT - 0.95, EXIT1 = OUT - 0.05;

  const seller: Step[] = [
    [-9, 'v_sell_scan'],
    [SCAN_OK, 'v_sell_scan_ok', 0, 0.15],
    [FORM, 'v_sell_form_filled', 1, 0.5],
    [TB, 'v_sell_photos', 1, 0.5],
    [AI + 0.35, 'v_sell_ai_loading', 3, 0.4],
    [RES, 'v_sell_ai_result', 3, 0.5],
  ];
  stepCues(seller);
  cue('success', SCAN_OK, { gain: 0.5 });
  [0, 1, 2].forEach((i) => cue('pop', F0 + i * BEAT, { gain: 0.55 }));
  [0, 1].forEach((i) => cue('pop', R0 + i * BEAT / 2, { gain: 0.6 }));
  cue('lift', V0, { gain: 0.8 });
  cue('swipe', TC + 0.15, { gain: 0.6 });
  const tapAi = new TapOn(ui, SELLER, 'tap_sell_ai', AI - 0.32);

  const P = (x: number, y: number, z: number, rx: number, ry: number, rz: number, s: number): Pose => ({ x, y, z, rx, ry, rz, s });
  // 賣家手機：由下方升起 → 書目欄位展開時往左讓位並微轉向右 → 換照片頁時回到中間 → 交棒時退到左後方 → 一起往下退場
  const main: [number, Pose][] = [
    [RISE, P(0.1, -2.0, 0, 0.5, 0.45, -0.1, 1.4)],
    [RISE + 1.15, P(0.02, -0.33, 0, 0.06, 0.14, -0.02, 1.4)],
    [FORM, P(0.0, -0.32, 0, 0.03, 0.04, 0, 1.41)],
    [F0 + 0.55, P(-0.27, -0.32, 0, 0.03, 0.13, 0, 1.41)],
    [TB - 0.5, P(-0.29, -0.32, 0, 0.02, 0.1, 0, 1.42)],
    [TB + 0.9, P(0.07, -0.33, 0, 0.03, -0.12, 0.01, 1.41)],
    [RES, P(0.04, -0.32, 0, 0.02, -0.05, 0, 1.42)],
    [R0 + 0.5, P(-0.27, -0.32, 0, 0.03, 0.13, 0, 1.41)],
    [TC, P(-0.28, -0.32, 0, 0.02, 0.1, 0, 1.43)],
    [TC + HAND, P(-0.42, -0.35, -10, 0.05, 0.42, 0.03, 1.28)],
    [EXIT0, P(-0.44, -0.35, -10, 0.05, 0.38, 0.03, 1.29)],
    [EXIT1, P(-0.44, -2.2, -10, -0.3, 0.42, 0.04, 1.28)],
  ];
  // 管理員手機：沿賣家手機讓出的弧線從右側滑入 → 正面慢推 → 往下退場
  const adm: [number, Pose][] = [
    [TC, P(1.7, -0.37, 0, 0.04, -0.6, -0.04, 1.4)],
    [TC + HAND, P(0.12, -0.33, 0, 0.03, -0.12, 0, 1.4)],
    [V0, P(0.1, -0.32, 0, 0.02, -0.05, 0, 1.42)],
    [EXIT0, P(0.09, -0.32, 0, 0.02, -0.02, 0, 1.43)],
    [EXIT1, P(0.09, -2.1, 0, -0.3, 0.06, 0.04, 1.4)],
  ];

  fly(RISE, RISE + 1.15, 0.6, 0.1);
  fly(TC, TC + HAND, 0.5, 0.4);
  fly(EXIT0, EXIT1, 0.5, 0);

  /** 浮出程度：t0 起 0.5 秒浮出（帶一點回彈），t1 起 0.35 秒收回。 */
  const k = (t: number, t0: number, t1: number) => back(soft(t, t0, t0 + 0.5) * (1 - soft(t, t1, t1 + 0.35)));
  const dim = (ps: Pop[]) => 1 - 0.4 * Math.max(0, ...ps.map((p) => Math.min(1, p.k)));

  return (t: number) => {
    word.at(t, 0.1, WORD_OUT);
    tA.at(t, WORD_OUT + 0.45, TB - 0.05);
    tB.at(t, TB + 0.6, TC);
    tC.at(t, TC + 0.65, OUT - 0.75);

    if (t > WORD_OUT && t < OUT) {
      const fields = ['title', 'author', 'publisher'];
      const out = spread(fields.map((f) => `cut_field_${f}`), 0.3, 'col');
      const ai = ['cut_ai_condition', 'cut_ai_price'];
      const aiOut = spread(ai, 0.3, 'col');
      const ps: Pop[] = [
        ...fields.map((f, i) => ({ id: `list_f_${f}`, cut: `cut_field_${f}`, k: k(t, F0 + i * BEAT, TB - 0.45), grow: 0.3, ...out[i], dz: i * 0.1 })),
        ...ai.map((cut, i) => ({ id: `list_${cut}`, cut, k: k(t, R0 + i * BEAT / 2, TC - 0.3), grow: 0.3, ...aiOut[i], dz: i * 0.1 })),
      ];
      world.frame.phones[SELLER] = { pose: glide(t, main, SIGMA), scr: seq(t, seller), glow: dim(ps), pops: ps };
    }
    if (t > TC - 0.2 && t < OUT) {
      // 整張待審卡片一起浮出（含規則原因與 AI 判定）：純文字的去背元件浮起後，原位的字還在下方，會看起來像兩層字
      const ps: Pop[] = [{ id: 'list_review', cut: 'cut_review_card', k: k(t, V0, OUT - 1.45), grow: 0.05 }];
      world.frame.phones[ADMIN] = { pose: glide(t, adm, SIGMA), scr: { a: 'v_admin_review' }, glow: dim(ps), pops: ps };
    }
    tapAi.at(world, t);
  };
}
