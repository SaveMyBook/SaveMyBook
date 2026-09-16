const express = require('express');
const authenticateToken = require('../../middleware/auth');
const requireAdmin = require('../../middleware/requireAdmin');

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
  './system',
  './ai',
  './auth'
];

const router = express.Router();

// 此處只驗身分，各分區須自行掛 requireAdmin('xxx') 檢查權限。
router.use(authenticateToken, requireAdmin());

for (const section of SECTIONS) {
  router.use(require(section));
}

module.exports = router;
module.exports.SECTIONS = SECTIONS;
