const express = require('express');
const prisma = require('../../lib/prisma');
const requireAdmin = require('../../middleware/requireAdmin');
const v = require('../../lib/validate');
const { HttpError, badRequest, forbidden, notFound, conflict } = require('../../lib/errors');
const password = require('../../lib/password');
const { rateLimit, byUser } = require('../../middleware/rateLimit');
const backup = require('../../services/backup');
const account = require('../../services/account');
const audit = require('../../services/audit');
const { requireVerification } = require('../../services/security');

const formatSize = (bytes) => (bytes >= 1024 * 1024 ? `${(bytes / 1024 / 1024).toFixed(1)} MB` : `${Math.ceil(bytes / 1024)} KB`);

const router = express.Router();
const canRunSystem = requireAdmin('system');
const canManageMembers = requireAdmin('members');

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

  await audit.record(null, {
    adminId: req.user.userId,
    action: '手動備份資料庫',
    targetType: 'backup',
    targetId: record.backup_id,
    summary: `建立資料庫備份 ${record.file_name}（${formatSize(Number(record.size_bytes))}）`,
    req
  });
  res.status(201).json({
    success: true,
    message: '備份完成',
    data: { backup_id: record.backup_id, file_name: record.file_name, size_bytes: Number(record.size_bytes) }
  });
});

router.get('/backups/:id/download', canRunSystem, async (req, res) => {
  const backupId = v.id(req.params.id, '備份編號');

  const record = await prisma.db_backups.findUnique({ where: { backup_id: backupId } });
  if (!record) throw notFound('找不到此備份');

  const filePath = backup.filePathOf(record.file_name);
  if (!filePath) throw notFound('備份檔已不存在');

  await audit.record(null, {
    adminId: req.user.userId,
    action: '下載資料庫備份',
    targetType: 'backup',
    targetId: backupId,
    summary: `下載資料庫備份 ${record.file_name}（含全站個資）`,
    req
  });
  res.set('Cache-Control', 'no-store');
  res.download(filePath, record.file_name);
});

const restoreLimiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 5, key: byUser, message: '嘗試次數過多，請 15 分鐘後再試' });

router.post('/backups/:id/restore', canRunSystem, restoreLimiter, async (req, res) => {
  const backupId = v.id(req.params.id, '備份編號');
  const plain = typeof req.body.password === 'string' ? req.body.password : '';
  if (!plain) throw badRequest('請輸入您的登入密碼以確認還原');

  const me = await prisma.users.findUnique({ where: { user_id: req.user.userId }, select: { password_hash: true, nickname: true } });
  if (!(await password.verify(plain, me?.password_hash))) throw badRequest('密碼錯誤');

  const adminId = req.user.userId;
  const { target, safety } = await backup.startRestore({
    backupId,
    adminId,
    // 紀錄須在匯入之後才寫，否則會被備份檔裡的舊資料蓋掉。
    onFinished: async ({ error }) => {
      const adminStillExists = await prisma.users.count({ where: { user_id: adminId } });
      if (!adminStillExists) return;
      await audit.record(null, {
        adminId,
        action: error ? '資料庫還原失敗' : '還原資料庫',
        targetType: 'backup',
        summary: error
          ? `嘗試將資料庫還原至 ${target.file_name} 失敗：${String(error.message).slice(0, 200)}。還原前備份為 ${safety.file_name}`
          : `將資料庫還原至 ${target.file_name}（${target.created_at.toISOString().slice(0, 16).replace('T', ' ')} UTC）。`
            + `還原前的狀態已備份為 ${safety.file_name}，如需復原請還原該備份`,
        req
      });
    }
  });

  res.status(202).json({
    success: true,
    message: '已開始還原，期間系統暫停服務，完成後將自動恢復',
    data: { file_name: target.file_name, safety_backup: safety.file_name }
  });
});

router.delete('/backups/:id', canRunSystem, requireVerification('sensitive'), async (req, res) => {
  const backupId = v.id(req.params.id, '備份編號');
  const record = await prisma.db_backups.findUnique({ where: { backup_id: backupId } });
  const removed = await backup.remove(backupId);
  if (!removed) throw notFound('找不到此備份');
  await audit.record(null, {
    adminId: req.user.userId,
    action: '刪除資料庫備份',
    targetType: 'backup',
    targetId: backupId,
    summary: `刪除資料庫備份 ${record.file_name}（檔案已從磁碟移除，無法復原）`,
    req
  });
  res.status(200).json({ success: true, message: '已刪除備份' });
});

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
  const before = await prisma.users.findUnique({
    where: { user_id: userId },
    select: { nickname: true, email: true, deletion_requested_at: true }
  });
  if (!before) throw notFound('找不到該會員');

  const after = { deletion_requested_at: null };
  await prisma.users.update({ where: { user_id: userId }, data: { ...after, updated_at: new Date() } });

  const fields = { deletion_requested_at: '申請刪除時間' };
  await audit.record(null, {
    adminId: req.user.userId,
    action: '取消會員刪除申請',
    targetType: 'user',
    targetId: userId,
    summary: `取消 ${before.nickname}（${before.email}）的刪除帳號申請`,
    changes: audit.diff(before, after, fields),
    undo: before.deletion_requested_at ? [audit.undoUpdate('users', userId, before, after, fields)] : null,
    req
  });
  res.status(200).json({ success: true, message: '已取消該會員的刪除申請' });
});

// 匿名化無法復原，只能對本人已申請刪除的帳號執行。
router.post('/deletions/:id/purge', canManageMembers, requireVerification('sensitive'), async (req, res) => {
  const userId = v.id(req.params.id, '會員編號');
  if (userId === req.user.userId) throw badRequest('無法對自己執行此操作');

  const user = await prisma.users.findUnique({
    where: { user_id: userId },
    select: { role: true, deletion_requested_at: true, anonymized_at: true }
  });
  if (!user) throw notFound('找不到該會員');
  if (user.anonymized_at) throw conflict('此帳號已匿名化');
  if (!user.deletion_requested_at) throw conflict('此會員未申請刪除帳號，無法匿名化');
  if (user.role === 'admin') throw forbidden('無法匿名化管理員帳號，請先移除管理員身分');
  if ((await account.unsettledOrderCount(userId)) > 0) {
    throw conflict('此會員尚有進行中的訂單，請處理完成後再匿名化');
  }

  const who = await prisma.users.findUnique({ where: { user_id: userId }, select: { nickname: true, email: true } });
  await account.anonymize(userId);
  await audit.record(null, {
    adminId: req.user.userId,
    action: '立即匿名化會員',
    targetType: 'user',
    targetId: userId,
    summary: `提前匿名化 ${who.nickname}（${who.email}）的帳號，個資已清除，無法復原`,
    req
  });
  res.status(200).json({ success: true, message: '已完成匿名化' });
});

module.exports = router;
