const express = require('express');
const requireAdmin = require('../../middleware/requireAdmin');
const { requireVerification } = require('../../middleware/verification');
const { rateLimit, byUser } = require('../../middleware/rateLimit');
const v = require('../../lib/validate');
const { actorOf } = require('../../lib/request-context');
const { badRequest } = require('../../lib/errors');
const backup = require('../../services/backup');
const account = require('../../services/account');

const router = express.Router();
const canRunSystem = requireAdmin('system');
const canManageMembers = requireAdmin('members');

const restoreLimiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 5, key: byUser, message: '嘗試次數過多，請 15 分鐘後再試' });

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
  const record = await backup.runManually(actorOf(req));
  res.status(201).json({
    success: true,
    message: '備份完成',
    data: { backup_id: record.backup_id, file_name: record.file_name, size_bytes: Number(record.size_bytes) }
  });
});

router.get('/backups/:id/download', canRunSystem, async (req, res) => {
  const { filePath, fileName } = await backup.prepareDownload(v.id(req.params.id, '備份編號'), actorOf(req));
  res.set('Cache-Control', 'no-store');
  res.download(filePath, fileName);
});

router.post('/backups/:id/restore', canRunSystem, restoreLimiter, async (req, res) => {
  const backupId = v.id(req.params.id, '備份編號');
  const plain = typeof req.body.password === 'string' ? req.body.password : '';
  if (!plain) throw badRequest('請輸入您的登入密碼以確認還原');

  const { target, safety } = await backup.restore(backupId, plain, actorOf(req));
  res.status(202).json({
    success: true,
    message: '已開始還原，期間系統暫停服務，完成後將自動恢復',
    data: { file_name: target.file_name, safety_backup: safety.file_name }
  });
});

router.delete('/backups/:id', canRunSystem, requireVerification('sensitive'), async (req, res) => {
  await backup.removeWithAudit(v.id(req.params.id, '備份編號'), actorOf(req));
  res.status(200).json({ success: true, message: '已刪除備份' });
});

router.get('/deletions', canManageMembers, async (req, res) => {
  res.status(200).json({ success: true, data: await account.pendingDeletions() });
});

router.post('/deletions/:id/cancel', canManageMembers, async (req, res) => {
  await account.cancelDeletionByAdmin(v.id(req.params.id, '會員編號'), actorOf(req));
  res.status(200).json({ success: true, message: '已取消該會員的刪除申請' });
});

router.post('/deletions/:id/purge', canManageMembers, requireVerification('sensitive'), async (req, res) => {
  await account.anonymizeByAdmin(v.id(req.params.id, '會員編號'), actorOf(req));
  res.status(200).json({ success: true, message: '已完成匿名化' });
});

module.exports = router;
