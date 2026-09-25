-- 023: 聊天防詐風險紀錄與管理員警示佇列，並於隱私權政策補充聊天訊息的防詐檢查說明
--   mysql -u <帳號> -p <資料庫名稱> < migrations/023_chat_risk.sql
-- 可重複執行；不需要 prisma db pull。未執行前聊天仍會依訊息內容提醒，但不計入帳號因素，也不會產生管理員警示。

CREATE TABLE IF NOT EXISTS chat_message_risks (
  message_id INT UNSIGNED NOT NULL,
  room_id    INT UNSIGNED NOT NULL,
  sender_id  INT UNSIGNED NOT NULL,
  level      VARCHAR(10) NOT NULL,
  categories VARCHAR(100) NOT NULL,
  score      TINYINT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL,
  PRIMARY KEY (message_id),
  KEY idx_risk_room (room_id, level),
  KEY idx_risk_sender (sender_id, level, created_at),
  CONSTRAINT fk_risk_message FOREIGN KEY (message_id) REFERENCES chat_messages (message_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS chat_risk_alerts (
  alert_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id    INT UNSIGNED NOT NULL,
  status     VARCHAR(10) NOT NULL,
  hit_count  INT UNSIGNED NOT NULL,
  first_at   DATETIME NOT NULL,
  last_at    DATETIME NOT NULL,
  handled_by INT UNSIGNED NULL DEFAULT NULL,
  handled_at DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (alert_id),
  KEY idx_alert_status (status, last_at),
  KEY idx_alert_user (user_id, status),
  CONSTRAINT fk_alert_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

UPDATE legal_documents
SET content = REPLACE(content,
      '服務改善與統計分析，以及依法令要求之用途。',
      '服務改善與統計分析，以及依法令要求之用途。\n為防範詐騙，本平台會以自動化規則檢查聊天訊息是否含有私下交易、索取驗證碼或常見詐騙話術等風險特徵，並向收訊方顯示提醒；判定為高風險之訊息將保存判定結果，並得由具權限之管理人員檢視相關訊息，以決定是否限制帳號。此項檢查不使用 AI 服務，亦不會將訊息內容提供予第三方。'),
    version = version + 1,
    requires_consent = 1,
    updated_at = NOW()
WHERE doc_key = 'privacy' AND content NOT LIKE '%防範詐騙%';

SELECT
  version AS '隱私權政策版本',
  IF(content LIKE '%防範詐騙%', '已包含聊天防詐說明', '未找到原句，請至後台手動補上') AS '聊天防詐說明'
FROM legal_documents WHERE doc_key = 'privacy';
