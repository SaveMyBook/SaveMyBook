// 各頁版面。每個函式收 (pres, k, opt)，k 為 kit()，opt 為該份簡報的差異（文案、講稿）。
// 文字出處：海報_v2/文案.md、兩組系統概述文件、複評簡報；新增的技術敘述已對過 savemybook_api 程式碼。
const { F, W, M, CW, asset } = require('./kit');

// 章節由 build.js 在呼叫各頁前以 pres.addSection 建立，名稱存在 pres.sectionName
const content = (pres) => pres.addSlide({ masterName: 'CONTENT', sectionTitle: pres.sectionName });

// ── 封面 ──
// 書櫃先放靜態圖（物件名稱「封面書櫃」），tools/add-3d.ps1 再以 PowerPoint 換成可轉動的 3D 模型（素材/cabinet.glb）
const COVER_MODEL = { x: 2.85, y: 2.65, w: 5.2, h: 4.55 };

function cover(pres, k, opt) {
  const s = pres.addSlide({ masterName: 'COVER', sectionTitle: pres.sectionName });
  s.addImage({ path: asset('logo.png'), x: W / 2 - 1.02, y: 0.66, w: 0.4, h: 0.33 });
  k.text(s, 'SaveMyBook', { x: W / 2 - 0.52, y: 0.6, w: 2, h: 0.44, face: F.numSemi, size: 18, color: k.C.gray, valign: 'middle' });
  k.text(s, ['救', k.grad('「舊」'), '我的書'], { x: M, y: 1.0, w: CW, h: 1.1, face: F.black, size: 60, align: 'center', valign: 'middle', name: '作品名稱' });
  k.text(s, '讓閒置的書，重新流動。', { x: M, y: 2.12, w: CW, h: 0.5, size: 22, color: k.C.gray, align: 'center' });
  const m = COVER_MODEL, ch = m.h, cw = ch * 1660 / 1799;
  s.addImage({ path: asset('hero-cabinet.png'), x: m.x + (m.w - cw) / 2, y: m.y, w: cw, h: ch, objectName: '封面書櫃', altText: '智慧書櫃' });
  const ph = 3.8, pw = ph * 700 / 1459;
  s.addImage({ path: asset('hero-phone.png'), x: 8.3, y: m.y + m.h - ph - 0.1, w: pw, h: ph, altText: 'App 首頁' });
  s.addNotes(opt.notes);
}

// ── 問題：四個難題 ──
const PROBLEMS = [
  { k: '問題 01・寄送不便', n: '57.9', p: '需自行包裝、跑超商寄貨' },
  { k: '問題 02・交易安全', n: '43.2', p: '擔心遇到放鳥或詐騙' },
  { k: '問題 03・書況不符', n: '95', pre: '逾', p: '線上查看實體書況照片\n有助提升購買意願' },
  { k: '問題 04・處理門檻', n: '35', p: '有閒置書想清空\n卻懶得處理' }
];

function problems(pres, k, opt) {
  const s = content(pres);
  k.title(s, ['二手書交易，', k.grad('難在哪裡？')]);
  k.sub(s, '本團隊二手書交易需求調查，有效問卷 498 份');
  const w = (CW - 0.9) / 4, y = 2.4, h = 3.0;
  PROBLEMS.forEach((p, i) => {
    const x = M + i * (w + 0.3);
    k.tile(s, x, y, w, h, `問題 ${i + 1}`);
    k.text(s, p.k, { x: x + 0.35, y: y + 0.4, w: w - 0.5, h: 0.32, size: 15, face: F.bold, bold: true, color: k.C.gray });
    k.text(s, k.num(p.n, { pre: p.pre, unit: '%', size: 60 }), { x: x + 0.35, y: y + 0.95, w: w - 0.4, h: 1.05, color: k.C.accent, valign: 'middle' });
    k.text(s, p.p, { x: x + 0.35, y: y + 2.25, w: w - 0.5, h: 0.8, size: 15, color: k.C.ink });
  });
  s.addNotes(opt.notes);
}

