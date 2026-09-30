'use strict';

const { el, g, fmt, T, EASE, anim, animT, motion, linearGradient, radialGradient, rrect, nextId, during, drawPath, penDot, rng, blurFilter } = require('../lib/core');
const { text, measure } = require('../lib/text');
const { iphone } = require('../lib/iphone');
const U = require('../lib/appui');
const A = require('../lib/aiscreens');
const W3 = require('../lib/ui3');
const { icon } = require('../lib/icons');
const C = require('../lib/palette');

const PHONE = { x: 1372, y: 96, s: 1.0 };
const LEFT = 120;
const toScreen = (x, y) => ({ x: PHONE.x + x * PHONE.s, y: PHONE.y + y * PHONE.s });

function times(S0) {
  const t = (d) => S0 + d;
  return {
    S0,
    intro: [t(0), t(5.4)],
    assist: [t(5.4), t(14.2)],
    review: [t(14.2), t(21.4)],
    enrich: [t(21.4), t(27.4)],
    rec: [t(27.4), t(35.6)],
    advisor: [t(35.6), t(42.8)],
    support: [t(42.8), t(49.0)],
    gov: [t(49.0), t(54.0)],
    end: t(54.0),
  };
}

const MODE = { text: true };

const COPY = {
  intro: ['AI 輔助', ['從上架到售後，', '都有 AI 協助'], ['七項 AI 功能，涵蓋上架、找書、', '客服與交易爭議處理。']],
  assist: ['AI 上架輔助', ['拍張照片，', 'AI 判斷書況與售價'], ['依 ISBN 查詢書目與網路資料，', '並附上建議售價區間與資料來源。']],
  review: ['上架審核', ['規則＋AI，', '雙層把關'], ['規則即時攔截售價異常與站外交易，', 'AI 再判讀最多 4 張照片，', '必要時交由管理員複核。']],
  enrich: ['資料補齊', ['空白欄位，', '自動補齊'], ['上架後於背景依 ISBN 查詢書目，', '由 AI 整理成繁體中文簡介，', '並標示「由 AI 依書目整理」。']],
  rec: ['個人化推薦', ['每本推薦，', '都有理由'], ['分析收藏、購物車與瀏覽紀錄，', '以語意向量找出相近書籍，', '再由 AI 排序並寫下推薦理由。']],
  advisor: ['AI 書籍顧問', ['說出需求，', 'AI 幫您挑書'], ['理解分類、預算與書況條件，', '只推薦站內可購買的書籍。']],
  support: ['AI 客服', ['有問題，', '立即回覆'], ['以關鍵字與語意混合檢索', '常見問題與服務條款作答，', '複雜問題一鍵轉接客服人員。']],
  dispute: ['爭議分析', ['比對證據，', '輔助裁決'], ['比對上架資料、照片與爭議說明，', '整理摘要與建議，僅供管理員參考。']],
  gov: ['AI 治理', ['採用 OpenAI，', '用量與隱私全程把關'], ['設有每月預算與每日次數上限；', '使用前須取得同意，', '對話紀錄保存 90 天後自動刪除。']],
};

function block(eyebrow, title, body, [t0, t1]) {
  if (!MODE.text) return '';
  return W3.leftBlock({ x: LEFT, y: 310, eyebrow, title, body, t0: t0 + 0.15, t1: t1 - 0.45, titleSize: 72, bodySize: 32 }).markup;
}

function visible(t0, t1, ...children) {
  return g({ display: 'none' }, during(t0, t1), ...children);
}

function intro([t0, t1]) {
  const cx = 1310;
  const cy = 540;
  const nodes = [
    ['上架輔助', 'wand'],
    ['上架審核', 'verified'],
    ['資料補齊', 'doc'],
    ['個人化推薦', 'star'],
    ['AI 書籍顧問', 'sparkle'],
    ['AI 客服', 'headset'],
    ['爭議分析', 'gavel'],
  ];
  const rx = 400;
  const ry = 300;
  const glow = radialGradient(nextId('ig'), [
    [0, '#FFFFFF', 1],
    [0.35, C.brand, 0.85],
    [1, C.brand, 0],
  ]);
  const els = nodes.map(([label, ic], i) => {
    const ang = (-90 + (360 / nodes.length) * i) * (Math.PI / 180);
    const x = cx + rx * Math.cos(ang);
    const y = cy + ry * Math.sin(ang);
    const ts = t0 + 0.9 + i * 0.12;
    const d = `M${fmt(cx + 120 * Math.cos(ang))} ${fmt(cy + 120 * Math.sin(ang) * 0.9)}L${fmt(x)} ${fmt(y)}`;
    const p = W3.pill(x, y, label, { iconName: ic, anchor: 'middle', size: 24, t0: ts + 0.25, t1: t1 - 0.7 });
    return [
      g({}, anim('opacity', [[t1 - 0.7, 1], [t1 - 0.3, 0, 'in']]), drawPath(d, ts, 0.45, { stroke: C.brand, width: 1.6, attrs: { 'stroke-opacity': 0.5 } }), penDot(d, ts, 0.45, { r: 7, fill: glow })),
      p.markup,
    ];
  });
  return visible(t0, t1 + 0.2, W3.aiCore(cx, cy, { r: 86, t0: t0 + 0.2, t1: t1 - 0.5 }), els, block('AI 輔助', ['從上架到售後，', '都有 AI 協助'], ['七項 AI 功能，涵蓋上架、找書、', '客服與交易爭議處理。'], [t0, t1]));
}

