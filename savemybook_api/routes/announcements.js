const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');
const requireAdmin = require('../middleware/requireAdmin');

const router = express.Router();

const TYPES = ['general', 'maintenance', 'promotion', 'policy'];

router.get('/', async (req, res) => {
  try {
    const now = new Date();
    const announcements = await prisma.system_announcements.findMany({
      where: {
        is_published: true,
        OR: [{ expires_at: null }, { expires_at: { gt: now } }]
      },
      orderBy: { published_at: 'desc' },
      include: { users: { select: { user_id: true, nickname: true } } }
    });
    res.status(200).json({ success: true, data: announcements });
  } catch (err) {
    console.error('[取得公告失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.get('/all', authenticateToken, requireAdmin('announcements'), async (req, res) => {
  try {
    const announcements = await prisma.system_announcements.findMany({
      orderBy: { created_at: 'desc' },
      include: { users: { select: { user_id: true, nickname: true } } }
    });
    res.status(200).json({ success: true, data: announcements });
  } catch (err) {
    console.error('[取得公告列表失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.post('/', authenticateToken, requireAdmin('announcements'), async (req, res) => {
  const { title, content, type, is_published, expires_at } = req.body;

  if (!title || !content) {
    return res.status(400).json({ success: false, message: '請填寫標題與內容' });
  }
  if (type && !TYPES.includes(type)) {
    return res.status(400).json({ success: false, message: `type 僅接受：${TYPES.join(', ')}` });
  }

  try {
    const published = is_published === true || is_published === 'true';
    const announcement = await prisma.system_announcements.create({
      data: {
        admin_id: req.user.userId,
        title,
        content,
        type: type || 'general',
        is_published: published,
        published_at: published ? new Date() : null,
        expires_at: expires_at ? new Date(expires_at) : null
      }
    });

    await prisma.admin_operation_logs.create({
      data: {
        admin_id: req.user.userId,
        action: '新增系統公告',
        target_type: 'announcement',
        target_id: announcement.announcement_id,
        detail: title
      }
    });

    res.status(201).json({ success: true, message: '公告已建立', data: announcement });
  } catch (err) {
    console.error('[建立公告失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.put('/:id', authenticateToken, requireAdmin('announcements'), async (req, res) => {
  const announcementId = parseInt(req.params.id);
  const { title, content, type, is_published, expires_at } = req.body;

  try {
    const existing = await prisma.system_announcements.findUnique({ where: { announcement_id: announcementId } });
    if (!existing) return res.status(404).json({ success: false, message: '找不到該公告' });

    const published = is_published === undefined ? existing.is_published : (is_published === true || is_published === 'true');

    const announcement = await prisma.system_announcements.update({
      where: { announcement_id: announcementId },
      data: {
        title, content, type,
        is_published: published,
        published_at: published && !existing.published_at ? new Date() : existing.published_at,
        expires_at: expires_at === undefined ? undefined : (expires_at ? new Date(expires_at) : null),
        updated_at: new Date()
      }
    });

    await prisma.admin_operation_logs.create({
      data: {
        admin_id: req.user.userId,
        action: '編輯系統公告',
        target_type: 'announcement',
        target_id: announcementId,
        detail: title ?? existing.title
      }
    });

    res.status(200).json({ success: true, message: '公告已更新', data: announcement });
  } catch (err) {
    console.error('[更新公告失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.delete('/:id', authenticateToken, requireAdmin('announcements'), async (req, res) => {
  const announcementId = parseInt(req.params.id);
  try {
    await prisma.system_announcements.delete({ where: { announcement_id: announcementId } });
    await prisma.admin_operation_logs.create({
      data: {
        admin_id: req.user.userId,
        action: '刪除系統公告',
        target_type: 'announcement',
        target_id: announcementId
      }
    });
    res.status(200).json({ success: true, message: '公告已刪除' });
  } catch (err) {
    if (err.code === 'P2025') return res.status(404).json({ success: false, message: '找不到該公告' });
    console.error('[刪除公告失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

module.exports = router;
