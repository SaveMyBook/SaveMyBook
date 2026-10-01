import re
p = 'update_part1.py'
s = open(p, encoding='utf-8').read()

def rep(old, new, count=1):
    global s
    assert s.count(old) == count, (old[:80], s.count(old))
    s = s.replace(old, new)

# 1. 路徑
rep("""UC, SQ, ST, ER = D + 'Use Case/v3/', D + 'Sequence Diagrams/v3/', D + 'State Machine/v3/', D + 'Relational Tables/v3/'
""", """UC, SQ, ST, ER = D + 'Use Case/v3/', D + 'Sequence Diagrams/v3/', D + 'State Machine/v3/', D + 'Relational Tables/v3/'
# 智慧書櫃（掃碼存取）相關之圖：原始碼與圖檔置於 scratchpad/cabdiag
CAB = __import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)), 'cabdiag') + '/'
CUC, CSQ, CST, CER, CAR = CAB + 'uc/', CAB + 'seq/', CAB + 'state/', CAB + 'er/', CAB + 'arch/'
CAB_SEQ = {'seq_deposit', 'seq_deposit_retrieval', 'seq_pickup',
           'seq_cabinet_manual_report', 'seq_cabinet_pairing', 'seq_cabinet_admin_open'}
""")

# 2. 5-2-3
s = re.sub(r"    '5-2-3': \(UC \+ 'uc_orders.png', '交易與訂單模組之使用個案圖',\n              '[^']*'\),",
           lambda m: """    '5-2-3': (CUC + 'uc_orders.png', '交易與訂單模組之使用個案圖',
              '本圖描繪交易與訂單模組之使用個案，參與者為買家、賣家與管理員。買家可將書籍加入購物車後結帳，或於書籍頁直接購買，兩者皆須通過付款驗證；買家至訂單指定之書櫃掃描QR Code取書，確認書況後完成訂單。賣家可掃描書櫃QR Code依訂單存書，亦可於書籍上架後先行存書，並可掃描書櫃取回書籍。掃描書櫃取書、存書與取回時，皆須於手機輸入書櫃螢幕上顯示之兩位數比對數字才會開啟櫃門；書櫃未配對裝置或裝置離線、故障時，可改為手動回報，由管理員確認後生效。雙方可於存書前取消訂單，交易發生問題時可提出申訴，由管理員仲裁。'),""", s, count=1)
assert "CUC + 'uc_orders.png'" in s
# 3. 5-2-6
s = re.sub(r"    '5-2-6': \(UC \+ 'uc_admin.png', '後台管理模組之使用個案圖',\n              '[^']*'\),",
           lambda m: """    '5-2-6': (CUC + 'uc_admin.png', '後台管理模組之使用個案圖',
              '本圖彙整後台管理模組之使用個案，參與者為管理員與AI服務。管理員可查看營運總覽，管理會員與等級、書籍與分類、訂單、公告與文件，並處理客服工單與查看操作紀錄與復原。內容審核包含上架審核、處理檢舉與處理防詐警示；仲裁申訴時可使用AI分析作為參考；管理智慧書櫃包含配對書櫃裝置、遠端開啟櫃門、處理待確認作業與櫃門、確認手動回報與登記取出存書；系統設定則包含AI功能、登入方式與資料庫備份還原。各項功能依管理員權限開放。'),""", s, count=1)
assert "CUC + 'uc_admin.png'" in s
# 4. 7-1-1 / 7-2-1 / 7-3-1
s = re.sub(r"    '7-1-1': \(D \+ 'System Architecture/v3/deployment.png', '佈署圖',\n              '[^']*'\),",
           lambda m: """    '7-1-1': (CAR + 'deployment.png', '佈署圖',
              '本圖呈現系統之實體部署環境。行動裝置App與智慧書櫃終端經Cloudflare邊緣節點連線至學校伺服器；每台智慧書櫃由一片ESP32控制顯示螢幕與4組電磁鎖（對應4扇櫃門），並以HTTPS定時輪詢伺服器，取得螢幕顯示內容與開鎖指令。伺服器以sslh多工器將HTTP流量轉交NGINX、SSH流量轉交OpenSSH；NGINX再將API請求與即時推送連線轉發至Express API服務，由其讀寫MariaDB資料庫。登入驗證、推播、AI服務與書目資料則由外部雲端服務提供。'),""", s, count=1)
assert "CAR + 'deployment.png'" in s
s = re.sub(r"    '7-2-1': \(D \+ 'Package Diagram/v3/package.png', '套件圖',\n              '[^']*'\),",
           lambda m: """    '7-2-1': (CAR + 'package.png', '套件圖',
              '本圖以分層方式呈現系統之套件劃分。展示層（Flutter）由共用元件、主題與語系設定及各功能畫面組成；應用層包含API服務、即時推送服務與推播服務，分別以REST API與Socket.IO連線至後端。後端之API層除Express應用程式與即時推送伺服器外，另提供裝置API（Device API）供智慧書櫃終端連線；請求經中介層進行身分驗證、敏感操作驗證與限流後，交由服務層之各項業務服務處理，其中書櫃服務（Cabinet Service）負責書櫃作業、裝置配對與櫃門管理，最後透過Prisma ORM存取MariaDB資料庫。'),""", s, count=1)
