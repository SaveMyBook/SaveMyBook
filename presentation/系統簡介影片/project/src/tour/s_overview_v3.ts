import { cue, fly } from '../lib/cues';
import { BUYER, CUTS, type World, type Pop } from '../world';
import type { KioskParams } from '../three/textures';
import type { Pose } from '../lib/kf';
import { seq, stepCues, type Step } from '../scenes/kit';
import { line, section } from './kit2';
import { glide, soft } from './kit4';
import { onBeat } from './kit5';
import { TitleV3 } from '../v3/title';
import { CameraPath, orbit, sectionPans } from '../v3/camera';
import { fit } from '../v3/frame';
import { lift, slotColor, preloadSlots, float } from '../v3/pop';

const SEC = 'overview';

/**
 * v3 系統總覽（旁白 04：線上看書況、付款，賣家存書、買家取書，驗收後才撥款）。規則見 DESIGN.md「v3 規則」。
 * 一個鏡位：買家手機在左、書櫃在右，鏡頭緩慢環繞。段落只有 7 秒，不換鏡頭；卡片浮出時手機往左讓位。
 * - 看書況（書籍詳情）→ 付款（付款成功）→ 推入訂單詳情。
 * - 唯一的浮出元素是「訂單進度」卡片：往手機與書櫃之間浮出，書櫃 A01 存書關門時換成「已存入書櫃」、
 *   取書關門時換成「買家已取書」（確認書況後完成訂單，滿 24 小時未申請爭議自動完成），交代「驗收後才撥款」的流程。
 * 旁白斷句（段落內秒數）：「線上看書況」1.20–2.46、「付款」2.64–3.14、「賣家存書」3.44–4.38、「買家取書」4.54–5.46、「驗收後才撥款」5.76–7.05。
 * 出處：複評版手冊 PDF 第 49 頁 表5-1-1「款項由平台保管，訂單完成後才撥給賣家」；
 * 第 50 頁「買家確認書況無誤按『完成訂單』，取書滿 24 小時未申請爭議則自動完成並撥款」。
 */
