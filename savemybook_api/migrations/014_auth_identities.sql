-- 014: 社群登入與簡訊驗證（第三方身分、登入方式設定、OAuth 暫存資料）
--   mysql -u <帳號> -p <資料庫名稱> < migrations/014_auth_identities.sql
-- 可重複執行；不需要 prisma db pull。新資料表皆以原生 SQL 存取，
-- users.password_set 也以原生 SQL 讀寫，因此不必重新產生 Prisma Client。
-- 各渠道的憑證只放在伺服器環境變數（LINE_CHANNEL_ID、LINE_CHANNEL_SECRET、
-- DISCORD_CLIENT_ID、DISCORD_CLIENT_SECRET），不會寫入資料庫。

CREATE TABLE IF NOT EXISTS user_identities (
  identity_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id       INT UNSIGNED NOT NULL,
  provider      ENUM('google','apple','phone','line','discord') NOT NULL,
  subject       VARCHAR(191) NOT NULL,
  email         VARCHAR(255) NULL DEFAULT NULL,
  phone         VARCHAR(20) NULL DEFAULT NULL,
  display_name  VARCHAR(100) NULL DEFAULT NULL,
  created_at    DATETIME NOT NULL,
  last_login_at DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (identity_id),
  UNIQUE KEY uk_identity (provider, subject),
  KEY idx_identity_user (user_id),
  CONSTRAINT fk_identity_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS auth_settings (
  id         TINYINT UNSIGNED NOT NULL,
  config     TEXT NOT NULL,
  updated_by INT UNSIGNED NULL DEFAULT NULL,
  updated_at DATETIME NOT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS oauth_states (
  state      CHAR(32) NOT NULL,
  provider   VARCHAR(20) NOT NULL,
  mode       ENUM('login','link') NOT NULL DEFAULT 'login',
  user_id    INT UNSIGNED NULL DEFAULT NULL,
  created_at DATETIME NOT NULL,
  PRIMARY KEY (state),
  KEY idx_oauth_state_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS oauth_results (
  code       CHAR(32) NOT NULL,
  payload    TEXT NOT NULL,
  created_at DATETIME NOT NULL,
  PRIMARY KEY (code),
  KEY idx_oauth_result_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 既有帳號都是以密碼註冊，一律視為已設定密碼。
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'password_set') = 0,
  'ALTER TABLE users ADD COLUMN password_set TINYINT(1) NOT NULL DEFAULT 1',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'login_logs' AND COLUMN_NAME = 'login_method') = 0,
  'ALTER TABLE login_logs ADD COLUMN login_method VARCHAR(20) NULL DEFAULT NULL AFTER device_info',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 新資料表的 collation 必須與既有資料表一致，否則字串比較會出現 1267 Illegal mix of collations。
SET @coll := (SELECT COLLATION_NAME FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'nickname');

SET @sql := IF(@coll IS NOT NULL AND @coll <> (SELECT TABLE_COLLATION FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'user_identities'),
  CONCAT('ALTER TABLE user_identities CONVERT TO CHARACTER SET utf8mb4 COLLATE ', @coll),
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@coll IS NOT NULL AND @coll <> (SELECT TABLE_COLLATION FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'auth_settings'),
  CONCAT('ALTER TABLE auth_settings CONVERT TO CHARACTER SET utf8mb4 COLLATE ', @coll),
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@coll IS NOT NULL AND @coll <> (SELECT TABLE_COLLATION FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'oauth_states'),
  CONCAT('ALTER TABLE oauth_states CONVERT TO CHARACTER SET utf8mb4 COLLATE ', @coll),
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@coll IS NOT NULL AND @coll <> (SELECT TABLE_COLLATION FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'oauth_results'),
  CONCAT('ALTER TABLE oauth_results CONVERT TO CHARACTER SET utf8mb4 COLLATE ', @coll),
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
