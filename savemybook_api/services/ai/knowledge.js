const prisma = require('../../lib/prisma');
const { clip } = require('../../lib/text');
const { ORDER_STATUS_LABELS, ORDER_STATUS_ALIASES } = require('../../constants/domain');
const policy = require('../../constants/policy');
const lexical = require('./lexical');
const semantic = require('./semantic');

const INDEX_TTL_MS = 2 * 60 * 1000;
const LEGAL_CHUNK_CHARS = 420;
const FAQ_ANSWER_CHARS = 1200;
const DEFAULT_TOP_K = 6;
const DEFAULT_BUDGET = 4200;
const RELATIVE_CUTOFF = 0.3;

const ORDER_STATUS_NAMES = [...new Set([
  ...Object.values(ORDER_STATUS_LABELS),
  ...Object.values(ORDER_STATUS_ALIASES).flat()
])].join(' ');

const CANCELLABLE_LABELS = policy.ORDER_CANCELLABLE_STATUSES.map((s) => ORDER_STATUS_LABELS[s]).join('或');

// 平台說明依主題拆開；keywords 與 en（英文介面使用者的說法）只參與檢索、不送給模型。
// 文件是中文，英文提問只能命中 en，所以 en 不可放 long、when、open 這類各主題都會出現的通用詞。
// 期限與金額一律取自 constants/policy.js，不可在文字中另寫數字。
const PLATFORM_TOPICS = [
  {
    id: 'about',
    title: '平台簡介',
    keywords: '平台 是什麼 介紹 代幣 台幣 匯率 智慧書櫃 二手書',
    en: 'platform coin coins token tokens currency exchange rate twd ntd secondhand',
    text: 'SaveMyBook 是結合智慧書櫃的二手書交易平台。站內以代幣結算，1 代幣等值新臺幣 1 元。賣家把書存入智慧書櫃，買家到書櫃取書，雙方不需要當面交付。'
  },
  {
    id: 'listing',
    title: '上架販售',
    keywords: '上架 賣書 刊登 販售 賣東西 新增書籍 ISBN 條碼 照片 書況 售價 定價 價格 多少錢 編輯 修改 下架 取消上架 刪除 重新上架',
    en: 'list listing listings sell selling post upload barcode photo photos picture pictures condition price pricing edit delist unlist relist',
    text: `賣家在 App 填寫書名、售價（大於 0 且不超過 ${policy.LISTING_MAX_PRICE} 代幣）、書況並上傳照片（每本最多 ${policy.LISTING_MAX_IMAGES} 張）即可上架，輸入或掃描 ISBN 可自動帶入書目資料。賣家可編輯或取消上架自己的書籍（狀態改為已下架），已下架的書籍仍可編輯；但預約保留期間或已有訂單的書籍無法編輯或取消上架。書籍存放於書櫃期間無法編輯（含售價、照片與書櫃），存放於書櫃的書籍取消上架後，須先至書櫃以 App 掃描 QR Code 取回，才能編輯或重新上架。因違規遭管理員下架的書籍無法自行重新上架，須聯絡客服。`
  },
  {
    id: 'review',
    title: '上架審核',
    keywords: '審核 審核中 送審 待審核 沒有上架 看不到 搜尋不到 被下架 未通過 駁回 違規 多久 為什麼',
    en: 'review reviewing moderation approval approve approved rejected rejection hidden invisible visible search violation',
    text: `上架後系統會自動檢查內容。售價明顯高於同書行情或一般二手書價格（例如 ${policy.LISTING_REVIEW_PRICE} 代幣以上）、疑似圖書館館藏或非賣品、非書籍商品、留下站外聯絡方式等情況，書籍會先送交人工審核，審核期間不會公開販售，賣家會收到「書籍已送交審核」通知。管理員核准後自動公開；未通過會下架並通知原因，已成立但買家尚未取書的訂單自動取消並全額退款；已取書的訂單照常進行，書籍停止公開顯示。審核時間依管理員處理進度而定，平台沒有承諾固定時限。`
  },
  {
    id: 'buying',
    title: '購買與付款',
    keywords: '購買 買書 結帳 付款 購物車 扣款 交易密碼 生物辨識 指紋 臉部 多位賣家 拆單 分次結帳 幾本 上限',
    en: 'buy buying purchase purchasing checkout pay payment paying cart pin biometric biometrics fingerprint face sellers split limit maximum',
    text: '買家將書加入購物車後結帳，結帳時立即從錢包扣除代幣，並需以交易密碼或生物辨識驗證。'
      + '結帳時依賣家與書籍指定的書櫃拆成多筆訂單，'
      + `同一賣家於同一書櫃的書籍，每筆訂單最多 ${policy.ORDER_MAX_BOOKS} 本，超過時請分次結帳。錢包餘額不足時無法結帳。`
  },
  {
    id: 'order-flow',
    title: '訂單流程',
    keywords: `訂單 狀態 進度 顯示 意思 什麼時候 多久 撥款 收款 入帳 待撥款項 待定收益 直接取書 完成訂單 自動完成 ${ORDER_STATUS_NAMES}`,
    en: 'order orders status progress payout payouts paid release released earnings income complete completed completion confirm awaiting',
    text: '結帳時即從買家錢包扣除代幣，款項由平台代為保管。訂單狀態依序為：待付款 → 待存書（買家端顯示「待賣家存書」）→ 已存書或待取書（買家端顯示「待取書」）→ 已完成。'
      + '訂單內的書籍皆已先行存入訂單指定的書櫃時，訂單成立即為已存書，買家可直接前往書櫃取書；'
      + '僅部分書籍已存入書櫃時，訂單仍為待存書，全部書籍存入後才轉為已存書並通知買家取書。'
      + '買家取書後、訂單完成前，買家端顯示「待完成訂單」，賣家端顯示「待買家確認」。'
      + `買家可在 App 按下「完成訂單」；未按下者，取書滿 ${policy.ORDER_AUTO_COMPLETE_HOURS} 小時且未申請爭議時，訂單自動完成。`
      + '訂單完成時款項才撥入賣家錢包，撥款前列於賣家錢包的「待撥款項」。'
      + '其他狀態：已取消；爭議處理中（舊版 App 顯示為「審核中」），表示訂單有處理中的交易爭議，訂單暫停進行，待管理員裁決；已退款。'
  },
  {
    id: 'cabinet',
    title: '智慧書櫃存書與取書',
    keywords: '書櫃 櫃子 置物櫃 存書 放書 先存 先行存書 預先存書 上架後存書 取書 拿書 取件 取貨 取回 暫停販售 取件碼 密碼 營業時間 地點 位置 在哪 打不開 開不了 壞掉 故障 連線中斷 離線 手動回報',
    en: 'locker lockers cabinet drop dropoff deposit deposited store stored retrieve location address broken stuck jammed offline manual',
    text: '賣家可在書籍上架後、訂單成立前，先把書存入該書指定的智慧書櫃（先行存書）；'
      + `也可以等訂單成立後，於 ${policy.ORDER_DEPOSIT_DAYS} 天內存入訂單指定的書櫃。`
      + '訂單內的書籍皆已先行存入訂單指定的書櫃時，買家下單後可直接到書櫃取書；僅部分書籍先行存書時，其餘書籍須在期限內存入訂單指定的書櫃。'
      + `存書滿 ${policy.DEPOSIT_PAUSE_DAYS} 天仍未售出，書籍會暫停販售，須至書櫃取回，因逾期而暫停販售的書取回後會自動恢復上架；`
      + `之後每 ${policy.DEPOSIT_REMIND_DAYS} 天會再提醒一次，滿 ${policy.DEPOSIT_ESCALATE_DAYS} 天仍未取回者，平台得派員取出並下架，取出後會通知賣家並代為保管 ${policy.DEPOSIT_REMOVED_KEEP_DAYS} 天，需領回請聯絡客服，逾期未領回視為拋棄。`
      + '存書期間無法變更書櫃。存書、取書與取回一律在書櫃旁以 App 掃描書櫃螢幕上的 QR Code 辦理。平台沒有取件碼，請勿向任何人索取或提供取件碼。'
      + '書櫃位置與營業時間可在 App 選擇書櫃時查看。書櫃故障或無法開啟時請轉接客服人員；書櫃連線中斷或故障期間可改為手動回報，經客服確認後才生效。'
  },
  {
    id: 'cabinet-capacity',
    title: '先行存書上限與櫃門分配',
    keywords: '先行存書 幾本 櫃門 可用櫃門 櫃門不足 分配 保留 放幾本 容量 滿了 部分存入 存不下 其餘書籍',
    en: 'limit limits capacity full compartment compartments quota partial remaining',
    text: `每位賣家在同一台書櫃最多先行存放 ${policy.CABINET_PREDEPOSIT_MAX_PER_SELLER} 本尚未售出的書，須待售出或取回後才能再先行存放。`
      + `書櫃僅剩 ${policy.CABINET_ORDER_RESERVED_DOORS} 扇可用櫃門時保留給訂單使用，暫停受理先行存放。`
      + '每扇櫃門只存放 1 本書，訂單書籍由系統逐本分配櫃門。'
      + '可用櫃門不足時，可先存入放得下的書籍，其餘書籍待有空櫃門時再存入；'
      + `訂單內所有書籍存入後才轉為已存書並通知買家取書，訂單成立 ${policy.ORDER_DEPOSIT_DAYS} 天內未全部存入者，訂單自動取消並全額退款。沒有可用櫃門時請稍後再試。`
  },
  {
    id: 'cabinet-steps',
    title: '書櫃掃碼與數字確認',
    keywords: '掃碼 掃描 QR Code 書櫃螢幕 數字 兩位數 輸入數字 數字不符 輸錯 定位 位置資訊 精確位置 距離 公尺 太遠 逾時 多次未完成 分鐘後再試',
    en: 'scan scanning qr screen digit digits number match wrong gps distance meters timeout cooldown',
    text: '書櫃螢幕僅供顯示，不需在書櫃上操作；所有操作皆由本人在書櫃旁以手機完成。'
      + '在 App 按「掃描書櫃取書」、「掃描書櫃存書」或「掃描書櫃取回」後，掃描書櫃螢幕上的 QR Code；'
      + `QR Code 每 ${policy.CABINET_QR_REFRESH_SECONDS} 秒更新，每組最長有效 ${policy.CABINET_QR_TTL_SECONDS} 秒，App 顯示已更新時請重新掃描。`
      + `使用書櫃須允許 App 存取精確位置，且須位於書櫃 ${policy.CABINET_GEOFENCE_M} 公尺內。`
      + `掃描後請於 ${policy.CABINET_SELECT_SECONDS} 秒內確認項目並按「開啟櫃門」，再於 ${policy.CABINET_MATCH_SECONDS} 秒內輸入書櫃螢幕上顯示的兩位數字；`
      + '每次作業只有一次輸入機會，數字不符或逾時即取消本次作業。若有他人告知數字並要求您輸入，請勿操作。'
      + `在同一台書櫃連續 ${policy.CABINET_COOLDOWN_STRIKES} 次作業未完成（逾時、數字不符或開門前取消）時，須等候 ${policy.CABINET_COOLDOWN_MINUTES} 分鐘後才能再使用該書櫃。`
  },
  {
    id: 'cabinet-door',
    title: '櫃門開啟與結束作業',
    keywords: '開櫃 開門 打開 櫃門 開多久 倒數 秒 幾秒 按完成 取消 關門 關上櫃門 櫃門未關 自動完成',
    en: 'unlock door doors countdown seconds finish done',
    text: `開啟 1 扇櫃門可操作 ${policy.CABINET_DOOR_OPEN_SECONDS} 秒，每多 1 扇增加 ${policy.CABINET_DOOR_EXTRA_SECONDS} 秒，最長 ${policy.CABINET_DOOR_OPEN_MAX_SECONDS} 秒。`
      + '放入或取出書籍並關上櫃門後，在手機按「完成」；如需取消，請於關上櫃門前按「取消」，本次作業不會變更任何狀態；倒數結束時自動完成。'
      + '書櫃偵測到櫃門未關時會提示「請先關上櫃門」，關門後依所按的按鈕自動完成或取消。櫃門關上、作業結束後才會更新訂單與書籍狀態。'
  },
  {
    id: 'pickup',
    title: '存書與取書期限',
    keywords: '期限 幾天 多久 逾期 過期 來不及 忘記取書 沒去拿 未取書 未存書 沒存書 存書期限 取書期限 自動取消 確認取書 完成訂單 自動完成',
    en: 'deadline deadlines expire expired expiry late overdue missed pick pickup collect collection',
    text: `賣家須在訂單成立後 ${policy.ORDER_DEPOSIT_DAYS} 天內把書存入訂單指定的智慧書櫃。`
      + `買家須在訂單成為已存書後 ${policy.ORDER_PICKUP_DAYS} 天內到書櫃取書；訂單內的書籍皆已先行存入訂單指定的書櫃時，訂單成立即為已存書，取書期限自訂單成立時起算。`
      + '賣家逾期未存書或買家逾期未取書時，訂單自動取消，代幣全額退回買家錢包，書籍改為下架。'
      + `買家取書後可在 App 按下「完成訂單」；未按下者，取書滿 ${policy.ORDER_AUTO_COMPLETE_HOURS} 小時且未申請爭議時，訂單自動完成並撥款給賣家。`
  },
  {
    id: 'wallet',
    title: '錢包與代幣',
    keywords: '錢包 代幣 餘額 儲值 加值 充值 提領 提現 領錢 轉出 匯款 銀行 入帳 收入 紀錄 明細',
    en: 'wallet balance coins top topup funds reload withdraw withdrawal cash cashout bank income transactions statement',
    text: '錢包餘額來源包含：售出入帳（訂單完成時撥入）、取消退款、爭議退款、管理員調整與聊天室轉帳。App 目前沒有自助儲值與提領功能，需要儲值或提領請轉接客服人員處理。錢包頁可查看每筆收支明細。'
  },
  {
    id: 'reservation',
    title: '預約保留',
    keywords: '預約 保留 留書 先幫我留 等我 幾小時 期限 逾期 取消預約',
    en: 'reserve reserved reservation reservations hold holding aside',
    text: `買家可在與賣家的一對一聊天室預約書籍，保留時間可選 ${policy.RESERVATION_HOLD_HOURS.join('、')} 小時。`
      + `賣家 ${policy.RESERVATION_RESPONSE_HOURS} 小時內未回覆，預約會自動失效。`
      + '賣家接受後，書籍在期限內只保留給該買家，其他買家無法購買，賣家也不得編輯或取消上架；買家須在期限內完成購買，逾期自動取消。'
      + `每位買家同時最多 ${policy.RESERVATION_MAX_ACTIVE} 筆進行中的預約。`
      + '書籍經審核下架時，進行中的預約會自動取消並通知買家。'
  },
  {
    id: 'cancel',
    title: '取消訂單與退款',
    keywords: '取消 取消訂單 不想買 退款 退錢 退費 退回 多久退 買錯 無法取消 不能取消 還能取消 先行存書 預先存書',
    en: 'cancel cancelling canceling cancellation cancelled refund refunds refunded mistake',
    text: `${CANCELLABLE_LABELS}（賣家尚未存書）的訂單，買賣雙方皆可在 App 取消，已付的代幣全額退回買家錢包。`
      + '賣家存書後雙方皆無法自行取消，如有問題請申請爭議；訂單內的書籍皆已先行存入訂單指定的書櫃時，訂單成立即為已存書，因此也無法取消。'
      + '僅部分書籍已存入書櫃的訂單仍為待存書，賣家存入全部書籍前雙方仍可取消。'
      + '爭議處理中（舊版 App 顯示為「審核中」）的訂單須等候管理員裁決，無法自行取消；已完成、已取消或已退款的訂單無法取消。'
      + `賣家逾 ${policy.ORDER_DEPOSIT_DAYS} 天未存書（含未存齊）或買家逾 ${policy.ORDER_PICKUP_DAYS} 天未取書時，訂單自動取消並全額退款。`
  },
  {
    id: 'dispute',
    title: '交易爭議',
    keywords: `爭議 申訴 客訴 書況不符 破損 缺頁 不一樣 沒收到 貨不對 退貨 糾紛 仲裁 有問題 ${ORDER_STATUS_NAMES}`,
    en: 'dispute disputes complaint complain damaged damage missing pages torn wrong received described mismatch return',
    text: '書況與描述有重大落差或未收到書籍時，可在 App 對訂單申請爭議。'
      + `取書前可隨時申請；取書後須在 ${policy.DISPUTE_WINDOW_HOURS} 小時內、且訂單完成前申請。`
      + '訂單狀態變成已完成後不再受理爭議，買家按下「完成訂單」即視為放棄爭議權利。已取消或已退款的訂單無法申請爭議。'
      + '申請後訂單轉為爭議處理中（舊版 App 顯示為「審核中」）並暫停進行，由管理員裁決退款、駁回或協調結案：'
      + '裁決退款時，代幣退回買家錢包；駁回或協調結案時，已取書的訂單直接完成並撥款給賣家，尚未取書的訂單恢復原本進度。'
      + '同一訂單同時只能有一筆處理中的爭議。'
  },
  {
    id: 'chat-transfer',
    title: '聊天室轉帳與請款',
    keywords: '聊天 聊天室 轉帳 請款 付款給 群組 收款 私訊 封鎖 靜音',
    en: 'chat chats transfer transfers group mute block',
    text: '一對一或群組聊天室可轉帳代幣或向成員請款，付款需交易密碼或生物辨識驗證。'
      + `單筆金額上限 ${policy.CHAT_TRANSFER_MAX_AMOUNT} 代幣，請款 ${policy.CHAT_REQUEST_TTL_HOURS} 小時內未付款會失效。可對聊天對象靜音或封鎖。`
  },
  {
    id: 'report',
    title: '檢舉',
    keywords: '檢舉 舉報 違規 詐騙 騷擾 假貨 不當',
    en: 'report reporting scam scammer fraud fake harassment harass harassing abuse spam inappropriate',
    text: '可檢舉違規的使用者、商品或訊息。審核期間商品照常販售，管理員確認違規成立才會下架或處置。'
      + '商品經審核下架時，進行中的預約與尚未取書的訂單會一併取消，已付代幣全額退還；已取書的訂單照常進行，商品停止公開顯示。'
  },
  {
    id: 'account',
    title: '帳號與安全',
    keywords: '帳號 註冊 登入 登不進去 忘記密碼 改密碼 交易密碼 通行密鑰 Passkey 綁定 Google LINE 刪除帳號 註銷 停權 黑名單 個資 資料匯出',
    en: 'account signup register login password reset unlink delete deactivate suspended banned ban privacy export',
    text: '可使用電子郵件與密碼、社群帳號或通行密鑰登入，並可在設定中綁定或解除社群帳號、更改密碼與交易密碼、登出其他所有裝置、匯出我的資料。'
      + `可在 App 申請刪除帳號，有 ${policy.ACCOUNT_DELETION_GRACE_DAYS} 天緩衝期可隨時取消；仍有進行中的訂單或仍有書籍存放於書櫃時無法申請。帳號遭停權或登入異常請轉接客服人員。`
  },
  {
    id: 'level',
    title: '會員等級',
    keywords: '會員 等級 積分 點數 升級 徽章',
    en: 'member membership level levels tier tiers points badge badges upgrade rank',
    text: `會員等級依積分計算，每完成一筆訂單可獲得 ${policy.LEVEL_POINTS_PER_ORDER} 點積分。各等級門檻可在 App 的會員等級頁查看。`
  },
  {
    id: 'ai',
    title: 'AI 功能',
    keywords: 'AI 人工智慧 機器人 客服 推薦 書籍顧問 上架輔助 同意',
    en: 'artificial intelligence bot chatbot assistant recommendation recommendations advisor assist consent',
    text: 'App 內的 AI 功能包含：AI 客服、上架輔助（依照片或 ISBN 產生書目與描述）、推薦書籍與 AI 書籍顧問。使用前須同意 AI 資料處理，每日使用次數有上限。AI 客服無法處理的問題可轉接客服人員。'
  },
  {
    id: 'handoff',
    title: '轉接客服人員',
    keywords: '真人 客服 人工 轉接 聯絡 客服人員 工單 提問 回覆 多久回',
    en: 'human agent staff representative ticket tickets enquiry inquiry customer',
    text: '使用者可在 AI 客服畫面轉接客服人員，系統會建立提問紀錄並附上對話內容，客服人員回覆後會通知使用者，可在「客服中心」查看提問紀錄與回覆。'
  }
];

