const express = require('express');
const requireAdmin = require('../../middleware/requireAdmin');
const v = require('../../lib/validate');
const { actorOf } = require('../../lib/request-context');
const { badRequest } = require('../../lib/errors');
const levels = require('../../services/levels');

const router = express.Router();
const canManage = requireAdmin('levels');

const MAX_POINTS = 100000000;

// max_points 由下一個等級的門檻推算，不接受用戶端指定，避免區間重疊或出現空隙。
const parseLevelBody = (body) => {
  const data = {
    level_name: v.text(body.level_name, { label: '等級名稱', max: 50 }),
    min_points: v.isBlank(body.min_points) ? 0 : v.int(body.min_points, { label: '門檻點數', min: 0, max: MAX_POINTS }),
    benefits: v.text(body.benefits, { label: '等級福利', max: 2000 }) || null
  };
  if (!data.level_name) throw badRequest('請輸入等級名稱');
  return data;
};

router.get('/levels', canManage, async (req, res) => {
  res.status(200).json({ success: true, data: await levels.listWithMembers() });
});

router.post('/levels', canManage, async (req, res) => {
  const created = await levels.create(parseLevelBody(req.body), actorOf(req));
  res.status(201).json({ success: true, data: { level_id: created.level_id } });
});

// 必須排在 /levels/:id 之前，否則 reorder 會被當成 id。
router.put('/levels/reorder', canManage, async (req, res) => {
  const ids = v.sortOrder(req.body.order, '請提供調整後的等級順序');
  await levels.reorder(ids, actorOf(req));
  res.status(200).json({ success: true, message: '已更新順序' });
});

router.put('/levels/:id', canManage, async (req, res) => {
  const levelId = v.id(req.params.id, '等級編號');
  await levels.update(levelId, parseLevelBody(req.body), actorOf(req));
  res.status(200).json({ success: true, message: '已更新等級' });
});

router.delete('/levels/:id', canManage, async (req, res) => {
  const result = await levels.remove(v.id(req.params.id, '等級編號'), actorOf(req));
  res.status(200).json({ success: true, message: '已刪除等級', data: result });
});

module.exports = router;