assert "CAR + 'package.png'" in s
s = re.sub(r"    '7-3-1': \(D \+ 'Component diagram/v3/component.png', '元件圖',\n              '[^']*'\),",
           lambda m: """    '7-3-1': (CAR + 'component.png', '元件圖',
              '本圖以元件觀點呈現系統主要功能單元之提供與使用關係。訂單元件使用書籍、錢包、使用者與通知元件所提供之介面，並提供報表元件所需資料；書櫃元件使用訂單、書籍與通知元件所提供之介面，於櫃門關閉後提交存書、取書與取回之結果；聊天元件使用使用者與通知元件；AI元件同時提供書籍與聊天元件使用。App與智慧書櫃終端（ESP32）皆經API元件存取後端，API元件則使用書櫃元件所提供之書櫃作業介面。'),""", s, count=1)
assert "CAR + 'component.png'" in s
# 5. 7-4-1 / 7-4-2
rep("    '7-4-1': (ST + 'state_books.png',", "    '7-4-1': (CST + 'state_books.png',")
rep("賣家回報取回後回到販售中，管理員登記取出後則轉為已下架。", "賣家至書櫃掃碼取回後回到販售中，管理員登記取出後則轉為已下架。")
s = re.sub(r"    '7-4-2': \(ST \+ 'state_orders.png', '訂單之狀態機',\n              '[^']*'\),",
           lambda m: """    '7-4-2': (CST + 'state_orders.png', '訂單之狀態機',
              '本狀態機描繪訂單之生命週期。買家付款時，若訂單內之書籍皆已存放於書櫃，訂單直接成為已存書，買家可立即取書；否則訂單為待存書，賣家掃描書櫃存書且櫃門關閉後轉為已存書。買家掃描書櫃取書且櫃門關閉後轉為待確認完成，買家完成訂單或取書滿24小時後轉為已完成並撥款給賣家；書櫃故障期間之手動回報，須經管理員確認後才轉換狀態。存書前可取消訂單，賣家逾期七天未存書或買家逾期七天未取書時系統自動取消並退款，惟書櫃紀錄顯示開門後未完成取書或櫃門異常時，改由管理員人工處理；交易有問題時可提出申訴，管理員判定退款則轉為已退款，駁回時已取書之訂單直接完成。'),""", s, count=1)
assert "CST + 'state_orders.png'" in s
# 6. 7-4-6（新增）
rep("""              '本狀態機描繪客服工單之生命週期。""", """              '本狀態機描繪客服工單之生命週期。""")
i = s.index("    '7-4-5': (ST + 'state_support_ticket.png'")
j = s.index("\n}\n", i)
s = s[:j] + """
    '7-4-6': (CST + 'state_cabinet_sessions.png', '書櫃作業之狀態機',
              '本狀態機描繪書櫃作業（使用者掃描書櫃QR Code至櫃門關閉之一次過程）之生命週期。使用者掃碼後作業為確認項目中，於手機確認項目並按「開啟櫃門」後，系統分配櫃門並產生兩位數比對碼，轉為數字比對中；使用者須於60秒內在手機輸入書櫃螢幕上之數字，且僅有一次機會，相符即轉為開門中，不符轉為失敗，逾時則轉為已逾時，開門前亦可於手機取消。書櫃回報櫃門開啟後轉為櫃門已開啟；使用者於手機按「完成」或「取消」，或倒數結束時，書櫃回報作業結束，系統才提交交易，並依項目結果轉為已完成、部分完成或已取消，開門後取消不變更交易狀態。開鎖指令未送達書櫃時轉為失敗；已送出開鎖指令卻未收到開門回報、書櫃重新開機或逾時未回報關閉時轉為待確認，待補收關閉回報或由管理員處理後再行提交。管理員遠端開啟櫃門時，作業由數字比對中開始；強制開啟無存放紀錄之空櫃門時，則直接進入開門中。'),""" + s[j:]

