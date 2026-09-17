-- 018: 群組暱稱（群組內所有成員看到相同的暱稱；一對一聊天的暱稱仍只有設定者本人看得到）
--   mysql -u <帳號> -p <資料庫名稱> < migrations/018_chat_group_nickname.sql
-- 可重複執行；不需要 prisma db pull。

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'chat_room_members' AND COLUMN_NAME = 'group_nickname') = 0,
  'ALTER TABLE chat_room_members ADD COLUMN group_nickname VARCHAR(30) NULL DEFAULT NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
