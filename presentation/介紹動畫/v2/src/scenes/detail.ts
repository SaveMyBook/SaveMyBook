import { span, lerp, clamp, easeOut, easeInOut } from '../lib/kf';
import { el, css } from '../lib/ui';

/**
 * 手機旁的圖解（比照第一版）：資料來源、照片分析、語意向量、需求拆解、驗證方式、客服檢索、爭議比對。
 * 一律放在畫面左側（x 為左緣、y 為中線），以 at(t, t0, t1, …) 控制進出場；內容文字取自 App 的實際資料。
 */

function show(root: HTMLElement, t: number, t0: number, t1: number, x: number, y: number) {
  const a = easeOut(span(t, t0, t0 + 0.5));
  const b = easeInOut(span(t, t1, t1 + 0.35));
  const k = a * (1 - b);
  css(root, 'visibility', k > 0.001 ? 'visible' : 'hidden');
  css(root, 'opacity', k.toFixed(3));
  css(root, 'transform', `translate(${x}px, ${(y + (1 - a) * 18 - b * 10).toFixed(1)}px) translateY(-50%)`);
  return k > 0.001;
}

/** 逐項完成的清單列：未開始為灰圈、進行中為轉圈、完成為綠勾。 */
function rowState(li: HTMLElement, t: number, start: number, done: number) {
  li.classList.toggle('is-active', t >= start && t < done);
  li.classList.toggle('is-done', t >= done);
  if (t >= start && t < done) css(li, '--spin', `${(((t - start) * 1.6) % 1) * 360}deg`);
}

/** 依序查詢的資料來源（上架第 1 步按下 AI 帶入後）。 */
export class Pipeline {
  readonly root: HTMLElement;
  private rows: HTMLElement[];
  constructor(parent: HTMLElement) {
    this.root = el('div', 'dcard dsteps', parent, '<p class="dcard__title">查詢書目</p>');
    const ol = el('ol', '', this.root);
    this.rows = [
      ['Google Books', '書名、作者、出版社'],
      ['Open Library', '補上缺少的欄位'],
      ['網路搜尋', '出版日期與頁數'],
      ['AI 整理', '寫成繁體中文簡介'],
    ].map(([b, s]) => el('li', '', ol, `<i></i><b>${b}</b><span>${s}</span>`));
  }
  at(t: number, t0: number, t1: number, done: number[], x: number, y: number) {
    if (!show(this.root, t, t0, t1, x, y)) return;
    this.rows.forEach((li, i) => rowState(li, t, i === 0 ? t0 + 0.15 : done[i - 1], done[i]));
  }
}

/** 照片分析：三張書況照片掃描，並依序完成查詢與判斷（上架第 2 步按下 AI 帶入後）。 */
export class PhotoScan {
  readonly root: HTMLElement;
  private rows: HTMLElement[];
  private scan: HTMLElement;
  constructor(parent: HTMLElement) {
    this.root = el('div', 'dcard dphoto', parent, '<p class="dcard__title">分析書況照片</p>');
    const strip = el('div', 'dphoto__strip', this.root);
    // 縮圖取自 App 截圖（邏輯座標 → 3 倍圖，縮放 0.5）
    // 上緣裁掉 26pt，不露出 App 縮圖右上角的刪除鈕
    for (const [img, x, label] of [['s_sell_photos', 34.7, '封面'], ['s_sell_photos', 136, '封底'], ['s_sell_photos_inner', 160, '內頁']] as const) {
      const f = el('figure', 'dphoto__thumb', strip);
      css(f, 'background-image', `url(/screens/${img}.webp)`);
      css(f, 'background-position', `${(-x * 1.5).toFixed(1)}px ${(-(187.7 + 26) * 1.5).toFixed(1)}px`);
      el('figcaption', '', f, label);
    }
    this.scan = el('i', 'dphoto__scan', strip);
    const ol = el('ol', 'dsteps__list', this.root);
    this.rows = ['查詢書目資料', '查詢網路行情', '判斷書況', '計算建議售價'].map((b) => el('li', '', ol, `<i></i><b>${b}</b>`));
  }
  at(t: number, t0: number, t1: number, done: number[], x: number, y: number) {
    if (!show(this.root, t, t0, t1, x, y)) return;
    this.rows.forEach((li, i) => rowState(li, t, i === 0 ? t0 + 0.15 : done[i - 1], done[i]));
    const k = span(t, t0 + 0.3, done[2]);
    css(this.scan, 'opacity', (k > 0 && k < 1 ? 1 : 0).toFixed(2));
    css(this.scan, 'transform', `translateX(${(k * 420).toFixed(1)}px)`);
  }
}