function assist([t0, t1]) {
  const id = nextId('as');
  const px = 820;
  const py = 238;
  const pw = 320;
  const ph = 420;
  const photoClip = nextId('pc');
  require('../lib/core').addDef(el('clipPath', { id: photoClip }, rrect(px, py, pw, ph, 20)));
  const scanGrad = linearGradient(`${id}s`, [
    [0, C.brand, 0],
    [0.5, C.brand, 0.35],
    [1, C.brand, 0],
  ]);
  const scanStart = t0 + 1.2;
  const photo = motion(
    { o: [[t0 + 0.4, 0], [t0 + 0.9, 1, 'out'], [t1 - 0.6, 1, 'lin'], [t1 - 0.2, 0, 'in']], t: [[t0 + 0.4, [0, 24]], [t0 + 1.1, [0, 0], 'emph']] },
    W3.card(px, py, pw, ph, { r: 20 }),
    g(
      { 'clip-path': `url(#${photoClip})` },
      el('rect', { x: px, y: py, width: pw, height: ph, fill: '#DDE3E7' }),
      el('ellipse', { cx: px + pw / 2 + 10, cy: py + ph - 40, rx: 130, ry: 16, fill: '#0B1A26', 'fill-opacity': 0.18 }),
      U.bookCover(px + 60, py + 64, 200, 290, 6, { color: '#4F7A63', accent: '#E7D9B8' }),
      el('path', { d: `M${px + 246} ${py + 64}l14 0 0 14z`, fill: '#FFFFFF', 'fill-opacity': 0.5 }),
      el('rect', { x: px, y: py - 60, width: pw, height: 60, fill: scanGrad }, anim('y', [[scanStart, py - 60], [scanStart + 0.9, py + ph, 'inout'], [scanStart + 0.95, py - 60, 'lin'], [scanStart + 1.85, py + ph, 'inout']])),
      el('rect', { x: px, y: py - 2, width: pw, height: 2.5, fill: C.brand }, anim('y', [[scanStart, py - 2], [scanStart + 0.9, py + ph, 'inout'], [scanStart + 0.95, py - 2, 'lin'], [scanStart + 1.85, py + ph, 'inout']]), anim('opacity', [[scanStart, 1], [scanStart + 1.85, 1, 'lin'], [scanStart + 2.0, 0, 'out']]))
    ),
    text('書況照片', { x: px + 22, y: py + 42, size: W3.TY.cardTitle, weight: 700, fill: C.text }),
    icon('camera', px + pw - 50, py + 18, 28, C.muted)
  );
  const box = (x, y, w, h, tIn) => motion({ o: [[tIn, 0], [tIn + 0.2, 1, 'out'], [t1 - 0.6, 1, 'lin'], [t1 - 0.2, 0, 'in']] }, el('rect', { x, y, width: w, height: h, rx: 8, fill: C.brand, 'fill-opacity': 0.08, stroke: C.brand, 'stroke-width': 2.5, 'stroke-dasharray': '8 6' }));
  const leader = (a, b, tIn) => g({}, anim('opacity', [[t1 - 0.6, 1], [t1 - 0.2, 0, 'in']]), drawPath(`M${a[0]} ${a[1]}L${b[0]} ${b[1]}`, tIn, 0.3, { stroke: C.brand, width: 2 }));
  const d1 = scanStart + 1.0;
  const d2 = scanStart + 1.6;
  const res = scanStart + 2.2;
  return visible(
    t0,
    t1 + 0.2,
    photo,
    box(px + 222, py + 56, 56, 56, d1),
    leader([px + 278, py + 84], [1162, py + 84], d1 + 0.1),
    W3.pill(1166, py + 84, '邊角輕微磨損', { anchor: 'start', size: W3.TY.callout, t0: d1 + 0.3, t1: t1 - 0.6 }).markup,
    box(px + 70, py + 194, 180, 150, d2),
    leader([px + 250, py + 269], [1162, py + 269], d2 + 0.1),
    W3.pill(1166, py + 269, '無劃線與摺痕', { anchor: 'start', size: W3.TY.callout, t0: d2 + 0.3, t1: t1 - 0.6 }).markup,
    W3.pill(px, 736, '書況｜近全新', { size: W3.TY.callout, weight: 700, color: A.COND.近全新, iconName: 'checkCircle', iconColor: A.COND.近全新, t0: res, t1: t1 - 0.6 }).markup,
    W3.pill(px, 818, '建議售價 $280・區間 $240–$320', { size: W3.TY.callout, weight: 700, color: C.brand, iconName: 'tag', t0: res + 0.3, t1: t1 - 0.6 }).markup,
    block('AI 上架輔助', ['拍張照片，', 'AI 判斷書況與售價'], ['依 ISBN 查詢書目與網路資料，', '並附上建議售價區間與資料來源。'], [t0, t1])
  );
}

