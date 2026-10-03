import { span, lerp, easeInOut, type Pose } from '../lib/kf';
import { el, css, place } from '../lib/ui';
import { cue, fly } from '../lib/cues';
import { BUYER, type World } from '../world';
import { Headline, Caption, Mark, Tap, at, frame, seq, stepCues, track, type Step } from './kit';
import { R, CARD_X, CARD_Y, cardHtml } from './story';

/**
 * 找書（買家海嫄）：上架的書卡飛進首頁推薦列 → 推薦理由 → 聊天室列表的 AI 書籍顧問 → 說出需求 → 推薦站內在售的書 → 點選那本書。
 * App 的顧問入口在聊天室列表，首頁沒有。
 * 旁白（段落內秒數）：ai4 1.4、ai5 7.6。
 */
export function find(world: World, ui: HTMLElement) {
  const t4 = at('ai4'), t5 = at('ai5');
  const head4 = new Headline(ui, '每本推薦，都有理由', '依收藏、購物車與瀏覽紀錄，以語意向量找出相近的書');
  const head5 = new Headline(ui, '說出需求，AI 幫您挑書', '理解分類、預算與書況條件，只推薦站內可購買的書');
  const card = el('div', 'lcard is-ok', ui, cardHtml('已上架'));

  const steps: Step[] = [[0, 'b_home'], [6.85, 'b_chat_list', 1, 0.45], [7.85, 'b_advisor', 1, 0.45]];
  stepCues(steps);
  const mid = (r: { x: number; y: number; w: number; h: number }): [number, number] => [r.x + r.w / 2, r.y + r.h / 2];
  const taps = [
    new Tap(ui, BUYER, ...mid(R.homeChat), 6.3),
    new Tap(ui, BUYER, ...mid(R.listAdvisor), 7.3),
    new Tap(ui, BUYER, R.advisorPick.x + R.advisorPick.w / 2, R.advisorPick.y + R.advisorPick.h * 0.4, 12.45),
  ];
  const markRec = new Mark(ui, BUYER, R.homeRec).register(3.45);
  const markAsk = new Mark(ui, BUYER, R.advisorAsk).register(9.4);
  const markPick = new Mark(ui, BUYER, R.advisorBoth).register(10.6);
  const capRec = new Caption(ui, '個人化推薦', 'AI 排序並寫下理由', '例如「與已收藏的《觀念化學1》相關」，每本附一句推薦理由', 120);
  const capAsk = new Caption(ui, 'AI 書籍顧問', '把需求拆成條件', '分類、程度、預算與書況', 120);
  const capPick = new Caption(ui, '推薦結果', '只推薦可購買的書', '附上價格、書況與推薦理由', 120);
  cue('pop', 1.0, { pan: 0.2, gain: 0.7 });
  fly(-0.4, 1.0, 0.5, 0.2);

  const CENTER: Pose = { x: 0, y: -0.12, z: 0, rx: 0.03, ry: 0, rz: 0, s: 1.15 };
  // 推薦列連同群組標題一起看；顧問的需求、回覆與推薦卡一起看，標示框依序換
  const recF = frame({ x: 16, y: 300, w: 377, h: 330 }, 1150, 560, 620);
  const chatF = frame({ x: 52, y: 129, w: 327, h: 479 }, 1150, 565, 580);

  return (t: number) => {
    const f = world.frame;
    head4.at(t, t4 - 0.2, 2.4);
    head5.at(t, t5 - 0.2, 8.3);
    if (t > -0.5 && t < 13.6) {
      const pose = track(t, [
        [-0.4, { ...CENTER, y: -2.2, rx: 0.45 }], [0.9, CENTER], [2.85, CENTER], [3.45, recF], [5.7, recF], [6.2, CENTER],
        [8.75, CENTER], [9.35, chatF], [12.1, chatF], [12.8, CENTER],
      ]);
      f.phones[BUYER] = { pose, scr: seq(t, steps) };
    }
    taps.forEach((tp) => tp.at(world, t));
    markRec.at(world, t, 3.5, 5.6);
    markAsk.at(world, t, 9.45, 10.3);
    markPick.at(world, t, 10.65, 12.1);
    capRec.at(t, 3.5, 5.6, 520);
    capAsk.at(t, 9.45, 10.2, 470);
    capPick.at(t, 10.65, 12.1, 520);

    // 書卡：自上一段停留處飛進首頁的推薦卡位置後消失
    const k = easeInOut(span(t, 0, 1.0));
    const vis = t >= 0 && t < 1.05;
    css(card, 'visibility', vis ? 'visible' : 'hidden');
    if (vis) {
      world.frame.after.push(() => {
        const p = world.point(BUYER, R.homeRec.x + R.homeRec.w / 2, R.homeRec.y + R.homeRec.h * 0.3);
        const w = world.point(BUYER, R.homeRec.x + R.homeRec.w, R.homeRec.y).x - world.point(BUYER, R.homeRec.x, R.homeRec.y).x;
        place(card, lerp(CARD_X, p.x, k), lerp(CARD_Y, p.y, k) - Math.sin(Math.PI * k) * 80, ` scale(${lerp(1, Math.max(0.2, w / 380), k).toFixed(3)})`);
        css(card, 'opacity', (1 - span(t, 0.85, 1.05)).toFixed(3));
      });
    }
  };
}
