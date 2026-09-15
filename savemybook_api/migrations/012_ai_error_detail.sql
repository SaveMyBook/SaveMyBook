-- 012: AI 用量紀錄保存服務商回傳的錯誤說明，供管理員排查連線與額度問題
--   mysql -u <帳號> -p <資料庫名稱> < migrations/012_ai_error_detail.sql
-- 可重複執行；未執行時 API 照常運作，僅不保存錯誤說明。

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.TABLES
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ai_usage_logs') = 1
  AND (SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ai_usage_logs' AND COLUMN_NAME = 'error_detail') = 0,
  'ALTER TABLE ai_usage_logs ADD COLUMN error_detail VARCHAR(400) NULL DEFAULT NULL AFTER error_code',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