function review([t0, t1]) {
  const g1 = { x: 860, y: 270, w: 400, h: 330 };
  const g2 = { x: 1320, y: 270, w: 480, h: 330 };
  const trackY = 760;
  const fadeOut = [[t1 - 0.6, 1], [t1 - 0.2, 0, 'in']];
  const gate = (G, title, ic, tIn) =>
    motion(
      { o: [[tIn, 0], [tIn + 0.4, 1, 'out'], ...fadeOut.map(([t, v, e]) => [t, v, e || 'lin'])], t: [[tIn, [0, 20]], [tIn + 0.7, [0, 0], 'emph']] },
      W3.card(G.x, G.y, G.w, G.h, { r: 24 }),
      el('circle', { cx: G.x + 44, cy: G.y + 46, r: 22, fill: C.brand, 'fill-opacity': 0.12 }),
      icon(ic, G.x + 32, G.y + 34, 24, C.brand),
      text(title, { x: G.x + 80, y: G.y + 55, size: W3.TY.cardTitle, weight: 700, fill: C.text })
    );
  const rule = ['售價異常', '館藏來源字樣', '站外聯絡・付款'];
  const ruleRows = rule.map((label, i) => {
    const y = g1.y + 130 + i * 62;
    const tc = t0 + 1.6 + i * 0.25;
    return g(
      {},
      anim('opacity', fadeOut),
      motion({ o: [[t0 + 0.9 + i * 0.08, 0], [t0 + 1.3 + i * 0.08, 1, 'out']] }, text(label, { x: g1.x + 36, y: y + 9, size: 24, weight: 500, fill: C.text })),
      el('circle', { cx: g1.x + g1.w - 50, cy: y, r: 16, fill: 'none', stroke: C.border, 'stroke-width': 2, opacity: 0 }, anim('opacity', [[t0 + 0.9, 0], [t0 + 1.3, 1, 'out']])),
      motion({ o: [[tc, 0], [tc + 0.15, 1, 'out']], s: [[tc, 0.3], [tc + 0.4, 1, 'emph']], origin: [g1.x + g1.w - 50, y] }, el('circle', { cx: g1.x + g1.w - 50, cy: y, r: 16, fill: C.success }), el('path', { d: `M${g1.x + g1.w - 58} ${y}l5 5 10-10`, fill: 'none', stroke: '#FFFFFF', 'stroke-width': 2.6, 'stroke-linecap': 'round', 'stroke-linejoin': 'round' }))
    );
  });
  const thumbs = [0, 1, 2, 3].map((i) => {
    const x = g2.x + 30 + (i % 2) * 100;
    const y = g2.y + 96 + Math.floor(i / 2) * 104;
    return [rrect(x, y, 90, 94, 12, { fill: '#DDE3E7' }), U.bookCover(x + 22, y + 12, 46, 70, 3, { color: ['#4F7A63', '#5C8870', '#476F5A', '#4F7A63'][i], accent: '#E7D9B8' })];
  });
  const scanT = t0 + 2.4;
  const clipId = nextId('rv');
  require('../lib/core').addDef(el('clipPath', { id: clipId }, el('rect', { x: g2.x + 30, y: g2.y + 96, width: 190, height: 198 })));
  const scan = g({ 'clip-path': `url(#${clipId})` }, el('rect', { x: g2.x + 30, y: g2.y + 96, width: 190, height: 3, fill: C.brand }, anim('y', [[scanT, g2.y + 96], [scanT + 0.8, g2.y + 294, 'inout'], [scanT + 0.85, g2.y + 96, 'lin'], [scanT + 1.6, g2.y + 294, 'inout']]), anim('opacity', [[scanT, 0], [scanT + 0.05, 1, 'lin'], [scanT + 1.6, 1, 'lin'], [scanT + 1.7, 0, 'lin']])));
  const verdicts = [['允許', C.success], ['需複核', C.warning], ['違規', C.danger]];
  const vt = scanT + 1.5;
  const verdictEls = verdicts.map(([label, col], i) => {
    const x = g2.x + 250;
    const y = g2.y + 120 + i * 58;
    const on = i === 0;
    return [
      rrect(x, y - 22, 200, 44, 22, { fill: on ? col : '#FFFFFF', 'fill-opacity': on ? 0 : 1, stroke: C.border, 'stroke-width': 1.5 }),
      on ? rrect(x, y - 22, 200, 44, 22, { fill: col, 'fill-opacity': 0.14, stroke: col, 'stroke-width': 2.5, opacity: 0 }, anim('opacity', [[vt, 0], [vt + 0.3, 1, 'out']])) : '',
      el('circle', { cx: x + 24, cy: y, r: 7, fill: col }),
      text(label, { x: x + 42, y: y + 8.5, size: 22, weight: on ? 700 : 500, fill: on ? col : C.muted }),
    ];
  });
  const conf = g(
    {},
    text('信心值', { x: g2.x + 250, y: g2.y + 301, size: W3.TY.meta, fill: C.muted }),
    rrect(g2.x + 326, g2.y + 290, 124, 10, 5, { fill: C.border }),
    el('rect', { x: g2.x + 326, y: g2.y + 290, width: 0, height: 10, rx: 5, fill: C.success }, anim('width', [[vt + 0.2, 0], [vt + 0.9, 118, 'out']]))
  );
  const card = (x) => [W3.card(x, trackY - 44, 250, 88, { r: 20 }), U.bookCover(x + 16, trackY - 32, 46, 64, 4, { color: '#4F7A63', accent: '#E7D9B8' }), text('統計學概論', { x: x + 76, y: trackY - 5, size: W3.TY.card, weight: 700, fill: C.text }), text('$280', { x: x + 76, y: trackY + 25, size: W3.TY.meta, weight: 800, fill: C.brand })];
  const cardMove = motion(
    {
      o: [[t0 + 0.6, 0], [t0 + 1.0, 1, 'out'], ...fadeOut],
      t: [[t0 + 0.6, [0, 0]], [t0 + 1.5, [g1.x + g1.w / 2 - 125 - 820, 0], 'inout'], [scanT - 0.5, [g1.x + g1.w / 2 - 125 - 820, 0], 'lin'], [scanT, [g2.x + 120 - 125 - 820, 0], 'inout'], [vt + 0.9, [g2.x + 120 - 125 - 820, 0], 'lin'], [vt + 1.5, [g2.x + g2.w - 250 - 820, 0], 'inout']],
    },
    card(820)
  );
  const pass = W3.pill(g2.x + g2.w - 125, trackY + 104, '上架販售', { iconName: 'checkCircle', iconColor: C.success, color: C.success, weight: 700, anchor: 'middle', size: W3.TY.callout, t0: vt + 1.35, t1: t1 - 0.6 });
  const human = W3.pill(g1.x + g1.w / 2, trackY + 104, '需複核時交由管理員', { iconName: 'person', anchor: 'middle', size: W3.TY.callout, color: C.muted, t0: vt + 0.3, t1: t1 - 0.6 });
  const track = g({}, anim('opacity', fadeOut), drawPath(`M820 ${trackY + 60}H1800`, t0 + 0.5, 1.0, { stroke: C.border, width: 2 }));
  return visible(
    t0,
    t1 + 0.2,
    gate(g1, '規則式檢查', 'search', t0 + 0.4),
    gate(g2, 'AI 影像審核', 'sparkle', t0 + 0.6),
    ruleRows,
    g({}, anim('opacity', [[t0 + 1.0, 0], [t0 + 1.4, 1, 'out'], ...fadeOut]), thumbs, verdictEls, conf),
    scan,
    track,
    cardMove,
    human.markup,
    pass.markup,
    block('上架審核', ['規則＋AI，', '雙層把關'], ['規則即時攔截售價異常與站外交易，', 'AI 再判讀最多 4 張照片，', '必要時交由管理員複核。'], [t0, t1])
  );
}

