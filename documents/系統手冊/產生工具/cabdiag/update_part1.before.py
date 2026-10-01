import copy
from docx.shared import Cm
from doctools import *
from seqdesc import SEQ

D = '/Users/xukaijun/Desktop/SaveMyBook/Diagrams/'
UC, SQ, ST, ER = D + 'Use Case/v3/', D + 'Sequence Diagrams/v3/', D + 'State Machine/v3/', D + 'Relational Tables/v3/'

# 既有圖：圖號 → (新圖檔, 新圖名, 說明)
FIGS = {
    '5-2-1': (UC + 'uc_account.png', '帳號與安全模組之使用個案圖',
              '本圖描繪帳號與安全模組之使用個案，參與者為訪客、會員與第三方登入服務。訪客可註冊帳號或登入，登入方式包含密碼登入、第三方登入（Google、Apple、LINE、Discord）與通行密鑰登入，登入時一律須同意最新版之服務條款與隱私權政策。會員登入後可管理個人資料、登入方式、交易密碼與生物辨識、登入裝置，並可匯出資料或申請刪除帳號；其中變更登入方式、交易密碼與刪除帳號皆須先通過身分驗證。'),
    '5-2-2': (UC + 'uc_books.png', '書籍與商品管理模組之使用個案圖',
              '本圖描繪書籍與商品管理模組之使用個案，參與者為賣家、買家與AI服務。賣家管理書籍時可上架、編輯、下架或重新上架；上架時可選用ISBN條碼掃描與AI輔助帶入書籍資訊，並一律經過上架審核，系統另依ISBN自動補齊空白之書籍資料。買家可瀏覽與搜尋書籍、查看書籍詳情與相似的書、查看個人化推薦、收藏書籍，並可檢舉違規商品。'),
    '5-2-3': (UC + 'uc_orders.png', '交易與訂單模組之使用個案圖',
              '本圖描繪交易與訂單模組之使用個案，參與者為買家、賣家與管理員。買家可將書籍加入購物車後結帳，或於書籍頁直接購買，兩者皆須通過付款驗證；買家取書時須掃描書櫃QR Code，確認書況後完成訂單。賣家可依訂單存書，亦可於書籍上架後先行存書；書籍逾期未售出時，賣家取回書籍後須回報取回。雙方可於存書前取消訂單，交易發生問題時可提出申訴，由管理員仲裁；管理員另負責登記人員自書櫃取出之書籍。'),
    '5-2-4': (UC + 'uc_chat.png', '聊天與社交模組之使用個案圖',
              '本圖描繪聊天與社交模組之使用個案，參與者為會員與管理員。會員可傳送訊息、建立與管理群組、預約保留書籍、站內轉帳或請款，並可設定暱稱、靜音、置頂或封鎖檢舉其他使用者，亦可使用AI問書；轉帳與請款皆須通過付款驗證。傳送聯絡方式或付款資訊前系統請傳送者確認，群組內可@提及成員；收訊方可查看防詐提醒並檢舉可疑訊息，高風險情形則由管理員處理防詐警示。'),
    '5-2-5': (UC + 'uc_wallet_support.png', '錢包、會員成長與客服模組之使用個案圖',
              '本圖描繪錢包、會員成長與客服模組之使用個案，參與者為會員與管理員。會員可管理代幣，查看交易紀錄與待撥款項，並查看會員等級與成就；遇到問題時可查看常見問題、使用AI客服，必要時轉真人客服，或直接建立客服工單並往來回覆。管理員負責調整會員錢包與處理客服工單。'),
    '5-2-6': (UC + 'uc_admin.png', '後台管理模組之使用個案圖',
              '本圖彙整後台管理模組之使用個案，參與者為管理員與AI服務。管理員可查看營運總覽，管理會員與等級、書籍與分類、訂單、智慧書櫃、公告與文件，並處理客服工單與查看操作紀錄與復原。內容審核包含上架審核、處理檢舉與處理防詐警示；仲裁申訴時可使用AI分析作為參考；系統設定則包含AI功能、登入方式與資料庫備份還原。各項功能依管理員權限開放。'),
    '5-4-1': (D + 'Analysis Class Diagram/v3/analysis_class.png', '分析類別圖',
              '本圖呈現系統於需求分析階段之主要領域類別與其關聯。使用者可擁有會員錢包、購物車、上架之書籍、訂單、聊天室與推播通知；訂單包含所購買之書籍，指定取貨之智慧書櫃據點，並於結算時撥款至錢包，發生爭議時可產生交易申訴。智慧書櫃據點由多個書櫃格位組成；預約管理保留特定書籍；聊天室包含多則聊天訊息，有風險之訊息另有對應之訊息風險紀錄。'),
    '6-2-1': (D + 'Class diagram/v3/design_class.png', '設計類別圖',
              '本圖延續分析類別圖之劃分，為各類別補上資料型態、多重性與主要操作。訂單為交易核心，提供建立訂單、直接購買、確認存書、確認取書、完成與取消等操作，並於完成時結算至會員錢包；書籍商品提供上架、編輯、下架與資料補齊；交易申訴提供提出、AI分析與仲裁；聊天訊息提供傳送、收回與已讀，並由訊息風險紀錄進行防詐評估；推播通知則負責派送與已讀管理。'),
    '7-1-1': (D + 'System Architecture/v3/deployment.png', '佈署圖',
              '本圖呈現系統之實體部署環境。行動裝置App與智慧書櫃終端經Cloudflare邊緣節點連線至學校伺服器，伺服器以sslh多工器將HTTP流量轉交NGINX、SSH流量轉交OpenSSH；NGINX再將API請求與即時推送連線轉發至Express API服務，由其讀寫MariaDB資料庫。登入驗證、推播、AI服務與書目資料則由外部雲端服務提供。'),
    '7-2-1': (D + 'Package Diagram/v3/package.png', '套件圖',
              '本圖以分層方式呈現系統之套件劃分。展示層（Flutter）由共用元件、主題與語系設定及各功能畫面組成；應用層包含API服務、即時推送服務與推播服務，分別以REST API與Socket.IO連線至後端。後端之API層接收請求後，經中介層進行身分驗證、敏感操作驗證與限流，再交由服務層之各項業務服務處理，最後透過Prisma ORM存取MariaDB資料庫。'),
    '7-3-1': (D + 'Component diagram/v3/component.png', '元件圖',
              '本圖以元件觀點呈現系統主要功能單元之提供與使用關係。訂單元件使用書籍、錢包、使用者與通知元件所提供之介面，並提供報表元件所需資料；聊天元件使用使用者與通知元件；AI元件同時提供書籍與聊天元件使用。App經API元件存取後端，API元件亦提供智慧書櫃終端（ESP32）連線之介面。'),
    '7-4-1': (ST + 'state_books.png', '書籍商品之狀態機',
              '本狀態機描繪書籍商品之生命週期。賣家上架後書籍為販售中，售價異常、疑似非正規來源或AI審核需人工確認時轉為審核中，由管理員核准或駁回。販售中之書籍可被預約保留或由買家下單而進入交易中，訂單完成後轉為已售出；存書前取消訂單時回到販售中，逾期未存書或未取書則轉為已下架。書籍存放於書櫃滿七天仍無訂單時轉為暫停販售（待取回），賣家回報取回後回到販售中，管理員登記取出後則轉為已下架。賣家可自行下架與重新上架，違規下架者須經管理員處理。'),
    '7-4-2': (ST + 'state_orders.png', '訂單之狀態機',
              '本狀態機描繪訂單之生命週期。買家付款時，若訂單內之書籍皆已存放於書櫃，訂單直接成為已存書，買家可立即取書；否則訂單為待存書，賣家存書後轉為已存書。買家取書後轉為待確認完成，買家完成訂單或取書滿24小時後轉為已完成並撥款給賣家。存書前可取消訂單，賣家逾期七天未存書或買家逾期七天未取書時系統自動取消並退款；交易有問題時可提出申訴，管理員判定退款則轉為已退款，駁回時已取書之訂單直接完成。'),
    '7-4-3': (ST + 'state_disputes.png', '交易申訴之狀態機',
              '本狀態機描繪交易申訴之生命週期。買家或賣家提出申訴後案件為待處理，管理員裁決後轉為已結案，結案結果分為退款、駁回與調解三種；已結案之案件不可再變更。'),
    '7-4-4': (ST + 'state_reservation.png', '書籍預約之狀態機',
              '本狀態機描繪聊天室內書籍預約之生命週期。買家發起預約後為待回應，賣家接受即轉為保留中，保留期間其他買家無法購買該書；賣家婉拒或任一方取消時轉為已取消，24小時未回應或保留時間到期時轉為已逾期，並通知收藏此書之使用者。'),
    '7-4-5': (ST + 'state_support_ticket.png', '客服工單之狀態機',
              '本狀態機描繪客服工單之生命週期。使用者建立工單後為待處理，客服回覆後轉為等待使用者回覆，使用者再回覆則回到待處理。客服可將工單標示為已解決，使用者若再次回覆則重新開啟；任一方結案後工單轉為已結案，不可再回覆，如有新問題須另開工單。'),
}
ER_FIGS = [
    (ER + 'er_account.png', '使用者帳號與登入模組ER圖',
     '本ER圖呈現使用者帳號與登入模組之關聯結構。以users為核心，一位使用者可擁有多個裝置工作階段（user_sessions）、多筆登入紀錄（login_logs）與多個推播裝置（push_devices）。user_sessions記錄各登入裝置之平台、版本、IP位址與最後使用時間，並以撤銷時間標示已登出之裝置；push_devices則保存各裝置之推播權杖與所屬工作階段。'),
    (ER + 'er_account_auth.png', '通行密鑰與第三方登入模組ER圖',
     '本ER圖呈現通行密鑰與第三方登入模組之關聯結構，users僅列出主鍵以表示與使用者帳號模組之關聯。一位使用者可連結多個外部登入身分（user_identities，包含Google、Apple、LINE、Discord與手機號碼），並可註冊多組通行密鑰（user_passkeys）；webauthn_challenges、oauth_states與oauth_results則暫存通行密鑰驗證及第三方登入過程中之一次性資料。'),
    (ER + 'er_account_settings.png', '帳號安全與偏好設定模組ER圖',
     '本ER圖呈現帳號安全與偏好設定模組之關聯結構，users僅列出主鍵以表示與使用者帳號模組之關聯。每位使用者各有一筆安全設定（user_security），記錄支付密碼、輸入錯誤鎖定與登入權杖失效時間，並有通知、主題與隱私等偏好設定（user_settings）。管理員另以admin_permissions記錄各項後台管理權限，user_blocks則以封鎖者與被封鎖者為複合主鍵記錄封鎖名單。'),
    (ER + 'er_account_consents.png', '條款同意、存摺與QR Code模組ER圖',
     '本ER圖呈現條款同意、存摺與QR Code模組之關聯結構，users僅列出主鍵以表示與使用者帳號模組之關聯。legal_documents保存服務條款與隱私權政策等可線上編輯之文件及其版本，並記錄最後修改之管理員；user_legal_consents以使用者與文件代碼為複合主鍵，記錄使用者所同意之版本與時間。bankbooks記錄使用者之存摺資料與驗證狀態，user_qr_codes則保存個人檔案與推薦好友所用之QR Code。'),
    (ER + 'er_books.png', '書籍與商品模組ER圖',
     '本ER圖呈現書籍與商品模組之關聯結構。以books為核心，關聯至分類、圖片、收藏、購物車、推薦紀錄、檢舉與人工審核等資料表；ai_book_reviews與ai_book_enrichments皆與books為一對一關聯，分別記錄AI上架審核結果與自動補齊之欄位。'),
    (ER + 'er_orders.png', '交易訂單與退款模組ER圖',
     '本ER圖呈現交易訂單與退款模組之關聯結構，smart_cabinets與cabinet_slots僅列出主鍵以表示與智慧書櫃模組之關聯。orders記錄買賣雙方、金額、取貨之書櫃與格位、取書碼及各階段時間，並關聯訂單明細（order_items）；order_items另以pre_deposited標示下單時已存放於書櫃中之書籍。transaction_disputes記錄使用者對訂單提出之申訴與管理員裁決，refund_records記錄退款並可對應至申訴案件。'),
    (ER + 'er_cabinets.png', '智慧書櫃、存書與預約模組ER圖',
     '本ER圖呈現智慧書櫃、存書與預約模組之關聯結構。smart_cabinets記錄各書櫃據點之位置、格位數量、營運時間與維護狀態，並包含多個格位（cabinet_slots），每一格位記錄目前存放之書籍與所屬訂單。book_deposits記錄賣家於訂單成立前先行存放於書櫃之書籍，包含存入時間，以及暫停販售、提醒取回與通知管理員之時間；reservations則記錄聊天室內之書籍預約，包含可指定之取書書櫃、取書期限與取書QR Code。'),
    (ER + 'er_chat.png', '聊天與社交模組ER圖',
     '本ER圖呈現聊天與社交模組之關聯結構。chat_rooms包含聊天訊息與群組成員，靜音、置頂與暱稱等個人設定各自獨立成表；chat_mentions記錄@提及，chat_transfers記錄站內轉帳與請款。chat_message_risks保存有風險之訊息判定結果，chat_risk_alerts則為管理員之防詐警示佇列。'),
    (ER + 'er_wallet.png', '錢包與會員成長模組ER圖',
     '本ER圖呈現錢包與會員成長模組之關聯結構。wallets與wallet_transactions構成代幣帳本，每筆異動皆記錄交易後餘額，可據以核對任一時點之餘額；member_levels、achievements與user_achievements構成會員等級與成就機制，referral_records記錄推薦好友之獎勵。'),
    (ER + 'er_ai_support.png', 'AI服務模組ER圖',
     '本ER圖呈現AI服務模組之關聯結構。AI問書與AI客服各有獨立之對話與訊息資料表，避免兩種對話紀錄混雜；ai_consents記錄使用者之AI使用同意，ai_recommendation_cache保存個人化推薦結果，ai_settings為全域設定，ai_usage_logs記錄每次呼叫之用量與費用，ai_embeddings則保存語意檢索所需之向量。'),
    (ER + 'er_support_admin.png', '客服、公告與後台模組ER圖',
     '本ER圖呈現客服、公告與後台模組之關聯結構。support_tickets包含往來訊息與附件，faqs與system_announcements提供常見問題與系統公告；admin_operation_logs記錄後台操作以供查核與復原，db_backups記錄資料庫備份，auth_settings為登入方式之全域設定，notifications則保存站內通知。'),
]
# 原稿 6 張 ER 圖依序對應的新圖檔；其餘各張複製鄰近圖框後插入
ER_ORIG = ['er_account', 'er_books', 'er_orders', 'er_chat', 'er_wallet', 'er_ai_support']
SEQ_FIGS = [
    ('seq_listing', '上架書籍'), ('seq_edit', '編輯書籍'), ('seq_delist', '下架與重新上架書籍'),
    ('seq_checkout', '加入購物車、結帳與直接購買'), ('seq_deposit', '賣家實體書櫃存書'), ('seq_deposit_retrieval', '存書逾期暫停與取回'),
    ('seq_pickup', '買家實體書櫃取書與完成訂單'),
    ('seq_dispute', '訂單申訴與管理員仲裁'), ('seq_auth', '註冊與登入'), ('seq_chat_transfer', '聊天協商、預約與站內轉帳'),
    ('seq_ai_support', 'AI客服對話與轉真人客服'), ('seq_admin_review', '管理員內容審核'), ('seq_support_ticket', '客服工單'),
    ('seq_passkey', '通行密鑰新增與登入'), ('seq_verification', '敏感操作身分驗證'), ('seq_session', '登入裝置管理'),
    ('seq_account_deletion', '資料匯出與帳號刪除'), ('seq_legal_consent', '服務條款與隱私權政策同意'),
    ('seq_chat_group', '群組聊天建立、管理與@提及'), ('seq_notification_push', '站內通知與推播'),
    ('seq_admin_audit_undo', '後台操作紀錄與復原'), ('seq_backup_restore', '資料庫備份與還原'), ('seq_recommend', '個人化推薦'),
    ('seq_isbn_share', 'ISBN查詢與分享連結'), ('seq_degradation', '系統限流與維護模式'), ('seq_oauth_link', 'LINE／Discord登入與帳號連結'),
    ('seq_chat_risk', '聊天防詐檢查'), ('seq_realtime', '聊天即時推送'),
]
for i, (name, title) in enumerate(SEQ_FIGS, start=1):
    FIGS[f'6-1-{i}'] = (SQ + name + '.png', title + '之循序圖', SEQ[name])


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

    # 循序圖由 25 張增為 28 張：新增的圖框接在 6-1-25 之後，圖號、圖檔與說明由下方依 SEQ_FIGS 順序重新填入
    anchor = caption(doc, '6-1-25')
    for num in ('6-1-26', '6-1-27', '6-1-28'):
        png = FIGS[num][0]
        d, i, c = clone_block(doc, anchor, png, max_w, max_h)
        anchor.addnext(d); d.addnext(i); i.addnext(c)
        set_para(c, f'圖 {num} x')
        anchor = c

    # ER 圖由 6 張改為 11 張：原稿各圖依 ER_ORIG 沿用，新增的圖框接在前一張之後
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
