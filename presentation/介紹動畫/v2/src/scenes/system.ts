import { span, lerp, easeOut, easeInOut, type Pose } from '../lib/kf';
import { el, css, place, number } from '../lib/ui';
import { cue, roll } from '../lib/cues';
import { BUYER, type World } from '../world';
import { Headline, at, back, track } from './kit';

const NS = 'http://www.w3.org/2000/svg';

/**
 * 依程式碼核對的架構（savemybook_api）：
 * - App 與 ESP32 書櫃都以 HTTPS 經 Cloudflare、NGINX 連到 Node.js（書櫃走 routes/device.js）。
 * - Socket.IO 與 Express 在同一個 Node.js 程序內（services/realtime.js）。
 * - Node.js 透過 Prisma 存取 MariaDB；呼叫 OpenAI、Google Books、data.taipei；以 Firebase 驗證登入憑證並發送推播（lib/firebase-token.js、lib/fcm.js）。
 */
const NODES: { id: string; x: number; y: number; title: string; note: string; kind?: 'ext' | 'server' }[] = [
  { id: 'app', x: 290, y: 450, title: 'Flutter App', note: '跨平台行動應用' },
  { id: 'cab', x: 290, y: 770, title: 'ESP32 智慧書櫃', note: '以 HTTPS 定時同步' },
  { id: 'edge', x: 700, y: 610, title: 'Cloudflare・NGINX', note: 'DNS、WAF 與反向代理' },
  { id: 'db', x: 1130, y: 900, title: 'MariaDB', note: '關聯式資料庫' },
  { id: 'ai', x: 1630, y: 370, title: 'OpenAI', note: 'AI 功能', kind: 'ext' },
  { id: 'gb', x: 1630, y: 500, title: 'Google Books', note: '書目資料', kind: 'ext' },
  { id: 'dt', x: 1630, y: 630, title: 'data.taipei', note: '交通開放資料', kind: 'ext' },
  { id: 'fb', x: 1630, y: 760, title: 'Firebase', note: '登入驗證與推播', kind: 'ext' },
];
const SERVER = { x: 1130, y: 590, w: 420, h: 290 };
const LINKS: [string, string, boolean?][] = [
  ['app', 'edge'], ['cab', 'edge'], ['edge', 'server'], ['server', 'db'],
  ['server', 'ai', true], ['server', 'gb', true], ['server', 'dt', true], ['server', 'fb', true],
];

const STATS = [
  { to: 300, unit: '個 API 端點', note: 'RESTful API' },
  { to: 1558, unit: '項後端測試', note: '11 組測試群組全數通過' },
  { to: 2570, unit: '項 App 測試', note: '50 個測試檔全數通過' },
  { to: 5, unit: '種介面語言', note: '繁中・簡中・英・日・韓' },
];

/**
 * 系統：上一段的手機縮成 App 節點 → 架構連線依序描出，資料脈衝沿線流動 → 開發成果數字。
 * 旁白（段落內秒數）：sys1 1.0、sys2 9.0。
 */