function enrich([t0, t1]) {
  const fadeOut = [[t1 - 0.6, 1], [t1 - 0.2, 0, 'in']];
  const steps = ['Google Books', 'Open Library', '網路搜尋', 'AI 整理'];
  const x0 = 880;
  const gap = 250;
  const sy = 262;
  const stepEls = steps.map((label, i) => {
    const x = x0 + i * gap;
    const on = t0 + 0.8 + i * 0.4;
    return [
      i < steps.length - 1 ? drawPath(`M${x + 24} ${sy}H${x + gap - 24}`, on + 0.1, 0.35, { stroke: C.brand, width: 2 }) : '',
      el('circle', { cx: x, cy: sy, r: 18, fill: '#FFFFFF', stroke: C.border, 'stroke-width': 2 }),
      motion({ o: [[on, 0], [on + 0.15, 1, 'out']], s: [[on, 0.4], [on + 0.4, 1, 'emph']], origin: [x, sy] }, el('circle', { cx: x, cy: sy, r: 18, fill: i === 3 ? C.brand : C.success }), i === 3 ? icon('sparkle', x - 11, sy - 11, 22, '#FFFFFF') : el('path', { d: `M${x - 8} ${sy}l5 5 10-10`, fill: 'none', stroke: '#FFFFFF', 'stroke-width': 2.6, 'stroke-linecap': 'round', 'stroke-linejoin': 'round' })),
      text(label, { x, y: sy + 52, size: 22, weight: 600, fill: C.text, anchor: 'middle' }),
    ];
  });
  const cardX = 820;
  const cardY = 360;
  const cardW = 1000;
  const cardH = 520;
  const rows = [['作者', '林志明'], ['出版社', '智識出版'], ['出版日期', '2022 年 2 月'], ['頁數', '512 頁']];
  const fillAt = t0 + 2.1;
  const rowEls = rows.map(([k, v], i) => {
    const y = cardY + 124 + i * 50;
    const tf = fillAt + i * 0.28;
    return [
      text(k, { x: cardX + 300, y, size: W3.TY.card, weight: 500, fill: C.muted }),
      rrect(cardX + 440, y - 22, 220, 26, 8, { fill: C.skeleton || '#E6EAEE', opacity: 1 }, anim('opacity', [[tf, 1], [tf + 0.2, 0, 'out']])),
      motion({ o: [[tf, 0], [tf + 0.3, 1, 'out']], t: [[tf, [12, 0]], [tf + 0.5, [0, 0], 'emph']] }, text(v, { x: cardX + 440, y, size: W3.TY.card, weight: 700, fill: C.text })),
    ];
  });
  const summary = ['從資料蒐集、敘述統計到推論統計，', '循序說明統計學的核心概念，', '並以生活實例與練習題幫助理解。'];
  const sumAt = fillAt + 1.3;
  const sumEls = summary.map((line, i) => motion({ o: [[sumAt + i * 0.2, 0], [sumAt + i * 0.2 + 0.4, 1, 'out']] }, text(line, { x: cardX + 300, y: cardY + 378 + i * 38, size: W3.TY.card, fill: C.text })));
  const label = motion({ o: [[sumAt + 0.8, 0], [sumAt + 1.1, 1, 'out']] }, icon('sparkle', cardX + 300, cardY + 474, 22, C.faint), text('由 AI 依書目整理', { x: cardX + 330, y: cardY + 492, size: W3.TY.meta, fill: C.faint }));
  return visible(
    t0,
    t1 + 0.2,
    g({}, anim('opacity', [[t0 + 0.3, 0], [t0 + 0.7, 1, 'out'], ...fadeOut]), stepEls),
    motion(
      { o: [[t0 + 0.5, 0], [t0 + 0.9, 1, 'out'], ...fadeOut], t: [[t0 + 0.5, [0, 30]], [t0 + 1.3, [0, 0], 'emph']] },
      W3.card(cardX, cardY, cardW, cardH, { r: 26 }),
      rrect(cardX + 40, cardY + 40, 210, 300, 10, { fill: '#DDE3E7' }),
      U.bookCover(cardX + 60, cardY + 64, 170, 250, 5, { color: '#4F7A63', accent: '#E7D9B8' }),
      text('統計學概論', { x: cardX + 300, y: cardY + 74, size: 32, weight: 700, fill: C.text }),
      rowEls,
      text('書籍簡介', { x: cardX + 300, y: cardY + 338, size: W3.TY.meta, weight: 700, fill: C.muted }),
      sumEls,
      label
    ),
    block('資料補齊', ['空白欄位，', '自動補齊'], ['上架後於背景依 ISBN 查詢書目，', '由 AI 整理成繁體中文簡介，', '並標示「由 AI 依書目整理」。'], [t0, t1])
  );
}

function recommend([t0, t1], rowsAt, { targets } = {}) {
  const fadeOut = [[t1 - 0.6, 1], [t1 - 0.2, 0, 'in']];
  const px = 800;
  const py = 250;
  const pw = 520;
  const ph = 580;
  const r = rng(11);
  const dots = [];
  for (let i = 0; i < 46; i++) {
    const x = px + 40 + r() * (pw - 80);
    const y = py + 110 + r() * (ph - 150);
    dots.push({ x, y, s: 4 + r() * 4, o: 0.18 + r() * 0.3 });
  }
  const fav = { x: px + 230, y: py + 330 };
  const near = [
    { x: fav.x + 90, y: fav.y - 70, label: '機率與統計' },
    { x: fav.x - 110, y: fav.y - 40, label: '迴歸分析實務' },
    { x: fav.x + 40, y: fav.y + 100, label: '資料分析入門' },
  ];
  const tDots = t0 + 0.6;
  const tFav = t0 + 1.3;
  const tRadar = t0 + 1.7;
  const tNear = t0 + 2.2;
  const tFly = rowsAt - 0.5;
  const dotEls = dots.map((d, i) => el('circle', { cx: d.x, cy: d.y, r: d.s, fill: C.brand, 'fill-opacity': d.o, opacity: 0 }, anim('opacity', [[tDots + i * 0.012, 0], [tDots + i * 0.012 + 0.3, 1, 'out']])));
  const glow = radialGradient(nextId('rg'), [
    [0, '#FFFFFF', 1],
    [0.3, C.brand, 0.9],
    [1, C.brand, 0],
  ]);
  const cardTargets = [0, 1, 2].map((i) => (targets ? targets(i) : toScreen(16 + i * 127 + 58, 59 + 8 + 30 + 20 + 44 + 20 + 76 + 28 + 12 + 55)));
  const nearEls = near.map((n, i) => {
    const tn = tNear + i * 0.15;
    const target = cardTargets[i];
    const path = `M${fmt(n.x)} ${fmt(n.y)}Q${fmt((n.x + target.x) / 2)} ${fmt(Math.min(n.y, target.y) - 120)} ${fmt(target.x)} ${fmt(target.y)}`;
    return [
      drawPath(`M${fav.x} ${fav.y}L${n.x} ${n.y}`, tn, 0.35, { stroke: C.brand, width: 2 }),
      motion({ o: [[tn, 0], [tn + 0.2, 1, 'out']], s: [[tn, 0.3], [tn + 0.45, 1, 'emph']], origin: [n.x, n.y] }, el('circle', { cx: n.x, cy: n.y, r: 10, fill: C.brand })),
      motion({ o: [[tn + 0.2, 0], [tn + 0.5, 1, 'out'], [tFly, 1, 'lin'], [tFly + 0.3, 0, 'out']] }, text(n.label, { x: n.x, y: n.y + (i === 2 ? 44 : -24), size: W3.TY.meta, weight: 700, fill: C.text, anchor: 'middle' })),
      el(
        'circle',
        { r: 11, fill: glow, opacity: 0 },
        el('animateMotion', { path, begin: T(tFly + i * 0.08), dur: '0.8s', fill: 'freeze', calcMode: 'spline', keyPoints: '0;1', keyTimes: '0;1', keySplines: EASE.inout.join(' ') }),
        anim('opacity', [[tFly + i * 0.08, 0], [tFly + i * 0.08 + 0.1, 1, 'out'], [tFly + i * 0.08 + 0.75, 1, 'lin'], [tFly + i * 0.08 + 0.95, 0, 'out']])
      ),
    ];
  });
  const panel = motion(
    { o: [[t0 + 0.3, 0], [t0 + 0.7, 1, 'out'], ...fadeOut], t: [[t0 + 0.3, [0, 24]], [t0 + 1.1, [0, 0], 'emph']] },
    W3.card(px, py, pw, ph, { r: 26 }),
    text('語意向量空間', { x: px + 32, y: py + 54, size: W3.TY.cardTitle, weight: 700, fill: C.text }),
    text('依收藏、購物車與瀏覽紀錄比對', { x: px + 32, y: py + 92, size: W3.TY.meta, fill: C.muted }),
    dotEls,
    el('circle', { cx: fav.x, cy: fav.y, r: 20, fill: 'none', stroke: C.brand, 'stroke-width': 2, opacity: 0 }, anim('r', [[tRadar, 20], [tRadar + 1.2, 170, 'out']]), anim('opacity', [[tRadar, 0.8], [tRadar + 1.2, 0, 'out']])),
    el('circle', { cx: fav.x, cy: fav.y, r: 20, fill: 'none', stroke: C.brand, 'stroke-width': 2, opacity: 0 }, anim('r', [[tRadar + 0.4, 20], [tRadar + 1.6, 170, 'out']]), anim('opacity', [[tRadar + 0.4, 0.6], [tRadar + 1.6, 0, 'out']])),
    motion({ o: [[tFav, 0], [tFav + 0.2, 1, 'out']], s: [[tFav, 0.3], [tFav + 0.5, 1, 'emph']], origin: [fav.x, fav.y] }, el('circle', { cx: fav.x, cy: fav.y, r: 15, fill: C.brand }), icon('heart', fav.x - 9, fav.y - 9, 18, '#FFFFFF')),
    W3.pill(fav.x, fav.y + 56, '已收藏：統計學概論', { anchor: 'middle', size: W3.TY.meta, weight: 700, t0: tFav + 0.3, t1: tFly }).markup,
    nearEls
  );
  return visible(t0, t1 + 0.2, panel, block('個人化推薦', ['每本推薦，', '都有理由'], ['分析收藏、購物車與瀏覽紀錄，', '以語意向量找出相近書籍，', '再由 AI 排序並寫下推薦理由。'], [t0, t1]));
}