# 7. ER_FIGS：er_cabinets 改寫，其後新增三張
s = re.sub(r"    \(ER \+ 'er_cabinets.png', '智慧書櫃、存書與預約模組ER圖',\n     '[^']*'\),",
           lambda m: """    (CER + 'er_cabinets.png', '智慧書櫃、存書與預約模組ER圖',
     '本ER圖呈現智慧書櫃、存書與預約模組之關聯結構，books與cabinet_sessions僅列出主鍵以表示與其他模組之關聯。smart_cabinets記錄各書櫃據點之位置、櫃門數量、營業時間與維修狀態，並包含多扇櫃門（cabinet_slots），每扇櫃門記錄標籤、對應之電磁鎖通道、狀態、故障代碼、待確認原因與門磁狀態。cabinet_slot_items以書籍為主鍵，記錄每本書實際存放之櫃門與放入時之書櫃作業，為書籍實體位置之依據；book_deposits記錄賣家於訂單成立前先行存放之書籍，包含存入、暫停販售、提醒取回與通知管理員之時間；reservations則記錄聊天室內之書籍預約，包含可指定之取書書櫃與取書期限。'),
    (CER + 'er_cabinet_devices.png', '書櫃裝置與配對模組ER圖',
     '本ER圖呈現書櫃裝置與配對模組之關聯結構，smart_cabinets僅列出主鍵以表示與智慧書櫃模組之關聯。cabinet_devices記錄各書櫃之控制裝置，包含裝置種類、狀態、櫃門數量、門磁與開鎖通電時間、故障與連線狀態，以及裝置憑證之雜湊值；同一書櫃同時僅有一台有效裝置，一台裝置同時亦僅進行一個書櫃作業。cabinet_pair_requests記錄裝置申請之配對碼，僅保存配對碼與輪詢權杖之雜湊值，管理員輸入配對碼後寫入所綁定之書櫃與裝置；cabinet_challenges則保存書櫃螢幕上QR Code所含一次性挑戰碼之雜湊值、效期與使用紀錄。'),
    (CER + 'er_cabinet_sessions.png', '書櫃作業模組ER圖',
     '本ER圖呈現書櫃作業模組之關聯結構，smart_cabinets、cabinet_devices、users、orders、books與cabinet_slots僅列出主鍵以表示與其他模組之關聯。cabinet_sessions記錄每一次掃碼至櫃門關閉之書櫃作業，包含發起者與作業種類、狀態與版本、定位距離與精度、比對碼、各階段期限與時間、手機送出之完成或取消請求、關門結果，以及管理員之處理紀錄。cabinet_session_items記錄作業中之取書、依訂單存書、先行存書與取回項目及其結果；cabinet_session_doors以作業與櫃門為複合主鍵，記錄每扇櫃門之開鎖指令送出、開啟與關閉時間。'),
    (CER + 'er_cabinet_reports.png', '書櫃手動回報與事件紀錄模組ER圖',
     '本ER圖呈現書櫃手動回報與事件紀錄模組之關聯結構，smart_cabinets、users、orders與books僅列出主鍵以表示與其他模組之關聯。cabinet_manual_reports記錄書櫃未配對裝置、裝置離線或故障期間之存書、取書與取回手動回報，包含回報原因、欲變更之狀態、確認狀態與管理員處理紀錄，並以待確認鍵確保同一項目同時僅有一筆待確認之回報。cabinet_events記錄書櫃裝置回報以及伺服器與管理員操作之事件，裝置事件以冪等鍵避免重複處理；為使交易資料清除後仍保留事件紀錄，其書櫃、裝置、作業、訂單與書籍欄位皆不設外鍵。'),""", s, count=1)
assert "CER + 'er_cabinet_reports.png'" in s

# 8. SEQ_FIGS：新增三張（接在最後，對應 UC-32～UC-34），書櫃相關圖改用 cabdiag
rep("""    ('seq_chat_risk', '聊天防詐檢查'), ('seq_realtime', '聊天即時推送'),
]""", """    ('seq_chat_risk', '聊天防詐檢查'), ('seq_realtime', '聊天即時推送'),
    ('seq_cabinet_manual_report', '書櫃故障備援之手動回報'), ('seq_cabinet_pairing', '書櫃裝置配對'),
    ('seq_cabinet_admin_open', '管理員遠端開啟櫃門'),
]""")
rep("""    FIGS[f'6-1-{i}'] = (SQ + name + '.png', title + '之循序圖', SEQ[name])""",
    """    FIGS[f'6-1-{i}'] = ((CSQ if name in CAB_SEQ else SQ) + name + '.png', title + '之循序圖', SEQ[name])""")

# 9. run()：原稿沒有的圖號（循序圖 6-1-26 起、狀態機 7-4-6）一律複製同節前一張圖框接在其後
rep("""    # 循序圖由 25 張增為 28 張：新增的圖框接在 6-1-25 之後，圖號、圖檔與說明由下方依 SEQ_FIGS 順序重新填入
    anchor = caption(doc, '6-1-25')
    for num in ('6-1-26', '6-1-27', '6-1-28'):
        png = FIGS[num][0]
        d, i, c = clone_block(doc, anchor, png, max_w, max_h)
        anchor.addnext(d); d.addnext(i); i.addnext(c)
        set_para(c, f'圖 {num} x')
        anchor = c
""", """    # 原稿沒有的圖號（循序圖 6-1-26 起、狀態機 7-4-6）：複製同節前一張圖框接在其後，圖檔與說明由下方依 FIGS 填入
    for num in sorted(FIGS, key=lambda n: tuple(map(int, n.split('-')))):
        if caption(doc, num) is not None: continue
        head, _, last = num.rpartition('-')
        anchor = caption(doc, f'{head}-{int(last) - 1}')
        d, i, c = clone_block(doc, anchor, FIGS[num][0], max_w, max_h)
        anchor.addnext(d); d.addnext(i); i.addnext(c)
        set_para(c, f'圖 {num} x')
""")
open(p, 'w', encoding='utf-8').write(s)
print('patched')
