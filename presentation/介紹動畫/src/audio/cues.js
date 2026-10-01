'use strict';
// 由動畫原始碼的時間公式推導每個音效的精確時間（秒）。輸出 cues.json
const SRC = require('path').resolve(__dirname, '..');
const full = require(`${SRC}/scenes/full`);
const flow = require(`${SRC}/scenes/flow`);
const fs = require('fs');

const W = full.WIN;
const CLOSE = full.CLOSE, CARD = full.CARD;
const R0 = 12.2, SWAP = R0 + 7.0, FULL_AT = SWAP + 2.6, XR = [SWAP + 3.0, SWAP + 10.4], F = SWAP + 10.8, OUT = F + 24.0, A = OUT + 2.3;
const t = { ...flow.times(F), matchPhone: F + 6.35, matchKiosk: F + 6.45, digits: [F + 9.1, F + 9.1] };
t.steps = [F + 0.5, F + 6.7, F + 12.0, F + 18.9];
const LIFT = t.digits[0] - 0.95;

const cues = [];
// type, time, gain(0-1 相對), pan(-1..1), extra
const c = (type, time, gain = 1, pan = 0, extra = {}) => cues.push({ type, t: +time.toFixed(4), gain, pan, ...extra });
// 鏡頭飛行：whoosh 的峰值落在飛行中段（速度最快）
const fly = (t0, t1, gain = 1, pan = 0, ease = 'inout') => c('whoosh', t0, gain, pan, { dur: +(t1 - t0).toFixed(3), ease });
// 標題逐字升起
const title = (t0, gain = 1) => c('textin', t0, gain);
// 里程表數字滾動
const odo = (t0, dur, digits, gain = 1, pan = 0) => { c('roll', t0, gain, pan, { dur: +(dur + (digits - 1) * 0.1).toFixed(3) }); c('land', t0 + dur + (digits - 1) * 0.1, gain, pan); };

