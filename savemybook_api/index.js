const { env, assertEnv } = require('./config/env');

assertEnv();

const { createApp } = require('./app');
const { startScheduler } = require('./jobs/scheduler');
const prisma = require('./lib/prisma');
const backup = require('./services/backup');
const realtime = require('./services/realtime');

const app = createApp();
const port = env.port;

const server = app.listen(port, () => {
  const { buildInfo } = require('./lib/build-info');
  console.log(`🚀 Server is running on http://localhost:${port}（API 版本 ${buildInfo.apiRevision}${buildInfo.commit ? `，commit ${buildInfo.commit}` : ''}）`);
  console.log(`📄 API 文件 (Scalar): http://localhost:${port}/api-docs`);
  console.log(`📦 OpenAPI 原始檔: http://localhost:${port}/openapi.json`);
  console.log(`💾 備份目錄: ${backup.BACKUP_DIR}（保留 ${backup.KEEP} 份）`);
});

const socket = realtime.attach(server);

const stopScheduler = startScheduler();

let shuttingDown = false;

const shutdown = (signal) => {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log(`收到 ${signal}，正在關閉伺服器…`);

  stopScheduler();
  socket.close();
  const force = setTimeout(() => process.exit(1), 10 * 1000);
  force.unref();

  server.close(async () => {
    await prisma.$disconnect().catch(() => {});
    process.exit(0);
  });
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

process.on('unhandledRejection', (reason) => {
  console.error('[未處理的 Promise rejection]:', reason);
});