// ── 解法：四個難題各一項技術 ──
const SOLUTIONS = [
  { k: '問題 01・寄送不便', t: '智慧書櫃\n免寄送', d: '一片 ESP32，控制四扇櫃門' },
  { k: '問題 02・交易安全', t: '先驗收、\n後撥款', d: '款項由平台暫管，驗收後撥款' },
  { k: '問題 03・書況不符', t: 'AI 判斷\n書況與售價', d: '附上判斷依據、建議售價區間' },
  { k: '問題 04・處理門檻', t: 'AI 降低\n上架負擔', d: 'ISBN 掃描・書目自動帶入' }
];

function solutions(pres, k, opt) {
  const s = content(pres);
  k.title(s, ['四個難題，', k.grad('我們用技術解開。')]);
  const w = (CW - 0.9) / 4, y = 1.95, h = 3.9;
  SOLUTIONS.forEach((p, i) => {
    const x = M + i * (w + 0.3);
    k.tile(s, x, y, w, h, `解法 ${i + 1}`);
    k.text(s, p.k, { x: x + 0.35, y: y + 0.4, w: w - 0.5, h: 0.32, size: 15, face: F.bold, bold: true, color: k.C.gray });
    s.addShape(pres.shapes.LINE, { x: x + 0.35, y: y + 1.0, w: w - 0.7, h: 0, line: { color: k.C.line, width: 1 } });
    k.text(s, '技術解法', { x: x + 0.35, y: y + 1.25, w: w - 0.5, h: 0.32, size: 15, face: F.bold, bold: true, color: k.C.ok });
    k.text(s, p.t, { x: x + 0.35, y: y + 1.65, w: w - 0.5, h: 1.2, size: 30, face: F.black, ls: 1.05 });
    k.text(s, p.d, { x: x + 0.35, y: y + 3.0, w: w - 0.45, h: 0.6, size: 14, color: k.C.gray });
  });
  s.addNotes(opt.notes);
}

// ── 交易閉環 ──
const LOOP = [
  ['線上看書況', 'App', '實拍照片與 AI 書況'],
  ['下單付款', '站內錢包', '款項由平台暫管'],
  ['掃碼存書', '智慧書櫃', '賣家到書櫃放書'],
  ['掃碼取書', '智慧書櫃', '買家到書櫃取書'],
  ['驗收確認', 'App', '24 小時內確認書況'],
  ['撥款', '平台暫管', '撥入賣家錢包']
];

function loop(pres, k, opt) {
  const s = content(pres);
  k.title(s, ['一條交易閉環，', k.grad('全程不必碰面')]);
  k.sub(s, '買賣雙方無須碰面，亦無須收付現金');
  const step = CW / 6, cy = 3.45, d = 0.8;
  s.addShape(pres.shapes.LINE, { x: M + step / 2, y: cy, w: step * 5, h: 0, line: { color: k.C.line, width: 2.5 } });
  LOOP.forEach(([t, by, dsc], i) => {
    const cx = M + step * (i + 0.5), cab = by === '智慧書櫃';
    s.addShape(pres.shapes.OVAL, { x: cx - d / 2, y: cy - d / 2, w: d, h: d, fill: { color: cab ? k.C.accent : k.C.white }, line: { color: k.C.accent, width: 2 } });
    k.text(s, String(i + 1).padStart(2, '0'), { x: cx - d / 2, y: cy - d / 2, w: d, h: d, face: F.num, size: 20, color: cab ? k.C.white : k.C.accent, align: 'center', valign: 'middle' });
    k.text(s, t, { x: cx - step / 2, y: cy + 0.65, w: step, h: 0.45, size: 21, face: F.bold, bold: true, align: 'center' });
    k.text(s, by, { x: cx - step / 2, y: cy + 1.15, w: step, h: 0.32, size: 14, face: F.bold, bold: true, color: cab ? k.C.accent : k.C.gray, align: 'center' });
    k.text(s, dsc, { x: cx - step / 2 + 0.08, y: cy + 1.55, w: step - 0.16, h: 0.35, size: 13.5, color: k.C.gray, align: 'center' });
  });
  if (opt.transit) {
    // 存書、取書兩步是買賣雙方要親自到書櫃的地方，臺北開放資料接在這裡
    const x0 = M + step * 2, x1 = M + step * 4, y = 5.6;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: x0 + 0.1, y, w: x1 - x0 - 0.2, h: 0.75, rectRadius: 0.2, fill: { color: k.C.white }, line: { color: k.C.ok, width: 1.5 } });
    k.text(s, '前往書櫃：整合 12 筆臺北市開放資料', { x: x0 + 0.1, y, w: x1 - x0 - 0.2, h: 0.75, size: 16, face: F.bold, bold: true, color: k.C.ok, align: 'center', valign: 'middle' });
  }
  s.addNotes(opt.notes);
}