function underline(x, y, before, word, t) {
  const ox = measure(before, W3.TY.body, { weight: 600 });
  const w = measure(word, W3.TY.body, { weight: 600 });
  return el('rect', { x: x + ox, y, width: 0, height: 4, rx: 2, fill: C.brand }, anim('width', [[t, 0], [t + 0.3, w, 'out']]));
}

function advisorVisual([t0, t1], tm) {
  const fadeOut = [[t1 - 0.6, 1], [t1 - 0.2, 0, 'in']];
  const x = 800;
  const card = motion(
    { o: [[t0 + 0.4, 0], [t0 + 0.8, 1, 'out'], ...fadeOut], t: [[t0 + 0.4, [0, 20]], [t0 + 1.1, [0, 0], 'emph']] },
    W3.card(x, 250, 520, 170, { r: 24 }),
    text('使用者需求', { x: x + 28, y: 292, size: W3.TY.meta, weight: 700, fill: C.muted }),
    text('想找適合入門的程式設計書，', { x: x + 28, y: 342, size: W3.TY.body, weight: 600, fill: C.text }),
    text('預算 300 代幣以內', { x: x + 28, y: 390, size: W3.TY.body, weight: 600, fill: C.text }),
    underline(x + 28, 351, '想找適合', '入門', tm.send + 0.3),
    underline(x + 28, 351, '想找適合入門的', '程式設計', tm.send + 0.45),
    underline(x + 28, 399, '預算 ', '300 代幣以內', tm.send + 0.6)
  );
  const chips = [
    ['程度｜入門', 'star'],
    ['分類｜程式設計', 'tag'],
    ['預算｜300 代幣以內', 'pie'],
  ];
  const chipEls = chips.map(([label, ic], i) => W3.pill(x, 484 + i * 72, label, { iconName: ic, size: W3.TY.callout, t0: tm.send + 0.8 + i * 0.15, t1: t1 - 0.6 }).markup);
  const filter = W3.pill(x, 710, '排除他人預約保留中的書籍', { iconName: 'lock', size: W3.TY.callout, color: C.muted, t0: tm.send + 1.35, t1: t1 - 0.6 });
  const result = W3.pill(x, 800, '找到 3 本站內可購買的書', { iconName: 'checkCircle', iconColor: C.success, size: W3.TY.callout, weight: 700, color: C.success, t0: tm.reply + 0.2, t1: t1 - 0.6 });
  return visible(t0, t1 + 0.2, card, chipEls, filter.markup, result.markup, block('AI 書籍顧問', ['說出需求，', 'AI 幫您挑書'], ['理解分類、預算與書況條件，', '只推薦站內可購買的書籍。'], [t0, t1]));
}

function supportVisual([t0, t1], tm) {
  const fadeOut = [[t1 - 0.6, 1], [t1 - 0.2, 0, 'in']];
  const docs = ['常見問題', '服務條款', '隱私權政策', '平台說明', '我的訂單'];
  const x0 = 830;
  const y0 = 330;
  const hl = tm.send + 0.55;
  const docEls = docs.map((label, i) => {
    const x = x0 + i * 16;
    const y = y0 + i * 70;
    const tIn = t0 + 0.4 + i * 0.08;
    const isHit = i === 0;
    return motion(
      { o: [[tIn, 0], [tIn + 0.35, 1, 'out'], ...fadeOut], t: [[tIn, [0, 20]], [tIn + 0.7, [0, 0], 'emph'], ...(isHit ? [[hl, [0, 0], 'lin'], [hl + 0.5, [-10, -34], 'emph']] : [])] },
      W3.card(x, y, 440, 118, { r: 18 }),
      isHit ? el('rect', { x, y, width: 440, height: 118, rx: 18, fill: 'none', stroke: C.brand, 'stroke-width': 3, opacity: 0 }, anim('opacity', [[hl, 0], [hl + 0.3, 1, 'out']])) : '',
      icon('doc', x + 22, y + 22, 24, isHit ? C.brand : C.muted),
      text(label, { x: x + 58, y: y + 43, size: W3.TY.card, weight: 700, fill: C.text }),
      rrect(x + 24, y + 64, 300, 10, 5, { fill: '#E6EAEE' }),
      rrect(x + 24, y + 86, 220, 10, 5, { fill: '#E6EAEE' })
    );
  });
  const beams = [
    W3.pill(830, 262, '關鍵字檢索', { iconName: 'search', size: W3.TY.callout, t0: tm.send + 0.15, t1: t1 - 0.6 }),
    W3.pill(1062, 262, '語意檢索', { iconName: 'sparkle', size: W3.TY.callout, t0: tm.send + 0.3, t1: t1 - 0.6 }),
  ];
  const excerpt = motion(
    { o: [[hl + 0.4, 0], [hl + 0.7, 1, 'out'], ...fadeOut], t: [[hl + 0.4, [0, 10]], [hl + 0.9, [0, 0], 'emph']] },
    rrect(830, 716, 480, 104, 18, { fill: C.brand, 'fill-opacity': 0.08, stroke: C.brand, 'stroke-opacity': 0.4, 'stroke-width': 1.5 }),
    text('找到相關段落', { x: 856, y: 755, size: W3.TY.meta, weight: 700, fill: C.brand }),
    text('買家完成訂單或取書滿 24 小時後撥款', { x: 856, y: 796, size: W3.TY.card, weight: 600, fill: C.text })
  );
  return visible(t0, t1 + 0.2, docEls, beams.map((b) => b.markup), excerpt, block('AI 客服', ['有問題，', '立即回覆'], ['以關鍵字與語意混合檢索', '常見問題與服務條款作答，', '複雜問題一鍵轉接客服人員。'], [t0, t1]));
}

