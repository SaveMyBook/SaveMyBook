import * as THREE from 'three';
import { cue, fly } from '../lib/cues';
import { SELLER, BUYER, ADMIN, RING, SEQS, type World, type Pop } from '../world';
import type { KioskParams } from '../three/textures';
import type { Pose } from '../lib/kf';
import { seq, frameSteps, type Step } from '../scenes/kit';
import { line, section } from './kit2';
import { glide, soft } from './kit4';
import { onBeat, TapOn } from './kit5';
import { PopBox } from './x_cabinet';
import { TitleV3 } from '../v3/title';
import { CameraPath, orbit, sequence, sectionPans, type CamKey } from '../v3/camera';
import { fit, worldOf } from '../v3/frame';
import { lift, slotColor, preloadSlots, float } from '../v3/pop';
import { kioskPop } from '../v3/kiosk';

const SEC = 'after';
type V = [number, number, number];

/**
 * v3 驗收售後（旁白 17 取書與撥款、18 爭議、19 AI 客服、19b 七項 AI）。規則見 DESIGN.md「v3 規則」，寫法照 s_cabinet_v3.ts。
 * - 17：書櫃完整入鏡、買家手機在右前方；按「確認」→ 櫃門開啟，書櫃螢幕（請取出 A01 內的書籍後關上櫃門）朝鏡頭浮出，
 *   書從 A01 滑出取走 → 關門、作業完成 → 鏡頭向左平移到賣家的代幣中心：餘額 9,194 → 9,444。
 * - 甩鏡（向左）：買家的爭議申請（爭議說明與兩張佐證照片）→ 管理員手機由右側移入、買家手機退到左後方；
 *   按「開始分析」→ 分析中 → 結果，AI 分析面板往兩支手機中間浮出。
 * - 平移（鏡頭向左）：AI 客服逐字輸入、送出、回答；手機往右讓位，「轉接客服人員」卡片往左浮出。
 * - 鏡頭後退並向左：上架（AI 建議）、選書（AI 書籍顧問）兩支手機由左側移入，與 AI 客服扇形排開 → 段落結束時鏡頭向左移出。
 * 每句旁白只浮出一個元素：17 書櫃螢幕、18 AI 分析面板、19 轉接客服人員卡片；19b 以三支手機與副標呈現，不另浮出。
 * 出處：買家於開櫃當下即可驗收書況【複評版手冊第 9 頁】；取書滿 24 小時未申請爭議則自動完成並撥款【第 35 頁、第 89 頁】；
 * 爭議可附佐證照片、受理後暫停撥款【第 36 頁、第 90 頁】；AI 分析比對上架資料與爭議說明供管理員參考、AI 客服複雜問題可一鍵轉接客服人員【第 37 頁】；
 * 七項 AI 服務【第 195 頁 表 9-1-1；web_redesign/BRIEF.md 第 8 點】。
 */
