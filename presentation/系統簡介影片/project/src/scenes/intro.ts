import { keyframes, span, lerp, easeOut, easeInOut, type Pose } from '../lib/kf';
import { Rise, el, css, fade, place, number } from '../lib/ui';
import { easeIn } from './kit';
import { cue, fly, roll } from '../lib/cues';
import { LogoDraw } from '../lib/logo';
import { BUYER, SELLER, RING, type World } from '../world';
import { Tag, Chips } from './kit';
import { BRAND, brandAccent, CORNER } from './brand';

/** 開場結尾兩支手機的位置（下一段接續使用）：左賣家、右買家。底邊要高於字幕卡（約 y=960）。 */
export const DUO = {
  seller: { x: -0.25, y: -0.28, z: 0, rx: 0.06, ry: 0.22, rz: 0.02, s: 0.9 } as Pose,
  buyer: { x: 0.25, y: -0.28, z: 0, rx: 0.06, ry: -0.22, rz: -0.02, s: 0.9 } as Pose,
};

/** 片頭 logo 與名稱飛到左上角的時間：FLY 開始、BRAND_LAND 落定（之後由 main.ts 的固定標誌接手）。 */
const FLY = 20.25;
export const BRAND_LAND = 21.0;

/**
 * 開場：面交與寄送的困擾 → 書櫃 → logo 描線 → 賣家與買家兩支手機升起。
 * 旁白 0.7「二手書交易，難在哪裡？」3.4「面交怕詐騙…」6.9「超過一半的人…」15.2「救舊我的書…」
 */
const RING_SCREENS = ['s_sell_ai_sheet_220', 'b_book_detail', 'b_chat_4', 'b_pay_done', 's_cab_open', 's_wallet'];