const SYNONYMS = [
  [['退錢', '退費', '退回來'], '退款'],
  [['拿書', '取件', '取貨', '領書'], '取書'],
  [['放書', '放進', '寄放'], '存書'],
  [['加值', '充值', '買代幣', '儲值'], '儲值'],
  [['提現', '領錢', '領出', '轉出', '換現金'], '提領'],
  [['賣書', '刊登', '販售'], '上架'],
  [['櫃子', '置物櫃', '櫃位'], '書櫃'],
  [['預先存書', '先存'], '先行存書'],
  [['申訴', '客訴', '糾紛', '書況不符'], '爭議'],
  [['舉報'], '檢舉'],
  [['註銷', '刪帳', '刪除帳號'], '刪除帳號'],
  [['真人', '人工', '專人'], '客服人員'],
  [['留書', '幫我留'], '預約'],
  [['錢包', '餘額'], '代幣'],
  [['一天', '每天', '一日'], '每日'],
  [['審核中', '送審', '待審'], '審核']
];

const expandQuery = (text) => {
  const s = lexical.normalize(text);
  const extra = [];
  for (const [variants, canonical] of SYNONYMS) {
    if (variants.some((v) => s.includes(v))) extra.push(canonical);
  }
  return extra.length ? `${text} ${extra.join(' ')}` : text;
};

