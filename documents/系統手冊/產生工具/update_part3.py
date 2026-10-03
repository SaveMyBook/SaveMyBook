import copy, re
from doctools import *
from doclib import captioned_tables

NEW_TABLES = [
    ('ai_book_enrichments', '書籍資料補齊紀錄表', 'book_id', '記錄系統依ISBN書目或AI網路搜尋自動補齊書籍欄位之結果、來源與重試排程，每本書一筆；賣家修改或清空過之欄位不再自動補齊',
     [('book_id', '書籍編號', 'INT', 'V', 'V', 'V'),
      ('status', '處理結果（done已補齊／partial部分補齊／none查無可用資料／mismatch書目書名與刊登不符）', 'VARCHAR(10)', '', 'V', ''),
      ('fields', '已補齊欄位（逗號分隔）', 'VARCHAR(200)', '', 'V', ''), ('ai_written', '簡介是否由AI整理', 'TINYINT(1)', '', 'V', ''),
      ('attempted_at', '最近處理時間', 'DATETIME', '', 'V', ''),
      ('attempts', '嘗試次數（外部服務暫時無法使用時不計入）', 'TINYINT', '', 'V', ''),
      ('next_attempt_at', '下次嘗試時間（依1、7、30天間隔，最多3次；為空時不再重試）', 'DATETIME', '', '', ''),
      ('seller_fields', '賣家修改或清空過而不再自動補齊之欄位（逗號分隔）', 'VARCHAR(100)', '', 'V', ''),
      ('rejected_fields', '賣家修改過之原自動補齊欄位（變更ISBN時恢復補齊）', 'VARCHAR(100)', '', 'V', ''),
      ('sources', '補齊內容之來源網頁（JSON）', 'TEXT', '', '', ''),
      ('observations', '觀察標記（simplified疑似簡體字／unsourced_numbers含來源外數字／uncited無引用來源；不影響寫入）', 'VARCHAR(100)', '', 'V', ''),
      ('generation', '補齊輪次（變更ISBN而重新補齊時加一，進行中之舊補齊放棄寫入）', 'INT', '', 'V', ''),
      ('restarted_at', '上次立即重新補齊之時間', 'DATETIME', '', '', '')],
     ['book_id　→　books.book_id']),
    ('ai_budget_alerts', 'AI預算通知紀錄表', 'month, threshold', '記錄每月AI費用達預算80%或100%時對具系統維運權限之管理員發出之通知，同一門檻每月只通知一次',
     [('month', '月份（YYYY-MM）', 'CHAR(7)', 'V', 'V', ''), ('threshold', '預算門檻百分比（80／100）', 'TINYINT', 'V', 'V', ''),
      ('cost_usd', '通知時之當月費用（USD）', 'DECIMAL(12, 6)', '', 'V', ''), ('created_at', '通知時間', 'DATETIME', '', 'V', '')],
     []),
    ('ai_decision_logs', 'AI決策紀錄表', 'log_id', '記錄AI客服、AI問書、個人化推薦、上架輔助與交易爭議分析每次處理之結果、路徑與統計，只保存代號、計數與耗時，不保存使用者原文、完整提示詞或照片；保存90日，撤回AI使用同意或刪除帳號時一併刪除',
     [('log_id', '紀錄編號', 'BIGINT', 'V', 'V', ''), ('request_id', '請求識別碼（與AI使用量紀錄串連）', 'VARCHAR(32)', '', 'V', ''),
      ('feature', '功能別', 'VARCHAR(30)', '', 'V', ''), ('user_id', '觸發使用者編號', 'INT', '', '', 'V'),
      ('outcome', '處理結果（ok成功／repaired修復後成功／degraded改用備援回覆／empty清理後為空／refused被拒絕／failed失敗）', 'VARCHAR(20)', '', 'V', ''),
      ('path', '處理路徑代號', 'VARCHAR(30)', '', '', ''), ('stats', '統計資料（JSON，僅含代號、計數與耗時）', 'TEXT', '', '', ''),
      ('created_at', '建立時間', 'DATETIME', '', 'V', '')],
     ['user_id　→　users.user_id']),
    ('ai_dispute_analyses', '交易爭議AI分析紀錄表', 'analysis_id', '保存交易爭議之AI分析結果，管理員開啟案件時直接載入最新一筆，按「重新分析」時才新增；裁決時於最後一筆記錄建議與裁決是否一致',
     [('analysis_id', '分析編號', 'INT', 'V', 'V', ''), ('dispute_id', '爭議案件編號', 'INT', '', 'V', 'V'),
      ('admin_id', '執行分析之管理員編號', 'INT', '', '', ''), ('result', '分析結果（JSON，含摘要、發現與理由）', 'TEXT', '', 'V', ''),
      ('suggestion', 'AI建議（refund退款／dismiss駁回／mediate調解／need_more_info需要更多資訊）', 'VARCHAR(20)', '', 'V', ''),
      ('listing_images', '實際送出之上架照片數', 'TINYINT', '', 'V', ''), ('evidence_images', '實際送出之爭議佐證照片數', 'TINYINT', '', 'V', ''),
      ('provider', 'AI供應商', 'VARCHAR(20)', '', 'V', ''), ('model', '使用模型', 'VARCHAR(80)', '', 'V', ''),
      ('prompt_version', '提示詞版本（雜湊）', 'CHAR(12)', '', 'V', ''), ('helpful', '管理員評價是否有幫助', 'TINYINT(1)', '', '', ''),
      ('resolved_result', '裁決結果', 'VARCHAR(20)', '', '', ''), ('agreed', '建議與裁決是否一致（建議需要更多資訊時為空）', 'TINYINT(1)', '', '', ''),
      ('resolved_at', '裁決時間', 'DATETIME', '', '', ''), ('created_at', '分析時間', 'DATETIME', '', 'V', '')],
     ['dispute_id　→　transaction_disputes.dispute_id']),
    ('ai_embeddings', 'AI語意索引表', 'kind, ref_id', '保存書籍與客服知識段落之向量嵌入，供混合檢索使用；內容或模型改變時重建',
     [('kind', '索引類型（book／knowledge）', 'VARCHAR(20)', 'V', 'V', ''), ('ref_id', '來源編號', 'VARCHAR(64)', 'V', 'V', ''),
      ('model', '嵌入模型名稱', 'VARCHAR(100)', '', 'V', ''), ('content_hash', '內容雜湊（SHA-256）', 'CHAR(64)', '', 'V', ''),
      ('vector', '向量（JSON）', 'MEDIUMTEXT', '', 'V', ''), ('updated_at', '更新時間', 'DATETIME', '', 'V', '')],
     []),
    ('ai_isbn_cache', 'ISBN書目共用快取表', 'isbn', '保存同一ISBN經書名比對與來源驗證之書目、簡介與定價，供不同賣家上架與書目補齊共用，避免重複付費搜尋；資料完整者保存180日，其餘保存30日，管理員可清除單一ISBN之快取',
     [('isbn', 'ISBN（13碼）', 'CHAR(13)', 'V', 'V', ''), ('status', '查詢結果（found有資料／none查無結果）', 'VARCHAR(10)', '', 'V', ''),
      ('fields', '書目欄位（JSON）', 'TEXT', '', '', ''), ('description', '簡介', 'TEXT', '', '', ''),
      ('description_source', '簡介來源（sources來源原文／mixed依來源整理／ai依網路搜尋撰寫）', 'VARCHAR(10)', '', 'V', ''),
      ('original_price', '定價（新臺幣）', 'INT', '', '', ''), ('sources', '來源網頁（JSON）', 'TEXT', '', '', ''),
      ('missing', '網路搜尋仍查無之欄位與搜尋時間（JSON，30天內不再搜尋）', 'VARCHAR(255)', '', '', ''),
      ('prompt_version', '提示詞版本（與目前版本不同時視為未命中）', 'VARCHAR(20)', '', 'V', ''), ('hits', '命中次數', 'INT', '', 'V', ''),
      ('created_at', '建立時間', 'DATETIME', '', 'V', ''), ('updated_at', '更新時間', 'DATETIME', '', 'V', ''),
      ('expires_at', '到期時間', 'DATETIME', '', 'V', '')],
     []),
    ('ai_listing_suggestions', '上架輔助建議紀錄表', 'token', '記錄上架輔助回應之建議值，賣家建立書籍時帶回權杖，據以計算各欄位之採用率；未使用之權杖1日後刪除，其餘保存90日',
     [('token', '建議權杖', 'CHAR(32)', 'V', 'V', ''), ('user_id', '會員編號', 'INT', '', 'V', 'V'),
      ('fields', '建議值（JSON；簡介僅存雜湊）', 'TEXT', '', 'V', ''), ('adopted', '建立書籍後各欄位是否採用（JSON）', 'VARCHAR(400)', '', '', ''),
      ('used_at', '建立書籍時帶回之時間', 'DATETIME', '', '', ''), ('created_at', '建立時間', 'DATETIME', '', 'V', '')],
     ['user_id　→　users.user_id']),
    ('ai_listing_tokens', '上架輔助折抵權杖表', 'token_hash', '上架輔助第一步完成時發給App之權杖，僅保存雜湊；第二步帶回時該次不另計每日次數，每個權杖僅能折抵一次，24小時內有效',
     [('token_hash', '權杖雜湊（SHA-256）', 'CHAR(64)', 'V', 'V', ''), ('user_id', '會員編號', 'INT', '', 'V', 'V'),
      ('created_at', '發出時間', 'DATETIME', '', 'V', ''), ('redeemed_at', '折抵時間', 'DATETIME', '', '', '')],
     ['user_id　→　users.user_id']),
    ('ai_message_requests', 'AI訊息登記表', 'request_id', '登記App為每則AI客服與AI問書訊息產生之識別碼，重送同一則訊息時回傳第一次之結果，不重複呼叫AI服務與寫入對話；只存訊息編號，不存內容，建立滿24小時後刪除',
     [('request_id', '登記編號', 'INT', 'V', 'V', ''), ('user_id', '會員編號', 'INT', '', 'V', 'V'),
      ('feature', '功能別（support AI客服／book_chat AI問書）', 'VARCHAR(20)', '', 'V', ''), ('client_id', 'App產生之訊息識別碼', 'VARCHAR(64)', '', 'V', ''),
      ('status', '處理狀態（processing處理中／done已完成）', "ENUM('processing', 'done')", '', 'V', ''),
      ('user_message_id', '對應之使用者訊息編號', 'INT', '', '', ''), ('reply_message_id', '對應之助理回覆編號', 'INT', '', '', ''),
      ('meta', '重建回應所需之資料（JSON，不含使用者原文）', 'TEXT', '', '', ''),
      ('created_at', '建立時間', 'DATETIME', '', 'V', ''), ('updated_at', '更新時間', 'DATETIME', '', 'V', '')],
     ['user_id　→　users.user_id']),
    ('ai_review_events', '上架審核事件表', 'event_id', '記錄上架審核狀態之每次變更，只新增不修改，保存執行者類型、所依據之判定與是否誤判，供統計各類別之誤判率',
     [('event_id', '事件編號', 'BIGINT', 'V', 'V', ''), ('book_id', '書籍編號', 'INT', '', 'V', 'V'),
      ('actor', '執行者類型（admin管理員審核／seller_edit賣家修改後重新審核／relist管理員恢復上架／system系統審核）', 'VARCHAR(12)', '', 'V', ''),
      ('prior', '變更前之審核狀態', 'VARCHAR(10)', '', '', ''), ('status', '變更後之審核狀態', 'VARCHAR(10)', '', 'V', ''),
      ('verdict', '判定結果（管理員審核時為原判定）', 'VARCHAR(10)', '', 'V', ''), ('origin', '判定來源（ai／rules）', 'VARCHAR(10)', '', 'V', ''),
      ('categories', '判定之違規類別（JSON）', 'VARCHAR(255)', '', 'V', ''), ('confidence', '判定之把握度', 'DECIMAL(4, 3)', '', '', ''),
      ('category', '管理員駁回時選擇之原因類別', 'VARCHAR(20)', '', '', ''),
      ('misjudged', '是否為誤判（管理員審核，以及恢復背景審核駁回之書籍時記錄）', 'TINYINT(1)', '', '', ''),
      ('created_at', '建立時間', 'DATETIME', '', 'V', '')],
     ['book_id　→　books.book_id']),
    ('book_deposits', '書櫃存書登記表', 'book_id', '記錄賣家於訂單成立前先行存放於智慧書櫃之書籍，以及逾期暫停販售、提醒取回與通知管理員之時間，每本書一筆',
     [('book_id', '書籍商品編號', 'INT', 'V', 'V', 'V'), ('cabinet_id', '存放之智慧書櫃編號', 'INT', '', 'V', 'V'),
      ('deposited_at', '存入時間', 'DATETIME', '', 'V', ''), ('paused_at', '存放滿7天轉為待取回之時間', 'DATETIME', '', '', ''),
      ('auto_paused', '是否由系統暫停販售（取回後恢復上架）', 'TINYINT(1)', '', 'V', ''),
      ('reminded_at', '最近提醒取回時間', 'DATETIME', '', '', ''), ('escalated_at', '通知管理員時間', 'DATETIME', '', '', '')],
     ['book_id　→　books.book_id', 'cabinet_id　→　smart_cabinets.cabinet_id']),
    ('chat_message_risks', '聊天訊息風險紀錄表', 'message_id', '記錄聊天文字訊息之防詐檢查結果（僅保存有風險者），供收訊方提醒與管理員警示',
     [('message_id', '訊息編號', 'INT', 'V', 'V', 'V'), ('room_id', '聊天室編號', 'INT', '', 'V', ''), ('sender_id', '傳送者會員編號', 'INT', '', 'V', ''),
      ('level', '風險等級（notice／high）', 'VARCHAR(10)', '', 'V', ''), ('categories', '風險類別（逗號分隔）', 'VARCHAR(100)', '', 'V', ''),
      ('score', '風險分數', 'TINYINT', '', 'V', ''), ('created_at', '建立時間', 'DATETIME', '', 'V', '')],
     ['message_id　→　chat_messages.message_id']),
    ('chat_risk_alerts', '聊天防詐警示表', 'alert_id', '會員24小時內累積3則高風險訊息時建立之管理員警示佇列',
     [('alert_id', '警示編號', 'INT', 'V', 'V', ''), ('user_id', '會員編號', 'INT', '', 'V', 'V'),
      ('status', '處理狀態（open／dismissed／resolved）', 'VARCHAR(10)', '', 'V', ''), ('hit_count', '累積高風險訊息數', 'INT', '', 'V', ''),
      ('first_at', '首次觸發時間', 'DATETIME', '', 'V', ''), ('last_at', '最近觸發時間', 'DATETIME', '', 'V', ''),
      ('handled_by', '處理之管理員編號', 'INT', '', '', ''), ('handled_at', '處理時間', 'DATETIME', '', '', '')],
     ['user_id　→　users.user_id']),
    ('recommendation_dismissals', '推薦不感興趣紀錄表', 'user_id, book_id', '記錄使用者對推薦書籍標示「不感興趣」，之後之推薦排除這些書籍',
     [('user_id', '會員編號', 'INT', 'V', 'V', 'V'), ('book_id', '書籍編號', 'INT', 'V', 'V', 'V'), ('created_at', '標示時間', 'DATETIME', '', 'V', '')],
     ['user_id　→　users.user_id', 'book_id　→　books.book_id']),
    ('support_ticket_attachments', '客服工單附件表', 'attachment_id', '客服工單訊息之附件圖片，僅能經簽章網址讀取',
     [('attachment_id', '附件編號', 'INT', 'V', 'V', ''), ('message_id', '工單訊息編號（上傳後尚未送出時為空）', 'INT', '', '', 'V'),
      ('uploader_id', '上傳者會員編號', 'INT', '', 'V', 'V'), ('url', '檔案路徑', 'VARCHAR(255)', 'V', 'V', ''),
      ('byte_size', '檔案大小（位元組）', 'INT', '', 'V', ''), ('sort_order', '排序', 'TINYINT', '', 'V', ''), ('created_at', '建立時間', 'DATETIME', '', 'V', '')],
     ['message_id　→　support_ticket_messages.message_id', 'uploader_id　→　users.user_id']),
    ('user_passkeys', '通行密鑰表', 'passkey_id', '使用者註冊之通行密鑰（WebAuthn）公鑰與使用紀錄，每帳號最多10組',
     [('passkey_id', '通行密鑰編號', 'INT', 'V', 'V', ''), ('user_id', '會員編號', 'INT', '', 'V', 'V'), ('credential_id', '憑證編號', 'VARCHAR(255)', 'V', 'V', ''),
      ('public_key', '公鑰', 'TEXT', '', 'V', ''), ('sign_count', '簽章計數', 'INT', '', 'V', ''), ('transports', '傳輸方式', 'VARCHAR(100)', '', '', ''),
      ('aaguid', '驗證器型號識別碼', 'CHAR(36)', '', '', ''), ('backed_up', '是否已同步備份', 'TINYINT(1)', '', 'V', ''),
      ('device_label', '裝置名稱', 'VARCHAR(50)', '', '', ''), ('created_at', '建立時間', 'DATETIME', '', 'V', ''), ('last_used_at', '最近使用時間', 'DATETIME', '', '', '')],
     ['user_id　→　users.user_id']),
    ('webauthn_challenges', 'WebAuthn挑戰碼暫存表', 'challenge', '通行密鑰註冊、登入與驗證之一次性挑戰碼，5分鐘內有效',
     [('challenge', '挑戰碼', 'CHAR(64)', 'V', 'V', ''), ('user_id', '會員編號（登入時為空）', 'INT', '', '', ''),
      ('purpose', '用途', "ENUM('register', 'login', 'verify')", '', 'V', ''), ('created_at', '建立時間', 'DATETIME', '', 'V', '')],
     []),
    # 智慧書櫃（掃碼存取）：依 cabrev/savemybook_api/prisma/schema.prisma
    ('cabinet_challenges', '書櫃QR挑戰碼表', 'challenge_id', '記錄書櫃螢幕QR Code所含一次性挑戰碼之雜湊與效期；每30秒更換一組、每組有效45秒，兌換後同一裝置之舊碼全部作廢',
     [('challenge_id', '挑戰碼編號', 'INT', 'V', 'V', ''), ('device_id', '書櫃裝置編號', 'INT', '', 'V', 'V'),
      ('token_hash', '挑戰碼雜湊（SHA-256）', 'CHAR(64)', 'V', 'V', ''), ('qr_seq', '裝置QR序號（兌換後遞增）', 'INT', '', 'V', ''),
      ('epoch', '30秒時間視窗序號', 'INT', '', 'V', ''), ('expires_at', '到期時間', 'DATETIME', '', 'V', ''),
      ('used_at', '兌換時間', 'DATETIME', '', '', ''), ('used_by', '兌換之會員編號', 'INT', '', '', ''),
      ('created_at', '建立時間', 'DATETIME', '', 'V', '')],
     ['device_id　→　cabinet_devices.device_id']),
    ('cabinet_devices', '書櫃裝置表', 'device_id', '記錄控制智慧書櫃之裝置（ESP32-S3實體書櫃或模擬書櫃）、裝置憑證雜湊、櫃門數與連線、故障狀態；一台書櫃同時僅有一台有效裝置，一台裝置同時僅有一個進行中之作業',
     [('device_id', '裝置編號', 'INT', 'V', 'V', ''), ('cabinet_id', '所屬書櫃編號', 'INT', '', 'V', 'V'),
      ('active_cabinet_id', '有效裝置之書櫃編號（有效時等於cabinet_id，其餘為空）', 'INT', 'V', '', ''),
      ('active_session_id', '進行中之書櫃作業編號', 'INT', 'V', '', ''),
      ('kind', '裝置種類（simulator模擬書櫃／esp32實體書櫃）', "ENUM('simulator', 'esp32')", '', 'V', ''),
      ('status', '裝置狀態（pending待配對／active有效／revoked已撤銷）', "ENUM('pending', 'active', 'revoked')", '', 'V', ''),
      ('token_hash', '裝置憑證雜湊（SHA-256）', 'CHAR(64)', 'V', '', ''), ('door_count', '櫃門數', 'TINYINT', '', 'V', ''),
      ('has_door_sensor', '是否裝有門磁感測器', 'TINYINT(1)', '', 'V', ''), ('unlock_pulse_ms', '電磁鎖開鎖通電時間（毫秒）', 'SMALLINT', '', 'V', ''),
      ('firmware', '韌體版本', 'VARCHAR(40)', '', '', ''), ('fault_code', '裝置故障代碼', 'VARCHAR(40)', '', '', ''),
      ('fault_since', '裝置故障開始時間', 'DATETIME', '', '', ''), ('qr_seq', 'QR序號（作業建立時遞增，使舊QR Code作廢）', 'INT', '', 'V', ''),
      ('current_boot_id', '目前開機代碼', 'VARCHAR(16)', '', '', ''), ('previous_boot_id', '前一次開機代碼', 'VARCHAR(16)', '', '', ''),
      ('boot_switched_at', '開機代碼切換時間', 'DATETIME', '', '', ''), ('last_seen_at', '最後連線時間', 'DATETIME', '', '', ''),
      ('last_ip', '最後連線IP位址', 'VARCHAR(45)', '', '', ''), ('offline_since', '離線開始時間', 'DATETIME', '', '', ''),
      ('offline_notified', '是否已通知管理員離線', 'TINYINT(1)', '', 'V', ''), ('created_by', '建立之管理員編號', 'INT', '', '', ''),
      ('paired_at', '配對時間', 'DATETIME', '', '', ''), ('revoked_at', '撤銷時間', 'DATETIME', '', '', ''),
      ('revoked_by', '撤銷之管理員編號', 'INT', '', '', ''),
      ('revoke_reason', '撤銷原因（device裝置解除配對／replaced新裝置取代／cloned憑證疑遭複製／admin管理員撤銷／simulator_off模擬書櫃功能關閉）', 'VARCHAR(20)', '', '', ''),
      ('created_at', '建立時間', 'DATETIME', '', 'V', ''), ('updated_at', '更新時間', 'DATETIME', '', 'V', '')],
     ['cabinet_id　→　smart_cabinets.cabinet_id']),
    ('cabinet_events', '書櫃事件紀錄表', 'event_id', '記錄書櫃裝置回報之事件（開機、開門、關門、故障等）及伺服器與管理員產生之事件，供後台查詢與稽核；裝置事件以裝置與事件鍵確保只處理一次。為使紀錄於交易資料清除後仍可保留，各編號欄位皆不設外鍵；紀錄保存365天',
     [('event_id', '事件編號', 'INT', 'V', 'V', ''), ('cabinet_id', '書櫃編號', 'INT', '', 'V', ''),
      ('device_id', '裝置編號', 'INT', '', '', ''), ('session_id', '書櫃作業編號', 'INT', '', '', ''),
      ('order_id', '相關訂單編號', 'INT', '', '', ''), ('book_id', '相關書籍編號', 'INT', '', '', ''),
      ('event_key', '裝置事件冪等鍵', 'VARCHAR(64)', '', '', ''),
      ('source', '事件來源（device裝置／server伺服器／admin管理員／user使用者）', "ENUM('device', 'server', 'admin', 'user')", '', 'V', ''),
      ('type', '事件種類', 'VARCHAR(32)', '', 'V', ''), ('lock_channel', '電磁鎖通道', 'TINYINT', '', '', ''),
      ('actor_id', '操作者會員編號', 'INT', '', '', ''), ('detail', '事件內容（JSON）', 'TEXT', '', '', ''),
      ('result', '處理結果', 'VARCHAR(40)', '', '', ''), ('occurred_at', '發生時間', 'DATETIME', '', 'V', ''),
      ('received_at', '接收時間', 'DATETIME', '', 'V', ''), ('claimed_at', '處理認領時間', 'DATETIME', '', '', ''),
      ('processed_at', '處理完成時間', 'DATETIME', '', '', '')],
     []),
    ('cabinet_manual_reports', '書櫃手動回報表', 'report_id', '記錄書櫃未配對裝置、裝置離線或故障期間，使用者對存書、取書或取回之手動回報；回報經管理員確認後才變更訂單或存書狀態',
     [('report_id', '手動回報編號', 'INT', 'V', 'V', ''), ('cabinet_id', '書櫃編號', 'INT', '', 'V', 'V'),
      ('user_id', '回報者會員編號', 'INT', '', 'V', 'V'),
      ('kind', '回報種類（deposit存書／pickup取書／retrieve取回）', "ENUM('deposit', 'pickup', 'retrieve')", '', 'V', ''),
      ('order_id', '相關訂單編號（依訂單存書與取書）', 'INT', '', '', 'V'), ('book_id', '相關書籍編號（先行存書與取回）', 'INT', '', '', 'V'),
      ('target_status', '訂單回報要求之狀態', 'VARCHAR(20)', '', '', ''),
      ('reason', '開放手動回報之原因（offline裝置離線／fault裝置故障／no_device未配對裝置）', 'VARCHAR(20)', '', '', ''),
      ('status', '處理狀態（pending待確認／confirmed已確認／rejected已駁回／cancelled已失效）', "ENUM('pending', 'confirmed', 'rejected', 'cancelled')", '', 'V', ''),
      ('pending_key', '待確認項目鍵（同一項目同時僅一筆待確認）', 'VARCHAR(40)', 'V', '', ''),
      ('held_on_sale', '取回待確認期間是否暫停販售', 'TINYINT(1)', '', 'V', ''), ('reviewed_by', '處理之管理員編號', 'INT', '', '', ''),
      ('reviewed_at', '處理時間', 'DATETIME', '', '', ''), ('review_note', '處理說明', 'VARCHAR(500)', '', '', ''),
      ('created_at', '建立時間', 'DATETIME', '', 'V', ''), ('updated_at', '更新時間', 'DATETIME', '', 'V', '')],
     ['cabinet_id　→　smart_cabinets.cabinet_id', 'user_id　→　users.user_id', 'order_id　→　orders.order_id', 'book_id　→　books.book_id']),
    ('cabinet_pair_requests', '書櫃裝置配對請求表', 'request_id', '記錄裝置申請之配對碼（有效10分鐘）；管理員輸入配對碼後綁定書櫃，裝置再以輪詢權杖領取裝置憑證，憑證僅交付一次',
     [('request_id', '配對請求編號', 'INT', 'V', 'V', ''), ('code_hash', '配對碼雜湊（SHA-256）', 'CHAR(64)', 'V', 'V', ''),
      ('poll_token_hash', '輪詢權杖雜湊（SHA-256）', 'CHAR(64)', 'V', 'V', ''),
      ('kind', '裝置種類（simulator模擬書櫃／esp32實體書櫃）', "ENUM('simulator', 'esp32')", '', 'V', ''),
      ('door_count', '櫃門數', 'TINYINT', '', 'V', ''), ('has_door_sensor', '是否裝有門磁感測器', 'TINYINT(1)', '', 'V', ''),
      ('unlock_pulse_ms', '電磁鎖開鎖通電時間（毫秒）', 'SMALLINT', '', 'V', ''), ('firmware', '韌體版本', 'VARCHAR(40)', '', 'V', ''),
      ('boot_id', '申請時之開機代碼', 'VARCHAR(16)', '', 'V', ''), ('ip', '申請來源IP位址', 'VARCHAR(45)', '', '', ''),
      ('cabinet_id', '綁定之書櫃編號', 'INT', '', '', 'V'), ('device_id', '綁定後建立之裝置編號', 'INT', '', '', ''),
      ('claimed_by', '輸入配對碼之管理員編號', 'INT', '', '', ''), ('claimed_at', '綁定時間', 'DATETIME', '', '', ''),
      ('delivered_at', '裝置憑證交付時間', 'DATETIME', '', '', ''), ('expires_at', '到期時間', 'DATETIME', '', 'V', ''),
      ('created_at', '建立時間', 'DATETIME', '', 'V', '')],
     ['cabinet_id　→　smart_cabinets.cabinet_id']),
    ('cabinet_session_doors', '書櫃作業櫃門表', 'session_id, slot_id', '記錄每次書櫃作業開啟之櫃門、開鎖指令送出時間與開關門時間',
     [('session_id', '書櫃作業編號', 'INT', 'V', 'V', 'V'), ('slot_id', '櫃門編號', 'INT', 'V', 'V', 'V'),
      ('lock_channel', '電磁鎖通道', 'TINYINT', '', 'V', ''),
      ('state', '櫃門狀態（pending待開啟／open已開啟／closed已關閉／failed未能開啟）', "ENUM('pending', 'open', 'closed', 'failed')", '', 'V', ''),
      ('command_served_at', '開鎖指令送出時間', 'DATETIME', '', '', ''), ('opened_at', '開門時間', 'DATETIME', '', '', ''),
      ('closed_at', '關門時間', 'DATETIME', '', '', ''),
      ('close_reason', '關門方式（user_done手機完成／timeout倒數結束／sensor門磁偵測）', 'VARCHAR(20)', '', '', '')],
     ['session_id　→　cabinet_sessions.session_id', 'slot_id　→　cabinet_slots.slot_id']),
    ('cabinet_session_items', '書櫃作業項目表', 'item_id', '記錄每次書櫃作業列出之取書、依訂單存書、先行存書與取回項目（每本書一筆）、所分配之櫃門與提交結果',
     [('item_id', '作業項目編號', 'INT', 'V', 'V', ''), ('session_id', '書櫃作業編號', 'INT', '', 'V', 'V'),
      ('kind', '項目種類（pickup取書／order_deposit依訂單存書／pre_deposit先行存書／retrieval取回）', "ENUM('pickup', 'order_deposit', 'pre_deposit', 'retrieval')", '', 'V', ''),
      ('order_id', '訂單編號（取書與依訂單存書）', 'INT', '', '', 'V'), ('book_id', '書籍編號', 'INT', '', 'V', 'V'),
      ('slot_id', '分配或存放之櫃門編號', 'INT', '', '', 'V'), ('selected', '是否選定辦理', 'TINYINT(1)', '', 'V', ''),
      ('held_on_sale', '取回期間是否暫停販售', 'TINYINT(1)', '', 'V', ''), ('blocked_code', '無法辦理原因代碼', 'VARCHAR(40)', '', '', ''),
      ('note_code', '提示代碼', 'VARCHAR(40)', '', '', ''),
      ('result', '處理結果（pending待處理／done完成／failed失敗／skipped略過）', "ENUM('pending', 'done', 'failed', 'skipped')", '', 'V', ''),
      ('error_code', '失敗原因代碼', 'VARCHAR(40)', '', '', '')],
     ['session_id　→　cabinet_sessions.session_id', 'order_id　→　orders.order_id', 'book_id　→　books.book_id', 'slot_id　→　cabinet_slots.slot_id']),
    ('cabinet_sessions', '書櫃作業表', 'session_id', '記錄使用者掃碼或管理員遠端開櫃之每一次書櫃作業（自掃碼至櫃門關閉），包含狀態、各階段期限、比對數字、與書櫃之距離、結束方式及管理員處理紀錄；不保存使用者座標',
     [('session_id', '書櫃作業編號', 'INT', 'V', 'V', ''), ('cabinet_id', '書櫃編號', 'INT', '', 'V', 'V'),
      ('device_id', '裝置編號', 'INT', '', 'V', 'V'), ('user_id', '發起之會員編號', 'INT', '', 'V', 'V'),
      ('kind', '作業種類（user使用者／admin管理員遠端開櫃）', "ENUM('user', 'admin')", '', 'V', ''),
      ('status', '作業狀態（selecting確認項目中／matching數字比對中／opening開門中／open櫃門已開啟／completed已完成／partial部分完成／cancelled已取消／failed失敗／expired逾時／needs_review待確認）',
       "ENUM('selecting', 'matching', 'opening', 'open', 'completed', 'partial', 'cancelled', 'failed', 'expired', 'needs_review')", '', 'V', ''),
      ('version', '版本號（狀態變更時遞增）', 'INT', '', 'V', ''), ('challenge_id', '兌換之挑戰碼編號', 'INT', 'V', '', ''),
      ('result_code', '結果代碼', 'VARCHAR(40)', '', '', ''), ('context_type', '掃碼入口種類（order訂單／book書籍）', 'VARCHAR(10)', '', '', ''),
      ('context_id', '掃碼入口之訂單或書籍編號', 'INT', '', '', ''),
      ('location_status', '定位狀態（granted已取得／denied拒絕／unavailable無法取得）', "ENUM('granted', 'denied', 'unavailable')", '', '', ''),
      ('distance_m', '與書櫃之距離（公尺）', 'INT', '', '', ''), ('accuracy_m', '定位精度（公尺）', 'INT', '', '', ''),
      ('match_code', '兩位數比對數字', 'TINYINT', '', '', ''), ('open_ms', '開門倒數長度（毫秒）', 'INT', '', '', ''),
      ('phase_deadline', '目前階段期限', 'DATETIME', '', '', ''), ('admin_reason', '遠端開櫃原因', 'VARCHAR(255)', '', '', ''),
      ('admin_force', '是否不經數字確認開啟', 'TINYINT(1)', '', 'V', ''),
      ('close_outcome', '關門結果（completed完成／cancelled取消）', 'VARCHAR(12)', '', '', ''),
      ('close_reason', '結束方式（user_done手機完成／user_cancel手機取消／timeout倒數結束／sensor門磁偵測／admin管理員確認已完成／admin_discard管理員確認未完成）', 'VARCHAR(20)', '', '', ''),
      ('close_request', '手機要求之結束方式（completed完成／cancelled取消）', 'VARCHAR(12)', '', '', ''),
      ('close_requested_at', '手機要求結束之時間', 'DATETIME', '', '', ''), ('close_refused_at', '書櫃因櫃門未關而拒絕結束之時間', 'DATETIME', '', '', ''),
      ('created_at', '建立時間', 'DATETIME', '', 'V', ''), ('started_at', '開始數字比對時間', 'DATETIME', '', '', ''),
      ('matched_at', '比對成功時間', 'DATETIME', '', '', ''), ('opened_at', '櫃門開啟時間', 'DATETIME', '', '', ''),
      ('closed_at', '關門回報時間', 'DATETIME', '', '', ''), ('finished_at', '作業結束時間', 'DATETIME', '', '', ''),
      ('reviewed_by', '處理之管理員編號', 'INT', '', '', ''), ('reviewed_at', '處理時間', 'DATETIME', '', '', ''),
      ('review_note', '處理說明', 'VARCHAR(500)', '', '', '')],
     ['cabinet_id　→　smart_cabinets.cabinet_id', 'device_id　→　cabinet_devices.device_id', 'user_id　→　users.user_id']),
    ('cabinet_slot_items', '櫃內書籍表', 'book_id', '記錄每本書目前實際存放之櫃門，為書籍實體位置之依據；存書作業櫃門關閉後寫入，取書或取回完成後刪除，管理員亦可登記或清空',
     [('book_id', '書籍編號', 'INT', 'V', 'V', 'V'), ('slot_id', '櫃門編號', 'INT', '', 'V', 'V'),
      ('cabinet_id', '書櫃編號', 'INT', '', 'V', ''), ('session_id', '寫入之書櫃作業編號', 'INT', '', '', 'V'),
      ('placed_by', '登記來源（session書櫃作業／admin管理員登記）', "ENUM('session', 'admin')", '', 'V', ''),
      ('placed_at', '放入時間', 'DATETIME', '', 'V', '')],
     ['book_id　→　books.book_id', 'slot_id　→　cabinet_slots.slot_id', 'session_id　→　cabinet_sessions.session_id']),
]

