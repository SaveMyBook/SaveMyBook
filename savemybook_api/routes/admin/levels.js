const express = require('express');
const prisma = require('../../lib/prisma');
const requireAdmin = require('../../middleware/requireAdmin');
const v = require('../../lib/validate');
const { badRequest, orNotFound } = require('../../lib/errors');
const { listLevels } = require('../../services/levels');
const { logAction } = require('../../services/audit');

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
  await logAction(req.user.userId, '新增會員等級', 'level', created.level_id, data.level_name);
  res.status(201).json({ success: true, data: { level_id: created.level_id } });
});

router.put('/levels/:id', canManage, async (req, res) => {
  const levelId = v.id(req.params.id, '等級編號');
  const data = parseLevelBody(req.body);
  await orNotFound(prisma.member_levels.update({ where: { level_id: levelId }, data }), '找不到這個等級');
  await logAction(req.user.userId, '編輯會員等級', 'level', levelId, data.level_name);
  res.status(200).json({ success: true, message: '已更新等級' });
});

router.delete('/levels/:id', canManage, async (req, res) => {
  const levelId = v.id(req.params.id, '等級編號');
  await orNotFound(prisma.member_levels.delete({ where: { level_id: levelId } }), '找不到這個等級');
  await logAction(req.user.userId, '刪除會員等級', 'level', levelId);
  res.status(200).json({ success: true, message: '已刪除等級' });
});

module.exports = router;
