import type * as THREE from 'three';
import { type Pose } from '../lib/kf';
import { el, css, place } from '../lib/ui';
import { cue, fly } from '../lib/cues';
import { SELLER, BUYER, ADMIN, RING, SEQS, type World, type Pop } from '../world';
import { seq, stepCues, frameSteps, back, type Step } from '../scenes/kit';
import { line } from './kit2';
import { Title, ChapterWord, glide, soft } from './kit4';
import { onBeat, TapOn, spread } from './kit5';
import './after.css';

const SEC = 'after';
const SIGMA = 0.42;

/**
 * 七項 AI 服務【手冊 p195 表 9-1-1 services/ai 規格描述】，依交易階段排序。兩支手機左右交替以 App 內推入換成下一項的真實畫面，
 * 每項畫面約停 1.1 秒（換到下下一項才被取代），名稱標在該支手機外側。
 */
const ITEMS: { stage: string; name: string; screen: string }[] = [
  { stage: '上架', name: 'AI 輔助上架', screen: 'v_sell_ai_result' },
  { stage: '上架', name: '上架內容審核', screen: 'v_admin_review' },
  { stage: '上架', name: '書籍資料補齊', screen: 'v_after_ai_enrich' },
  { stage: '選書', name: '個人化推薦', screen: 'v_home_rec' },
  { stage: '選書', name: 'AI 書籍顧問', screen: 'v_advisor_answer' },
  { stage: '售後', name: '交易爭議分析', screen: 'v_after_admin_ai' },
  { stage: '售後', name: 'AI 客服', screen: 'v_after_sup_answer' },
];

/**
 * 第 6 章 驗收售後（旁白 17 取書與撥款、18 爭議、19 AI 客服、19b 七項 AI），畫面由 savemybook_app/tool/video_shots/pay_after_test.dart 產生。
 * 旁白停頓（tts 音檔量測，段落內秒數）：17「取書，」3.24、「書況；」5.18、「爭議，」7.18；18「不符，」10.76、「爭議，」13.14、「資料，」14.96；
 * 19「問題，」18.56、「回答，」20.52；19b「上架、」23.88、「售後，」25.18。
 * 取書：書櫃由左側轉入、買家手機由右下升起，按「確認」→ 櫃門開啟，「請取出櫃門 A01 內的書籍」卡片浮出；書從 A01 取出並往下帶出畫面，櫃門關上，書櫃螢幕顯示作業完成。
 * 撥款：書櫃與買家手機往左移出、雪喵的錢包由右跟進：撥款前「目前餘額 9,194／待撥款項 $250」→ 撥款後餘額 9,444，餘額卡片與「賣出 +$250」浮出。
 * 爭議：錢包往左移出、買家的爭議申請由右跟進（旁白 18 開始時到位），爭議說明與兩張實拍佐證照片往右展開 → 買家手機退到左後方、管理員手機沿同一道弧線接力，
 * 按「開始分析」→ 分析中 → 結果出現，AI 分析面板浮出。結果畫面是長截圖（面板展開後高過螢幕，頂端會蓋到狀態列），只顯示上方一個螢幕高。
 * AI 客服：兩支手機往左右兩側移出、AI 客服由下方升起：逐字輸入、送出，回答與「轉接客服人員」卡片往右展開。
 * 七項 AI：客服手機縮小到左側、另一支由右下升起，兩支左右交替以 App 內推入依序換成七項服務的畫面，名稱標在該支手機外側 → 一起往下退場。
 * 出處：買家於開櫃當下即可驗收書況【手冊 p9】；取書滿 24 小時未申請爭議則自動完成並撥款【手冊 p35】；爭議可附佐證照片、受理後暫停撥款【手冊 p90】；
 * AI 分析比對上架資料與爭議說明作為參考、AI 客服可一鍵轉接客服人員【手冊 p37】；七項 AI 服務【手冊 p195 表 9-1-1】。
 */
