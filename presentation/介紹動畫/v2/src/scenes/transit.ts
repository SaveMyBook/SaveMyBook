import { span, type Pose } from '../lib/kf';
import { cue, fly } from '../lib/cues';
import { BUYER, ADMIN, type World } from '../world';
import { Headline, Caption, Chips, Mark, Tap, Tag, at, frame, seq, stepCues, track, scrollKeys, mix, easeIn, type Step } from './kit';
import { GUIDE, ADMIN_R } from './story';

/**
 * 前往書櫃（買家海嫄）：點開存書通知 → 前往書櫃頁依序捲過捷運、公車、YouBike、開車 → 管理員新增書櫃時帶入目前座標。
 * 旁白（段落內秒數）：transit1 1.4、transit2 10.0。交通資料取自 data.taipei 的實際資料（見 assets-src/transit_nearby.json）。
 */
export function transit(world: World, ui: HTMLElement) {
  const t2 = at('transit2');
  const head1 = new Headline(ui, '前往書櫃，交通一次看清', '整合臺北市政府開放資料');
  const head2 = new Headline(ui, '設置書櫃，帶入目前位置', '管理員新增書櫃時，一鍵取得所在位置的座標');
  const source = new Chips(ui, ['資料來源：臺北市資料大平臺（data.taipei）'], 'chips--meta');
  // 長截圖捲動：每張卡片的頂端停在螢幕 y=TOP（標題列下方）
  const TOP = 150;
  const offOf = (y: number) => (y - TOP) / 852;
  const KEYS: [number, number][] = [
    [3.35, 0], [3.85, offOf(GUIDE.mrt.y)], [4.9, offOf(GUIDE.mrt.y)], [5.4, offOf(GUIDE.bus.y)],
    [6.4, offOf(GUIDE.bus.y)], [6.9, offOf(GUIDE.youbike.y)], [7.7, offOf(GUIDE.youbike.y)], [8.2, offOf(GUIDE.drive.y)],
  ];
  const scroll = (name: string, t: number) => (name === 'b_guide_long' ? scrollKeys(t, KEYS) : 0);
  const steps: Step[] = [[0, 'b_home'], [0.75, 'b_guide_long', 1, 0.45]];
  stepCues(steps);
  for (let i = 0; i < KEYS.length - 1; i += 2) cue('swipe', KEYS[i][0], { gain: 0.4 });
  const tapBanner = new Tap(ui, BUYER, GUIDE.banner.x + GUIDE.banner.w / 2, GUIDE.banner.y + GUIDE.banner.h / 2, 0.15);
  // 開車卡比螢幕高，只框出螢幕內看得到的部分
  const driveVisible = { ...GUIDE.drive, h: 830 - TOP };
  const cards = [
    { base: GUIDE.mrt, t0: 3.9, t1: 4.9, cap: new Caption(ui, '捷運', '最近車站與出口', '大安森林公園站 520 公尺，出口 5 設有無障礙電梯；並依出發站計算票價', 120) },
    { base: GUIDE.bus, t0: 5.45, t1: 6.4, cap: new Caption(ui, '公車', '附近站牌即時到站', '大安國宅站：38、298、紅57', 120) },
    { base: GUIDE.youbike, t0: 6.95, t1: 7.7, cap: new Caption(ui, 'YouBike 2.0', '可借與可還數量', '臺北市立圖書館（總館）站 50 公尺', 120) },
    { base: driveVisible, t0: 8.25, t1: 9.0, cap: new Caption(ui, '開車與計程車', '路況與停車場空位', '建國南路高架橋下停車場 B 區，距離 50 公尺', 120) },
  ].map((c) => ({ ...c, mark: new Mark(ui, BUYER, c.base) }));
  cards.forEach((c) => cue('select', c.t0 + 0.05, { gain: 0.6 }));
  const adminTag = new Tag(ui, ADMIN, '管理員', '');
  const LOC = t2 + 1.2;
  const tapLoc = new Tap(ui, ADMIN, ADMIN_R.locBtn.x + ADMIN_R.locBtn.w / 2, ADMIN_R.locBtn.y + ADMIN_R.locBtn.h / 2, LOC);
  const adminSteps: Step[] = [[0, 'a_cabinet_pre'], [LOC + 0.55, 'a_cabinet_edit', 0, 0.3]];
  const markLoc = new Mark(ui, ADMIN, ADMIN_R.coords).register(LOC + 1.2);
  const markPrev = new Mark(ui, ADMIN, ADMIN_R.preview).register(13.45);
  const capLoc = new Caption(ui, '取得目前座標', '一鍵帶入經緯度', '同時顯示定位精確度', 120);
  const capPrev = new Caption(ui, '確認位置', '預覽附近的交通', '用來確認座標與地址是否相符', 120);
  cue('sonar', LOC + 0.4, { gain: 0.7 });
  fly(9.0, 10.0, 0.6, -0.4);
  fly(14.7, 15.5, 0.5);

  const CENTER: Pose = { x: 0, y: -0.12, z: 0, rx: 0.03, ry: 0, rz: 0, s: 1.15 };
  // 卡片頂端停在 TOP，取景涵蓋 TOP 以下的螢幕
  const READ = frame({ x: 0, y: 140, w: 393, h: 560 }, 1150, 560, 600);
  const locF = frame({ x: 20, y: 318, w: 353, h: 345 }, 1150, 560, 560);

  return (t: number) => {
    const f = world.frame;
    head1.at(t, 1.2, 2.3);
    head2.at(t, t2 - 0.2, LOC + 0.2);
    source.at(t, 3.4, 9.0, 120, 860);
    if (t > -0.5 && t < 10.1) {
      let pose = track(t, [[-0.5, CENTER], [2.75, CENTER], [3.35, READ], [9.0, READ]]);
      pose = mix(pose, { ...READ, x: 1.2, y: -0.3, ry: -1.5, z: -20, s: 1.0 }, easeIn(span(t, 9.0, 10.0)));
      f.phones[BUYER] = { pose, scr: seq(t, steps, scroll) };
    }
    tapBanner.at(world, t);
    const off = scrollKeys(t, KEYS);
    cards.forEach((c) => {
      // 長截圖捲動後，卡片在螢幕上的位置＝長圖中的位置－捲動量
      c.mark.rect = { ...c.base, y: c.base.y - off * 852 };
      c.mark.at(world, t, c.t0, c.t1);
      c.cap.at(t, c.t0, c.t1, 520);
    });
    if (t > 8.9 && t < 15.6) {
      let pose = track(t, [[9.25, { ...CENTER, x: -1.3, y: -0.4, z: -14, rx: 0.15, ry: 1.45, rz: 0.1 }], [9.85, { ...CENTER, x: -0.12, z: 3, ry: 0.34, rz: 0.03 }], [10.25, CENTER], [LOC + 0.65, CENTER], [LOC + 1.2, locF], [14.3, locF], [14.7, CENTER]]);
      pose = mix(pose, { ...CENTER, y: -2.2, rx: 0.4 }, easeIn(span(t, 14.7, 15.5)));
      f.phones[ADMIN] = { pose, scr: seq(t, adminSteps) };
    }
    adminTag.at(world, t, 10.0, LOC + 0.4);
    tapLoc.at(world, t);
    markLoc.at(world, t, LOC + 1.25, 13.1);
    markPrev.at(world, t, 13.5, 14.25);
    capLoc.at(t, LOC + 1.25, 13.05, 520);
    capPrev.at(t, 13.5, 14.2, 520);
  };
}
