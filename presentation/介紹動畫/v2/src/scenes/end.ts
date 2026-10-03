import { span, lerp, easeOut, easeInOut } from '../lib/kf';
import { el, css, place, fade, Rise } from '../lib/ui';
import { LogoDraw } from '../lib/logo';
import { at } from './kit';
import type { World } from '../world';
import { cue } from '../lib/cues';

/**
 * 片尾：「讓閒置的書，重新流動。」→ 只留 logo 與名稱，停在完整的 logo 上結束。
 * 段落 5.6 秒（全片上限 2:59）；logo 描繪與填色約 2.45 秒，最後至少停留 0.8 秒。
 * 旁白（段落內秒數）：end1 0.4、end2 3.5。
 */
export function end(_world: World, ui: HTMLElement) {
  const e1 = at('end1'), e2 = at('end2');
  const line = new Rise(ui, '讓閒置的書，重新流動。', 'h-display h-display--line');
  const logo = new LogoDraw(ui);
  const name = new Rise(ui, '救「舊」我的書', 'h-display');
  const veil = el('i', 'veil', ui);

  cue('textin', 0.1, { gain: 1.0 });
  const LOGO = 2.3;
  cue('riser_short', LOGO - 0.3, { dur: 1.2 }); cue('line', LOGO, { dur: 1.4, pan: -0.3 }); cue('line', LOGO, { dur: 1.4, pan: 0.3 });
  cue('impact', LOGO + 1.15); cue('textin', e2 + 0.2, { gain: 1.0 }); cue('final', e2 + 1.0);

  return (t: number) => {
    line.at(t, 0.1, LOGO);
    place(line.root, 960, 540 - span(t, e1, LOGO) * 16);
    logo.at(t, LOGO);
    css(logo.root, 'opacity', '1');
    place(logo.root, 960, 430, ' scale(0.2)');
    name.at(t, e2 + 0.2, 99);
    place(name.root, 960, 690);
    css(veil, 'visibility', 'hidden');
    void lerp; void easeOut; void easeInOut; void fade;
  };
}
