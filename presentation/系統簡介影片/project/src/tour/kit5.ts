/**
 * 第二版的節奏工具：把換場、浮出對齊配樂的小節線與拍點。
 * 格線由 audio/music.py 輸出到 src/beats.json；配樂每個曲風段落速度不同，所以格線依絕對秒數查詢。
 */
import BEATS from '../beats.json';
import TL from '../timeline.json';

const GRID: number[] = [];
const BEAT_GRID: number[] = [];
for (const s of BEATS.sections) {
  for (const t of s.bar_times) GRID.push(t);
  for (let i = 0; i < s.bars * 4; i++) BEAT_GRID.push(s.t0 + i * s.beat);
}
GRID.sort((a, b) => a - b);
BEAT_GRID.sort((a, b) => a - b);

const START: Record<string, number> = Object.fromEntries(TL.sections.map((s) => [s.id, s.start]));

function nearest(grid: number[], t: number) {
  let best = grid[0];
  for (const g of grid) if (Math.abs(g - t) < Math.abs(best - t)) best = g;
  return best;
}

/** 段落 sec 內的時間 t（秒）最接近的小節線，回傳段落內秒數。 */
export function onBar(sec: string, t: number) {
  return nearest(GRID, START[sec] + t) - START[sec];
}

/** 段落 sec 內的時間 t 最接近的拍點，回傳段落內秒數。 */
export function onBeat(sec: string, t: number) {
  return nearest(BEAT_GRID, START[sec] + t) - START[sec];
}

/** 段落 sec 內 [t0, t1] 之間的拍點（段落內秒數），用來把一串依序浮出的元件排在拍子上。 */
export function beatsIn(sec: string, t0: number, t1: number) {
  const a = START[sec] + t0, b = START[sec] + t1;
  return BEAT_GRID.filter((g) => g >= a - 1e-6 && g <= b + 1e-6).map((g) => g - START[sec]);
}

import { TAPS, type World } from '../world';
import { Tap } from '../scenes/kit';

/**
 * 點擊截圖工具輸出的按鈕（public/v2/taps.json）。
 * 建構時就建立 Tap（點擊音效要在場景建構時登記，時間才會對），座標等 world.load() 讀入 json 後於播放時填入。
 */
export class TapOn {
  private tap: Tap;
  constructor(ui: HTMLElement, phone: number, private name: string, t0: number) {
    this.tap = new Tap(ui, phone, 0, 0, t0);
  }
  at(world: World, t: number) {
    const r = TAPS[this.name];
    if (!r) return;
    this.tap.x = r.x + r.w / 2;
    this.tap.y = r.y + r.h / 2;
    this.tap.at(world, t);
  }
}

import { CUTS } from '../world';

const PHONE_PT = 393;

/**
 * 相鄰的一組去背元件往手機右側展開（使用者 2026-10-09 選定「B 為主」：同時浮起會黏在一起）。
 * 回傳每個元件的 dx、dy（App 邏輯 pt，dy 向下為正），展開後元件左緣離手機右緣 margin，彼此相隔 gap。
 * col：上下排成一列，整列垂直置中於原本位置；row：保持原本高度，左右排開。
 * 座標取自 cuts.json，world.load() 之後才有，所以要在播放時呼叫。
 */
export function spread(names: string[], grow: number, dir: 'col' | 'row', gap = 24, margin = 48) {
  const rs = names.map((n) => CUTS[n]);
  if (rs.some((r) => !r)) return names.map(() => ({ dx: 0, dy: 0 }));
  if (dir === 'col') {
    const hs = rs.map((r) => r.h * (1 + grow));
    const total = hs.reduce((a, b) => a + b, 0) + gap * (rs.length - 1);
    const mid = (Math.min(...rs.map((r) => r.y)) + Math.max(...rs.map((r) => r.y + r.h))) / 2;
    let y = mid - total / 2;
    return rs.map((r, i) => {
      const w = r.w * (1 + grow);
      const cy = y + hs[i] / 2;
      y += hs[i] + gap;
      return { dx: PHONE_PT + margin + w / 2 - (r.x + r.w / 2), dy: cy - (r.y + r.h / 2) };
    });
  }
  let x = PHONE_PT + margin;
  return rs.map((r) => {
    const w = r.w * (1 + grow);
    const cx = x + w / 2;
    x += w + gap;
    return { dx: cx - (r.x + r.w / 2), dy: 0 };
  });
}