// ── 智慧書櫃硬體 ──
const PARTS = [
  ['2.8 吋 TFT 螢幕', '顯示 QR Code 與數字'],
  ['ESP32-S3 控制板', 'Wi-Fi・HTTPS 同步'],
  ['四路繼電器', '驅動電磁鎖'],
  ['12V 電磁鎖 ×4', '斷電上鎖'],
  ['門磁開關 ×4', '偵測櫃門是否關閉']
];

function cabinet(pres, k, opt) {
  const s = content(pres);
  k.title(s, ['一片 ESP32，', k.grad('控制四扇櫃門')]);
  s.addImage({ path: asset('xray.png'), x: 1.0, y: 1.6, w: 4.85, h: 4.85 * 1758 / 1675, altText: '智慧書櫃透視圖（官網現行模型）' });
  const x = 6.6, w = W - M - x, row = 0.82, y0 = 1.95;
  PARTS.forEach(([n, d], i) => {
    const y = y0 + i * row;
    k.text(s, n, { x, y, w: 3.0, h: 0.5, size: 20, face: F.bold, bold: true, valign: 'middle' });
    k.text(s, d, { x: x + 3.05, y, w: w - 3.05, h: 0.5, size: 16, color: k.C.gray, valign: 'middle' });
    if (i < PARTS.length - 1) s.addShape(pres.shapes.LINE, { x, y: y + 0.66, w, h: 0, line: { color: k.C.line, width: 0.75 } });
  });
  s.addNotes(opt.notes);
}

// ── 四道驗證 ──
const CHECKS = [
  ['動態 QR Code', '每 30 秒更換\n截圖轉傳無效'],
  ['定位必要', '須在書櫃\n200 公尺內'],
  ['兩位數比對', '60 秒內輸入\n一次機會'],
  ['裝置憑證', '回報關門後\n才登記存取']
];

function checks(pres, k, opt) {
  const s = content(pres);
  k.title(s, ['存取安全：', k.grad('四道驗證')]);
  const w = (CW - 0.9) / 4, y = 2.3, h = 3.0;
  CHECKS.forEach(([t, d], i) => {
    const x = M + i * (w + 0.3);
    k.tile(s, x, y, w, h, t);
    k.text(s, String(i + 1).padStart(2, '0'), { x: x + 0.4, y: y + 0.45, w: 1, h: 0.45, face: F.num, size: 26, color: k.C.accent });
    k.text(s, t, { x: x + 0.4, y: y + 1.15, w: w - 0.6, h: 0.5, size: 23, face: F.black });
    k.text(s, d, { x: x + 0.4, y: y + 1.85, w: w - 0.6, h: 1.1, size: 17, color: k.C.gray, ls: 1.3 });
  });
  s.addNotes(opt.notes);
}

// ── 展示：賣家存書／買家取書（同複評簡報：書櫃動畫＋手機錄影＋六步，步驟隨影片亮起） ──
// at：各步亮起的時間（毫秒），對齊手機錄影的 marks.txt（savemybook_app/tool/deck_gifs，錄影時寫出）；
// 第六步亮到下一輪第一步。period 由影片長度決定，後處理依此展開成多輪（同複評簡報的做法）。
const FLOWS = {
  deposit: { title: ['賣家', { text: '存書', options: { color: '2E749F' } }], video: 'cabinet_deposit',
    steps: ['掃描書櫃 QR Code', '確認存書項目', '輸入螢幕比對碼', '比對成功，A01 開鎖', '放入書籍並關門', '存書完成，通知買家取書'],
    at: [1100, 3200, 5150, 7117, 7900, 9800] },
  pickup: { title: ['買家', { text: '取書', options: { color: '2E749F' } }], video: 'cabinet_pickup',
    steps: ['掃描書櫃 QR Code', '確認取書項目', '輸入螢幕比對碼', '比對成功，A01 開鎖', '取出書籍並關門', '取書完成，進入驗收'],
    at: [1100, 3200, 5150, 7117, 7900, 9967] }
};

