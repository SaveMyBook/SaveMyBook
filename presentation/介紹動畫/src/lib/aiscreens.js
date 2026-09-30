'use strict';

const { el, g, fmt, T, anim, motion, rrect, linearGradient, nextId, during, blurFilter } = require('./core');
const { text, measure, ellipsize } = require('./text');
const U = require('./appui');
const { icon } = require('./icons');
const { statusBar } = require('./iphone');
const C = require('./palette');

const COND = { 全新: '#26A69A', 近全新: '#66BB6A', 良好: '#FFA726', 尚可: '#EF5350' };
const bg = () => el('rect', { x: 0, y: 0, width: U.W, height: U.H, fill: C.stage });

function fadeSlide(t, content, { dy = 10, dur = 0.38 } = {}) {
  return motion({ o: [[t, 0], [t + dur, 1, 'out']], t: [[t, [0, dy]], [t + dur + 0.1, [0, 0], 'emph']] }, content);
}

function field(y, label, value, { h = 58 } = {}) {
  return [
    text(label, { x: 20, y: y - 10, size: 13, weight: 600, fill: C.muted }),
    rrect(16, y, 370, h - 12, 14, { fill: C.card, stroke: C.border, 'stroke-width': 1 }),
    value ? text(value, { x: 32, y: y + (h - 12) / 2 + 5.5, size: 15, fill: C.text }) : '',
  ];
}

function sellPage() {
  const photos = [
    ['#4F7A63', '#E7D9B8'],
    ['#5C8870', '#EFE6D0'],
    ['#476F5A', '#E2D3B0'],
  ];
  return [
    bg(),
    U.header('上架書籍', { iconName: null }),
    text('書況照片', { x: 20, y: 150, size: 13, weight: 600, fill: C.muted }),
    photos.map(([c1, c2], i) => g({}, rrect(16 + i * 124, 162, 114, 114, 14, { fill: '#DDE3E7' }), U.bookCover(16 + i * 124 + 22, 172, 70, 94, 4, { color: c1, accent: c2 }))),
    field(318, '書名', '統計學概論'),
    field(390, '書況', ''),
    field(462, '售價', ''),
    rrect(16, 520, 370, 50, 14, { fill: C.brand, 'fill-opacity': 0.08, stroke: C.brand, 'stroke-opacity': 0.35, 'stroke-width': 1 }),
    icon('sparkle', 32, 535.5, 19, C.brand),
    text('AI 帶入', { x: 60, y: 550, size: 14, weight: 700, fill: C.brand }),
    U.homeIndicator(),
  ];
}

function tag(x, y, label, color) {
  const w = measure(label, 10, { weight: 600 }) + 12;
  return g({}, rrect(x, y - 11, w, 16, 5, { fill: color, 'fill-opacity': 0.12 }), text(label, { x: x + 6, y: y + 0.5, size: 10, weight: 600, fill: color }));
}

function checkbox(x, y) {
  return [rrect(x, y, 18, 18, 5, { fill: C.brand }), el('path', { d: `M${x + 4} ${y + 9.2}l3.6 3.6 6.6-6.8`, fill: 'none', stroke: '#FFFFFF', 'stroke-width': 2, 'stroke-linecap': 'round', 'stroke-linejoin': 'round' })];
}

// 分析與建議是同一張底部面板：分析完成後面板往上展開成建議清單，不另外換頁。
const SHEET = { low: 540, high: 118 };