export function intro(world: World, ui: HTMLElement) {
  const q1 = new Rise(ui, '二手書交易，難在哪裡？', 'h-headline');
  const q2 = new Rise(ui, '二手書交易，需要更好的方式', 'h-headline');
  const sub1 = el('p', 'sub', ui, '受訪者對兩種交易方式最大的困擾');
  const sub2 = el('p', 'sub', ui, '受訪者期待的解決方式');
  const source = el('p', 'meta', ui, '資料來源：本專題「二手書籍交易行為與市場需求調查」，498 份有效問卷');
  const stats = [0, 1].map(() => {
    const box = el('div', 'stat', ui);
    const num = el('p', 'stat__num', box);
    const val = el('span', '', num);
    el('small', '', num, '%');
    const key = el('p', 'stat__key', box);
    const note = el('p', 'stat__note', box);
    return { box, key, val, note };
  });
  const SET1 = [['面交', 43.2, '擔心對方失約或遭遇詐騙'], ['寄送', 57.9, '須自行包裝並至超商寄件']] as const;
  const SET2 = [['交易方式', 51.4, '傾向使用實體儲物櫃'], ['書櫃功能', 57.4, '最看重 24 小時自助存取']] as const;

  const logo = new LogoDraw(ui);
  const title = new Rise(ui, BRAND, 'h-brand', brandAccent);
  const tagline = el('p', 'sub', ui, '結合智慧書櫃的二手書交易平台');
  const pillars = new Chips(ui, ['掃碼存取', '款項暫管', 'AI 輔助'], 'chips--brand');

  fly(3.15, 4.25, 0.5, -0.5);
  fly(3.35, 4.55, 0.4, 0.5); cue('bump', 4.55, { pan: 0.4 });
  [0, 1].forEach((i) => roll(3.7 + i * 0.25, 1.4, i ? 0.6 : -0.6, 0.55));
  [0, 1].forEach((i) => roll(6.95 + i * 0.12, 1.25, i ? 0.6 : -0.6, 0.45));
  fly(6.85, 8.1, 0.6);
  cue('door_open', 9.0, { dur: 0.6, pan: -0.1 }); cue('book', 10.2, { pan: -0.1 });
  cue('slam', 10.9, { pan: -0.1, gain: 0.6 }); cue('success', 10.95, { gain: 0.7 });
  fly(11.4, 12.6, 0.4);
  cue('line', 12.58, { dur: 1.15, pan: -0.3 }); cue('line', 12.58, { dur: 1.15, pan: 0.3 });
  cue('impact', 13.65, { gain: 0.8 }); cue('shimmer', 14.4, { gain: 0.7 });
  fly(17.0, 18.2, 0.6, -0.3); fly(17.2, 18.4, 0.6, 0.3);
  const sellerTag = new Tag(ui, SELLER, '賣家', '侖娥');
  const buyerTag = new Tag(ui, BUYER, '買家', '海嫄');

  return (t: number) => {
    const f = world.frame;

    // 標題：先置中慢慢上飄，數字出現時移到上方並縮小
    const up = easeInOut(span(t, 3.0, 3.7));
    q1.at(t, 0.55, 6.55);
    // 置中時緩慢放大，維持畫面的動態
    place(q1.root, 960, lerp(520, 150, up), ` scale(${lerp(1 + span(t, 0.5, 3.0) * 0.05, 0.8, up).toFixed(3)})`);
    q2.at(t, 6.85, 11.6);
    place(q2.root, 960, 150, ' scale(0.8)');
    fade(sub1, t, 3.55, 6.55, 24, 0);
    place(sub1, 960, 222);
    fade(sub2, t, 7.1, 11.6, 24, 0);
    place(sub2, 960, 222);
    // 書櫃升起時暫時讓開
    fade(source, t, 4.0, 11.6, 10);
    css(source, 'opacity', ((t < 6.6 ? 1 : t < 8.2 ? 1 - span(t, 6.6, 6.9) + span(t, 7.9, 8.2) : 1) * Number(source.style.opacity || 0)).toFixed(3));
    place(source, 960, 1018);

    // 數字欄：兩組數字直接由前一組滾動到下一組
    stats.forEach((s, i) => {
      const enter = 3.7 + i * 0.25;
      const swap = span(t, 6.95 + i * 0.12, 8.2 + i * 0.12);
      const [k1, v1, n1] = SET1[i];
      const [k2, v2, n2] = SET2[i];
      const count = easeOut(span(t, enter, enter + 1.4));
      number(s.val, swap > 0 ? lerp(v1, v2, easeInOut(swap)) : v1 * count, 1);
      s.key.textContent = swap < 0.5 ? k1 : k2;
      s.note.textContent = swap < 0.5 ? n1 : n2;
      const blink = swap > 0 && swap < 1 ? Math.abs(swap - 0.5) * 2 : 1;
      css(s.key, 'opacity', blink.toFixed(3));
      css(s.note, 'opacity', blink.toFixed(3));
      fade(s.box, t, enter, 11.5 + i * 0.1, 40);
      place(s.box, i ? 1600 : 320, 600 + Math.sin(t * 0.8 + i) * 6);
    });

    // 面交：手機自左下旋轉飛入，防詐提醒自螢幕浮出
    if (t > 3.1 && t < 7.4) {
      const pose = keyframes(t, [
        [3.15, { x: -0.95, y: -1.7, z: 0, rx: 0.6, ry: 1.3, rz: 0.4, s: 1.05 }],
        [4.3, { x: -0.19, y: -0.12, rx: 0.03, ry: 0.06, rz: 0 }],
        [6.4, { x: -0.18, ry: 0.04 }],
        [7.3, { x: -1.1, y: 0.25, rx: -0.2, ry: 1.9, rz: -0.3 }],
      ]);
      f.phones[BUYER] = { pose, scr: { a: 'b_chat_warn' } };
    }
    // 寄送：紙箱自右上翻滾落定
    if (t > 3.3 && t < 7.4) {
      f.parcel = keyframes(t, [
        [3.35, { x: 0.95, y: 1.25, z: 0, rx: 2.2, ry: -1.6, rz: 1.1, s: 1.35 }],
        [4.55, { x: 0.2, y: -0.1, rx: 0.42, ry: -0.62, rz: 0.06 }],
        [6.4, { ry: -0.4 }],
        [7.3, { x: 1.2, y: -0.5, rx: 1.4, ry: -2.2, rz: -0.6 }],
      ]);
    }

    // 書櫃自下方旋轉升起，轉場時旋轉飛離
    if (t > 6.8 && t < 12.7) {
      f.cabinet = {
        pose: keyframes(t, [
          [6.85, { x: 0, y: -1.9, z: 0, rx: 0.12, ry: 1.1, rz: 0, s: 1.38 }],
          [8.1, { y: -0.08, rx: 0.06, ry: 0.32 }],
          [11.4, { ry: -0.18 }],
          [12.6, { y: -1.9, rx: 0.2, ry: -0.5 }],
        ]),
        kiosk: { state: t < 9.0 ? 'qr' : t < 10.9 ? 'open' : 'done', refresh: (t / 30) % 1, seconds: Math.round(lerp(30, 27, span(t, 9.0, 10.9))), digits: 1, check: easeOut(span(t, 10.9, 11.3)) },
        // A01 櫃門打開、放入一本書再關上
        door: easeInOut(span(t, 9.0, 9.6)) * (1 - easeInOut(span(t, 10.4, 10.9))),
        deposit: easeOut(span(t, 9.4, 10.2)),
      };
    }

    // logo：描出輪廓與書頁後填色，完成時擴散一道光環
    const lift = easeInOut(span(t, 16.9, 17.9));
    // 品牌段結束時 logo 與名稱縮小飛到左上角，落定後由固定標誌接手
    // logo 先走、名稱稍後跟上，飛行途中兩者不疊在一起
    const fly = easeInOut(span(t, FLY, BRAND_LAND - 0.12));
    const flyName = easeInOut(span(t, FLY + 0.12, BRAND_LAND));
    const landed = t >= BRAND_LAND;
    logo.at(t, 12.5);
    css(logo.root, 'opacity', landed ? '0' : '1');
    place(logo.root, lerp(960, CORNER.logoX, fly), lerp(lerp(430, 112, lift), CORNER.logoY, fly), ` scale(${lerp(lerp(0.3, 0.115, lift), CORNER.logoScale, fly).toFixed(4)})`);

    // 品牌名稱：先在 logo 下方，手機升起時一起移到上方，最後飛到左上角
    title.at(t, 15.3, 99);
    css(title.root, 'opacity', landed ? '0' : '1');
    const s0 = lerp(1, 0.6, lift), s1 = CORNER.size / 132;
    const w = title.root.offsetWidth;
    // 名稱以左緣對齊固定標誌的文字位置（rise__line 上下留白不對稱，中線往上修正）
    place(title.root, lerp(960, CORNER.textX + (w * s1) / 2, flyName), lerp(lerp(746, 262, lift), CORNER.textY + 2, flyName), ` scale(${lerp(s0, s1, flyName).toFixed(4)})`);
    fade(tagline, t, 15.9, FLY - 0.1, 24, 0);
    place(tagline, 960, lerp(866, 340, lift));
    pillars.at(t, 16.2, FLY - 0.15, 0, 0);
    place(pillars.root, 960, lerp(930, 396, lift));

    // 賣家與買家兩支手機各自從正下方升起，同時由背面轉到正面，轉正後略微回穩
    if (t > 16.9) {
      [SELLER, BUYER].forEach((ph, i) => {
        const to = ph === SELLER ? DUO.seller : DUO.buyer;
        const side = ph === SELLER ? 1 : -1;
        const t0 = 17.1 + i * 0.15;
        const k = span(t, t0, t0 + 1.7);
        if (k <= 0) return;
        const up = easeOut(span(k, 0, 0.75));
        const turn = easeInOut(span(k, 0.08, 0.92));
        // 轉正後以小幅阻尼擺動回穩
        const after = Math.max(0, t - (t0 + 1.55));
        const settle = after > 0 ? Math.sin(after * 9) * Math.exp(-after * 4.5) * 0.07 : 0;
        const pose: Pose = {
          ...to,
          y: lerp(-2.3, to.y ?? 0, up),
          z: lerp(-10, to.z ?? 0, up),
          rx: (to.rx ?? 0) + (1 - up) * 0.3,
          ry: (to.ry ?? 0) + side * (Math.PI * 0.9 * (1 - turn) - settle),
          rz: (to.rz ?? 0) - side * (1 - up) * 0.1,
        };
        pose.ry = (pose.ry ?? 0) + Math.sin((t - 17) * 0.5) * 0.04;
        f.phones[ph] = { pose, scr: { a: ph === SELLER ? 's_sell_isbn' : 'b_home' } };
      });
    }

    // 背景：左右各三支手機排成弧形、由近而遠，展示 App 的主要畫面；中間留給兩支主角手機。
    // 由近到遠依序升起，緩慢向外漂移；進入上架段時下沉
    const wallOut = easeIn(span(t, 20.2, 21.2));
    if (t > 16.8 && wallOut < 0.999) {
      RING.forEach((ph, i) => {
        const side = i < 3 ? -1 : 1;
        const d = i % 3;
        const rise = easeOut(span(t, 17.1 + d * 0.18, 18.5 + d * 0.18));
        const drift = (t - 17) * 0.012;
        f.phones[ph] = {
          pose: {
            x: side * ([0.98, 1.42, 1.92][d] + drift),
            y: lerp(-2.6 - d * 0.4, [-0.3, -0.2, -0.1][d], rise) - wallOut * 3,
            z: [-26, -52, -82][d],
            rx: 0.04,
            ry: -side * ([0.42, 0.55, 0.66][d] + Math.sin((t - 17) * 0.4 + d) * 0.05) + side * (1 - rise) * 0.9,
            rz: 0,
            s: 1,
          },
          scr: { a: RING_SCREENS[i] },
          glow: 0.94,
        };
      });
    }

    // 品牌字幕卡（至 19.45）收起後才出現，標籤與字幕卡在同一高度
    sellerTag.at(world, t, 19.5, 20.6);
    buyerTag.at(world, t, 19.6, 20.6);
  };
}