/** 語意向量空間：已收藏的書連到相近的書（個人化推薦）。 */
export class VectorSpace {
  readonly root: HTMLElement;
  private lines: SVGLineElement[] = [];
  private nodes: SVGGElement[] = [];
  constructor(parent: HTMLElement) {
    this.root = el('div', 'dcard dvec', parent, '<p class="dcard__title">語意向量空間</p><p class="dcard__note">依收藏、購物車與瀏覽紀錄比對</p>');
    const NS = 'http://www.w3.org/2000/svg';
    const svg = document.createElementNS(NS, 'svg');
    svg.setAttribute('viewBox', '0 0 420 230');
    svg.setAttribute('class', 'dvec__svg');
    this.root.append(svg);
    let seed = 5;
    const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
    for (let i = 0; i < 46; i++) {
      const c = document.createElementNS(NS, 'circle');
      c.setAttribute('cx', (14 + rnd() * 392).toFixed(1));
      c.setAttribute('cy', (12 + rnd() * 206).toFixed(1));
      c.setAttribute('r', (2 + rnd() * 2.2).toFixed(1));
      c.setAttribute('class', 'dvec__dot');
      svg.append(c);
    }
    const C = [190, 120];
    const N: [number, number, string][] = [[330, 62, '普通化學'], [318, 186, '觀念化學2'], [70, 176, '普通化學實驗']];
    for (const [x, y] of N) {
      const l = document.createElementNS(NS, 'line');
      l.setAttribute('x1', String(C[0])); l.setAttribute('y1', String(C[1]));
      l.setAttribute('x2', String(x)); l.setAttribute('y2', String(y));
      l.setAttribute('class', 'dvec__line');
      svg.append(l);
      this.lines.push(l);
    }
    const node = (x: number, y: number, label: string, main: boolean) => {
      const g = document.createElementNS(NS, 'g');
      g.setAttribute('class', main ? 'dvec__node dvec__node--main' : 'dvec__node');
      const c = document.createElementNS(NS, 'circle');
      c.setAttribute('cx', String(x)); c.setAttribute('cy', String(y)); c.setAttribute('r', main ? '9' : '7');
      const tx = document.createElementNS(NS, 'text');
      tx.setAttribute('x', String(x)); tx.setAttribute('y', String(y - 16)); tx.setAttribute('text-anchor', 'middle');
      tx.textContent = label;
      g.append(c, tx);
      svg.append(g);
      return g;
    };
    this.nodes.push(node(C[0], C[1], '已收藏《觀念化學1》', true));
    for (const [x, y, label] of N) this.nodes.push(node(x, y, label, false));
  }
  at(t: number, t0: number, t1: number, x: number, y: number) {
    if (!show(this.root, t, t0, t1, x, y)) return;
    css(this.nodes[0] as unknown as HTMLElement, 'opacity', easeOut(span(t, t0 + 0.2, t0 + 0.5)).toFixed(3));
    this.lines.forEach((l, i) => {
      const k = easeInOut(span(t, t0 + 0.5 + i * 0.25, t0 + 0.9 + i * 0.25));
      const len = 160;
      l.setAttribute('stroke-dasharray', `${len}`);
      l.setAttribute('stroke-dashoffset', ((1 - k) * len).toFixed(1));
      css(this.nodes[i + 1] as unknown as HTMLElement, 'opacity', easeOut(span(t, t0 + 0.8 + i * 0.25, t0 + 1.1 + i * 0.25)).toFixed(3));
    });
  }
}

