-- 019: 書櫃維修中狀態（整台書櫃暫停存書，但仍保留在後台與既有訂單中；與「停用」不同，維修完成即可恢復）
--   mysql -u <帳號> -p <資料庫名稱> < migrations/019_cabinet_maintenance.sql
-- 可重複執行；不需要 prisma db pull（程式以原生 SQL 讀寫此欄位，未執行前後台會提示需要此 migration）。

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'smart_cabinets' AND COLUMN_NAME = 'is_maintenance') = 0,
  'ALTER TABLE smart_cabinets ADD COLUMN is_maintenance TINYINT(1) NOT NULL DEFAULT 0 COMMENT ''維修中：暫停存書與選用'' AFTER is_active',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
