-- 006: 手機推播
--   mysql -u <帳號> -p <資料庫名稱> < migrations/006_push_notifications.sql
-- 可重複執行；不需要 prisma db pull。

CREATE TABLE IF NOT EXISTS push_devices (
  device_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id      INT UNSIGNED NOT NULL,
  token        VARCHAR(255) NOT NULL,
  platform     ENUM('ios', 'android') NOT NULL,
  app_version  VARCHAR(20) NULL DEFAULT NULL,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_seen_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (device_id),
  UNIQUE KEY uk_push_token (token),
  KEY idx_push_user (user_id),
  CONSTRAINT fk_push_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET @had_pushed_at := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'notifications' AND COLUMN_NAME = 'pushed_at');

SET @sql := IF(@had_pushed_at = 0,
  'ALTER TABLE notifications ADD COLUMN pushed_at DATETIME NULL DEFAULT NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 只在第一次加欄位時標成已推，否則會推出全部歷史通知；重跑時不可執行。
SET @sql := IF(@had_pushed_at = 0,
  'UPDATE notifications SET pushed_at = created_at WHERE pushed_at IS NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'notifications'
     AND INDEX_NAME = 'idx_notification_push_queue') = 0,
  'CREATE INDEX idx_notification_push_queue ON notifications (pushed_at, notification_id)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
