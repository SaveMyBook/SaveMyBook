import { span, easeOut, easeInOut } from '../lib/kf';
import { el, css, place, fade, number } from '../lib/ui';
import { Headline, at } from './kit';
import type { World } from '../world';
import { cue, roll } from '../lib/cues';

/**
 * 服務費：以售價 110 元為例，比較本平台規劃的 10% 與委託寄賣的 35%。
 * 旁白（段落內秒數）：fee 0.8。
 */
export function fee(_world: World, ui: HTMLElement) {
  const t0 = at('fee');
  const head = new Headline(ui, '低抽成，快速撥款', '規劃收取 10% 交易服務費，遠低於委託寄賣的 35%');
  const cap = el('p', 'fee-cap', ui, '以售價 110 元為例');
  const ROWS = [
    { name: '救「舊」我的書', tag: '規劃', pct: 10, gets: 99, ours: true },
    { name: '委託寄賣', tag: '', pct: 35, gets: 71, ours: false },
  ];
  const rows = ROWS.map((r) => {
    const row = el('div', r.ours ? 'fee-row fee-row--ours' : 'fee-row', ui);
    el('p', 'fee-row__name', row, `${r.name}${r.tag ? `<small>${r.tag}</small>` : ''}`);
    const bar = el('div', 'fee-row__bar', row);
    const fill = el('i', '', bar);
    const pct = el('p', 'fee-row__pct', row);
    const pv = el('span', '', pct);
    el('small', '', pct, '%');
    const gets = el('p', 'fee-row__gets', row, '賣家實得 ');
    const gv = el('b', '', gets);
    gets.append('元');
    return { row, fill, pv, gv };
  });
  const note = el('p', 'meta fee-note', ui, '委託寄賣以 TAAZE 讀冊生活二手書代售服務條款（2025 年 8 月版）為例；本系統之交易服務費為規劃，目前未收取。');

  cue('textin', -0.3);
  [0, 1].forEach((i) => { cue('grow', t0 + 0.8 + i * 0.35, { dur: 1.5, up: i ? 2 : 1, gain: 0.8 }); roll(t0 + 0.8 + i * 0.35, 1.5, 0.3, 0.6); });

  return (t: number) => {
    const end = 6.9;
    head.at(t, -0.3, end);
    fade(cap, t, t0 + 0.2, end);
    place(cap, 960, 330);
    rows.forEach((r, i) => {
      const a = t0 + 0.5 + i * 0.35;
      const k = easeOut(span(t, a, a + 0.6)) * (1 - easeInOut(span(t, end, end + 0.45)));
      css(r.row, 'opacity', k.toFixed(3));
      css(r.row, 'visibility', k > 0.001 ? 'visible' : 'hidden');
      place(r.row, 960, 470 + i * 170 + (1 - k) * 24);
      const g = easeOut(span(t, a + 0.3, a + 1.8));
      css(r.fill, 'transform', `scaleX(${(ROWS[i].pct / 40 * g).toFixed(3)})`);
      number(r.pv, ROWS[i].pct * g, 0);
      number(r.gv, 110 - (110 - ROWS[i].gets) * g, 0);
    });
    fade(note, t, t0 + 1.6, end, 10);
    place(note, 960, 900);
  };
}
