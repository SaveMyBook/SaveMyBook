const express = require('express');
const authenticateToken = require('../middleware/auth');
const { rateLimit, byUser } = require('../middleware/rateLimit');
const { imageUpload, audioUpload } = require('../lib/upload');
const { badRequest } = require('../lib/errors');
const supportAttachments = require('../services/support-attachments');

const router = express.Router();

const evidence = imageUpload({ folder: 'evidence', maxFileSize: 8 * 1024 * 1024 });
const chatImages = imageUpload({ folder: 'chat', maxFileSize: 10 * 1024 * 1024 });
const supportImages = imageUpload({ folder: supportAttachments.FOLDER, maxFileSize: supportAttachments.MAX_FILE_BYTES });
const voices = audioUpload({ folder: 'voice', maxFileSize: 5 * 1024 * 1024 });

const uploadLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 30,
  key: byUser,
  message: '上傳過於頻繁，請稍後再試'
});

const chatUploadLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 60,
  key: byUser,
  message: '上傳過於頻繁，請稍後再試'
});

router.post('/', authenticateToken, uploadLimiter, ...evidence.array('files', 5), (req, res) => {
  if (!req.files || req.files.length === 0) throw badRequest('請選擇要上傳的檔案');

  const urls = req.files.map((f) => evidence.urlOf(f));
  res.status(201).json({ success: true, message: '上傳成功', data: { urls } });
});

router.post('/chat-image', authenticateToken, chatUploadLimiter, ...chatImages.single('file'), (req, res) => {
  if (!req.file) throw badRequest('請選擇要傳送的圖片');
  res.status(201).json({ success: true, data: { url: chatImages.urlOf(req.file) } });
});

router.post('/voice', authenticateToken, chatUploadLimiter, ...voices.single('file'), (req, res) => {
  if (!req.file) throw badRequest('請選擇要傳送的語音');
  res.status(201).json({ success: true, data: { url: voices.urlOf(req.file) } });
});

// 須在接收檔案前檢查，否則資料表未建立或待送出過多時檔案已寫入磁碟。
const canUploadSupport = async (req, res, next) => {
  await supportAttachments.assertCanUpload(req.user.userId);
  next();
};

router.post('/support-image', authenticateToken, uploadLimiter, canUploadSupport, ...supportImages.single('file'), async (req, res) => {
  if (!req.file) throw badRequest('請選擇要上傳的圖片');
  const url = supportImages.urlOf(req.file);
  await supportAttachments.recordUpload(req.user.userId, { url, size: req.file.size });
  res.status(201).json({ success: true, data: { url } });
});

module.exports = router;
