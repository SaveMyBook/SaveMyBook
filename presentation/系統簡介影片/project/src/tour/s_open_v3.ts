import * as THREE from 'three';
import { cue, fly } from '../lib/cues';
import { SELLER, BUYER, type World, type Pop } from '../world';
import type { KioskParams } from '../three/textures';
import { span, type Pose } from '../lib/kf';
import { seq, type Step } from '../scenes/kit';
import { line, section } from './kit2';
import { glide, soft } from './kit4';
import { onBeat } from './kit5';
import { TitleV3 } from '../v3/title';
import { CameraPath, orbit, sequence, sectionPans, toCamera, type CamKey } from '../v3/camera';
import { fit } from '../v3/frame';
import { lift, slotColor, preloadSlots, float } from '../v3/pop';
import { kioskPop } from '../v3/kiosk';
import { BrandMark, BrandTitle, mixMark, stackToRow, markIn, HERO, ROW_F, ROW_Y, type MarkPose } from './x_open_v3';

const SEC = 'open';
type V = [number, number, number];

/**
 * v3 片頭（旁白 01 痛點、02 問卷 57.4%、03 品牌）。規則見 DESIGN.md「v3 規則」。
 * - 開場：logo 淡入並輕微放大（不放名稱，名稱留到 03 隨旁白出現）→ 鏡頭向左平移，logo 往右出畫。
 * - 01：買家手機由左側移入，畫面是約好面交的訊息對話（模擬的 iOS 訊息，不是本系統 App），
 *   「請問快到了嗎？」「？」依拍點送出、已讀未回 → 唸到「寄送又麻煩」時紙箱由右側翻滾落到手機右邊。
 * - 平移到 02：書櫃完整入鏡、鏡頭緩慢俯視環繞；唸到「書櫃最吸引人的是」時螢幕從原位朝鏡頭浮起，
 *   唸到「24 小時自助」時換一組 QR Code（無人值守、自助運作），之後落回。
 * - 平移到 03：書櫃往右出畫時 logo 開始淡入並輕微放大，配樂新段落的第一拍時完全出現；名稱隨旁白浮現 → 標誌縮成標題第一行，
 *   鏡頭向左平移到書櫃與賣家、買家兩支手機，標題補上「結合 App 與智慧書櫃／買賣雙方不必約時間見面」；
 *   買家畫面「請取出櫃門 A01 內的書籍」浮出 → 標題收起，標誌縮到左上角與 Corner 逐像素重合（18.48 秒交接），鏡頭向左移出。
 * 每句旁白只浮出一個元素：02 書櫃螢幕、03 取書卡片；01 的訊息不是本系統畫面，沒有去背元件，不做浮出。
 *
 * 畫面文字出處（複評版系統手冊，PDF 頁碼／印刷頁碼）：
 * - 「面交與寄送的不便，是二手書交易的主要障礙」：PDF 第 21 頁／p6（1-2 動機的結論）。
 * - 「約好面交，對方卻沒出現」：旁白 01「面交被放鳥」；PDF 第 19 頁／p4 圖 1-2-5「擔心遇到放鳥或詐騙」。
 * - 「又要自行包裝寄貨」：旁白 01「寄送又麻煩」；PDF 第 19 頁／p4 圖 1-2-6「需自行包裝、跑超商寄貨」。
 * - 「57.4%」「24 小時自助」：旁白 02；PDF 第 19 頁／p4 圖 1-2-8。
 * - 「498 份有效樣本」：PDF 第 16 頁／p1（1-2 動機）。
 * 手機畫面由 savemybook_app/tool/video_shots/open_test.dart 產生：書為正式站 book_id 150、新北高工書櫃 A01。
 */
