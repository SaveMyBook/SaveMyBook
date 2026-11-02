// InnoServe 決賽簡報：資訊應用組（IP）與臺北生活好便利創新應用組（TCGIA）各一份，每份約 6 分鐘。
// 用法：node tools/assets.js（第一次或素材更新時）→ node build.js
// 輸出：成品/*.pptx 與對應的講稿 .md（講稿＝每頁備忘稿，秒數為目標時間）。
const fs = require('fs');
const path = require('path');
const pptxgen = require('pptxgenjs');
const { THEME, kit, postprocess } = require('./tools/kit');
const S = require('./tools/slides');

const OUT = path.join(__dirname, '成品');
const LABEL = {
  cover: '封面', problems: '難在哪裡', solutions: '技術解法', loop: '交易閉環', cabinet: '智慧書櫃', checks: '四道驗證',
  demoFlow: '展示', payout: '先驗收、後撥款', safety: '交易把關', aiServices: '七項 AI 服務', tests: '測試', backup: '故障備援',
  architecture: '四層架構', extend: '擴充性', ending: '結尾', datasets: '12 筆臺北開放資料', demoTransit: '展示：前往書櫃',
  pipeline: '開放資料串接', guards: '開放資料備援', completeness: '系統完整性'
};
const label = (fn, extra) => (fn === S.demoFlow ? (extra.flow === 'deposit' ? '展示：賣家存書' : '展示：買家取書') : LABEL[fn.name]);

const SAFETY_IP = {
  title: ['交易安全，', { text: '層層把關', options: { color: '2E749F' } }],
  tiles: [['書況不符', '申請爭議', '附照片申請爭議\n暫停撥款、管理員裁決'],
    ['付款驗證', '密碼・生物辨識', '付款、轉帳都要驗證'],
    ['聊天防詐', '即時提醒', '偵測站外聯絡\n與私下付款']]
};
const SAFETY_TCGIA = {
  title: ['AI 與防詐，', { text: '一起把關', options: { color: '2E749F' } }],
  tiles: [['AI', '判斷書況與售價', '依實拍照片判斷\n附上建議售價區間'],
    ['AI', '爭議分析', '比對照片整理爭點\n由管理員裁決'],
    ['聊天防詐', '即時提醒', '偵測站外聯絡\n與私下付款']]
};

// 每頁：[版面函式, 秒數, 講稿, 其他選項]
const IP = {
  file: '救舊我的書－決賽簡報（資訊應用組）',
  group: '資訊應用組（IP）',
  slides: [
    [S.cover, 10, '評審好，我們的作品是「救「舊」我的書」，一個結合 App 與自製智慧書櫃的二手書交易平台，目標是讓閒置的書，重新流動。'],
    [S.problems, 35, '我們先做了二手書交易需求調查，取得 498 份有效問卷，整理出四個難題。寄送方面，最大的不便是需自行包裝、跑超商寄貨，占 57.9%；面交方面，43.2% 是擔心遇到放鳥或詐騙；書況方面，逾 95% 的受訪者認為線上查看實體書況照片，有助提升購買意願；而處理閒置書，35% 是有閒置書想清空卻懶得處理。（註：57.9%、43.2%、35% 是複選題的勾選占比，口頭不要說成「受訪者」。）'],
    [S.solutions, 15, '針對這四個難題，我們各用一項技術解開：智慧書櫃免寄送、先驗收後撥款、AI 判斷書況與售價、AI 降低上架負擔。'],
    [S.loop, 15, '串起來就是一條交易閉環：線上看書況、下單付款、到書櫃掃碼存書、掃碼取書、驗收確認，最後撥款。買賣雙方不必碰面，也不必收付現金。'],
    [S.cabinet, 25, '這是我們自己設計製作的智慧書櫃。合板櫃體，壓克力櫃門以 SolidWorks 繪製後雷射切割。一片 ESP32-S3 透過繼電器控制四扇櫃門的電磁鎖，2.8 吋螢幕顯示 QR Code 與比對數字，門磁開關偵測櫃門是否關上。'],
    [S.checks, 20, '開櫃有四道驗證：QR Code 每 30 秒更換、只能用一次，截圖轉傳無效；使用者必須在書櫃 200 公尺內；比對數字要在 60 秒內輸入，只有一次機會；書櫃以專屬憑證連線，回報關門後才登記存書或取書。'],
    [S.demoFlow, 30, '實際操作來看賣家存書：掃描書櫃 QR Code、確認存書項目，輸入書櫃螢幕上的比對數字，比對成功後 A01 開鎖；放入書籍、關上門，存書完成，系統通知買家取書。（現場若有實機：歡迎評審稍後到攤位實際操作。）', { flow: 'deposit' }],
    [S.demoFlow, 20, '買家取書的流程相同：掃碼、確認取書項目、輸入比對數字，A01 開鎖；取出書籍並關門，取書完成，訂單進入驗收。', { flow: 'pickup' }],
    [S.payout, 20, '金流採先驗收、後撥款。買家付款後，款項由平台暫管；取書關門後進入 24 小時驗收，買家確認書況後撥款給賣家；取書滿 24 小時沒有申請爭議，也會自動完成並撥款。'],
    [S.safety, 20, '其他把關：書況不符可以附照片申請爭議，暫停撥款，由管理員參考 AI 的分析裁決；付款、轉帳須通過交易密碼或生物辨識；聊天室偵測到站外聯絡或私下付款時，會即時提醒雙方。', SAFETY_IP],
    [S.aiServices, 40, 'AI 貫穿整個交易流程，共七項服務。上架時，輸入或掃描 ISBN，AI 會查詢 Google Books、Open Library 與網路來源帶入書目並附上出處，賣家只套用勾選的欄位；拍照後 AI 還能判斷書況、建議售價區間；資料補齊會在背景把空白欄位補上；上架後由規則加 AI 雙層審核。選書時有個人化推薦與 AI 書籍顧問；售後有 AI 客服與爭議分析。AI 只提供建議，最後仍由人確認。'],
    [S.tests, 15, '穩定性方面，後端 1,563 項測試、App 2,815 項測試全數通過，共 301 個 API 端點；以每年停機約 28 小時估算，書櫃妥善率約 99.7%。使用上支援五種語系、深淺色主題，以及 Passkey 與生物辨識登入。'],
    [S.backup, 20, '出狀況時也有備援：書櫃逾 15 秒沒回報就視為離線，5 分鐘通知管理員，故障超過 2 分鐘可改手動回報；斷線時事件先存在書櫃本機，恢復後補送、不重複登記；扣款與撥款在資料庫交易內以條件式更新執行，不會重複扣款或撥款。'],
    [S.architecture, 20, '系統分成四層：表現層是 Flutter App 與書櫃；安全閘道由 Cloudflare 與 NGINX 負責；業務邏輯在 Express API、Socket.IO 與 AI 服務；資料存在 MariaDB。每層職責分明，可以各自替換或擴充。'],
    [S.extend, 20, '擴充上，AI 供應商可以在後台切換並控管用量；新書櫃零件國內買得到，單台電子零件約 3,209 元，輸入 8 位數配對碼就能加入；學校、圖書館、社區或商家只要提供空間、電力與網路，就能設點。'],
    [S.ending, 10, '救「舊」我的書，讓閒置的書，重新流動。以上是我們的報告，謝謝評審，敬請指教。']
  ]
};