// ── 1. 開場
title(0.6);
fly(3.0, 3.6, 0.5);
for (const [t0, t1] of [[3.25, 6.4], [6.75, 9.8]]) {
  [0, 1].forEach((i) => {
    const ti = t0 + 0.15 + i * 0.15, pan = i ? 0.35 : -0.35;
    c('pop', ti, 0.8, pan);
    odo(ti + 0.15, 1.2, 3, 0.9, pan);
  });
  fly(t1 - 0.05, t1 + 0.45, 0.45);
}
title(10.1);
// ── 2. Logo
c('riser_short', R0 + 0.35, 1, 0, { dur: 1.3 });            // 書本線條描繪
c('line', R0 + 0.43, 0.9, -0.3, { dur: 1.15 });
c('line', R0 + 0.43, 0.9, 0.3, { dur: 1.15 });
c('impact', R0 + 1.5, 1);                                     // 書本填色（13.7）
c('shimmer', R0 + 2.1, 0.8);                                  // 書頁光澤
fly(R0 + 2.75, R0 + 3.75, 0.5);                               // Logo 上移
[...'救「舊」我的書'].forEach((ch, i) => c('type', R0 + 3.0 + i * 0.05, 0.55, -0.3 + i * 0.1));
c('shimmer', R0 + 4.35, 0.7);                                 // 字樣光澤
[0, 1, 2].forEach((i) => c('pop', R0 + 4.35 + i * 0.1, 0.9, -0.4 + i * 0.4));
fly(R0 + 5.9, R0 + 7.0, 0.8);                                 // Logo 飛向書櫃銘牌
// ── 3. 書櫃建構
c('line', SWAP + 0.35, 0.7, 0, { dur: 0.8 });
c('line', SWAP + 0.55, 0.7, -0.2, { dur: 1.0 });
[0, 1, 2, 3].forEach((i) => c('tick', SWAP + 0.85 + i * 0.07, 0.5, -0.3 + i * 0.2));
c('build', SWAP + 1.35, 1);                                   // 實體浮現
c('power', SWAP + 1.8, 0.9);                                  // 螢幕開機
fly(SWAP + 0.2, FULL_AT, 0.9);                                // 大幅拉遠
c('shimmer', SWAP + 0.35 + 2.1, 0.5);
c('pop', FULL_AT - 0.4, 0.5, -0.8);                           // 左上角品牌徽章
[0, 1, 2, 3, 4].forEach((i) => { const ti = XR[0] + 0.9 + i * 0.22; c('line', ti + 0.05, 0.45, i < 4 ? 0.5 : -0.5, { dur: 0.45 }); c('tick', ti + 0.35, 0.6, i < 4 ? 0.5 : -0.5); });
// ── 4. 存書流程
fly(XR[1], F + 0.9, 0.9);
t.steps.forEach((s) => c('dot', s, 0.5, -0.6));
fly(t.phoneIn, t.phoneIn + 1.1, 0.8, 0.6, 'emph');                    // 手機滑入
c('glint', t.phoneIn + 0.95, 0.5, 0.6);
c('scan', t.phoneIn + 1.1, 0.35, 0.6, { dur: t.detect - t.phoneIn - 1.1 });
c('beep', t.detect, 1, 0.5);                                  // 掃到 QR
c('ring', t.detect + 0.02, 0.6, 0.5);
c('success', t.detect + 0.3, 0.8, 0);                         // QR Code 驗證成功
c('swap', t.confirm, 0.5, 0.5);
c('tap', t.openTap, 1, 0.6);
c('zip', t.openTap + 0.1, 0.6, 0.2, { dur: 0.7 });
fly(F + 6.6, F + 7.5, 0.5);
c('digital', t.matchKiosk + 0.02, 0.9, -0.2);                 // 書櫃顯示 25
c('lift', LIFT, 0.7, -0.2);                                   // 數字飛起
fly(LIFT + 0.1, t.digits[0] - 0.05, 0.5, 0.3);
c('key', t.digits[0], 1, 0.55); c('key', t.digits[0] + 0.035, 0.8, 0.6);
c('pop', t.digits[1] + 0.25, 0.7, -0.1);                      // 定位確認
c('tap', t.okTap, 1, 0.6);
c('zip', t.okTap + 0.08, 0.5, 0.2, { dur: 0.34 });
c('process', t.opening, 0.5, -0.1, { dur: t.open - t.opening });
fly(F + 11.6, F + 12.8, 0.7);
c('digital', t.open, 0.7, -0.2);
c('unlock', t.door.unlatch, 1, -0.2);                         // 電磁鎖
c('pop', t.door.unlatch + 0.1, 0.6, -0.4);                   // A01 已開鎖
c('door_open', t.door.swing, 0.8, -0.3, { dur: t.door.settle[0] - t.door.swing });
c('bump', t.door.settle[0], 0.5, -0.3);
[1, 2, 3, 4, 5].forEach((k) => c('clock', t.open + k, 0.45, -0.1)); // 倒數 29→25
fly(t.book[0], t.book[1], 0.45, -0.1);
c('book', t.book[1], 1, -0.2);                                // 書放入
c('slide', t.book[1], 0.5, -0.2, { dur: t.book[2] - t.book[1] });
c('door_close', t.door.close[0], 0.7, -0.3, { dur: t.door.close[1] - t.door.close[0] });
c('slam', t.door.close[1], 1, -0.3);
c('zip', t.door.close[1] + 0.05, 0.5, 0.2, { dur: 0.5 });
c('digital', t.kioskDone, 0.6, -0.2);
c('tap', t.doneTap, 0.8, 0.6);
c('success', t.result, 1, 0.3);
c('lock', t.door.close[1] + 0.8, 0.4, -0.3);
fly(F + 17.9, F + 19.4, 0.6);
c('notify', t.result + 2.1, 1, -0.4);
// ── 5. AI
fly(OUT - 0.6, OUT + 0.4, 0.5, 0.6, 'in');                          // 手機離場
fly(OUT - 0.3, A, 1.0);                                       // 大幅飛向 AI 核心
c('core', A - 0.9, 1);
c('ring', A - 0.7, 0.8);
[0, 1, 2, 3, 4, 5, 6].forEach((i) => c('zip', A - 0.5 + i * 0.08, 0.3, Math.sin(i * 0.9) * 0.7, { dur: 1.1 }));
fly(A + 2.5, A + 3.6, 0.6);
[0, 1, 2, 3, 4, 5, 6].forEach((i) => c('node', A + 2.7 + i * 0.1, 0.7, Math.sin((-90 - 360 / 7 + (360 / 7) * i) * Math.PI / 180 + Math.PI / 2) * 0.8, { i }));

