import { type Pose } from '../lib/kf';
import { cue, fly } from '../lib/cues';
import { SELLER, BUYER, ADMIN, type World, type Pop } from '../world';
import { Tap, seq, stepCues, back, type Step } from '../scenes/kit';
import { R } from '../scenes/story';
import { line } from './kit2';
import { Title, ChapterWord, glide, soft } from './kit4';

/**
 * 浮出元件的精確邊界（以 tools/bounds.py 從截圖量測，含邊線；圓角 12pt），只抬起元件本身、不帶到周圍背景。
 */
const FIELD_CARDS = [187.3, 266.3, 345.3, 424.3].map((y) => ({ x: 16, y, w: 361, h: 70.7, r: 12 }));
const PRICE_CARD = { x: 16, y: 497, w: 361, h: 128, r: 12 };
const REVIEW_BOX = { x: 29, y: 291, w: 335, h: 44, r: 12 };
const TAU = Math.PI * 2;

/**
 * 第 2 章 賣家上架（旁白 05 ISBN、06 AI 書況售價、07 雙層審核）。
 * 版面規則：標題固定在上方（y < 230），手機全程在標題下方，不與任何文字重疊；進出場只走下方與左右。
 * 章名大字單獨出現 → 收起後手機由下方升起，輸入 ISBN，四張書目卡依序浮出
 * → 手機原地快轉一圈（背面時換畫面），後方第二支手機錯落 → 建議售價卡浮出
 * → 兩支手機往左甩出、管理員手機由右甩入 → 審核理由浮出 → 往下退場（段落結束前完全出畫，下一段章名才出現）。
 */
