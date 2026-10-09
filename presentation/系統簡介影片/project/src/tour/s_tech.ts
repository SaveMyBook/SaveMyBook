import { type Pose } from '../lib/kf';
import { cue, fly, roll } from '../lib/cues';
import { BUYER, type World } from '../world';
import { line, section } from './kit2';
import { ChapterWord, glide, soft } from './kit4';
import { onBeat } from './kit5';
import { TechLabel, Stat, DevBoard } from './x_tech';

const SEC = 'tech';
const SIGMA = 0.42;

/**
 * 第 9 章 技術架構（旁白 24 四項技術、24b API 與測試數量）。
 * 版面依實際架構排列，不畫連線：左側 App（Flutter）、右側書櫃（ESP32-S3），兩者都經 API 存取的後端放在中間（Node.js 之下為 MariaDB）。
 * 章名 → 手機與書櫃各自從正下方平行升起到靠近中間的位置（旁白「系統以」），念到 Node.js 前往兩側讓出中間；旁白念到哪項技術，名稱就在對應的位置升起：
 *   Flutter 在手機上方、Node.js 與 MariaDB 在中間、ESP32-S3 在書櫃上方；念到 ESP32-S3 時書櫃轉為透視，
 *   頂列的控制板轉為品牌藍，ESP32-S3 開發板由該處抬出到櫃子前方並放大，停留後收回
 * → 中間改為 301 個 API、4,000+ 項自動化測試的滾動數字 → 手機與書櫃往下退場。
 * 旁白 24 的四個技術名稱都已在畫面上，該句不燒入字幕（audio/subs_hide.json）。
 * 出處（複評版手冊，頁碼為頁面印刷頁碼）：p23 業務邏輯與應用層（Node.js、Express.js，同一行程以 Socket.IO 即時推送）；
 *   p25–27 表 3-2-4（Flutter 行動端、MariaDB 資料庫、ESP32-S3 負責電磁鎖與螢幕控制）；
 *   p118「App 與智慧書櫃終端（ESP32-S3）皆經 API 元件存取後端」；
 *   p216 後端 11 組測試群組 1,558 項、Flutter 實際執行 2,571 項，全數通過；301 個 API 出自旁白（savemybook_api/routes 的路由宣告數）。
 */