const keys = ['assist', 'review', 'enrich', 'rec', 'advisor', 'support', 'dispute'];
keys.forEach((k) => {
  const w = W[k];
  fly(w.travel, w.arrive, 0.85);
  c('check', w.t1 + 0.35, 0.35);
});
// 上架輔助
{ const [t0, t1] = [W.assist.t0, W.assist.t1];
  fly(t0 + 0.05, t0 + 1.1, 0.6, 0.6, 'emph'); c('glint', t0 + 0.7, 0.4, 0.6);
  c('shutter', t0 + 0.4, 1, -0.1);
  const s = t0 + 1.2; c('scan', s, 0.6, -0.1, { dur: 0.9 }); c('scan', s + 0.95, 0.6, -0.1, { dur: 0.9 });
  [0.9, 1.5, 2.1, 2.7].forEach((d) => c('tick', t0 + d, 0.6, 0.6));
  c('box', s + 1.0, 0.7, 0.1); c('line', s + 1.1, 0.35, 0.2, { dur: 0.3 }); c('pop', s + 1.3, 0.7, 0.3);
  c('box', s + 1.6, 0.7, 0.1); c('line', s + 1.7, 0.35, 0.2, { dur: 0.3 }); c('pop', s + 1.9, 0.7, 0.3);
  c('success', s + 2.2, 0.8, -0.1); c('coin_s', s + 2.5, 0.7, -0.1);
  c('sheet', t0 + 3.4, 0.6, 0.6);
  for (let n = 0; n < 9; n++) c('tick', t0 + 3.4 + 0.2 + n * 0.045, 0.25, 0.6);
  c('tap', t1 - 0.9, 0.9, 0.6);
  fly(W.review.t0 - 0.2, W.review.t0 + 0.5, 0.45, 0.7, 'in'); }
// 上架審核
{ const [t0] = [W.review.t0];
  c('pop', t0 + 0.4, 0.7, -0.2); c('pop', t0 + 0.6, 0.7, 0.4);
  c('line', t0 + 0.5, 0.35, 0, { dur: 1.0 });
  fly(t0 + 0.6, t0 + 1.5, 0.4, -0.2);
  [0, 1, 2].forEach((i) => c('check', t0 + 1.6 + i * 0.25, 0.8, -0.3));
  const scanT = t0 + 2.4; fly(scanT - 0.5, scanT, 0.4, 0.2);
  c('scan', scanT, 0.5, 0.4, { dur: 0.8 }); c('scan', scanT + 0.85, 0.5, 0.4, { dur: 0.75 });
  const vt = scanT + 1.5; c('select', vt, 0.8, 0.5); c('pop', vt + 0.3, 0.5, -0.2); c('sweep', vt + 0.2, 0.4, 0.5, { dur: 0.7 });
  fly(vt + 0.9, vt + 1.5, 0.4, 0.4); c('success', vt + 1.35, 0.8, 0.4); }
