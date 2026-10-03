/** 卡點音效：各場景在建立時登記音效時間（段落內秒數），由 tools/cues.mjs 匯出給 audio/sfx.py。 */
export interface Cue { type: string; t: number; gain: number; pan: number; dur?: number; ease?: string; i?: number; n?: number; up?: number }

export const CUES: Cue[] = [];
let base = 0;

/** 之後登記的音效以此秒數為段落起點。 */
export function cueBase(t: number) { base = t; }

export function cue(type: string, t: number, o: Partial<Omit<Cue, 'type' | 't'>> = {}) {
  CUES.push({ gain: 1, pan: 0, ...o, type, t: +(base + t).toFixed(4) });
}

/** 物件移動的咻聲：峰值落在移動中段。 */
export function fly(t0: number, t1: number, gain = 1, pan = 0, ease = 'inout') {
  cue('whoosh', t0, { dur: +(t1 - t0).toFixed(3), gain, pan, ease });
}

/** 數字滾動：滾動期間的細碎點擊與停住時的一聲。 */
export function roll(t0: number, dur: number, pan = 0, gain = 1) {
  cue('roll', t0, { dur, pan, gain });
  cue('land', t0 + dur, { pan, gain });
}