function assistSheet(t0, t1, { steps: stepTimes, doneAt, expand, tap }) {
  const top = SHEET.high;
  const lift = SHEET.low - SHEET.high;
  const fadeOut = [[expand, 1], [expand + 0.2, 0, 'out']];

  const labels = ['查詢書籍資料', '搜尋網路資料', '分析照片', '判斷分類、書況與售價'];
  const rows = labels.map((label, i) => {
    const y = top + 88 + i * 36;
    const done = stepTimes[i];
    const start = i === 0 ? t0 + 0.3 : stepTimes[i - 1];
    return [
      el('circle', { cx: 35, cy: y - 5, r: 9, fill: 'none', stroke: C.hint, 'stroke-width': 2, opacity: 1 }, anim('opacity', [[start, 1], [start + 0.1, 0, 'lin']])),
      g({ opacity: 0 }, anim('opacity', [[start, 0], [start + 0.1, 1, 'lin'], [done, 1, 'lin'], [done + 0.1, 0, 'lin']]), U.spinner(35, y - 5, 7.5, 2.2, C.brand, start, done + 0.2)),
      motion({ o: [[done, 0], [done + 0.15, 1, 'out']], s: [[done, 0.4], [done + 0.35, 1, 'emph']], origin: [35, y - 5] }, el('circle', { cx: 35, cy: y - 5, r: 11, fill: C.success }), el('path', { d: `M${29.5} ${y - 5}l3.8 3.8 7-7.2`, fill: 'none', stroke: '#FFFFFF', 'stroke-width': 2.2, 'stroke-linecap': 'round', 'stroke-linejoin': 'round' })),
      motion({ fill: [[t0, C.hint], [start, C.hint, 'lin'], [start + 0.2, C.text, 'out']] }, text(label, { x: 58, y, size: 14.5, weight: 500, fill: null })),
    ];
  });
  const title = (label, o) => motion({ o }, text(label, { x: 60, y: top + 45, size: 17, weight: 700, fill: C.text }));
  const head = [
    motion({ s: [[t0, 1], [t0 + 0.7, 1.15, 'soft'], [t0 + 1.4, 1, 'soft'], [t0 + 2.1, 1.15, 'soft'], [doneAt, 1, 'soft']], origin: [36, top + 38] }, icon('sparkle', 24, top + 26, 24, C.brand)),
    title('AI 分析中', [[t0, 1], [doneAt - 0.12, 1, 'lin'], [doneAt, 0, 'lin']]),
    title('分析完成', [[doneAt - 0.06, 0], [doneAt + 0.1, 1, 'out'], [expand, 1, 'lin'], [expand + 0.1, 0, 'lin']]),
    title('AI 建議', [[expand + 0.1, 0], [expand + 0.3, 1, 'out']]),
  ];
  const sheet = motion(
    { t: [[t0, [0, lift + 340]], [t0 + 0.5, [0, lift], 'emph'], [expand, [0, lift], 'lin'], [expand + 0.55, [0, 0], 'emph']] },
    el('path', { d: `M0 ${top + 20}Q0 ${top} 20 ${top}H${U.W - 20}Q${U.W} ${top} ${U.W} ${top + 20}V${U.H + lift + 340}H0Z`, fill: C.card }),
    el('rect', { x: U.W / 2 - 18, y: top + 10, width: 36, height: 4, rx: 2, fill: C.divider }),
    head,
    motion({ o: fadeOut }, rows, rrect(24, top + 250, 354, 46, 14, { fill: C.inputFill }), text('取消', { x: U.W / 2, y: top + 279, size: 15, weight: 600, fill: C.muted, anchor: 'middle' }))
  );

  let y = top + 60;
  const parts = [];
  let n = 0;
  const at = () => expand + 0.2 + n++ * 0.045;
  const section = (label) => {
    parts.push(fadeSlide(at(), text(label, { x: 20, y: y + 14, size: 12.5, weight: 700, fill: C.muted, ls: 0.04 })));
    y += 26;
  };
  const tile = (h, content) => {
    const yy = y;
    parts.push(fadeSlide(at(), [rrect(16, yy, 370, h, 14, { fill: C.cardAlt, stroke: C.border, 'stroke-width': 1 }), checkbox(30, yy + 14), content(yy)]));
    y += h + 8;
  };
  section('書籍資料');
  [['作者', '林志明'], ['出版社', '智識出版'], ['出版日期', '2022 年 2 月']].forEach(([k, v]) =>
    tile(48, (yy) => [text(k, { x: 60, y: yy + 29, size: 12.5, weight: 600, fill: C.muted }), text(v, { x: 128, y: yy + 29, size: 14.5, weight: 600, fill: C.text }), tag(292, yy + 25, '依 ISBN 書目補齊', C.muted)])
  );
  section('分類');
  tile(46, (yy) => text('統計學', { x: 60, y: yy + 28, size: 14.5, weight: 600, fill: C.text }));
  section('書況');
  tile(92, (yy) => [
    text('近全新', { x: 60, y: yy + 30, size: 16, weight: 700, fill: COND.近全新 }),
    text('・書頁無劃線與摺痕', { x: 60, y: yy + 55, size: 12.5, fill: C.muted }),
    text('・封面邊角輕微磨損', { x: 60, y: yy + 75, size: 12.5, fill: C.muted }),
  ]);
  section('建議售價');
  tile(70, (yy) => [text('$280', { x: 60, y: yy + 32, size: 20, weight: 800, fill: C.brand }), text('建議區間 $240–$320・定價 $620', { x: 60, y: yy + 55, size: 12.5, fill: C.muted })]);
  section('資料來源');
  ['Google Books', 'Open Library'].forEach((label) => {
    parts.push(fadeSlide(at(), [icon('link', 22, y + 2, 16, C.hint), text(label, { x: 46, y: y + 15, size: 13, fill: C.text }), icon('openInNew', 364, y + 3, 14, C.hint)]));
    y += 26;
  });
  const footerY = U.H - 34 - 66;
  const footer = fadeSlide(expand + 0.24, [
    el('rect', { x: 0, y: footerY - 10, width: U.W, height: 1, fill: C.divider }),
    rrect(16, footerY, 118, 46, 14, { fill: C.inputFill }),
    text('取消', { x: 75, y: footerY + 29, size: 15, weight: 600, fill: C.muted, anchor: 'middle' }),
    U.primaryButton(144, footerY - 1, 242, '套用 5 項', { press: tap }),
  ], { dy: 8 });

  return U.switchIn(t0, t1, [
    sellPage(),
    el('rect', { x: 0, y: 0, width: U.W, height: U.H, fill: '#000000', opacity: 0.45 }),
    statusBar('#FFFFFF'),
    sheet,
    parts,
    footer,
    U.touch(265, footerY + 23, tap),
    U.homeIndicator(),
  ], { dur: 0.3, slide: 0 });
}

