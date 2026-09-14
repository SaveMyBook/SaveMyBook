-- 007: 法律文件同意、登入裝置、交易密碼
--   mysql -u <帳號> -p <資料庫名稱> < migrations/007_consent_sessions_payment.sql
-- 可重複執行；不需要 prisma db pull。

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'legal_documents' AND COLUMN_NAME = 'version') = 0,
  'ALTER TABLE legal_documents ADD COLUMN version INT UNSIGNED NOT NULL DEFAULT 1',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @had_requires := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'legal_documents' AND COLUMN_NAME = 'requires_consent');

SET @sql := IF(@had_requires = 0,
  'ALTER TABLE legal_documents ADD COLUMN requires_consent TINYINT(1) NOT NULL DEFAULT 0',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@had_requires = 0,
  'UPDATE legal_documents SET requires_consent = 1 WHERE doc_key IN (''terms'', ''privacy'')',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS user_legal_consents (
  user_id     INT UNSIGNED NOT NULL,
  doc_key     VARCHAR(50) NOT NULL,
  version     INT UNSIGNED NOT NULL,
  accepted_at DATETIME NOT NULL,
  PRIMARY KEY (user_id, doc_key),
  CONSTRAINT fk_consent_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS user_sessions (
  session_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id      INT UNSIGNED NOT NULL,
  sid          CHAR(32) NOT NULL,
  device_id    VARCHAR(64) NULL DEFAULT NULL,
  device_name  VARCHAR(100) NULL DEFAULT NULL,
  platform     VARCHAR(20) NULL DEFAULT NULL,
  app_version  VARCHAR(20) NULL DEFAULT NULL,
  ip_address   VARCHAR(45) NULL DEFAULT NULL,
  pay_key_hash CHAR(64) NULL DEFAULT NULL,
  created_at   DATETIME NOT NULL,
  last_seen_at DATETIME NOT NULL,
  revoked_at   DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (session_id),
  UNIQUE KEY uk_session_sid (sid),
  KEY idx_session_user (user_id, revoked_at),
  CONSTRAINT fk_session_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS user_security (
  user_id            INT UNSIGNED NOT NULL,
  payment_pin_hash   VARCHAR(255) NULL DEFAULT NULL,
  pin_failed_count   INT UNSIGNED NOT NULL DEFAULT 0,
  pin_locked_until   DATETIME NULL DEFAULT NULL,
  pin_updated_at     DATETIME NULL DEFAULT NULL,
  tokens_valid_after DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (user_id),
  CONSTRAINT fk_security_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.TABLES
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'push_devices') = 1
  AND (SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'push_devices' AND COLUMN_NAME = 'session_sid') = 0,
  'ALTER TABLE push_devices ADD COLUMN session_sid CHAR(32) NULL DEFAULT NULL, ADD KEY idx_push_session (session_sid)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 新資料表的 collation 必須與既有資料表一致，否則字串比較會出現 1267 Illegal mix of collations。
SET @coll := (SELECT COLLATION_NAME FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'legal_documents' AND COLUMN_NAME = 'doc_key');

SET @sql := IF(@coll IS NOT NULL AND @coll <> (SELECT COLLATION_NAME FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'user_legal_consents' AND COLUMN_NAME = 'doc_key'),
  CONCAT('ALTER TABLE user_legal_consents CONVERT TO CHARACTER SET utf8mb4 COLLATE ', @coll),
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@coll IS NOT NULL AND @coll <> (SELECT COLLATION_NAME FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'user_sessions' AND COLUMN_NAME = 'sid'),
  CONCAT('ALTER TABLE user_sessions CONVERT TO CHARACTER SET utf8mb4 COLLATE ', @coll),
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@coll IS NOT NULL AND @coll <> (SELECT COLLATION_NAME FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'user_security' AND COLUMN_NAME = 'payment_pin_hash'),
  CONCAT('ALTER TABLE user_security CONVERT TO CHARACTER SET utf8mb4 COLLATE ', @coll),
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