export function sList(world: World, ui: HTMLElement, fx: HTMLElement) {
  const L5 = line('05'), L6 = line('06'), L7 = line('07');
  const OUT = L7.end;

  const word = new ChapterWord(fx, '賣家上架');
  const tA = new Title(ui, '掃一下 [ISBN]', '書名、作者、出版社　自動帶入');
  const tB = new Title(ui, '拍張照片　[AI] 判斷書況', '依照片與定價，建議售價區間');
  const tC = new Title(ui, '規則＋AI　[雙層把關]', '售價異常或需人工複核，送交審核');

  const WORD_OUT = 1.0;
  const T0 = L5.at;
  const TYPE = [T0 + 1.35, T0 + 1.5, T0 + 1.65, T0 + 1.83];
  const AI1 = T0 + 2.1, SHEET1 = T0 + 2.75, POP1 = SHEET1 + 0.6;
  const SPIN0 = L6.at - 0.5, SPIN1 = L6.at + 0.6;
  const SWAP = (SPIN0 + SPIN1) / 2;
  const AI2 = SPIN1 + 0.2, SHEET2 = AI2 + 1.0, POP2 = SHEET2 + 0.65;
  const WHIP = L7.at - 0.45;
  const POP3 = L7.at + 1.2;

  const steps: Step[] = [
    [-9, 's_sell_isbn_t00'],
    ...(['t03', 't06', 't09', 't13'].map((n, i) => [TYPE[i], `s_sell_isbn_${n}`, 0, 0.03] as Step)),
    [AI1 + 0.07, 's_sell_isbn_loading', 0, 0.1],
    [SHEET1, 's_sell_fill', 3, 0.5],
    [SWAP, 's_sell_photos', 0, 0.01],
    [AI2 + 0.12, 's_sell_ai_loading_1', 0, 0.12],
    [AI2 + 0.42, 's_sell_ai_loading_2', 0, 0.12],
    [AI2 + 0.7, 's_sell_ai_loading_3', 0, 0.12],
    [SHEET2, 's_sell_ai_sheet_220', 3, 0.5],
  ];
  stepCues(steps.filter((s) => s[0] !== SWAP));
  TYPE.forEach((t) => cue('key', t, { gain: 0.35 }));
  FIELD_CARDS.forEach((_, i) => cue('pop', POP1 + i * 0.12, { gain: 0.6 }));
  [POP2, POP3].forEach((t) => cue('lift', t, { gain: 0.8 }));
  cue('swipe', SPIN0 + 0.15, { gain: 1 });
  cue('whoosh', WHIP + 0.1, { gain: 0.9 });
  const mid = (r: { x: number; y: number; w: number; h: number }): [number, number] => [r.x + r.w / 2, r.y + r.h / 2];
  const taps = [new Tap(ui, SELLER, ...mid(R.isbnAi), AI1), new Tap(ui, SELLER, ...mid(R.photosAi), AI2)];

  const P = (x: number, y: number, z: number, rx: number, ry: number, rz: number, s: number): Pose => ({ x, y, z, rx, ry, rz, s });
  // 主手機：由下方升起 → 慢推 → 正面 → 原地快轉一圈 → 正面 → 往左甩出
  const main: [number, Pose][] = [
    [WORD_OUT + 0.15, P(0.12, -2.0, 0, 0.55, 0.5, -0.12, 1.4)],
    [WORD_OUT + 1.25, P(0.04, -0.34, 0, 0.1, 0.32, -0.05, 1.4)],
    [SHEET1 + 0.2, P(0.02, -0.33, 0, 0.05, 0.16, -0.03, 1.41)],
    [POP1 - 0.1, P(0.0, -0.32, 0, 0.02, 0.0, 0, 1.42)],
    [SPIN0 - 0.15, P(0.0, -0.32, 0, 0.02, -0.03, 0, 1.43)],
    [SWAP, P(0.02, -0.33, -3, 0.05, TAU / 2, 0.02, 1.4)],
    [SPIN1 + 0.15, P(0.1, -0.33, 0, 0.03, -0.12 + TAU, 0.02, 1.4)],
    [POP2 - 0.1, P(0.09, -0.32, 0, 0.02, TAU, 0, 1.42)],
    [WHIP, P(0.08, -0.32, 0, 0.02, 0.03 + TAU, 0, 1.43)],
    [WHIP + 0.55, P(-1.7, -0.36, 0, 0.04, 0.5 + TAU, 0.05, 1.4)],
  ];
  // 錯落在後方的第二支手機（上架第 1 步完成的書目）
  const side: [number, Pose][] = [
    [SPIN1 - 0.35, P(-1.5, -0.5, -14, 0.15, 1.0, 0.08, 1.28)],
    [SPIN1 + 0.85, P(-0.38, -0.34, -10, 0.05, 0.44, 0.03, 1.28)],
    [WHIP, P(-0.35, -0.34, -10, 0.05, 0.36, 0.02, 1.29)],
    [WHIP + 0.55, P(-2.2, -0.36, -10, 0.06, 0.8, 0.05, 1.28)],
  ];
  // 管理員手機：由右甩入 → 正面 → 往下退場
  const adm: [number, Pose][] = [
    [WHIP + 0.05, P(1.8, -0.34, 0, 0.04, -0.7, -0.05, 1.4)],
    [WHIP + 0.75, P(0.0, -0.33, 0, 0.03, -0.1, 0, 1.4)],
    [POP3 - 0.1, P(0.0, -0.32, 0, 0.02, 0.0, 0, 1.42)],
    [OUT - 0.85, P(0.0, -0.32, 0, 0.02, 0.03, 0, 1.43)],
    [OUT + 0.1, P(0.0, -2.1, 0, -0.35, 0.1, 0.04, 1.4)],
  ];

  fly(WORD_OUT + 0.15, WORD_OUT + 1.25, 0.6, 0.1);
  fly(SPIN1 - 0.35, SPIN1 + 0.85, 0.4, -0.5);
  fly(OUT - 0.85, OUT + 0.1, 0.5, 0);

  const pops = (keys: { id: string; screen: string; rect: Pop['rect']; t0: number }[], t: number, t1: number) =>
    keys.map(({ id, screen, rect, t0 }) => ({ id, screen, rect, k: back(soft(t, t0, t0 + 0.5) * (1 - soft(t, t1, t1 + 0.35))) }));

  return (t: number) => {
    word.at(t, 0.1, WORD_OUT);
    tA.at(t, WORD_OUT + 0.45, SPIN0 + 0.05);
    tB.at(t, SPIN1 - 0.15, WHIP);
    tC.at(t, WHIP + 0.65, OUT - 0.75);

    if (t > WORD_OUT && t < WHIP + 0.7) {
      // 四張相鄰的卡片：放大 12%，同時以第 2、3 張之間為中心上下拉開，放大後仍保持 8pt 間隔，深度也錯開
      const GROW = 0.12, H = FIELD_CARDS[0].h, GAP = FIELD_CARDS[1].y - FIELD_CARDS[0].y;
      const SPREAD = H * (1 + GROW) + 8 - GAP;
      const p1 = pops(FIELD_CARDS.map((r, i) => ({ id: `f${i}`, screen: 's_sell_fill', rect: r, t0: POP1 + i * 0.12 })), t, SPIN0 - 0.25)
        .map((p, i) => ({ ...p, grow: GROW, dy: (i - 1.5) * SPREAD, dz: i * 0.15 }));
      const p2 = pops([{ id: 'price', screen: 's_sell_ai_sheet_220', rect: PRICE_CARD, t0: POP2 }], t, WHIP - 0.15);
      const dim = Math.max(...p1.map((p) => Math.min(1, p.k)), Math.min(1, p2[0].k));
      world.frame.phones[SELLER] = { pose: glide(t, main), scr: seq(t, steps), glow: 1 - 0.4 * dim, pops: [...p1, ...p2] };
    }
    if (t > SPIN1 - 0.8 && t < WHIP + 0.7) {
      world.frame.phones[BUYER] = { pose: glide(t, side), scr: { a: 's_sell_fill' } };
    }
    if (t > WHIP - 0.3 && t < OUT + 0.1) {
      const p3 = pops([{ id: 'review', screen: 'a_listing_review', rect: REVIEW_BOX, t0: POP3 }], t, OUT - 1.15);
      world.frame.phones[ADMIN] = { pose: glide(t, adm), scr: { a: 'a_listing_review' }, glow: 1 - 0.4 * Math.min(1, p3[0].k), pops: p3 };
    }
    taps.forEach((tp) => tp.at(world, t));
  };
}
