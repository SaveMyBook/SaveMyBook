import copy
from docx.shared import Cm
from doctools import *
from seqdesc import SEQ

D = '/Users/xukaijun/Desktop/SaveMyBook/Diagrams/'
UC, SQ, ST, ER = D + 'Use Case/v3/', D + 'Sequence Diagrams/v3/', D + 'State Machine/v3/', D + 'Relational Tables/v3/'
# 智慧書櫃（掃碼存取）相關之圖：原始碼與圖檔置於 scratchpad/cabdiag
CAB = __import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)), 'cabdiag') + '/'
CUC, CSQ, CST, CER, CAR, CCL = CAB + 'uc/', CAB + 'seq/', CAB + 'state/', CAB + 'er/', CAB + 'arch/', CAB + 'class/'
# AI 改善後有變動之 ER 圖（gen_er.py 產生）：原始碼與圖檔置於 scratchpad/aidiag/er
AER = __import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)), 'aidiag', 'er') + '/'
CAB_SEQ = {'seq_deposit', 'seq_deposit_retrieval', 'seq_pickup',
           'seq_cabinet_manual_report', 'seq_cabinet_pairing', 'seq_cabinet_admin_open'}

# 既有圖：圖號 → (新圖檔, 新圖名, 說明)
FIGS = {
    '5-2-1': (UC + 'uc_account.png', '帳號與安全模組之使用個案圖',
              '本圖描繪帳號與安全模組之使用個案，參與者為訪客、會員與第三方登入服務。訪客可註冊帳號或登入，登入方式包含密碼登入、第三方登入（Google、Apple、LINE、Discord）與通行密鑰登入，登入時一律須同意最新版之服務條款與隱私權政策。會員登入後可管理個人資料、登入方式、交易密碼與生物辨識、登入裝置，並可匯出資料或申請刪除帳號；其中變更登入方式、交易密碼與刪除帳號皆須先通過身分驗證。'),
    '5-2-2': (UC + 'uc_books.png', '書籍與商品管理模組之使用個案圖',
              '本圖描繪書籍與商品管理模組之使用個案，參與者為賣家、買家與AI服務。賣家管理書籍時可上架、編輯、下架或重新上架；上架時可選用ISBN條碼掃描與AI輔助帶入書籍資訊，並一律經過上架審核，系統另依ISBN自動補齊空白之書籍資料。買家可瀏覽與搜尋書籍、查看書籍詳情與相似書籍、查看個人化推薦、收藏書籍，並可檢舉違規商品。'),
    '5-2-3': (CUC + 'uc_orders.png', '交易與訂單模組之使用個案圖',
              '本圖描繪交易與訂單模組之使用個案，參與者為買家、賣家與管理員。買家可將書籍加入購物車後結帳，或於書籍頁直接購買，兩者皆須通過付款驗證；買家可於「我的預約」查看已保留與待賣家回覆之預約，於「訂單紀錄」查看購買訂單，並至訂單指定之書櫃掃描QR Code取書，確認書況後完成訂單。賣家可於「訂單紀錄」查看銷售訂單，掃描書櫃QR Code依訂單存書，亦可於書籍上架後先行存書，並可掃描書櫃取回書籍。掃描書櫃取書、存書與取回皆屬「掃描書櫃開啟櫃門」，開啟櫃門時須於手機輸入書櫃螢幕上顯示之兩位數比對數字；書櫃未配對裝置或裝置離線、故障時，可改為手動回報，由管理員確認後生效。雙方可於存書前取消訂單，交易發生問題時可申請爭議，由管理員仲裁。'),
    '5-2-4': (UC + 'uc_chat.png', '聊天與社交模組之使用個案圖',
              '本圖描繪聊天與社交模組之使用個案，參與者為會員與管理員。會員可傳送訊息、建立與管理群組、預約保留書籍、站內轉帳或請款，並可設定暱稱、靜音、置頂或封鎖檢舉其他使用者，亦可使用AI問書；轉帳與請款皆須通過付款驗證。傳送聯絡方式或付款資訊前系統請傳送者確認，群組內可@提及成員；收訊方可查看防詐提醒並檢舉可疑訊息，高風險情形則由管理員處理防詐警示。'),
    '5-2-5': (UC + 'uc_wallet_support.png', '錢包、會員成長與客服模組之使用個案圖',
              '本圖描繪錢包、會員成長與客服模組之使用個案，參與者為會員與管理員。會員可管理代幣，查看交易紀錄與待撥款項，並查看會員等級與成就；遇到問題時可查看常見問題、使用AI客服，必要時轉真人客服，或直接建立客服工單並往來回覆。管理員負責調整會員錢包與處理客服工單。'),
    '5-2-6': (CUC + 'uc_admin.png', '後台管理模組之使用個案圖',
              '本圖彙整後台管理模組之使用個案，參與者為管理員與AI服務。管理員可查看營運總覽，管理會員與等級、書籍與分類、訂單、公告與文件，並處理客服工單與查看操作紀錄與復原。內容審核包含上架審核、處理檢舉與處理防詐警示；仲裁交易爭議時可使用AI分析作為參考；管理智慧書櫃包含配對書櫃裝置、遠端開啟櫃門、處理待確認作業與櫃門、確認手動回報與登記取出存書；系統設定則包含AI功能、登入方式與資料庫備份還原。各項功能依管理員權限開放。'),
    '5-4-1': (CCL + 'analysis_class.png', '分析類別圖',
              '本圖呈現系統於需求分析階段之主要領域類別與其關聯。使用者可擁有會員錢包、購物車、上架之書籍、訂單、聊天室與推播通知；訂單包含所購買之書籍，指定取貨之智慧書櫃據點，並於結算時撥款至錢包，交易發生問題時可產生交易爭議案件。智慧書櫃據點由多扇櫃門組成；預約管理保留特定書籍；聊天室包含多則聊天訊息，有風險之訊息另有對應之訊息風險紀錄。'),
    '6-2-1': (CCL + 'design_class.png', '設計類別圖',
              '本圖延續分析類別圖之劃分，為各類別補上資料型態、多重性與主要操作。訂單為交易核心，提供建立訂單、直接購買、確認存書、確認取書、完成與取消等操作，並於完成時結算至會員錢包；書籍商品提供上架、編輯、下架與資料補齊；交易爭議提供申請、AI分析與仲裁；聊天訊息提供傳送、收回與已讀，並由訊息風險紀錄進行防詐評估；推播通知則負責派送與已讀管理。'),
    '7-1-1': (CAR + 'deployment.png', '佈署圖',
              '本圖呈現系統之實體部署環境。行動裝置App與智慧書櫃終端經Cloudflare邊緣節點連線至學校伺服器；每台智慧書櫃由一片ESP32控制顯示螢幕與4組電磁鎖（對應4扇櫃門），並以HTTPS定時輪詢伺服器，取得螢幕顯示內容與開鎖指令；模擬書櫃網頁於瀏覽器執行與書櫃終端相同之裝置邏輯，供測試使用。伺服器以sslh多工器將HTTP流量轉交NGINX、SSH流量轉交OpenSSH；NGINX再將API請求、即時推送連線與模擬書櫃網頁（/kiosk）轉發至Express API服務，由其讀寫MariaDB資料庫。登入驗證、推播、AI服務與書目資料則由外部雲端服務提供。'),
    '7-2-1': (CAR + 'package.png', '套件圖',
              '本圖以分層方式呈現系統之套件劃分。展示層（Flutter）由共用元件、主題與語系設定及各功能畫面組成；應用層包含API服務、即時推送服務與推播服務，分別以REST API與Socket.IO連線至後端。後端之API層除Express應用程式與即時推送伺服器外，另提供裝置API（Device API）供智慧書櫃終端連線；請求經中介層進行身分驗證、敏感操作驗證與限流後，交由服務層之各項業務服務處理，其中書櫃服務（Cabinet Service）負責書櫃作業、裝置配對與櫃門管理，最後透過Prisma ORM存取MariaDB資料庫。'),
    '7-3-1': (CAR + 'component.png', '元件圖',
              '本圖以元件觀點呈現系統主要功能單元之提供與使用關係。訂單元件使用書籍、錢包、使用者與通知元件所提供之介面，並提供報表元件所需資料；書櫃元件使用訂單、書籍與通知元件所提供之介面，於櫃門關閉後提交存書、取書與取回之結果；聊天元件使用使用者與通知元件；AI元件同時提供書籍與聊天元件使用。App與智慧書櫃終端（ESP32）皆經API元件存取後端，API元件則使用書櫃元件所提供之書櫃作業介面。'),
    '7-4-1': (CST + 'state_books.png', '書籍商品之狀態機',
              '本狀態機描繪書籍商品之生命週期。賣家上架後書籍為販售中，售價異常、疑似非正規來源或AI審核需人工確認時轉為審核中，由管理員核准或駁回。販售中之書籍可被預約保留或由買家下單而進入交易中，訂單完成後轉為已售出；存書前取消訂單時回到販售中，逾期未存書或未取書則轉為已下架。書籍存放於書櫃滿七天仍無訂單時轉為暫停販售（待取回），賣家至書櫃掃碼取回後回到販售中，管理員登記取出後則轉為已下架。賣家可自行下架與重新上架，違規下架者須經管理員處理。'),
    '7-4-2': (CST + 'state_orders.png', '訂單之狀態機',
              '本狀態機描繪訂單之生命週期。買家付款時，若訂單內之書籍皆已存放於書櫃，訂單直接成為已存書，買家可立即取書；否則訂單為待存書，賣家掃描書櫃存書且櫃門關閉後轉為已存書。買家掃描書櫃取書且櫃門關閉後轉為待確認完成，買家完成訂單或取書滿24小時後轉為已完成並撥款給賣家；書櫃故障期間之手動回報，須經管理員確認後才轉換狀態。存書前可取消訂單，賣家逾期七天未存書或買家逾期七天未取書時系統自動取消並退款，惟書櫃紀錄顯示開門後未完成取書或櫃門異常時，改由管理員人工處理；交易有問題時可申請爭議，訂單轉為爭議處理中，管理員判定退款則轉為已退款，駁回時已取書之訂單直接完成。'),
    '7-4-3': (ST + 'state_disputes.png', '交易爭議之狀態機',
              '本狀態機描繪交易爭議案件之生命週期。買家或賣家申請爭議後案件為待處理，管理員裁決後轉為已結案，結案結果分為退款、駁回與調解三種；已結案之案件不可再變更。'),
    '7-4-4': (ST + 'state_reservation.png', '書籍預約之狀態機',
              '本狀態機描繪聊天室內書籍預約之生命週期。買家發起預約後為待回應，賣家接受即轉為保留中，保留期間其他買家無法購買該書；賣家婉拒或任一方取消時轉為已取消，24小時未回應或保留時間到期時轉為已逾期，並通知收藏此書之使用者。'),
    '7-4-5': (ST + 'state_support_ticket.png', '客服工單之狀態機',
              '本狀態機描繪客服工單之生命週期。使用者建立工單後為待處理，客服回覆後轉為等待使用者回覆，使用者再回覆則回到待處理。客服可將工單標示為已解決，使用者若再次回覆則重新開啟；任一方結案後工單轉為已結案，不可再回覆，如有新問題須另開工單。'),
    '7-4-6': (CST + 'state_cabinet_sessions.png', '書櫃作業之狀態機',
              '本狀態機描繪書櫃作業（使用者掃描書櫃QR Code至櫃門關閉之一次過程）之生命週期。使用者掃碼後作業為確認項目中，於手機確認項目並按「開啟櫃門」後，系統分配櫃門並產生兩位數比對碼，轉為數字比對中；使用者須於60秒內在手機輸入書櫃螢幕上之數字，且僅有一次機會，相符即轉為開門中，不符轉為失敗，逾時則轉為已逾時；開門前使用者可於手機取消，管理員亦可強制結束，已送出開鎖指令之櫃門設為待確認。書櫃回報櫃門開啟後轉為櫃門已開啟；使用者於手機按「完成」或「取消」，或倒數結束時，書櫃回報作業結束，系統才提交交易，並依項目結果轉為已完成、部分完成或已取消，開門後取消不變更交易狀態。開鎖指令未送達書櫃時轉為失敗；已送出開鎖指令卻未收到開門回報、書櫃重新開機或逾時未回報關閉時轉為待確認，待補收關閉回報或由管理員處理後再行提交。管理員遠端開啟櫃門時，作業由數字比對中開始；強制開啟無存放紀錄之空櫃門時，則直接進入開門中。'),
}
ER_FIGS = [
    (ER + 'er_account.png', '使用者帳號與登入模組ER圖',
     '本ER圖呈現使用者帳號與登入模組之關聯結構。以users為核心，一位使用者可擁有多個裝置工作階段（user_sessions）、多筆登入紀錄（login_logs）與多個推播裝置（push_devices）。user_sessions記錄各登入裝置之平台、版本、IP位址與最後使用時間，並以撤銷時間標示已登出之裝置；push_devices則保存各裝置之推播權杖與所屬工作階段。'),
    (ER + 'er_account_auth.png', '通行密鑰與第三方登入模組ER圖',
     '本ER圖呈現通行密鑰與第三方登入模組之關聯結構，users僅列出主鍵以表示與使用者帳號模組之關聯。一位使用者可連結多個外部登入身分（user_identities，包含Google、Apple、LINE、Discord與手機號碼），並可註冊多組通行密鑰（user_passkeys）；webauthn_challenges、oauth_states與oauth_results則暫存通行密鑰驗證及第三方登入過程中之一次性資料。'),
    (ER + 'er_account_settings.png', '帳號安全與偏好設定模組ER圖',
     '本ER圖呈現帳號安全與偏好設定模組之關聯結構，users僅列出主鍵以表示與使用者帳號模組之關聯。每位使用者各有一筆安全設定（user_security），記錄交易密碼、輸入錯誤鎖定與登入權杖失效時間，並有通知偏好設定（user_settings）。管理員另以admin_permissions記錄各項後台管理權限，user_blocks則以封鎖者與被封鎖者為複合主鍵記錄封鎖名單。'),
    (ER + 'er_account_consents.png', '條款同意與QR Code模組ER圖',
     '本ER圖呈現條款同意與QR Code模組之關聯結構，users僅列出主鍵以表示與使用者帳號模組之關聯。legal_documents保存服務條款與隱私權政策等可線上編輯之文件及其版本，並記錄最後修改之管理員；user_legal_consents以使用者與文件代碼為複合主鍵，記錄使用者所同意之版本與時間。user_qr_codes則保存使用者個人檔案所用之QR Code。'),
    (AER + 'er_books.png', '書籍與商品模組ER圖',
     '本ER圖呈現書籍與商品模組之關聯結構。以books為核心，關聯至分類、圖片、收藏、購物車、推薦紀錄與檢舉等資料表；recommendation_logs記錄推薦書籍之曝光來源與點擊，recommendation_dismissals則以使用者與書籍為複合主鍵，記錄使用者標示不感興趣之書籍。AI上架審核與書籍資料補齊之資料表列於AI上架輔助、審核與書目補齊模組ER圖。'),
    (ER + 'er_orders.png', '交易訂單與退款模組ER圖',
     '本ER圖呈現交易訂單與退款模組之關聯結構，smart_cabinets與cabinet_slots僅列出主鍵以表示與智慧書櫃模組之關聯。orders記錄買賣雙方、金額、取貨之書櫃與主要櫃門，以及存書、取書等各階段時間，並關聯訂單明細（order_items）；order_items另以pre_deposited標示下單時已存放於書櫃中之書籍。transaction_disputes記錄使用者對訂單申請之交易爭議與管理員裁決，refund_records記錄退款並可對應至爭議案件。'),
    (CER + 'er_cabinets.png', '智慧書櫃、存書與預約模組ER圖',
     '本ER圖呈現智慧書櫃、存書與預約模組之關聯結構，books與cabinet_sessions僅列出主鍵以表示與其他模組之關聯。smart_cabinets記錄各書櫃據點之位置、櫃門數量、營業時間與維修狀態，並包含多扇櫃門（cabinet_slots），每扇櫃門記錄標籤、對應之電磁鎖通道、狀態、故障代碼、待確認原因與門磁狀態。cabinet_slot_items以書籍為主鍵，記錄每本書實際存放之櫃門與放入時之書櫃作業，為書籍實體位置之依據；book_deposits記錄賣家於訂單成立前先行存放之書籍，包含存入、暫停販售、提醒取回與通知管理員之時間；reservations則記錄聊天室內之書籍預約，包含賣家接受預約後之保留期限。'),
    (CER + 'er_cabinet_devices.png', '書櫃裝置與配對模組ER圖',
     '本ER圖呈現書櫃裝置與配對模組之關聯結構，smart_cabinets僅列出主鍵以表示與智慧書櫃模組之關聯。cabinet_devices記錄各書櫃之控制裝置，包含裝置種類、狀態、櫃門數量、門磁與開鎖通電時間、故障與連線狀態，以及裝置憑證之雜湊值；同一書櫃同時僅有一台有效裝置，一台裝置同時亦僅進行一個書櫃作業。cabinet_pair_requests記錄裝置申請之配對碼，僅保存配對碼與輪詢權杖之雜湊值，管理員輸入配對碼後寫入所綁定之書櫃與裝置；cabinet_challenges則保存書櫃螢幕上QR Code所含一次性挑戰碼之雜湊值、效期與使用紀錄。'),
    (CER + 'er_cabinet_sessions.png', '書櫃作業模組ER圖',
     '本ER圖呈現書櫃作業模組之關聯結構，smart_cabinets、cabinet_devices、users、orders、books與cabinet_slots僅列出主鍵以表示與其他模組之關聯。cabinet_sessions記錄每一次掃碼至櫃門關閉之書櫃作業，包含發起者與作業種類、狀態與版本、定位距離與精度、比對碼、各階段期限與時間、手機送出之完成或取消請求、關門結果，以及管理員之處理紀錄。cabinet_session_items記錄作業中之取書、依訂單存書、先行存書與取回項目及其結果；cabinet_session_doors以作業與櫃門為複合主鍵，記錄每扇櫃門之開鎖指令送出、開啟與關閉時間。'),
    (CER + 'er_cabinet_reports.png', '書櫃手動回報與事件紀錄模組ER圖',
     '本ER圖呈現書櫃手動回報與事件紀錄模組之關聯結構，smart_cabinets、users、orders與books僅列出主鍵以表示與其他模組之關聯。cabinet_manual_reports記錄書櫃未配對裝置、裝置離線或故障期間之存書、取書與取回手動回報，包含回報原因、欲變更之狀態、確認狀態與管理員處理紀錄，並以待確認鍵確保同一項目同時僅有一筆待確認之回報。cabinet_events記錄書櫃裝置回報以及伺服器與管理員操作之事件，裝置事件以冪等鍵避免重複處理；為使交易資料清除後仍保留事件紀錄，其書櫃、裝置、作業、訂單與書籍欄位皆不設外鍵。'),
    (ER + 'er_chat.png', '聊天與社交模組ER圖',
     '本ER圖呈現聊天與社交模組之關聯結構。chat_rooms包含聊天訊息與群組成員，靜音、釘選與暱稱等個人設定各自獨立成表；chat_mentions記錄@提及，chat_transfers記錄站內轉帳與請款。chat_message_risks保存有風險之訊息判定結果，chat_risk_alerts則為管理員之防詐警示佇列。'),
    (ER + 'er_wallet.png', '錢包與會員成長模組ER圖',
     '本ER圖呈現錢包與會員成長模組之關聯結構。wallets與wallet_transactions構成代幣帳本，每筆異動皆記錄交易後餘額，可據以核對任一時點之餘額；member_levels則定義各會員等級之名稱、門檻點數與權益。'),
    (AER + 'er_ai_support.png', 'AI對話、同意與推薦快取模組ER圖',
     '本ER圖呈現AI對話、同意與推薦快取模組之關聯結構。AI書籍顧問與AI客服各有獨立之對話與訊息資料表，避免兩種對話紀錄混雜；助理訊息另保存回覆之處理資訊（不含使用者原文），以及使用者對回覆之評價與原因。ai_message_requests登記App為每則訊息產生之識別碼，重送同一則訊息時回傳第一次之結果，不重複呼叫AI服務；ai_consents記錄使用者之AI使用同意，以及同意時之隱私權政策與同意說明版本；ai_recommendation_cache則保存個人化推薦結果。'),
    (AER + 'er_ai_listing.png', 'AI上架輔助、審核與書目補齊模組ER圖',
     '本ER圖呈現AI上架輔助、審核與書目補齊模組之關聯結構，books僅列出主鍵以表示與書籍與商品模組之關聯。ai_book_reviews與books為一對一關聯，記錄每本書最近一次上架審核之判定、把握度與人工複核結果，AI審核通過或暫時放行時亦留下標記，供排程補審；ai_review_events只新增不修改，記錄每次審核狀態變更之執行者、所依據之判定與是否誤判。ai_book_enrichments與books為一對一關聯，記錄自動補齊之欄位、來源、重試時間與賣家修改過之欄位；ai_isbn_cache以ISBN為主鍵，保存經書名比對與來源驗證之書目、簡介與定價，供不同賣家共用。ai_listing_tokens保存上架輔助折抵權杖之雜湊，使一次上架只計一次每日次數；ai_listing_suggestions保存上架輔助之建議值，用以統計各欄位之採用率。'),
    (AER + 'er_ai_ops.png', 'AI用量、設定與爭議分析模組ER圖',
     '本ER圖呈現AI用量、設定與爭議分析模組之關聯結構，transaction_disputes僅列出主鍵以表示與交易訂單模組之關聯。ai_settings為全域設定；ai_usage_logs記錄每次呼叫之用量、費用、處理結果與提示詞版本，並以請求識別碼串連同一次操作之多次呼叫；ai_decision_logs記錄每次功能處理之路徑與統計，只保存代號與計數；ai_budget_alerts記錄每月AI費用達預算80%與100%之通知，每個門檻每月只通知一次。ai_dispute_analyses保存交易爭議之AI分析結果、實際送出之照片數與管理員評價，並於裁決時記錄建議與裁決是否一致；ai_embeddings則保存語意檢索所需之向量。'),
    (AER + 'er_support_admin.png', '客服、公告與後台模組ER圖',
     '本ER圖呈現客服、公告與後台模組之關聯結構。support_tickets包含往來訊息與附件，並標示是否由AI客服轉接建立；faqs與system_announcements提供常見問題與系統公告，由AI客服轉接之工單建立之常見問題另記錄來源工單；admin_operation_logs記錄後台操作以供查核與還原，db_backups記錄資料庫備份，auth_settings為登入方式之全域設定，notifications則保存站內通知。'),
]
# 原稿 6 張 ER 圖依序對應的新圖檔；其餘各張複製鄰近圖框後插入
ER_ORIG = ['er_account', 'er_books', 'er_orders', 'er_chat', 'er_wallet', 'er_ai_support']
SEQ_FIGS = [
    ('seq_listing', '上架書籍'), ('seq_edit', '編輯書籍'), ('seq_delist', '下架與重新上架書籍'),
    ('seq_checkout', '加入購物車、結帳與直接購買'), ('seq_deposit', '賣家實體書櫃存書'), ('seq_deposit_retrieval', '存書逾期暫停與取回'),
    ('seq_pickup', '買家實體書櫃取書與完成訂單'),
    ('seq_dispute', '訂單爭議與管理員仲裁'), ('seq_auth', '註冊與登入'), ('seq_chat_transfer', '聊天協商、預約與站內轉帳'),
    ('seq_ai_support', 'AI客服對話與轉真人客服'), ('seq_admin_review', '管理員內容審核'), ('seq_support_ticket', '客服工單'),
    ('seq_passkey', '通行密鑰新增與登入'), ('seq_verification', '敏感操作身分驗證'), ('seq_session', '登入裝置管理'),
    ('seq_account_deletion', '資料匯出與帳號刪除'), ('seq_legal_consent', '服務條款與隱私權政策同意'),
    ('seq_chat_group', '群組聊天建立、管理與@提及'), ('seq_notification_push', '站內通知與推播'),
    ('seq_admin_audit_undo', '後台操作紀錄與復原'), ('seq_backup_restore', '資料庫備份與還原'), ('seq_recommend', '個人化推薦'),
    ('seq_isbn_share', 'ISBN查詢與分享連結'), ('seq_degradation', '系統限流與維護模式'), ('seq_oauth_link', 'LINE／Discord登入與帳號連結'),
    ('seq_chat_risk', '聊天防詐檢查'), ('seq_realtime', '聊天即時推送'),
    ('seq_cabinet_manual_report', '書櫃故障備援手動回報'), ('seq_cabinet_pairing', '書櫃裝置配對'),
    ('seq_cabinet_admin_open', '管理員遠端開啟櫃門'),
]
for i, (name, title) in enumerate(SEQ_FIGS, start=1):
    FIGS[f'6-1-{i}'] = ((CSQ if name in CAB_SEQ else SQ) + name + '.png', title + '之循序圖', SEQ[name])


