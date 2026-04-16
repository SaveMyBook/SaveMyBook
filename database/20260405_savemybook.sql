-- phpMyAdmin SQL Dump
-- version 5.2.1deb3
-- https://www.phpmyadmin.net/
--
-- 主機： localhost:3306
-- 產生時間： 2026 年 04 月 04 日 22:15
-- 伺服器版本： 8.0.45-0ubuntu0.24.04.1
-- PHP 版本： 8.3.6

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- 資料庫： `savemybook`
--
CREATE DATABASE IF NOT EXISTS `savemybook` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE `savemybook`;

-- --------------------------------------------------------

--
-- 資料表結構 `achievements`
--

CREATE TABLE IF NOT EXISTS `achievements` (
  `achievement_id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `achievement_name` varchar(100) NOT NULL,
  `description` text,
  `icon_url` varchar(500) DEFAULT NULL,
  `condition_type` varchar(50) NOT NULL COMMENT '達成條件類型',
  `condition_value` int NOT NULL COMMENT '達成條件數值',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`achievement_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='成就定義表';

-- --------------------------------------------------------

--
-- 資料表結構 `admin_operation_logs`
--

CREATE TABLE IF NOT EXISTS `admin_operation_logs` (
  `log_id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `admin_id` int UNSIGNED NOT NULL,
  `action` varchar(100) NOT NULL COMMENT '操作動作',
  `target_type` varchar(50) DEFAULT NULL COMMENT '操作對象類型',
  `target_id` int UNSIGNED DEFAULT NULL COMMENT '操作對象ID',
  `detail` text COMMENT '操作詳情',
  `ip_address` varchar(45) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`log_id`),
  KEY `idx_admin_time` (`admin_id`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='後台操作日誌表';

-- --------------------------------------------------------

--
-- 資料表結構 `admin_permissions`
--

CREATE TABLE IF NOT EXISTS `admin_permissions` (
  `admin_perm_id` int UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '權限編號',
  `user_id` int UNSIGNED NOT NULL COMMENT '管理員的會員編號',
  `can_manage_transactions` tinyint(1) NOT NULL DEFAULT '1' COMMENT '交易仲裁權限',
  `can_manage_members` tinyint(1) NOT NULL DEFAULT '1' COMMENT '會員管控權限',
  `can_manage_content` tinyint(1) NOT NULL DEFAULT '1' COMMENT '內容審核權限',
  `can_manage_reports` tinyint(1) NOT NULL DEFAULT '1' COMMENT '檢舉處理權限',
  `can_manage_announcements` tinyint(1) NOT NULL DEFAULT '1' COMMENT '系統公告權限',
  `can_manage_cabinets` tinyint(1) NOT NULL DEFAULT '1' COMMENT '智慧書櫃管理權限',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`admin_perm_id`),
  UNIQUE KEY `uk_admin_user` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='後台管理員權限表（僅四位組員）';

--
-- 傾印資料表的資料 `admin_permissions`
--

INSERT INTO `admin_permissions` (`admin_perm_id`, `user_id`, `can_manage_transactions`, `can_manage_members`, `can_manage_content`, `can_manage_reports`, `can_manage_announcements`, `can_manage_cabinets`, `created_at`) VALUES
(1, 1, 1, 1, 1, 1, 1, 1, '2026-03-25 01:14:16'),
(2, 2, 1, 1, 1, 1, 1, 1, '2026-03-25 01:14:16'),
(3, 3, 1, 1, 1, 1, 1, 1, '2026-03-25 01:14:16'),
(4, 4, 1, 1, 1, 1, 1, 1, '2026-03-25 01:14:16');

-- --------------------------------------------------------

--
-- 資料表結構 `bankbooks`
--

CREATE TABLE IF NOT EXISTS `bankbooks` (
  `bankbook_id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` int UNSIGNED NOT NULL,
  `bank_name` varchar(100) DEFAULT NULL COMMENT '銀行名稱',
  `account_number` varchar(30) DEFAULT NULL COMMENT '帳號（加密儲存）',
  `qr_code_url` varchar(500) DEFAULT NULL COMMENT '存摺存者QR Code',
  `is_verified` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否已驗證',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`bankbook_id`),
  KEY `idx_user` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='存摺管理表';

-- --------------------------------------------------------

--
-- 資料表結構 `books`
--

CREATE TABLE IF NOT EXISTS `books` (
  `book_id` int UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '書籍商品編號',
  `seller_id` int UNSIGNED NOT NULL COMMENT '賣家會員編號',
  `isbn` varchar(13) DEFAULT NULL COMMENT 'ISBN碼',
  `title` varchar(255) NOT NULL COMMENT '書名',
  `author` varchar(255) DEFAULT NULL COMMENT '作者',
  `publisher` varchar(255) DEFAULT NULL COMMENT '出版社',
  `publish_date` varchar(20) DEFAULT NULL COMMENT '出版年月',
  `category_id` int UNSIGNED DEFAULT NULL COMMENT '書籍分類',
  `condition_level` enum('like_new','good','fair','poor') NOT NULL DEFAULT 'good' COMMENT '書況等級',
  `condition_note` text COMMENT '書籍狀況描述',
  `price` decimal(10,2) NOT NULL COMMENT '售價',
  `quantity` int UNSIGNED NOT NULL DEFAULT '1' COMMENT '數量',
  `description` text COMMENT '商品描述',
  `cabinet_id` int UNSIGNED DEFAULT NULL COMMENT '指定存放的智慧書櫃',
  `status` enum('on_sale','reserved','sold','removed') NOT NULL DEFAULT 'on_sale' COMMENT '商品狀態',
  `view_count` int UNSIGNED NOT NULL DEFAULT '0' COMMENT '瀏覽次數',
  `is_approved` tinyint(1) NOT NULL DEFAULT '1' COMMENT '後台審核狀態',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '上架時間',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`book_id`),
  KEY `idx_seller` (`seller_id`),
  KEY `idx_isbn` (`isbn`),
  KEY `idx_category` (`category_id`),
  KEY `idx_cabinet` (`cabinet_id`),
  KEY `idx_status` (`status`),
  KEY `idx_created` (`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='書籍商品表（交易方式：智慧書櫃取書）';

--
-- 傾印資料表的資料 `books`
--

INSERT INTO `books` (`book_id`, `seller_id`, `isbn`, `title`, `author`, `publisher`, `publish_date`, `category_id`, `condition_level`, `condition_note`, `price`, `quantity`, `description`, `cabinet_id`, `status`, `view_count`, `is_approved`, `created_at`, `updated_at`) VALUES
(1, 7, '9789862767425', '深入淺出 Node.js', '朴靈', NULL, NULL, NULL, 'good', NULL, 350.00, 1, '九成新，內頁無劃線筆記。', NULL, 'on_sale', 0, 1, '2026-04-02 08:58:56', '2026-04-02 08:58:56');

-- --------------------------------------------------------

--
-- 資料表結構 `book_categories`
--

CREATE TABLE IF NOT EXISTS `book_categories` (
  `category_id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `category_name` varchar(50) NOT NULL COMMENT '分類名稱（人文社會、專業資訊、藝術設計等）',
  `parent_id` int UNSIGNED DEFAULT NULL COMMENT '上層分類編號（支援子分類）',
  `sort_order` int NOT NULL DEFAULT '0' COMMENT '排序順序',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`category_id`),
  KEY `idx_parent` (`parent_id`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='書籍分類表';

--
-- 傾印資料表的資料 `book_categories`
--

INSERT INTO `book_categories` (`category_id`, `category_name`, `parent_id`, `sort_order`, `created_at`) VALUES
(1, '人文社會', NULL, 1, '2026-03-25 01:05:44'),
(2, '專業資訊', NULL, 2, '2026-03-25 01:05:44'),
(3, '藝術設計', NULL, 3, '2026-03-25 01:05:44'),
(4, '商業管理', NULL, 4, '2026-03-25 01:05:44'),
(5, '自然科學', NULL, 5, '2026-03-25 01:05:44'),
(6, '語言學習', NULL, 6, '2026-03-25 01:05:44'),
(7, '考試用書', NULL, 7, '2026-03-25 01:05:44'),
(8, '文學小說', NULL, 8, '2026-03-25 01:05:44'),
(9, '生活休閒', NULL, 9, '2026-03-25 01:05:44'),
(10, '其他', NULL, 99, '2026-03-25 01:05:44');

-- --------------------------------------------------------

--
-- 資料表結構 `book_images`
--

CREATE TABLE IF NOT EXISTS `book_images` (
  `image_id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `book_id` int UNSIGNED NOT NULL,
  `image_url` varchar(500) NOT NULL COMMENT '圖片路徑',
  `image_type` enum('cover','back','inside','other') NOT NULL DEFAULT 'other' COMMENT '圖片類型',
  `sort_order` int NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`image_id`),
  KEY `idx_book_images` (`book_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='書籍圖片表（2NF拆分）';

-- --------------------------------------------------------

--
-- 資料表結構 `cabinet_slots`
--

CREATE TABLE IF NOT EXISTS `cabinet_slots` (
  `slot_id` int UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '格位編號',
  `cabinet_id` int UNSIGNED NOT NULL COMMENT '所屬書櫃',
  `slot_number` varchar(10) NOT NULL COMMENT '格位號碼（如 A1, B3）',
  `status` enum('empty','occupied','reserved','maintenance') NOT NULL DEFAULT 'empty' COMMENT '格位狀態',
  `current_book_id` int UNSIGNED DEFAULT NULL COMMENT '目前存放的書籍',
  `current_order_id` int UNSIGNED DEFAULT NULL COMMENT '關聯的訂單編號',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`slot_id`),
  UNIQUE KEY `uk_cabinet_slot` (`cabinet_id`,`slot_number`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='書櫃格位表（2NF拆分）';

-- --------------------------------------------------------

--
-- 資料表結構 `chat_messages`
--

CREATE TABLE IF NOT EXISTS `chat_messages` (
  `message_id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `room_id` int UNSIGNED NOT NULL,
  `sender_id` int UNSIGNED NOT NULL,
  `content` text NOT NULL,
  `message_type` enum('text','image','system') NOT NULL DEFAULT 'text',
  `is_read` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`message_id`),
  KEY `idx_room_time` (`room_id`,`created_at`),
  KEY `fk_msg_sender` (`sender_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='聊天訊息表';

-- --------------------------------------------------------

--
-- 資料表結構 `chat_rooms`
--

CREATE TABLE IF NOT EXISTS `chat_rooms` (
  `room_id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_a_id` int UNSIGNED NOT NULL COMMENT '對話方A',
  `user_b_id` int UNSIGNED NOT NULL COMMENT '對話方B',
  `book_id` int UNSIGNED DEFAULT NULL COMMENT '關聯書籍（可選）',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`room_id`),
  UNIQUE KEY `uk_chat_pair` (`user_a_id`,`user_b_id`,`book_id`),
  KEY `fk_chat_user_b` (`user_b_id`),
  KEY `fk_chat_book` (`book_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='聊天室表';

-- --------------------------------------------------------

--
-- 資料表結構 `content_reviews`
--

CREATE TABLE IF NOT EXISTS `content_reviews` (
  `review_id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `content_type` enum('book','message','user_profile') NOT NULL COMMENT '審核內容類型',
  `content_id` int UNSIGNED NOT NULL COMMENT '對應內容ID',
  `status` enum('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  `admin_id` int UNSIGNED DEFAULT NULL,
  `review_note` text,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `reviewed_at` datetime DEFAULT NULL,
  PRIMARY KEY (`review_id`),
  KEY `idx_status_type` (`status`,`content_type`),
  KEY `fk_content_admin` (`admin_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='內容審核表（後台管理 > 違規商品處理 / 違規下架）';

-- --------------------------------------------------------

--
-- 資料表結構 `favorites`
--

CREATE TABLE IF NOT EXISTS `favorites` (
  `favorite_id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` int UNSIGNED NOT NULL,
  `book_id` int UNSIGNED NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`favorite_id`),
  UNIQUE KEY `uk_user_book` (`user_id`,`book_id`),
  KEY `fk_fav_book` (`book_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='收藏清單表';

-- --------------------------------------------------------

--
-- 資料表結構 `login_logs`
--

CREATE TABLE IF NOT EXISTS `login_logs` (
  `log_id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` int UNSIGNED NOT NULL,
  `login_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `ip_address` varchar(45) DEFAULT NULL COMMENT '登入IP',
  `device_info` varchar(255) DEFAULT NULL COMMENT '裝置資訊',
  PRIMARY KEY (`log_id`),
  KEY `idx_user_login` (`user_id`,`login_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='登入紀錄表';

-- --------------------------------------------------------

--
-- 資料表結構 `member_levels`
--

CREATE TABLE IF NOT EXISTS `member_levels` (
  `level_id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `level_name` varchar(50) NOT NULL COMMENT '等級名稱',
  `min_points` int NOT NULL COMMENT '最低積分',
  `max_points` int DEFAULT NULL COMMENT '最高積分',
  `benefits` text COMMENT '等級權益描述',
  PRIMARY KEY (`level_id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='會員等級定義表';

--
-- 傾印資料表的資料 `member_levels`
--

INSERT INTO `member_levels` (`level_id`, `level_name`, `min_points`, `max_points`, `benefits`) VALUES
(1, '新手書友', 0, 99, '基本交易功能'),
(2, '活躍書友', 100, 499, '享有推薦曝光加成'),
(3, '資深書友', 500, 1999, '享有交易手續費折扣'),
(4, '菁英書友', 2000, NULL, '享有全部VIP權益');

-- --------------------------------------------------------

--
-- 資料表結構 `notifications`
--

CREATE TABLE IF NOT EXISTS `notifications` (
  `notification_id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` int UNSIGNED NOT NULL COMMENT '接收者',
  `type` enum('system','order','message','promotion','reservation') NOT NULL COMMENT '通知類型',
  `title` varchar(255) NOT NULL COMMENT '通知標題',
  `content` text NOT NULL COMMENT '通知內容',
  `related_id` int UNSIGNED DEFAULT NULL COMMENT '關聯資源ID（訂單ID / 書籍ID等）',
  `related_type` varchar(50) DEFAULT NULL COMMENT '關聯資源類型',
  `is_read` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否已讀',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`notification_id`),
  KEY `idx_user_read` (`user_id`,`is_read`),
  KEY `idx_user_time` (`user_id`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='推播通知表';

-- --------------------------------------------------------

--
-- 資料表結構 `orders`
--

CREATE TABLE IF NOT EXISTS `orders` (
  `order_id` int UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '訂單編號',
  `order_no` varchar(30) NOT NULL COMMENT '訂單號碼（顯示用）',
  `buyer_id` int UNSIGNED NOT NULL COMMENT '買家會員編號',
  `seller_id` int UNSIGNED NOT NULL COMMENT '賣家會員編號',
  `total_amount` decimal(10,2) NOT NULL COMMENT '訂單總金額',
  `cabinet_id` int UNSIGNED DEFAULT NULL COMMENT '取書智慧書櫃',
  `slot_id` int UNSIGNED DEFAULT NULL COMMENT '書櫃格位編號',
  `pickup_code` varchar(20) DEFAULT NULL COMMENT '取書驗證碼',
  `pickup_qr_code` varchar(500) DEFAULT NULL COMMENT '取書QR Code路徑',
  `status` enum('pending_payment','pending_deposit','deposited','pending_pickup','completed','cancelled','refunding','refunded') NOT NULL DEFAULT 'pending_payment' COMMENT '訂單狀態：待付款/待賣家放書/已放入書櫃/待買家取書/已完成/已取消/退款中/已退款',
  `payment_method` enum('wallet','bank_transfer') DEFAULT NULL COMMENT '付款方式',
  `payment_at` datetime DEFAULT NULL COMMENT '付款時間',
  `deposited_at` datetime DEFAULT NULL COMMENT '賣家放入書櫃時間',
  `picked_up_at` datetime DEFAULT NULL COMMENT '買家取書時間',
  `completed_at` datetime DEFAULT NULL COMMENT '訂單完成時間',
  `cancelled_at` datetime DEFAULT NULL COMMENT '取消時間',
  `cancel_reason` text COMMENT '取消原因',
  `note` text COMMENT '訂單備註',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`order_id`),
  UNIQUE KEY `uk_order_no` (`order_no`),
  KEY `idx_buyer` (`buyer_id`),
  KEY `idx_seller` (`seller_id`),
  KEY `idx_cabinet` (`cabinet_id`),
  KEY `idx_status` (`status`),
  KEY `idx_created` (`created_at`),
  KEY `fk_order_slot` (`slot_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='訂單主表（智慧書櫃取書流程）';

-- --------------------------------------------------------

--
-- 資料表結構 `order_items`
--

CREATE TABLE IF NOT EXISTS `order_items` (
  `item_id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `order_id` int UNSIGNED NOT NULL,
  `book_id` int UNSIGNED NOT NULL,
  `quantity` int UNSIGNED NOT NULL DEFAULT '1',
  `unit_price` decimal(10,2) NOT NULL COMMENT '成交單價',
  `subtotal` decimal(10,2) NOT NULL COMMENT '小計',
  PRIMARY KEY (`item_id`),
  KEY `idx_order` (`order_id`),
  KEY `idx_book` (`book_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='訂單明細表（2NF拆分）';

-- --------------------------------------------------------

--
-- 資料表結構 `recommendation_logs`
--

CREATE TABLE IF NOT EXISTS `recommendation_logs` (
  `rec_id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` int UNSIGNED NOT NULL,
  `book_id` int UNSIGNED NOT NULL,
  `rec_type` enum('hot_transaction','new_listing','nearby_cabinet','personalized') NOT NULL COMMENT '推薦類型',
  `is_clicked` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`rec_id`),
  KEY `idx_user` (`user_id`),
  KEY `idx_type_time` (`rec_type`,`created_at`),
  KEY `fk_rec_book` (`book_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='推薦紀錄表';

-- --------------------------------------------------------

--
-- 資料表結構 `referral_records`
--

CREATE TABLE IF NOT EXISTS `referral_records` (
  `referral_id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `inviter_id` int UNSIGNED NOT NULL COMMENT '邀請人',
  `invitee_id` int UNSIGNED NOT NULL COMMENT '被邀請人',
  `reward_amount` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '獎勵金額',
  `status` enum('pending','rewarded','expired') NOT NULL DEFAULT 'pending',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`referral_id`),
  KEY `idx_inviter` (`inviter_id`),
  KEY `fk_ref_invitee` (`invitee_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='邀請紀錄表';

-- --------------------------------------------------------

--
-- 資料表結構 `refund_records`
--

CREATE TABLE IF NOT EXISTS `refund_records` (
  `refund_id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `order_id` int UNSIGNED NOT NULL,
  `dispute_id` int UNSIGNED DEFAULT NULL COMMENT '關聯的仲裁編號',
  `refund_type` enum('manual','auto','admin') NOT NULL COMMENT '人工撥款/自動退款/管理員退款',
  `amount` decimal(10,2) NOT NULL,
  `status` enum('pending','approved','rejected','completed') NOT NULL DEFAULT 'pending',
  `admin_id` int UNSIGNED DEFAULT NULL,
  `reason` text,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `processed_at` datetime DEFAULT NULL,
  PRIMARY KEY (`refund_id`),
  KEY `idx_order` (`order_id`),
  KEY `fk_refund_dispute` (`dispute_id`),
  KEY `fk_refund_admin` (`admin_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='退款紀錄表（後台管理）';

-- --------------------------------------------------------

--
-- 資料表結構 `reports`
--

CREATE TABLE IF NOT EXISTS `reports` (
  `report_id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `reporter_id` int UNSIGNED NOT NULL COMMENT '檢舉人',
  `target_type` enum('user','book','message') NOT NULL COMMENT '檢舉對象類型',
  `target_id` int UNSIGNED NOT NULL COMMENT '被檢舉對象ID',
  `reason` text NOT NULL COMMENT '檢舉原因',
  `evidence_urls` text COMMENT '證據（JSON）',
  `status` enum('pending','reviewing','resolved','dismissed') NOT NULL DEFAULT 'pending',
  `admin_id` int UNSIGNED DEFAULT NULL,
  `admin_note` text,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `resolved_at` datetime DEFAULT NULL,
  PRIMARY KEY (`report_id`),
  KEY `idx_status` (`status`),
  KEY `idx_target` (`target_type`,`target_id`),
  KEY `fk_report_reporter` (`reporter_id`),
  KEY `fk_report_admin` (`admin_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='檢舉管理表（後台管理）';

-- --------------------------------------------------------

--
-- 資料表結構 `reservations`
--

CREATE TABLE IF NOT EXISTS `reservations` (
  `reservation_id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `book_id` int UNSIGNED NOT NULL COMMENT '預約書籍',
  `buyer_id` int UNSIGNED NOT NULL COMMENT '預約買家',
  `seller_id` int UNSIGNED NOT NULL COMMENT '賣家',
  `cabinet_id` int UNSIGNED DEFAULT NULL COMMENT '預約取書的智慧書櫃',
  `status` enum('pending','confirmed','cancelled','expired') NOT NULL DEFAULT 'pending' COMMENT '預約狀態',
  `pickup_deadline` datetime DEFAULT NULL COMMENT '取書期限',
  `qr_code` varchar(500) DEFAULT NULL COMMENT '預約確認QR Code路徑',
  `note` text,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`reservation_id`),
  KEY `idx_book` (`book_id`),
  KEY `idx_buyer` (`buyer_id`),
  KEY `idx_seller` (`seller_id`),
  KEY `idx_cabinet` (`cabinet_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='預約管理表（智慧書櫃取書預約）';

-- --------------------------------------------------------

--
-- 資料表結構 `shopping_cart`
--

CREATE TABLE IF NOT EXISTS `shopping_cart` (
  `cart_id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` int UNSIGNED NOT NULL,
  `book_id` int UNSIGNED NOT NULL,
  `quantity` int UNSIGNED NOT NULL DEFAULT '1',
  `added_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`cart_id`),
  UNIQUE KEY `uk_user_book` (`user_id`,`book_id`),
  KEY `fk_cart_book` (`book_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='購物車';

-- --------------------------------------------------------

--
-- 資料表結構 `smart_cabinets`
--

CREATE TABLE IF NOT EXISTS `smart_cabinets` (
  `cabinet_id` int UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '書櫃編號',
  `cabinet_name` varchar(100) NOT NULL COMMENT '書櫃名稱（如：中央大學圖書館旁）',
  `address` varchar(500) NOT NULL COMMENT '書櫃地址',
  `latitude` decimal(10,7) NOT NULL COMMENT '緯度（GPS定位）',
  `longitude` decimal(10,7) NOT NULL COMMENT '經度（GPS定位）',
  `total_slots` int UNSIGNED NOT NULL DEFAULT '20' COMMENT '書櫃總格數',
  `available_slots` int UNSIGNED NOT NULL DEFAULT '20' COMMENT '目前可用格數',
  `is_active` tinyint(1) NOT NULL DEFAULT '1' COMMENT '書櫃啟用狀態',
  `open_time` time DEFAULT NULL COMMENT '開放起始時間',
  `close_time` time DEFAULT NULL COMMENT '開放結束時間',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`cabinet_id`),
  KEY `idx_location` (`latitude`,`longitude`),
  KEY `idx_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='智慧書櫃據點表';

-- --------------------------------------------------------

--
-- 資料表結構 `system_announcements`
--

CREATE TABLE IF NOT EXISTS `system_announcements` (
  `announcement_id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `admin_id` int UNSIGNED NOT NULL COMMENT '發布管理員',
  `title` varchar(255) NOT NULL,
  `content` text NOT NULL,
  `type` enum('general','maintenance','promotion','policy') NOT NULL DEFAULT 'general',
  `is_published` tinyint(1) NOT NULL DEFAULT '0',
  `published_at` datetime DEFAULT NULL,
  `expires_at` datetime DEFAULT NULL COMMENT '公告到期時間',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`announcement_id`),
  KEY `idx_published` (`is_published`,`published_at`),
  KEY `fk_announce_admin` (`admin_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='系統公告表（後台管理）';

-- --------------------------------------------------------

--
-- 資料表結構 `transaction_disputes`
--

CREATE TABLE IF NOT EXISTS `transaction_disputes` (
  `dispute_id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `order_id` int UNSIGNED NOT NULL COMMENT '爭議訂單',
  `applicant_id` int UNSIGNED NOT NULL COMMENT '申訴人',
  `reason` text NOT NULL COMMENT '申訴理由',
  `evidence_urls` text COMMENT '證據圖片路徑（JSON格式）',
  `status` enum('pending','processing','resolved') NOT NULL DEFAULT 'pending' COMMENT '待處理/處理中/已結案',
  `admin_id` int UNSIGNED DEFAULT NULL COMMENT '處理的管理員',
  `admin_note` text COMMENT '管理員備註',
  `result` enum('refund_manual','refund_auto','dismissed','mediated') DEFAULT NULL COMMENT '處理結果',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `resolved_at` datetime DEFAULT NULL,
  PRIMARY KEY (`dispute_id`),
  KEY `idx_order` (`order_id`),
  KEY `idx_status` (`status`),
  KEY `fk_dispute_applicant` (`applicant_id`),
  KEY `fk_dispute_admin` (`admin_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='交易仲裁/申訴表（後台管理）';

-- --------------------------------------------------------

--
-- 資料表結構 `users`
--

CREATE TABLE IF NOT EXISTS `users` (
  `user_id` int UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '會員編號',
  `email` varchar(255) NOT NULL COMMENT '電子信箱（登入帳號）',
  `password_hash` varchar(255) NOT NULL COMMENT '密碼雜湊',
  `nickname` varchar(50) NOT NULL COMMENT '用戶名稱',
  `avatar_url` varchar(500) DEFAULT NULL COMMENT '用戶頭像路徑',
  `bio` text COMMENT '個人簡介',
  `phone` varchar(20) DEFAULT NULL COMMENT '電話號碼',
  `birthday` date DEFAULT NULL COMMENT '生日',
  `gender` enum('male','female','other','undisclosed') DEFAULT 'undisclosed' COMMENT '性別',
  `role` enum('buyer_seller','admin') NOT NULL DEFAULT 'buyer_seller' COMMENT '角色：一般買賣家 / 後台管理員',
  `is_active` tinyint(1) NOT NULL DEFAULT '1' COMMENT '帳號啟用狀態',
  `is_blacklisted` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否列入黑名單',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '註冊時間',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `uk_email` (`email`),
  KEY `idx_role` (`role`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='會員資料表';

--
-- 傾印資料表的資料 `users`
--

INSERT INTO `users` (`user_id`, `email`, `password_hash`, `nickname`, `avatar_url`, `bio`, `phone`, `birthday`, `gender`, `role`, `is_active`, `is_blacklisted`, `created_at`, `updated_at`) VALUES
(1, 'admin1@bookapp.com', '$2b$10$nUVFtk9d4DEMz8XI3wZWZukQ4lPet3wY4mtlBjbKzx8b82LcYrYgW', '管理員A', NULL, NULL, NULL, NULL, 'undisclosed', 'admin', 1, 0, '2026-03-25 01:12:08', '2026-04-05 06:15:15'),
(2, 'admin2@bookapp.com', '$2b$10$nUVFtk9d4DEMz8XI3wZWZukQ4lPet3wY4mtlBjbKzx8b82LcYrYgW', '管理員B', NULL, NULL, NULL, NULL, 'undisclosed', 'admin', 1, 0, '2026-03-25 01:12:08', '2026-04-05 06:15:13'),
(3, 'admin3@bookapp.com', '$2b$10$nUVFtk9d4DEMz8XI3wZWZukQ4lPet3wY4mtlBjbKzx8b82LcYrYgW', '管理員C', NULL, NULL, NULL, NULL, 'undisclosed', 'admin', 1, 0, '2026-03-25 01:12:08', '2026-04-05 06:15:11'),
(4, 'admin4@bookapp.com', '$2b$10$nUVFtk9d4DEMz8XI3wZWZukQ4lPet3wY4mtlBjbKzx8b82LcYrYgW', '管理員D', NULL, NULL, NULL, NULL, 'undisclosed', 'admin', 1, 0, '2026-03-25 01:12:08', '2026-04-05 06:15:09'),
(7, 'kaijun@kaijun.tw', '$2b$10$nUVFtk9d4DEMz8XI3wZWZukQ4lPet3wY4mtlBjbKzx8b82LcYrYgW', '許大帥哥', NULL, NULL, NULL, NULL, 'undisclosed', 'admin', 1, 0, '2026-03-28 19:09:09', '2026-03-28 19:09:09'),
(10, 'ivychiang726@gmail.com', '$2b$10$MM.lCr5pyz3ZpEBvnjsh.O4ZmFvQrQVwoLlbdcs9hanJwkE2uDIE6', 'yx', NULL, NULL, NULL, NULL, 'undisclosed', 'admin', 1, 0, '2026-03-30 10:47:48', '2026-03-30 10:47:48');

-- --------------------------------------------------------

--
-- 資料表結構 `user_achievements`
--

CREATE TABLE IF NOT EXISTS `user_achievements` (
  `user_achievement_id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` int UNSIGNED NOT NULL,
  `achievement_id` int UNSIGNED NOT NULL,
  `achieved_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_achievement_id`),
  UNIQUE KEY `uk_user_achievement` (`user_id`,`achievement_id`),
  KEY `fk_ua_achievement` (`achievement_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='使用者成就紀錄表';

-- --------------------------------------------------------

--
-- 資料表結構 `user_qr_codes`
--

CREATE TABLE IF NOT EXISTS `user_qr_codes` (
  `qr_id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` int UNSIGNED NOT NULL,
  `qr_type` enum('profile','referral') NOT NULL DEFAULT 'profile' COMMENT '我的QR Code / 推薦QR Code',
  `qr_code_url` varchar(500) NOT NULL COMMENT 'QR Code圖片路徑',
  `qr_data` varchar(500) NOT NULL COMMENT 'QR Code對應資料',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`qr_id`),
  KEY `idx_user_type` (`user_id`,`qr_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='使用者QR Code表';

-- --------------------------------------------------------

--
-- 資料表結構 `user_settings`
--

CREATE TABLE IF NOT EXISTS `user_settings` (
  `setting_id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` int UNSIGNED NOT NULL,
  `theme` enum('light','dark') NOT NULL DEFAULT 'light' COMMENT '主題（深淺模式）',
  `notification_order` tinyint(1) NOT NULL DEFAULT '1' COMMENT '訂單通知開關',
  `notification_promo` tinyint(1) NOT NULL DEFAULT '1' COMMENT '推播通知開關',
  `notification_message` tinyint(1) NOT NULL DEFAULT '1' COMMENT '訊息通知開關',
  `privacy_show_profile` tinyint(1) NOT NULL DEFAULT '1' COMMENT '公開個人檔案',
  `privacy_show_phone` tinyint(1) NOT NULL DEFAULT '0' COMMENT '公開電話',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`setting_id`),
  UNIQUE KEY `uk_user_setting` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='使用者設定表';

-- --------------------------------------------------------

--
-- 資料表結構 `wallets`
--

CREATE TABLE IF NOT EXISTS `wallets` (
  `wallet_id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` int UNSIGNED NOT NULL,
  `balance` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT '目前餘額/可用餘額',
  `frozen_amount` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT '凍結金額（交易中）',
  `total_income` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT '累計收益',
  `total_expense` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT '累計支出',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`wallet_id`),
  UNIQUE KEY `uk_wallet_user` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='會員錢包表';

-- --------------------------------------------------------

--
-- 資料表結構 `wallet_transactions`
--

CREATE TABLE IF NOT EXISTS `wallet_transactions` (
  `txn_id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `wallet_id` int UNSIGNED NOT NULL,
  `user_id` int UNSIGNED NOT NULL,
  `type` enum('deposit','withdrawal','purchase','sale_income','refund','admin_adjust') NOT NULL COMMENT '交易類型',
  `amount` decimal(12,2) NOT NULL COMMENT '交易金額',
  `balance_after` decimal(12,2) NOT NULL COMMENT '交易後餘額',
  `related_order_id` int UNSIGNED DEFAULT NULL COMMENT '關聯訂單編號',
  `description` varchar(255) DEFAULT NULL COMMENT '說明',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`txn_id`),
  KEY `idx_wallet` (`wallet_id`),
  KEY `idx_user_time` (`user_id`,`created_at`),
  KEY `fk_txn_order` (`related_order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='錢包交易紀錄表';

--
-- 已傾印資料表的索引
--

--
-- 資料表索引 `books`
--
ALTER TABLE `books` ADD FULLTEXT KEY `ft_book_search` (`title`,`author`,`publisher`,`description`);

--
-- 已傾印資料表的限制式
--

--
-- 資料表的限制式 `admin_operation_logs`
--
ALTER TABLE `admin_operation_logs`
  ADD CONSTRAINT `fk_oplog_admin` FOREIGN KEY (`admin_id`) REFERENCES `users` (`user_id`);

--
-- 資料表的限制式 `admin_permissions`
--
ALTER TABLE `admin_permissions`
  ADD CONSTRAINT `fk_admin_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `bankbooks`
--
ALTER TABLE `bankbooks`
  ADD CONSTRAINT `fk_bankbook_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `books`
--
ALTER TABLE `books`
  ADD CONSTRAINT `fk_book_cabinet` FOREIGN KEY (`cabinet_id`) REFERENCES `smart_cabinets` (`cabinet_id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_book_category` FOREIGN KEY (`category_id`) REFERENCES `book_categories` (`category_id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_book_seller` FOREIGN KEY (`seller_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `book_categories`
--
ALTER TABLE `book_categories`
  ADD CONSTRAINT `fk_category_parent` FOREIGN KEY (`parent_id`) REFERENCES `book_categories` (`category_id`) ON DELETE SET NULL;

--
-- 資料表的限制式 `book_images`
--
ALTER TABLE `book_images`
  ADD CONSTRAINT `fk_image_book` FOREIGN KEY (`book_id`) REFERENCES `books` (`book_id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `cabinet_slots`
--
ALTER TABLE `cabinet_slots`
  ADD CONSTRAINT `fk_slot_cabinet` FOREIGN KEY (`cabinet_id`) REFERENCES `smart_cabinets` (`cabinet_id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `chat_messages`
--
ALTER TABLE `chat_messages`
  ADD CONSTRAINT `fk_msg_room` FOREIGN KEY (`room_id`) REFERENCES `chat_rooms` (`room_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_msg_sender` FOREIGN KEY (`sender_id`) REFERENCES `users` (`user_id`);

--
-- 資料表的限制式 `chat_rooms`
--
ALTER TABLE `chat_rooms`
  ADD CONSTRAINT `fk_chat_book` FOREIGN KEY (`book_id`) REFERENCES `books` (`book_id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_chat_user_a` FOREIGN KEY (`user_a_id`) REFERENCES `users` (`user_id`),
  ADD CONSTRAINT `fk_chat_user_b` FOREIGN KEY (`user_b_id`) REFERENCES `users` (`user_id`);

--
-- 資料表的限制式 `content_reviews`
--
ALTER TABLE `content_reviews`
  ADD CONSTRAINT `fk_content_admin` FOREIGN KEY (`admin_id`) REFERENCES `users` (`user_id`);

--
-- 資料表的限制式 `favorites`
--
ALTER TABLE `favorites`
  ADD CONSTRAINT `fk_fav_book` FOREIGN KEY (`book_id`) REFERENCES `books` (`book_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_fav_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `login_logs`
--
ALTER TABLE `login_logs`
  ADD CONSTRAINT `fk_login_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `notifications`
--
ALTER TABLE `notifications`
  ADD CONSTRAINT `fk_notif_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `orders`
--
ALTER TABLE `orders`
  ADD CONSTRAINT `fk_order_buyer` FOREIGN KEY (`buyer_id`) REFERENCES `users` (`user_id`),
  ADD CONSTRAINT `fk_order_cabinet` FOREIGN KEY (`cabinet_id`) REFERENCES `smart_cabinets` (`cabinet_id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_order_seller` FOREIGN KEY (`seller_id`) REFERENCES `users` (`user_id`),
  ADD CONSTRAINT `fk_order_slot` FOREIGN KEY (`slot_id`) REFERENCES `cabinet_slots` (`slot_id`) ON DELETE SET NULL;

--
-- 資料表的限制式 `order_items`
--
ALTER TABLE `order_items`
  ADD CONSTRAINT `fk_item_book` FOREIGN KEY (`book_id`) REFERENCES `books` (`book_id`),
  ADD CONSTRAINT `fk_item_order` FOREIGN KEY (`order_id`) REFERENCES `orders` (`order_id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `recommendation_logs`
--
ALTER TABLE `recommendation_logs`
  ADD CONSTRAINT `fk_rec_book` FOREIGN KEY (`book_id`) REFERENCES `books` (`book_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_rec_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `referral_records`
--
ALTER TABLE `referral_records`
  ADD CONSTRAINT `fk_ref_invitee` FOREIGN KEY (`invitee_id`) REFERENCES `users` (`user_id`),
  ADD CONSTRAINT `fk_ref_inviter` FOREIGN KEY (`inviter_id`) REFERENCES `users` (`user_id`);

--
-- 資料表的限制式 `refund_records`
--
ALTER TABLE `refund_records`
  ADD CONSTRAINT `fk_refund_admin` FOREIGN KEY (`admin_id`) REFERENCES `users` (`user_id`),
  ADD CONSTRAINT `fk_refund_dispute` FOREIGN KEY (`dispute_id`) REFERENCES `transaction_disputes` (`dispute_id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_refund_order` FOREIGN KEY (`order_id`) REFERENCES `orders` (`order_id`);

--
-- 資料表的限制式 `reports`
--
ALTER TABLE `reports`
  ADD CONSTRAINT `fk_report_admin` FOREIGN KEY (`admin_id`) REFERENCES `users` (`user_id`),
  ADD CONSTRAINT `fk_report_reporter` FOREIGN KEY (`reporter_id`) REFERENCES `users` (`user_id`);

--
-- 資料表的限制式 `reservations`
--
ALTER TABLE `reservations`
  ADD CONSTRAINT `fk_reservation_book` FOREIGN KEY (`book_id`) REFERENCES `books` (`book_id`),
  ADD CONSTRAINT `fk_reservation_buyer` FOREIGN KEY (`buyer_id`) REFERENCES `users` (`user_id`),
  ADD CONSTRAINT `fk_reservation_cabinet` FOREIGN KEY (`cabinet_id`) REFERENCES `smart_cabinets` (`cabinet_id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_reservation_seller` FOREIGN KEY (`seller_id`) REFERENCES `users` (`user_id`);

--
-- 資料表的限制式 `shopping_cart`
--
ALTER TABLE `shopping_cart`
  ADD CONSTRAINT `fk_cart_book` FOREIGN KEY (`book_id`) REFERENCES `books` (`book_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_cart_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `system_announcements`
--
ALTER TABLE `system_announcements`
  ADD CONSTRAINT `fk_announce_admin` FOREIGN KEY (`admin_id`) REFERENCES `users` (`user_id`);

--
-- 資料表的限制式 `transaction_disputes`
--
ALTER TABLE `transaction_disputes`
  ADD CONSTRAINT `fk_dispute_admin` FOREIGN KEY (`admin_id`) REFERENCES `users` (`user_id`),
  ADD CONSTRAINT `fk_dispute_applicant` FOREIGN KEY (`applicant_id`) REFERENCES `users` (`user_id`),
  ADD CONSTRAINT `fk_dispute_order` FOREIGN KEY (`order_id`) REFERENCES `orders` (`order_id`);

--
-- 資料表的限制式 `user_achievements`
--
ALTER TABLE `user_achievements`
  ADD CONSTRAINT `fk_ua_achievement` FOREIGN KEY (`achievement_id`) REFERENCES `achievements` (`achievement_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_ua_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `user_qr_codes`
--
ALTER TABLE `user_qr_codes`
  ADD CONSTRAINT `fk_qr_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `user_settings`
--
ALTER TABLE `user_settings`
  ADD CONSTRAINT `fk_setting_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `wallets`
--
ALTER TABLE `wallets`
  ADD CONSTRAINT `fk_wallet_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `wallet_transactions`
--
ALTER TABLE `wallet_transactions`
  ADD CONSTRAINT `fk_txn_order` FOREIGN KEY (`related_order_id`) REFERENCES `orders` (`order_id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_txn_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`),
  ADD CONSTRAINT `fk_txn_wallet` FOREIGN KEY (`wallet_id`) REFERENCES `wallets` (`wallet_id`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
