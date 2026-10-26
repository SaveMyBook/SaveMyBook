import { cue, fly } from '../lib/cues';
import { SELLER, ADMIN, type World, type Pop } from '../world';
import type { Pose } from '../lib/kf';
import { seq, stepCues, type Step } from '../scenes/kit';
import { line, section } from './kit2';
import { glide, soft } from './kit4';
import { onBeat, TapOn } from './kit5';
import { TitleV3 } from '../v3/title';
import { CameraPath, orbit, sequence, sectionPans, type CamKey } from '../v3/camera';
import { fit } from '../v3/frame';
import { lift, slotColor, preloadSlots, float } from '../v3/pop';

const SEC = 'list';

/**
 * v3 賣家上架（旁白 05 掃描 ISBN、06 AI 書況與售價、07 雙層審核）。內容與畫面順序沿用第二版核准樣片 s_list.ts，版型與浮出改為 v3。
 * - 05（仰拍）：掃描條碼 → 返回表單查詢書目 → 欄位帶入 → 「書名」欄位往右浮出，手機往左讓位。
 * - 平移（鏡頭向左）：手機回到中央；接著原地翻轉一圈，背面朝向鏡頭時（拍照）換成照片頁。
 * - 06：點「AI 帶入」→ AI 分析中 → AI 建議，「建議售價」卡片往左浮出（依定價與書況「近全新」計算的建議區間），手機往右讓位。
 * - 甩鏡（向左）到管理員手機（略俯拍），手機由畫面左緣進入中央。
 * - 07：內容審核的待審卡片往右浮出、手機往左讓位：同一張卡片上有規則送審的原因與 AI 判定。
 * 每句旁白只浮出一個元素：05 書名欄位、06 建議售價、07 待審卡片。
 */
