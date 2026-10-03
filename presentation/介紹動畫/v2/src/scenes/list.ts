import { span, lerp, easeOut, easeInOut, type Pose } from '../lib/kf';
import { el, css, place } from '../lib/ui';
import { cue, fly } from '../lib/cues';
import { SELLER, BUYER, type World } from '../world';
import { DUO } from './intro';
import { Headline, Caption, Chips, Mark, Tap, at, frame, seq, stepCues, track, mix, easeIn, type Step } from './kit';
import { R, CARD_X, CARD_Y, cardHtml } from './story';

/**
 * 上架（賣家侖娥），照 App 的兩個步驟：
 * 1. 書籍資料：輸入 ISBN → AI 帶入 → 書目與簡介（預設只勾空白欄位）→ 套用。
 * 2. 詳細資料與照片：AI 帶入 → 書況與建議售價 $220 → 套用 → 侖娥定價 $222 → 確認上架。
 * 送出後書卡依序通過規則檢查與 AI 影像審核。
 * 旁白（段落內秒數）：ai1 1.0、ai3 6.4、ai2 13.0。
 */
export function list(world: World, ui: HTMLElement) {
  const t2 = at('ai2');
  const head1 = new Headline(ui, '輸入 ISBN，自動補齊書目', '依 ISBN 查詢書目，由 AI 整理成繁體中文簡介');
  const head3 = new Headline(ui, '拍張照片，AI 判斷書況與售價', '附上判斷依據、建議售價區間與資料來源');
  const head2 = new Headline(ui, '規則＋AI，雙層把關', '規則即時攔截異常，AI 再判讀照片，有疑慮才交由管理員複核');

  const steps: Step[] = [
    [0, 's_sell_isbn'],
    [2.0, 's_sell_fill', 3, 0.5],
    [6.15, 's_sell_info', 0, 0.35],
    [6.9, 's_sell_photos', 1, 0.45],
    [8.4, 's_sell_ai_sheet_220', 3, 0.5],
    [11.55, 's_sell_ready', 0, 0.35],
  ];
  stepCues(steps);
  const mid = (r: { x: number; y: number; w: number; h: number }): [number, number] => [r.x + r.w / 2, r.y + r.h / 2];
  const taps = [
    new Tap(ui, SELLER, ...mid(R.isbnAi), 1.4),
    new Tap(ui, SELLER, ...mid(R.fillApply), 5.75),
    new Tap(ui, SELLER, ...mid(R.photosAi), 7.8),
    new Tap(ui, SELLER, ...mid(R.sellApply), 11.15),
    new Tap(ui, SELLER, ...mid(R.readySubmit), 12.55),
  ];
  const markFields = new Mark(ui, SELLER, R.fillFields).register(3.3);
  const markIntro = new Mark(ui, SELLER, R.fillIntro).register(4.4);
  const markCond = new Mark(ui, SELLER, R.sellCondition).register(9.1);
  const markPrice = new Mark(ui, SELLER, R.sellPrice).register(10.15);
  const markReady = new Mark(ui, SELLER, R.readyPrice).register(11.85);
  const capFields = new Caption(ui, '書目查詢', '依 ISBN 帶出書目', '書名、作者、出版社與出版日期', 120);
  const sources = new Chips(ui, ['Google Books', 'Open Library']);
  const capIntro = new Caption(ui, '簡介', 'AI 整理成繁體中文', '預設只勾選空白欄位，已填寫的內容由賣家決定是否取代', 120);
  const capCond = new Caption(ui, '書況', '依照片判斷書況', '並逐項列出判斷依據', 120);
  const capPrice = new Caption(ui, '建議售價', '附上區間與理由', '依定價與書況計算，並列出資料來源', 120);
  const capReady = new Caption(ui, '定價', '售價由賣家決定', 'AI 建議 $220，侖娥定為 $222', 120);

  // 雙層審核：書卡自手機送出，依序通過兩道檢查
  const card = el('div', 'lcard', ui, cardHtml('審核中'));
  const cardState = card.querySelector<HTMLElement>('.lcard__state')!;
  const gates = [
    { title: '規則檢查', items: ['售價未明顯高於行情', '未含站外聯絡資訊', '非館藏或非正規來源'] },
    { title: 'AI 影像審核', items: ['照片與書名、描述相符', '未發現盜版或違禁內容'] },
  ].map((g) => {
    const box = el('div', 'gate', ui, `<p class="gate__title">${g.title}</p>`);
    const rows = g.items.map((it) => el('p', 'gate__row', box, `<i></i>${it}`));
    return { box, rows };
  });
  const GX = [760, 1180];
  gates.forEach((g, gi) => g.rows.forEach((_, ri) => cue('check', t2 + 1.2 + gi * 1.6 + ri * 0.3, { pan: gi ? 0.3 : -0.1, gain: 0.7 })));
  cue('success', t2 + 4.4, { pan: 0.5 });

  // 取景：書目整張單一起看（標示框依序換），書況與售價兩張卡一起看，最後看賣家填的售價
  const CENTER: Pose = { x: 0, y: -0.12, z: 0, rx: 0.03, ry: 0, rz: 0, s: 1.15 };
  const fillF = frame({ x: 16, y: 188, w: 361, h: 493 }, 1150, 560, 470);
  const sheetF = frame({ x: 16, y: 360, w: 361, h: 265 }, 1150, 560, 600);
  const readyF = frame({ x: 16, y: 416, w: 361, h: 157 }, 1150, 540, 600);
  const LEFT: Pose = { x: -0.55, y: -0.12, z: 0, rx: 0.03, ry: 0.2, rz: 0, s: 0.95 };
  fly(0, 1.2, 0.5, -0.2);
  fly(13.0, 13.8, 0.5, -0.5);

  return (t: number) => {
    const f = world.frame;
    head1.at(t, 0.8, 2.3);
    head3.at(t, 6.3, 8.1);
    head2.at(t, t2 - 0.2, 18.1);

    if (t > -0.6 && t < 19.2) {
      let pose = track(t, [
        [0, DUO.seller], [1.2, CENTER], [2.75, CENTER], [3.3, fillF], [5.6, fillF], [6.2, CENTER],
        [8.55, CENTER], [9.1, sheetF], [11.25, sheetF], [11.75, readyF], [12.3, readyF], [12.8, CENTER], [13.6, LEFT],
      ]);
      pose = mix(pose, { ...LEFT, x: -1.5, ry: 0.6 }, easeIn(span(t, 17.6, 18.8)));
      f.phones[SELLER] = { pose, scr: seq(t, steps) };
    }
    // 買家手機在開場右側，往右後方退場
    if (t > -0.6 && t < 1.4) {
      const k = easeIn(span(t, 0, 1.2));
      f.phones[BUYER] = { pose: mix(DUO.buyer, { ...DUO.buyer, x: 1.5, z: -10, ry: -0.8 }, k), scr: { a: 'b_home' } };
    }
    taps.forEach((tp) => tp.at(world, t));
    markFields.at(world, t, 3.35, 4.3);
    markIntro.at(world, t, 4.45, 5.55);
    markCond.at(world, t, 9.15, 10.05);
    markPrice.at(world, t, 10.2, 11.2);
    markReady.at(world, t, 11.9, 12.35);
    // 說明文字依序出現：前一則淡出（0.4 秒）後才出現下一則，避免重疊
    capFields.at(t, 3.35, 4.1, 470);
    sources.at(t, 3.5, 4.1, 120, 610);
    capIntro.at(t, 4.5, 5.55, 500);
    capCond.at(t, 9.15, 9.85, 500);
    capPrice.at(t, 10.25, 11.15, 500);
    capReady.at(t, 11.9, 12.5, 500);

    // 書卡：自手機送出 → 通過兩道檢查 → 標示上架成功 → 停在右側，下一段由買家手機接手（find.ts 的書卡從同一位置出發）
    const out = easeOut(span(t, t2 + 0.1, t2 + 0.8));
    const x = lerp(330, 560, out) + (t > t2 + 0.8 ? lerp(0, CARD_X - 560, easeInOut(span(t, t2 + 0.9, t2 + 4.2))) : 0);
    const vis = t > t2 && t < 19.0;
    css(card, 'visibility', vis ? 'visible' : 'hidden');
    if (vis) {
      place(card, x, CARD_Y, ` scale(${lerp(0.6, 1, out).toFixed(3)})`);
      css(card, 'opacity', out.toFixed(3));
      const ok = t > t2 + 4.4;
      if (cardState.textContent !== (ok ? '已上架' : '審核中')) cardState.textContent = ok ? '已上架' : '審核中';
      card.classList.toggle('is-ok', ok);
    }
    gates.forEach((g, gi) => {
      const k = easeOut(span(t, t2 + 0.4 + gi * 0.25, t2 + 1.0 + gi * 0.25)) * (1 - easeInOut(span(t, t2 + 4.8, t2 + 5.3)));
      css(g.box, 'opacity', k.toFixed(3));
      css(g.box, 'visibility', k > 0.001 ? 'visible' : 'hidden');
      place(g.box, GX[gi], 420 + (1 - k) * 24);
      g.rows.forEach((r, ri) => r.classList.toggle('is-ok', t > t2 + 1.2 + gi * 1.6 + ri * 0.3));
      g.box.classList.toggle('is-pass', t > t2 + 1.2 + gi * 1.6 + g.rows.length * 0.3);
    });
  };
}
