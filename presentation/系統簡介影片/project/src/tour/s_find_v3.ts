import { cue, fly } from '../lib/cues';
import { BUYER, RING, SEQS, type World, type Pop } from '../world';
import type { Pose } from '../lib/kf';
import { seq, frameSteps, Tap, type Step } from '../scenes/kit';
import { line, section } from './kit2';
import { glide } from './kit4';
import { onBeat, TapOn } from './kit5';
import { TitleV3 } from '../v3/title';
import { CameraPath, orbit, sequence, sectionPans } from '../v3/camera';
import { fit } from '../v3/frame';
import { lift, slotColor, preloadSlots, float } from '../v3/pop';

const SEC = 'find';
const HOME = RING[0], ADV = RING[1], CHAT = RING[2];
type V = [number, number, number];

/**
 * v3 買家找書（旁白 08、09、10）。浮出：08 推薦書卡、09 推薦書籍、10 警示橫幅。
 * 物件放在世界座標 x≈-520 一帶：段落交界前後 0.05 秒會和相鄰段落同時寫入，鏡頭以後寫者為準，主體離得遠才不會出現在別段的畫面裡。
 */
export default function sFindV3(world: World, ui: HTMLElement, _fx: HTMLElement) {
  const L9 = line('09');
  const LEN = section(SEC).end - section(SEC).start;

  // 旁白實際發聲（段落內秒數，量自 audio/out/旁白.wav）：08「…ISBN 搜尋」1.18–4.85、「也會收到個人化推薦」5.13–6.93；
  // 09「說出需求與預算」7.44–9.08、「AI 書籍顧問幫你挑書」9.33–11.53；10「聊天室支援文字、圖片與語音」12.03–14.88、「出現高風險訊息時」15.13–16.98、「會即時提醒防詐」17.23–18.73
  const TYPE0 = onBeat(SEC, 1.6), TYPE1 = TYPE0 + 0.85;
  const RESULT = onBeat(SEC, 3.0);
  const RPOP = onBeat(SEC, 4.7), RPOP_OUT = RPOP + 0.5 + 1.55;
  const WHIP0 = RPOP_OUT + 0.3, WHIP1 = WHIP0 + 0.5;
  const ATYPE0 = Math.max(WHIP1 + 0.15, L9.at + 0.2), ATYPE1 = ATYPE0 + 1.15;
  const SEND = ATYPE1 + 0.15;
  const ANS = onBeat(SEC, SEND + 0.45);
  const PPOP = ANS + 0.1, PPOP_OUT = PPOP + 0.5 + 1.55;
  const MOVE0 = PPOP_OUT + 0.2, MOVE1 = MOVE0 + 0.95;
  const PUSH = onBeat(SEC, 14.45);
  const MSG = PUSH + 0.55;
  const WPOP = onBeat(SEC, MSG + 0.2);
  const EXIT = LEN - 0.9;
  const WPOP_OUT = EXIT - 0.45;

  // 搜尋：複評版手冊 PDF 第 247 頁（頁碼 232）表 12-2-2「於搜尋列輸入書名、作者或 ISBN」；
  // 推薦：第 248 頁（頁碼 233）表 12-2-4「『為您推薦』依收藏、購物車與瀏覽紀錄推薦書籍」
  const tA = new TitleV3(ui, ['如何找到想要的書？', '書名、作者或 ISBN 都能搜尋'], '首頁另依收藏、購物車與瀏覽紀錄推薦書籍');
  // 第 258 頁（頁碼 243）表 12-5-8「描述需求（分類、預算、書況等）…AI 即推薦站內可購買之書籍並說明理由」
  const tB = new TitleV3(ui, ['不知道該選哪一本？', 'AI 書籍顧問依需求與預算挑書'], '只推薦站內可購買的書籍，並說明推薦理由');
  // 第 255 頁（頁碼 240）表 12-5-1、12-5-2 文字、圖片與語音；第 259 頁（頁碼 244）表 12-5-9「高風險時聊天室上方顯示警示橫幅」
  const tC = new TitleV3(ui, ['聊天時如何避免受騙？', '高風險訊息即時提醒'], '聊天室支援文字、圖片與語音訊息');

  // 搜尋頁右上角的「搜尋」（App 邏輯座標，量自 v_search_typing_t04：文字範圍 x 347–377、y 85–100）
  const taps = [
    new Tap(ui, BUYER, 362, 92, RESULT - 0.32),
    new TapOn(ui, ADV, 'tap_advisor_send', SEND - 0.32),
  ];
  world.later.push(() => preloadSlots(['cut_home_rec_card_1', 'cut_advisor_pick_1']));

  const FA: V = [-520, 0, 0];
  const KA0 = orbit(FA, 0.05, 0.035, 58, [0, 0.5, 0]);
  const KA1 = orbit(FA, -0.03, 0.03, 57, [0, 0.5, 0]);
  const th = (-62 * Math.PI) / 180;
  const FB: V = [KA1.pos[0] + Math.sin(th) * 58, 0, KA1.pos[2] - Math.cos(th) * 58];
  const PHI = Math.atan2(KA1.pos[0] - FB[0], KA1.pos[2] - FB[2]);
  const rx = Math.cos(PHI), rz = -Math.sin(PHI);
  const KB0 = orbit(FB, PHI, 0.26, 57, [0, 0.4, 0]);
  const KB1 = orbit(FB, PHI + 0.03, 0.245, 56, [0, 0.4, 0]);
  const KB2 = orbit(FB, PHI + 0.045, 0.24, 56.5, [0, 0.4, 0]);
  const FC: V = [FB[0] - rx * 46, 0, FB[2] - rz * 46];
  const KC0 = orbit(FC, PHI + 0.02, 0.02, 57, [0, 0.6, 0]);
  const KC1 = orbit(FC, PHI - 0.02, 0.025, 56, [0, 0.6, 0]);
  const KC2 = orbit(FC, PHI - 0.04, 0.03, 56.5, [0, 0.6, 0]);

  const camA = new CameraPath([[0, KA0], [WHIP0, KA1]]);
  const camB = new CameraPath([[WHIP1 - 0.2, KB0], [ANS, KB1], [MOVE0, KB2]]);
  const camC = new CameraPath([[MOVE1 - 0.3, KC0], [MSG, KC1], [LEN, KC2]]);

  const PS = fit(world, KA0, 'phone', { cx: 650, cy: 630, h: 668, yaw: 0.26, rx: 0.02, rz: 0.07, depth: 54 });
  const PH = fit(world, KA0, 'phone', { cx: 1270, cy: 636, h: 652, yaw: -0.26, rx: 0.02, rz: -0.07, depth: 62 });
  const PB = fit(world, KB0, 'phone', { cx: 780, cy: 632, h: 672, yaw: 0.24, rx: -0.38, rz: -0.1 });
  const PC0 = fit(world, KC0, 'phone', { cx: 960, cy: 632, h: 676, yaw: -0.22, rx: 0.03, rz: 0.03 });
  const PC = fit(world, KC1, 'phone', { cx: 1140, cy: 632, h: 676, yaw: -0.32, rx: 0.03, rz: 0.035 });
  const drift = (p: Pose, d: Partial<Pose>): Pose => ({ ...p, ...Object.fromEntries(Object.entries(d).map(([k, v]) => [k, (p[k] ?? 0) + (v ?? 0)])) });

  const sKeys: [number, Pose][] = [[0, PS], [RESULT, drift(PS, { ry: -0.03 })], [WHIP0, drift(PS, { ry: -0.05, rz: 0.005 })]];
  const hKeys: [number, Pose][] = [[0, PH], [RPOP, drift(PH, { ry: 0.02 })], [WHIP0, drift(PH, { ry: 0.04 })]];
  // 平移途中鏡頭由俯拍轉為平視，手機會被帶低；先略往上抬，途中不進入字幕帶（標題此時已離場）
  const bKeys: [number, Pose][] = [
    [WHIP0, PB], [ANS, drift(PB, { ry: -0.03 })], [MOVE0, drift(PB, { ry: -0.05, rz: 0.005 })],
    [MOVE0 + 0.3, drift(PB, { ry: -0.05, rz: 0.005, y: 1.0 / world.stage.halfH })], [MOVE1, drift(PB, { ry: -0.05, rz: 0.005, y: 1.3 / world.stage.halfH })],
  ];
  const cKeys: [number, Pose][] = [[MOVE1 - 0.3, PC0], [PUSH, drift(PC0, { ry: 0.03 })], [WPOP + 0.55, PC], [LEN, drift(PC, { ry: 0.05, rz: -0.005 })]];

  // 逐字輸入的畫面清單由截圖工具輸出（sequences.json），world.load() 之後才有，所以播放時才組
  let searchSteps: Step[] | null = null;
  const buildSearch = (): Step[] => [
    [-9, 'v_search_typing_t00'],
    ...frameSteps((SEQS.search_typing ?? []).filter((n) => /_t0[1-9]$/.test(n)), TYPE0, TYPE1),
    [RESULT, 'v_search_result', 0, 0.001],
  ];
  let advSteps: Step[] | null = null;
  const buildAdv = (): Step[] => [
    [-9, 'v_advisor_empty'],
    ...frameSteps((SEQS.advisor_type ?? []).filter((n) => /_t\d+$/.test(n)), ATYPE0, ATYPE1),
    [SEND, 'v_advisor_wait', 0, 0.001],
    [ANS, 'v_advisor_answer', 0, 0.001],
  ];
  const chatSteps: Step[] = [
    [-9, 'v_chat_seller'],
    [PUSH, 'v_chat_scam_0', 1, 0.45],
    [MSG, 'v_chat_scam', 0, 0.001],
  ];


  fly(0, 0.9, 0.5, 0.2);
  [0, 1, 2, 3].forEach((i) => cue('key', TYPE0 + (i * (TYPE1 - TYPE0)) / 3, { gain: 0.3, pan: -0.3 }));
  cue('pop', RPOP, { gain: 0.5, pan: 0.2 });
  fly(WHIP0, WHIP1, 0.7, 0);
  cue('typing', ATYPE0, { dur: ATYPE1 - ATYPE0, n: 9, gain: 0.6, pan: -0.4 });
  cue('send', SEND, { gain: 0.6, pan: -0.4 });
  cue('bubble', ANS, { gain: 0.5, pan: -0.4 });
  cue('pop', PPOP, { gain: 0.5, pan: 0 });
  fly(MOVE0, MOVE1, 0.5, 0.3);
  cue('swipe', PUSH, { gain: 0.8, pan: 0.4 });
  cue('bubble', MSG, { gain: 0.6, pan: 0.4 });
  cue('alert', MSG + 0.1, { gain: 0.6, pan: 0.4 });
  cue('pop', WPOP, { gain: 0.5, pan: 0.1 });
  fly(EXIT, LEN, 0.5, 0.3);

  return (t: number) => {
    // 標題在提早返回之前更新：段落前後 1 秒這一層仍會顯示，沒更新的標題會停在預設的不透明狀態
    tA.at(t, 1.0, WHIP0 - 0.45);
    tB.at(t, WHIP1 + 0.1, MOVE0 - 0.45);
    tC.at(t, MOVE1 + 0.05, EXIT - 0.45);
    taps.forEach((tp) => tp.at(world, t));
    if (t < -0.05 || t > LEN + 0.05) return;

    const cam = sectionPans(sequence(t, [camA, camB, camC], [{ at: WHIP0, kind: 'whip' }, { at: MOVE0, kind: 'move' }]), t, LEN, { sec: SEC });
    world.frame.camera = cam;

    if (t < WHIP1 + 0.05) {
      searchSteps ??= SEQS.search_typing ? buildSearch() : null;
      world.frame.phones[BUYER] = { pose: glide(t, sKeys, 0.42), scr: searchSteps ? seq(t, searchSteps) : { a: 'v_search_typing_t00' } };
      const k = lift(t, RPOP, RPOP_OUT), f = float(t, k);
      const ps: Pop[] = [{ id: 'find3_rec', cut: 'cut_home_rec_card_1', k, grow: 0.4, dx: -300 + f.dx, dy: -10 + f.dy, dz: 2.2 + f.dz, slot: slotColor('cut_home_rec_card_1') }];
      world.frame.phones[HOME] = { pose: glide(t, hKeys, 0.42), scr: { a: 'v_home' }, pops: ps };
    }
    if (t > WHIP0 - 0.05 && t < MOVE1 + 0.05) {
      advSteps ??= SEQS.advisor_type ? buildAdv() : null;
      const k = lift(t, PPOP, PPOP_OUT), f = float(t, k, 0.7);
      const ps: Pop[] = [{ id: 'find3_pick', cut: 'cut_advisor_pick_1', k, grow: 0.48, dx: 585 + f.dx, dy: -330 + f.dy, dz: 2.6 + f.dz, slot: slotColor('cut_advisor_pick_1') }];
      world.frame.phones[ADV] = { pose: glide(t, bKeys, 0.42), scr: advSteps ? seq(t, advSteps) : { a: 'v_advisor_empty' }, pops: ps };
    }
    if (t > MOVE0 - 0.05) {
      const k = lift(t, WPOP, WPOP_OUT), f = float(t, k, 1.4);
      // 橫幅滿版、左右貼齊螢幕邊緣，周圍取色會量到橫幅本身的淡紅色；空位改用聊天室底色（cuts.json 的 backdrop）
      const ps: Pop[] = [{ id: 'find3_warn', cut: 'cut_warn_banner', k, grow: 0.3, dx: -430 + f.dx, dy: 65 + f.dy, dz: 2.4 + f.dz, slot: '#F3F5F7' }];
      world.frame.phones[CHAT] = { pose: glide(t, cKeys, 0.42), scr: seq(t, chatSteps), pops: ps };
    }
  };
}
