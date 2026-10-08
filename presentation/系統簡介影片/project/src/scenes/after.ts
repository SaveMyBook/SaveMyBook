import { span, lerp, clamp, easeOut, easeInOut, type Pose } from '../lib/kf';
import { el, css, place } from '../lib/ui';
import { AI_FEATURES } from '../lib/content';
import { cue, fly } from '../lib/cues';
import { BUYER, ADMIN, type World } from '../world';
import { Headline, Caption, Chips, Mark, Tag, Tap, at, frame, frameSteps, seq, track, mix, easeIn, type Step } from './kit';
import { AFTER } from './story';
import { Compare, Retrieval } from './detail';
import SEQ from '../lib/sequences.json';

/**
 * 售後：AI 客服（買家）→ 爭議分析（管理員）→ 回顧一路出現的七項 AI → 用量與隱私（使用前同意）。
 * 旁白（段落內秒數）：ai6 0.8、ai7 7.4、ai0 14.4、ai8 18.8。
 */
export function after(world: World, ui: HTMLElement) {
  const t6 = at('ai6'), t7 = at('ai7'), t0 = at('ai0'), t8 = at('ai8');
  const head6 = new Headline(ui, 'AI 客服，立即回覆', '以關鍵字與語意混合檢索作答，複雜問題一鍵轉接客服人員');
  const head7 = new Headline(ui, '爭議分析，協助裁決', '比對上架照片、說明與雙方佐證，整理成摘要');
  const head0 = new Headline(ui, '從上架到售後，七項 AI', '每一項都在交易中實際出現');
  const head8 = new Headline(ui, '用量與隱私，全程把關', '使用前說明資料用途並取得同意');
  // AI 客服：標題後拉近輸入列逐字輸入第 1 題 → 輸入中 → 回覆（左側同步顯示檢索）→ 輸入第 2 題 → 回覆並出現轉接客服
  const Q1 = [2.15, 2.75], SEND1 = 2.82, A1 = 3.3, Q2 = [4.75, 5.2], SEND2 = 5.27, A2 = 5.75;
  const supSteps: Step[] = [
    [-1, 'b_support_empty'],
    ...frameSteps(SEQ.support_q1, Q1[0], Q1[1]),
    [SEND1 + 0.04, 'b_support_wait1', 0, 0.12],
    [A1, 'b_support_a1', 0, 0.3],
    ...frameSteps(SEQ.support_q2, Q2[0], Q2[1]),
    [SEND2 + 0.04, 'b_support_wait2', 0, 0.12],
    [A2, 'b_support', 0, 0.3],
  ];
  [...frameSteps(SEQ.support_q1, Q1[0], Q1[1]), ...frameSteps(SEQ.support_q2, Q2[0], Q2[1])].forEach(([t0]) => cue('key', t0, { gain: 0.3 }));
  cue('bubble', SEND1 + 0.05, { gain: 0.7 }); cue('pop', A1 + 0.02, { gain: 0.7 });
  cue('bubble', SEND2 + 0.05, { gain: 0.7 }); cue('pop', A2 + 0.02, { gain: 0.7 });
  const taps = [new Tap(ui, BUYER, 360, 765, SEND1), new Tap(ui, BUYER, 360, 765, SEND2)];
  const retrieval = new Retrieval(ui);
  const markAns = new Mark(ui, BUYER, AFTER.supAns).register(3.6);
  const markHuman = new Mark(ui, BUYER, AFTER.supHuman).register(5.95);
  const markDis = new Mark(ui, ADMIN, AFTER.dispute).register(9.85);
  const markObs = new Mark(ui, ADMIN, AFTER.disputeObs).register(11.25);
  const markTo = new Mark(ui, BUYER, AFTER.consentTo).register(t8 + 2.8);
  const capHuman = new Caption(ui, '轉接真人', '複雜問題交給客服', '需要人工時，顯示轉接按鈕', 120);
  const capDis = new Caption(ui, '爭議分析', '整理證據與建議', '標註有利買賣雙方的觀察，結果僅供管理員參考', 120);
  const govern = new Chips(ui, ['每月預算上限', '每日次數上限', '使用前須同意', '對話紀錄 90 天後自動刪除']);
  const adminTag = new Tag(ui, ADMIN, '管理員', '');

  // 七項 AI 回顧：依出現順序排成一列
  const tiles = AI_FEATURES.map((f) => {
    const li = el('div', 'tile tile--sm', ui);
    el('span', 'tile__ico', li, f.icon);
    el('b', '', li, f.name);
    return li;
  });
  tiles.forEach((_, i) => cue('pop', t0 - 0.2 + i * 0.16, { pan: -0.6 + i * 0.2, gain: 0.6 }));
  fly(-0.6, 0.6, 0.5); fly(6.8, 7.8, 0.6); fly(13.4, 14.2, 0.5); fly(t8 - 0.2, t8 + 0.8, 0.6, 0.3); fly(25.0, 26.0, 0.5);

  const CENTER: Pose = { x: 0, y: -0.12, z: 0, rx: 0.03, ry: 0, rz: 0, s: 1.15 };
  // 客服整段對話一起看、爭議整個 AI 面板一起看，標示框依序換
  const supF = frame({ x: 52, y: 130, w: 327, h: 560 }, 1150, 565, 540);
  // 輸入時拉近輸入列（比照 AI 書籍顧問）；第 2 題連同下方回覆與轉接卡一起看
  const typeS = frame({ x: 0, y: 520, w: 393, h: 332 }, 1150, 600, 600);
  const q2F = frame({ x: 0, y: 420, w: 393, h: 432 }, 1150, 580, 560);
  const disF = frame({ x: 20, y: 102, w: 353, h: 442 }, 1150, 560, 540);
  const toF = frame({ x: 16, y: 540, w: 361, h: 250 }, 1150, 560, 600);
  const compare = new Compare(ui);
  const BACK: Pose = { x: -1.45, y: -0.05, z: -14, rx: 0.03, ry: 0.7, rz: 0, s: 1.0 };

  return (t: number) => {
    const f = world.frame;
    // 標題在推近輸入列之前收起，避免手機放大時壓到副標
    head6.at(t, t6 - 0.4, 1.5);
    head7.at(t, t7 - 0.2, 8.8);
    head0.at(t, t0 - 0.3, t8 - 0.6);
    head8.at(t, t8 - 0.1, t8 + 1.75);

    // 客服（買家）：前景 → 7 秒時退到左後方，管理員手機從右後方換到前景
    if (t > -0.3 && t < 7.85) {
      let pose = track(t, [[-0.3, { ...CENTER, y: 0.05, z: -46, rx: 0.25, ry: 0.9, rz: 0.35 }], [0.75, CENTER], [1.8, CENTER], [2.12, typeS], [2.85, typeS], [3.2, supF], [4.35, supF], [4.7, q2F], [6.5, q2F], [6.9, CENTER]]);
      pose = mix(pose, BACK, easeInOut(span(t, 6.9, 7.8)));
      css(ui, '--x', '0');
      f.phones[BUYER] = { pose, scr: seq(t, supSteps), glow: 1 - 0.25 * span(t, 7.0, 7.8) };
    }
    if (t > 6.8 && t < 14.4) {
      let pose = track(t, [[6.9, { ...CENTER, x: 0.45, z: -14, ry: -0.35, s: 1.0 }], [7.8, CENTER], [9.25, CENTER], [9.85, disF], [13.0, disF], [13.5, CENTER]]);
      pose = mix(pose, { ...CENTER, y: -2.2, rx: 0.4 }, easeIn(span(t, 13.5, 14.3)));
      // 先顯示 AI 分析中，與左側比對結果同時完成
      f.phones[ADMIN] = { pose, scr: seq(t, [[0, 'a_dispute_loading'], [8.98, 'a_dispute_ai', 0, 0.15]]) };
    }
    adminTag.at(world, t, 7.8, 8.4);
    taps.forEach((tp) => tp.at(world, t));
    markAns.at(world, t, 3.65, 4.35);
    markHuman.at(world, t, 6.0, 6.5);
    retrieval.at(t, 2.15, 4.35, 3.1, 120, 560);
    markDis.at(world, t, 9.9, 11.1);
    markObs.at(world, t, 11.3, 13.0);
    capHuman.at(t, 6.0, 6.55, 560);
    capDis.at(t, 9.9, 13.0, 520);

    // 七項 AI：自畫面兩側依序飛進，排成一列；用量段縮到左側
    // 七項依序由下方升到自己的位置（不互相交錯），用量段開始前收起
    tiles.forEach((li, i) => {
      const a = t0 - 0.4 + i * 0.16;
      const k = easeOut(span(t, a, a + 0.7));
      const out = easeInOut(span(t, t8 - 0.6 + i * 0.04, t8 - 0.1 + i * 0.04));
      const x = 960 + (i - 3) * 240;
      const y = 600 + (1 - k) * 90 - out * 40 + Math.sin(t * 0.8 + i) * 4;
      place(li, x, y);
      const vis = k * (1 - out);
      css(li, 'opacity', clamp(vis * 1.3).toFixed(3));
      css(li, 'visibility', vis > 0.001 ? 'visible' : 'hidden');
    });

    // 用量與隱私：使用前的資料處理說明
    if (t > t8 - 0.3 && t < 26.2) {
      let pose = track(t, [[t8 - 0.2, { ...CENTER, x: 1.25, y: -0.3, z: -16, rx: 0.1, ry: -1.6, rz: -0.25 }], [t8 + 0.5, { ...CENTER, x: 0.42, z: 2, ry: -0.3, rz: -0.03 }], [t8 + 0.95, { ...CENTER, x: 0.3 }], [t8 + 2.2, { ...CENTER, x: 0.3 }], [t8 + 2.75, toF], [24.6, toF], [25.2, { ...CENTER, x: 0.3 }]]);
      pose = mix(pose, { ...pose, s: 0.4, x: -0.69, y: 0.2 }, easeInOut(span(t, 25.2, 26.1)));
      f.phones[BUYER] = { pose, scr: { a: 'b_ai_consent' }, glow: 1 };
    }
    // 管理員手機正對鏡頭時，左側先比對上架資料與爭議說明，推近 AI 面板前收起
    compare.at(t, 7.85, 9.65, 120, 540);
    markTo.at(world, t, t8 + 2.85, 24.6);
    govern.at(t, t8 + 2.85, 24.8, 120, 380);
  };
}