const TCGIA = {
  file: '救舊我的書－決賽簡報（臺北生活好便利組）',
  group: '臺北生活好便利創新應用組（TCGIA）',
  slides: [
    [S.cover, 10, '評審好，我們的作品是「救「舊」我的書」，結合 App、自製智慧書櫃與臺北市開放資料的二手書交易平台，讓閒置的書，重新流動。'],
    [S.problems, 25, '我們的二手書交易需求調查取得 498 份有效問卷。寄送最大的不便是需自行包裝、跑超商寄貨，占 57.9%；面交最令人卻步的是擔心遇到放鳥或詐騙，占 43.2%；逾 95% 的受訪者認為線上查看實體書況照片有助提升購買意願；處理閒置書則有 35% 是想清空卻懶得處理。（註：57.9%、43.2%、35% 是複選題勾選占比。）'],
    [S.solutions, 15, '我們用四項技術解開這些難題：智慧書櫃免寄送、先驗收後撥款、AI 判斷書況與售價、AI 降低上架負擔。'],
    [S.loop, 15, '串成一條交易閉環。其中存書與取書這兩步，買賣雙方都要親自到書櫃，所以我們在這裡接上了臺北市的開放資料。', { transit: true }],
    [S.cabinet, 20, '智慧書櫃是我們自己設計製作的：一片 ESP32-S3 透過繼電器控制四扇櫃門的電磁鎖，螢幕顯示 QR Code 與比對數字，門磁開關偵測櫃門是否關上。'],
    [S.datasets, 30, '書櫃解決了面交，但使用者還是得「去書櫃」，這是最後一哩路。我們介接臺北市資料大平臺 12 筆資料集：捷運 3 筆，是票價、出入口座標、無障礙電梯與坡道座標；公車 3 筆，是站牌、預估到站時間與公車票價；YouBike 即時資訊 1 筆；開車 4 筆，是停車場資訊、路邊停車格位、格位使用情形與道路速率；以及計程車招呼站 1 筆。'],
    [S.demoTransit, 40, '來看書櫃頁面的實際畫面。捷運可以選擇出發站，試算到書櫃附近車站的票價與里程，並標示最近出口和無障礙電梯出口；公車列出 300 公尺內站牌與即時到站；YouBike 顯示 500 公尺內站點的可借、可還數量；開車顯示停車場剩餘車位、300 公尺內路邊停車格的即時空位和周邊路況；計程車列出 800 公尺內的招呼站。使用者不用切換多個 App，無障礙出口的標示也照顧行動不便的使用者。'],
    [S.pipeline, 20, '資料是這樣接進來的：從臺北市資料大平臺取得 12 筆資料集，後端依各資料集的更新頻率個別快取，過期才重抓、同時間的請求合併成一次；再依書櫃座標篩出最近的站點與出口，送到 App 的書櫃頁。'],
    [S.guards, 15, '資料來源故障時沿用上一份成功的資料，頁面照常顯示；伺服器啟動時先預載每日更新的靜態資料；出發的最近捷運站在手機上計算，使用者位置不會上傳伺服器。'],
    [S.checks, 15, '到了書櫃，開櫃有四道驗證：動態 QR Code、200 公尺內定位、60 秒內的兩位數比對，以及書櫃專屬憑證與關門回報。'],
    [S.demoFlow, 20, '賣家存書：掃描書櫃 QR Code、確認存書項目、輸入比對數字，A01 開鎖；放入書籍並關門，存書完成，系統通知買家取書。', { flow: 'deposit' }],
    [S.demoFlow, 15, '買家取書流程相同，取出書籍並關門後，訂單進入驗收。', { flow: 'pickup' }],
    [S.payout, 20, '金流採先驗收、後撥款：款項由平台暫管，取書後 24 小時內買家確認書況才撥款；期滿沒有爭議也會自動完成並撥款。'],
    [S.safety, 20, 'AI 也協助把關：上架時依實拍照片判斷書況並建議售價區間；有爭議時比對照片整理爭點，由管理員裁決；聊天室偵測到站外聯絡或私下付款，會即時提醒雙方。', SAFETY_TCGIA],
    [S.completeness, 15, '系統完整串起三端：使用者端從上架、選購、書櫃存取、交通指引到錢包與爭議；管理端負責審核、爭議仲裁與書櫃裝置管理；書櫃端負責顯示比對碼、開鎖與回報開關門。'],
    [S.tests, 10, '後端 1,563 項、App 2,815 項測試全數通過，共 301 個 API 端點；書櫃估算妥善率約 99.7%。', { sub: '上架、付款暫管、存書、取書、撥款與爭議處理皆可實際操作' }],
    [S.backup, 15, '出狀況時也有備援：書櫃逾 15 秒沒回報視為離線，5 分鐘通知管理員；斷線事件先存本機、恢復後補送；金流以條件式更新，不會重複扣款或撥款。'],
    [S.extend, 15, '擴充上，AI 供應商可切換；書櫃單台電子零件約 3,209 元，以配對碼加入；可以和臺北市的學校、圖書館、社區或商家合作，鄰近捷運、公車或 YouBike 的地點尤其適合。',
      { items: [[null, 'AI 供應商可切換', 'OpenAI 與 Google Gemini\n後台控管用量'],
        [null, '書櫃複製擴點', '單台電子零件約 3,209 元\n配對碼即可加入'],
        [null, '臺北場域合作', '鄰近捷運、公車\n或 YouBike 尤佳']] }],
    [S.ending, 10, '救「舊」我的書，讓閒置的書，重新流動。謝謝評審，敬請指教。']
  ]
};