export default function sOpenV3(world: World, ui: HTMLElement, _fx: HTMLElement) {
  world.cabinet.kiosk.setScale(4);
  const L2 = line('02');
  const LEN = section(SEC).end - section(SEC).start;
  const EXIT = LEN - 0.9;

  // ── 時間（段落內秒數）。旁白斷句：01「二手書交易」0.80–1.86、「最怕面交被放鳥」2.16–3.66、「寄送又麻煩」3.96–5.17；
  // 02「問卷中」5.67–6.43、「57.4% 的人認為」6.73–8.99、「書櫃最吸引人的是」9.29–10.93、「24 小時自助」11.01–12.40；
  // 03「救舊我的書」12.90–13.88、「結合 App 與智慧書櫃」14.18–15.88、「買賣雙方不必約時間見面」16.18–18.48。
  // 配樂：0–12.6 秒每拍 0.63 秒，12.6 秒起換段落（每拍 0.49 秒）。
  const LOGO0 = 0.1;
  const MOVE1 = onBeat(SEC, 1.26), MOVE1E = MOVE1 + 0.95;
  const MSG2 = onBeat(SEC, 2.52), MSG3 = onBeat(SEC, 3.15);
  const BOX0 = onBeat(SEC, 3.78), BOX1 = BOX0 + 0.62;
  const MOVE2 = onBeat(SEC, 5.04), MOVE2E = MOVE2 + 0.95;
  const KPOP = onBeat(SEC, 9.45), KDOWN = KPOP + 0.5 + 1.52;
  const FLASH = L2.at + 5.34;
  const LOGO3 = onBeat(SEC, 12.6);
  const MOVE3 = LOGO3 - 0.85, MOVE3E = MOVE3 + 0.95;
  // 03 的 logo 在書櫃出畫途中就開始淡入（畫面不停在空背景），第一拍時完全出現
  const LOGO3F = LOGO3 - 0.4;
  const NAME3 = onBeat(SEC, 13.0);
  // 標誌先縮成標題第一行，再平移到書櫃與手機：買家手機由左側橫越畫面時，標誌已在畫面頂端，不會和手機重疊
  const UP0 = onBeat(SEC, 13.58) + 0.25, UP1 = UP0 + 0.75;
  const MOVE4 = UP0 + 0.3, MOVE4E = MOVE4 + 0.95;
  const POP3 = onBeat(SEC, 15.05), POP3_OUT = POP3 + 0.5 + 1.52;
  const CORNER0 = EXIT - 0.3, CORNER1 = CORNER0 + 0.9;

  // ── 標題
  const t1 = new TitleV3(ui, ['約好面交，對方卻沒出現？', '改用寄送，又要自行包裝寄貨？'], '面交與寄送的不便，是二手書交易的主要障礙');
  const t2 = new TitleV3(ui, ['智慧書櫃最吸引人的是什麼？', '57.4% 選擇「24 小時自助」'], '問卷調查共取得 498 份有效樣本');
  const t3 = new BrandTitle(ui, '結合 App 與智慧書櫃', '買賣雙方不必約時間見面');
  const markA = new BrandMark(ui);
  const markB = new BrandMark(ui);
  world.later.push(() => preloadSlots(['cut_open_take']));

  // ── 鏡位：每個主體相隔 44 單位，依序向左（鏡頭向左平移，畫面內容往右走）
  const C0: V = [132, 0, 0], C1: V = [88, 0, 0], C2: V = [44, 0, 0], C3: V = [0, 0, 0], C4: V = [-44, 0, 0];
  const camH0 = new CameraPath([[0, orbit(C0, 0, 0.02, 60, [0, 0.5, 0])], [MOVE1, orbit(C0, 0.01, 0.02, 59.4, [0, 0.5, 0])]]);
  const cam1 = new CameraPath([[MOVE1E - 0.3, orbit(C1, 0.08, -0.05, 59, [0, 0.8, 0])], [MOVE2, orbit(C1, 0.03, -0.035, 58, [0, 0.8, 0])]]);
  const cam2 = new CameraPath([[MOVE2E - 0.3, orbit(C2, 0.34, 0.17, 58, [0, 0.4, 0])], [KPOP, orbit(C2, 0.2, 0.15, 57.5, [0, 0.4, 0])], [MOVE3, orbit(C2, 0.12, 0.13, 57, [0, 0.4, 0])]]);
  const camH3 = new CameraPath([[MOVE3E - 0.3, orbit(C3, 0, 0.02, 60, [0, 0.5, 0])], [MOVE4, orbit(C3, -0.01, 0.02, 59.4, [0, 0.5, 0])]]);
  const cam4 = new CameraPath([[MOVE4E - 0.3, orbit(C4, 0.05, 0.1, 64, [0, 0.4, 0])], [LEN, orbit(C4, -0.04, 0.085, 63, [0, 0.4, 0])]]);
  const camAt = (t: number) => sectionPans(sequence(t, [camH0, cam1, cam2, camH3, cam4], [
    { at: MOVE1, kind: 'move' }, { at: MOVE2, kind: 'move' }, { at: MOVE3, kind: 'move' }, { at: MOVE4, kind: 'move' },
  ]), t, LEN, { sec: SEC, in: false });

  // ── 擺位（取景工具依畫面位置反推）
  const drift = (p: Pose, d: Partial<Pose>): Pose => ({ ...p, ...Object.fromEntries(Object.entries(d).map(([k, v]) => [k, (p[k] ?? 0) + (v ?? 0)])) });
  // 01：買家手機在標題下方偏左、轉向右方，紙箱落下前往左讓位
  const KM1 = cam1.at(BOX0);
  const P1a = fit(world, KM1, 'phone', { cx: 900, cy: 628, h: 680, yaw: 0.34, rx: -0.03, rz: 0.035 });
  const P1b = fit(world, KM1, 'phone', { cx: 720, cy: 634, h: 680, yaw: 0.42, rx: -0.03, rz: 0.03 });
  // 平移到書櫃時鏡頭由仰拍升到俯拍，手機在畫面上會往下掉；平移途中略往上抬，不進入字幕帶
  const buy1: [number, Pose][] = [[MOVE1, drift(P1a, { ry: -0.06 })], [MOVE1E, P1a], [BOX0, drift(P1a, { ry: 0.02 })], [BOX1, P1b], [MOVE2, drift(P1b, { ry: 0.03 })], [MOVE2E, drift(P1b, { ry: 0.04, y: 3 / world.stage.halfH })]];
  // 紙箱：由畫面右側外翻滾落到手機右邊（只取位置，大小與角度另訂）
  const at1 = (cx: number, cy: number) => fit(world, KM1, 'phone', { cx, cy, h: 400 });
  const box = (p: Pose, rx: number, ry: number, rz: number, s: number): Pose => ({ x: p.x, y: p.y, z: p.z, rx, ry, rz, s });
  const BOXL = box(at1(1290, 742), 0.34, -0.58, 0.04, 1.42);
  const parcel: [number, Pose][] = [
    [BOX0 - 0.1, box(at1(2300, 610), 1.3, -2.5, 0.9, 1.42)],
    [BOX1, BOXL],
    [MOVE2E, drift(BOXL, { ry: 0.05 })],
  ];
  // 02：書櫃完整入鏡、先在畫面中央；螢幕浮出時書櫃往右讓位，螢幕往左上方的空白處浮出
  const PC2c = fit(world, cam2.at(7.5), 'cabinet', { cx: 1000, cy: 640, h: 620, yaw: 0.38 });
  const PC2r = fit(world, cam2.at(KPOP + 0.5), 'cabinet', { cx: 1200, cy: 646, h: 612, yaw: 0.46 });
  const cab2: [number, Pose][] = [[MOVE2E, PC2c], [KPOP - 0.3, drift(PC2c, { ry: -0.03 })], [KPOP + 0.5, PC2r], [MOVE3, drift(PC2r, { ry: -0.03 })]];
  // 03：書櫃在中央、賣家與買家手機在兩側且離鏡頭較近，與標題左右錯開（標題在平移接近結束時才完全出現）
  const KM4 = cam4.at(POP3);
  const PC4 = fit(world, KM4, 'cabinet', { cx: 960, cy: 668, h: 590, yaw: 0.12 });
  const PS = fit(world, KM4, 'phone', { cx: 440, cy: 612, h: 700, yaw: 0.5, rx: -0.03, rz: 0.04, depth: 52 });
  const PB = fit(world, KM4, 'phone', { cx: 1480, cy: 612, h: 700, yaw: -0.5, rx: -0.03, rz: -0.04, depth: 52 });
  const sell4: [number, Pose][] = [[MOVE4, drift(PS, { ry: 0.05 })], [LEN, drift(PS, { ry: -0.04 })]];
  const buy4: [number, Pose][] = [[MOVE4, drift(PB, { ry: -0.05 })], [LEN, drift(PB, { ry: 0.04 })]];
  const cab4: [number, Pose][] = [[MOVE4, drift(PC4, { ry: 0.04 })], [LEN, drift(PC4, { ry: -0.04 })]];

  // 開場 logo 固定在 3D 空間中的一點：鏡頭平移時與其他物件同步往右出畫
  const HERO0 = { x: 960, y: 480 };
  const K0 = camH0.at(0);
  const anchor = (() => {
    const cam = toCamera(K0);
    const eye = new THREE.Vector3(...K0.pos);
    const fwd = new THREE.Vector3(...K0.look).sub(eye).normalize();
    const dir = new THREE.Vector3(HERO0.x / 960 - 1, 1 - HERO0.y / 540, 0.5).unproject(cam).sub(eye).normalize();
    return eye.clone().add(dir.multiplyScalar(60 / dir.dot(fwd)));
  })();
  const project = (k: CamKey) => {
    const cam = toCamera(k);
    const v = anchor.clone().project(cam);
    const depth = anchor.clone().sub(new THREE.Vector3(...k.pos)).dot(new THREE.Vector3(...k.look).sub(new THREE.Vector3(...k.pos)).normalize());
    return { x: (v.x + 1) / 2 * 1920, y: (1 - v.y) / 2 * 1080, k: 60 / depth };
  };

  const meetSteps: Step[] = [[-9, 'v_open_meet_1'], [MSG2, 'v_open_meet_2', 0, 0.001], [MSG3, 'v_open_meet_3', 0, 0.001]];

  // 書櫃螢幕：QR Code 約每 30 秒更新，唸到「24 小時自助」時換一組（倒數條歸零、換碼瞬間閃白）
  const kiosk = (t: number, cam: CamKey, cab: Pose, popOn: boolean): KioskParams => ({
    state: 'qr',
    refresh: ((t - FLASH) / 30 + 1) % 1,
    seconds: 30,
    digits: 1,
    check: 0,
    qr: t >= FLASH ? 1 : 0,
    clock: '14:25',
    flash: Math.max(0, 1 - Math.abs(t - FLASH) / 0.22),
    tick: t,
    pop: popOn ? kioskPop(world, lift(t, KPOP, KDOWN), cam, cab, { toward: 10, left: 3.0, up: -0.5, scale: 1.85 }) : undefined,
  });


  // ── 音效：只對應本段畫面上的動作
  cue('glint', LOGO0 + 0.4, { gain: 0.6 });
  fly(MOVE1, MOVE1E, 0.5, 0.3);
  cue('send', MSG2, { gain: 0.6, pan: -0.2 });
  cue('send', MSG3, { gain: 0.6, pan: -0.2 });
  fly(BOX0 - 0.1, BOX1, 0.5, 0.5);
  cue('box', BOX1, { gain: 0.7, pan: 0.4 });
  fly(MOVE2, MOVE2E, 0.5, 0.3);
  cue('lift', KPOP, { gain: 0.7, pan: -0.2 });
  cue('digital', FLASH, { gain: 0.5, pan: -0.2 });
  cue('pop', KDOWN + 0.25, { gain: 0.35, pan: 0.2 });
  fly(MOVE3, MOVE3E, 0.5, 0.3);
  cue('textin', NAME3 + 0.05, { gain: 0.8 });
  cue('shimmer', LOGO3 + 0.35, { gain: 0.5 });
  fly(MOVE4, MOVE4E, 0.5, 0.2);
  cue('pop', POP3, { gain: 0.5, pan: 0.4 });
  // 標誌縮到左上角與鏡頭移出幾乎同時，只登記一聲
  fly(EXIT, LEN, 0.5, 0.3);

  return (t: number) => {
    // 段落結束（18.48 秒）起標誌交給 Corner，本段不再顯示任何東西，避免同時出現兩份
    if (t >= LEN) {
      markA.at(t, false, logoOnly(1), 0, 0, 0);
      markB.at(t, false, logoOnly(1), 0, 0, 0);
      t1.at(t, 99, 99);
      t2.at(t, 99, 99);
      t3.at(t, 99, 99);
      return;
    }


    const cam = camAt(t);
    world.frame.camera = cam;

    t1.at(t, MOVE1 + 0.62, MOVE2 - 0.3);
    t2.at(t, MOVE2E - 0.05, MOVE3 - 0.4);
    t3.at(t, MOVE4 + 0.7, EXIT - 0.58);

    // 開場 logo：淡入並輕微放大，鏡頭平移時跟著 3D 空間往右出畫
    const pa = project(cam);
    const grow = 1 + 0.025 * soft(t, LOGO0, MOVE1 + 0.5);
    const inA = markIn(t, LOGO0);
    markA.at(t, t >= LOGO0 - 0.01 && t < MOVE1E, logoOnly(pa.k * grow, pa.x, pa.y), LOGO0 - 1.95, inA.fade, 0, inA.grow);

    // 品牌段標誌：直式淡入 → 縮成標題第一行 → 縮到左上角
    const hero = markB.stackPose(960, HERO.logoY, HERO.logoS, HERO.nameY, HERO.nameF);
    const row = markB.rowPose(ROW_F, 960, ROW_Y);
    const corner = markB.cornerPose();
    let p: MarkPose;
    if (t < UP0) p = hero;
    else if (t < CORNER0) p = stackToRow(hero, row, t, UP0, UP1);
    else if (t < CORNER1) p = mixMark(row, corner, soft(t, CORNER0, CORNER1), soft(t, CORNER0 + 0.06, CORNER1));
    else p = corner;
    const inB = markIn(t, LOGO3F);
    markB.at(t, t >= LOGO3F - 0.01, p, LOGO3 - 1.95, inB.fade, span(t, NAME3, NAME3 + 0.5), inB.grow);

    // 01：訊息對話與紙箱
    if (t > MOVE1 - 0.05 && t < MOVE2E + 0.05) {
      world.frame.phones[BUYER] = { pose: glide(t, buy1, 0.42), scr: seq(t, meetSteps) };
      if (t > BOX0 - 0.15) world.frame.parcel = glide(t, parcel, 0.3);
    }
    // 02：書櫃與螢幕浮出
    if (t > MOVE2 - 0.05 && t < MOVE3E + 0.05) {
      const pose = glide(t, cab2, 0.42);
      world.frame.cabinet = { pose, kiosk: kiosk(t, cam, pose, true) };
    }
    // 03：書櫃與兩支手機，買家的取書卡片浮出
    if (t > MOVE4 - 0.05) {
      const pose = glide(t, cab4, 0.42);
      world.frame.cabinet = { pose, kiosk: { ...kiosk(t, cam, pose, false), flash: 0 } };
      const k = lift(t, POP3, POP3_OUT), f = float(t, k, 0.7);
      const take: Pop[] = [{ id: 'ov3_take', cut: 'cut_open_take', k, grow: 0.3, dx: -40 + f.dx, dy: 30 + f.dy, dz: 2.2 + f.dz, slot: slotColor('cut_open_take') }];
      world.frame.phones[SELLER] = { pose: glide(t, sell4, 0.42), scr: { a: 'v_open_deposit' } };
      world.frame.phones[BUYER] = { pose: glide(t, buy4, 0.42), scr: { a: 'v_open_pickup' }, pops: take };
    }
  };
}

/** 開場 logo（不放名稱）：中心 (x, y)、縮放 k 倍。 */
function logoOnly(k: number, x = 960, y = 480): MarkPose {
  return { lx: x, ly: y, ls: HERO.logoS * k, nx: 0, ny: 0, nf: 1 };
}
