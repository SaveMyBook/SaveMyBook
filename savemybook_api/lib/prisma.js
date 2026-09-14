const { PrismaClient } = require('@prisma/client');
const { PrismaMariaDb } = require('@prisma/adapter-mariadb');
const { env } = require('../config/env');
const { parseDatabaseUrl } = require('./db-url');

if (!env.databaseUrl) {
  console.error('❌ Error: DATABASE_URL not found in environment variables!');
  process.exit(1);
}

const adapter = new PrismaMariaDb({
  ...parseDatabaseUrl(env.databaseUrl),
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

module.exports = prisma;
