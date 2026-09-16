const express = require('express');
const backup = require('../services/backup');

const router = express.Router();

// 不經登入驗證：持有者憑一次性票證下載，票證由已驗證身分的管理員產生。
router.get('/:ticket', async (req, res) => {
  res.set('Cache-Control', 'no-store');
  res.set('Referrer-Policy', 'no-referrer');
  const { filePath, fileName } = await backup.redeemDownloadTicket(req.params.ticket, req);
  res.download(filePath, fileName);
});

module.exports = router;
