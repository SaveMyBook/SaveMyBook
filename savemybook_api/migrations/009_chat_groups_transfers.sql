-- 009: 群組聊天、釘選、自訂暱稱、編輯訊息、代幣轉帳與請款、通知觸發者
--   mysql -u <帳號> -p <資料庫名稱> < migrations/009_chat_groups_transfers.sql
--   npx prisma db pull && npx prisma generate
-- 可重複執行。新資料表與欄位皆以原生 SQL 存取，但 wallet_transactions.type 新增 transfer_in、transfer_out，
-- 必須重新產生 Prisma Client 並重新啟動 API，否則轉帳端點會回傳 503 CHAT_V2_UNAVAILABLE。
-- 須先 db pull：版本庫內的 prisma/schema.prisma 未包含 004、005 新增的欄位，直接 generate 會使帳號刪除與分享功能失效。
-- 若在舊版程式仍運作時先執行本檔，新版啟動後請再執行一次，以補齊期間新建的一對一聊天室成員。

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'chat_rooms' AND COLUMN_NAME = 'room_type') = 0,
  'ALTER TABLE chat_rooms ADD COLUMN room_type ENUM(''direct'',''group'') NOT NULL DEFAULT ''direct''',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'chat_rooms' AND COLUMN_NAME = 'name') = 0,
  'ALTER TABLE chat_rooms ADD COLUMN name VARCHAR(50) NULL DEFAULT NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'chat_rooms' AND COLUMN_NAME = 'avatar_url') = 0,
  'ALTER TABLE chat_rooms ADD COLUMN avatar_url VARCHAR(500) NULL DEFAULT NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'chat_rooms' AND COLUMN_NAME = 'created_by') = 0,
  'ALTER TABLE chat_rooms ADD COLUMN created_by INT UNSIGNED NULL DEFAULT NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'chat_messages' AND COLUMN_NAME = 'edited_at') = 0,
  'ALTER TABLE chat_messages ADD COLUMN edited_at DATETIME NULL DEFAULT NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'notifications' AND COLUMN_NAME = 'actor_id') = 0,
  'ALTER TABLE notifications ADD COLUMN actor_id INT UNSIGNED NULL DEFAULT NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 以現有定義組出 MODIFY，保留既有的列舉值、NULL 設定與欄位註解。
SET @sql := (SELECT IF(COLUMN_TYPE LIKE '%''transfer_in''%', 'SELECT 1',
    CONCAT('ALTER TABLE wallet_transactions MODIFY COLUMN type ',
      LEFT(COLUMN_TYPE, CHAR_LENGTH(COLUMN_TYPE) - 1), ',''transfer_in'',''transfer_out'')',
      IF(IS_NULLABLE = 'NO', ' NOT NULL', ' NULL'),
      IF(COLUMN_COMMENT <> '', CONCAT(' COMMENT ', QUOTE(COLUMN_COMMENT)), '')))
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'wallet_transactions' AND COLUMN_NAME = 'type');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS chat_room_members (
  room_id              INT UNSIGNED NOT NULL,
  user_id              INT UNSIGNED NOT NULL,
  role                 ENUM('owner','member') NOT NULL DEFAULT 'member',
  joined_at            DATETIME NOT NULL,
  left_at              DATETIME NULL DEFAULT NULL,
  last_read_message_id INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (room_id, user_id),
  KEY idx_member_user (user_id),
  CONSTRAINT fk_member_room FOREIGN KEY (room_id) REFERENCES chat_rooms (room_id) ON DELETE CASCADE,
  CONSTRAINT fk_member_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS chat_room_pins (
  user_id   INT UNSIGNED NOT NULL,
  room_id   INT UNSIGNED NOT NULL,
  pinned_at DATETIME NOT NULL,
  PRIMARY KEY (user_id, room_id),
  KEY idx_pin_room (room_id),
  CONSTRAINT fk_pin_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE,
  CONSTRAINT fk_pin_room FOREIGN KEY (room_id) REFERENCES chat_rooms (room_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS chat_aliases (
  owner_id       INT UNSIGNED NOT NULL,
  target_user_id INT UNSIGNED NOT NULL,
  alias          VARCHAR(30) NOT NULL,
  updated_at     DATETIME NOT NULL,
  PRIMARY KEY (owner_id, target_user_id),
  KEY idx_alias_target (target_user_id),
  CONSTRAINT fk_alias_owner FOREIGN KEY (owner_id) REFERENCES users (user_id) ON DELETE CASCADE,
  CONSTRAINT fk_alias_target FOREIGN KEY (target_user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 不對 chat_rooms 設外鍵：刪除一對一聊天室時，轉帳紀錄屬帳務資料，必須保留。
CREATE TABLE IF NOT EXISTS chat_transfers (
  transfer_id  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  room_id      INT UNSIGNED NOT NULL,
  message_id   INT UNSIGNED NULL DEFAULT NULL,
  kind         ENUM('transfer','request') NOT NULL,
  from_user_id INT UNSIGNED NOT NULL,
  to_user_id   INT UNSIGNED NOT NULL,
  amount       DECIMAL(12,2) NOT NULL,
  note         VARCHAR(100) NULL DEFAULT NULL,
  status       ENUM('completed','pending','declined','cancelled','expired') NOT NULL,
  created_at   DATETIME NOT NULL,
  responded_at DATETIME NULL DEFAULT NULL,
  expires_at   DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (transfer_id),
  KEY idx_transfer_room (room_id, transfer_id),
  KEY idx_transfer_pending (status, expires_at),
  CONSTRAINT fk_transfer_from FOREIGN KEY (from_user_id) REFERENCES users (user_id),
  CONSTRAINT fk_transfer_to FOREIGN KEY (to_user_id) REFERENCES users (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 新資料表的 collation 必須與既有資料表一致，否則字串比較會出現 1267 Illegal mix of collations。
SET @coll := (SELECT COLLATION_NAME FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'nickname');

SET @sql := IF(@coll IS NOT NULL AND @coll <> (SELECT COLLATION_NAME FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'chat_room_members' AND COLUMN_NAME = 'role'),
  CONCAT('ALTER TABLE chat_room_members CONVERT TO CHARACTER SET utf8mb4 COLLATE ', @coll),
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@coll IS NOT NULL AND @coll <> (SELECT COLLATION_NAME FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'chat_aliases' AND COLUMN_NAME = 'alias'),
  CONCAT('ALTER TABLE chat_aliases CONVERT TO CHARACTER SET utf8mb4 COLLATE ', @coll),
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@coll IS NOT NULL AND @coll <> (SELECT COLLATION_NAME FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'chat_transfers' AND COLUMN_NAME = 'note'),
  CONCAT('ALTER TABLE chat_transfers CONVERT TO CHARACTER SET utf8mb4 COLLATE ', @coll),
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

INSERT IGNORE INTO chat_room_members (room_id, user_id, role, joined_at, last_read_message_id)
SELECT room_id, user_a_id, 'member', created_at, 0 FROM chat_rooms
WHERE room_type = 'direct' AND user_a_id <> user_b_id;

INSERT IGNORE INTO chat_room_members (room_id, user_id, role, joined_at, last_read_message_id)
SELECT room_id, user_b_id, 'member', created_at, 0 FROM chat_rooms
WHERE room_type = 'direct' AND user_a_id <> user_b_id;