META = re.compile(r'^表 8-2-\d+ (\S+) ')

def meta_captions(doc):
    return [p for p in doc.paragraphs if p.style.name == 'Caption' and META.match(p.text.strip())]

def meta_of(T, name):
    return next(v._tbl for k, v in T.items() if META.match(k) and META.match(k).group(1) == name)

def build_table(template, name, cname, pk, desc, cols, fks):
    tbl = copy.deepcopy(template)
    rows = tbl.findall(W('tr'))
    set_cell(tcs(rows[0])[1], name); set_cell(tcs(rows[1])[1], cname)
    set_cell(tcs(rows[1])[3], pk); set_cell(tcs(rows[2])[1], desc)
    data_tpl = rows[4]
    fk_rows = [r for r in rows[4:] if len(tcs(r)) == 1]
    fk_head, fk_tpl = (fk_rows[0], fk_rows[1]) if len(fk_rows) >= 2 else (None, None)
    for r in rows[4:]: tbl.remove(r)
    for col in cols:
        tr = copy.deepcopy(data_tpl)
        for tc, v in zip(tcs(tr), col): set_cell(tc, v)
        tbl.append(tr)
    if fks:
        tbl.append(copy.deepcopy(fk_head))
        for fk in fks:
            tr = copy.deepcopy(fk_tpl); set_cell(tcs(tr)[0], fk); tbl.append(tr)
    return tbl