const splitLegal = (title, content) => {
  const text = String(content ?? '').replace(/\r\n?/g, '\n').trim();
  if (!text) return [];
  const blocks = text
    .split(/\n\s*\n|(?=\n\s*第\s*[一二三四五六七八九十百\d]+\s*條)|(?=\n\s*[一二三四五六七八九十]+、)/)
    .map((b) => b.replace(/\s+/g, ' ').trim())
    .filter(Boolean);
  const chunks = [];
  let current = '';
  const push = () => {
    if (current.trim()) chunks.push(current.trim());
    current = '';
  };
  for (const block of blocks) {
    if (block.length > LEGAL_CHUNK_CHARS) {
      push();
      const sentences = block.split(/(?<=[。；！？])/);
      for (const sentence of sentences) {
        if (current.length + sentence.length > LEGAL_CHUNK_CHARS) push();
        current += sentence;
      }
      push();
    } else {
      if (current.length + block.length + 1 > LEGAL_CHUNK_CHARS) push();
      current += `${current ? ' ' : ''}${block}`;
    }
  }
  push();
  return chunks.map((c, i) => ({ id: `legal:${title}:${i}`, source: 'legal', title: `《${title}》`, text: c }));
};

const loadDocuments = async () => {
  const [faqs, legal] = await Promise.all([
    prisma.faqs.findMany({
      where: { is_visible: true },
      orderBy: [{ category: 'asc' }, { sort_order: 'asc' }, { faq_id: 'asc' }],
      select: { faq_id: true, category: true, question: true, answer: true }
    }),
    prisma.legal_documents.findMany({ select: { title: true, content: true }, orderBy: { doc_id: 'asc' }, take: 20 })
  ]);

  const docs = PLATFORM_TOPICS.map((t) => ({
    id: `platform:${t.id}`, source: 'platform', title: t.title, text: t.text, keywords: `${t.keywords} ${t.en}`
  }));
  for (const f of faqs) {
    docs.push({
      id: `faq:${f.faq_id}`,
      source: 'faq',
      title: `常見問題（${clip(String(f.category ?? ''), 30)}）`,
      text: `問：${clip(String(f.question), 200)}\n答：${clip(String(f.answer), FAQ_ANSWER_CHARS)}`,
      keywords: clip(String(f.question), 200)
    });
  }
  for (const d of legal) docs.push(...splitLegal(clip(String(d.title), 100), d.content));
  return docs;
};

