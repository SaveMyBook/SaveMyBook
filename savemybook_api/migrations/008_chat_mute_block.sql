-- 008: 聊天室靜音、封鎖使用者、回覆訊息
--   mysql -u <帳號> -p <資料庫名稱> < migrations/008_chat_mute_block.sql
-- 可重複執行；不需要 prisma db pull。

CREATE TABLE IF NOT EXISTS chat_room_mutes (
  user_id    INT UNSIGNED NOT NULL,
  room_id    INT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL,
  PRIMARY KEY (user_id, room_id),
  KEY idx_mute_room (room_id),
  CONSTRAINT fk_mute_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE,
  CONSTRAINT fk_mute_room FOREIGN KEY (room_id) REFERENCES chat_rooms (room_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS user_blocks (
  blocker_id INT UNSIGNED NOT NULL,
  blocked_id INT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL,
  PRIMARY KEY (blocker_id, blocked_id),
  KEY idx_block_blocked (blocked_id),
  CONSTRAINT fk_block_blocker FOREIGN KEY (blocker_id) REFERENCES users (user_id) ON DELETE CASCADE,
  CONSTRAINT fk_block_blocked FOREIGN KEY (blocked_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'chat_messages' AND COLUMN_NAME = 'reply_to_id') = 0,
  'ALTER TABLE chat_messages ADD COLUMN reply_to_id INT UNSIGNED NULL DEFAULT NULL, ADD KEY idx_msg_reply (reply_to_id)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