def add_rows(tbl, after, rows):
    anchor = row_by_key(tbl, after)
    for values in rows:
        anchor = clone_row_after(anchor)
        for tc, v in zip(tcs(anchor), values): set_cell(tc, v)


def set_rows(tbl, cols):
    for col, idx, text in cols:
        set_cell(tcs(row_by_key(tbl, col))[idx], text)


def set_desc(tbl, text):
    set_cell(tcs(tbl.findall(W('tr'))[2])[1], text)


def ai_batch34(T):
    """AI 改善（P3、P8–P14）新增之欄位與說明變更，依 dryM/savemybook_api/prisma/schema.prisma。"""
    t = meta_of(T, 'ai_book_reviews')
    set_desc(t, '記錄每本書最近一次上架審核之判定、把握度與人工複核狀態；AI審核通過或暫時放行時亦留下標記，暫時放行之書籍由排程每10分鐘補審')
    set_rows(t, [('verdict', 1, '判定結果（allow允許／review需人工確認／reject違規；暫時放行時為none）'),
                 ('status', 1, '審核狀態（pending待人工審核／approved已核准／rejected已駁回／passed AI審核通過／skipped暫時放行待補審）'),
                 ('status', 2, "ENUM('pending', 'approved', 'rejected', 'passed', 'skipped')"),
                 ('model', 1, '使用模型（規則送審時為rules）'),
                 ('created_at', 1, '判定時間（暫時放行時為上次嘗試時間）')])
    add_rows(t, 'reviewed_at', [
        ('skip_reason', '暫時放行原因（budget預算用盡／invalid_output輸出格式錯誤，或錯誤代碼）', 'VARCHAR(20)', '', '', ''),
        ('attempts', '補審失敗次數（僅計與書籍內容有關之失敗，達3次改送人工審核）', 'TINYINT', '', 'V', ''),
        ('ai_opinion', '規則送審之書籍於背景取得之AI判定（JSON，供管理員參考）', 'TEXT', '', '', ''),
        ('confidence', 'AI判定之把握度（0至1；規則送審時為空）', 'DECIMAL(4, 3)', '', '', ''),
        ('decision_reason', '管理員駁回時選擇之原因類別', 'VARCHAR(20)', '', '', '')])

    feedback = [('feedback', '使用者評價（helpful有幫助／unhelpful沒有幫助）', 'VARCHAR(10)', '', '', ''),
                ('feedback_reason', '評價為沒有幫助之原因代碼', 'VARCHAR(20)', '', '', ''),
                ('feedback_at', '評價時間', 'DATETIME', '', '', '')]
    add_rows(meta_of(T, 'ai_chat_messages'), 'book_ids', [
        ('meta', '助理回覆之處理資訊（JSON，含搜尋條件、處理路徑、候選書、推薦理由與追問建議，不含使用者原文；保存90日）', 'TEXT', '', '', '')] + feedback)
    add_rows(meta_of(T, 'ai_support_messages'), 'content', [
        ('meta', '助理回覆之處理資訊（JSON，含檢索依據、回答類型、轉接建議與追問建議，不含使用者原文；保存90日）', 'TEXT', '', '', '')] + feedback)

    add_rows(meta_of(T, 'ai_consents'), 'policy_version', [
        ('notice_version', '同意時App顯示之同意說明版本（0表示未記錄）', 'TINYINT', '', 'V', '')])

    add_rows(meta_of(T, 'ai_usage_logs'), 'error_detail', [
        ('request_id', '請求識別碼（串連同一次操作之多次呼叫）', 'VARCHAR(32)', '', '', ''),
        ('prompt_version', '提示詞版本（固定規則文字之雜湊）', 'VARCHAR(16)', '', '', ''),
        ('outcome', '處理結果（ok／repaired／degraded／empty／refused／failed；未送出請求時為not_sent）', 'VARCHAR(20)', '', '', ''),
        ('origin', '發起嵌入呼叫之功能（僅嵌入呼叫記錄）', 'VARCHAR(30)', '', '', ''),
        ('format_dropped', '輸出驗證時捨棄之清單項目數', 'SMALLINT', '', 'V', ''),
        ('format_defaulted', '輸出驗證時改用預設值之欄位數', 'SMALLINT', '', 'V', '')])

    add_rows(meta_of(T, 'faqs'), 'is_visible', [
        ('source_ticket_id', '來源客服工單編號（由AI客服轉接之工單建立時記錄）', 'INT', '', '', '')])
    add_rows(meta_of(T, 'support_tickets'), 'status', [
        ('from_ai_support', '是否由AI客服轉接建立', 'TINYINT(1)', '', 'V', '')])

    t = meta_of(T, 'recommendation_logs')
    set_desc(t, '記錄推薦書籍之曝光與點擊；同一來源6小時內每本書只記一次，點擊記在7日內最近一次曝光，紀錄保存90日')
    set_rows(t, [('created_at', 1, '曝光時間')])
    add_rows(t, 'rec_type', [('source', '推薦來源（ai AI推薦／rules規則式推薦）', 'VARCHAR(10)', '', 'V', '')])
    add_rows(t, 'is_clicked', [('clicked_at', '點擊時間', 'DATETIME', '', '', '')])


