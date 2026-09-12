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
  SELECT 'admin_permissions', 'can_manage_system'
) t
LEFT JOIN information_schema.COLUMNS c
  ON c.TABLE_SCHEMA = DATABASE() AND c.TABLE_NAME = t.tbl AND c.COLUMN_NAME = t.want

UNION ALL

SELECT '索引', t.want,
       IF(s.INDEX_NAME IS NULL, '缺少', '已存在')
FROM (
  SELECT 'users' AS tbl, 'idx_deletion_requested' AS want UNION ALL
  SELECT 'users', 'uk_share_token' UNION ALL
  SELECT 'books', 'uk_book_share_token'
) t
LEFT JOIN information_schema.STATISTICS s
  ON s.TABLE_SCHEMA = DATABASE() AND s.TABLE_NAME = t.tbl AND s.INDEX_NAME = t.want

UNION ALL

SELECT '資料表', 'db_backups',
       IF(COUNT(*) = 0, '缺少', '已存在')
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'db_backups';
