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
  // MySQL 8 的 caching_sha2_password 在非 TLS 連線下需主動取得 RSA 公鑰，否則連不上。
  allowPublicKeyRetrieval: true,
});

const prisma = new PrismaClient({
  adapter,
  log: ['error', 'warn'],
});

module.exports = prisma;
