-- 016: 通行密鑰（Passkey / WebAuthn）登入與身分驗證
--   mysql -u <帳號> -p <資料庫名稱> < migrations/016_passkeys.sql
-- 可重複執行；不需要 prisma db pull。兩張資料表皆以原生 SQL 存取，不必重新產生 Prisma Client。
-- RP ID、RP 名稱與允許的來源只放在伺服器環境變數（PASSKEY_RP_ID、PASSKEY_RP_NAME、PASSKEY_ORIGINS）。

CREATE TABLE IF NOT EXISTS user_passkeys (
  passkey_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id       INT UNSIGNED NOT NULL,
  credential_id VARCHAR(255) NOT NULL,
  public_key    TEXT NOT NULL,
  sign_count    INT UNSIGNED NOT NULL DEFAULT 0,
  transports    VARCHAR(100) NULL DEFAULT NULL,
  aaguid        CHAR(36) NULL DEFAULT NULL,
  backed_up     TINYINT(1) NOT NULL DEFAULT 0,
  device_label  VARCHAR(50) NULL DEFAULT NULL,
  created_at    DATETIME NOT NULL,
  last_used_at  DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (passkey_id),
  UNIQUE KEY uk_credential (credential_id),
  KEY idx_passkey_user (user_id),
  CONSTRAINT fk_passkey_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS webauthn_challenges (
  challenge  CHAR(64) NOT NULL,
  user_id    INT UNSIGNED NULL DEFAULT NULL,
  purpose    ENUM('register','login','verify') NOT NULL,
  created_at DATETIME NOT NULL,
  PRIMARY KEY (challenge),
  KEY idx_challenge_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 新資料表的 collation 必須與既有資料表一致，否則字串比較會出現 1267 Illegal mix of collations。
SET @coll := (SELECT COLLATION_NAME FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'nickname');

SET @sql := IF(@coll IS NOT NULL AND @coll <> (SELECT TABLE_COLLATION FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'user_passkeys'),
  CONCAT('ALTER TABLE user_passkeys CONVERT TO CHARACTER SET utf8mb4 COLLATE ', @coll),
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@coll IS NOT NULL AND @coll <> (SELECT TABLE_COLLATION FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'webauthn_challenges'),
  CONCAT('ALTER TABLE webauthn_challenges CONVERT TO CHARACTER SET utf8mb4 COLLATE ', @coll),
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
