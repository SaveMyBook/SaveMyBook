const { env } = require('../config/env');

/// 分享連結的網址前綴。沒設 PUBLIC_WEB_URL 時退回請求的 host，
/// 但 Host 標頭可被偽造，正式環境務必設定。
const publicBase = (req) => env.publicWebUrl || `${req.protocol}://${req.get('host')}`;

module.exports = { publicBase };
