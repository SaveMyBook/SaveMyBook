-- 006: 手機推播
--
-- 執行方式（在 API 目錄下）：
--   mysql -u <帳號> -p <資料庫名稱> < migrations/006_push_notifications.sql
--
-- 這次不需要 prisma db pull：推播相關的查詢用原生 SQL，沒有新的 Prisma model。
-- 與 004、005 同樣可重複執行。

-- 每台裝置一列。同一支手機換帳號登入時，token 會轉給新帳號，不會兩個人都收到。
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

-- 推播佇列直接用 notifications 表：pushed_at 為 NULL 的就是還沒推出去的。
-- 通知是在交易裡寫入的，交易回滾時這一列根本不存在，不會推出一則實際沒發生的通知。
SET @had_pushed_at := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'notifications' AND COLUMN_NAME = 'pushed_at');

SET @sql := IF(@had_pushed_at = 0,
  'ALTER TABLE notifications ADD COLUMN pushed_at DATETIME NULL DEFAULT NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 只在第一次加欄位時把既有通知標成已推，否則上線瞬間會把歷史通知全部推一遍。
-- 重跑時不再執行，免得把剛寫入、還在佇列裡的通知吃掉。
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
