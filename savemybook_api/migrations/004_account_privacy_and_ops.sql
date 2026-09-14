-- 004: 帳號刪除、分享連結權杖、資料庫備份紀錄
--   mysql -u <帳號> -p <資料庫名稱> < migrations/004_account_privacy_and_ops.sql
--   npx prisma db pull && npx prisma generate
-- 可重複執行：DDL 不在交易中，每步先查 information_schema；不用 ADD COLUMN IF NOT EXISTS（MySQL 8 不支援）。

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users'
     AND COLUMN_NAME = 'deletion_requested_at') = 0,
  'ALTER TABLE users ADD COLUMN deletion_requested_at DATETIME NULL DEFAULT NULL AFTER bonus_points',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users'
     AND COLUMN_NAME = 'anonymized_at') = 0,
  'ALTER TABLE users ADD COLUMN anonymized_at DATETIME NULL DEFAULT NULL AFTER deletion_requested_at',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users'
     AND INDEX_NAME = 'idx_deletion_requested') = 0,
  'CREATE INDEX idx_deletion_requested ON users (deletion_requested_at)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users'
     AND COLUMN_NAME = 'share_token') = 0,
  'ALTER TABLE users ADD COLUMN share_token CHAR(32) NULL DEFAULT NULL AFTER anonymized_at',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users'
     AND INDEX_NAME = 'uk_share_token') = 0,
  'CREATE UNIQUE INDEX uk_share_token ON users (share_token)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'admin_permissions'
     AND COLUMN_NAME = 'can_manage_system') = 0,
  'ALTER TABLE admin_permissions ADD COLUMN can_manage_system BOOLEAN NOT NULL DEFAULT FALSE AFTER can_manage_support',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS db_backups (
  backup_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  file_name   VARCHAR(255) NOT NULL,
  size_bytes  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  trigger_by  VARCHAR(20)  NOT NULL DEFAULT 'schedule',
  admin_id    INT UNSIGNED NULL,
  status      VARCHAR(20)  NOT NULL DEFAULT 'success',
  detail      TEXT NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (backup_id),
  UNIQUE KEY uk_backup_file (file_name),
  KEY idx_backup_time (created_at),
  CONSTRAINT fk_backup_admin FOREIGN KEY (admin_id) REFERENCES users (user_id)
    ON DELETE SET NULL ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- share_token 不可用 UUID() 產生（可被推測），由 API 以 crypto.randomBytes 補上。
