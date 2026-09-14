require('dotenv').config();

const int = (value, fallback) => {
  const n = parseInt(value, 10);
  return Number.isFinite(n) ? n : fallback;
};

const env = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: int(process.env.PORT, 3000),
  databaseUrl: process.env.DATABASE_URL,
  jwtSecret: process.env.JWT_SECRET,
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '24h',
  publicWebUrl: (process.env.PUBLIC_WEB_URL || '').replace(/\/+$/, ''),
  googleBooksApiKey: process.env.GOOGLE_BOOKS_API_KEY || '',
  corsOrigins: (process.env.CORS_ORIGINS || 'https://savemybook.today,https://www.savemybook.today')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean),
  // 設成 true 會讓任何人偽造 X-Forwarded-For 繞過登入限流。
  trustProxy: process.env.TRUST_PROXY ?? 'loopback',
  backupEnabled: process.env.BACKUP_ENABLED !== 'false',
  backupDir: process.env.BACKUP_DIR || '',
  backupKeep: int(process.env.BACKUP_KEEP, 14),
  fcmServiceAccountFile: process.env.FCM_SERVICE_ACCOUNT_FILE || process.env.GOOGLE_APPLICATION_CREDENTIALS || '',
  pushEnabled: process.env.PUSH_ENABLED !== 'false'
};

const assertEnv = () => {
  const missing = [];
  if (!env.databaseUrl) missing.push('DATABASE_URL');
  if (!env.jwtSecret) missing.push('JWT_SECRET');
  if (missing.length) {
    console.error(`❌ 缺少必要的環境變數：${missing.join(', ')}`);
    process.exit(1);
  }
  if (env.jwtSecret.length < 32) {
    console.warn('⚠️  JWT_SECRET 長度不足 32 字元，容易被暴力破解，請盡快更換。');
  }
};

module.exports = { env, assertEnv };