// 資料補齊
{ const t0 = W.enrich.t0;
  fly(t0 + 0.5, t0 + 1.3, 0.35);
  [0, 1, 2, 3].forEach((i) => { c(i === 3 ? 'sparkle' : 'check', t0 + 0.8 + i * 0.4, 0.7, -0.3 + i * 0.25); if (i < 3) c('line', t0 + 0.9 + i * 0.4, 0.25, 0, { dur: 0.35 }); });
  [0, 1, 2, 3].forEach((i) => c('fill', t0 + 2.1 + i * 0.28, 0.6, 0.2));
  [0, 1, 2].forEach((i) => c('tick', t0 + 3.4 + i * 0.2, 0.3, 0.2));
  c('sparkle', t0 + 3.4 + 0.8, 0.5, 0.2); }
// 個人化推薦
{ const t0 = W.rec.t0; const rowsAt = t0 + 4.2;
  fly(t0 - 0.4, t0 + 0.5, 0.6, 0.6, 'emph');
  c('sprinkle', t0 + 0.6, 0.5, -0.2, { dur: 0.6 });
  c('pop', t0 + 1.3, 0.9, -0.2);                             // 愛心
  c('sonar', t0 + 1.7, 0.6, -0.2); c('sonar', t0 + 2.1, 0.45, -0.2);
  [0, 1, 2].forEach((i) => { c('pop', t0 + 2.2 + i * 0.15, 0.65, -0.4 + i * 0.3); c('line', t0 + 2.2 + i * 0.15, 0.2, 0, { dur: 0.35 }); });
  [0, 1, 2].forEach((i) => { c('zip', rowsAt - 0.5 + i * 0.08, 0.5, 0.2, { dur: 0.8 }); c('tick', rowsAt + 0.3 + i * 0.08, 0.5, 0.6); });
  [0, 1, 2].forEach((r) => c('pop', rowsAt + 0.35 + r * 0.35, 0.45, 0.6)); }
// AI 書籍顧問
{ const t0 = W.advisor.t0; const adv = { typeAt: t0 + 0.6, send: t0 + 1.7, reply: t0 + 2.9, thumb: W.advisor.t1 - 1.2 };
  c('pop', t0 + 0.4, 0.5, -0.2);
  c('typing', adv.typeAt, 0.5, 0.6, { dur: adv.send - 0.2 - adv.typeAt, n: 23 });
  c('send', adv.send, 1, 0.6);
  [0.3, 0.45, 0.6].forEach((d) => c('swipe', adv.send + d, 0.45, -0.2));
  [0, 1, 2].forEach((i) => c('pop', adv.send + 0.8 + i * 0.15, 0.6, -0.3));
  c('pop', adv.send + 1.35, 0.4, -0.3);
  c('bubble', adv.reply, 0.9, 0.6);
  [0, 1, 2].forEach((i) => c('tick', adv.reply + 0.2 + i * 0.07, 0.4, 0.6));
  c('success', adv.reply + 0.2, 0.7, -0.3);
  c('tap', adv.thumb, 0.8, 0.6); c('pop', adv.thumb + 0.02, 0.4, 0.6); }
// AI 客服
{ const t0 = W.support.t0; const sup = { send: t0 + 0.9, reply: t0 + 2.0 };
  [0, 1, 2, 3, 4].forEach((i) => c('card', t0 + 0.4 + i * 0.08, 0.4, -0.3));
  c('send', sup.send, 1, 0.6);
  c('pop', sup.send + 0.15, 0.55, -0.4); c('pop', sup.send + 0.3, 0.55, -0.1);
  c('select', sup.send + 0.55, 0.7, -0.3);
  c('bubble', sup.reply, 0.9, 0.6);
  c('pop', sup.send + 0.55 + 0.4, 0.4, -0.2); }