function governance([t0, t1], { core = true, lineStart = 100 } = {}) {
  const cx = 1310;
  const cy = 520;
  const py = 236;
  const provider = W3.pill(cx, py, 'OpenAI', { anchor: 'middle', size: W3.TY.callout, weight: 700, t0: t0 + 0.5, t1: t1 - 0.5 });
  const tSel = t0 + 1.3;
  const ring = rrect(provider.left - 7, py - provider.h / 2 - 7, provider.w + 14, provider.h + 14, (provider.h + 14) / 2, { fill: 'none', stroke: C.brand, 'stroke-width': 3, opacity: 0 }, anim('opacity', [[tSel, 0], [tSel + 0.25, 1, 'out'], [t1 - 0.5, 1, 'lin'], [t1 - 0.2, 0, 'in']]));
  const d = `M${cx} ${cy - lineStart}L${cx} ${py + provider.h / 2 + 4}`;
  const glow = radialGradient(nextId('gv'), [
    [0, '#FFFFFF', 1],
    [0.35, C.brand, 0.9],
    [1, C.brand, 0],
  ]);
  const wire = g(
    {},
    anim('opacity', [[t1 - 0.5, 1], [t1 - 0.2, 0, 'in']]),
    drawPath(d, t0 + 0.6, 0.4, { stroke: C.brand, width: 2, attrs: { 'stroke-opacity': 0.5 } }),
    [0, 1, 2].map((k) => penDot(d, t0 + 1.0 + k * 1.2, 0.8, { r: 9, fill: glow }))
  );
  const guards = [
    ['每月預算上限', 'pie'],
    ['每日次數上限', 'clock'],
    ['使用前取得同意', 'verified'],
    ['對話保存 90 天', 'doc'],
  ];
  const guardEls = guards.map(([label, ic], i) => {
    const left = i % 2 === 0;
    const y = 792 + Math.floor(i / 2) * 72;
    return W3.pill(left ? cx - 12 : cx + 12, y, label, { iconName: ic, anchor: left ? 'end' : 'start', size: W3.TY.callout, t0: t0 + 1.6 + i * 0.12, t1: t1 - 0.5 }).markup;
  });
  return visible(
    t0,
    t1 + 0.2,
    core ? W3.aiCore(cx, cy, { r: 70, t0: t0 + 0.2, t1: t1 - 0.5 }) : '',
    wire,
    provider.markup,
    ring,
    guardEls,
    block('AI 治理', ['採用 OpenAI，', '用量與隱私全程把關'], ['設有每月預算與每日次數上限；', '使用前須取得同意，', '對話紀錄保存 90 天後自動刪除。'], [t0, t1])
  );
}

