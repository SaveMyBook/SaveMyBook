-- 022: 書籍資料自動補齊紀錄（賣家未填簡介、作者、出版社或出版日期時，依 ISBN 查詢書目並由 AI 整理簡介）
--   mysql -u <帳號> -p <資料庫名稱> < migrations/022_book_enrichment.sql
-- 可重複執行；不需要 prisma db pull。每本書只處理一次，status 為 none 代表查無資料或不需補齊。

CREATE TABLE IF NOT EXISTS ai_book_enrichments (
  book_id      INT UNSIGNED NOT NULL,
  status       VARCHAR(10) NOT NULL,
  fields       VARCHAR(200) NOT NULL DEFAULT '',
  ai_written   TINYINT(1) NOT NULL DEFAULT 0,
  attempted_at DATETIME NOT NULL,
  PRIMARY KEY (book_id),
  KEY idx_enrichment_status (status, attempted_at),
  CONSTRAINT fk_enrichment_book FOREIGN KEY (book_id) REFERENCES books (book_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