// 爭議分析
{ const t0 = W.dispute.t0; const tF = [t0 + 3.3, t0 + 3.7, t0 + 4.1];
  fly(t0 - 0.2, t0 + 0.5, 0.45, 0.7, 'in');                   // 手機離場
  fly(t0 + 0.3, t0 + 1.1, 0.4, -0.5);
  c('line', t0 + 0.9, 0.3, -0.1, { dur: 0.5 });
  [0, 1, 2].forEach((k) => c('zip', t0 + 1.0 + k * 0.45, 0.25, 0, { dur: 0.7 }));
  c('sparkle', t0 + 1.1, 0.8, 0);
  fly(t0 + 1.3, t0 + 2.1, 0.35, 0.5);
  c('process', t0 + 1.6, 0.4, 0.4, { dur: 1.0 });
  c('warn_pop', t0 + 2.6, 0.8, 0.4);
  tF.forEach((tt, i) => c('check', tt, 0.6, 0.4));
  c('pop', tF[0] + 0.1, 0.5, -0.3); c('pop', tF[0] + 0.18, 0.5, -0.2); c('pop', tF[2] + 0.1, 0.5, -0.3);
  c('line', tF[1] + 0.1, 0.3, -0.3, { dur: 0.4 });
  [0, 1, 2, 3].forEach((i) => c('tick', t0 + 5.1 + i * 0.08, 0.4, 0.5)); }
// AI 治理
{ const w = W.gov;
  fly(w.travel, w.arrive, 0.85);
  c('ring', w.arrive - 0.3, 0.8); c('core', w.arrive - 0.4, 0.5);
  c('pop', w.t0 + 0.5, 0.8, 0.3); c('line', w.t0 + 0.6, 0.3, 0.3, { dur: 0.4 });
  c('select', w.t0 + 1.3, 0.8, 0.3);
  [0, 1, 2].forEach((k) => c('zip', w.t0 + 1.0 + k * 1.2, 0.25, 0.3, { dur: 0.8 }));
  [0, 1, 2, 3].forEach((i) => c('pop', w.t0 + 1.6 + i * 0.12, 0.6, i % 2 ? 0.5 : 0.1)); }
// ── 6. 交易安全
const stations = ['escrow', 'pay', 'chat', 'arch', 'nums', 'fee'];
stations.forEach((k) => fly(W[k].travel, W[k].arrive, 0.9));
{ const t0 = W.escrow.t0; const pay = t0 + 1.3, release = t0 + 4.9;
  [0, 1, 2].forEach((i) => c('pop', t0 + 0.3 + i * 0.15, 0.8, -0.5 + i * 0.5));
  c('line', t0 + 0.7, 0.3, -0.25, { dur: 0.4 }); c('line', t0 + 0.8, 0.3, 0.25, { dur: 0.4 });
  c('coin_up', pay - 0.3, 0.6, -0.5);
  c('coin_fly', pay, 0.7, -0.25, { dur: 0.8 }); c('coin_land', pay + 0.8, 0.9, 0);
  c('lock', pay + 0.8, 0.5, 0);
  [pay + 0.2, pay + 1.0, pay + 1.8, pay + 2.8, release + 0.4].forEach((tt, i) => c('dot', tt, 0.6, -0.5 + i * 0.25));
  c('coin_fly', release, 0.7, 0.25, { dur: 0.8 }); c('cash', release + 0.8, 1, 0.5); }
{ const pw = W.pay; const tm = { checkout: pw.t0 + 1.0, sheet: pw.t0 + 1.35, pin: [0, 1, 2, 3, 4, 5].map((i) => pw.t0 + 2.1 + i * 0.26), done: pw.t0 + 4.05, success: pw.t0 + 4.3 };
  fly(pw.t0 - 0.2, pw.t0 + 0.8, 0.6, 0.6, 'emph'); c('glint', pw.t0 + 0.6, 0.4, 0.6);
  [0, 1, 2].forEach((i) => c('pop', pw.t0 + 0.4 + i * 0.15, 0.6, -0.4));
  c('tap', tm.checkout, 0.8, 0.6); c('sheet', tm.sheet, 0.6, 0.6); c('select', tm.sheet + 0.2, 0.5, -0.4);
  tm.pin.forEach((p, i) => c('pin', p, 0.9, 0.6, { i }));
  c('process', tm.done - 0.3, 0.3, 0.6, { dur: 0.3 });
  c('success', tm.success, 1, 0.5); c('pop', tm.success + 0.3, 0.6, -0.4); }
{ const cw = W.chat; const tm = { m1: cw.t0 + 0.6, m2: cw.t0 + 1.3, m3: cw.t0 + 2.2, note: cw.t0 + 2.75, banner: cw.t0 + 3.6 };
  c('pop', cw.t0 + 0.4, 0.5, -0.4);
  c('bubble', tm.m1, 0.8, 0.5); c('send', tm.m2, 0.8, 0.7); c('bubble', tm.m3, 0.8, 0.5);
  c('scan', tm.m3 + 0.05, 0.5, -0.4, { dur: 0.6 });
  [0, 1, 2].forEach((i) => c('flag', tm.m3 + 0.35 + i * 0.12, 0.8, -0.5 + i * 0.25));
  c('alert', tm.note, 0.8, 0.4); c('pop', tm.note, 0.4, -0.4);
  c('banner', tm.banner, 0.9, 0.6); c('pop', tm.banner, 0.4, -0.4); c('pop', tm.banner + 0.6, 0.4, -0.4);
  fly(cw.t1 - 0.2, cw.t1 + 0.5, 0.45, 0.7, 'in'); }
