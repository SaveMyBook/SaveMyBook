const express = require('express');
const v = require('../../lib/validate');
const { requireVerification } = require('../../middleware/verification');
const transfers = require('../../services/chat/transfers');
const { sendLimiter } = require('./limits');

const router = express.Router();

// 先驗證參數再要求交易密碼，避免使用者輸入密碼後才得知金額格式錯誤。
const parseTransfer = (counterpartKey) => (req, res, next) => {
  req.transfer = {
    roomId: v.id(req.params.roomId, '聊天室編號'),
    counterpartId: v.optionalId(req.body[counterpartKey], '對象的使用者編號'),
    amount: v.int(req.body.amount, { label: '金額', min: 1, max: transfers.MAX_AMOUNT }),
    note: v.optionalText(req.body.note, { label: '備註', max: transfers.MAX_NOTE_LENGTH }) ?? null
  };
  next();
};

router.post('/rooms/:roomId/transfers', sendLimiter, parseTransfer('to_user_id'), requireVerification('payment'), async (req, res) => {
  const { roomId, counterpartId, amount, note } = req.transfer;
  const data = await transfers.send(roomId, req.user.userId, { toUserId: counterpartId, amount, note });
  res.status(201).json({ success: true, message: '轉帳完成', data });
});

router.post('/rooms/:roomId/transfer-requests', sendLimiter, parseTransfer('from_user_id'), async (req, res) => {
  const { roomId, counterpartId, amount, note } = req.transfer;
  const data = await transfers.request(roomId, req.user.userId, { fromUserId: counterpartId, amount, note });
  res.status(201).json({ success: true, message: '已送出請款', data });
});

router.post('/transfers/:id/pay', requireVerification('payment'), async (req, res) => {
  const data = await transfers.respond(v.id(req.params.id, '轉帳編號'), req.user.userId, 'pay');
  res.status(200).json({ success: true, message: '付款完成', data });
});

router.post('/transfers/:id/decline', async (req, res) => {
  const data = await transfers.respond(v.id(req.params.id, '轉帳編號'), req.user.userId, 'decline');
  res.status(200).json({ success: true, message: '已婉拒請款', data });
});

router.post('/transfers/:id/cancel', async (req, res) => {
  const data = await transfers.respond(v.id(req.params.id, '轉帳編號'), req.user.userId, 'cancel');
  res.status(200).json({ success: true, message: '已取消請款', data });
});

module.exports = router;
