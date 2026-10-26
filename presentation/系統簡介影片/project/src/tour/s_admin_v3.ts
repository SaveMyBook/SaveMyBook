import { cue, fly } from '../lib/cues';
import { ADMIN, SEQS, type World, type Pop } from '../world';
import type { KioskParams } from '../three/textures';
import type { Pose } from '../lib/kf';
import { seq, frameSteps, type Step } from '../scenes/kit';
import { line, section } from './kit2';
import { glide } from './kit4';
import { onBeat, TapOn } from './kit5';
import { PopBox } from './x_cabinet';
import { TitleV3 } from '../v3/title';
import { CameraPath, sequence, sectionPans, type CamKey } from '../v3/camera';
import { fit } from '../v3/frame';
import { lift, slotColor, preloadSlots, float } from '../v3/pop';
import { kioskPop } from '../v3/kiosk';

const SEC = 'admin';

/**
 * v3 管理後台（旁白 22 後台模組、23 配對新書櫃）。規則見 DESIGN.md「v3 規則」，寫法照 s_cabinet_v3.ts。
 * - 22：管理員手機在標題下方、略為俯拍，管理後台首頁往下捲到四個模組都在畫面上，「內容審核」一列往右浮出（旁白念到上架審核）。
 * - 推入書櫃裝置頁後鏡頭向左平移：同一支手機往右移到書櫃右前方，書櫃由左側進入並完整入鏡。
 * - 23：點「配對裝置」→ 書櫃螢幕從原位朝鏡頭浮起，顯示八位數配對碼（8 碼一列，同韌體）→ 手機對話框逐字輸入同一組配對碼
 *   → 點「配對裝置」→ 螢幕落回 → 等待裝置連線 → 完成配對，書櫃螢幕同時改為 QR Code 閒置畫面。
 * 每句旁白只浮出一個元素：22「內容審核」列、23 書櫃螢幕；手機上的逐字輸入由手機在書櫃右前方、離鏡頭較近的構圖交代。
 * 配對碼效期 10 分鐘、配對後閒置時顯示 QR Code：複評版手冊 PDF 第 127 頁（圖 6-1-30 書櫃裝置配對之循序圖說明）。
 */