function bookCard(x, y, w, book, { t, reason } = {}) {
  const imgH = w * 0.95;
  const h = imgH + 74 + (reason ? 16 : 0);
  const content = [
    rrect(x, y, w, h, 14, { fill: C.card }),
    g({}, el('rect', { x, y, width: w, height: imgH, fill: '#E3E8EC', rx: 14 }), el('rect', { x, y: y + imgH - 14, width: w, height: 14, fill: '#E3E8EC' })),
    U.bookCover(x + w * 0.24, y + imgH * 0.12, w * 0.52, imgH * 0.76, 3, book),
    text(ellipsize(book.title, 12.5, w - 20, { weight: 700 }), { x: x + 10, y: y + imgH + 21, size: 12.5, weight: 700, fill: C.text }),
    reason ? text(ellipsize(reason, 10, w - 20), { x: x + 10, y: y + imgH + 38, size: 10, fill: C.muted }) : '',
    text(`$${book.price}`, { x: x + 10, y: y + h - 13, size: 15, weight: 900, fill: C.brand }),
    text(book.cond, { x: x + w - 10, y: y + h - 14, size: 10.5, weight: 600, fill: COND[book.cond], anchor: 'end' }),
  ];
  return t === undefined ? g({}, content) : fadeSlide(t, content, { dy: 14 });
}

const BOOKS = {
  stats2: { title: '機率與統計', price: 240, cond: '近全新', color: '#3E6A9E', accent: '#E9EEF1' },
  regress: { title: '迴歸分析實務', price: 300, cond: '良好', color: '#A45F4B', accent: '#F1E3C8' },
  data: { title: '資料分析入門', price: 260, cond: '全新', color: '#4F7A63', accent: '#E7D9B8' },
  exam1: { title: '統計學考前總複習', price: 180, cond: '良好', color: '#A7792C', accent: '#FBEFD5' },
  exam2: { title: '經濟學歷屆試題', price: 200, cond: '近全新', color: '#75689C', accent: '#EDE7F6' },
  exam3: { title: '會計學重點整理', price: 160, cond: '尚可', color: '#9E5A76', accent: '#F6E4EC' },
  py: { title: 'Python 程式設計入門', price: 260, cond: '近全新', color: '#3E6A9E', accent: '#E9EEF1' },
  ds: { title: '資料結構與演算法', price: 220, cond: '良好', color: '#4B5563', accent: '#E5E7EB' },
  web: { title: '網頁設計入門', price: 180, cond: '全新', color: '#4F7A63', accent: '#E7D9B8' },
};

