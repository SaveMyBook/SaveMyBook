const express = require('express');
const prisma = require('../../lib/prisma');
const requireAdmin = require('../../middleware/requireAdmin');
const v = require('../../lib/validate');
const { HttpError, badRequest, forbidden, notFound, conflict, orNotFound } = require('../../lib/errors');
const backup = require('../../services/backup');
const account = require('../../services/account');
const { logAction } = require('../../services/audit');

const router = express.Router();
const canRunSystem = requireAdmin('system');
const canManageMembers = requireAdmin('members');

// ---------- 資料庫備份 ----------

router.get('/backups', canRunSystem, async (req, res) => {
  const { page, limit, skip } = v.pagination(req.query, { limit: 30 });
  const { total, rows } = await backup.list({ skip, limit });
  res.status(200).json({
    success: true,
    pagination: v.pageMeta(total, { page, limit }),
    keep: backup.KEEP,
    data: rows
  });
});

router.post('/backups', canRunSystem, async (req, res) => {
  let record;
  try {
    record = await backup.run({ adminId: req.user.userId, trigger: 'manual' });
  } catch (err) {
    if (err instanceof HttpError) throw err;
    console.error('[手動備份失敗]:', err);
    throw new HttpError(500, `備份失敗：${String(err.message).slice(0, 300)}`);
  }

  await logAction(req.user.userId, '手動備份資料庫', 'backup', record.backup_id, record.file_name);
  res.status(201).json({
    success: true,
    message: '備份完成',
    data: { backup_id: record.backup_id, file_name: record.file_name, size_bytes: Number(record.size_bytes) }
  });
});

router.get('/backups/:id/download', canRunSystem, async (req, res) => {
  const backupId = v.id(req.params.id, '備份編號');

  const record = await prisma.db_backups.findUnique({ where: { backup_id: backupId } });
  if (!record) throw notFound('找不到這份備份');

  const filePath = backup.filePathOf(record.file_name);
  if (!filePath) throw notFound('備份檔已不存在');

  await logAction(req.user.userId, '下載資料庫備份', 'backup', backupId, record.file_name);
  res.set('Cache-Control', 'no-store');
  res.download(filePath, record.file_name);
});

router.delete('/backups/:id', canRunSystem, async (req, res) => {
  const backupId = v.id(req.params.id, '備份編號');
  const removed = await backup.remove(backupId);
  if (!removed) throw notFound('找不到這份備份');
  await logAction(req.user.userId, '刪除資料庫備份', 'backup', backupId);
  res.status(200).json({ success: true, message: '已刪除備份' });
});

// ---------- 待刪除帳號 ----------

router.get('/deletions', canManageMembers, async (req, res) => {
  const pending = await prisma.users.findMany({
    where: { deletion_requested_at: { not: null }, anonymized_at: null },
    orderBy: { deletion_requested_at: 'asc' },
    select: { user_id: true, nickname: true, email: true, avatar_url: true, deletion_requested_at: true }
  });

  res.status(200).json({
    success: true,
    data: pending.map((u) => ({ ...u, purge_at: account.graceDeadline(u.deletion_requested_at) }))
  });
});

router.post('/deletions/:id/cancel', canManageMembers, async (req, res) => {
  const userId = v.id(req.params.id, '會員編號');
  await orNotFound(
    prisma.users.update({
      where: { user_id: userId },
      data: { deletion_requested_at: null, updated_at: new Date() }
    }),
    '找不到該會員'
  );
  await logAction(req.user.userId, '取消會員刪除申請', 'user', userId);
  res.status(200).json({ success: true, message: '已取消該會員的刪除申請' });
});

/// 匿名化無法復原，只能對「本人已申請刪除」的帳號提前執行。
/// 過去沒有這個檢查，任何有會員權限的管理員都能直接抹掉任一帳號。
router.post('/deletions/:id/purge', canManageMembers, async (req, res) => {
  const userId = v.id(req.params.id, '會員編號');
  if (userId === req.user.userId) throw badRequest('無法對自己執行此操作');

  const user = await prisma.users.findUnique({
    where: { user_id: userId },
    select: { role: true, deletion_requested_at: true, anonymized_at: true }
  });
  if (!user) throw notFound('找不到該會員');
  if (user.anonymized_at) throw conflict('這個帳號已經匿名化了');
  if (!user.deletion_requested_at) throw conflict('這位會員沒有申請刪除帳號，無法匿名化');
  if (user.role === 'admin') throw forbidden('不能匿名化管理員帳號，請先移除管理員身分');
  if ((await account.unsettledOrderCount(userId)) > 0) {
    throw conflict('這位會員還有進行中的訂單，請先處理後再匿名化');
  }

  await account.anonymize(userId);
  await logAction(req.user.userId, '立即匿名化會員', 'user', userId);
  res.status(200).json({ success: true, message: '已完成匿名化' });
});

module.exports = router;