/** 把使用者的需求拆成條件（AI 書籍顧問）。 */
export class Conditions {
  readonly root: HTMLElement;
  private marks: HTMLElement[];
  private chips: HTMLElement[];
  constructor(parent: HTMLElement) {
    this.root = el('div', 'dcard dcond', parent);
    el('p', 'dcard__title', this.root, '使用者需求');
    const q = el('p', 'dcond__quote', this.root);
    q.innerHTML = '我想找<u>普通化學</u>的<u>入門書</u>，要能解釋像 <u>Fe3O4</u> 這類化合物，<u>預算 300 代幣以內</u>。';
    this.marks = [...q.querySelectorAll<HTMLElement>('u')];
    const list = el('div', 'dcond__chips', this.root);
    this.chips = [
      ['分類', '普通化學'], ['程度', '入門'], ['需求', '能解釋 Fe3O4'], ['預算', '300 代幣以內'], ['排除', '他人保留中的書'],
    ].map(([k, v]) => el('span', 'dcond__chip', list, `<b>${k}</b>${v}`));
    this.chips.push(el('span', 'dcond__chip dcond__chip--ok', list, '<i></i>找到 2 本站內可購買的書'));
  }
  at(t: number, t0: number, t1: number, okAt: number, x: number, y: number) {
    if (!show(this.root, t, t0, t1, x, y)) return;
    this.marks.forEach((u, i) => u.classList.toggle('is-on', t >= t0 + 0.35 + i * 0.22));
    this.chips.forEach((c, i) => {
      const at = i < this.chips.length - 1 ? t0 + 0.6 + i * 0.22 : okAt;
      const k = easeOut(span(t, at, at + 0.35));
      css(c, 'opacity', k.toFixed(3));
      css(c, 'transform', `translateY(${((1 - k) * 10).toFixed(1)}px)`);
    });
  }
}

/** 付款前的驗證方式：交易密碼、生物辨識、通行密鑰。 */
export class Methods {
  readonly root: HTMLElement;
  private rows: HTMLElement[];
  private ok: HTMLElement;
  constructor(parent: HTMLElement) {
    this.root = el('div', 'dmethods', parent, '<p class="dcard__eyebrow">付款前再驗證一次</p>');
    this.rows = [
      ['lock', '交易密碼', '結帳時輸入 6 位數字'],
      ['face', '生物辨識付款', '以 Face ID 或指紋取代交易密碼'],
      ['key', '通行密鑰登入', '「海嫄的 iPhone」免輸入密碼'],
    ].map(([ic, b, s]) => el('div', `dmethods__row dmethods__row--${ic}`, this.root, `<i></i><p><b>${b}</b><span>${s}</span></p>`));
    this.ok = el('p', 'dmethods__ok', this.root, '<i></i>付款成功，款項由平台暫管');
  }
  at(t: number, t0: number, t1: number, active: number, okAt: number, x: number, y: number) {
    if (!show(this.root, t, t0, t1, x, y)) return;
    this.rows.forEach((r, i) => {
      const k = easeOut(span(t, t0 + 0.15 + i * 0.15, t0 + 0.55 + i * 0.15));
      css(r, 'opacity', k.toFixed(3));
      css(r, 'transform', `translateX(${((1 - k) * -16).toFixed(1)}px)`);
      r.classList.toggle('is-on', i === 0 && t >= active);
    });
    const k = easeOut(span(t, okAt, okAt + 0.4));
    css(this.ok, 'opacity', k.toFixed(3));
    css(this.ok, 'transform', `translateY(${((1 - k) * 10).toFixed(1)}px)`);
  }
}