function homeHeader() {
  const h = 59 + 8 + 30 + 20 + 44 + 20;
  const d = `M0 0H${U.W}V${h - 24}Q${U.W} ${h} ${U.W - 24} ${h}H24Q0 ${h} 0 ${h - 24}Z`;
  return {
    h,
    markup: g(
      {},
      el('path', { d, fill: C.brand }),
      statusBar('#FFFFFF'),
      text('您好，海嫄', { x: 16, y: 59 + 8 + 24, size: 22, weight: 700, fill: '#FFFFFF' }),
      icon('cart', U.W - 80, 70, 26, '#FFFFFF'),
      icon('chat', U.W - 44, 72, 24, '#FFFFFF'),
      rrect(16, 59 + 8 + 30 + 20, 370, 44, 12, { fill: C.card }),
      icon('search', 30, 59 + 8 + 30 + 20 + 11, 22, C.hint),
      text('搜尋書名、作者或 ISBN', { x: 60, y: 59 + 8 + 30 + 20 + 28, size: 15, fill: C.hint })
    ),
  };
}

function bottomNav(selected = 0) {
  const y = U.H - 34 - 4 - 56;
  const x = 20;
  const w = U.W - 40;
  const slot = w / 5;
  const items = [['home', '首頁'], ['bell', '通知'], null, ['qrScanner', '取書'], ['person', '會員']];
  const id = nextId('bn');
  return g(
    {},
    rrect(x + 6, y + 10, w - 12, 56, 28, { fill: '#0B1A26', 'fill-opacity': 0.12, filter: blurFilter(`${id}b`, 10) }),
    rrect(x, y, w, 56, 28, { fill: '#FFFFFF', 'fill-opacity': 0.9, stroke: '#FFFFFF', 'stroke-width': 1 }),
    rrect(x + slot * selected + (slot - 52) / 2, y + 5, 52, 46, 23, { fill: C.brand, 'fill-opacity': 0.12 }),
    items.map((it, i) => {
      const cx = x + slot * i + slot / 2;
      if (!it) return [el('circle', { cx, cy: y + 28, r: 20, fill: C.brand }), icon('add', cx - 12, y + 16, 24, '#FFFFFF')];
      const col = i === selected ? C.brand : C.iconInactive;
      return [icon(it[0], cx - 11, y + 8, 22, col), text(it[1], { x: cx, y: y + 46, size: 10.5, weight: i === selected ? 700 : 500, fill: col, anchor: 'middle' })];
    })
  );
}

function home(t0, t1, rowsAt = t0) {
  const hdr = homeHeader();
  const chips = ['全部書籍', '考試用書', '統計學', '程式設計', '文學小說'];
  let cx = 16;
  const chipEls = chips.map((c, i) => {
    const w = measure(c, 13, { weight: 600 }) + 24;
    const x = cx;
    cx += w + 8;
    return fadeSlide(t0 + 0.15 + i * 0.045, [rrect(x, hdr.h + 14, w, 32, 16, { fill: i === 0 ? C.brand : C.brandSoft }), text(c, { x: x + 12, y: hdr.h + 35, size: 13, weight: 600, fill: i === 0 ? '#FFFFFF' : C.text })]);
  });
  const y0 = hdr.h + 76;
  const cardW = 116;
  const rows = [
    ['與已收藏的《統計學概論》相關', [BOOKS.stats2, BOOKS.regress, BOOKS.data]],
    ['「考試用書」類別推薦', [BOOKS.exam1, BOOKS.exam2, BOOKS.exam3]],
  ];
  const rowEls = rows.map(([title, books], r) => {
    const y = y0 + 28 + r * 238;
    const tt = rowsAt + 0.35 + r * 0.35;
    return [
      fadeSlide(tt, text(title, { x: 16, y, size: 14, weight: 700, fill: C.text })),
      books.map((b, i) => bookCard(16 + i * (cardW + 11), y + 12, cardW, b, { t: tt + 0.1 + i * 0.045 })),
    ];
  });
  return U.switchIn(t0, t1, [
    bg(),
    hdr.markup,
    chipEls,
    fadeSlide(t0 + 0.25, [text('為您推薦', { x: 16, y: y0, size: 18, weight: 800, fill: C.text }), icon('sparkle', 104, y0 - 18, 18, C.brand)]),
    rowEls,
    bottomNav(0),
    U.homeIndicator(),
  ], { dur: 0.35, slide: 0 });
}

function chatHeader(title, iconName) {
  return U.header(title, { iconName });
}