// 知識段落以內容雜湊當向量的鍵：條款改版後段落切分會變，用內容比對才不會沿用錯的向量。
const buildIndex = (docs) => lexical.buildIndex(docs.map((doc) => {
  const text = `${doc.title}\n${doc.text}`;
  const hash = semantic.hashOf(text);
  return {
    ...doc,
    embed: { ref: hash, text, hash },
    fields: [{ text: doc.title }, { text: doc.keywords ?? '' }, { text: doc.text }]
  };
}));

let cached = null;

const index = async () => {
  if (cached && Date.now() - cached.at < INDEX_TTL_MS) return cached.value;
  const value = buildIndex(await loadDocuments());
  cached = { value, at: Date.now() };
  return value;
};

const invalidate = () => {
  cached = null;
};

// query 是本次提問；context 是先前幾則使用者訊息，權重較低，讓「那要多久？」這類追問也能找到前文主題。
const search = async (query, { context = [], topK = DEFAULT_TOP_K, budget = DEFAULT_BUDGET, userId = null, inlineSync = true, trace = null } = {}) => {
  const idx = await index();
  const weights = lexical.queryWeights([
    { text: query, weight: 1 },
    ...context.filter(Boolean).map((text, i) => ({ text, weight: i === context.length - 1 ? 0.5 : 0.3 }))
  ], expandQuery);
  const lexicalRanked = lexical.rank(idx, weights);
  const lexicalFloor = lexicalRanked.length ? lexicalRanked[0].score * RELATIVE_CUTOFF : Infinity;
  const lexicalKept = lexicalRanked.filter((r) => r.score >= lexicalFloor);

  const docs = idx.entries.map((e) => e.doc);
  const byRef = new Map(docs.map((d) => [d.embed.ref, d]));
  const semanticQuery = [context[context.length - 1], query].filter(Boolean).join('\n');
  const semanticKept = semantic.relevant(
    await semantic.rank('knowledge', docs.map((d) => d.embed), semanticQuery, { userId, inlineSync, trace }),
    { relative: 0.8, limit: topK * 2 }
  );
  if (lexicalKept.length === 0 && semanticKept.length === 0) return [];

  const lexicalScore = new Map(lexicalRanked.map((r) => [r.doc.id, r.score]));
  const similarity = new Map(semanticKept.map((r) => [byRef.get(r.ref).id, r.similarity]));
  const fused = semantic.fuse([
    { ids: lexicalKept.map((r) => r.doc.id) },
    { ids: semanticKept.map((r) => byRef.get(r.ref).id) }
  ]);
  const byId = new Map(docs.map((d) => [d.id, d]));
  const ranked = [...fused.entries()].sort((a, b) => b[1] - a[1]).map(([id]) => byId.get(id));

  const picked = [];
  let used = 0;
  for (const doc of ranked) {
    if (picked.length >= topK) break;
    const size = doc.title.length + doc.text.length;
    if (used + size > budget && picked.length > 0) continue;
    const { embed, fields, ...rest } = doc;
    picked.push({
      ...rest,
      score: Math.round((lexicalScore.get(doc.id) ?? 0) * 100) / 100,
      similarity: similarity.has(doc.id) ? Math.round(similarity.get(doc.id) * 1000) / 1000 : null
    });
    used += size;
  }
  return picked;
};

