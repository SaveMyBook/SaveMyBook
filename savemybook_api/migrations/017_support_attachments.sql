-- 017: 客服工單圖片附件
--   mysql -u <帳號> -p <資料庫名稱> < migrations/017_support_attachments.sql
-- 可重複執行；不需要 prisma db pull。資料表以原生 SQL 存取，不必重新產生 Prisma Client。
-- 未執行前工單照常運作，只是無法上傳或顯示附件。

CREATE TABLE IF NOT EXISTS support_ticket_attachments (
  attachment_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  message_id    INT UNSIGNED NULL DEFAULT NULL,
  uploader_id   INT UNSIGNED NOT NULL,
  url           VARCHAR(255) NOT NULL,
  byte_size     INT UNSIGNED NOT NULL DEFAULT 0,
  sort_order    TINYINT UNSIGNED NOT NULL DEFAULT 0,
  created_at    DATETIME NOT NULL,
  PRIMARY KEY (attachment_id),
  UNIQUE KEY uk_support_attachment_url (url),
  KEY idx_support_attachment_message (message_id, sort_order),
  KEY idx_support_attachment_pending (uploader_id, message_id, created_at),
  CONSTRAINT fk_support_attachment_message FOREIGN KEY (message_id)
    REFERENCES support_ticket_messages (message_id) ON DELETE CASCADE,
  CONSTRAINT fk_support_attachment_uploader FOREIGN KEY (uploader_id)
    REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 新資料表的 collation 必須與既有資料表一致，否則字串比較會出現 1267 Illegal mix of collations。
SET @coll := (SELECT COLLATION_NAME FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'nickname');

SET @sql := IF(@coll IS NOT NULL AND @coll <> (SELECT TABLE_COLLATION FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'support_ticket_attachments'),
  CONCAT('ALTER TABLE support_ticket_attachments CONVERT TO CHARACTER SET utf8mb4 COLLATE ', @coll),
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