function demoFlow(pres, k, opt) {
  const f = FLOWS[opt.flow];
  const s = content(pres);
  k.title(s, f.title);
  const top = 1.6, vh = 5.1;
  const cw = k.video(s, `cabinet3d_${opt.flow}`, M, top + 0.1, vh - 0.2);
  k.video(s, f.video, M + cw + 0.25, top, vh);
  const x = 8.4, w = W - M - x, row = 0.76, d = 0.48, y0 = top + (vh - 6 * row) / 2;
  const period = k.durationMs(f.video);
  f.steps.forEach((t, i) => {
    const y = y0 + i * row, cy = y + (row - d) / 2;
    const end = i < 5 ? f.at[i + 1] : period + f.at[0];
    const name = (part) => `步驟亮 ${i + 1} ${part}｜${f.at[i]}-${end}-${period}`;
    // 亮起時的白底與實心圓（一開始隱藏，由後處理的動畫依時間淡入淡出）
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: x - 0.15, y: y + 0.04, w: w + 0.15, h: row - 0.08, rectRadius: 0.16, fill: { color: k.C.white }, line: { type: 'none' }, objectName: name('底') });
    const num = (o) => s.addText(String(i + 1), { shape: pres.shapes.OVAL, x, y: cy, w: d, h: d, margin: 0, align: 'center', valign: 'middle', fontFace: F.num, fontSize: 15, lang: 'zh-TW', ...o });
    num({ fill: { color: 'F5F5F7' }, line: { color: k.C.slate, width: 1.25 }, color: k.C.slate });
    k.text(s, t, { x: x + 0.7, y, w: w - 0.8, h: row, size: 18, valign: 'middle' });
    num({ fill: { color: i === 5 ? k.C.ok : k.C.accent }, line: { type: 'none' }, color: k.C.white, objectName: name('圈') });
  });
  s.addNotes(opt.notes);
}

// ── 先驗收、後撥款 ──
const PAYOUT = [
  ['付款暫管', '款項由平台暫管'],
  ['取書關門', '訂單進入驗收'],
  ['24 小時驗收', '買家確認書況'],
  ['撥款', '撥入賣家錢包']
];

function payout(pres, k, opt) {
  const s = content(pres);
  k.title(s, ['先驗收、', k.grad('後撥款')]);
  k.sub(s, '取書滿 24 小時未申請爭議，也會自動完成並撥款');
  const step = CW / 4, cy = 3.25, d = 0.85;
  s.addShape(pres.shapes.LINE, { x: M + step / 2, y: cy, w: step * 3, h: 0, line: { color: k.C.line, width: 2.5 } });
  PAYOUT.forEach(([t, dsc], i) => {
    const cx = M + step * (i + 0.5), last = i === PAYOUT.length - 1;
    s.addShape(pres.shapes.OVAL, { x: cx - d / 2, y: cy - d / 2, w: d, h: d, fill: { color: last ? k.C.ok : k.C.accent }, line: { type: 'none' } });
    k.text(s, String(i + 1).padStart(2, '0'), { x: cx - d / 2, y: cy - d / 2, w: d, h: d, face: F.num, size: 20, color: k.C.white, align: 'center', valign: 'middle' });
    k.text(s, t, { x: cx - step / 2, y: cy + 0.7, w: step, h: 0.5, size: 24, face: F.black, align: 'center' });
    k.text(s, dsc, { x: cx - step / 2, y: cy + 1.25, w: step, h: 0.4, size: 17, color: k.C.gray, align: 'center' });
  });
  s.addNotes(opt.notes);
}

// ── 七項 AI 服務 ──
const AI = [
  ['01', '上架', ['上架輔助', '資料補齊', '上架審核']],
  ['02', '選書', ['個人化推薦', 'AI 書籍顧問']],
  ['03', '售後', ['AI 客服', '爭議分析']]
];

function aiServices(pres, k, opt) {
  const s = content(pres);
  k.title(s, ['七項 AI 服務，', k.grad('從上架到售後')]);
  k.phone(s, 'ai_listing_isbn', 0.95, 1.7, 4.95);
  const x0 = 3.95, w = (W - M - x0 - 0.6) / 3, y = 1.9, h = 4.4;
  AI.forEach(([no, stage, items], i) => {
    const x = x0 + i * (w + 0.3);
    k.tile(s, x, y, w, h, `AI ${stage}`);
    k.text(s, no, { x: x + 0.4, y: y + 0.4, w: 1, h: 0.4, face: F.num, size: 20, color: k.C.accent });
    k.text(s, stage, { x: x + 0.4, y: y + 0.9, w: w - 0.6, h: 0.55, size: 28, face: F.black });
    items.forEach((n, j) => {
      k.text(s, n, { x: x + 0.4, y: y + 1.85 + j * 0.62, w: w - 0.6, h: 0.45, size: 19, face: F.bold, bold: true, color: k.C.ink });
    });
  });
  s.addNotes(opt.notes);
}