export default function sListV3(world: World, ui: HTMLElement, _fx: HTMLElement) {
  const L5 = line('05'), L6 = line('06'), L7 = line('07');
  const LEN = section(SEC).end - section(SEC).start;
  const EXIT = LEN - 0.9;

  // ── 時間（段落內秒數）
  // 05：掃描成功 → 返回表單（查詢中）→ 欄位帶入 → 書名欄位浮出
  const SCAN_OK = onBeat(SEC, L5.at + 1.3);
  const BACK = SCAN_OK + 0.41;
  const FILLED = onBeat(SEC, BACK + 0.9);
  const FPOP = FILLED + 0.41;
  // 05 與 06 之間：鏡頭向左平移，接著手機翻轉一圈
  const MOVE0 = L5.end - 0.2, MOVE1 = MOVE0 + 0.95;
  const FPOP_OUT = MOVE0 - 0.4;
  const FLIP0 = MOVE1 - 0.1, FLIP1 = FLIP0 + 0.9, FLIP_MID = (FLIP0 + FLIP1) / 2;
  // 06：點 AI 帶入 → 分析中 → 建議（底部展開）→ 建議售價卡片浮出
  const TAP_AI = FLIP1 + 0.2;
  const AI = onBeat(SEC, TAP_AI + 0.4);
  const RES = onBeat(SEC, AI + 0.8);
  const PPOP = RES + 0.45;
  // 07：甩鏡到管理員手機 → 待審卡片浮出 → 段落結束前收回、鏡頭移出
  const WHIP0 = Math.max(PPOP + 0.5 + 1.52 + 0.4, L7.at - 0.05), WHIP1 = WHIP0 + 0.5;
  const PPOP_OUT = WHIP0 - 0.4;
  const RPOP = onBeat(SEC, WHIP1 + 0.6);
  const RPOP_OUT = EXIT - 0.45;

  // ── 標題（情境＋解法）
  // 05：複評版手冊 PDF 第 49 頁 表5-1-1「掃描書籍 ISBN 條碼，系統透過 Google Books／Open Library 自動帶出書名、作者、出版社」
  const tA = new TitleV3(ui, ['上架一本書，要輸入多少資料？', '掃描 ISBN，自動帶出書目'], '書名、作者與出版社由 Google Books 與 Open Library 查詢帶入');
  // 06：複評版手冊 PDF 第 252 頁 表12-3-3「AI 依照片與定價判斷書況並提出建議售價區間；照片不足以判斷時會提示補拍」
  const tB = new TitleV3(ui, ['書況與售價如何決定？', 'AI 依照片判斷書況並建議售價'], '依照片與定價提出建議售價區間，照片不足時提示補拍');
  // 07：複評版手冊 PDF 第 134 頁 7-4 狀態機（售價異常、疑似非正規來源、含站外交易或聯絡資訊，或 AI 審核需人工確認時轉為審核中）；
  // 網站 BRIEF 第 2 點「規則即時攔截……AI 判讀最多 4 張照片，必要時交管理員複核」；
  // 類別名稱同後端 services/ai/moderation.js 的 CATEGORY_LABELS（站外交易或聯絡資訊），規則在 services/listing-screening.js
  const tC = new TitleV3(ui, ['上架內容由誰把關？', '規則與 AI 雙層審核'], '規則攔截售價異常、站外交易或聯絡資訊，AI 再判讀內容與照片');
  const tapAi = new TapOn(ui, SELLER, 'tap_sell_ai', TAP_AI);
  world.later.push(() => preloadSlots(['cut_field_title', 'cut_ai_price', 'cut_review_card']));

  // ── 鏡頭：A 仰拍（05）→ 向左平移 → B 平視（06）→ 向左甩鏡 → C 略俯拍（07）
  const KA0: CamKey = { pos: [-0.3, -4.6, 60], look: [0.2, 0.8, 0] };
  const KA1: CamKey = { pos: [-1.0, -4.3, 59.6], look: [0.3, 0.85, 0] };
  const KB0: CamKey = { pos: [-7.6, 0.2, 58.4], look: [-6.6, 0.5, 0] };
  const KB1: CamKey = { pos: [-8.6, 0.7, 57.4], look: [-6.9, 0.5, 0] };
  const th = (-70 * Math.PI) / 180;
  // C 的主體放低，略俯拍的鏡頭才會和 B 同高：甩鏡時鏡頭只轉向、不升高，B 的手機不會被往下推進字幕帶
  const C: [number, number, number] = [KB1.pos[0] + Math.sin(th) * 58, KB1.pos[1] - 57.5 * Math.sin(0.13), KB1.pos[2] - Math.cos(th) * 58];
  const PHI = Math.atan2(KB1.pos[0] - C[0], KB1.pos[2] - C[2]);
  const KC0 = orbit(C, PHI, 0.13, 57.5, [0, 0.4, 0]);
  const KC1 = orbit(C, PHI + 0.04, 0.125, 57, [0, 0.4, 0]);
  const camA = new CameraPath([[0, KA0], [MOVE0, KA1]]);
  const camB = new CameraPath([[MOVE1 - 0.3, KB0], [WHIP0, KB1]]);
  const camC = new CameraPath([[WHIP1 - 0.2, KC0], [LEN, KC1]]);

  // ── 擺位：手機在標題正下方時最高約 690px（上緣在副標下方 40px）。平常在中央，元件浮出時往另一側讓位
  // A：仰拍；書名欄位往右浮出時手機往左退、轉向右方
  const PA0 = fit(world, KA0, 'phone', { cx: 930, cy: 630, h: 672, yaw: 0.1, rx: -0.06, rz: 0.03 });
  const PA1 = fit(world, KA0, 'phone', { cx: 690, cy: 630, h: 672, yaw: 0.32, rx: -0.06, rz: 0.04 });
  // B：平視；建議售價往左浮出時手機往右退、轉向左方
  const PB0 = fit(world, KB0, 'phone', { cx: 960, cy: 630, h: 672, yaw: -0.08, rx: 0.02, rz: -0.02 });
  const PB1 = fit(world, KB0, 'phone', { cx: 1235, cy: 630, h: 672, yaw: -0.3, rx: 0.02, rz: -0.035 });
  // C：管理員手機往後仰（略俯拍）；待審卡片往右浮出時手機往左退
  const PC0 = fit(world, KC0, 'phone', { cx: 900, cy: 626, h: 664, yaw: 0.12, rx: -0.14, rz: 0.07 });
  const PC1 = fit(world, KC0, 'phone', { cx: 670, cy: 626, h: 664, yaw: 0.3, rx: -0.14, rz: 0.09 });
  const drift = (p: Pose, d: Partial<Pose>): Pose => ({ ...p, ...Object.fromEntries(Object.entries(d).map(([k, v]) => [k, (p[k] ?? 0) + (v ?? 0)])) });

  const sell: [number, Pose][] = [
    [0, drift(PA0, { ry: 0.05 })],
    [FPOP, PA0],
    [FPOP + 0.6, PA1],
    [MOVE0, drift(PA1, { ry: -0.02 })],
    [MOVE1, PB0],
    [PPOP, drift(PB0, { ry: -0.02 })],
    [PPOP + 0.6, PB1],
    [WHIP0 + 0.3, drift(PB1, { ry: 0.04, rz: 0.01 })],
  ];
  // 甩鏡途中手機由畫面左緣進入：畫面邊緣的透視放大會讓左下角下沉，先略高、略小、略往順時針轉，甩鏡結束時落到定位
  const admIn = drift(PC0, { ry: 0.06, y: 1.8 / world.stage.halfH, rz: -0.05, s: -0.08 * (PC0.s ?? 1) });
  const adm: [number, Pose][] = [[WHIP0, admIn], [WHIP0 + 0.33, admIn], [WHIP1 + 0.2, PC0], [RPOP, drift(PC0, { ry: -0.02 })], [RPOP + 0.6, PC1], [LEN, drift(PC1, { ry: -0.04, rz: 0.01 })]];
  // 翻轉一圈：另外疊加在 ry 上（五次平滑），背面朝向鏡頭的那一刻換畫面
  // 側面朝向鏡頭時機身的厚度會讓外框變高，翻轉途中略縮小，外框不進入字幕帶
  const spin = (t: number) => 2 * Math.PI * soft(t, FLIP0, FLIP1);
  const shrink = (t: number) => 1 - 0.07 * Math.sin(Math.PI * soft(t, FLIP0 - 0.1, FLIP1 + 0.1));

  const seller: Step[] = [
    [-9, 'v_sell_scan'],
    [SCAN_OK, 'v_sell_scan_ok', 0, 0.001],
    [BACK, 'v_sell_form_lookup', 2, 0.45],
    [FILLED, 'v_sell_form_filled', 0, 0.12],
    [FLIP_MID, 'v_sell_photos', 0, 0.001],
    [AI, 'v_sell_ai_loading', 3, 0.4],
    [RES, 'v_sell_ai_result', 3, 0.45],
  ];


  // ── 音效：只對應本段畫面上的動作
  fly(0, 0.9, 0.5, -0.3);
  cue('scan', SCAN_OK - 0.6, { dur: 0.6, pan: -0.2 });
  cue('beep', SCAN_OK, { pan: -0.2 });
  stepCues(seller);
  cue('fill', FILLED, { gain: 0.6, pan: -0.2 });
  cue('lift', FPOP, { gain: 0.7, pan: 0.3 });
  cue('pop', FPOP_OUT + 0.25, { gain: 0.35, pan: 0.2 });
  fly(MOVE0, MOVE1, 0.5, 0.2);
  fly(FLIP0, FLIP1, 0.4, 0.3);
  cue('shutter', FLIP_MID, { gain: 0.7, pan: 0.3 });
  cue('lift', PPOP, { gain: 0.7, pan: -0.2 });
  cue('pop', PPOP_OUT + 0.25, { gain: 0.35, pan: 0 });
  fly(WHIP0, WHIP1, 0.7, 0);
  cue('lift', RPOP, { gain: 0.7, pan: 0.2 });
  cue('pop', RPOP_OUT + 0.25, { gain: 0.35, pan: 0 });
  fly(EXIT, LEN, 0.5, 0.3);

  return (t: number) => {
    // 標題與點擊每格都要更新：段落圖層在段落前後 1 秒也會顯示，沒更新時會停在預設的可見狀態
    tA.at(t, 1.0, MOVE0 - 0.45);
    tB.at(t, MOVE1 + 0.05, WHIP0 - 0.45);
    tC.at(t, WHIP1 + 0.35, EXIT - 0.45);
    tapAi.at(world, t);
    if (t < 0 || t > LEN) return;

    const cam = sectionPans(sequence(t, [camA, camB, camC], [{ at: MOVE0, kind: 'move' }, { at: WHIP0, kind: 'whip' }]), t, LEN, { sec: SEC });
    world.frame.camera = cam;

    if (t < WHIP1 + 0.05) {
      const kf = lift(t, FPOP, FPOP_OUT), kp = lift(t, PPOP, PPOP_OUT);
      const ff = float(t, kf), fp = float(t, kp, 1.3);
      const ps: Pop[] = [
        { id: 'list3_title', cut: 'cut_field_title', k: kf, grow: 0.36, dx: 640 + ff.dx, dy: -40 + ff.dy, dz: 4.0 + ff.dz, slot: slotColor('cut_field_title') },
        { id: 'list3_price', cut: 'cut_ai_price', k: kp, grow: 0.36, dx: -640 + fp.dx, dy: -170 + fp.dy, dz: 4.0 + fp.dz, slot: slotColor('cut_ai_price') },
      ];
      const pose = glide(t, sell, 0.42);
      world.frame.phones[SELLER] = { pose: { ...pose, ry: (pose.ry ?? 0) + spin(t), s: (pose.s ?? 1) * shrink(t) }, scr: seq(t, seller), pops: ps };
    }
    if (t > WHIP0 - 0.05) {
      const kr = lift(t, RPOP, RPOP_OUT);
      const fr = float(t, kr, 2.1);
      const ps: Pop[] = [{ id: 'list3_review', cut: 'cut_review_card', k: kr, grow: 0.25, dx: 600 + fr.dx, dy: -10 + fr.dy, dz: 3.5 + fr.dz, slot: slotColor('cut_review_card') }];
      world.frame.phones[ADMIN] = { pose: glide(t, adm, 0.42), scr: { a: 'v_admin_review' }, pops: ps };
    }
  };
}
