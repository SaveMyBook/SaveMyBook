/**
 * 版面語言（第二版，排版導向）：
 * - 不用卡片、色條、圖示方塊、膠囊標籤；層次只靠字級、字重、留白與一條細線。
 * - 左側一次只講一件事：小標（章節）→ 大標（功能，兩行內）→ 細線 → 說明一句 →（有數據時）大數字。
 * - 右側手機以鏡頭推近呈現重點區塊，畫面上不疊任何框或連線。
 * - 右上角只標章節編號與名稱。y > 930 保留給字幕。
 */
import { span, easeOut, easeInOut } from '../lib/kf';
import { el, css, Rise, fade } from '../lib/ui';
import { cue } from '../lib/cues';
import TL from '../timeline.json';
import { CHAPTERS, chapterNo, section, line } from './kit2';

export { CHAPTERS, chapterNo, section, line };

/** 右上角章節標記：「02 ─ 賣家上架」，換章時數字與名稱上下替換。 */
export class ChapterMark {
  private root: HTMLElement;
  private rows: { no: HTMLElement; name: HTMLElement; s: number; e: number }[] = [];
  constructor(parent: HTMLElement) {
    this.root = el('div', 'cmark', parent);
    el('i', 'cmark__rule', this.root);
    for (const c of CHAPTERS) {
      const s = section(c.id);
      const no = el('b', 'cmark__no', this.root, String(chapterNo(c.id)).padStart(2, '0'));
      const name = el('span', 'cmark__name', this.root, c.name);
      this.rows.push({ no, name, s: s.start, e: s.end });
    }
  }
  at(t: number) {
    const first = this.rows[0].s, last = this.rows[this.rows.length - 1].e;
    const k = easeOut(span(t, first, first + 0.6)) * (1 - easeInOut(span(t, last - 0.3, last + 0.2)));
    css(this.root, 'visibility', k > 0.001 ? 'visible' : 'hidden');
    if (k <= 0.001) return;
    css(this.root, 'opacity', k.toFixed(3));
    for (const r of this.rows) {
      const a = easeOut(span(t, r.s + 0.1, r.s + 0.6));
      const b = easeInOut(span(t, r.e - 0.1, r.e + 0.3));
      const y = (1 - a) * 26 - b * 26;
      for (const e of [r.no, r.name]) {
        css(e, 'opacity', (a * (1 - b)).toFixed(3));
        css(e, 'transform', `translateY(${y.toFixed(1)}px)`);
      }
    }
  }
}

export interface Point {
  line: string;
  /** 大標，最多兩行；用 <em> 標出石板藍的字（以 [ ] 包住）。 */
  title: [string, string?];
  body: string;
  /** 有明確數據時的大數字（例：['10', '張', '書況照片上限']）。 */
  fact?: [string, string, string];
  shift?: number;
}

const accent = (s: string) => {
  const marks: boolean[] = [];
  let on = false, out = '';
  for (const ch of s) {
    if (ch === '[') { on = true; continue; }
    if (ch === ']') { on = false; continue; }
    marks.push(on); out += ch;
  }
  return { text: out, at: (i: number) => marks[i] };
};

/** 左側重點：一次只顯示一項；旁白換句時，舊的往上收、新的由下浮出。 */
export class Points {
  private root: HTMLElement;
  private eyebrow: HTMLElement;
  private items: { t0: number; t1: number; rows: Rise[]; rule: HTMLElement; body: HTMLElement; fact: HTMLElement | null }[] = [];
  constructor(parent: HTMLElement, chapterId: string, points: Point[], readonly x = 150, readonly y = 330) {
    this.root = el('div', 'pts', parent);
    const c = CHAPTERS.find((q) => q.id === chapterId)!;
    this.eyebrow = el('p', 'pts__eyebrow', this.root, `<b>${String(chapterNo(chapterId)).padStart(2, '0')}</b>${c.name}`);
    points.forEach((p, i) => {
      const t0 = line(p.line).at + (p.shift ?? 0) - 0.15;
      const next = points[i + 1];
      const t1 = next ? line(next.line).at + (next.shift ?? 0) - 0.45 : Infinity;
      const box = el('div', 'pts__item', this.root);
      const rows = p.title.filter(Boolean).map((s) => { const a = accent(s!); return new Rise(box, a.text, 'pts__title', a.at); });
      const rule = el('i', 'pts__rule', box);
      const body = el('p', 'pts__body', box, p.body);
      const fact = p.fact ? el('p', 'pts__fact', box, `<b>${p.fact[0]}</b><small>${p.fact[1]}</small><span>${p.fact[2]}</span>`) : null;
      this.items.push({ t0, t1, rows, rule, body, fact });
      cue('textin', t0 + 0.05, { gain: 0.5 });
    });
  }
  at(t: number, tOut: number) {
    const vis = t >= this.items[0].t0 - 0.1 && t <= tOut + 0.8;
    css(this.root, 'visibility', vis ? 'visible' : 'hidden');
    if (!vis) return;
    css(this.root, 'transform', `translate(${this.x}px, ${this.y}px)`);
    fade(this.eyebrow, t, this.items[0].t0 - 0.1, tOut, 14);
    for (const it of this.items) {
      const t1 = Math.min(it.t1, tOut);
      it.rows.forEach((r, j) => {
        r.at(t, it.t0 + j * 0.08, t1);
        css(r.root, 'transform', `translateY(${j * 104}px)`);
      });
      const top = it.rows.length * 104 + 34;
      const a = easeOut(span(t, it.t0 + 0.25, it.t0 + 0.85));
      const b = easeInOut(span(t, t1, t1 + 0.35));
      css(it.rule, 'transform', `translateY(${top}px) scaleX(${(a * (1 - b)).toFixed(3)})`);
      css(it.rule, 'visibility', a * (1 - b) > 0.001 ? 'visible' : 'hidden');
      fade(it.body, t, it.t0 + 0.35, t1, 18);
      css(it.body, 'top', `${top + 30}px`);
      if (it.fact) {
        fade(it.fact, t, it.t0 + 0.55, t1, 18);
        css(it.fact, 'top', `${top + 120}px`);
      }
    }
  }
}