/** AI 客服的檢索：關鍵字與語意檢索找出相關段落。 */
export class Retrieval {
  readonly root: HTMLElement;
  private docs: HTMLElement[];
  private found: HTMLElement;
  private tabs: HTMLElement[];
  constructor(parent: HTMLElement) {
    this.root = el('div', 'dcard dret', parent);
    const tabs = el('div', 'dret__tabs', this.root);
    this.tabs = ['關鍵字檢索', '語意檢索'].map((s) => el('span', '', tabs, s));
    const stack = el('div', 'dret__docs', this.root);
    this.docs = ['常見問題', '服務條款', '書櫃使用說明', '隱私權政策', '我的訂單'].map((s) => el('p', '', stack, `<i></i>${s}`));
    this.found = el('p', 'dret__found', this.root, '<b>找到相關段落</b>存書後 7 天內，於開放時間掃碼取書');
  }
  at(t: number, t0: number, t1: number, hit: number, x: number, y: number) {
    if (!show(this.root, t, t0, t1, x, y)) return;
    this.tabs.forEach((s, i) => s.classList.toggle('is-on', t >= t0 + 0.2 + i * 0.2));
    const sweep = span(t, t0 + 0.5, hit);
    this.docs.forEach((d, i) => {
      const cur = sweep > 0 && sweep < 1 && Math.floor(sweep * this.docs.length) === i;
      d.classList.toggle('is-scan', cur);
      d.classList.toggle('is-hit', t >= hit && (i === 2 || i === 4));
      d.classList.toggle('is-dim', t >= hit && i !== 2 && i !== 4);
    });
    const k = easeOut(span(t, hit + 0.1, hit + 0.5));
    css(this.found, 'opacity', k.toFixed(3));
    css(this.found, 'transform', `translateY(${((1 - k) * 10).toFixed(1)}px)`);
  }
}

/** 爭議比對：上架資料與爭議說明交給 AI 分析，得出建議與可信度。 */
export class Compare {
  readonly root: HTMLElement;
  private cards: HTMLElement[];
  private ai: HTMLElement;
  private res: HTMLElement;
  private wires: HTMLElement[];
  constructor(parent: HTMLElement) {
    this.root = el('div', 'dcmp', parent);
    this.cards = [
      ['上架資料', '描述「近全新、內頁無畫線」', '照片 3 張：封面、封底、內頁'],
      ['爭議說明', '多個章節有大量畫線與筆記', '佐證照片 2 張'],
    ].map(([h, b, s]) => el('div', 'dcard dcmp__card', this.root, `<p class="dcard__title">${h}</p><p class="dcmp__body">${b}</p><p class="dcard__note">${s}</p>`));
    this.wires = [0, 1].map((i) => el('i', `dcmp__wire dcmp__wire--${i}`, this.root));
    this.ai = el('p', 'dcmp__ai', this.root, '<i></i>AI 分析');
    this.res = el('p', 'dcmp__res', this.root, '建議退款・可信度：中');
  }
  at(t: number, t0: number, t1: number, x: number, y: number) {
    if (!show(this.root, t, t0, t1, x, y)) return;
    this.cards.forEach((c, i) => {
      const k = easeOut(span(t, t0 + i * 0.18, t0 + 0.45 + i * 0.18));
      css(c, 'opacity', k.toFixed(3));
    });
    this.wires.forEach((w, i) => css(w, '--k', easeInOut(span(t, t0 + 0.4 + i * 0.08, t0 + 0.7 + i * 0.08)).toFixed(3)));
    const a = easeOut(span(t, t0 + 0.65, t0 + 0.9));
    css(this.ai, 'opacity', a.toFixed(3));
    this.ai.classList.toggle('is-busy', t < t0 + 1.1);
    css(this.ai, '--spin', `${(((t - t0) * 1.6) % 1) * 360}deg`);
    const r = easeOut(span(t, t0 + 1.1, t0 + 1.4));
    css(this.res, 'opacity', r.toFixed(3));
    css(this.res, 'transform', `scale(${lerp(0.92, 1, r).toFixed(3)})`);
    void clamp;
  }
}
