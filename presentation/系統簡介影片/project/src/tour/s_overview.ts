import { type Pose } from '../lib/kf';
import { cue, fly } from '../lib/cues';
import { BUYER, CUTS, type World, type Pop } from '../world';
import type { KioskParams } from '../three/textures';
import { seq, stepCues, back, type Step } from '../scenes/kit';
import { line } from './kit2';
import { Title, ChapterWord, glide, soft } from './kit4';
import { onBeat } from './kit5';

const SEC = 'overview';
const SIGMA = 0.42;

/**
 * 第 1 章 系統總覽（旁白 04：線上看書況、付款，賣家存書、買家取書，驗收後才撥款）。
 * 買家 es 的一支手機貫穿全段，書櫃（新北高工）在右側，畫面都是真實資料（正式站 book_id 150）：
 * 手機與書櫃升起，書籍詳情頁的實拍照片與書況（看書況）→ 付款成功對話框（付款）
 * → App 內推入訂單詳情，「訂單進度」卡片原地浮出；書櫃 A01 開門、書放入、關門，卡片換成「已存入書櫃」（賣家存書）
 * → 再開門、書取出、關門，卡片換成「買家已取書」（買家取書）→ 卡片收回，「完成訂單」確認對話框寫明款項此時才撥給賣家（驗收後才撥款）
 * → 手機與書櫃往下退場。
 * 旁白斷句（tts 音檔靜音量測，段落內秒數）：「線上看書況」1.20–2.46、「付款」2.64–3.14、「賣家存書」3.44–4.38、「買家取書」4.54–5.46、「驗收後才撥款」5.76–7.05。
 * 出處：【手冊 p9】「線上看書況→預訂→實體取貨→驗收確認」；【手冊 p10】「驗收後撥款」。
 */
