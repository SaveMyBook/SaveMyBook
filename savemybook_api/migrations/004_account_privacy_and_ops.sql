-- 004: 帳號刪除、分享連結權杖、資料庫備份紀錄
--
-- 執行方式（在 API 目錄下）：
--   mysql -u <帳號> -p <資料庫名稱> < migrations/004_account_privacy_and_ops.sql
--   npx prisma db pull && npx prisma generate

-- ---------- 排程刪除帳號 ----------
-- deletion_requested_at 不為 null 代表使用者已申請刪除，30 天內登入可取消。
-- 逾期由排程匿名化：清掉個資、帳號停用，但訂單與交易紀錄保留，
-- 否則對方的購買紀錄會憑空出現破洞。
ALTER TABLE users
  ADD COLUMN deletion_requested_at DATETIME NULL DEFAULT NULL AFTER bonus_points,
  ADD COLUMN anonymized_at DATETIME NULL DEFAULT NULL AFTER deletion_requested_at;

CREATE INDEX idx_deletion_requested ON users (deletion_requested_at);

-- ---------- 分享連結權杖 ----------
-- 個人分享頁原本是 /u/<user_id>，可以直接從 1 枚舉到 N 把全站使用者掃出來。
-- 改用隨機權杖，並保留重新產生的能力（連結外流時可作廢）。
ALTER TABLE users
  ADD COLUMN share_token CHAR(32) NULL DEFAULT NULL AFTER anonymized_at;

CREATE UNIQUE INDEX uk_share_token ON users (share_token);

-- ---------- 資料庫備份紀錄 ----------
CREATE TABLE IF NOT EXISTS db_backups (
  backup_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  file_name   VARCHAR(255) NOT NULL,
  size_bytes  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  trigger_by  VARCHAR(20)  NOT NULL DEFAULT 'schedule',
  admin_id    INT UNSIGNED NULL,
  status      VARCHAR(20)  NOT NULL DEFAULT 'success',
  detail      TEXT NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (backup_id),
  UNIQUE KEY uk_backup_file (file_name),
  KEY idx_backup_time (created_at),
  CONSTRAINT fk_backup_admin FOREIGN KEY (admin_id) REFERENCES users (user_id)
    ON DELETE SET NULL ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 權杖不在 SQL 產生：UUID() 是時間與 MAC 推導出來的，可以被推測。
-- 改由 API 用 crypto.randomBytes 於首次存取時補上。

-- ---------- 系統維運權限 ----------
-- 備份檔含全站個資，不能讓任何管理員都下載得到，所以獨立一個開關。
-- 既有管理員預設關閉，要由人明確開啟。
ALTER TABLE admin_permissions
  ADD COLUMN can_manage_system BOOLEAN NOT NULL DEFAULT FALSE AFTER can_manage_support;
