"""智慧書櫃（掃碼存取、書櫃螢幕純顯示）之手冊內文與表格：系統規格、元件、限流、錯誤代碼、路由、測試、操作與使用手冊。

由 update_part4.run() 在 9-2 各表重新編號之前呼叫，因此 9-2 各表沿用原稿編號（權限鍵 9-2-7、路由 9-2-8）。
"""
import copy
from doctools import *


def _row(tbl, prefix, col=0):
    for tr in tbl.findall(W('tr')):
        c = tcs(tr)
        if len(c) > col and text_of(c[col]).strip().startswith(prefix): return tr
    raise KeyError(prefix)


def _set(tr, values):
    for tc, v in zip(tcs(tr), values):
        if v is not None: set_cell(tc, v)


def _after(tr, values):
    new = clone_row_after(tr)
    _set(new, values)
    return new


def _append(tbl, values):
    return _after(tbl.findall(W('tr'))[-1], values)


def _para(doc, prefix):
    for p in doc.paragraphs:
        if p.style.name != 'table of figures' and p.text.strip().startswith(prefix): return p
    raise KeyError(prefix)


def run(doc, t, manual_table, steps_replace):
    # 3-1 系統架構
    set_para(_para(doc, '物聯網控制終端：')._p,
             '物聯網控制終端：每台實體智慧書櫃搭載一片ESP32微控制器，控制四組電磁鎖（對應A01至A04四扇櫃門）與書櫃螢幕；螢幕僅供顯示QR Code、比對數字、櫃門編號與倒數等提示，使用者之操作皆於App完成。終端以專屬之裝置憑證透過HTTPS定時向伺服器查詢書櫃狀態、接收開鎖指令，並回報開門、關門與故障等事件；另提供於瀏覽器執行相同裝置邏輯之模擬書櫃網頁，供測試使用。')

    # 3-2 軟硬體需求
    _set(_row(t('表 3-2-3'), '硬體功能要求'), [None, '具備後置相機鏡頭（用於掃描QR Code與拍攝書況）與定位功能（使用智慧書櫃時須允許存取位置資訊）'])
    x = t('表 3-2-4')
    _set(_row(x, '微控制器'), [None, 'ESP32開發板或同等級具備Wi-Fi聯網能力之晶片，每台書櫃一片'])
    _set(_row(x, '周邊元件'), [None, '電磁鎖4組及其驅動電路（對應A01至A04四扇櫃門）；240×320 TFT顯示模組（僅供顯示QR Code、比對數字與櫃門提示，不需觸控）；門磁感測器（選配）'])
    _set(_row(x, '通訊介面'), [None, '內建Wi-Fi（2.4 GHz, 802.11 b/g/n），以HTTPS連線伺服器'])
    _set(_row(x, '電源供應'), [None, 'DC 5V/2A以上穩壓電源（控制板與顯示模組）；電磁鎖依其額定規格供電'])
    x = t('表 3-2-5')
    fw = _row(x, '韌體開發', col=1)
    _set(fw, [None, None, None, '編寫微控制器之電磁鎖、顯示螢幕與網路通訊控制程式。'])
    hw = _row(x, '硬體環境', col=1)
    _set(hw, [None, None, None, '負責電磁鎖、顯示螢幕與門磁感測器之控制，並以HTTPS定時與後端伺服器同步狀態、回報事件。'])
    _after(hw, [None, '模擬書櫃', 'HTML5網頁（/kiosk）', '於瀏覽器執行與韌體相同之裝置邏輯，供測試書櫃存取流程。'])

    # 附錄二 硬體接線圖：內文依最終硬體改寫；接線圖圖檔須由硬體負責人依電磁鎖設計重畫後替換
    set_para(_para(doc, '本系統硬體以ESP32')._p,
             '本系統每台智慧書櫃以一片ESP32作為主控制器，經驅動電路控制4組電磁鎖（對應A01至A04四扇櫃門），另接240×320 TFT顯示模組（僅供顯示，不需觸控）與選配之門磁感測器。各模組與主控制器間之腳位連接方式如下：')

    # 4-2 組織分工：書櫃以電磁鎖開關櫃門
    for node in doc.element.body.iter(W('t')):
        if node.text and '步進馬達控制' in node.text:
            node.text = node.text.replace('步進馬達控制', '電磁鎖控制')

    # 9-1-1 元件清單
    x = t('表 9-1-1')
    _set(_row(x, 'features/orders（Flutter）'), [None, None, '購物車、訂單列表與明細（含掃描書櫃取書與存書之入口）、爭議申請畫面。'])
    _set(_row(x, 'services/api/*_api.dart'), ['services/api/*_api.dart（27個檔案）', None, '以Dart extension方式依業務領域擴充ApiService，對應後端29組路由掛載。'])
    for values in [
        ('services/cabinet-devices.js, cabinet-challenges.js, cabinet-access.js', '後端', '裝置配對請求與裝置憑證、裝置驗證與憑證複製偵測、狀態輪詢與事件回報（以事件鍵避免重複處理）、一次性書櫃QR挑戰碼，以及書櫃存取模式（掃碼、手動回報、暫停服務）之判定。'),
        ('services/cabinet-sessions.js, cabinet-candidates.js, cabinet-commit.js', '後端', '書櫃作業狀態機：掃碼建立作業、列出可辦理項目、數字比對、開鎖指令、手機結束作業與各階段逾時；櫃門關閉後逐項提交存書、取書與取回，重複呼叫不會重複提交。'),
        ('services/cabinet-doors.js, cabinet-release.js', '後端', '櫃門與電磁鎖通道之對應、櫃門分配與狀態判定、櫃內書籍紀錄與待確認櫃門；訂單取消、逾期與作業進行中之櫃門處理。'),
        ('services/cabinet-manual.js, cabinet-admin.js, cabinet-events.js', '後端', '故障備援之手動回報與管理員確認、後台櫃門處理（登記存放內容、清空存放紀錄）、書櫃事件紀錄與管理員通知。'),
        ('routes/device.js, middleware/device-auth.js', '後端', '書櫃裝置API（/api/device/v1）：配對申請與輪詢、狀態查詢、事件回報與解除配對；以Device憑證與開機代碼驗證裝置，並依裝置限流。'),
        ('routes/kiosk.js, views/kiosk/（device-core.js, kiosk.js）', '後端', '模擬書櫃網頁（/kiosk）：以240×320畫面模擬書櫃螢幕，device-core.js實作與ESP32韌體相同之配對、輪詢、事件佇列、開鎖與倒數邏輯；控制台可模擬開關門、門磁、櫃門故障、離線、網路延遲與重新開機。'),
        ('features/cabinet（Flutter）', '前端', '書櫃掃碼流程：相機掃描書櫃QR Code、取得定位、確認項目、輸入比對數字、顯示櫃門與倒數、完成或取消、接續進行中之作業與顯示結果，以及故障備援之手動回報。'),
        ('features/admin/admin_cabinet_device_screen.dart（Flutter）', '前端', '後台書櫃裝置管理：輸入配對碼、裝置狀態與撤銷、櫃門卡片（遠端開啟、確認內容、登記與清空存放紀錄、維修與故障）、待確認手動回報與作業、最近作業與事件紀錄。'),
    ]:
        _append(x, list(values))

    # 9-2-2 前端套件
    x = t('表 9-2-2')
    _set(_row(x, 'geolocator'), [None, None, '取得使用者位置以排序鄰近智慧書櫃，並於掃描書櫃時確認使用者位於書櫃附近'])
    _set(_row(x, 'qr_flutter'), [None, None, '個人主頁QR Code產生'])

    # 9-2-3 限流
    x = t('表 9-2-3')
    for values in [('書櫃掃碼建立作業', '1分鐘', '10次', '使用者'),
                   ('書櫃作業操作（開啟櫃門、取消、輸入比對數字、結束作業）', '1分鐘', '20次', '使用者'),
                   ('書櫃作業查詢', '1分鐘', '120次', '使用者'),
                   ('後台輸入書櫃配對碼', '10分鐘', '10次', '使用者'),
                   ('後台遠端開啟櫃門', '10分鐘', '10次', '使用者'),
                   ('裝置申請配對碼', '10分鐘', '10次', 'IP'),
                   ('裝置申請配對碼（全站）', '1分鐘', '30次', '全站'),
                   ('裝置輪詢配對結果', '1分鐘', '60次', 'IP'),
                   ('裝置狀態查詢', '1分鐘', '240次', '裝置'),
                   ('裝置事件回報', '1分鐘', '120次', '裝置'),
                   ('裝置解除配對', '1分鐘', '10次', '裝置')]:
        _append(x, list(values))

    # 9-2-4 錯誤代碼
    x = t('表 9-2-4')
    anchor = row_by_key(x, 'CABINET_HAS_DEPOSITS')
    for values in [
        ('CABINET_CODE_INVALID', '400', '掃描之QR Code並非本平台之書櫃QR Code'),
        ('CABINET_CODE_EXPIRED', '410', '書櫃QR Code已更新或已使用，須重新掃描書櫃螢幕上之QR Code'),
        ('CABINET_BUSY', '409', '書櫃正由其他作業使用'),
        ('CABINET_OFFLINE', '409', '書櫃裝置連線中斷；離線持續2分鐘以上時可改為手動回報'),
        ('CABINET_CLOSED', '409', '目前非書櫃營業時間'),
        ('CABINET_LOCATION_REQUIRED', '403', '使用者未允許App存取位置資訊'),
        ('CABINET_LOCATION_UNAVAILABLE', '403', '無法取得定位，或定位精度超過500公尺、取得時間超過60秒'),
        ('CABINET_TOO_FAR', '403', '使用者與書櫃之距離超過200公尺'),
        ('CABINET_WRONG_CABINET', '409', '訂單或書籍之指定書櫃非此書櫃'),
        ('CABINET_CONTEXT_CHANGED', '409', '掃碼時訂單或書籍之狀態已變更'),
        ('CABINET_NOTHING_TO_DO', '404', '使用者於此書櫃沒有待辦理之項目'),
        ('CABINET_ITEM_BLOCKED', '409', '項目皆無法辦理（櫃門故障、待確認或無法確認櫃門）'),
        ('CABINET_ACTIVE_SESSION', '409', '使用者已有進行中之書櫃作業'),
        ('CABINET_COOLDOWN', '429', '使用者於同一書櫃最近兩次作業皆於開門前結束，須等候10分鐘；管理員10分鐘內兩次遠端開櫃之數字確認逾時或不符，須待該10分鐘期間屆滿'),
        ('CABINET_NO_SELECTION', '400', '開啟櫃門時未選擇任何項目'),
        ('CABINET_FULL', '409', '書櫃可用櫃門不足'),
        ('CABINET_ITEMS_CHANGED', '409', '開啟櫃門前部分項目狀態已變更，須重新確認'),
        ('PREDEPOSIT_LIMIT', '409', '賣家於此書櫃之先行存書已達上限'),
        ('CABINET_SESSION_NOT_FOUND', '404', '查無此書櫃作業，或非本人之作業'),
        ('CABINET_SESSION_STATE', '409', '書櫃作業目前之狀態不允許此操作'),
        ('MATCH_CODE_INVALID', '400', '比對數字須為兩位數字，格式錯誤不消耗比對機會'),
        ('CABINET_SCAN_REQUIRED', '409', '書櫃連線正常，須至書櫃掃碼辦理，不接受手動回報'),
        ('MANUAL_REPORT_PENDING', '409', '此項目已有待管理員確認之手動回報'),
        ('ORDER_IN_CABINET_SESSION', '409', '訂單正於書櫃辦理中，暫時不可取消或申請爭議'),
        ('DEVICE_NOT_PAIRED', '409', '書櫃尚未配對裝置'),
        ('DEVICE_OFFLINE', '409', '書櫃裝置離線，無法遠端開啟櫃門'),
        ('PAIRING_CODE_INVALID', '400', '配對碼無效、已逾時或已綁定'),
        ('PAIRING_EXPIRED', '410', '裝置之配對請求已逾時或憑證已領取，須重新申請配對碼'),
        ('DOOR_NOT_FOUND', '404', '櫃門不屬於此書櫃或未對應電磁鎖'),
        ('DOOR_NOT_EMPTY', '409', '櫃門有存放紀錄、待確認或被作業保留，不可不經數字確認開啟'),
        ('DOOR_HAS_ORDER', '409', '櫃門存放進行中訂單之書籍，須先於訂單管理調整訂單狀態'),
        ('DOOR_ASSIGN_INVALID', '409', '登記之書籍不在此書櫃、已有櫃門紀錄，或與櫃內其他項目不屬同一筆訂單或同一本書'),
        ('DOOR_REQUIRED', '400', '確認存書之手動回報時未指定櫃門'),
        ('SLOT_STATUS_DERIVED', '409', '櫃門狀態由系統依存放內容判定，僅可設定或結束維修'),
        ('SESSION_NOT_REVIEWABLE', '409', '書櫃作業目前之狀態無法由管理員處理'),
        ('SESSION_SELF_REVIEW', '403', '使用者作業之發起人或所選項目之當事人為本人時，管理員不得處理該作業'),
        ('MANUAL_REPORT_SELF_REVIEW', '403', '管理員不得處理與本人相關之手動回報'),
        ('MANUAL_REPORT_NOT_PENDING', '409', '手動回報已處理'),
        ('MANUAL_REPORT_STALE', '409', '確認時項目狀態已變更，手動回報改為失效'),
        ('DEVICE_AUTH_REQUIRED', '401', '裝置API缺少Device憑證'),
        ('DEVICE_REVOKED', '401', '裝置憑證已失效，須重新配對'),
        ('DEVICE_DISABLED', '403', '模擬書櫃功能未開放'),
        ('DEVICE_PAYLOAD_INVALID', '400', '裝置請求格式不正確或缺少開機代碼'),
        ('DEVICE_STALE_BOOT', '409', '請求來自裝置重新啟動前，已略過'),
    ]:
        anchor = _after(anchor, list(values))

    # 9-2-8 路由掛載（重新編號前）
    p = _para(doc, 'API路由掛載對照')
    set_para(p._p, p.text.strip().replace('26組', '29組'))
    x = t('表 9-2-8')
    _after(row_by_key(x, '/api/cabinets'), ['/api/device/v1', 'routes/device.js', '書櫃裝置API：配對、狀態查詢與事件回報（以Device憑證驗證，與使用者權杖互不通用）'])
    _after(row_by_key(x, '/api/orders'), ['/api/cabinet-sessions', 'routes/cabinet-sessions.js', '書櫃掃碼作業：建立作業、開啟櫃門、輸入比對數字、結束或取消作業'])
    _after(row_by_key(x, '/api/ai'), ['/kiosk', 'routes/kiosk.js', '模擬書櫃網頁（僅於開放模擬書櫃功能時提供）'])
    _set(row_by_key(x, '/api/admin'), [None, None, '後台管理（14個子模組，需管理員角色）'])

    # 10-1-1 後端測試
    x = t('表 10-1-1')
    _after(row_by_key(x, 'test/auth'), ['test/cabinet', '書櫃存取模式、QR挑戰碼、裝置配對與撤銷、開機代碼與複製偵測、狀態輪詢與事件回報、櫃門分配與待確認、掃碼建立作業（定位、冷卻、情境）、數字比對與開門、手機結束作業與門磁拒絕、關門後提交與重送、逾時與待確認處理、遠端開櫃、手動回報待確認、排程與端對端流程', '207'])
    _after(row_by_key(x, 'test/commerce'), ['test/kiosk', '模擬書櫃device-core（假時鐘與假fetch：配對、輪詢、事件佇列、開鎖時序、倒數與關門指令）、模擬書櫃路由與安全標頭', '51'])

    # 10-2-1 代表性測試
    x = t('表 10-2-1')
    for values in [
        ('比對數字只有一次機會', '開啟櫃門後於手機輸入錯誤之兩位數字', '作業轉為failed／MATCH_FAILED並釋放書櫃，事件不記錄輸入值', '通過'),
        ('定位為開啟櫃門之必要條件', '拒絕定位權限、無法取得定位、精度超過500公尺或定位超過60秒時掃碼', '回傳403 CABINET_LOCATION_REQUIRED或CABINET_LOCATION_UNAVAILABLE，留下拒絕紀錄且QR Code未被使用', '通過'),
        ('同一組QR Code只能兌換一次', '兩位使用者同時以同一組QR Code建立作業', '只有一人建立作業，另一人之作業不會留下', '通過'),
        ('櫃門關閉後才提交取書', '買家開門取書後，書櫃回報session_closed', '記錄取書時間、通知賣家、刪除櫃內紀錄並釋放櫃門', '通過'),
        ('重送關門回報不重複提交', '書櫃重送同一作業之session_closed', '訂單與存書只提交一次', '通過'),
        ('櫃門未關時手機按完成', '有門磁之書櫃櫃門仍開啟時，手機送出完成', '書櫃拒絕並提示先關上櫃門，關門後作業完成', '通過'),
        ('開門後取消不變更狀態', '存書櫃門開啟後於手機按取消', '作業為cancelled／CANCELLED_AFTER_OPEN，櫃門設為待確認並通知管理員', '通過'),
        ('配對憑證只交付一次', '管理員輸入配對碼後，裝置並行輪詢配對結果', '只有一次取得裝置憑證，原有裝置隨即撤銷', '通過'),
        ('裝置憑證遭複製時撤銷', '同一憑證以兩個開機代碼交錯連線', '撤銷裝置、記錄事件並通知管理員', '通過'),
        ('僅空櫃門可不經比對遠端開啟', '管理員以不經數字確認之方式開啟有存放紀錄之櫃門', '回傳409 DOOR_NOT_EMPTY', '通過'),
        ('故障期間之手動回報待管理員確認', '裝置離線超過2分鐘時賣家回報存書', '回傳202，訂單維持待存書；管理員確認後改為已存書並通知買家', '通過'),
        ('連線正常時不接受手動回報', '裝置在線時一般使用者回報取書', '回傳409 CABINET_SCAN_REQUIRED', '通過'),
    ]:
        _append(x, list(values))

    # 11-1-1 系統元件
    x = t('表 11-1-1')
    r = _after(row_by_key(x, '行動應用執行環境'), ['智慧書櫃終端', 'ESP32（Arduino Core for ESP32）＋電磁鎖4組＋240×320 TFT顯示模組', '每台書櫃一片ESP32，以裝置憑證經HTTPS定時查詢書櫃狀態（閒置每2秒、作業中每1秒）並回報事件；事件先保存於本機佇列，連線恢復後補送'])
    _after(r, ['模擬書櫃網頁', '瀏覽器（HTML5 Canvas），由API於/kiosk提供', '於瀏覽器執行與韌體相同之裝置邏輯，須經管理員輸入配對碼後啟用；僅於CABINET_SIMULATOR=true時開放'])

    # 11-2-1 後端安裝：NGINX 步驟之後加入書櫃設定
    x = t('表 11-2-1')
    step8 = row_by_key(x, '8')
    for tr in x.findall(W('tr'))[1:]:
        n = text_of(tcs(tr)[0]).strip()
        if n.isdigit() and int(n) >= 9: set_cell(tcs(tr)[0], str(int(n) + 1))
    _after(step8, ['9', '設定智慧書櫃：於.env設定CABINET_SIMULATOR（是否開放模擬書櫃網頁/kiosk）與CABINET_TIMEZONE，並確認NGINX將/kiosk轉發至API；書櫃裝置（ESP32或模擬書櫃）開機後螢幕顯示8位數配對碼，由管理員於App後台之「書櫃裝置」頁面輸入完成配對'])

    # 11-2-3 環境變數
    x = t('表 11-2-3')
    for values in [('CABINET_SIMULATOR', '選用', 'false', '開放模擬書櫃網頁（/kiosk）並接受模擬書櫃裝置；關閉後模擬書櫃之裝置憑證立即失效。接上實體書櫃正式營運前應關閉'),
                   ('CABINET_QR_SECRET', '選用', '由JWT_SECRET推導', '書櫃QR Code挑戰碼之推導金鑰；更換後各書櫃於下一次查詢時顯示新QR Code'),
                   ('CABINET_TIMEZONE', '選用', 'Asia/Taipei', '判斷書櫃營業時間所用之時區')]:
        _append(x, list(values))

    # 使用手冊：書櫃裝置與櫃門管理（管理員）
    head = next(p for p in doc.paragraphs if p.text.strip() == '後台管理入口導覽')._p
    tbl = manual_table(doc, '後台管理入口導覽')
    new_head, new_tbl = copy.deepcopy(head), copy.deepcopy(tbl)
    set_para(new_head, '書櫃裝置與櫃門管理（管理員）')
    steps_replace(new_tbl, [
        '於後台「硬體與營運」之「書櫃監控」，點擊書櫃卡片之裝置圖示進入「書櫃裝置」頁面，可查看裝置種類、裝置編號、韌體版本、最後連線與存取模式。',
        '配對裝置：書櫃裝置通電連網後，螢幕顯示8位數配對碼與剩餘時間；於頁面輸入此配對碼並完成身分驗證，裝置隨即取得憑證並開始顯示QR Code。配對碼逾時時，書櫃會自動顯示新的配對碼；新裝置配對後，原有裝置即失效。',
        '遠端開啟櫃門：於櫃門卡片選擇「遠端開啟櫃門」，輸入開啟原因並完成身分驗證；書櫃螢幕顯示兩位數字後，請現場人員告知並於App輸入，櫃門隨即開啟並倒數120秒，處理完畢後點擊「完成」。無存放紀錄之空櫃門可選擇「不經數字確認直接開啟」。',
        '櫃門開啟後或作業異常時，櫃門標示「待確認存放內容」；請依實際情況選擇「確認內容無誤」、「登記存放內容」或「清空存放紀錄」（「書籍已取出」或「僅更正紀錄」）。櫃門亦可設為維修中或清除故障。',
        '「待確認手動回報」列出書櫃故障期間使用者之存書、取書與取回回報，可「確認回報」（存書須選擇書籍實際存放之櫃門）或「駁回回報」（須填寫處理說明）；與本人相關之回報須由其他管理員處理。',
        '「待確認作業」列出書櫃未回報開門或關門之作業，可「確認已完成」或「確認未完成」並填寫處理說明；「最近作業」與「事件紀錄」可查閱每次作業之時間軸與書櫃事件。',
        '需停用裝置時點擊「撤銷裝置」；撤銷後書櫃改為手動回報，須重新配對才能恢復掃碼存取。',
    ])
    tbl.addnext(new_head); new_head.addnext(new_tbl)