// ── 7. 架構
{ const t0 = W.arch.t0;
  const boxes = [[t0 + 0.4, 0], [t0 + 0.9, -0.3], [t0 + 1.0, 0.1], [t0 + 1.4, -0.1], [t0 + 1.9, -0.3], [t0 + 2.0, 0.1], [t0 + 2.6, 0.5], [t0 + 2.72, 0.5], [t0 + 2.84, 0.5]];
  boxes.forEach(([tt, pan], i) => c('block', tt, 0.8, pan, { i }));
  [2.2, 2.25, 2.3, 2.35, 2.4, 2.45].forEach((d, i) => c('tick', t0 + d, 0.35, i % 2 ? 0.1 : -0.3));
  c('line', t0 + 2.9, 0.4, 0.4, { dur: 0.6 }); }
// ── 開發成果
{ const t0 = W.nums.t0; const digits = [3, 4, 4, 1];
  digits.forEach((dg, i) => odo(t0 + 0.5 + i * 0.18, 1.4, dg, 0.8, -0.6 + i * 0.4)); }
// ── 抽成
{ const t0 = W.fee.t0;
  [0, 1].forEach((i) => { const tIn = t0 + 0.5 + i * 0.25; c('pop', tIn, 0.5, -0.4); c('grow', tIn + 0.2, 0.7, -0.3, { dur: 0.9, up: i === 0 ? 1 : 1.5 }); c('tick', tIn + 0.95, 0.6, 0); c(i === 0 ? 'cash' : 'pop', tIn + 1.4, i === 0 ? 0.7 : 0.5, 0.5); });
  c('pop', t0 + 1.6, 0.35, 0.5); }
// ── 8. 片尾
c('swell', CLOSE, 0.7, 0, { dur: 0.8 });
title(CLOSE + 0.5, 1);
c('final', CARD + 0.1, 1);
[...'救「舊」我的書'].forEach((ch, i) => c('type', CARD + 0.35 + i * 0.05, 0.5, -0.3 + i * 0.1));
c('shimmer', CARD + 0.6, 0.6);

cues.sort((a, b) => a.t - b.t);
const marks = { R0, SWAP, FULL_AT, XR, F, OUT, A, CLOSE, CARD, WIN: W, flow: t };
fs.writeFileSync(__dirname + '/cues.json', JSON.stringify({ cues, marks }, null, 1));
console.log(cues.length, 'cues');
