import { lerp } from '../lib/kf';
import { el, css, place, Rise, fade } from '../lib/ui';
import { cue, fly } from '../lib/cues';
import { LogoDraw } from '../lib/logo';
import { BRAND, brandAccent, CORNER } from '../scenes/brand';
import type { World } from '../world';
import { line } from './kit2';
import { soft } from './kit4';
import { onBeat } from './kit5';
import './end.css';

/**
 * 片尾（旁白 25）：左上角的 logo 由 main.ts 的 Corner 交接，平順飛到畫面中央放大 → 品牌名稱升起 → 標語淡入，
 * 之後整組極慢推近，停在完整的 logo 上結束。不放組別、學校、指導老師與成員名單。
 * 交接：Corner 在段落起點前 0.15 秒開始淡出（0.35 秒），本段在同一時刻於完全相同的位置與大小顯示一份完整的 logo，
 * 疊在 Corner 下方；Corner 淡完後才開始移動，畫面上看不到接縫。左上角的名稱隨 Corner 原地淡出。
 * 品牌名稱與標語合起來和旁白 25 一字不差，該句不燒入字幕（audio/subs_hide.json）。
 * 名稱與標語的出現時間對齊配樂拍點：名稱在旁白開頭、標語在念到「讓閒置的書」時（tts/25.wav 的停頓約在 0.99–1.29 秒）。
 */
export function sEnd(_world: World, ui: HTMLElement, _fx: HTMLElement) {
  const L25 = line('25');

  const logo = new LogoDraw(ui);
  logo.root.classList.add('end__logo');
  logo.at(99, 0);
  const brand = new Rise(ui, BRAND, 'end__brand', brandAccent);
  const tag = el('p', 'rise end__tag', ui, '讓閒置的書，在校園裡重新流動');

  const HAND = -0.15, MOVE0 = 0.25, MOVE1 = 1.5;
  const LOGO = { x: 960, y: 392, s: 0.22 };
  const BEAT = onBeat('end', 1.45) - onBeat('end', 0.75);
  const BRAND_T = onBeat('end', L25.at + 0.15);
  const TAG_T = onBeat('end', L25.at + 1.15 - BEAT / 2) + BEAT / 2;

  fly(MOVE0, MOVE1, 0.45, -0.3);
  cue('textin', BRAND_T + 0.05, { gain: 0.8 });
  cue('textin', TAG_T + 0.05, { gain: 0.6 });

  // 以畫面中央為中心的極慢推近（結束時仍在移動，鏡頭不完全靜止）
  const CX = 960, CY = 540;
  const zoom = (t: number) => 1 + 0.035 * soft(t, MOVE1 - 0.4, 11);
  const at = (z: number, x: number, y: number): [number, number] => [CX + (x - CX) * z, CY + (y - CY) * z];

  return (t: number) => {
    const z = zoom(t);
    const vis = t >= HAND;
    css(logo.root, 'visibility', vis ? 'visible' : 'hidden');
    if (vis) {
      const kx = soft(t, MOVE0, MOVE1), ky = soft(t, MOVE0 + 0.1, MOVE1), ks = soft(t, MOVE0, MOVE1);
      const s = Math.exp(lerp(Math.log(CORNER.logoScale), Math.log(LOGO.s), ks));
      const [x, y] = at(z, lerp(CORNER.logoX, LOGO.x, kx), lerp(CORNER.logoY, LOGO.y, ky));
      place(logo.root, x, y, ` scale(${(s * z).toFixed(5)})`);
    }
    brand.at(t, BRAND_T, 999, 0.04);
    place(brand.root, ...at(z, 960, 650), ` scale(${z.toFixed(4)})`);
    fade(tag, t, TAG_T, 999, 18);
    place(tag, ...at(z, 960, 768), ` scale(${z.toFixed(4)})`);
  };
}
