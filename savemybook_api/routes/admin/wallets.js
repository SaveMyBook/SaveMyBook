const express = require('express');
const requireAdmin = require('../../middleware/requireAdmin');
const { requireVerification } = require('../../middleware/verification');
const v = require('../../lib/validate');
const { actorOf } = require('../../lib/request-context');
const { badRequest } = require('../../lib/errors');
const wallet = require('../../services/wallet');

const router = express.Router();
const canManage = requireAdmin('wallets');

router.get('/wallets', canManage, async (req, res) => {
  const keyword = v.text(req.query.keyword, { label: '關鍵字', max: 100 });
  const { page, limit, skip } = v.pagination(req.query, { limit: 30 });

  const { rows, total } = await wallet.adminList({ keyword, skip, limit });
  res.status(200).json({ success: true, pagination: v.pageMeta(total, { page, limit }), data: rows });
});

router.get('/wallets/:userId', canManage, async (req, res) => {
  res.status(200).json({ success: true, data: await wallet.adminDetail(v.id(req.params.userId, '會員編號')) });
});

router.post('/wallets/:userId/adjust', canManage, requireVerification('sensitive'), async (req, res) => {
  const userId = v.id(req.params.userId, '會員編號');
  const amount = Number(req.body.amount);
  const description = v.text(req.body.description, { label: '調整原因', max: 200 });

  if (!Number.isFinite(amount) || amount === 0) throw badRequest('請輸入非零的調整金額');
  if (Math.abs(amount) > wallet.MAX_ADJUST) throw badRequest('單次調整不可超過 1,000,000');
  // 餘額欄位為 DECIMAL(12,2)，超過兩位小數會被資料庫默默四捨五入。
  if (Math.abs(amount * 100 - Math.round(amount * 100)) > 1e-6) throw badRequest('金額最多可至小數點後兩位');
  if (!description) throw badRequest('請填寫調整原因，此原因將記錄於帳務紀錄');

  const balance = await wallet.adjust(userId, { amount, description }, actorOf(req));
  res.status(200).json({ success: true, message: '已調整餘額', data: { balance } });
});

module.exports = router;