export function sTech(world: World, ui: HTMLElement, fx: HTMLElement) {
  const L24 = line('24'), L24b = line('24b');
  const OUT = L24b.end;
  const LEN = section('tech').end - section('tech').start;

  // 開場時手機與書櫃靠近中間，後端名稱出現前再往兩側讓位，中間不留長時間的空白
  const PHONE_X = -0.6, CAB_X = 0.6, NEAR = 0.42;
  // 兩側標籤放在物件上方、往內偏一點：左上角的 logo（main.ts 的 Corner）約占 x < 330、y < 110，標籤任何時刻都要在它的右下方
  const LABEL_Y = 172, INSET = 40;
  const word = new ChapterWord(fx, '技術架構');
  const flutter = new TechLabel(ui, 'Flutter', '行動 App', 960 + PHONE_X * 960 + INSET, LABEL_Y);
  const esp = new TechLabel(ui, 'ESP32-S3', '書櫃控制', 960 + CAB_X * 960 - INSET, LABEL_Y);
  const node = new TechLabel(ui, 'Node.js', 'Express API・Socket.IO', 960, 410);
  const maria = new TechLabel(ui, 'MariaDB', '資料庫', 960, 600);
  const api = new Stat(ui, 301, '個 API', 'App 與書櫃皆經由 API 存取後端', false, 960, 440);
  const tests = new Stat(ui, 4000, '項自動化測試　全數通過', '後端 1,558 項、前端 2,571 項', true, 960, 440);

  const WORD_OUT = 1.0;
  const RISE = WORD_OUT + 0.02;
  const BEAT = onBeat(SEC, 5) - onBeat(SEC, 4.6);
  const half = (t: number) => onBeat(SEC, t - BEAT / 2) + BEAT / 2;
  // 名稱出現時間依旁白（tts/24.wav 的停頓：Flutter 約 2.63、Node.js 3.78、MariaDB 5.09、ESP32-S3 6.35），對齊拍點與半拍
  const T_FL = onBeat(SEC, L24.at + 1.3);
  const T_NODE = half(L24.at + 2.45);
  const T_DB = half(L24.at + 3.9);
  const T_ESP = onBeat(SEC, L24.at + 5.1);
  // 透視 → 開發板抬出、完全浮出後停 1.2 秒以上 → 收回
  const XRAY = T_ESP + 0.25;
  const LIFT = onBeat(SEC, XRAY + 0.55);
  const DROP = onBeat(SEC, LIFT + 0.7 + 1.5);
  // 24b：中間的名稱收起 → 301 個 API → 4,000+ 項測試
  const MID_OUT = L24b.at - 0.4;
  const N1 = onBeat(SEC, L24b.at - 0.05), R1 = N1 + 0.2;
  const N2 = onBeat(SEC, L24b.at + 2.1), R2 = N2 + 0.2;
  const EXIT0 = OUT - 0.95, EXIT1 = OUT - 0.05;
  // 兩側標籤在手機與書櫃退場前收完
  const LABEL_OUT = EXIT0 - 0.6;
  const PART0 = T_NODE - 0.35, PART1 = T_NODE + 0.75;

  roll(R1, 1.1, 0, 0.8);
  roll(R2, 1.3, 0, 0.8);
  [T_FL, T_NODE, T_DB, T_ESP].forEach((t) => cue('textin', t + 0.05, { gain: 0.55 }));
  cue('scan', XRAY, { dur: 0.6, gain: 0.7, pan: 0.4 });
  cue('lift', LIFT, { gain: 0.8, pan: 0.4 });
  cue('swipe', DROP, { gain: 0.4, pan: 0.4 });

  const P = (x: number, y: number, z: number, rx: number, ry: number, rz: number, s: number): Pose => ({ x, y, z, rx, ry, rz, s });
  // App 手機：從正下方升起 → 慢推並緩慢轉向 → 往下退場
  const phone: [number, Pose][] = [
    [RISE, P(-NEAR, -2.0, 0, 0.5, 0.5, -0.08, 1.35)],
    [RISE + 1.15, P(-NEAR, -0.3, 0, 0.06, 0.22, -0.01, 1.35)],
    [PART0, P(-NEAR - 0.01, -0.3, 0, 0.04, 0.2, 0, 1.36)],
    [PART1, P(PHONE_X, -0.3, 0, 0.04, 0.3, 0, 1.35)],
    [T_ESP + 0.3, P(PHONE_X + 0.01, -0.3, 0, 0.03, 0.26, 0, 1.36)],
    [EXIT0, P(PHONE_X + 0.02, -0.3, 0, 0.02, 0.16, 0, 1.38)],
    [EXIT1, P(PHONE_X, -2.1, 0, -0.3, 0.2, 0.04, 1.35)],
  ];
  // 書櫃：從正下方升起 → 透視時稍微轉正讓開發板抬出 → 緩慢轉向 → 往下退場
  const cab: [number, Pose][] = [
    [RISE + 0.1, P(NEAR, -1.95, 0, 0.12, -0.75, 0, 1.22)],
    [RISE + 1.25, P(NEAR, -0.06, 0, 0.06, -0.45, 0, 1.22)],
    [PART0, P(NEAR + 0.01, -0.06, 0, 0.06, -0.43, 0, 1.22)],
    [PART1, P(CAB_X, -0.06, 0, 0.06, -0.5, 0, 1.22)],
    [XRAY, P(CAB_X - 0.01, -0.06, 0, 0.05, -0.42, 0, 1.23)],
    [DROP + 0.5, P(CAB_X - 0.01, -0.06, 0, 0.05, -0.36, 0, 1.24)],
    [EXIT0, P(CAB_X - 0.02, -0.06, 0, 0.05, -0.3, 0, 1.25)],
    [EXIT1, P(CAB_X, -2.0, 0, -0.2, -0.24, 0, 1.22)],
  ];

  fly(RISE, RISE + 1.25, 0.6, 0);
  fly(PART0, PART1, 0.35, 0);
  fly(EXIT0, EXIT1, 0.5, 0);

  const dev = new DevBoard(world);

  return (t: number) => {
    word.at(t, 0.1, WORD_OUT);
    const pose = glide(t, phone, SIGMA);
    flutter.at(t, T_FL, LABEL_OUT, 960 + (pose.x ?? 0) * 960 + INSET);
    esp.at(t, T_ESP, LABEL_OUT);
    node.at(t, T_NODE, MID_OUT);
    maria.at(t, T_DB, MID_OUT + 0.06);
    api.at(t, N1, N2 - 0.45, R1, 1.1);
    tests.at(t, N2, OUT - 0.75, R2, 1.3);

    if (t > RISE - 0.3 && t <= LEN) {
      world.frame.phones[BUYER] = { pose, scr: { a: 'v_home' } };
    }
    if (t > RISE - 0.2 && t <= LEN) {
      const x = soft(t, XRAY, XRAY + 0.5) * (1 - soft(t, DROP + 0.45, DROP + 0.95));
      world.frame.cabinet = {
        pose: glide(t, cab, SIGMA),
        kiosk: { state: 'qr', refresh: (t / 30) % 1, seconds: 52, digits: 1, check: 0 },
        xray: x,
      };
      world.cabinet.setFocus('board', x);
      const lift = soft(t, LIFT, LIFT + 0.7) * (1 - soft(t, DROP, DROP + 0.6));
      dev.at(lift, 0.25 * soft(t, LIFT, DROP));
    }
  };
}
