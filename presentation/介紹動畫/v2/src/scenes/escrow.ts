import { span, lerp, easeOut, easeInOut } from '../lib/kf';
import { el, css, place } from '../lib/ui';
import { cue } from '../lib/cues';
import TL from '../timeline.json';
import { BUYER, SELLER, type World } from '../world';
import { BOOK } from './story';

const S = Object.fromEntries(TL.sections.map((s) => [s.id, s.start])) as Record<string, number>;

/** 款項進度（右上角）：付款 → 存書 → 取書 → 撥款，硬幣在付款時飛進平台暫管，取書 24 小時後飛進賣家錢包。全片時間。 */
export const ESCROW = {
  show: S.pay + 6.2,
  hide: S.pickup + 9.4,
  coinIn: [S.pay + 6.4, S.pay + 7.4] as [number, number],
  steps: [S.pay + 3.5, S.deposit + 17.2, S.pickup + 4.4, S.pickup + 7.5],
  coinOut: [S.pickup + 6.5, S.pickup + 7.5] as [number, number],
  clock: [S.pickup + 4.7, S.pickup + 6.0] as [number, number],
};
const HUD_X = 330, HUD_Y = 92;

export function escrow(world: World, ui: HTMLElement) {
  const hud = el('div', 'hud', ui, `<p class="hud__vault"><i></i>平台暫管<b>${BOOK.price} 代幣</b></p><ol class="hud__steps"><li>付款</li><li>存書</li><li>取書</li><li>撥款</li></ol>`);
  const vault = hud.querySelector<HTMLElement>('.hud__vault')!;
  const steps = [...hud.querySelectorAll<HTMLElement>('li')];
  const coin = el('div', 'coin', ui, `<b>${BOOK.price}</b><small>代幣</small>`);
  const clock = el('div', 'ffwd', ui, '<i class="ffwd__dial"><i class="ffwd__hand"></i></i><b>取書 24 小時後</b>');
  const hand = clock.querySelector<HTMLElement>('.ffwd__hand')!;
  cue('coin_fly', ESCROW.coinIn[0], { dur: 1.0, pan: 0.4 }); cue('coin_land', ESCROW.coinIn[1], { pan: 0.8 });
  ESCROW.steps.forEach((s, i) => cue('check', s, { pan: 0.8, gain: 0.6 + (i === 3 ? 0.2 : 0) }));
  cue('clock', ESCROW.clock[0] + 0.2); cue('sweep', ESCROW.clock[0] + 0.3, { dur: 0.9, gain: 0.6 });
  cue('coin_fly', ESCROW.coinOut[0], { dur: 1.1, pan: -0.2 }); cue('cash', ESCROW.coinOut[1], { pan: -0.4 });

  return (T: number) => {
    const k = easeOut(span(T, ESCROW.show, ESCROW.show + 0.5)) * (1 - easeInOut(span(T, ESCROW.hide, ESCROW.hide + 0.5)));
    css(hud, 'visibility', k > 0.001 ? 'visible' : 'hidden');
    css(hud, 'opacity', k.toFixed(3));
    place(hud, HUD_X, HUD_Y + (1 - k) * -20);
    steps.forEach((li, i) => li.classList.toggle('is-done', T >= ESCROW.steps[i]));
    const held = T >= ESCROW.coinIn[1] && T < ESCROW.coinOut[0];
    vault.classList.toggle('is-held', held);
    vault.classList.toggle('is-empty', T >= ESCROW.coinOut[0]);

    // 硬幣：付款後自買家手機飛進暫管；取書 24 小時後自暫管飛進賣家錢包
    const inK = span(T, ESCROW.coinIn[0], ESCROW.coinIn[1]);
    const outK = span(T, ESCROW.coinOut[0], ESCROW.coinOut[1]);
    const flyingIn = inK > 0 && inK < 1;
    const flyingOut = outK > 0 && outK < 1;
    css(coin, 'visibility', flyingIn || flyingOut ? 'visible' : 'hidden');
    if (flyingIn || flyingOut) {
      world.frame.after.push(() => {
        const vaultPos = { x: HUD_X - 180, y: HUD_Y - 22 };
        let from, to, e;
        if (flyingIn) {
          from = world.frame.phones[BUYER] ? world.point(BUYER, 196, 420) : { x: 960, y: 540 };
          to = vaultPos; e = easeInOut(inK);
        } else {
          from = vaultPos;
          to = world.frame.phones[SELLER] ? world.point(SELLER, 196, 300) : { x: 600, y: 540 };
          e = easeInOut(outK);
        }
        const arc = Math.sin(Math.PI * e) * 120;
        place(coin, lerp(from.x, to.x, e), lerp(from.y, to.y, e) - arc, ` scale(${(1 + Math.sin(Math.PI * e) * 0.25).toFixed(3)})`);
      });
    }
    // 時間快轉：表盤指針轉兩圈
    const ck = span(T, ESCROW.clock[0], ESCROW.clock[1]);
    const cv = easeOut(span(ck, 0, 0.2)) * (1 - span(ck, 0.85, 1));
    css(clock, 'visibility', cv > 0.001 ? 'visible' : 'hidden');
    css(clock, 'opacity', cv.toFixed(3));
    // 放在上方：此時書櫃與手機正從兩側退場，置中會壓在它們上面
    place(clock, 960, 165);
    css(hand, 'transform', `rotate(${(easeInOut(span(ck, 0.1, 0.85)) * 720).toFixed(1)}deg)`);
  };
}