function disputeVisual([t0, t1]) {
  const TY = W3.TY;
  const fadeOut = [[t1 - 0.6, 1], [t1 - 0.2, 0, 'in']];
  const slideIn = (tIn, dx, ...children) => motion({ o: [[tIn, 0], [tIn + 0.4, 1, 'out'], ...fadeOut], t: [[tIn, [dx, 0]], [tIn + 0.8, [0, 0], 'emph']] }, ...children);
  const appear = (tIn, ...children) => motion({ o: [[tIn, 0], [tIn + 0.35, 1, 'out'], ...fadeOut], t: [[tIn, [0, 12]], [tIn + 0.6, [0, 0], 'emph']] }, ...children);
  const head = (x, y, ic, label) => [el('circle', { cx: x + 22, cy: y, r: 22, fill: C.brand, 'fill-opacity': 0.12 }), icon(ic, x + 10, y - 12, 24, C.brand), text(label, { x: x + 58, y: y + 9, size: TY.cardTitle, weight: 700, fill: C.text })];
  const chip = (x, y, label, col) => {
    const w = measure(label, TY.meta, { weight: 700 }) + 28;
    return [rrect(x, y - 19, w, 38, 19, { fill: col, 'fill-opacity': 0.14 }), text(label, { x: x + 14, y: y + 8, size: TY.meta, weight: 700, fill: col })];
  };
  const ring = (x, y, w, h, r, tOn) => rrect(x - 5, y - 5, w + 10, h + 10, r + 5, { fill: 'none', stroke: C.brand, 'stroke-width': 3, opacity: 0 }, anim('opacity', [[tOn, 0], [tOn + 0.2, 1, 'out'], [t1 - 0.6, 1, 'lin'], [t1 - 0.2, 0, 'in']]));
  const tag = (x, y, label, tOn) => motion({ o: [[tOn, 0], [tOn + 0.2, 1, 'out'], ...fadeOut], s: [[tOn, 0.5], [tOn + 0.4, 1, 'emph']], origin: [x, y] }, W3.pill(x, y, label, { size: TY.meta, weight: 700, anchor: 'middle', color: C.brand }).markup);

  const cA = { x: 660, y: 300, w: 460, h: 250 };
  const cB = { x: 660, y: 580, w: 460, h: 370 };
  const pn = { x: 1240, y: 300, w: 700, h: 660 };
  const tF = [t0 + 3.3, t0 + 3.7, t0 + 4.1];

  const bookBox = { x: cA.x + 30, y: cA.y + 88, w: 104, h: 136 };
  const noteW = measure('無劃線、無摺痕', TY.meta);
  const cardA = slideIn(
    t0 + 0.3,
    -40,
    W3.card(cA.x, cA.y, cA.w, cA.h, { r: 24 }),
    head(cA.x + 30, cA.y + 48, 'doc', '上架資料'),
    rrect(bookBox.x, bookBox.y, bookBox.w, bookBox.h, 12, { fill: '#DDE3E7' }),
    U.bookCover(bookBox.x + 14, bookBox.y + 12, 76, 112, 4, { color: '#8C5A3C', accent: '#F1E3C8' }),
    text('會計學原理', { x: cA.x + 158, y: cA.y + 120, size: TY.card, weight: 700, fill: C.text }),
    chip(cA.x + 158, cA.y + 162, '近全新', '#66BB6A'),
    text('無劃線、無摺痕', { x: cA.x + 158, y: cA.y + 214, size: TY.meta, fill: C.muted }),
    drawPath(`M${cA.x + 158} ${cA.y + 226}H${fmt(cA.x + 158 + noteW)}`, tF[1] + 0.1, 0.4, { stroke: C.brand, width: 3 })
  );

  const page = (x, y, marks) => {
    const lines = [0, 1, 2, 3, 4, 5, 6].map((i) => {
      const yy = y + 22 + i * 17;
      const w = i === 6 ? 52 : 92 - (i % 3) * 8;
      return [marks.includes(i) ? el('rect', { x: x + 10, y: yy - 5, width: w + 8, height: 13, rx: 3, fill: '#F6D55C', 'fill-opacity': 0.85 }) : '', el('rect', { x: x + 14, y: yy, width: w, height: 4, rx: 2, fill: '#9AA5AE' })];
    });
    return [rrect(x, y, 120, 150, 10, { fill: '#FFFFFF', stroke: C.border, 'stroke-width': 1.5 }), lines];
  };
  const shots = [{ x: cB.x + 30, y: cB.y + 184, marks: [1, 2, 4] }, { x: cB.x + 166, y: cB.y + 184, marks: [0, 3, 5] }];
  const cardB = slideIn(
    t0 + 0.45,
    -40,
    W3.card(cB.x, cB.y, cB.w, cB.h, { r: 24 }),
    head(cB.x + 30, cB.y + 48, 'chat', '爭議說明'),
    text('佐證照片 2 張', { x: cB.x + cB.w - 30, y: cB.y + 56, size: TY.meta, fill: C.muted, anchor: 'end' }),
    text('內頁有多頁螢光筆劃線，', { x: cB.x + 30, y: cB.y + 112, size: TY.card, fill: C.text }),
    text('與標示的書況不符。', { x: cB.x + 30, y: cB.y + 148, size: TY.card, fill: C.text }),
    shots.map((p) => page(p.x, p.y, p.marks))
  );
  const highlights = [
    shots.map((p) => ring(p.x, p.y, 120, 150, 10, tF[0] + 0.05)),
    tag(shots[0].x + 60, shots[0].y + 150, '照片 3', tF[0] + 0.1),
    tag(shots[1].x + 60, shots[1].y + 150, '照片 4', tF[0] + 0.18),
    ring(bookBox.x, bookBox.y, bookBox.w, bookBox.h, 12, tF[2] + 0.05),
    tag(bookBox.x + bookBox.w / 2, bookBox.y + bookBox.h, '照片 1', tF[2] + 0.1),
  ];

  const hub = { x: 1180, y: 625 };
  const dA = `M${cA.x + cA.w} ${cA.y + cA.h / 2}C1150 ${cA.y + cA.h / 2} 1146 ${hub.y} ${hub.x - 30} ${hub.y}`;
  const dB = `M${cB.x + cB.w} ${cB.y + cB.h / 2}C1150 ${cB.y + cB.h / 2} 1146 ${hub.y} ${hub.x - 30} ${hub.y}`;
  const glow = radialGradient(nextId('dg'), [
    [0, '#FFFFFF', 1],
    [0.35, C.brand, 0.9],
    [1, C.brand, 0],
  ]);
  const wires = g(
    {},
    anim('opacity', fadeOut),
    drawPath(dA, t0 + 0.9, 0.5, { stroke: C.brand, width: 2.5, attrs: { 'stroke-opacity': 0.5 } }),
    drawPath(dB, t0 + 0.95, 0.5, { stroke: C.brand, width: 2.5, attrs: { 'stroke-opacity': 0.5 } }),
    drawPath(`M${hub.x + 30} ${hub.y}H${pn.x}`, t0 + 1.3, 0.2, { stroke: C.brand, width: 2.5, attrs: { 'stroke-opacity': 0.5 } }),
    [0, 1, 2].map((k) => [penDot(dA, t0 + 1.0 + k * 0.45, 0.7, { r: 12, fill: glow }), penDot(dB, t0 + 1.1 + k * 0.45, 0.7, { r: 12, fill: glow })])
  );
  const hubEl = motion(
    { o: [[t0 + 1.1, 0], [t0 + 1.3, 1, 'out'], ...fadeOut], s: [[t0 + 1.1, 0.3], [t0 + 1.6, 1, 'emph'], [t0 + 2.0, 1.12, 'soft'], [t0 + 2.4, 1, 'soft']], origin: [hub.x, hub.y] },
    el('circle', { cx: hub.x, cy: hub.y, r: 30, fill: C.brand }),
    icon('sparkle', hub.x - 14, hub.y - 14, 28, '#FFFFFF')
  );

  const skeleton = g(
    { opacity: 0 },
    anim('opacity', [[t0 + 1.6, 0], [t0 + 1.8, 1, 'out'], [t0 + 2.5, 1, 'lin'], [t0 + 2.7, 0, 'out']]),
    [[420, 0], [600, 1], [520, 2]].map(([w, i]) => rrect(pn.x + 30, pn.y + 108 + i * 46, w, 22, 11, { fill: '#E6EAEE' }, el('animate', { attributeName: 'opacity', values: '1;0.45;1', dur: '0.9s', begin: T(t0 + 1.6 + i * 0.15), repeatCount: 'indefinite' })))
  );
  const sugLabel = '建議退款・可信度：高';
  const sugW = measure(sugLabel, TY.card, { weight: 700 }) + 76;
  const suggestion = motion(
    { o: [[t0 + 2.6, 0], [t0 + 2.8, 1, 'out'], ...fadeOut], s: [[t0 + 2.6, 0.6], [t0 + 3.1, 1, 'emph']], origin: [pn.x + 30, pn.y + 129] },
    rrect(pn.x + 30, pn.y + 104, sugW, 50, 25, { fill: C.warning, 'fill-opacity': 0.14 }),
    icon('undo', pn.x + 46, pn.y + 117, 24, C.warning),
    text(sugLabel, { x: pn.x + 80, y: pn.y + 138, size: TY.card, weight: 700, fill: C.warning })
  );
  const summary = ['買家取書後表示內頁有多頁劃線，', '與上架標示的「近全新」不符。'].map((line, i) => appear(t0 + 2.85 + i * 0.1, text(line, { x: pn.x + 30, y: pn.y + 204 + i * 38, size: TY.card, fill: C.text })));
  const findings = [
    ['佐證照片可見多頁螢光筆劃線', '有利買家・照片 3（佐證）'],
    ['上架描述標示無劃線', '有利買家'],
    ['上架照片未拍攝內頁', '照片 1（封面）・照片 2（封底）'],
  ].map(([content, meta], i) => {
    const y = pn.y + 304 + i * 80;
    return appear(tF[i], el('circle', { cx: pn.x + 38, cy: y - 8, r: 4.5, fill: C.muted }), text(content, { x: pn.x + 56, y, size: TY.card, fill: C.text }), text(meta, { x: pn.x + 56, y: y + 33, size: TY.meta, fill: C.faint }));
  });
  const footnote = appear(
    t0 + 4.6,
    el('line', { x1: pn.x + 30, y1: pn.y + 536, x2: pn.x + pn.w - 30, y2: pn.y + 536, stroke: C.border, 'stroke-width': 1.5 }),
    icon('info', pn.x + 30, pn.y + 555, 22, C.faint),
    text('AI 分析僅供參考，請依實際證據裁決。', { x: pn.x + 62, y: pn.y + 574, size: TY.meta, fill: C.muted })
  );
  const decideY = pn.y + 622;
  const decideHead = appear(t0 + 5.0, icon('gavel', pn.x + 30, decideY - 13, 26, C.brand), text('管理員裁決', { x: pn.x + 64, y: decideY + 9, size: TY.card, weight: 700, fill: C.text }));
  let dx = pn.x + 202;
  const decisions = ['人工退款', '自動退款', '駁回爭議', '協調結案'].map((label, i) => {
    const w = measure(label, TY.meta, { weight: 600 }) + 22;
    const x = dx;
    dx += w + 8;
    return appear(t0 + 5.1 + i * 0.08, rrect(x, decideY - 20, w, 40, 20, { fill: '#FFFFFF', stroke: C.border, 'stroke-width': 1.5 }), text(label, { x: x + 11, y: decideY + 8, size: TY.meta, weight: 600, fill: C.text }));
  });
  const panel = slideIn(
    t0 + 1.3,
    40,
    W3.card(pn.x, pn.y, pn.w, pn.h, { r: 26 }),
    el('circle', { cx: pn.x + 52, cy: pn.y + 50, r: 22, fill: C.brand, 'fill-opacity': 0.12 }),
    icon('sparkle', pn.x + 40, pn.y + 38, 24, C.brand),
    text('AI 分析', { x: pn.x + 88, y: pn.y + 59, size: TY.cardTitle, weight: 700, fill: C.text }),
    text('AI 參考：上架 2 張、佐證 2 張', { x: pn.x + pn.w - 30, y: pn.y + 58, size: TY.meta, fill: C.muted, anchor: 'end' })
  );
  return visible(t0, t1 + 0.2, cardA, cardB, wires, hubEl, panel, skeleton, suggestion, summary, findings, highlights, footnote, decideHead, decisions);
}