function bubbleUser(y, lines, t) {
  const w = Math.max(...lines.map((l) => measure(l, 15))) + 28;
  const h = 18 + lines.length * 22;
  const x = U.W - 16 - w;
  return fadeSlide(t, [rrect(x, y, w, h, 18, { fill: C.brand }), lines.map((l, i) => text(l, { x: x + 14, y: y + 26 + i * 22, size: 15, fill: '#FFFFFF' }))], { dy: 16 });
}

function avatar(x, y) {
  return [el('circle', { cx: x + 15, cy: y + 15, r: 15, fill: C.brand, 'fill-opacity': 0.14 }), icon('sparkle', x + 6, y + 6, 18, C.brand)];
}

function bubbleAi(y, lines, t, { w } = {}) {
  const ww = w || Math.max(...lines.map((l) => measure(l, 15))) + 28;
  const h = 18 + lines.length * 22.5;
  return fadeSlide(t, [avatar(16, y), rrect(54, y, ww, h, 18, { fill: C.card }), lines.map((l, i) => text(l, { x: 68, y: y + 26 + i * 22.5, size: 15, fill: C.text }))], { dy: 16 });
}

function typing(y, t0, t1) {
  const dots = [0, 1, 2].map((i) =>
    el('circle', { cx: 76 + i * 13, cy: y + 20, r: 4, fill: C.hint }, el('animate', { attributeName: 'opacity', values: '0.3;1;0.3', dur: '0.9s', begin: T(t0 + i * 0.15), end: T(t1), repeatCount: 'indefinite' }))
  );
  return g({ display: 'none' }, during(t0, t1), avatar(16, y), rrect(54, y, 70, 40, 18, { fill: C.card }), dots);
}

function inputBar(placeholder, { typed, typeAt, sendAt } = {}) {
  const y = U.H - 34 - 8 - 48;
  const items = [
    el('rect', { x: 0, y: y - 10, width: U.W, height: U.H - y + 10, fill: C.card }),
    rrect(16, y, 318, 48, 24, { fill: C.inputFill }),
    el('circle', { cx: 362, cy: y + 24, r: 22, fill: C.brand }),
    icon('send', 351, y + 13, 22, '#FFFFFF'),
  ];
  if (typed) {
    const chars = [...typed];
    const per = (sendAt - 0.2 - typeAt) / chars.length;
    items.push(g({ display: 'none' }, during(0, typeAt), text(placeholder, { x: 34, y: y + 30, size: 15, fill: C.hint })));
    const clipId = nextId('ib');
    require('./core').addDef(el('clipPath', { id: clipId }, el('rect', { x: 30, y, width: 292, height: 48 })));
    const full = measure(typed, 15);
    const overflow = Math.max(0, full - 276);
    const shift = overflow > 0 ? { t: [[typeAt + (chars.length - Math.ceil(overflow / 15) - 2) * per, [0, 0]], [sendAt - 0.2, [-overflow, 0], 'lin']] } : {};
    items.push(
      g(
        { display: 'none', 'clip-path': `url(#${clipId})` },
        during(typeAt, sendAt),
        motion(
          shift,
          text(typed, {
            x: 34,
            y: y + 30,
            size: 15,
            fill: C.text,
            perChar: (n) => ({ o: [[typeAt + n * per, 0], [typeAt + n * per + 0.02, 1, 'lin']] }),
          })
        )
      )
    );
    items.push(g({ display: 'none' }, el('set', { attributeName: 'display', to: 'inline', begin: T(sendAt), fill: 'freeze' }), text(placeholder, { x: 34, y: y + 30, size: 15, fill: C.hint })));
  } else {
    items.push(text(placeholder, { x: 34, y: y + 30, size: 15, fill: C.hint }));
  }
  return items;
}

