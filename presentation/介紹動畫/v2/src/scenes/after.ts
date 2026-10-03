import { span, lerp, clamp, easeOut, easeInOut, type Pose } from '../lib/kf';
import { el, css, place } from '../lib/ui';
import { AI_FEATURES } from '../lib/content';
import { cue, fly } from '../lib/cues';
import { BUYER, ADMIN, type World } from '../world';
import { Headline, Caption, Chips, Mark, Tag, at, frame, track, mix, easeIn } from './kit';
import { AFTER } from './story';

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
  const markAns = new Mark(ui, BUYER, AFTER.supAns).register(2.95);
  const markHuman = new Mark(ui, BUYER, AFTER.supHuman).register(4.45);
  const markDis = new Mark(ui, ADMIN, AFTER.dispute).register(9.85);
  const markObs = new Mark(ui, ADMIN, AFTER.disputeObs).register(11.25);
  const markTo = new Mark(ui, BUYER, AFTER.consentTo).register(t8 + 2.8);
  const capAns = new Caption(ui, 'AI 客服', '依規則與訂單回覆', '例：訂單 ODNMX0225 的取書期限', 120);
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
  const disF = frame({ x: 20, y: 102, w: 353, h: 442 }, 1150, 560, 540);
  const toF = frame({ x: 16, y: 540, w: 361, h: 250 }, 1150, 560, 600);
  const BACK: Pose = { x: -0.45, y: -0.05, z: -14, rx: 0.03, ry: 0.35, rz: 0, s: 1.0 };

  return (t: number) => {
    const f = world.frame;
    head6.at(t, t6 - 0.2, 1.9);
    head7.at(t, t7 - 0.2, 8.8);
    head0.at(t, t0 - 0.3, t8 - 0.6);
    head8.at(t, t8 - 0.1, t8 + 1.75);

    // 客服（買家）：前景 → 7 秒時退到左後方，管理員手機從右後方換到前景
    if (t > -0.7 && t < 8.4) {
      let pose = track(t, [[-0.6, { ...CENTER, y: -2.2, rx: 0.45 }], [0.6, CENTER], [2.35, CENTER], [2.95, supF], [6.3, supF], [6.9, CENTER]]);
      pose = mix(pose, BACK, easeInOut(span(t, 6.9, 7.8)));
      css(ui, '--x', '0');
      f.phones[BUYER] = { pose, scr: { a: 'b_support' }, glow: 1 - 0.25 * span(t, 7.0, 7.8) };
    }
    if (t > 6.8 && t < 14.4) {
      let pose = track(t, [[6.9, { ...CENTER, x: 0.45, z: -14, ry: -0.35, s: 1.0 }], [7.8, CENTER], [9.25, CENTER], [9.85, disF], [13.0, disF], [13.5, CENTER]]);
      pose = mix(pose, { ...CENTER, y: -2.2, rx: 0.4 }, easeIn(span(t, 13.5, 14.3)));
      f.phones[ADMIN] = { pose, scr: { a: 'a_dispute_ai' } };
    }
    adminTag.at(world, t, 7.8, 8.4);
    markAns.at(world, t, 3.0, 4.15);
    markHuman.at(world, t, 4.5, 6.3);
    markDis.at(world, t, 9.9, 11.1);
    markObs.at(world, t, 11.3, 13.0);
    capAns.at(t, 3.0, 4.1, 480);
    capHuman.at(t, 4.55, 6.3, 560);
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
      let pose = track(t, [[t8 - 0.2, { ...CENTER, x: 0.3, y: -2.2, rx: 0.45 }], [t8 + 0.8, { ...CENTER, x: 0.3 }], [t8 + 2.2, { ...CENTER, x: 0.3 }], [t8 + 2.75, toF], [24.6, toF], [25.2, { ...CENTER, x: 0.3 }]]);
      pose = mix(pose, { ...pose, s: 0.4, x: -0.69, y: 0.2 }, easeInOut(span(t, 25.2, 26.1)));
      f.phones[BUYER] = { pose, scr: { a: 'b_ai_consent' }, glow: 1 };
    }
    markTo.at(world, t, t8 + 2.85, 24.6);
    govern.at(t, t8 + 2.85, 24.8, 120, 380);
  };
}
