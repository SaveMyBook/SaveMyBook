const { rateLimit, byUser } = require('../../middleware/rateLimit');

// 傳訊、預約、轉帳與群組邀請共用同一個計數器。
const sendLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 60,
  key: byUser,
  message: '訊息傳送過於頻繁，請稍後再試'
});

const CHAT_IMAGE_RE = /^\/uploads\/chat\/[\w.-]+$/;

module.exports = { sendLimiter, CHAT_IMAGE_RE };
