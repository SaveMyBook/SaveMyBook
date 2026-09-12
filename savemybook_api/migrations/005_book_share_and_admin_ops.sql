-- 書籍分享連結改用權杖，並讓管理員能改書籍內容。
-- 套用：mysql -u admin -p 930914_pw < migrations/005_book_share_and_admin_ops.sql
--       npx prisma db pull && npx prisma generate

-- 分享書籍原本是 savemybook://book/<流水號>，任何人都能從 1 開始枚舉全站書籍，
-- 而且只能在裝了 App 的裝置上開。改成跟個人頁一樣的 32 位元組亂數權杖。
ALTER TABLE books
  ADD COLUMN share_token CHAR(32) NULL DEFAULT NULL AFTER is_approved;

CREATE UNIQUE INDEX uk_book_share_token ON books (share_token);
