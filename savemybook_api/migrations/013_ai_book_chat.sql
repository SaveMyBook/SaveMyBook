-- 013: AI 書籍顧問聊天（對話與訊息）
--   mysql -u <帳號> -p <資料庫名稱> < migrations/013_ai_book_chat.sql
-- 可重複執行；不需要 prisma db pull。新資料表皆以原生 SQL 存取。
-- 須先執行 011_ai.sql。

CREATE TABLE IF NOT EXISTS ai_chat_sessions (
  session_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id    INT UNSIGNED NOT NULL,
  status     ENUM('open','closed') NOT NULL DEFAULT 'open',
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  PRIMARY KEY (session_id),
  KEY idx_ai_chat_session_user (user_id, status),
  CONSTRAINT fk_ai_chat_session_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS ai_chat_messages (
  message_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  session_id INT UNSIGNED NOT NULL,
  role       ENUM('user','assistant') NOT NULL,
  content    TEXT NOT NULL,
  book_ids   VARCHAR(255) NULL DEFAULT NULL,
  created_at DATETIME NOT NULL,
  PRIMARY KEY (message_id),
  KEY idx_ai_chat_message_session (session_id, message_id),
  CONSTRAINT fk_ai_chat_message_session FOREIGN KEY (session_id) REFERENCES ai_chat_sessions (session_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 新資料表的 collation 必須與既有資料表一致，否則日後與既有字串欄位比較時會出現 1267 Illegal mix of collations。
SET @coll := (SELECT COLLATION_NAME FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'nickname');

SET @sql := IF(@coll IS NOT NULL AND @coll <> (SELECT TABLE_COLLATION FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ai_chat_sessions'),
  CONCAT('ALTER TABLE ai_chat_sessions CONVERT TO CHARACTER SET utf8mb4 COLLATE ', @coll), 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@coll IS NOT NULL AND @coll <> (SELECT TABLE_COLLATION FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ai_chat_messages'),
  CONCAT('ALTER TABLE ai_chat_messages CONVERT TO CHARACTER SET utf8mb4 COLLATE ', @coll), 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