// ── 穩定性之一：測試與成效數字 ──
const TESTS = [
  ['1,563', '', '後端測試', '11 組全數通過'],
  ['2,815', '', 'App 測試', '全數通過'],
  ['301', '', 'API 端點', 'OpenAPI 文件'],
  ['99.7', '%', '妥善率', '以每年停機約 28 小時估算']
];

function tests(pres, k, opt) {
  const s = content(pres);
  k.title(s, ['測試', k.grad('全數通過')]);
  k.sub(s, opt.sub || '五種語系、深淺色主題，Passkey 與生物辨識登入');
  const w = (CW - 0.9) / 4, y = 2.2, h = 3.3;
  TESTS.forEach(([n, unit, label, note], i) => {
    const x = M + i * (w + 0.3);
    k.tile(s, x, y, w, h, label);
    k.text(s, k.num(n, { unit, size: 54 }), { x, y: y + 0.75, w, h: 1.0, color: k.C.accent, align: 'center', valign: 'middle' });
    k.text(s, label, { x, y: y + 1.95, w, h: 0.4, size: 19, face: F.bold, bold: true, align: 'center' });
    k.text(s, note, { x: x + 0.2, y: y + 2.42, w: w - 0.4, h: 0.35, size: 14, color: k.C.gray, align: 'center' });
  });
  s.addNotes(opt.notes);
}

// ── 三格卡片（備援、擴充、交易把關、開放資料防護共用）：編號或標籤、標題、一兩行說明 ──
function cards(s, k, items, color) {
  const w = (CW - 0.6) / 3, y = 2.3, h = 2.9;
  items.forEach(([tag, t, d], i) => {
    const x = M + i * (w + 0.3);
    k.tile(s, x, y, w, h, t);
    k.text(s, tag || String(i + 1).padStart(2, '0'), { x: x + 0.45, y: y + 0.5, w: w - 0.7, h: 0.4, face: tag ? F.bold : F.num, bold: !!tag, size: tag ? 15 : 22, color });
    k.text(s, t, { x: x + 0.45, y: y + 1.0, w: w - 0.7, h: 0.6, size: 26, face: F.black });
    k.text(s, d, { x: x + 0.45, y: y + 1.8, w: w - 0.8, h: 1.2, size: 17, color: k.C.gray, ls: 1.3 });
  });
}

// ── 交易把關（先驗收後撥款之外） ──
function safety(pres, k, opt) {
  const s = content(pres);
  k.title(s, opt.title);
  cards(s, k, opt.tiles, k.C.ok);
  s.addNotes(opt.notes);
}

// ── 穩定性之二：故障備援 ──
const BACKUP = [
  [null, '離線偵測', '逾 15 秒未回報即視為離線\n5 分鐘通知管理員'],
  [null, '斷線補送', '事件先存在書櫃本機\n恢復連線後補送'],
  [null, '金流一致', '條件式更新\n不重複扣款、撥款']
];

function backup(pres, k, opt) {
  const s = content(pres);
  k.title(s, ['出狀況時，', k.grad('也有備援')]);
  cards(s, k, BACKUP, k.C.accent);
  s.addNotes(opt.notes);
}

// ── 擴充性之一：四層架構 ──
const LAYERS = [
  ['表現層與終端存取', [['Flutter App', 'iPhone・iPad・Android'], ['ESP32-S3 書櫃', '專屬憑證・HTTPS 輪詢']]],
  ['安全閘道與代理層', [['Cloudflare', 'DNS・CDN・WAF'], ['NGINX', '反向代理']]],
  ['業務邏輯與應用層', [['Express 5 API', 'RESTful'], ['Socket.IO', '即時訊息'], ['AI 服務', 'OpenAI・Gemini']]],
  ['資料持久層', [['MariaDB', 'Prisma ORM']]]
];

