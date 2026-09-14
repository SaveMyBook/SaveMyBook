const express = require('express');
const authenticateToken = require('../middleware/auth');
const { rateLimit, byUser } = require('../middleware/rateLimit');
const { imageUpload } = require('../lib/upload');
const { badRequest } = require('../lib/errors');

const router = express.Router();

const evidence = imageUpload({ folder: 'evidence', maxFileSize: 8 * 1024 * 1024 });

const uploadLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 30,
  key: byUser,
  message: '上傳太頻繁，請稍後再試'
});

router.post('/', authenticateToken, uploadLimiter, ...evidence.array('files', 5), (req, res) => {
  if (!req.files || req.files.length === 0) throw badRequest('請選擇要上傳的檔案');

  const urls = req.files.map((f) => evidence.urlOf(f));
  res.status(201).json({ success: true, message: '上傳成功', data: { urls } });
});

module.exports = router;