function advisor(t0, t1, tm) {
  const chips = ['200 代幣以內的書籍', '適合入門的程式設計書', '最近熱門的文學小說'];
  const chipEls = chips.map((c, i) => {
    const w = measure(c, 13.5, { weight: 500 }) + 28;
    return fadeSlide(t0 + 0.3 + i * 0.06, [rrect(68, 216 + i * 44, w, 34, 17, { fill: C.card, stroke: C.border, 'stroke-width': 1 }), text(c, { x: 82, y: 238 + i * 44, size: 13.5, weight: 500, fill: C.text })]);
  });
  const greet = bubbleAi(134, ['描述您想找的書籍，', '我會從站內挑選適合的書。'], t0 + 0.2);
  const intro = g({ display: 'none' }, during(t0, tm.send + 0.3), greet, chipEls);
  const user = bubbleUser(140, ['想找適合入門的程式設計書，', '預算 300 代幣以內'], tm.send);
  const reply = bubbleAi(238, ['以下是符合條件的書籍：'], tm.reply);
  const cards = [BOOKS.py, BOOKS.ds, BOOKS.web].map((b, i) => bookCard(54 + i * 116, 296, 108, b, { t: tm.reply + 0.2 + i * 0.07, reason: ['範例由淺入深', '附習題解說', '適合零基礎'][i] }));
  const feedback = fadeSlide(tm.reply + 0.6, [
    rrect(54, 510, 108, 34, 17, { fill: C.card, stroke: C.border, 'stroke-width': 1 }),
    motion({ fill: [[tm.thumb, C.muted], [tm.thumb + 0.2, C.brand, 'out']] }, icon('thumbUp', 66, 518, 18, null), text('有幫助', { x: 90, y: 532, size: 13, weight: 600, fill: null })),
    rrect(170, 510, 122, 34, 17, { fill: C.card, stroke: C.border, 'stroke-width': 1 }),
    icon('thumbDown', 182, 519, 18, C.muted),
    text('沒有幫助', { x: 206, y: 532, size: 13, weight: 600, fill: C.muted }),
    motion({ o: [[tm.thumb, 0], [tm.thumb + 0.2, 1, 'out']] }, rrect(54, 510, 108, 34, 17, { fill: C.brand, 'fill-opacity': 0.1, stroke: C.brand, 'stroke-width': 1.2 })),
    U.touch(108, 527, tm.thumb),
  ]);
  return U.switchIn(t0, t1, [
    bg(),
    chatHeader('AI 書籍顧問', 'sparkle'),
    intro,
    user,
    typing(238, tm.send + 0.45, tm.reply),
    reply,
    cards,
    feedback,
    inputBar('描述您想找的書籍', { typed: '想找適合入門的程式設計書，預算 300 代幣以內', typeAt: tm.typeAt, sendAt: tm.send }),
    U.homeIndicator(),
  ], { dur: 0.35 });
}

function support(t0, t1, tm) {
  const quick = ['如何上架書籍？', '如何至書櫃取書？', '如何申請退款？', '代幣如何使用？'];
  const chipEls = quick.map((c, i) => {
    const w = measure(c, 13.5, { weight: 500 }) + 28;
    const col = i % 2;
    const row = Math.floor(i / 2);
    return fadeSlide(t0 + 0.3 + i * 0.05, [rrect(68 + col * 160, 196 + row * 44, w, 34, 17, { fill: C.card, stroke: C.border, 'stroke-width': 1 }), text(c, { x: 82 + col * 160, y: 218 + row * 44, size: 13.5, weight: 500, fill: C.text })]);
  });
  const greet = bubbleAi(136, ['請問有什麼需要協助的地方？'], t0 + 0.2);
  const user = bubbleUser(300, ['賣出的書什麼時候撥款？'], tm.send);
  const answer = bubbleAi(372, ['買家完成訂單，或取書滿 24 小時', '未申請爭議時，款項即撥入您的', '錢包。'], tm.reply, { w: 290 });
  const handoff = fadeSlide(tm.reply + 0.5, [
    rrect(54, 470, 150, 36, 18, { fill: C.card, stroke: C.brand, 'stroke-width': 1.4 }),
    icon('headset', 66, 479, 18, C.brand),
    text('轉接客服人員', { x: 90, y: 493, size: 13.5, weight: 700, fill: C.brand }),
    el('rect', { x: 54, y: 470, width: 150, height: 36, rx: 18, fill: 'none', stroke: C.brand, 'stroke-width': 2, opacity: 0 }, anim('opacity', [[tm.reply + 1.0, 0], [tm.reply + 1.2, 0.6, 'out'], [tm.reply + 1.9, 0, 'out']])),
    text('AI 回覆僅供參考，實際以訂單頁面與客服人員說明為準', { x: 54, y: 530, size: 10.5, fill: C.hint }),
  ]);
  return U.switchIn(t0, t1, [
    bg(),
    chatHeader('AI 客服', 'headset'),
    greet,
    chipEls,
    user,
    typing(372, tm.send + 0.45, tm.reply),
    answer,
    handoff,
    inputBar('輸入問題'),
    U.homeIndicator(),
  ], { dur: 0.35 });
}

module.exports = { COND, BOOKS, sellPage, assistSheet, home, advisor, support, bookCard };