def prune_unused(doc):
    """系統未使用之資料表整張刪除；未使用之欄位刪除欄位列與對應之外鍵列。"""
    import schema_model
    from update_fk import SEP
    for p in meta_captions(doc):
        name = META.match(p.text.strip()).group(1)
        tbl = p._p.getnext()
        if name in schema_model.UNUSED_TABLES:
            tbl.getparent().remove(tbl)
            p._p.getparent().remove(p._p)
            continue
        for col in schema_model.UNUSED_COLUMNS.get(name, []):
            tbl.remove(row_by_key(tbl, col))
            for tr in list(tbl.findall(W('tr'))):
                if text_of(tcs(tr)[0]).strip().startswith(col + SEP):
                    tbl.remove(tr)


def run(doc):
    T = captioned_tables(doc)
    template = T['表 8-2-21 chat_messages 聊天訊息表']._tbl

    # smart_cabinets 補 is_maintenance
    sc = T['表 8-2-46 smart_cabinets 智慧書櫃據點表']._tbl
    active = row_by_key(sc, 'is_active')
    new = clone_row_after(active)
    for tc, v in zip(tcs(new), ['is_maintenance', '維修中（暫停存書與選用）', 'TINYINT(1)', '', 'V', '']): set_cell(tc, v)

    # order_items 補 pre_deposited
    oi = next(v._tbl for k, v in T.items() if META.match(k) and META.match(k).group(1) == 'order_items')
    new = clone_row_after(row_by_key(oi, 'subtotal'))
    for tc, v in zip(tcs(new), ['pre_deposited', '下單時是否已存放於書櫃', 'TINYINT(1)', '', 'V', '']): set_cell(tc, v)

    # 智慧書櫃：cabinet_slots 為櫃門，補電磁鎖通道、故障、待確認與門磁欄位
    cs = meta_of(T, 'cabinet_slots')
    rows = cs.findall(W('tr'))
    set_cell(tcs(rows[1])[1], '書櫃櫃門表')
    set_cell(tcs(rows[2])[1], '記錄智慧書櫃之櫃門及其狀態；對應電磁鎖通道者為可分配之櫃門，狀態由系統依存放內容判定，並記錄櫃門故障、待確認與門磁感測狀態')
    for col, text in [('slot_id', '櫃門編號'), ('cabinet_id', '所屬書櫃'), ('slot_number', '櫃門標籤（如A01）'),
                      ('status', '櫃門狀態（empty空門／occupied存放中／reserved作業保留／maintenance維修中）'),
                      ('current_book_id', '保留欄位（系統不寫入）'),
                      ('current_order_id', '保留欄位（系統不寫入）')]:
        set_cell(tcs(row_by_key(cs, col))[1], text)
    anchor_row = row_by_key(cs, 'updated_at')
    for values in [('lock_channel', '電磁鎖通道（1至4，對應櫃門A01至A04）', 'TINYINT', '', '', ''),
                   ('fault_code', '櫃門故障代碼', 'VARCHAR(40)', '', '', ''),
                   ('check_required_at', '待確認時間（門內內容可能與紀錄不符）', 'DATETIME', '', '', ''),
                   ('check_session_id', '觸發待確認之書櫃作業編號', 'INT', '', '', ''),
                   ('check_reason', '待確認原因', 'VARCHAR(40)', '', '', ''),
                   ('sensor_state', '門磁感測狀態（open開啟／closed關閉；未裝門磁者為空）', 'VARCHAR(10)', '', '', ''),
                   ('sensor_at', '門磁狀態回報時間', 'DATETIME', '', '', '')]:
        anchor_row = clone_row_after(anchor_row)
        for tc, v in zip(tcs(anchor_row), values): set_cell(tc, v)
    for p in meta_captions(doc):
        m = META.match(p.text.strip())
        if m.group(1) == 'cabinet_slots':
            set_para(p._p, p.text.strip().replace('書櫃格位表', '書櫃櫃門表'))
    for col, text in [('total_slots', '櫃門總數（依配對裝置之櫃門數）'), ('available_slots', '可用櫃門數（空門且無故障、未待確認）'),
                      ('is_maintenance', '維修中（暫停書櫃存取與選用）'), ('open_time', '營業開始時間（未設定表示全天營業）'),
                      ('close_time', '營業結束時間')]:
        set_cell(tcs(row_by_key(sc, col))[1], text)
    od = meta_of(T, 'orders')
    for col, text in [('slot_id', '主要櫃門編號（依訂單存書時為編號最小之櫃門）'),
                      ('pickup_code', '保留欄位（系統不寫入）'),
                      ('pickup_qr_code', '保留欄位（系統不寫入）'),
                      ('deposited_at', '存書完成時間'), ('picked_up_at', '買家取書時間（櫃門關閉後記錄）')]:
        set_cell(tcs(row_by_key(od, col))[1], text)

    # ai_consents 補 policy_version
    ac = meta_of(T, 'ai_consents')
    try:
        row_by_key(ac, 'policy_version')
    except KeyError:
        new = clone_row_after(row_by_key(ac, 'granted'))
        for tc, v in zip(tcs(new), ['policy_version', '同意時之隱私權政策版本（低於目前版本時視為未同意）', 'INT', '', 'V', '']): set_cell(tc, v)

    ai_batch34(T)

    # chat_room_members 補 group_nickname
    crm = next(v._tbl for k, v in T.items() if META.match(k) and META.match(k).group(1) == 'chat_room_members')
    new = clone_row_after(row_by_key(crm, 'history_from_id'))
    for tc, v in zip(tcs(new), ['group_nickname', '群組內暱稱', 'VARCHAR(30)', '', '', '']): set_cell(tc, v)

    cap_tpl = meta_captions(doc)[0]._p
    for name, cname, pk, desc, cols, fks in NEW_TABLES:
        caps = meta_captions(doc)
        names = [META.match(p.text.strip()).group(1) for p in caps]
        after = [p for p, n in zip(caps, names) if n > name]
        cap = copy.deepcopy(cap_tpl); set_para(cap, f'表 8-2-0 {name} {cname}')
        tbl = build_table(template, name, cname, pk, desc, cols, fks)
        if after:
            after[0]._p.addprevious(cap)
        else:
            last_tbl = caps[-1]._p.getnext()
            last_tbl.addnext(cap)
        cap.addnext(tbl)

    prune_unused(doc)

    # 重新編號：表名與表格內的「資料表編號」
    for i, p in enumerate(meta_captions(doc), start=1):
        m = META.match(p.text.strip())
        rest = p.text.strip()[m.end():]
        set_para(p._p, f'表 8-2-{i} {m.group(1)} {rest}')
        tbl = p._p.getnext()
        set_cell(tcs(tbl.findall(W('tr'))[0])[3], str(i))
    return len(meta_captions(doc))
