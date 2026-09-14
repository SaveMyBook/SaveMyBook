const { env } = require('../config/env');

// Host 標頭可被偽造，正式環境務必設定 PUBLIC_WEB_URL。
const publicBase = (req) => env.publicWebUrl || `${req.protocol}://${req.get('host')}`;

module.exports = { publicBase };