export default function sAfterV3(world: World, ui: HTMLElement, _fx: HTMLElement) {
  world.cabinet.kiosk.setScale(4);
  const L18 = line('18');
  const LEN = section(SEC).end - section(SEC).start;
  const HW = world.stage.halfW;

  // ── 時間（段落內秒數）
  // 17：按確認 → 開櫃 → 螢幕浮出、取書 → 關門、作業完成 → 平移到賣家錢包 → 撥款
  const TAP_OK = onBeat(SEC, 1.4) - 0.32;
  const OPENING = TAP_OK + 0.42;
  const UNLOCK = onBeat(SEC, OPENING + 0.5);
  const KPOP = UNLOCK + 0.35, KDOWN = KPOP + 0.5 + 1.55;
  const W0 = KPOP + 0.75, W1 = W0 + 0.8;
  const CLOSE = KDOWN + 0.2, CLOSED = CLOSE + 0.5;
  const DONE = CLOSED + 0.05;
  const MAB0 = DONE + 0.9, MAB1 = MAB0 + 0.95;
  const PAY = onBeat(SEC, 7.45);
  // 18：甩鏡到爭議 → 管理員手機移入 → 開始分析 → 結果 → AI 分析面板浮出
  const WHIP0 = L18.at - 0.55, WHIP1 = WHIP0 + 0.5;
  const ADM0 = onBeat(SEC, 11.9), ADM1 = ADM0 + 0.75;
  const AN = onBeat(SEC, L18.at + 3.6);
  const RES = onBeat(SEC, AN + 0.75);
  const APOP = RES + 0.15, APOP_OUT = APOP + 0.5 + 1.55;
  // 19：平移到 AI 客服 → 逐字輸入 → 送出 → 回答 → 轉接卡片浮出
  const MCD0 = APOP_OUT + 0.4, MCD1 = MCD0 + 0.95;
  const TYPE0 = MCD1 + 0.15, TYPE1 = TYPE0 + 0.75;
  const SEND = onBeat(SEC, TYPE1 + 0.2);
  const ANS = onBeat(SEC, SEND + 0.4);
  const HPOP = onBeat(SEC, ANS + 0.8), HPOP_OUT = HPOP + 0.5 + 1.55;
  // 19b：鏡頭後退並向左，上架與選書的手機由左側移入 → 段落結束時鏡頭向左移出
  const DOLLY0 = HPOP_OUT + 0.3, DOLLY1 = DOLLY0 + 1.2;
  const EXIT = LEN - 0.9;

  // ── 標題（情境＋解法；數字出自旁白、複評版手冊與 BRIEF）
  // 「24 小時」：旁白 17；手冊第 35 頁「取書滿 24 小時未申請爭議則自動完成並撥款」
  const t17 = new TitleV3(ui, ['買家何時確認書況？', '取書當下即可檢查'], '取書滿 24 小時無爭議，款項自動撥給賣家');
  // 手冊第 37 頁「AI 分析比對上架資料與爭議說明作為參考，裁決退款、駁回或協調結案」
  const t18 = new TitleV3(ui, ['書況與描述不符？', '附上照片申請爭議'], 'AI 比對上架資料與爭議說明，協助管理員裁決');
  // 手冊第 37 頁「複雜問題可一鍵轉接客服人員並建立客服工單」
  const t19 = new TitleV3(ui, ['使用上遇到問題？', 'AI 客服即時回答'], '複雜問題可一鍵轉接客服人員');
  // 七項名稱：BRIEF 第 8 點（同手冊第 195 頁 表 9-1-1 services/ai），依上架、選書、售後排列
  const t19b = new TitleV3(ui, ['哪些環節有 AI 協助？', '七項 AI 服務全程協助'], '上架輔助、資料補齊、上架審核、個人化推薦、書籍顧問、客服、交易爭議分析');
  const popBox = new PopBox(ui);

  const PICK = BUYER, WALLET = SELLER, DISP = RING[4], ADM = ADMIN, SUP = BUYER, LIST = RING[3], FIND = RING[5];
  const taps = [
    new TapOn(ui, PICK, 'tap_after_pick_confirm', TAP_OK),
    new TapOn(ui, ADM, 'tap_after_admin_analyze', AN - 0.32),
    new TapOn(ui, SUP, 'tap_after_sup_send', SEND - 0.32),
  ];
  world.later.push(() => preloadSlots(['cut_after_ai_panel', 'cut_after_sup_handoff']));

  // ── 場景配置：先定鏡頭，再用取景工具依畫面位置擺物件
  const rightOf = (k: CamKey) => {
    const f = new THREE.Vector3(...k.look).sub(new THREE.Vector3(...k.pos));
    return new THREE.Vector3(-f.z, 0, f.x).normalize();
  };
  const fwdOf = (k: CamKey) => new THREE.Vector3(...k.look).sub(new THREE.Vector3(...k.pos)).normalize();
  const shift = (k: CamKey, v: THREE.Vector3, d: number): CamKey => ({
    ...k,
    pos: [k.pos[0] + v.x * d, k.pos[1] + v.y * d, k.pos[2] + v.z * d],
    look: [k.look[0] + v.x * d, k.look[1] + v.y * d, k.look[2] + v.z * d],
  });
  const drift = (p: Pose, d: Partial<Pose>): Pose => ({ ...p, ...Object.fromEntries(Object.entries(d).map(([k, v]) => [k, (p[k] ?? 0) + (v ?? 0)])) });
  /** 沿某個世界方向移開 d 單位（進出場用）。 */
  const away = (p: Pose, v: THREE.Vector3, d: number, extra: Partial<Pose> = {}): Pose =>
    drift({ ...p, x: (p.x ?? 0) + (v.x * d) / HW, z: (p.z ?? 0) + v.z * d }, extra);

  // A：書櫃在原點，鏡頭略高往下看；B：賣家錢包在 A 的左方（向左平移）
  const CA: V = [0, 0, 0];
  const KA1 = orbit(CA, 0, 0.1, 57, [1.5, 1.2, 0]);
  const KA2 = orbit(CA, 0.03, 0.085, 56, [1.4, 1.2, 0]);
  const KA3 = orbit(CA, 0.05, 0.08, 56.5, [1.5, 1.2, 0]);
  const rA = rightOf(KA3);
  const KB1 = shift(orbit(CA, 0.05, -0.02, 56.5, [1.5, 1.2, 0]), rA, -44);
  const KB2 = shift(orbit(CA, 0.07, -0.03, 55, [1.4, 1.2, 0]), rA, -44);
  // C：在 B 的左前方 55°（向左甩鏡；角度小一點，甩鏡中段前後兩支手機都還在畫面邊緣）
  const th = (55 * Math.PI) / 180;
  const fB = fwdOf(KB2);
  const dirC = new THREE.Vector3(fB.x * Math.cos(th) + fB.z * Math.sin(th), 0, -fB.x * Math.sin(th) + fB.z * Math.cos(th)).normalize();
  const C: V = [KB2.pos[0] + dirC.x * 58, 0, KB2.pos[2] + dirC.z * 58];
  const PHI = Math.atan2(KB2.pos[0] - C[0], KB2.pos[2] - C[2]);
  const KC0 = orbit(C, PHI + 0.035, 0.03, 58.5, [0, 0.8, 0]);
  const KC1 = orbit(C, PHI, 0.04, 57, [0, 0.8, 0]);
  const KC2 = orbit(C, PHI - 0.03, 0.05, 56, [0, 0.8, 0]);
  const KC3 = orbit(C, PHI - 0.05, 0.045, 56.5, [0, 0.8, 0]);
  const rC = rightOf(KC3);
  // D：在 C 的左方（向左平移）；E：D 往後退並向左
  const KD1 = shift(orbit(C, PHI - 0.05, 0.07, 56.5, [0, 0.8, 0]), rC, -44);
  const KD2 = shift(orbit(C, PHI - 0.03, 0.065, 55.5, [0, 0.8, 0]), rC, -44);
  const KE = shift(shift(orbit(C, PHI - 0.02, 0.06, 56, [0, 0.8, 0]), rC, -44 - 9), fwdOf(KD2), -9);

  const camA = new CameraPath([[0, KA1], [UNLOCK, KA1], [KDOWN, KA2], [MAB0, KA3]]);
  const camB = new CameraPath([[MAB1 - 0.3, KB1], [WHIP0, KB2]]);
  // 甩鏡後先慢慢推近買家的爭議申請，管理員手機移入時到定位
  const camC = new CameraPath([[WHIP1 - 0.2, KC0], [ADM0, KC1], [ADM1, KC1], [APOP_OUT, KC2], [MCD0, KC3]]);

  // 書櫃：完整入鏡，在標題下方 40px 與字幕帶之間；買家手機在右前方、離鏡頭更近，櫃門開啟時門板在手機後方
  const PCab = fit(world, KA1, 'cabinet', { cx: 780, cy: 640, h: 640, yaw: 0.38 });
  const PBuy = fit(world, KA1, 'phone', { cx: 1560, cy: 566, h: 752, yaw: -0.32, rx: 0.02, rz: -0.025, depth: 40 });
  // 賣家錢包：標題正下方、略為仰拍
  const PW = fit(world, KB1, 'phone', { cx: 960, cy: 614, h: 656, yaw: 0.3, rx: -0.1, rz: 0.04 });
  // 爭議：買家手機先在中央偏左，管理員手機移入時退到左後方；管理員手機在右前方，AI 分析面板浮到兩支中間
  const PD0 = fit(world, KC1, 'phone', { cx: 880, cy: 618, h: 668, yaw: 0.22, rx: 0.03, rz: 0.02 });
  const PD1 = fit(world, KC1, 'phone', { cx: 470, cy: 616, h: 660, yaw: 0.42, rx: 0.03, rz: 0.03 });
  const PAd = fit(world, KC1, 'phone', { cx: 1460, cy: 572, h: 748, yaw: -0.36, rx: 0.03, rz: -0.03 });
  // AI 客服：中央偏右，轉接卡片浮出時略往右讓位，卡片浮到左側
  const PS0 = fit(world, KD1, 'phone', { cx: 1120, cy: 632, h: 680, yaw: -0.2, rx: 0.02, rz: -0.02 });
  const PS1 = fit(world, KD2, 'phone', { cx: 1220, cy: 632, h: 680, yaw: -0.28, rx: 0.02, rz: -0.025 });
  // 七項 AI：選書在中央最前，上架與售後在兩側後方、往外轉，扇形排開並略為交疊
  const PF = fit(world, KE, 'phone', { cx: 960, cy: 628, h: 682, yaw: 0.03, rx: 0.02, depth: 54 });
  const PL = fit(world, KE, 'phone', { cx: 650, cy: 618, h: 600, yaw: 0.55, rx: 0.02, rz: 0.06, depth: 72 });
  const PS2 = fit(world, KE, 'phone', { cx: 1300, cy: 618, h: 600, yaw: -0.55, rx: 0.02, rz: -0.06, depth: 72 });
  const rE = rightOf(KE);
  // 扇形排開後鏡頭繞著中央那支慢慢向左轉，前後三支之間看得出視差
  const G = worldOf(world, PF);
  const about = (k: CamKey, a: number): CamKey => {
    const rot = (p: V): V => { const x = p[0] - G.x, z = p[2] - G.z; return [G.x + x * Math.cos(a) + z * Math.sin(a), p[1], G.z - x * Math.sin(a) + z * Math.cos(a)]; };
    return { ...k, pos: rot(k.pos), look: rot(k.look) };
  };
  const KE2 = about(KE, -0.06);
  const camD = new CameraPath([[MCD1 - 0.3, KD1], [HPOP, KD2], [DOLLY0, KD2], [DOLLY1, KE], [LEN, KE2]]);

  const cabA: [number, Pose][] = [[0, PCab], [UNLOCK, drift(PCab, { ry: -0.02 })], [MAB1, drift(PCab, { ry: -0.05 })]];
  const buyA: [number, Pose][] = [[0, PBuy], [UNLOCK, drift(PBuy, { ry: 0.02 })], [MAB1, drift(PBuy, { ry: 0.05, rz: 0.005 })]];
  // 甩鏡時往後退一點，滾轉時下緣不進入字幕帶
  const walB: [number, Pose][] = [[MAB0, PW], [PAY, drift(PW, { ry: -0.03 })], [WHIP0, drift(PW, { ry: -0.05, rz: -0.01 })], [WHIP1, away(PW, fwdOf(KB2), 5, { ry: -0.07, rz: -0.01 })]];
  const dspC: [number, Pose][] = [[WHIP0, drift(PD0, { ry: -0.04 })], [ADM0, drift(PD0, { ry: 0.03 })], [ADM1, PD1], [MCD1, drift(PD1, { ry: 0.05 })]];
  // 管理員手機甩鏡時不顯示，之後由畫面右側外移入
  const admC: [number, Pose][] = [[ADM0, away(PAd, rC, 26, { ry: -0.35 })], [ADM1, PAd], [APOP, drift(PAd, { ry: 0.02 })], [MCD1, drift(PAd, { ry: 0.05 })]];
  const supD: [number, Pose][] = [[MCD0, PS0], [HPOP - 0.1, drift(PS0, { ry: 0.02 })], [HPOP + 0.5, PS1], [DOLLY0, drift(PS1, { ry: 0.02 })], [DOLLY1, PS2], [LEN, drift(PS2, { ry: 0.04 })]];
  const lstE: [number, Pose][] = [[DOLLY0 + 0.3, away(away(PL, rE, -30, { ry: 0.3 }), fwdOf(KE), 6)], [DOLLY0 + 1.25, PL], [LEN, drift(PL, { ry: -0.04 })]];
  const fndE: [number, Pose][] = [[DOLLY0 + 0.8, away(away(PF, rE, -36, { ry: 0.3 }), fwdOf(KE), 8)], [DOLLY0 + 1.8, PF], [LEN, drift(PF, { ry: -0.03 })]];

  // ── App 畫面
  const pickSteps: Step[] = [
    [-9, 'v_after_pick_match'],
    [OPENING, 'v_cab_opening', 0, 0.001],
    [UNLOCK, 'v_after_pick_open', 0, 0.001],
    [DONE, 'v_after_pick_done', 0, 0.001],
  ];
  const walSteps: Step[] = [[-9, 'v_after_wallet_0'], [PAY, 'v_after_wallet_1', 0, 0.001]];
  const admSteps: Step[] = [[-9, 'v_after_admin_sheet'], [AN, 'v_after_admin_wait', 0, 0.001], [RES, 'v_after_admin_ai', 0, 0.001]];
  // 逐字輸入的連續畫面由截圖工具輸出（sequences.json），world.load() 之後才有，所以播放時才組
  let supSteps: Step[] | null = null;
  const buildSup = (): Step[] => [
    [-9, 'v_after_sup_empty'],
    ...frameSteps((SEQS.after_support ?? []).filter((n) => /_t\d+$/.test(n)), TYPE0, TYPE1),
    [SEND, 'v_after_sup_wait', 0, 0.001],
    [ANS, 'v_after_sup_answer', 0, 0.001],
  ];

  // ── 書櫃螢幕：取書（take）時顯示「請取出 A01 內的書籍後關上櫃門」；開門後朝鏡頭浮起，往畫面左上
  const kiosk = (t: number, cam: CamKey, cab: Pose): KioskParams => {
    const pop = kioskPop(world, lift(t, KPOP, KDOWN), cam, cab, { toward: 9, left: 3.2, up: -0.45, scale: 1.85 });
    const base = { refresh: (Math.max(0, t) / 30) % 1, seconds: 52, digits: 1, check: 0, take: true, clock: '14:25', tick: t, pop };
    if (t < OPENING) return { ...base, state: 'match', seconds: 52 - Math.floor(Math.max(0, t)) };
    if (t < UNLOCK) return { ...base, state: 'opening' };
    if (t < CLOSED) return { ...base, state: 'open', seconds: 25 - Math.floor(t - UNLOCK) };
    return { ...base, state: 'done', check: soft(t, DONE, DONE + 0.5) };
  };


  // ── 音效：只對應本段畫面上的動作
  fly(0, 0.9, 0.5, 0.2);
  cue('select', OPENING, { gain: 0.5, pan: 0.4 });
  cue('unlock', UNLOCK, { pan: -0.2 });
  cue('door_open', UNLOCK + 0.05, { dur: 0.6, pan: -0.1 });
  cue('lift', KPOP, { gain: 0.7, pan: -0.5 });
  cue('slide', W0, { dur: W1 - W0, pan: -0.1 });
  cue('pop', KDOWN + 0.25, { gain: 0.35, pan: -0.5 });
  cue('door_close', CLOSE, { dur: 0.5, pan: -0.1 });
  cue('slam', CLOSED, { pan: -0.1, gain: 0.7 });
  cue('success', DONE + 0.05, { pan: -0.3 });
  fly(MAB0, MAB1, 0.5, 0.3);
  cue('coin_land', PAY, { gain: 0.8 });
  fly(WHIP0, WHIP1, 0.7, 0);
  fly(ADM0, ADM1, 0.4, 0.6);
  cue('sparkle', RES + 0.05, { gain: 0.6, pan: 0.4 });
  cue('lift', APOP, { gain: 0.7, pan: 0.2 });
  fly(MCD0, MCD1, 0.5, 0.3);
  for (let tk = TYPE0; tk < TYPE1; tk += 0.12) cue('key', tk, { gain: 0.3, pan: 0.1 });
  cue('send', SEND, { gain: 0.6, pan: 0.1 });
  cue('bubble', ANS + 0.02, { gain: 0.7, pan: 0.1 });
  cue('pop', HPOP, { gain: 0.5, pan: -0.1 });
  fly(DOLLY0 + 0.3, DOLLY0 + 1.25, 0.45, -0.5);
  fly(DOLLY0 + 0.8, DOLLY0 + 1.8, 0.45, -0.2);
  fly(EXIT, LEN, 0.5, 0.3);

  return (t: number) => {
    // 段落前後各 1 秒這一層仍會顯示：標題與點擊每格都要更新（段落外為隱藏），否則從中途開始算圖時會停在預設的可見狀態
    t17.at(t, 1.0, WHIP0 - 0.45);
    t18.at(t, WHIP1 + 0.05, MCD0 - 0.45);
    t19.at(t, MCD1 + 0.05, HPOP_OUT - 0.05);
    t19b.at(t, HPOP_OUT + 0.5, EXIT - 0.45);
    taps.forEach((tp) => tp.at(world, t));
    if (t < -0.05 || t > LEN + 0.05) return;

    const cam = sectionPans(sequence(t, [camA, camB, camC, camD], [
      { at: MAB0, kind: 'move' }, { at: WHIP0, kind: 'whip' }, { at: MCD0, kind: 'move' },
    ]), t, LEN, { sec: SEC });
    world.frame.camera = cam;

    // 17：書櫃與買家手機
    if (t < MAB1 + 0.05) {
      const pose = glide(t, cabA, 0.42);
      world.frame.cabinet = {
        pose,
        kiosk: kiosk(t, cam, pose),
        door: soft(t, UNLOCK + 0.05, UNLOCK + 0.65) * (1 - soft(t, CLOSE, CLOSED)),
        deposit: 1,
        // 取書與 s_cabinet_v3 的放書對稱：書從 A01 滑到櫃門外即由買家取走（setDeposit 在 withdraw ≥ 0.99 時隱藏）
        withdraw: soft(t, W0, W1),
      };
      world.frame.after.push(() => {
        world.cabinet.setFocus('board', 0);
        world.cabinet.setFocus('locks', 0);
      });
      world.frame.phones[PICK] = { pose: glide(t, buyA, 0.42), scr: seq(t, pickSteps) };
    }
    // 17：賣家的代幣中心（撥款前 9,194、待撥款項 $250 → 撥款後 9,444）
    if (t > MAB0 - 0.05 && t < WHIP1 + 0.05) {
      world.frame.phones[WALLET] = { pose: glide(t, walB, 0.42), scr: seq(t, walSteps) };
    }
    // 18：爭議申請與管理員的 AI 分析
    if (t > WHIP0 - 0.05 && t < MCD1 + 0.05) {
      world.frame.phones[DISP] = { pose: glide(t, dspC, 0.42), scr: { a: 'v_after_dispute' } };
      if (t > ADM0) {
        const k = lift(t, APOP, APOP_OUT), f = float(t, k);
        const ps: Pop[] = [{ id: 'after3_ai', cut: 'cut_after_ai_panel', k, grow: 0.24, dx: -600 + f.dx, dy: -40 + f.dy, dz: 2.4 + f.dz, slot: slotColor('cut_after_ai_panel') }];
        world.frame.phones[ADM] = { pose: glide(t, admC, 0.3), scr: seq(t, admSteps), pops: ps };
      }
    }
    // 19、19b：AI 客服（19b 起為扇形排開中的售後那支）
    if (t > MCD0 - 0.05) {
      supSteps ??= SEQS.after_support ? buildSup() : null;
      const k = lift(t, HPOP, HPOP_OUT), f = float(t, k, 0.7);
      const ps: Pop[] = [{ id: 'after3_handoff', cut: 'cut_after_sup_handoff', k, grow: 0.42, dx: -740 + f.dx, dy: -30 + f.dy, dz: 2.4 + f.dz, slot: slotColor('cut_after_sup_handoff') }];
      world.frame.phones[SUP] = { pose: glide(t, supD, 0.42), scr: supSteps ? seq(t, supSteps) : { a: 'v_after_sup_empty' }, pops: ps };
    }
    if (t > DOLLY0 + 0.25) {
      world.frame.phones[LIST] = { pose: glide(t, lstE, 0.42), scr: { a: 'v_sell_ai_result' } };
      world.frame.phones[FIND] = { pose: glide(t, fndE, 0.42), scr: { a: 'v_advisor_answer' } };
    }
    popBox.at(world);
  };
}
