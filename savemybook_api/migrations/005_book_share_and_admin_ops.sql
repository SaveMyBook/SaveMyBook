-- 005: 書籍分享權杖
--   mysql -u <帳號> -p <資料庫名稱> < migrations/005_book_share_and_admin_ops.sql
--   npx prisma db pull && npx prisma generate

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'books'
     AND COLUMN_NAME = 'share_token') = 0,
  'ALTER TABLE books ADD COLUMN share_token CHAR(32) NULL DEFAULT NULL AFTER is_approved',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'books'
     AND INDEX_NAME = 'uk_book_share_token') = 0,
  'CREATE UNIQUE INDEX uk_book_share_token ON books (share_token)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
