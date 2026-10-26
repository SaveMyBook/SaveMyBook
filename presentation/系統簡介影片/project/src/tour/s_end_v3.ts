import { cue } from '../lib/cues';
import type { World } from '../world';
import { span } from '../lib/kf';
import { line, section } from './kit2';
import { soft } from './kit4';
import { orbit, sectionPans } from '../v3/camera';
import { BrandMark, HERO, markIn, zoomMark } from './x_open_v3';

const SEC = 'end';

/**
 * v3 片尾（旁白 25）：只放標誌與名稱（NTUB 片尾的做法，不畫同心圓），排列與片頭品牌段相同（x_open_v3.ts 的 HERO）。
 * - 左上角的 Corner 在交界前 0.5 秒起淡出、交界前 0.15 秒收完（main.ts：END - 0.5，0.35 秒）；
 *   上一段往右出畫的同時，logo 在交界後立刻淡入並輕微放大（markIn），畫面上不會同時出現兩份標誌，也不會停在空背景。
 * - 名稱在旁白唸到「救舊我的書」時浮現；不放標語，旁白 25 需要上字幕（建議從 audio/subs_hide.json 移除 25）。
 * - 之後到片尾整組以極慢的速度推近，背景光暈緩慢漂移，畫面不會完全靜止。最後一段不做離場橫移。
 */
export default function sEndV3(world: World, ui: HTMLElement, _fx: HTMLElement) {
  const L25 = line('25');
  const LEN = section(SEC).end - section(SEC).start;

  const LOGO = 0.02, NAME = L25.at;
  const mark = new BrandMark(ui);
  const K = orbit([0, 0, 0], 0, 0.02, 60, [0, 0.5, 0]);

  cue('glint', LOGO + 0.35, { gain: 0.6 });
  cue('textin', NAME + 0.05, { gain: 0.8 });

  return (t: number) => {
    const on = t >= LOGO - 0.01 && t <= LEN + 0.05;
    // 以整組中心為準極慢推近（結束時仍在移動）
    const z = 1 + 0.04 * soft(t, LOGO + 0.6, LEN + 1.5);
    const p = zoomMark(mark.stackPose(960, HERO.logoY, HERO.logoS, HERO.nameY, HERO.nameF), z, 960, (HERO.logoY + HERO.nameY) / 2);
    const m = markIn(t, LOGO);
    mark.at(t, on, p, LOGO - 1.95, m.fade, span(t, NAME, NAME + 0.5), m.grow);
    if (t < 0 || t > LEN + 0.05) return;
    world.frame.camera = sectionPans(K, t, LEN, { sec: SEC, out: false });
  };
}
