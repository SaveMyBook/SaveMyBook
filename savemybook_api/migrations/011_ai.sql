-- 011: AI 功能（設定、用量紀錄、AI 客服、推薦快取、上架審核、使用者同意）
--   mysql -u <帳號> -p <資料庫名稱> < migrations/011_ai.sql
-- 可重複執行；不需要 prisma db pull。新資料表皆以原生 SQL 存取。
-- API 金鑰只放在伺服器環境變數 DEEPSEEK_API_KEY、GEMINI_API_KEY、OPENAI_API_KEY，不會寫入資料庫。

CREATE TABLE IF NOT EXISTS ai_settings (
  id         TINYINT UNSIGNED NOT NULL,
  config     TEXT NOT NULL,
  updated_by INT UNSIGNED NULL DEFAULT NULL,
  updated_at DATETIME NOT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS ai_usage_logs (
  usage_id      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  feature       VARCHAR(30) NOT NULL,
  provider      VARCHAR(20) NOT NULL,
  model         VARCHAR(80) NOT NULL,
  user_id       INT UNSIGNED NULL DEFAULT NULL,
  input_tokens  INT UNSIGNED NOT NULL DEFAULT 0,
  cached_tokens INT UNSIGNED NOT NULL DEFAULT 0,
  output_tokens INT UNSIGNED NOT NULL DEFAULT 0,
  search_calls  INT UNSIGNED NOT NULL DEFAULT 0,
  cost_usd      DECIMAL(12,6) NOT NULL DEFAULT 0,
  latency_ms    INT UNSIGNED NOT NULL DEFAULT 0,
  status        ENUM('ok','error') NOT NULL,
  error_code    VARCHAR(60) NULL DEFAULT NULL,
  created_at    DATETIME NOT NULL,
  PRIMARY KEY (usage_id),
  KEY idx_ai_usage_created (created_at),
  KEY idx_ai_usage_feature (feature, created_at),
  KEY idx_ai_usage_user (user_id, feature, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS ai_support_sessions (
  session_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id    INT UNSIGNED NOT NULL,
  status     ENUM('open','closed','escalated') NOT NULL DEFAULT 'open',
  ticket_id  INT UNSIGNED NULL DEFAULT NULL,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  PRIMARY KEY (session_id),
  KEY idx_ai_session_user (user_id, status),
  CONSTRAINT fk_ai_session_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS ai_support_messages (
  message_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  session_id INT UNSIGNED NOT NULL,
  role       ENUM('user','assistant') NOT NULL,
  content    TEXT NOT NULL,
  created_at DATETIME NOT NULL,
  PRIMARY KEY (message_id),
  KEY idx_ai_message_session (session_id, message_id),
  CONSTRAINT fk_ai_message_session FOREIGN KEY (session_id) REFERENCES ai_support_sessions (session_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS ai_recommendation_cache (
  user_id    INT UNSIGNED NOT NULL,
  payload    TEXT NOT NULL,
  created_at DATETIME NOT NULL,
  PRIMARY KEY (user_id),
  CONSTRAINT fk_ai_rec_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS ai_book_reviews (
  book_id     INT UNSIGNED NOT NULL,
  verdict     VARCHAR(10) NOT NULL,
  reasons     TEXT NULL,
  categories  TEXT NULL,
  status      ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  provider    VARCHAR(20) NULL DEFAULT NULL,
  model       VARCHAR(80) NULL DEFAULT NULL,
  created_at  DATETIME NOT NULL,
  reviewed_by INT UNSIGNED NULL DEFAULT NULL,
  reviewed_at DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (book_id),
  KEY idx_ai_review_status (status, created_at),
  CONSTRAINT fk_ai_review_book FOREIGN KEY (book_id) REFERENCES books (book_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS ai_consents (
  user_id    INT UNSIGNED NOT NULL,
  granted    TINYINT(1) NOT NULL,
  updated_at DATETIME NOT NULL,
  PRIMARY KEY (user_id),
  CONSTRAINT fk_ai_consent_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 新資料表的 collation 必須與既有資料表一致，否則日後與既有字串欄位比較時會出現 1267 Illegal mix of collations。
SET @coll := (SELECT COLLATION_NAME FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'nickname');

SET @sql := IF(@coll IS NOT NULL AND @coll <> (SELECT TABLE_COLLATION FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ai_settings'),
  CONCAT('ALTER TABLE ai_settings CONVERT TO CHARACTER SET utf8mb4 COLLATE ', @coll), 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@coll IS NOT NULL AND @coll <> (SELECT TABLE_COLLATION FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ai_usage_logs'),
  CONCAT('ALTER TABLE ai_usage_logs CONVERT TO CHARACTER SET utf8mb4 COLLATE ', @coll), 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@coll IS NOT NULL AND @coll <> (SELECT TABLE_COLLATION FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ai_support_sessions'),
  CONCAT('ALTER TABLE ai_support_sessions CONVERT TO CHARACTER SET utf8mb4 COLLATE ', @coll), 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@coll IS NOT NULL AND @coll <> (SELECT TABLE_COLLATION FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ai_support_messages'),
  CONCAT('ALTER TABLE ai_support_messages CONVERT TO CHARACTER SET utf8mb4 COLLATE ', @coll), 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@coll IS NOT NULL AND @coll <> (SELECT TABLE_COLLATION FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ai_recommendation_cache'),
  CONCAT('ALTER TABLE ai_recommendation_cache CONVERT TO CHARACTER SET utf8mb4 COLLATE ', @coll), 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@coll IS NOT NULL AND @coll <> (SELECT TABLE_COLLATION FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ai_book_reviews'),
  CONCAT('ALTER TABLE ai_book_reviews CONVERT TO CHARACTER SET utf8mb4 COLLATE ', @coll), 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@coll IS NOT NULL AND @coll <> (SELECT TABLE_COLLATION FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ai_consents'),
  CONCAT('ALTER TABLE ai_consents CONVERT TO CHARACTER SET utf8mb4 COLLATE ', @coll), 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
