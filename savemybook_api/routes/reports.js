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
    let ownerId = null;

    if (targetType === 'book') {
      const book = await prisma.books.findUnique({
        where: { book_id: targetId },
        select: { seller_id: true, title: true }
      });
      if (!book) return res.status(404).json({ success: false, message: '找不到該書籍' });
      if (book.seller_id === req.user.userId) {
        return res.status(400).json({ success: false, message: '無法檢舉自己上架的商品' });
      }
      ownerId = book.seller_id;
    }

    if (targetType === 'user') {
      if (targetId === req.user.userId) {
        return res.status(400).json({ success: false, message: '無法檢舉自己' });
      }
      const target = await prisma.users.findUnique({
        where: { user_id: targetId },
        select: { user_id: true }
      });
      if (!target) return res.status(404).json({ success: false, message: '找不到該使用者' });
      ownerId = target.user_id;
    }

    const duplicate = await prisma.reports.findFirst({
      where: {
        reporter_id: req.user.userId,
        target_type: targetType,
        target_id: targetId,
        status: { in: ['pending', 'reviewing'] }
      }
    });
    if (duplicate) {
      return res.status(409).json({ success: false, message: '你已經檢舉過了，我們正在處理中' });
    }

    const report = await prisma.$transaction(async (tx) => {
      const created = await tx.reports.create({
        data: {
          reporter_id: req.user.userId,
          target_type: targetType,
          target_id: targetId,
          reason,
          evidence_urls: evidenceUrls
        }
      });

      if (ownerId) {
        await tx.notifications.create({
          data: {
            user_id: ownerId,
            type: 'system',
            title: targetType === 'book' ? '你的商品被檢舉' : '你的帳號被檢舉',
            content: '我們已收到一則檢舉並開始審核，審核期間商品仍可正常販售。若違規成立將會通知你。',
            related_id: targetId,
            related_type: targetType
          }
        });
      }

      return created;
    });

    res.status(201).json({ success: true, message: '檢舉已送出，我們會盡快處理', data: report });
  } catch (err) {
    console.error('[建立檢舉失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

// 自己被檢舉的案件，讓賣家在書籍管理看到標註
router.get('/against-me', authenticateToken, async (req, res) => {
  try {
    const myBooks = await prisma.books.findMany({
      where: { seller_id: req.user.userId },
      select: { book_id: true }
    });

    const bookIds = myBooks.map(b => b.book_id);
    if (bookIds.length === 0) return res.status(200).json({ success: true, data: [] });

    const reports = await prisma.reports.findMany({
      where: { target_type: 'book', target_id: { in: bookIds } },
      orderBy: { created_at: 'desc' },
      select: { report_id: true, target_id: true, status: true, reason: true, created_at: true, resolved_at: true }
    });

    res.status(200).json({ success: true, data: reports });
  } catch (err) {
    console.error('[取得被檢舉紀錄失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

module.exports = router;
