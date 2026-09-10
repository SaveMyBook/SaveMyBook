-- SaveMyBook 追加：細部管理權限、法律文件、常見問題、客服工單
-- 全部都是新增，不會動到既有資料。

ALTER TABLE admin_permissions
  ADD COLUMN can_manage_orders   TINYINT(1) NOT NULL DEFAULT 1,
  ADD COLUMN can_manage_wallets  TINYINT(1) NOT NULL DEFAULT 1,
  ADD COLUMN can_manage_levels   TINYINT(1) NOT NULL DEFAULT 1,
  ADD COLUMN can_view_stats      TINYINT(1) NOT NULL DEFAULT 1,
  ADD COLUMN can_manage_support  TINYINT(1) NOT NULL DEFAULT 1;

CREATE TABLE IF NOT EXISTS legal_documents (
  doc_id     INT UNSIGNED NOT NULL AUTO_INCREMENT,
  doc_key    VARCHAR(50)  NOT NULL,
  title      VARCHAR(255) NOT NULL,
  content    TEXT         NOT NULL,
  updated_by INT UNSIGNED NULL,
  updated_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (doc_id),
  UNIQUE KEY uk_legal_key (doc_key),
  KEY fk_legal_admin (updated_by),
  CONSTRAINT fk_legal_admin FOREIGN KEY (updated_by) REFERENCES users (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS faqs (
  faq_id     INT UNSIGNED NOT NULL AUTO_INCREMENT,
  category   VARCHAR(50)  NOT NULL DEFAULT 'general',
  question   VARCHAR(255) NOT NULL,
  answer     TEXT         NOT NULL,
  sort_order INT          NOT NULL DEFAULT 0,
  is_visible TINYINT(1)   NOT NULL DEFAULT 1,
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (faq_id),
  KEY idx_faq_order (category, sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS support_tickets (
  ticket_id  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id    INT UNSIGNED NOT NULL,
  subject    VARCHAR(255) NOT NULL,
  category   VARCHAR(50)  NOT NULL DEFAULT 'other',
  status     ENUM('open','pending','resolved','closed') NOT NULL DEFAULT 'open',
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  closed_at  DATETIME     NULL,
  PRIMARY KEY (ticket_id),
  KEY idx_ticket_user (user_id, updated_at),
  KEY idx_ticket_status (status, updated_at),
  CONSTRAINT fk_ticket_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS support_ticket_messages (
  message_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  ticket_id  INT UNSIGNED NOT NULL,
  sender_id  INT UNSIGNED NOT NULL,
  is_staff   TINYINT(1)   NOT NULL DEFAULT 0,
  content    TEXT         NOT NULL,
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (message_id),
  KEY idx_tmsg_ticket (ticket_id, created_at),
  KEY fk_tmsg_sender (sender_id),
  CONSTRAINT fk_tmsg_ticket FOREIGN KEY (ticket_id) REFERENCES support_tickets (ticket_id) ON DELETE CASCADE,
  CONSTRAINT fk_tmsg_sender FOREIGN KEY (sender_id) REFERENCES users (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 預設文件與幾則常見問題，讓畫面一開始就不是空的
INSERT IGNORE INTO legal_documents (doc_key, title, content) VALUES
  ('terms',   '服務條款',   '請由管理後台編輯服務條款內容。'),
  ('privacy', '隱私權政策', '請由管理後台編輯隱私權政策內容。'),
  ('about',   '關於我們',   'SaveMyBook 是一個結合智慧書櫃的二手書交易平台。');

INSERT IGNORE INTO faqs (faq_id, category, question, answer, sort_order) VALUES
  (1, 'trade',   '書賣出後要多久存書？', '訂單成立後請於七天內把書放入指定書櫃，逾期訂單會自動取消並退款給買家。', 0),
  (2, 'trade',   '買家沒有取書怎麼辦？', '超過取書期限的訂單會自動取消，書籍會恢復上架，代幣退回買家帳戶。', 1),
  (3, 'wallet',  '代幣要怎麼取得？',     '完成銷售後款項會撥入代幣餘額，也可以由客服協助儲值。', 0),
  (4, 'account', '忘記密碼怎麼辦？',     '請至登入頁點選「忘記密碼」，或透過「聯絡我們」開立工單由客服協助。', 0);