function architecture(pres, k, opt) {
  const s = content(pres);
  k.title(s, ['四層架構，', k.grad('職責分明')]);
  const y0 = 1.85, h = 1.0, gap = 0.25, lw = 3.0;
  LAYERS.forEach(([label, items], i) => {
    const y = y0 + i * (h + gap);
    k.tile(s, M, y, CW, h, label);
    k.text(s, String(i + 1).padStart(2, '0'), { x: M + 0.35, y, w: 0.6, h, face: F.num, size: 17, color: k.C.accent, valign: 'middle' });
    k.text(s, label, { x: M + 0.95, y, w: lw - 0.6, h, size: 17, face: F.bold, bold: true, color: k.C.gray, valign: 'middle' });
    const x0 = M + lw + 0.4, cw = (CW - lw - 0.6) / 3;
    items.forEach(([n, d], j) => {
      const x = x0 + j * cw;
      k.text(s, n, { x, y: y + 0.18, w: cw - 0.2, h: 0.38, size: 19, face: F.bold, bold: true });
      k.text(s, d, { x, y: y + 0.58, w: cw - 0.2, h: 0.3, size: 13, color: k.C.gray });
    });
  });
  s.addNotes(opt.notes);
}

// ── 擴充性之二：怎麼擴充 ──
const EXTEND = [
  [null, 'AI 供應商可切換', 'OpenAI 與 Google Gemini\n後台控管用量'],
  [null, '書櫃複製擴點', '單台電子零件約 3,209 元\n配對碼即可加入'],
  [null, '場域合作', '學校、圖書館、社區或商家\n提供空間即可設點']
];

function extend(pres, k, opt) {
  const s = content(pres);
  k.title(s, ['新書櫃、新場域，', k.grad('都能接得上')]);
  cards(s, k, opt.items || EXTEND, k.C.ok);
  s.addNotes(opt.notes);
}

// ── 結尾 ──
function ending(pres, k, opt) {
  const s = pres.addSlide({ masterName: 'COVER', sectionTitle: pres.sectionName });
  k.text(s, ['讓閒置的書，', k.grad('重新流動。')], { x: M, y: 2.35, w: CW, h: 1.3, face: F.black, size: 56, align: 'center', valign: 'middle' });
  k.text(s, '謝謝聆聽，敬請指教', { x: M, y: 4.05, w: CW, h: 0.5, size: 22, face: F.bold, bold: true, color: k.C.gray, align: 'center' });
  s.addNotes(opt.notes);
}

// ── 臺北組：12 筆開放資料（資料集名稱放講稿） ──
const DATASETS = [['捷運', 3], ['公車', 3], ['YouBike', 1], ['開車', 4], ['計程車', 1]];

function datasets(pres, k, opt) {
  const s = content(pres);
  k.title(s, ['前往書櫃的', k.grad('最後一哩路')]);
  k.sub(s, '買賣雙方仍須親赴書櫃，所以書櫃頁面接上臺北市開放資料');
  k.text(s, [k.grad('12')], { x: M, y: 1.95, w: CW, h: 1.6, face: F.num, size: 110, align: 'center', valign: 'middle' });
  k.text(s, '筆臺北市資料大平臺資料集', { x: M, y: 3.55, w: CW, h: 0.45, size: 20, face: F.bold, bold: true, align: 'center' });
  const w = (CW - 4 * 0.25) / 5, y = 4.35, h = 1.6;
  DATASETS.forEach(([mode, n], i) => {
    const x = M + i * (w + 0.25);
    k.tile(s, x, y, w, h, mode);
    k.text(s, k.num(String(n), { unit: ' 筆', size: 34 }), { x, y: y + 0.22, w, h: 0.7, color: k.C.accent, align: 'center', valign: 'middle' });
    k.text(s, mode, { x, y: y + 0.98, w, h: 0.4, size: 18, face: F.bold, bold: true, align: 'center' });
  });
  s.addNotes(opt.notes);
}

// ── 臺北組：展示交通指引 ──
const MODES = [
  ['捷運', '票價試算、最近與無障礙出口'],
  ['公車', '300 公尺內站牌、即時到站'],
  ['YouBike', '500 公尺內可借、可還'],
  ['開車', '停車場與路邊停車即時空位'],
  ['計程車', '800 公尺內招呼站']
];

