import { span } from '../lib/kf';
import { el, css } from '../lib/ui';
import { V3, hyphen } from './spec';
import './v3.css';

/**
 * 字幕帶：畫在畫面裡（不再由 ffmpeg 燒入白字黑框），深色字、不描邊，固定在畫面底部 y ≥ 976 的字幕帶。
 * 字幕內容與時間取自 audio/subs_new.py 產生的 audio/out/subs.ass（已套用 subs_hide.json：畫面標題與旁白相同的句子不上字幕）。
 * 使用 v3 時，輸出流程不要再燒入 ASS 字幕。
 */
export interface Cue { t0: number; t1: number; text: string }

let cues: Cue[] = [];
let loading: Promise<void> | null = null;

const sec = (s: string) => {
  const [h, m, x] = s.split(':');
  return Number(h) * 3600 + Number(m) * 60 + Number(x);
};

/** 讀入字幕（world.load 時呼叫一次即可，重複呼叫共用同一個 Promise）。 */
export function loadCues(url = '/audio/out/subs.ass'): Promise<void> {
  loading ??= fetch(url).then((r) => (r.ok ? r.text() : '')).then((text) => {
    cues = text.split('\n').filter((l) => l.startsWith('Dialogue:')).map((l) => {
      const p = l.split(',');
      return { t0: sec(p[1]), t1: sec(p[2]), text: p.slice(9).join(',').replace(/\\N/g, ' ').trim() };
    });
  }).catch(() => { cues = []; });
  return loading;
}

export class SubtitleBand {
  private e: HTMLElement;
  private shown = '';
  /** from：只顯示這個時間（絕對秒數）以後開始的字幕，樣片用來避免出現上一句的尾巴。 */
  constructor(parent: HTMLElement, readonly from = 0) {
    this.e = el('div', 'v3-cap', parent);
  }
  /** t 為全片絕對秒數；字幕前後各 0.12 秒淡入淡出。 */
  at(t: number) {
    const ok = (q: Cue) => q.t0 >= this.from - 1e-6;
    // 同一句拆成兩段時前後相接，直接換字；只有前後沒有相接的字幕才淡入淡出
    const c = cues.find((q) => ok(q) && t >= q.t0 && t < q.t1) ?? cues.find((q) => ok(q) && t >= q.t0 - 0.12 && t < q.t1 + 0.12);
    if (!c) { css(this.e, 'visibility', 'hidden'); return; }
    if (this.shown !== c.text) { this.e.textContent = hyphen(c.text); this.shown = c.text; }
    const a = (t < c.t0 ? span(t, c.t0 - 0.12, c.t0) : 1) * (t >= c.t1 ? 1 - span(t, c.t1, c.t1 + 0.12) : 1);
    css(this.e, 'visibility', a > 0.002 ? 'visible' : 'hidden');
    css(this.e, 'opacity', a.toFixed(3));
    css(this.e, 'transform', `translate(960px, ${V3.subtitle.centerY}px) translate(-50%, -50%)`);
  }
}