export default function sAdminV3(world: World, ui: HTMLElement, _fx: HTMLElement) {
  world.cabinet.kiosk.setScale(4);
  const L22 = line('22'), L23 = line('23');
  const LEN = section(SEC).end - section(SEC).start;

  // ── 時間（段落內秒數）
  // 22：tts/22.wav「管理後台整合在 App 中，」約 0–1.95（句內秒數），「可以處理上架審核」約 2.25 起
  const SCROLL0 = onBeat(SEC, L22.at + 1.35), SCROLL1 = SCROLL0 + 0.45;
  const RP0 = onBeat(SEC, L22.at + 2.27), RP1 = RP0 + 0.5 + 1.51;
  // 「內容審核」落回後才推入書櫃裝置頁（推入途中元件還浮著會蓋在滑動的頁面上），推入完成後鏡頭向左平移到書櫃
  const PUSH = RP1 + 0.37;
  const MOVE0 = PUSH + 0.5, MOVE1 = MOVE0 + 0.95;
  // 23：tts/23.wav「輸入書櫃螢幕上的八位數配對碼，」約 0–2.9、「就能連線新書櫃」約 3.15 起（句內秒數）
  const TAP_OPEN = MOVE1 + 0.15;
  const DIALOG = TAP_OPEN + 0.12;
  const KPOP = onBeat(SEC, L23.at + 0.5);
  const TYPE0 = KPOP + 0.72, TYPE1 = TYPE0 + 1.0;
  const TAP_PAIR = TYPE1 + 0.07;
  const WAIT = TAP_PAIR + 0.38;
  const KDOWN = KPOP + 0.5 + 1.58;
  const DONE = onBeat(SEC, L23.at + 3.3);
  const EXIT = LEN - 0.9;

  // ── 標題（情境＋解法）
  // 旁白 22
  const tA = new TitleV3(ui, ['管理工作需要另一套系統？', 'App 內建管理後台'], '上架審核、訂單、爭議與公告集中處理');
  // 旁白 23；效期 10 分鐘：複評版手冊 PDF 第 127 頁
  const tB = new TitleV3(ui, ['新書櫃如何加入系統？', '輸入螢幕上的配對碼'], '書櫃螢幕顯示八位數配對碼，效期 10 分鐘');
  const popBox = new PopBox(ui);
  const taps = [
    new TapOn(ui, ADMIN, 'tap_adm_pair_open', TAP_OPEN - 0.32),
    new TapOn(ui, ADMIN, 'tap_adm_pair', TAP_PAIR - 0.32),
  ];
  world.later.push(() => preloadSlots(['cut_adm_review']));
  // 段落外（前後各 1 秒，圖層仍顯示）場景不更新，標題要先藏起來，否則會以初始狀態疊在相鄰段落上
  [tA, tB].forEach((x) => x.at(-99, 0, 1));

  // ── 鏡頭：A 管理員手機（略為俯拍）→ 向左平移到 B（書櫃在左、手機在右前方），視線方向相同
  const D = 25;
  const KA: CamKey = { pos: [0.4, 5.2, 60], look: [0.2, 0.6, 0] };
  const KA2: CamKey = { pos: [-0.2, 4.6, 59], look: [0.1, 0.6, 0] };
  const KB: CamKey = { pos: [-D - 0.6, 3.6, 59.5], look: [-D - 0.2, 0.9, 0] };
  // 逐字輸入時鏡頭慢慢推近、轉向手機，交代手機上的輸入（書櫃仍完整入鏡）
  const KB2: CamKey = { pos: [-D + 0.3, 3.0, 57.4], look: [-D + 0.8, 0.9, 0] };
  const camA = new CameraPath([[0, KA], [MOVE0, KA2]]);
  const camB = new CameraPath([[MOVE1 - 0.3, KB], [TYPE0 - 0.2, KB], [WAIT + 0.2, KB2], [LEN, KB2]]);

  // 管理員手機：標題下方、螢幕轉向右側；「內容審核」列往右浮出
  const PA = fit(world, KA, 'phone', { cx: 900, cy: 628, h: 668, yaw: 0.28, rx: -0.1, rz: -0.03 });
  const PA2 = fit(world, KA, 'phone', { cx: 860, cy: 630, h: 660, yaw: 0.33, rx: -0.1, rz: -0.03 });
  // 書櫃：畫面左側、完整入鏡；手機：書櫃右前方、離鏡頭較近、轉向書櫃
  const PC = fit(world, KB, 'cabinet', { cx: 760, cy: 636, h: 620, yaw: 0.4 });
  const PB = fit(world, KB, 'phone', { cx: 1555, cy: 590, h: 740, yaw: -0.3, rx: 0.02, rz: -0.02, depth: 44 });
  const drift = (p: Pose, d: Partial<Pose>): Pose => ({ ...p, ...Object.fromEntries(Object.entries(d).map(([k, v]) => [k, (p[k] ?? 0) + (v ?? 0)])) });

  const phone: [number, Pose][] = [
    // 等待浮出前緩慢轉向，畫面不完全靜止
    [0, drift(PA, { ry: -0.08, rz: 0.01 })],
    [RP0, PA],
    [RP0 + 0.6, PA2],
    [MOVE0, drift(PA2, { ry: 0.02 })],
    [MOVE1, PB],
    [DONE, drift(PB, { ry: 0.04 })],
    [LEN, drift(PB, { ry: 0.06, rz: 0.005 })],
  ];
  const cab: [number, Pose][] = [[MOVE0, PC], [LEN, drift(PC, { ry: -0.08 })]];

  let steps: Step[] | null = null;
  const build = (): Step[] => [
    [-9, 'v_adm_home'],
    ...frameSteps((SEQS.adm_scroll ?? []).slice(1), SCROLL0, SCROLL1),
    [PUSH, 'v_adm_device', 1, 0.5],
    [DIALOG, 'v_adm_pair_t00', 0, 0.12],
    ...frameSteps((SEQS.adm_pair_type ?? []).slice(1), TYPE0, TYPE1),
    [WAIT, 'v_adm_pair_wait', 0, 0.001],
    [DONE, 'v_adm_pair_done', 0, 0.001],
  ];

  // ── 書櫃螢幕：配對碼（效期 10 分鐘倒數）→ 完成配對後改為 QR Code 閒置畫面
  const kiosk = (t: number, cam: CamKey, pose: Pose): KioskParams => {
    const pop = kioskPop(world, lift(t, KPOP, KDOWN), cam, pose, { toward: 9, left: 3.0, up: -0.45, scale: 1.85 });
    if (t < DONE) return { state: 'pair', refresh: 0, seconds: 582 - Math.floor(Math.max(0, t - MOVE0)), digits: 1, check: 0, code: '0151-7752', total: 600, clock: '14:25', pop };
    return { state: 'qr', refresh: (t - DONE) / 30, seconds: 60, digits: 1, check: 0, qr: 2, clock: '14:25', flash: Math.max(0, 1 - Math.abs(t - DONE - 0.12) / 0.2), pop };
  };


  fly(0, 0.9, 0.5, 0.2);
  cue('swipe', SCROLL0, { gain: 0.4 });
  cue('pop', RP0 + 0.05, { gain: 0.5, pan: 0.2 });
  cue('swipe', PUSH, { gain: 0.8 });
  fly(MOVE0, MOVE1, 0.5, 0.3);
  cue('sheet', DIALOG, { gain: 0.5, pan: 0.5 });
  cue('lift', KPOP, { gain: 0.7, pan: -0.5 });
  for (let i = 0; i < 8; i++) cue('key', TYPE0 + (i / 7) * (TYPE1 - TYPE0), { gain: 0.35, pan: 0.5 });
  cue('pop', KDOWN + 0.25, { gain: 0.35, pan: -0.5 });
  cue('success', DONE + 0.05, { gain: 0.9, pan: 0.3 });
  cue('digital', DONE + 0.1, { gain: 0.6, pan: -0.4 });
  fly(EXIT, LEN, 0.5, 0.3);

  return (t: number) => {
    tA.at(t, 1.0, MOVE0 - 0.4);
    tB.at(t, MOVE1 + 0.1, EXIT - 0.45);
    // 浮出外框與點擊要在書櫃、手機寫入這一格之後更新；段落外也要更新一次才會藏起來
    const marks = () => { popBox.at(world); taps.forEach((tp) => tp.at(world, t)); };
    if (t < -0.05 || t > LEN + 0.05) { marks(); return; }

    const cam = sectionPans(sequence(t, [camA, camB], [{ at: MOVE0, kind: 'move' }]), t, LEN, { sec: SEC });
    world.frame.camera = cam;

    steps ??= SEQS.adm_scroll && SEQS.adm_pair_type ? build() : null;
    const kr = lift(t, RP0, RP1), fr = float(t, kr);
    const ps: Pop[] = [
      { id: 'adm3_review', cut: 'cut_adm_review', k: kr, grow: 0.38, dx: 470 + fr.dx, dy: 50 + fr.dy, dz: 2.4 + fr.dz, slot: slotColor('cut_adm_review') },
    ];
    world.frame.phones[ADMIN] = { pose: glide(t, phone, 0.42), scr: steps ? seq(t, steps) : { a: 'v_adm_home' }, pops: ps };
    if (t > MOVE0 - 0.05) {
      const pose = glide(t, cab, 0.42);
      world.frame.cabinet = { pose, kiosk: kiosk(t, cam, pose) };
    }
    marks();
  };
}