export function sOverview(world: World, ui: HTMLElement, fx: HTMLElement) {
  const L4 = line('04');
  const OUT = L4.end;

  const word = new ChapterWord(fx, '系統總覽');
  const tA = new Title(ui, '線上[看書況]、[付款]');
  const tB = new Title(ui, '賣家[存書]　買家[取書]');
  const tC = new Title(ui, '[驗收]後　才[撥款]');

  const WORD_OUT = 1.0;
  const RISE = WORD_OUT + 0.05;
  const PAY = onBeat(SEC, L4.at + 1.25);
  const ORDER = onBeat(SEC, L4.at + 2.05);
  const F0 = onBeat(SEC, ORDER + 0.4);
  // 存書與取書：開門 → 書放入（取出）→ 關門，關門時訂單進度前進一格（換畫面對齊拍點）
  const DEP = F0, DEP_DONE = onBeat(SEC, DEP + 0.8);
  const TAKE = DEP_DONE + 0.12, TAKE_DONE = onBeat(SEC, TAKE + 0.7);
  const DONE = onBeat(SEC, L4.at + 4.5);
  // 進度卡片要在換成「完成訂單」對話框之前收完（收回 0.35 秒），否則會浮在對話框上
  const F1 = Math.min(TAKE_DONE + 0.15, DONE - 0.36);
  const EXIT0 = OUT - 0.95, EXIT1 = OUT - 0.05;

  const steps: Step[] = [
    [-9, 'v_ov_detail'],
    [PAY, 'v_ov_paid', 0, 0.3],
    [ORDER, 'v_ov_order_0', 1, 0.4],
    [DEP_DONE, 'v_ov_order_1', 0, 0.2],
    [TAKE_DONE, 'v_ov_order_2', 0, 0.2],
    [DONE, 'v_ov_confirm', 0, 0.3],
  ];

  const P = (x: number, y: number, z: number, rx: number, ry: number, rz: number, s: number): Pose => ({ x, y, z, rx, ry, rz, s });
  // 手機在左、書櫃在右；手機只在推入訂單詳情時順勢小幅移位
  const phone: [number, Pose][] = [
    [RISE, P(-0.3, -2.0, 0, 0.5, 0.4, -0.1, 1.38)],
    [RISE + 1.15, P(-0.22, -0.33, 0, 0.06, 0.16, -0.02, 1.38)],
    [ORDER - 0.2, P(-0.21, -0.32, 0, 0.03, 0.1, 0, 1.39)],
    [ORDER + 0.7, P(-0.24, -0.32, 0, 0.03, 0.15, 0, 1.38)],
    [EXIT0, P(-0.23, -0.32, 0, 0.02, 0.1, 0, 1.4)],
    [EXIT1, P(-0.23, -2.1, 0, -0.3, 0.12, 0.04, 1.38)],
  ];
  const cab: [number, Pose][] = [
    [RISE + 0.1, P(0.33, -1.9, -2, 0.14, -0.85, 0, 1.4)],
    [RISE + 1.25, P(0.32, -0.15, -2, 0.07, -0.28, 0, 1.4)],
    [EXIT0, P(0.31, -0.15, -2, 0.06, -0.14, 0, 1.42)],
    [OUT - 0.1, P(0.32, -2.2, -2, 0.12, -0.05, 0, 1.4)],
  ];

  fly(RISE, RISE + 1.25, 0.6, 0);
  stepCues(steps);
  cue('success', PAY + 0.1, { gain: 0.6 });
  cue('lift', F0, { gain: 0.7 });
  for (const [t0, kind] of [[DEP, 'deposit'], [TAKE, 'pickup']] as const) {
    cue('unlock', t0, { gain: 0.5, pan: 0.4 });
    cue('door_open', t0 + 0.02, { dur: 0.3, gain: 0.7, pan: 0.4 });
    cue(kind === 'deposit' ? 'book' : 'slide', t0 + 0.3, { gain: 0.6, pan: 0.4 });
    cue('door_close', t0 + 0.55, { dur: 0.25, gain: 0.7, pan: 0.4 });
  }
  cue('check', DEP_DONE, { gain: 0.5 });
  cue('check', TAKE_DONE, { gain: 0.5 });
  cue('coin_land', DONE + 0.2, { gain: 0.7 });
  fly(EXIT0, EXIT1, 0.5, 0);

  const k = (t: number, t0: number, t1: number) => back(soft(t, t0, t0 + 0.5) * (1 - soft(t, t1, t1 + 0.35)));
  const dim = (ps: Pop[]) => 1 - 0.4 * Math.max(0, ...ps.map((p) => Math.min(1, p.k)));
  const GROW = 0.15;
  // 書櫃螢幕（同韌體畫面）：開門期間顯示大字的櫃門編號與放入／取出說明，取書關門後短暫顯示「作業完成」；
  // 「櫃門開啟中」只有一行小字，在這個距離看起來像一塊黑色方塊，所以不用
  const kiosk = (t: number): KioskParams => {
    const base = { refresh: (t / 30) % 1, digits: 1, check: 0 };
    if (t >= DEP - 0.05 && t < TAKE - 0.05) return { ...base, state: 'open', seconds: Math.max(1, 29 - Math.floor(t - DEP)) };
    if (t >= TAKE - 0.05 && t < TAKE + 0.8) return { ...base, state: 'open', take: true, seconds: Math.max(1, 29 - Math.floor(t - TAKE)) };
    // 作業完成畫面也以深色為主，打勾畫完就回到 QR Code 畫面，退場時不留一塊深色
    if (t >= TAKE + 0.8 && t < TAKE + 1.5) return { ...base, state: 'done', seconds: 0, check: soft(t, TAKE + 0.8, TAKE + 1.2) };
    return { ...base, state: 'qr', seconds: 30 };
  };

  return (t: number) => {
    word.at(t, 0.1, WORD_OUT);
    tA.at(t, WORD_OUT + 0.45, ORDER - 0.15);
    tB.at(t, ORDER + 0.45, DONE - 0.55);
    tC.at(t, DONE + 0.05, OUT - 0.75);

    if (t <= WORD_OUT || t > OUT) return;
    // 訂單進度卡片：同一位置依狀態換成下一張（各狀態高度不同，以上緣對齊：dy 抵銷放大造成的上緣位移）
    const at = t < DEP_DONE ? 0 : t < TAKE_DONE ? 1 : 2;
    const h0 = CUTS.cut_ov_flow_0?.h ?? 0;
    const base = k(t, F0, F1);
    const ps: Pop[] = [0, 1, 2].map((i) => ({
      id: `ov_flow${i}`,
      cut: `cut_ov_flow_${i}`,
      k: i === at ? base : 0,
      grow: GROW,
      dy: (GROW * ((CUTS[`cut_ov_flow_${i}`]?.h ?? h0) - h0)) / 2,
    }));
    world.frame.phones[BUYER] = { pose: glide(t, phone, SIGMA), scr: seq(t, steps), glow: dim(ps), pops: ps };

    const door = (t0: number) => 0.85 * soft(t, t0, t0 + 0.3) * (1 - soft(t, t0 + 0.55, t0 + 0.8));
    world.frame.cabinet = {
      pose: glide(t, cab, SIGMA),
      kiosk: kiosk(t),
      door: Math.max(door(DEP), door(TAKE)),
      deposit: soft(t, DEP + 0.2, DEP + 0.55),
      withdraw: soft(t, TAKE + 0.2, TAKE + 0.55),
    };
  };
}
