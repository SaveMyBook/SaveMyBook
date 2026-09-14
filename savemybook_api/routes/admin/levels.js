const express = require('express');
const prisma = require('../../lib/prisma');
const requireAdmin = require('../../middleware/requireAdmin');
const v = require('../../lib/validate');
const { badRequest, notFound } = require('../../lib/errors');
const { listLevels } = require('../../services/levels');
const audit = require('../../services/audit');

const LEVEL_FIELDS = {
  level_name: '名稱',
  min_points: '最低點數',
  max_points: { label: '最高點數', format: (v) => (v === null ? '無上限' : String(v)) },
  benefits: '福利說明'
};

const router = express.Router();
const canManage = requireAdmin('levels');

const MAX_POINTS = 100000000;

const parseLevelBody = (body) => {
  const data = {
    level_name: v.text(body.level_name, { label: '等級名稱', max: 50 }),
    min_points: v.isBlank(body.min_points) ? 0 : v.int(body.min_points, { label: '最低點數', min: 0, max: MAX_POINTS }),
    max_points: v.isBlank(body.max_points) ? null : v.int(body.max_points, { label: '最高點數', min: 0, max: MAX_POINTS }),
    benefits: v.text(body.benefits, { label: '等級福利', max: 2000 }) || null
  };
  if (!data.level_name) throw badRequest('請輸入等級名稱');
  if (data.max_points !== null && data.max_points < data.min_points) throw badRequest('最高點數不能小於最低點數');
  return data;
};

router.get('/levels', canManage, async (req, res) => {
  res.status(200).json({ success: true, data: await listLevels() });
});

router.post('/levels', canManage, async (req, res) => {
  const data = parseLevelBody(req.body);
  const created = await prisma.member_levels.create({ data });
  await audit.record(null, {
    adminId: req.user.userId,
    action: '新增會員等級',
    targetType: 'level',
    targetId: created.level_id,
    summary: `新增了會員等級「${data.level_name}」（${data.min_points} 點起）`,
    undo: [audit.undoCreate('member_levels', created.level_id)],
    req
  });
  res.status(201).json({ success: true, data: { level_id: created.level_id } });
});

router.put('/levels/:id', canManage, async (req, res) => {
  const levelId = v.id(req.params.id, '等級編號');
  const data = parseLevelBody(req.body);
  const before = await prisma.member_levels.findUnique({ where: { level_id: levelId } });
  if (!before) throw notFound('找不到這個等級');

  await prisma.member_levels.update({ where: { level_id: levelId }, data });

  const changes = audit.diff(before, data, LEVEL_FIELDS);
  await audit.record(null, {
    adminId: req.user.userId,
    action: '編輯會員等級',
    targetType: 'level',
    targetId: levelId,
    summary: changes.length
      ? `修改了會員等級「${before.level_name}」的${changes.map((c) => c.label).join('、')}`
      : `重新儲存了會員等級「${before.level_name}」（沒有實際變動）`,
    changes,
    undo: changes.length ? [audit.undoUpdate('member_levels', levelId, before, data, LEVEL_FIELDS)] : null,
    req
  });
  res.status(200).json({ success: true, message: '已更新等級' });
});

router.delete('/levels/:id', canManage, async (req, res) => {
  const levelId = v.id(req.params.id, '等級編號');
  const before = await prisma.member_levels.findUnique({ where: { level_id: levelId } });
  if (!before) throw notFound('找不到這個等級');
  await prisma.member_levels.delete({ where: { level_id: levelId } });
  await audit.record(null, {
    adminId: req.user.userId,
    action: '刪除會員等級',
    targetType: 'level',
    targetId: levelId,
    summary: `刪除了會員等級「${before.level_name}」`,
    undo: [audit.undoDelete('member_levels', before)],
    req
  });
  res.status(200).json({ success: true, message: '已刪除等級' });
});

module.exports = router;
