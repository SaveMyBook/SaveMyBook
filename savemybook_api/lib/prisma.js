require('dotenv').config();

const { PrismaClient } = require('@prisma/client');
const { PrismaMariaDb } = require('@prisma/adapter-mariadb');

if (!process.env.DATABASE_URL) {
  console.error('❌ Error: DATABASE_URL not found in environment variables!');
  process.exit(1);
}

const dbUrl = new URL(process.env.DATABASE_URL);

// DATABASE_URL 內的帳密可能是百分比編碼（密碼含 @ # / : 等字元時必須編碼）。
// 解不開就沿用原字串，避免密碼中帶有裸 % 時整個炸掉。
const decode = (value) => {
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
};

const adapter = new PrismaMariaDb({
  host: dbUrl.hostname,
  user: decode(dbUrl.username),
  password: decode(dbUrl.password),
  database: decode(dbUrl.pathname.substring(1)),
  port: parseInt(dbUrl.port, 10) || 3306,
  connectionLimit: 5,
  // MySQL 8 的 caching_sha2_password 首次連線需要 server 的 RSA 公鑰。
  // 非 TLS 連線時驅動預設不會自動索取，會出現 RSA public key is not
  // available client side 而連不上。DB 若不在本機，建議改用 TLS。
  allowPublicKeyRetrieval: true,
});

const prisma = new PrismaClient({
  adapter,
  log: ['error', 'warn'],
});

console.log('✅ Prisma Client initialized successfully.');

module.exports = prisma;
