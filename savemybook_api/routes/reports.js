const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');

const router = express.Router();

const TARGET_TYPES = ['user', 'book', 'message'];

router.get('/', authenticateToken, async (req, res) => {
  try {
    const reports = await prisma.reports.findMany({
      where: { reporter_id: req.user.userId },
      orderBy: { created_at: 'desc' }
    });
    res.status(200).json({ success: true, data: reports });
  } catch (err) {
    console.error('[取得檢舉列表失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.post('/', authenticateToken, async (req, res) => {
  const targetType = req.body.target_type;
  const targetId = parseInt(req.body.target_id);
  const reason = (req.body.reason || '').trim();
  const evidenceUrls = Array.isArray(req.body.evidence_urls)
    ? req.body.evidence_urls.join(',')
    : (req.body.evidence_urls || null);

  if (!TARGET_TYPES.includes(targetType)) {
    return res.status(400).json({ success: false, message: `target_type 僅接受：${TARGET_TYPES.join(', ')}` });
  }
  if (!targetId) return res.status(400).json({ success: false, message: '請提供 target_id' });
  if (!reason) return res.status(400).json({ success: false, message: '請填寫檢舉原因' });

  try {
    const report = await prisma.reports.create({
      data: {
        reporter_id: req.user.userId,
        target_type: targetType,
        target_id: targetId,
        reason,
        evidence_urls: evidenceUrls
      }
    });
    res.status(201).json({ success: true, message: '檢舉已送出，我們會盡快處理', data: report });
  } catch (err) {
    console.error('[建立檢舉失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

module.exports = router;