export default function sOverviewV3(world: World, ui: HTMLElement, _fx: HTMLElement) {
  const L4 = line('04');
  const LEN = section(SEC).end - section(SEC).start;
  const EXIT = LEN - 0.9;

  // ── 時間（段落內秒數，對齊配樂拍點）
  const PAY = onBeat(SEC, 2.5);
  const ORDER = onBeat(SEC, 3.2);
  const KPOP = ORDER + 0.42;
  // 存書：開門 → 書放入 → 關門（0.8 秒），關門時訂單進度換成下一個狀態
  const DEP = ORDER + 0.2, DEP_DONE = DEP + 0.8;
  const TAKE = onBeat(SEC, L4.at + 3.34), TAKE_DONE = TAKE + 0.8;
  // 卡片在鏡頭移出前落回（鏡頭移出時的位移以三次方緩入，前 0.15 秒幾乎不動）
  const KDOWN = Math.max(KPOP + 0.5 + 1.55, EXIT - 0.2);

  // ── 標題（情境＋解法）：出處同上
  const title = new TitleV3(ui, ['不必見面，如何完成交易？', '書櫃存取，驗收後才撥款'], '線上看書況與付款，賣家、買家分別至書櫃存書與取書');
  world.later.push(() => preloadSlots(['cut_ov_flow_0', 'cut_ov_flow_1', 'cut_ov_flow_2']));

  // ── 鏡頭與擺位：先定鏡頭，再用取景工具依畫面位置擺物件
  const C: [number, number, number] = [0, 0, 0];
  const K0 = orbit(C, -0.05, 0.1, 58.5, [0, 0.6, 0]);
  const K1 = orbit(C, 0.04, 0.085, 57.5, [0, 0.6, 0]);
  const cam = new CameraPath([[0, K0], [LEN, K1]]);
  const KM = cam.at(LEN / 2);
  // 手機：標題下方（上緣在副標下方 40px）、轉向右方的書櫃；卡片浮出時往左讓位
  const PP0 = fit(world, KM, 'phone', { cx: 650, cy: 630, h: 672, yaw: 0.18, rx: -0.03, rz: 0.03, depth: 55 });
  const PP = fit(world, KM, 'phone', { cx: 490, cy: 630, h: 672, yaw: 0.28, rx: -0.03, rz: 0.04, depth: 55 });
  // 書櫃：畫面右側、完整入鏡，正面轉向手機
  const PC = fit(world, KM, 'cabinet', { cx: 1395, cy: 650, h: 622, yaw: -0.5, depth: 61 });
  const drift = (p: Pose, d: Partial<Pose>): Pose => ({ ...p, ...Object.fromEntries(Object.entries(d).map(([k, v]) => [k, (p[k] ?? 0) + (v ?? 0)])) });
  const phone: [number, Pose][] = [[0, drift(PP0, { ry: 0.05 })], [KPOP, PP0], [KPOP + 0.6, PP], [LEN, drift(PP, { ry: -0.05, rz: -0.01 })]];
  const cabinet: [number, Pose][] = [[0, drift(PC, { ry: 0.04 })], [LEN, drift(PC, { ry: -0.04 })]];

  const steps: Step[] = [
    [-9, 'v_ov_detail'],
    [PAY, 'v_ov_paid', 0, 0.12],
    [ORDER, 'v_ov_order_0', 1, 0.4],
    [DEP_DONE, 'v_ov_order_1', 0, 0.001],
    [TAKE_DONE, 'v_ov_order_2', 0, 0.001],
  ];

  // ── 書櫃螢幕（同韌體畫面）：開門期間顯示櫃門編號，取書關門後短暫顯示作業完成，之後回到 QR Code
  const kiosk = (t: number): KioskParams => {
    const base = { refresh: (t / 30) % 1, digits: 1, check: 0, clock: '14:25', tick: t };
    if (t >= DEP - 0.05 && t < TAKE - 0.05) return { ...base, state: 'open', seconds: Math.max(1, 30 - Math.floor(t - DEP)) };
    if (t >= TAKE - 0.05 && t < TAKE_DONE) return { ...base, state: 'open', take: true, seconds: Math.max(1, 30 - Math.floor(t - TAKE)) };
    if (t >= TAKE_DONE && t < TAKE_DONE + 0.9) return { ...base, state: 'done', seconds: 0, check: soft(t, TAKE_DONE, TAKE_DONE + 0.4) };
    return { ...base, state: 'qr', seconds: 30 };
  };


  // ── 音效：只對應本段畫面上的動作
  fly(0, 0.9, 0.5, -0.2);
  cue('success', PAY + 0.03, { gain: 0.5, pan: -0.5 });
  stepCues(steps);
  cue('lift', KPOP, { gain: 0.7, pan: -0.1 });
  for (const [t0, kind] of [[DEP, 'book'], [TAKE, 'slide']] as const) {
    cue('unlock', t0, { gain: 0.5, pan: 0.5 });
    cue('door_open', t0 + 0.02, { dur: 0.3, gain: 0.6, pan: 0.5 });
    cue(kind, t0 + 0.32, { gain: 0.55, pan: 0.5 });
    cue('door_close', t0 + 0.55, { dur: 0.25, gain: 0.6, pan: 0.5 });
  }
  cue('check', DEP_DONE, { gain: 0.5, pan: -0.1 });
  cue('check', TAKE_DONE, { gain: 0.5, pan: -0.1 });
  cue('pop', KDOWN + 0.25, { gain: 0.35, pan: -0.3 });
  fly(EXIT, LEN, 0.5, 0.3);

  const door = (t: number, t0: number) => soft(t, t0, t0 + 0.3) * (1 - soft(t, t0 + 0.55, t0 + 0.8));
  const h0 = CUTS.cut_ov_flow_0?.h ?? 231;

  return (t: number) => {
    // 標題每格都要更新：段落圖層在段落前後 1 秒也會顯示，沒更新時會停在預設的可見狀態
    title.at(t, 1.0, EXIT - 0.45);
    if (t < 0 || t > LEN) return;
    const k = cam.at(t);
    world.frame.camera = sectionPans(k, t, LEN, { sec: SEC });

    // 訂單進度卡片：同一位置依狀態換成下一張（各狀態高度不同，以上緣對齊）
    const at = t < DEP_DONE ? 0 : t < TAKE_DONE ? 1 : 2;
    const kk = lift(t, KPOP, KDOWN);
    const f = float(t, kk);
    const ps: Pop[] = [0, 1, 2].map((i) => {
      const cut = `cut_ov_flow_${i}`;
      const h = CUTS[cut]?.h ?? h0;
      const grow = 0.34;
      return { id: `ov3_flow${i}`, cut, k: i === at ? kk : 0, grow, dx: 540 + f.dx, dy: 50 + (grow * (h - h0)) / 2 + f.dy, dz: 3.4 + f.dz, slot: slotColor(cut) };
    });
    world.frame.phones[BUYER] = { pose: glide(t, phone, 0.42), scr: seq(t, steps), pops: ps };
    world.frame.cabinet = {
      pose: glide(t, cabinet, 0.42),
      kiosk: kiosk(t),
      door: Math.max(door(t, DEP), door(t, TAKE)),
      deposit: soft(t, DEP + 0.2, DEP + 0.55),
      withdraw: soft(t, TAKE + 0.2, TAKE + 0.55),
    };
  };
}