export function system(world: World, ui: HTMLElement) {
  const s1 = at('sys1'), s2 = at('sys2');
  const head1 = new Headline(ui, '從手機到書櫃，一套系統串起', 'App 與書櫃經 Cloudflare、NGINX 連到 Node.js，資料存於 MariaDB');
  const head2 = new Headline(ui, '完整實作，逐項驗證', '後端與 App 測試全數通過');

  const svg = document.createElementNS(NS, 'svg');
  svg.setAttribute('class', 'overlay arch');
  svg.setAttribute('viewBox', '0 0 1920 1080');
  ui.append(svg);
  const pos: Record<string, { x: number; y: number; w: number; h: number }> = {};
  NODES.forEach((n) => { pos[n.id] = { x: n.x, y: n.y, w: n.kind === 'ext' ? 250 : 320, h: n.kind === 'ext' ? 84 : 96 }; });
  pos.server = SERVER;
  const anchor = (id: string, side: 'l' | 'r' | 't' | 'b') => {
    const p = pos[id];
    return side === 'l' ? { x: p.x - p.w / 2, y: p.y } : side === 'r' ? { x: p.x + p.w / 2, y: p.y } : side === 't' ? { x: p.x, y: p.y - p.h / 2 } : { x: p.x, y: p.y + p.h / 2 };
  };
  const wires = LINKS.map(([a, b, dash], i) => {
    const vertical = b === 'db';
    const p = vertical ? anchor(a, 'b') : anchor(a, 'r');
    const q = vertical ? anchor(b, 't') : anchor(b, 'l');
    const path = document.createElementNS(NS, 'path');
    const d = vertical ? `M${p.x} ${p.y} L${q.x} ${q.y}` : `M${p.x} ${p.y} C${(p.x + q.x) / 2} ${p.y} ${(p.x + q.x) / 2} ${q.y} ${q.x} ${q.y}`;
    path.setAttribute('d', d);
    path.setAttribute('class', dash ? 'wire wire--ext' : 'wire');
    svg.append(path);
    const dot = document.createElementNS(NS, 'circle');
    dot.setAttribute('r', dash ? '5' : '7');
    dot.setAttribute('class', 'pulse');
    svg.append(dot);
    return { path, dot, len: 0, dash: !!dash, i };
  });
  const boxes = NODES.map((n) => {
    const b = el('div', n.kind === 'ext' ? 'arch-node arch-node--ext' : 'arch-node', ui);
    el('b', '', b, n.title);
    el('small', '', b, n.note);
    return b;
  });
  const server = el('div', 'arch-server', ui, '<p class="arch-server__title">Node.js 服務</p><div class="arch-server__row"><b>Express</b><small>RESTful API 與排程作業</small></div><div class="arch-server__row"><b>Socket.IO</b><small>聊天與書櫃即時推送</small></div><p class="arch-server__orm">以 Prisma ORM 存取資料庫</p>');

  const stats = STATS.map((s) => {
    const box = el('div', 'stat2', ui);
    const v = el('p', 'stat2__num', box);
    el('p', 'stat2__unit', box, s.unit);
    el('p', 'stat2__note', box, s.note);
    return { box, v };
  });
  const appearAt = (i: number) => s1 - 0.4 + i * 0.14;
  NODES.forEach((n, i) => cue('node', appearAt(n.kind === 'ext' ? i + 3 : i) + 0.25, { i: i % 5, pan: (n.x - 960) / 960 * 0.6, gain: 0.55 }));
  cue('node', s1 - 0.1, { i: 2, gain: 0.6 });
  STATS.forEach((_, i) => roll(s2 + 0.2 + i * 0.25, 1.8, -0.6 + i * 0.4, 0.6));

  return (t: number) => {
    head1.at(t, 0.2, s2 - 0.9);
    head2.at(t, s2 - 0.2, 14.8);
    const out = easeInOut(span(t, s2 - 1.0, s2 - 0.3));
    const vis = t > -0.2 && out < 1;
    css(svg as unknown as HTMLElement, 'visibility', vis ? 'visible' : 'hidden');
    css(svg as unknown as HTMLElement, 'opacity', (1 - out).toFixed(3));

    // 上一段的手機縮小移到 App 節點的位置後淡出
    if (t > -0.2 && t < 1.0) {
      const k = easeInOut(span(t, -0.1, 0.9));
      const from: Pose = { x: -0.69, y: 0.2, z: 0, rx: 0.03, ry: 0, rz: 0, s: 0.4 };
      const to: Pose = { x: (290 - 960) / 960, y: (540 - 450) / 540, z: 0, rx: 0.03, ry: 0, rz: 0, s: 0.12 };
      world.frame.phones[BUYER] = { pose: track(k, [[0, from], [1, to]]), scr: { a: 'b_ai_consent' } };
    }

    NODES.forEach((n, i) => {
      const a = appearAt(n.kind === 'ext' ? i + 3 : i);
      const k = back(span(t, a, a + 0.6)) * (1 - out);
      css(boxes[i], 'opacity', Math.min(1, k * 1.4).toFixed(3));
      css(boxes[i], 'visibility', k > 0.001 ? 'visible' : 'hidden');
      place(boxes[i], n.x, n.y - out * 30, ` scale(${(0.8 + 0.2 * Math.min(1, k)).toFixed(3)})`);
    });
    const ks = back(span(t, s1 - 0.1, s1 + 0.5)) * (1 - out);
    css(server, 'opacity', Math.min(1, ks * 1.4).toFixed(3));
    css(server, 'visibility', ks > 0.001 ? 'visible' : 'hidden');
    place(server, SERVER.x, SERVER.y - out * 30, ` scale(${(0.85 + 0.15 * Math.min(1, ks)).toFixed(3)})`);

    wires.forEach((w) => {
      if (!w.len) w.len = w.path.getTotalLength();
      const a = w.dash ? s1 + 1.7 + (w.i - 4) * 0.15 : s1 + 0.2 + w.i * 0.25;
      const d = easeInOut(span(t, a, a + 0.8));
      w.path.setAttribute('stroke-dasharray', w.dash ? '6 8' : `${w.len}`);
      w.path.setAttribute('stroke-dashoffset', w.dash ? '0' : `${(w.len * (1 - d)).toFixed(1)}`);
      w.path.setAttribute('opacity', w.dash ? d.toFixed(3) : '1');
      const run = t - (a + 0.8);
      if (run > 0) {
        const p = w.path.getPointAtLength(((run * 0.45 + w.i * 0.13) % 1) * w.len);
        w.dot.setAttribute('cx', p.x.toFixed(1));
        w.dot.setAttribute('cy', p.y.toFixed(1));
        w.dot.setAttribute('opacity', '1');
      } else w.dot.setAttribute('opacity', '0');
    });

    stats.forEach((s, i) => {
      const a = s2 + 0.2 + i * 0.25;
      const k = easeOut(span(t, a, a + 0.6)) * (1 - easeInOut(span(t, 15.0, 15.6)));
      css(s.box, 'opacity', k.toFixed(3));
      css(s.box, 'visibility', k > 0.001 ? 'visible' : 'hidden');
      place(s.box, 300 + i * 440, 600 + (1 - k) * 30);
      number(s.v, STATS[i].to * easeOut(span(t, a, a + 1.8)), 0, STATS[i].to >= 1000);
    });
    void lerp;
  };
}
