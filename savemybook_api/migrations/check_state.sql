-- 看目前資料庫實際到哪一步。純查詢，不會改任何東西。
--   mysql -u <帳號> -p <資料庫名稱> < migrations/check_state.sql

SELECT VERSION() AS db_version, DATABASE() AS db_name;

SELECT '欄位' AS 類別, t.want AS 名稱,
       IF(c.COLUMN_NAME IS NULL, '缺少', '已存在') AS 狀態
FROM (
  SELECT 'users' AS tbl, 'deletion_requested_at' AS want UNION ALL
  SELECT 'users', 'anonymized_at' UNION ALL
  SELECT 'users', 'share_token' UNION ALL
  SELECT 'books', 'share_token' UNION ALL
  SELECT 'admin_permissions', 'can_manage_system' UNION ALL
  SELECT 'notifications', 'pushed_at' UNION ALL
  SELECT 'legal_documents', 'version' UNION ALL
  SELECT 'legal_documents', 'requires_consent' UNION ALL
  SELECT 'push_devices', 'session_sid' UNION ALL
  SELECT 'chat_rooms', 'room_type' UNION ALL
  SELECT 'chat_rooms', 'name' UNION ALL
  SELECT 'chat_rooms', 'avatar_url' UNION ALL
  SELECT 'chat_rooms', 'created_by' UNION ALL
  SELECT 'chat_messages', 'edited_at' UNION ALL
  SELECT 'notifications', 'actor_id' UNION ALL
  SELECT 'chat_room_members', 'history_from_id' UNION ALL
  SELECT 'chat_messages', 'mentions'
) t
LEFT JOIN information_schema.COLUMNS c
  ON c.TABLE_SCHEMA = DATABASE() AND c.TABLE_NAME = t.tbl AND c.COLUMN_NAME = t.want

UNION ALL

SELECT '索引', t.want,
       IF(s.INDEX_NAME IS NULL, '缺少', '已存在')
FROM (
  SELECT 'users' AS tbl, 'idx_deletion_requested' AS want UNION ALL
  SELECT 'users', 'uk_share_token' UNION ALL
  SELECT 'books', 'uk_book_share_token' UNION ALL
  SELECT 'notifications', 'idx_notification_push_queue'
) t
LEFT JOIN information_schema.STATISTICS s
  ON s.TABLE_SCHEMA = DATABASE() AND s.TABLE_NAME = t.tbl AND s.INDEX_NAME = t.want

UNION ALL

SELECT '資料表', 'db_backups',
       IF(COUNT(*) = 0, '缺少', '已存在')
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'db_backups'

UNION ALL

SELECT '資料表', 'push_devices',
       IF(COUNT(*) = 0, '缺少', '已存在')
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'push_devices'

UNION ALL

SELECT '資料表', 'user_legal_consents',
       IF(COUNT(*) = 0, '缺少', '已存在')
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'user_legal_consents'

UNION ALL

SELECT '資料表', 'user_sessions',
       IF(COUNT(*) = 0, '缺少', '已存在')
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'user_sessions'

UNION ALL

SELECT '資料表', 'user_security',
       IF(COUNT(*) = 0, '缺少', '已存在')
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'user_security'

UNION ALL

SELECT '資料表', 'chat_room_mutes',
       IF(COUNT(*) = 0, '缺少', '已存在')
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'chat_room_mutes'

UNION ALL

SELECT '資料表', 'user_blocks',
       IF(COUNT(*) = 0, '缺少', '已存在')
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'user_blocks'

UNION ALL

SELECT '欄位', 'chat_messages.reply_to_id',
       IF(COUNT(*) = 0, '缺少', '已存在')
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'chat_messages' AND COLUMN_NAME = 'reply_to_id'

UNION ALL

SELECT '資料表', 'chat_room_members',
       IF(COUNT(*) = 0, '缺少', '已存在')
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'chat_room_members'

UNION ALL

SELECT '資料表', 'chat_room_pins',
       IF(COUNT(*) = 0, '缺少', '已存在')
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'chat_room_pins'

UNION ALL

SELECT '資料表', 'chat_aliases',
       IF(COUNT(*) = 0, '缺少', '已存在')
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'chat_aliases'

UNION ALL

SELECT '資料表', 'chat_transfers',
       IF(COUNT(*) = 0, '缺少', '已存在')
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'chat_transfers'

UNION ALL

SELECT '列舉值', 'wallet_transactions.type 含 transfer_in',
       IF(COUNT(*) = 0, '缺少', '已存在')
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'wallet_transactions' AND COLUMN_NAME = 'type'
  AND COLUMN_TYPE LIKE '%''transfer_in''%'

UNION ALL

SELECT '資料表', 'chat_mentions',
       IF(COUNT(*) = 0, '缺少', '已存在')
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'chat_mentions'

UNION ALL

SELECT '資料表', 'ai_settings',
       IF(COUNT(*) = 0, '缺少', '已存在')
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ai_settings'

UNION ALL

SELECT '資料表', 'ai_usage_logs',
       IF(COUNT(*) = 0, '缺少', '已存在')
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ai_usage_logs'

UNION ALL

SELECT '資料表', 'ai_support_sessions',
       IF(COUNT(*) = 0, '缺少', '已存在')
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ai_support_sessions'

UNION ALL

SELECT '資料表', 'ai_support_messages',
       IF(COUNT(*) = 0, '缺少', '已存在')
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ai_support_messages'

UNION ALL

SELECT '資料表', 'ai_recommendation_cache',
       IF(COUNT(*) = 0, '缺少', '已存在')
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ai_recommendation_cache'

UNION ALL

SELECT '資料表', 'ai_book_reviews',
       IF(COUNT(*) = 0, '缺少', '已存在')
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ai_book_reviews'

UNION ALL

SELECT '資料表', 'ai_consents',
       IF(COUNT(*) = 0, '缺少', '已存在')
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ai_consents'

UNION ALL

SELECT '欄位', 'ai_usage_logs.error_detail',
       IF(COUNT(*) = 0, '缺少', '已存在')
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ai_usage_logs' AND COLUMN_NAME = 'error_detail';