def caption(doc, num):
    hits = [p for p in doc.paragraphs if p.style.name == 'Caption' and p.text.strip().startswith(f'圖 {num} ')]
    return hits[0]._p if hits else None


def fill(doc, cap, num, png, title, text, max_w, max_h):
    img = cap.getprevious(); desc = img.getprevious()
    assert img.find('.//' + qn('a:blip')) is not None, num
    replace_image(doc, img, png, max_w, max_h)
    set_para(cap, f'圖 {num} {title}')
    set_para(desc, text)


def clone_block(doc, ref_cap, png, max_w, max_h):
    img = ref_cap.getprevious(); desc = img.getprevious()
    return copy.deepcopy(desc), new_picture_para(doc, img, png, max_w, max_h), copy.deepcopy(ref_cap)


def run(doc):
    sec = doc.sections[-1]
    max_w = sec.page_width - sec.left_margin - sec.right_margin
    max_h = min(Cm(23), int(sec.page_height - sec.top_margin - sec.bottom_margin) - Cm(3))

    # 原稿沒有的圖號（循序圖 6-1-26 起、狀態機 7-4-6）：複製同節前一張圖框接在其後，圖檔與說明由下方依 FIGS 填入
    for num in sorted(FIGS, key=lambda n: tuple(map(int, n.split('-')))):
        if caption(doc, num) is not None: continue
        head, _, last = num.rpartition('-')
        anchor = caption(doc, f'{head}-{int(last) - 1}')
        d, i, c = clone_block(doc, anchor, FIGS[num][0], max_w, max_h)
        anchor.addnext(d); d.addnext(i); i.addnext(c)
        set_para(c, f'圖 {num} x')

    # ER 圖由 6 張改為 16 張：原稿各圖依 ER_ORIG 沿用，新增的圖框接在前一張之後
    old = dict(zip(ER_ORIG, (caption(doc, f'8-1-{n}') for n in range(1, len(ER_ORIG) + 1))))
    er_caps, anchor = [], None
    for png, _, _ in ER_FIGS:
        key = png.rsplit('/', 1)[1][:-4]
        if key in old:
            anchor = old[key]
        else:
            d, i, c = clone_block(doc, anchor, png, max_w, max_h)
            anchor.addnext(d); d.addnext(i); i.addnext(c)
            anchor = c
        er_caps.append(anchor)
    for n, (cap, (png, title, text)) in enumerate(zip(er_caps, ER_FIGS), start=1):
        fill(doc, cap, f'8-1-{n}', png, title, text, max_w, max_h)

    for num, (png, title, text) in FIGS.items():
        cap = caption(doc, num)
        assert cap is not None, num
        fill(doc, cap, num, png, title, text, max_w, max_h)
    clamp_figures(doc, max_w, max_h)
    return len(FIGS) + len(ER_FIGS)


def clamp_figures(doc, max_w, max_h):
    """沿用原稿的圖（如甘特圖）也等比縮至版面內。"""
    for p in doc.paragraphs:
        if not p.text.strip().startswith('圖 '): continue
        img = p._p.getprevious()
        if img is None or img.find('.//' + qn('a:blip')) is None: continue
        ext = img.find('.//' + qn('wp:extent'))
        cx, cy = int(ext.get('cx')), int(ext.get('cy'))
        scale = min(1, max_w / cx, max_h / cy)
        if scale >= 1: continue
        nx, ny = int(cx * scale), int(cy * scale)
        for e in img.iter(qn('wp:extent')):
            e.set('cx', str(nx)); e.set('cy', str(ny))
        for e in img.iter(qn('a:ext')):
            if e.get('cx') is not None:
                e.set('cx', str(nx)); e.set('cy', str(ny))