export function sAfter(world: World, ui: HTMLElement, fx: HTMLElement) {
  const L19 = line('19'), L19b = line('19b');
  const OUT = L19b.end;

  const word = new ChapterWord(fx, '驗收售後');
  const tA = new Title(ui, '同樣掃碼開櫃　[當場驗收]', '取出書籍，立即檢查書況');
  const tA2 = new Title(ui, '滿 24 小時無爭議　[自動撥款]', '款項撥入賣家錢包');
  const tB = new Title(ui, '書況不符　[附照片]申請爭議', '受理後暫停撥款，直至裁決');
  const tB2 = new Title(ui, '[AI] 比對上架資料', '協助管理員處理爭議');
  const tC = new Title(ui, 'AI 客服　[即時回答]', '也能一鍵轉接客服人員');
  const tD = new Title(ui, '七項 [AI 服務]　全程協助', '從上架、選書到售後');
  const names = ITEMS.map((it) => el('p', 'meta after_ai', ui, `<b>${it.stage}</b><span>${it.name}</span>`));

  const WORD_OUT = 1.0;
  const RISE = WORD_OUT + 0.05;
  const HOLD = 1.2, RISE_K = 0.5;

  // ── 取書 ──
  const OPEN = onBeat(SEC, 2.7);
  const PC = onBeat(SEC, 3.3);
  const W0 = OPEN + 0.45, W1 = W0 + 0.6, CARRY = W1 + 0.6;
  const CLOSE = CARRY + 0.05, CLOSED = CLOSE + 0.5;
  const PC1 = Math.max(PC + RISE_K + HOLD, CLOSED);
  const X0 = PC1 + 0.2;
  // ── 撥款：撥款前的錢包只停留片刻，餘額更新後浮出；旁白 18 開始時爭議畫面須已到位，錢包提早退場 ──
  const SWAP = X0 + 1.3;
  const WA = onBeat(SEC, SWAP + 0.2);
  const HALF_B = (onBeat(SEC, 12.0) - onBeat(SEC, 11.6)) / 2;
  const WA1 = WA + HALF_B + RISE_K + HOLD;
  // ── 爭議 ──
  const RD = WA1 + 0.02;
  const D0 = onBeat(SEC, RD + 1.15);
  const D1 = D0 + HALF_B + RISE_K + HOLD;
  const HAND = 1.1;
  const RA = D1 + 0.05;
  // 管理員按「開始分析」→ 分析中 → 結果（長截圖的上方一個螢幕高）→ 分析面板浮出
  const AN = onBeat(SEC, RA + HAND + 0.3);
  const RES = AN + 0.6;
  const AP = onBeat(SEC, RES + 0.25);
  // ── AI 客服 ──
  // 分析面板在管理員手機開始移出前完全收回
  const AP1 = AP + RISE_K + HOLD;
  const RS = Math.max(AP1 + 0.37, L19.at - 0.85);
  const TYPE0 = RS + 1.0, TYPE1 = TYPE0 + 0.8;
  const SEND = onBeat(SEC, TYPE1 + 0.15);
  const ANS = onBeat(SEC, SEND + 0.4);
  const Q0 = onBeat(SEC, ANS + 0.35);
  // 回答與轉接卡片停到旁白「一鍵轉接真人」說到一半，七項 AI 須提早開始，每項才停得夠久
  const Q1 = Math.max(Q0 + HALF_B + RISE_K + HOLD, L19.end - 1.1);
  // ── 七項 AI：每 1.5 拍換一項，左右交替 ──
  const AI0 = Q1 + 0.05;
  const IT0 = onBeat(SEC, AI0 + 0.4);
  const STEP = 1.5 * HALF_B * 2;
  const IT = ITEMS.map((_, i) => IT0 + i * STEP);
  const EXIT0 = OUT - 0.9, EXIT1 = OUT - 0.02;

  const pickSteps: Step[] = [
    [-9, 'v_after_pick_match'],
    [OPEN, 'v_after_pick_open', 1, 0.5],
    [PC1 + 0.38, 'v_after_pick_done', 0, 0.35],
  ];
  const adminSteps: Step[] = [
    [-9, 'v_after_admin_sheet'],
    [AN, 'v_after_admin_wait', 0, 0.12],
    [RES, 'v_after_admin_ai', 0, 0.35],
  ];
  // 七項 AI：左邊由客服手機接續（第 1、3、5、7 項），右邊另一支（第 2、4、6 項），換頁一律 App 內推入
  const leftSteps: Step[] = [[-9, 'v_after_sup_answer'], ...[0, 2, 4, 6].map((i) => [IT[i], ITEMS[i].screen, 1, 0.45] as Step)];
  const rightSteps: Step[] = [[-9, ITEMS[1].screen], ...[3, 5].map((i) => [IT[i], ITEMS[i].screen, 1, 0.45] as Step)];
  const walletSteps: Step[] = [
    [-9, 'v_after_wallet_0'],
    [SWAP, 'v_after_wallet_1', 0, 0.3],
  ];
  let supSteps: Step[] | null = null;
  const buildSup = (): Step[] => [
    [-9, 'v_after_sup_empty'],
    ...frameSteps((SEQS.after_support ?? []).filter((n) => /_t\d+$/.test(n)), TYPE0, TYPE1),
    [SEND, 'v_after_sup_wait', 0, 0.1],
    [ANS, 'v_after_sup_answer', 0, 0.35],
    ...leftSteps.slice(1),
  ];

  stepCues(pickSteps);
  const tapOk = new TapOn(ui, BUYER, 'tap_after_pick_confirm', OPEN - 0.75);
  const tapSend = new TapOn(ui, BUYER, 'tap_after_sup_send', SEND - 0.32);
  const tapAnalyze = new TapOn(ui, ADMIN, 'tap_after_admin_analyze', AN - 0.32);
  cue('unlock', OPEN, { pan: -0.3 });
  cue('door_open', OPEN + 0.05, { dur: 0.5, pan: -0.3 });
  cue('lift', PC, { gain: 0.8 });
  cue('slide', W0, { dur: W1 - W0, pan: -0.3 });
  cue('whoosh', W1 + 0.1, { gain: 0.4, pan: -0.2 });
  cue('door_close', CLOSE, { dur: 0.5, pan: -0.3 });
  cue('slam', CLOSED, { gain: 0.5, pan: -0.3 });
  cue('check', CLOSED + 0.15, { gain: 0.6, pan: -0.3 });
  cue('coin_land', SWAP + 0.1, { gain: 0.8 });
  cue('lift', WA, { gain: 0.8 });
  [0, 1].forEach((i) => cue('pop', D0 + i * HALF_B, { gain: 0.6 }));
  cue('sparkle', RES + 0.05, { gain: 0.6 });
  cue('lift', AP, { gain: 0.8 });
  for (let tk = TYPE0; tk < TYPE1; tk += 0.13) cue('key', tk, { gain: 0.3 });
  cue('send', SEND, { gain: 0.6 });
  cue('bubble', ANS + 0.02, { gain: 0.7 });
  [0, 1].forEach((i) => cue('pop', Q0 + i * HALF_B, { gain: 0.6 }));
  IT.forEach((t) => cue('swipe', t, { gain: 0.45 }));

  const P = (x: number, y: number, z: number, rx: number, ry: number, rz: number, s: number): Pose => ({ x, y, z, rx, ry, rz, s });

  // 書櫃：由左側轉入 → 微微轉動 → 與買家手機一起往左移出（錢包由右跟進）
  const cab: [number, Pose][] = [
    [WORD_OUT + 0.05, P(-1.8, -0.2, -6, 0.08, 1.0, 0.02, 1.25)],
    [WORD_OUT + 1.1, P(-0.33, -0.2, 0, 0.05, 0.36, 0, 1.25)],
    [X0, P(-0.32, -0.2, 0, 0.05, 0.3, 0, 1.27)],
    [X0 + 0.95, P(-2.1, -0.2, 0, 0.05, 0.45, 0, 1.27)],
  ];
  // 取書的買家手機：由右下升起 → 書櫃右側 → 一起往左移出
  const pick: [number, Pose][] = [
    [RISE + 0.1, P(0.75, -2.0, 0, 0.6, -0.6, -0.12, 1.28)],
    [RISE + 1.15, P(0.33, -0.24, 0, 0.05, -0.22, 0, 1.28)],
    [X0, P(0.32, -0.24, 0, 0.03, -0.15, 0, 1.3)],
    [X0 + 0.95, P(-1.45, -0.24, 0, 0.03, 0.2, 0, 1.3)],
  ];
  // 雪喵的錢包：由右跟進到中央 → 慢推 → 往左移出（爭議由右跟進）
  const wallet: [number, Pose][] = [
    [X0 + 0.05, P(1.75, -0.22, 0, 0.04, -0.5, -0.04, 1.32)],
    [X0 + 1.0, P(0.0, -0.22, 0, 0.03, -0.06, 0, 1.32)],
    [RD, P(0.0, -0.22, 0, 0.02, 0.02, 0, 1.34)],
    [RD + 0.9, P(-1.75, -0.22, 0, 0.04, 0.5, 0.04, 1.32)],
  ];
  // 申請爭議的買家手機：由右跟進到左側（元件往右展開）→ 交棒時退到左後方 → 往左移出
  const disp: [number, Pose][] = [
    [RD + 0.05, P(1.7, -0.3, 0, 0.04, -0.5, -0.04, 1.4)],
    [RD + 1.0, P(-0.27, -0.32, 0, 0.03, 0.13, 0, 1.4)],
    [RA, P(-0.28, -0.32, 0, 0.02, 0.1, 0, 1.41)],
    [RA + HAND, P(-0.44, -0.35, -10, 0.05, 0.42, 0.03, 1.28)],
    [RS, P(-0.45, -0.35, -10, 0.05, 0.38, 0.03, 1.29)],
    [RS + 0.9, P(-1.8, -0.35, -10, 0.05, 0.6, 0.04, 1.28)],
  ];
  // 管理員：沿弧線從右側接力滑入 → 正面慢推 → 往右移出（AI 客服由下方升起）
  const adm: [number, Pose][] = [
    [RA, P(1.7, -0.36, 0, 0.04, -0.6, -0.04, 1.36)],
    [RA + HAND, P(0.12, -0.25, 0, 0.03, -0.12, 0, 1.36)],
    [RS, P(0.1, -0.25, 0, 0.02, -0.04, 0, 1.38)],
    [RS + 0.95, P(1.75, -0.28, 0, 0.04, -0.55, -0.04, 1.36)],
  ];
  // 七項 AI：左右兩支放大到與前面各段相同（畫面讀得到），名稱標在各自外側
  const LX = -0.245, RX = 0.245, AIY = -0.3, AIS = 1.34;
  // AI 客服：由下方升起到左側 → 縮小成七項 AI 的左邊那支 → 往下退場
  const sup: [number, Pose][] = [
    [RS + 0.2, P(-0.3, -2.1, 0, 0.5, 0.35, -0.06, 1.4)],
    [RS + 1.15, P(-0.27, -0.32, 0, 0.04, 0.14, 0, 1.4)],
    [AI0, P(-0.28, -0.32, 0, 0.02, 0.1, 0, 1.41)],
    [AI0 + 0.9, P(LX, AIY, 0, 0.03, 0.12, 0, AIS)],
    [EXIT0, P(LX, AIY + 0.01, 0, 0.02, 0.09, 0, AIS + 0.01)],
    [EXIT1, P(LX, -2.0, 0, -0.3, 0.1, 0.03, AIS)],
  ];
  // 七項 AI 的右邊那支：由右下升起 → 正面慢推 → 往下退場
  const right: [number, Pose][] = [
    [AI0 + 0.2, P(0.36, -2.1, 0, 0.5, -0.35, 0.06, AIS)],
    [AI0 + 1.05, P(RX, AIY, 0, 0.03, -0.12, 0, AIS)],
    [EXIT0, P(RX, AIY + 0.01, 0, 0.02, -0.09, 0, AIS + 0.01)],
    [EXIT1, P(RX, -2.0, 0, -0.3, -0.1, -0.03, AIS)],
  ];

  fly(WORD_OUT + 0.05, WORD_OUT + 1.1, 0.6, -0.2);
  fly(X0, X0 + 1.0, 0.6, 0.3);
  fly(RD, RD + 1.0, 0.6, 0.3);
  fly(RA, RA + HAND, 0.5, 0.4);
  fly(RS, RS + 1.0, 0.6, 0.3);
  fly(AI0 + 0.2, AI0 + 1.05, 0.5, 0.3);
  fly(EXIT0, EXIT1, 0.5, 0);

  const k = (t: number, t0: number, t1: number) => back(soft(t, t0, t0 + RISE_K) * (1 - soft(t, t1, t1 + 0.35)));
  const dim = (ps: Pop[]) => 1 - 0.4 * Math.max(0, ...ps.map((p) => Math.min(1, p.k)));

  return (t: number) => {
    word.at(t, 0.1, WORD_OUT);
    tA.at(t, WORD_OUT + 0.45, X0 - 0.1);
    tA2.at(t, X0 + 0.5, RD - 0.05);
    tB.at(t, RD + 0.55, RA - 0.05);
    tB2.at(t, RA + 0.6, RS - 0.05);
    tC.at(t, RS + 0.55, AI0 - 0.05);
    tD.at(t, AI0 + 0.6, OUT - 0.75);

    if (t > WORD_OUT && t < OUT) {
      // 取書：書櫃與買家手機
      if (t < X0 + 1.3) {
        const state = t < OPEN - 0.3 ? 'match' : t < OPEN ? 'opening' : t < CLOSED ? 'open' : 'done';
        world.frame.cabinet = {
          pose: glide(t, cab, SIGMA),
          kiosk: {
            state, refresh: (t / 30) % 1, digits: 1, take: true,
            seconds: state === 'match' ? 52 - Math.floor(t - RISE) : Math.max(0, 30 - Math.floor(t - OPEN)),
            check: soft(t, CLOSED + 0.1, CLOSED + 0.6),
          },
          door: soft(t, OPEN + 0.05, OPEN + 0.55) * (1 - soft(t, CLOSE, CLOSED)),
          deposit: 1,
          withdraw: 0.98 * soft(t, W0, W1),
        };
        // 書取出到櫃門外後，繼續往下帶出畫面（買家拿走），櫃門才關上；cabinet.setDeposit 的路徑只到門外，這段在套用後接續
        const u = soft(t, W1, CARRY);
        if (u > 0) {
          world.frame.after.push(() => {
            const book = (world.cabinet as unknown as { deposit: THREE.Object3D }).deposit;
            book.position.y -= 15 * u;
            book.position.z += 2.5 * u;
            book.rotation.x -= 0.5 * u;
            if (u > 0.995) book.visible = false;
          });
        }
        const ps: Pop[] = [{ id: 'after_pick', cut: 'cut_after_pick_card', k: k(t, PC, PC1), grow: 0.08 }];
        world.frame.phones[BUYER] = { pose: glide(t, pick, SIGMA), scr: seq(t, pickSteps), glow: dim(ps), pops: ps };
      }
      // 撥款：雪喵的錢包（撥款前 9,194、待撥款項 $250 → 撥款後 9,444，餘額卡片與入帳紀錄上下相隔很遠，各自原地浮出）
      if (t > X0 && t < RD + 1.3) {
        const ps: Pop[] = [
          { id: 'after_bal1', cut: 'cut_after_wallet_card1', k: k(t, WA, WA1), grow: 0.2 },
          { id: 'after_income', cut: 'cut_after_income', k: k(t, WA + HALF_B, WA1), grow: 0.12, dz: 0.15 },
        ];
        world.frame.phones[SELLER] = { pose: glide(t, wallet, SIGMA), scr: seq(t, walletSteps), glow: dim(ps), pops: ps };
      }
      // 爭議：買家申請（爭議說明與佐證照片往右展開）
      if (t > RD && t < RS + 1.3) {
        const cuts = ['cut_after_dispute_reason', 'cut_after_dispute_photos'];
        const out = spread(cuts, 0.3, 'col');
        const ps: Pop[] = cuts.map((cut, i) => ({ id: `after_disp${i}`, cut, k: k(t, D0 + i * HALF_B, D1), grow: 0.3, ...out[i], dz: i * 0.1 }));
        world.frame.phones[RING[4]] = { pose: glide(t, disp, SIGMA), scr: { a: 'v_after_dispute' }, glow: dim(ps), pops: ps };
      }
      // 爭議：管理員的 AI 分析
      if (t > RA && t < RS + 1.3) {
        // 面板在畫面下半部，浮起時因透視往下偏，往上抬離字幕區
        const ps: Pop[] = [{ id: 'after_ai', cut: 'cut_after_ai_panel', k: k(t, AP, AP1), grow: 0.05, dy: -200 }];
        world.frame.phones[ADMIN] = { pose: glide(t, adm, SIGMA), scr: seq(t, adminSteps), glow: dim(ps), pops: ps };
      }
      // AI 客服 → 七項 AI 的左邊那支
      if (t > RS) {
        supSteps ??= SEQS.after_support ? buildSup() : null;
        const cuts = ['cut_after_sup_answer', 'cut_after_sup_handoff'];
        const out = spread(cuts, 0.3, 'col');
        const ps: Pop[] = cuts.map((cut, i) => ({ id: `after_sup${i}`, cut, k: k(t, Q0 + i * HALF_B, Q1), grow: 0.3, ...out[i], dz: i * 0.1 }));
        world.frame.phones[BUYER] = { pose: glide(t, sup, SIGMA), scr: supSteps ? seq(t, supSteps) : { a: 'v_after_sup_empty' }, glow: dim(ps), pops: ps };
      }
      // 七項 AI 的右邊那支
      if (t > AI0 + 0.2) world.frame.phones[RING[3]] = { pose: glide(t, right, SIGMA), scr: seq(t, rightSteps) };
    }

    // 服務名稱：換到該項時出現在該支手機外側，被下下一項取代前收起（最後兩項到退場前）
    names.forEach((n, i) => {
      const t1 = i + 2 < IT.length ? IT[i + 2] - 0.05 : EXIT0 - 0.2;
      const a = soft(t, IT[i] + 0.1, IT[i] + 0.4) * (1 - soft(t, t1 - 0.25, t1));
      css(n, 'visibility', a > 0.001 ? 'visible' : 'hidden');
      if (a <= 0.001) return;
      css(n, 'opacity', a.toFixed(3));
      place(n, 960 + (i % 2 === 0 ? LX * 960 - 420 : RX * 960 + 420), 560 + (1 - a) * 12);
    });
    tapOk.at(world, t);
    tapSend.at(world, t);
    tapAnalyze.at(world, t);
  };
}
