-- 010: 群組歷史訊息可見範圍、提及成員（@）
--   mysql -u <帳號> -p <資料庫名稱> < migrations/010_chat_mentions_albums.sql
-- 可重複執行；不需要 prisma db pull。相簿訊息不需要資料庫變更。
-- 若在舊版程式仍運作時先執行本檔，新版啟動後請再執行一次，以補齊期間加入群組的成員可見範圍。

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'chat_room_members' AND COLUMN_NAME = 'history_from_id') = 0,
  'ALTER TABLE chat_room_members ADD COLUMN history_from_id INT UNSIGNED NOT NULL DEFAULT 0',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'chat_messages' AND COLUMN_NAME = 'mentions') = 0,
  'ALTER TABLE chat_messages ADD COLUMN mentions TEXT NULL DEFAULT NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS chat_mentions (
  message_id INT UNSIGNED NOT NULL,
  room_id    INT UNSIGNED NOT NULL,
  user_id    INT UNSIGNED NOT NULL,
  PRIMARY KEY (message_id, user_id),
  KEY idx_mention_user_room (user_id, room_id, message_id),
  CONSTRAINT fk_mention_message FOREIGN KEY (message_id) REFERENCES chat_messages (message_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 新資料表的 collation 必須與既有資料表一致，否則日後新增字串欄位時會出現 1267 Illegal mix of collations。
SET @coll := (SELECT COLLATION_NAME FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'nickname');

SET @sql := IF(@coll IS NOT NULL AND @coll <> (SELECT TABLE_COLLATION FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'chat_mentions'),
  CONCAT('ALTER TABLE chat_mentions CONVERT TO CHARACTER SET utf8mb4 COLLATE ', @coll),
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 既有群組成員：可見範圍自加入時間起的第一則訊息（即邀請或建立群組的系統訊息）。
UPDATE chat_room_members m
JOIN chat_rooms r ON r.room_id = m.room_id AND r.room_type = 'group'
SET m.history_from_id = COALESCE((
  SELECT MIN(x.message_id) FROM chat_messages x
  WHERE x.room_id = m.room_id AND x.created_at >= m.joined_at - INTERVAL 1 SECOND
), 0)
WHERE m.history_from_id = 0;
