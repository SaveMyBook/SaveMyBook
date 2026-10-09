import { type Pose } from '../lib/kf';
import { cue, fly } from '../lib/cues';
import { CUTS, type World, type Pop } from '../world';
import { seq, stepCues, back, type Step } from '../scenes/kit';
import { line } from './kit2';
import { Title, ChapterWord, glide, soft } from './kit4';
import { onBeat } from './kit5';
import { LangSub, spreadAt } from './x_account';

const SEC = 'account';
const SIGMA = 0.42;

/** 手機編號：登入頁、會員等級（推入設定後為淺色設定頁）、深色設定頁。 */
const LOGIN = 1, MAIN = 0, DARK = 2;

/** 五種介面語言（savemybook_app/lib/services/locale_provider.dart 的 nativeNames），畫面由截圖工具以各 locale 實際渲染。 */
const LANGS = [
  { tag: 'hant', name: '繁體中文' },
  { tag: 'en', name: 'English' },
  { tag: 'ja', name: '日本語' },
  { tag: 'ko', name: '한국어' },
  { tag: 'hans', name: '简体中文' },
];

/**
 * 第 7 章 帳號會員（旁白 20 登入方式、21 點數等級、語言與主題）。畫面由 savemybook_app/tool/video_shots/account_test.dart 產生。
 * 20：登入頁手機由下方直接升到左側，Google、Apple、LINE、手機簡訊四個登入按鈕依旁白念到的拍點往右展開成一列並放大一倍，
 *     最後「使用通行密鑰登入」接在這列下方。
 * 21：登入頁沿弧線往左滑出，會員等級頁沿同一道弧線從右側接力滑入（es 完成劇情中的購買訂單後累積 10 點，畫面切在下一等級「活躍書友」），
 *     「目前累積 10 點，已完成 1 筆交易」與「再 90 點即可解鎖」的進度卡往右展開；
 *     → App 內推入設定頁，深色主題的同一頁從右側滑入並排；淺色手機的「語言」列原地放大浮出，
 *     兩支手機與浮出的語言列在拍點上同步由繁體中文切換到 English、日本語、한국어、简体中文 → 往下退場。
 * 文案出處：旁白 20、21；每完成一筆購買訂單累積 10 點、等級門檻 100／500／2000 點見複評版手冊 p260（表 12-16-1、12-16-2，PDF 第 275 頁）；
 * 五種語言與深淺色主題見手冊 p37（表 5-1-1 多國語系與主題切換）。
 */
