const express = require('express');
const authenticateToken = require('../../middleware/auth');
const requireAdmin = require('../../middleware/requireAdmin');

/// 後台路由依功能拆檔，與 docs/admin-*.yaml 一一對應。
/// scripts/check-docs.js 會讀這張表找出每個分區的端點，新增分區時兩邊都要改。
const SECTIONS = [
  './overview',
  './members',
  './content',
  './orders',
  './moderation',
  './cabinets',
  './wallets',
  './levels',
  './support',
  './system'
];

const router = express.Router();

// 身分只驗一次。各分區自己再掛 requireAdmin('xxx') 檢查細部權限。
router.use(authenticateToken, requireAdmin());

for (const section of SECTIONS) {
  router.use(require(section));
}

module.exports = router;
module.exports.SECTIONS = SECTIONS;