async function build(deck) {
  const pres = new pptxgen();
  pres.layout = 'LAYOUT_WIDE';
  pres.theme = { headFontFace: THEME.headFontFace, bodyFontFace: THEME.bodyFontFace };
  pres.title = '救「舊」我的書';
  pres.subject = `InnoServe 決賽簡報　${deck.group}`;
  pres.author = 'SaveMyBook';
  const k = kit(pres);
  let total = 0;
  const script = [`# ${deck.file.replace('－', '　')}講稿`, '', `現場說明與展示約 6 分鐘。秒數是目標時間，影片頁進入即自動循環播放（靜音）。`, ''];
  deck.slides.forEach(([fn, sec, notes, extra], i) => {
    total += sec;
    pres.sectionName = `${String(i + 1).padStart(2, '0')} ${label(fn, extra || {})}`;
    pres.addSection({ title: pres.sectionName });
    fn(pres, k, { ...(extra || {}), notes: `【約 ${sec} 秒】${notes}` });
    script.push(`## ${i + 1}．${label(fn, extra || {})}（約 ${sec} 秒，累計 ${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}）`, '', notes, '');
  });
  fs.mkdirSync(OUT, { recursive: true });
  const file = path.join(OUT, `${deck.file}.pptx`);
  await pres.writeFile({ fileName: file });
  await postprocess(file);
  fs.writeFileSync(path.join(OUT, `${deck.file}－講稿.md`), script.join('\n'));
  console.log(`${deck.file}.pptx　${deck.slides.length} 頁，約 ${Math.floor(total / 60)} 分 ${total % 60} 秒`);
}

(async () => {
  for (const d of [IP, TCGIA]) await build(d);
})().catch((e) => { console.error(e); process.exit(1); });