function demoTransit(pres, k, opt) {
  const s = content(pres);
  k.title(s, ['一次看完', k.grad('五種交通方式')]);
  k.phone(s, 'cabinet_transit', 0.95, 1.7, 4.95);
  const x = 4.0, w = W - M - x, h = 0.78, gap = 0.16;
  MODES.forEach(([m, d], i) => {
    const y = 1.85 + i * (h + gap);
    k.tile(s, x, y, w, h, m);
    k.text(s, m, { x: x + 0.4, y, w: 1.6, h, size: 20, face: F.bold, bold: true, valign: 'middle' });
    k.text(s, d, { x: x + 2.1, y, w: w - 2.4, h, size: 17, color: k.C.gray, valign: 'middle' });
  });
  s.addNotes(opt.notes);
}

// ── 臺北組：開放資料怎麼接 ──
const PIPE = [
  ['臺北資料大平臺', '12 筆資料集'],
  ['後端快取', '過期才重抓'],
  ['依書櫃座標篩選', '最近站點與出口'],
  ['App 書櫃頁', '五種交通方式']
];

function pipeline(pres, k, opt) {
  const s = content(pres);
  k.title(s, ['開放資料，', k.grad('怎麼接進 App')]);
  const gap = 0.45, w = (CW - 3 * gap) / 4, y = 2.4, h = 2.4;
  PIPE.forEach(([t, d], i) => {
    const x = M + i * (w + gap);
    k.tile(s, x, y, w, h, t);
    k.text(s, String(i + 1).padStart(2, '0'), { x: x + 0.35, y: y + 0.4, w: 1, h: 0.4, face: F.num, size: 22, color: k.C.accent });
    k.text(s, t, { x: x + 0.35, y: y + 1.0, w: w - 0.45, h: 0.5, size: 18, face: F.bold, bold: true });
    k.text(s, d, { x: x + 0.35, y: y + 1.6, w: w - 0.5, h: 0.4, size: 17, color: k.C.gray });
    if (i < PIPE.length - 1) k.text(s, '→', { x: x + w, y, w: gap, h, face: F.num, size: 24, color: k.C.slate, align: 'center', valign: 'middle' });
  });
  s.addNotes(opt.notes);
}

// ── 臺北組：開放資料的防護 ──
const GUARD = [
  [null, '來源故障不中斷', '沿用上一份成功的資料'],
  [null, '啟動預熱', '先載入每日更新的靜態資料'],
  [null, '位置不上傳', '最近捷運站在手機上計算']
];

function guards(pres, k, opt) {
  const s = content(pres);
  k.title(s, ['資料來源出狀況，', k.grad('頁面照常')]);
  cards(s, k, GUARD, k.C.accent);
  s.addNotes(opt.notes);
}

// ── 臺北組：系統完整性 ──
const ENDS = [
  ['01', '使用者端', ['上架與選購', '書櫃存取與交通指引', '錢包、聊天與爭議']],
  ['02', '管理端', ['會員與內容審核', '爭議仲裁', '書櫃裝置管理']],
  ['03', '智慧書櫃端', ['顯示 QR Code 與比對碼', '驗證後開鎖', '回報開關門']]
];

function completeness(pres, k, opt) {
  const s = content(pres);
  k.title(s, ['使用者、管理員、書櫃，', k.grad('三端完整串接')]);
  const w = (CW - 0.6) / 3, y = 2.0, h = 3.8;
  ENDS.forEach(([no, t, items], i) => {
    const x = M + i * (w + 0.3);
    k.tile(s, x, y, w, h, t);
    k.text(s, no, { x: x + 0.45, y: y + 0.45, w: 1, h: 0.4, face: F.num, size: 22, color: k.C.accent });
    k.text(s, t, { x: x + 0.45, y: y + 1.0, w: w - 0.7, h: 0.6, size: 26, face: F.black });
    k.text(s, items.map((t2, j) => ({ text: t2, options: { bullet: { indent: 16 }, breakLine: j < items.length - 1 } })),
      { x: x + 0.45, y: y + 1.85, w: w - 0.75, h: 1.7, size: 18, color: k.C.gray, after: 8 });
  });
  s.addNotes(opt.notes);
}

module.exports = {
  cover, problems, solutions, loop, cabinet, checks, demoFlow, payout, safety, aiServices, tests, backup, architecture, extend, ending,
  datasets, demoTransit, pipeline, guards, completeness
};