function phone(t) {
  const a0 = t.assist[0];
  const steps = [a0 + 0.9, a0 + 1.5, a0 + 2.1, a0 + 2.7];
  const sheet = { steps, doneAt: steps[3] + 0.1, expand: a0 + 3.4, tap: t.assist[1] - 0.9 };
  const adv = { typeAt: t.advisor[0] + 0.6, send: t.advisor[0] + 1.7, reply: t.advisor[0] + 2.9, thumb: t.advisor[1] - 1.2 };
  const sup = { send: t.support[0] + 0.9, reply: t.support[0] + 2.0 };
  const rowsAt = t.rec[0] + 4.2;
  const screens = [
    A.assistSheet(a0, t.review[0] + 0.1, sheet),
    A.home(t.rec[0] - 0.3, t.advisor[0], rowsAt),
    A.advisor(t.advisor[0], t.support[0], adv),
    A.support(t.support[0], t.gov[0] + 0.2, sup),
  ];
  const outB = t.review[0] - 0.2;
  const inE = t.rec[0] - 0.4;
  const outH = t.gov[0] - 0.2;
  const mv = motion(
    {
      x: PHONE.x,
      y: PHONE.y,
      t: [
        [t.assist[0] + 0.05, [40, 840]],
        [t.assist[0] + 1.1, [0, 0], 'emph'],
        [outB, [0, 0], 'lin'],
        [outB + 0.7, [720, 40], 'in'],
        [inE, [720, 40], 'lin'],
        [inE + 0.9, [0, 0], 'emph'],
        [outH, [0, 0], 'lin'],
        [outH + 0.7, [720, 40], 'in'],
      ],
      r: [[t.assist[0] + 0.05, 5], [t.assist[0] + 1.1, 0, 'emph'], [outB, 0, 'lin'], [outB + 0.7, 8, 'in'], [inE, 8, 'lin'], [inE + 0.9, 0, 'emph'], [outH, 0, 'lin'], [outH + 0.7, 8, 'in']],
      origin: [(U.W * PHONE.s) / 2, (U.H * PHONE.s) / 2],
    },
    g({ transform: `scale(${PHONE.s})` }, iphone(screens, { glint: t.assist[0] + 0.7 }))
  );
  return { markup: visible(t.assist[0], t.end, mv), adv, sup, rowsAt };
}

function scrim() {
  const grad = linearGradient('aiScrim', [
    [0, C.stage, 1],
    [0.6, C.stage, 0.9],
    [1, C.stage, 0],
  ], { x1: 0, y1: 0, x2: 1, y2: 0 });
  return el('rect', { x: 0, y: 0, width: 820, height: 1080, fill: grad });
}

function build(S0) {
  const t = times(S0);
  const ph = phone(t);
  return {
    t,
    end: t.end,
    markup: g(
      {},
      intro(t.intro),
      assist(t.assist),
      review(t.review),
      enrich(t.enrich),
      recommend(t.rec, ph.rowsAt),
      advisorVisual(t.advisor, ph.adv),
      supportVisual(t.support, ph.sup),
      governance(t.gov),
      ph.markup
    ),
  };
}

module.exports = { build, times, MODE, COPY, intro, assist, review, enrich, recommend, advisorVisual, supportVisual, disputeVisual, governance, phone, toScreen };
