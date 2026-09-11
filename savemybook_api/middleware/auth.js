const jwt = require('jsonwebtoken');
const prisma = require('../lib/prisma');

/// 每次請求都回資料庫確認帳號狀態。只驗 JWT 簽章的話，停權與黑名單要等
/// token 自然過期才生效，期間被停權者仍可持舊 token 呼叫全部端點；
/// role 被降級同理。代價是每個請求多一次 DB 查詢。
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ success: false, message: '存取被拒，未提供 Token' });
  }

  jwt.verify(token, process.env.JWT_SECRET, async (err, decodedUser) => {
    if (err) {
      return res.status(403).json({ success: false, message: 'Token 無效或已過期' });
    }

    try {
      const user = await prisma.users.findUnique({
        where: { user_id: decodedUser.userId },
        select: { user_id: true, role: true, is_active: true, is_blacklisted: true }
      });

      if (!user) {
        return res.status(401).json({
          success: false,
          code: 'ACCOUNT_NOT_FOUND',
          message: '帳號不存在，請重新登入'
        });
      }

      if (user.is_blacklisted) {
        return res.status(401).json({
          success: false,
          code: 'ACCOUNT_BLACKLISTED',
          message: '此帳號已被列入黑名單，如有疑問請聯絡客服'
        });
      }

      if (!user.is_active) {
        return res.status(401).json({
          success: false,
          code: 'ACCOUNT_INACTIVE',
          message: '此帳號已被停權，如有疑問請聯絡客服'
        });
      }

      // role 以資料庫為準，管理員被降級後立刻失效。
      req.user = { ...decodedUser, userId: user.user_id, role: user.role };
      next();
    } catch (dbErr) {
      console.error('[驗證帳號狀態失敗]:', dbErr);
      res.status(500).json({ success: false, message: '伺服器發生錯誤' });
    }
  });
};

module.exports = authenticateToken;
