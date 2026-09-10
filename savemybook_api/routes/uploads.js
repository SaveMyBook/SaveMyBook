const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const authenticateToken = require('../middleware/auth');

const router = express.Router();

const uploadDir = path.join(__dirname, '../uploads/evidence');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const upload = multer({
  storage: multer.diskStorage({
    destination: (req, file, cb) => cb(null, uploadDir),
    filename: (req, file, cb) => {
      cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}${path.extname(file.originalname)}`);
    }
  }),
  limits: { fileSize: 8 * 1024 * 1024 }
});

router.post('/', authenticateToken, upload.array('files', 5), (req, res) => {
  if (!req.files || req.files.length === 0) {
    return res.status(400).json({ success: false, message: '請選擇要上傳的檔案' });
  }

  const urls = req.files.map(f => `/uploads/evidence/${f.filename}`);
  res.status(201).json({ success: true, message: '上傳成功', data: { urls } });
});

module.exports = router;
