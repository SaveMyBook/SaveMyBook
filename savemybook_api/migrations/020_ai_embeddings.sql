-- 020: AI 語意檢索的向量索引（書籍顧問、個人推薦、AI 客服共用）
--   mysql -u <帳號> -p <資料庫名稱> < migrations/020_ai_embeddings.sql
-- 可重複執行；不需要 prisma db pull。向量由伺服器自動建立與更新，執行後不需要手動匯入資料。
-- vector 為 Float32 陣列的 Base64，model 同時記錄向量模型與維度，更換模型時會自動重建。

CREATE TABLE IF NOT EXISTS ai_embeddings (
  kind         VARCHAR(20) NOT NULL,
  ref_id       VARCHAR(64) NOT NULL,
  model        VARCHAR(100) NOT NULL,
  content_hash CHAR(64) NOT NULL,
  vector       MEDIUMTEXT NOT NULL,
  updated_at   DATETIME NOT NULL,
  PRIMARY KEY (kind, ref_id),
  KEY idx_ai_embedding_model (kind, model)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
