import { span, lerp, easeOut, easeInOut, type Pose } from '../lib/kf';
import { el, css, place } from '../lib/ui';
import { cue, fly } from '../lib/cues';
import { SELLER, BUYER, type World } from '../world';
import { DUO } from './intro';
import { Headline, Caption, Chips, Mark, Tap, at, frame, seq, stepCues, track, mix, easeIn, type Step } from './kit';
import { R, CARD_X, CARD_Y, cardHtml } from './story';
import { Pipeline, PhotoScan } from './detail';

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

  // 第 1 步在手機上逐字輸入 ISBN → 按 AI 帶入 → 依序查詢書目來源 → 書目單由下展開
  const TYPE = [1.3, 1.45, 1.6, 1.78], AI1 = 2.05, SHEET1 = 3.0;
  // 第 2 步按 AI 帶入 → 分析照片與行情 → 建議單由下展開
  const AI2 = 7.8, SHEET2 = 8.9;
  const steps: Step[] = [
    [0, 's_sell_isbn_t00'],
    ...(['t03', 't06', 't09', 't13'].map((n, i) => [TYPE[i], `s_sell_isbn_${n}`, 0, 0.03] as Step)),
    [AI1 + 0.07, 's_sell_isbn_loading', 0, 0.1],
    [SHEET1, 's_sell_fill', 3, 0.5],
    [6.15, 's_sell_info', 0, 0.35],
    [6.9, 's_sell_photos', 1, 0.45],
    // App 的分析進度分三步，與左側照片分析的勾選同步
    [AI2 + 0.12, 's_sell_ai_loading_1', 0, 0.12],
    [8.4, 's_sell_ai_loading_2', 0, 0.12],
    [8.65, 's_sell_ai_loading_3', 0, 0.12],
    [SHEET2, 's_sell_ai_sheet_220', 3, 0.5],
    [11.55, 's_sell_ready', 0, 0.35],
  ];
  stepCues(steps);
  TYPE.forEach((t0) => cue('key', t0, { gain: 0.35, pan: -0.1 }));
  const pipeline = new Pipeline(ui);
  const scan = new PhotoScan(ui);
  const mid = (r: { x: number; y: number; w: number; h: number }): [number, number] => [r.x + r.w / 2, r.y + r.h / 2];
  const taps = [
    new Tap(ui, SELLER, ...mid(R.isbnAi), AI1),
    new Tap(ui, SELLER, ...mid(R.fillApply), 5.75),
    new Tap(ui, SELLER, ...mid(R.photosAi), AI2),
    new Tap(ui, SELLER, ...mid(R.sellApply), 11.15),
    new Tap(ui, SELLER, ...mid(R.readySubmit), 12.55),
  ];
  const markFields = new Mark(ui, SELLER, R.fillFields).register(3.3);
  const markIntro = new Mark(ui, SELLER, R.fillIntro).register(4.4);
  const markCond = new Mark(ui, SELLER, R.sellCondition).register(9.5);
  const markPrice = new Mark(ui, SELLER, R.sellPrice).register(10.15);
  const markReady = new Mark(ui, SELLER, R.readyPrice).register(11.85);
  const capFields = new Caption(ui, '書目查詢', '依 ISBN 帶出書目', '書名、作者、出版社與出版日期', 120);
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
    // AI 影像審核另顯示判定與信心值
    const conf = g.title === 'AI 影像審核' ? el('p', 'gate__conf', box, '<span>允許</span><span>需複核</span><span>退回</span><i><b></b></i><em>信心值 0%</em>') : null;
    return { box, rows, conf };
  });
  // 兩道檢查排在手機右側，書卡沿底下的軌道依序停在每一道的正下方受檢
  const GX = [900, 1340];
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
        [0, DUO.seller], [0.6, { x: -0.13, y: -0.1, z: 4, rx: 0.02, ry: 0.32, rz: 0.03, s: 1.06 }], [1.25, CENTER], [2.75, CENTER], [3.3, fillF], [5.6, fillF], [6.2, CENTER],
        [9.0, CENTER], [9.5, sheetF], [11.25, sheetF], [11.75, readyF], [12.3, readyF], [12.8, CENTER], [12.85, CENTER], [13.6, LEFT],
      ]);
      pose = mix(pose, { ...LEFT, x: -1.5, ry: 0.6 }, easeIn(span(t, 17.6, 18.8)));
      f.phones[SELLER] = { pose, scr: seq(t, steps) };
    }
    // 買家手機在開場右側，往右後方退場
    if (t > -0.6 && t < 1.4) {
      const k = easeIn(span(t, 0, 1.2));
      f.phones[BUYER] = { pose: mix(DUO.buyer, { ...DUO.buyer, x: 1.45, y: -0.18, z: -12, ry: -1.35, rz: -0.06 }, k), scr: { a: 'b_home' } };
    }
    taps.forEach((tp) => tp.at(world, t));
    markFields.at(world, t, 3.35, 4.3);
    markIntro.at(world, t, 4.45, 5.55);
    markCond.at(world, t, 9.55, 10.15);
    markPrice.at(world, t, 10.2, 11.2);
    markReady.at(world, t, 11.9, 12.35);
    // 說明文字依序出現：前一則淡出（0.4 秒）後才出現下一則，避免重疊
    capFields.at(t, 3.35, 4.1, 400);
    pipeline.at(t, AI1 + 0.05, 4.25, [2.4, 2.65, 2.85, SHEET1], 120, 720);
    scan.at(t, AI2 + 0.05, 9.3, [8.15, 8.4, 8.65, SHEET2], 120, 540);
    capIntro.at(t, 4.5, 5.55, 500);
    capCond.at(t, 9.6, 10.1, 500);
    capPrice.at(t, 10.25, 11.15, 500);
    capReady.at(t, 11.9, 12.5, 500);

    // 書卡：自手機右側送出 → 停在第一道檢查下方 → 移到第二道下方 → 通過後移到右側，下一段由買家手機接手（find.ts 的書卡從同一位置出發）
    const out = easeOut(span(t, t2 + 0.1, t2 + 0.8));
    const x = 700 + (GX[0] - 700) * easeInOut(span(t, t2 + 0.1, t2 + 0.95))
      + (GX[1] - GX[0]) * easeInOut(span(t, t2 + 2.15, t2 + 2.75))
      + (CARD_X - GX[1]) * easeInOut(span(t, t2 + 3.95, t2 + 4.55));
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
      // 兩道檢查上緣對齊，虛線一律接到書卡上緣
      const h = g.box.offsetHeight;
      place(g.box, GX[gi], 310 + h / 2 + (1 - k) * 24);
      css(g.box, '--drop', `${(CARD_Y - card.offsetHeight / 2 - 310 - h).toFixed(0)}px`);
      // 連接線只在書卡停在這一關正下方時往下接到書卡，書卡離開即收回，不留沒有接到東西的線
      css(g.box, '--line', (vis ? Math.max(0, 1 - Math.abs(x - GX[gi]) / 40) : 0).toFixed(3));
      g.rows.forEach((r, ri) => r.classList.toggle('is-ok', t > t2 + 1.2 + gi * 1.6 + ri * 0.3));
      g.box.classList.toggle('is-pass', t > t2 + 1.2 + gi * 1.6 + g.rows.length * 0.3);
      if (g.conf) {
        const c0 = t2 + 1.2 + gi * 1.6;
        const k = easeOut(span(t, c0, c0 + 0.6));
        css(g.conf.querySelector('b')!, 'transform', `scaleX(${(k * 0.94).toFixed(3)})`);
        g.conf.querySelector('em')!.textContent = `信心值 ${Math.round(k * 94)}%`;
        g.conf.classList.toggle('is-ok', t > c0 + 0.6);
      }
    });
  };
}