export function sAccount(world: World, ui: HTMLElement, fx: HTMLElement) {
  const L20 = line('20'), L21 = line('21');
  const OUT = L21.end;

  const word = new ChapterWord(fx, '帳號會員');
  // 本段手機上移（頂端約 y 270），標題整組上移 10px，副標才不會碰到手機
  const tA = new Title(ui, '支援[多種登入方式]', 'Google、Apple、LINE、手機簡訊與通行密鑰', 112);
  const tB = new Title(ui, '累積點數　[升級會員]', '每完成一筆購買訂單累積 10 點，滿 100、500、2000 點升級', 112);
  const tC = new Title(ui, '[五種語言]　深淺色主題');
  const langs = new LangSub(ui, LANGS.map((l) => l.name));

  const WORD_OUT = 1.0;
  const RISE = WORD_OUT + 0.02;
  const HOLD = 1.2, RISE_K = 0.5;
  const BEAT = onBeat(SEC, 5) - onBeat(SEC, 4.5);
  const HALF = BEAT / 2;
  /** 最接近的拍點或半拍。 */
  const onHalf = (t: number) => {
    const a = onBeat(SEC, t), b = onBeat(SEC, t - HALF) + HALF;
    return Math.abs(a - t) <= Math.abs(b - t) ? a : b;
  };
  // 20：按鈕依旁白念到的時間浮出（tts/20.wav 的停頓：Google 約 1.8、Apple 2.55、LINE 3.15、手機簡訊 3.75、通行密鑰 4.85），對齊拍點與半拍
  const ICON_T = {
    google: onHalf(L20.at + 1.1),
    apple: onHalf(L20.at + 1.36),
    line: onHalf(L20.at + 1.95),
    phone: onHalf(L20.at + 2.52),
  };
  // 通行密鑰在念到前浮出完畢，按鈕列才有時間在換手機前依序收回
  const KEY = onHalf(L20.at + 3.22);
  // 21：時間由段落結尾往回排。每組元件完全浮出後至少停 HOLD 秒（浮出動畫 RISE_K 秒另計）
  const EXIT0 = OUT - 0.95, EXIT1 = OUT - 0.05;
  // 設定頁推入後半拍，「語言」那一列原地放大浮出；之後每拍切換一種語言，最後的简体中文停到浮出收回
  const PUSH = onBeat(SEC, EXIT0 - 0.25) - 5 * BEAT;
  const LANG_POP = PUSH + HALF, LANG_OFF = EXIT0 - 0.35;
  const SWAP = [1, 2, 3, 4].map((i) => PUSH + i * BEAT);
  // 等級卡在推入前 LEVEL_OFF 秒收完：手機推入設定頁時會往下移，元件回到原位時不可落進字幕區
  const LEVEL_OFF = PUSH - 0.45;
  const P0 = LEVEL_OFF - HOLD - RISE_K - HALF;
  // 登入按鈕在通行密鑰完全浮出後停 HOLD 秒才收回，下一拍接力換手機
  const KEY_OFF = KEY + RISE_K + HOLD;
  // 按鈕全部收回後才換手機：通行密鑰先收，按鈕由近而遠每 0.08 秒收一個
  const T1 = onBeat(SEC, KEY_OFF + 0.85);
  const HAND = 0.95;

  const light: Step[] = [
    [-9, 'v_acc_level'],
    [PUSH, 'v_acc_settings_hant', 1, 0.45],
    // 換語言直接切換，不淡化：不同語言的字形、寬度不同，淡化那幾格會像兩種語言的字疊在一起（App 換語言也是整頁直接重畫）
    ...SWAP.map((t, i): Step => [t, `v_acc_settings_${LANGS[i + 1].tag}`, 0, 0.01]),
  ];
  const dark: Step[] = [
    [-9, 'v_acc_settings_hant_dark'],
    ...SWAP.map((t, i): Step => [t, `v_acc_settings_${LANGS[i + 1].tag}_dark`, 0, 0.01]),
  ];
  const langAt = (t: number) => SWAP.filter((s) => t >= s).length;

  stepCues(light);
  Object.values(ICON_T).forEach((t) => cue('pop', t, { gain: 0.55 }));
  cue('pop', KEY, { gain: 0.6 });
  [0, 1].forEach((i) => cue('pop', P0 + i * HALF, { gain: 0.55 }));
  SWAP.forEach((t) => cue('swap', t, { gain: 0.8 }));
  cue('lift', LANG_POP, { gain: 0.7, pan: -0.2 });

  const P = (x: number, y: number, z: number, rx: number, ry: number, rz: number, s: number): Pose => ({ x, y, z, rx, ry, rz, s });
  // 登入頁：由下方直接升到左側（按鈕往右展開）→ 停留時微轉 → 沿弧線往左滑出
  const login: [number, Pose][] = [
    [RISE, P(-0.2, -2.0, 0, 0.5, 0.45, -0.1, 1.4)],
    [RISE + 0.85, P(-0.27, -0.18, 0, 0.04, 0.15, -0.01, 1.4)],
    [T1 - 0.3, P(-0.29, -0.18, 0, 0.02, 0.1, 0, 1.42)],
    [T1 + HAND, P(-1.8, -0.25, -6, 0.04, 0.55, 0.03, 1.38)],
  ];
  // 會員等級：沿同一道弧線從右側滑入 → App 內推入設定頁，同時縮小並讓出右側給深色手機 → 往下退場
  const main: [number, Pose][] = [
    [T1, P(1.8, -0.25, -6, 0.04, -0.55, -0.03, 1.38)],
    [T1 + HAND, P(-0.27, -0.18, 0, 0.03, 0.13, 0, 1.41)],
    [PUSH - 0.3, P(-0.29, -0.18, 0, 0.02, 0.1, 0, 1.42)],
    [PUSH + 1.0, P(-0.3, -0.3, 0, 0.03, 0.15, 0, 1.3)],
    [EXIT0, P(-0.3, -0.3, 0, 0.02, 0.11, 0, 1.31)],
    [EXIT1, P(-0.32, -2.1, 0, -0.3, 0.16, 0.04, 1.3)],
  ];
  // 深色設定頁：沿同一道弧線從右側滑入並排 → 往下退場
  const night: [number, Pose][] = [
    [PUSH, P(1.8, -0.34, -6, 0.04, -0.55, -0.03, 1.28)],
    [PUSH + HAND, P(0.3, -0.3, 0, 0.03, -0.15, 0, 1.3)],
    [EXIT0, P(0.3, -0.3, 0, 0.02, -0.11, 0, 1.31)],
    [EXIT1, P(0.32, -2.1, 0, -0.3, -0.16, -0.04, 1.3)],
  ];

  fly(RISE, RISE + 0.85, 0.6, -0.2);
  fly(T1 - 0.2, T1 + HAND, 0.55, 0);
  fly(PUSH, PUSH + HAND, 0.45, 0.4);
  fly(EXIT0, EXIT1, 0.5, 0);

  const k = (t: number, t0: number, t1: number) => back(soft(t, t0, t0 + RISE_K) * (1 - soft(t, t1, t1 + 0.35)));
  // 登入按鈕移動距離長（放大 2.4 倍、橫越半個畫面），回彈會越過預定位置碰到旁邊的按鈕，改用不回彈的平滑曲線
  const kFlat = (t: number, t0: number, t1: number) => soft(t, t0, t0 + RISE_K) * (1 - soft(t, t1, t1 + 0.35));
  const dim = (ps: Pop[]) => 1 - 0.4 * Math.max(0, ...ps.map((p) => Math.min(1, p.k)));

  /**
   * 登入按鈕：往右排成一列並放大 2.4 倍；通行密鑰按鈕放在這列下方、左緣對齊（座標取自 cuts.json，播放時才有）。
   * 目的地照 App 畫面原本的左右順序（Google、Apple、手機簡訊、LINE），浮出時間照旁白（Google、Apple、LINE、手機簡訊）。
   * 每顆按鈕都從螢幕下緣斜向右上飛到這一列，後出發的會從已就位的按鈕前方短暫飛過，所以越晚出發的 dz 越高、畫在前面。
   * 收回時通行密鑰先回去，按鈕再由近而遠依序收，往回飛時經過的位置都已清空。
   * 這段手機放在較高的位置（頂端約 y 258），按鈕原位（螢幕下緣）才不會落在字幕區。
   */
  const ICONS = ['google', 'apple', 'phone', 'line'] as const;
  const ICON_GROW = 1.4, KEY_GROW = 0.5, ROW_CY = 388;
  // 收回順序：通行密鑰 → 最近的 Google → Apple → 手機簡訊 → 最遠的 LINE
  const ICON_OFF = { google: KEY_OFF + 0.3, apple: KEY_OFF + 0.38, phone: KEY_OFF + 0.46, line: KEY_OFF + 0.54 };
  const DZ = { google: 0, apple: 0.1, line: 0.2, phone: 0.3 };
  const loginPops = (t: number): Pop[] => {
    const row = spreadAt(ICONS.map((i) => `cut_acc_${i}`), ICON_GROW, 'row', ROW_CY, 64);
    const ps: Pop[] = ICONS.map((id, i) => ({ id: `acc_${id}`, cut: `cut_acc_${id}`, k: kFlat(t, ICON_T[id], ICON_OFF[id]), grow: ICON_GROW, ...row[i], dz: DZ[id] }));
    const r = CUTS.cut_acc_passkey, g = CUTS.cut_acc_google;
    if (r && g) {
      const f = CUTS[`cut_acc_${ICONS[0]}`] ?? g;
      const left = f.x + f.w / 2 + row[0].dx - f.w * (1 + ICON_GROW) / 2;
      const cy = ROW_CY + g.h * (1 + ICON_GROW) / 2 + 28 + r.h * (1 + KEY_GROW) / 2;
      ps.push({ id: 'acc_passkey', cut: 'cut_acc_passkey', k: k(t, KEY, KEY_OFF), grow: KEY_GROW, dx: left + r.w * (1 + KEY_GROW) / 2 - (r.x + r.w / 2), dy: cy - (r.y + r.h / 2), dz: 0.4 });
    }
    return ps;
  };
  const LEVEL = ['cut_acc_level_card', 'cut_acc_points'];
  // 先浮出「目前累積 10 點」（旁白：完成交易可以累積點數），再浮出升級進度卡
  const LEVEL_T = [P0 + HALF, P0];

  return (t: number) => {
    word.at(t, 0.1, WORD_OUT);
    tA.at(t, WORD_OUT + 0.45, T1 - 0.05);
    tB.at(t, T1 + 0.6, PUSH - 0.05);
    tC.at(t, PUSH + 0.6, OUT - 0.75);
    langs.at(t, PUSH + 0.9, OUT - 0.75, langAt(t));

    if (t > WORD_OUT && t < T1 + HAND + 0.8) {
      const ps = loginPops(t);
      world.frame.phones[LOGIN] = { pose: glide(t, login, SIGMA), scr: { a: 'v_acc_login' }, glow: dim(ps), pops: ps };
    }
    if (t > T1 - 0.5 && t < OUT) {
      const out = spreadAt(LEVEL, 0.5, 'col', 460, 48);
      const ps: Pop[] = LEVEL.map((cut, i) => ({ id: `acc_level${i}`, cut, k: k(t, LEVEL_T[i], LEVEL_OFF), grow: 0.5, ...out[i], dz: i * 0.1 }));
      // 單一元件原地放大浮出，去背圖隨畫面語言切換（五種語言的列位置相同）
      ps.push({ id: 'acc_lang', cut: `cut_acc_lang_${LANGS[langAt(t)].tag}`, k: k(t, LANG_POP, LANG_OFF), grow: 0.8, dz: 0.4 });
      // 語言列浮出時螢幕只稍微變暗，淺色與深色兩支手機的對比仍看得出來
      const glow = Math.min(dim(ps.slice(0, LEVEL.length)), 1 - 0.2 * Math.min(1, ps[LEVEL.length].k));
      world.frame.phones[MAIN] = { pose: glide(t, main, SIGMA), scr: seq(t, light), glow, pops: ps };
    }
    if (t > PUSH - 0.5 && t < OUT) {
      world.frame.phones[DARK] = { pose: glide(t, night, SIGMA), scr: seq(t, dark) };
    }
  };
}