const TOPIC_CONFIDENT_SCORE = 4.5;
const TOPIC_CONTEXT_WEIGHTS = [1, 0.3, 0.2];

let topicIndex = null;

const topTopic = (parts) => {
  topicIndex ??= lexical.buildIndex(PLATFORM_TOPICS.map((t) => ({
    id: t.id, fields: [{ text: t.title }, { text: `${t.keywords} ${t.en}` }, { text: t.text }]
  })));
  return lexical.rank(topicIndex, lexical.queryWeights(parts, expandQuery), { strong: true })[0] ?? null;
};

// texts 須依新到舊排列；分數門檻以這份只含平台主題的固定索引校準，不可改用含常見問題與條款的檢索索引。
const topicOf = (texts) => {
  const questions = texts.filter(Boolean);
  for (const text of questions) {
    const top = topTopic([{ text, weight: 1 }]);
    if (top && top.score >= TOPIC_CONFIDENT_SCORE) return top.doc.id;
  }
  const combined = topTopic(questions.slice(0, TOPIC_CONTEXT_WEIGHTS.length).map((text, i) => ({ text, weight: TOPIC_CONTEXT_WEIGHTS[i] })));
  return combined?.doc.id ?? null;
};

const warm = async () => {
  const idx = await index();
  return semantic.sync('knowledge', idx.entries.map((e) => e.doc.embed));
};

const format = (docs) => (docs.length
  ? docs.map((d, i) => `[${i + 1}] ${d.title}\n${d.text}`).join('\n\n')
  : '（沒有找到相關資料）');

module.exports = {
  PLATFORM_TOPICS, SYNONYMS, tokenize: lexical.tokenize, expandQuery, splitLegal, buildIndex, search, topicOf, warm, format, invalidate
};
