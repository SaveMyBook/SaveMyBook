require('dotenv').config();

const { PrismaClient } = require('@prisma/client');
const { PrismaMariaDb } = require('@prisma/adapter-mariadb');

if (!process.env.DATABASE_URL) {
  console.error('❌ Error: DATABASE_URL not found in environment variables!');
  process.exit(1);
}

const dbUrl = new URL(process.env.DATABASE_URL);

const adapter = new PrismaMariaDb({
  host: dbUrl.hostname,
  user: dbUrl.username,
  password: dbUrl.password,
  database: dbUrl.pathname.substring(1),
  port: parseInt(dbUrl.port, 10) || 3306,
  connectionLimit: 5 
});

const prisma = new PrismaClient({
  adapter,
  log: ['error', 'warn'], 
});

console.log('✅ Prisma Client initialized successfully.');

module.exports = prisma;