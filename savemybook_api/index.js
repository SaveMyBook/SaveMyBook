require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');

const { apiReference } = require('@scalar/express-api-reference');
const { buildSpec } = require('./config/openapi');
const { processDueDeletions } = require('./lib/account');
const backup = require('./lib/backup');
const userRoutes = require('./routes/users');
const authRoutes = require('./routes/auth');
const bookRoutes = require('./routes/books');
const categoriesRoutes = require('./routes/categories');
const cabinetRoutes = require('./routes/cabinets');
const favoriteRoutes = require('./routes/favorites');
const cartRoutes = require('./routes/cart');
const orderRoutes = require('./routes/orders');
const notificationRoutes = require('./routes/notifications');
const chatRoutes = require('./routes/chat');
const walletRoutes = require('./routes/wallet');
const disputeRoutes = require('./routes/disputes');
const reportRoutes = require('./routes/reports');
const announcementRoutes = require('./routes/announcements');
const adminRoutes = require('./routes/admin');
const uploadRoutes = require('./routes/uploads');
const supportRoutes = require('./routes/support');
const publicRoutes = require('./routes/public');

const app = express();
const port = process.env.PORT || 3000;

app.use(cors({
    origin: ['https://savemybook.today', 'https://www.savemybook.today']
}));
app.use(express.json());

app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// 文件在啟動時組一次並快取，改 docs/*.yaml 需重啟才會生效。
const openapiSpec = buildSpec();

app.get('/openapi.json', (req, res) => res.json(openapiSpec));

app.use(
  '/api-docs',
  apiReference({
    content: openapiSpec,
    theme: 'default',
    layout: 'modern',
    hideModels: false,
    hideDownloadButton: false,
    defaultHttpClient: { targetKey: 'shell', clientKey: 'curl' },
    metaData: {
      title: 'SaveMyBook API 文件',
      description: 'SaveMyBook 二手書交易平台的完整 API 文件'
    }
  })
);

app.use('/api/users', userRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/books', bookRoutes);
app.use('/api/categories', categoriesRoutes);
app.use('/api/cabinets', cabinetRoutes);
app.use('/api/favorites', favoriteRoutes);
app.use('/api/cart', cartRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/wallet', walletRoutes);
app.use('/api/disputes', disputeRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/announcements', announcementRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/uploads', uploadRoutes);
app.use('/api/support', supportRoutes);
app.use('/', publicRoutes);

app.get('/', (req, res) => {
  res.send('SaveMyBook API is running. Visit /api-docs for API documentation.');
});

// ==========================================
// 排程
// ------------------------------------------
// 用 setInterval 而不是 cron：這支服務是單一行程常駐，不需要為了兩個
// 週期性工作多裝一個排程器。重啟後從當下重新計時，漏跑一次的影響有限
// （刪除有 30 天緩衝、備份保留 14 份）。
// ==========================================
const HOUR = 3600 * 1000;

const runDeletionSweep = async () => {
  try {
    const count = await processDueDeletions();
    if (count > 0) console.log(`🗑️  已匿名化 ${count} 個逾期帳號`);
  } catch (err) {
    console.error('[刪除排程失敗]:', err);
  }
};

const runDailyBackup = async () => {
  if (process.env.BACKUP_ENABLED === 'false') return;
  try {
    const record = await backup.run({ trigger: 'schedule' });
    console.log(`💾 資料庫已備份：${record.file_name}`);
  } catch (err) {
    console.error('[備份排程失敗]:', err.message);
  }
};

setInterval(runDeletionSweep, HOUR);
setInterval(runDailyBackup, 24 * HOUR);

// 啟動後先掃一次逾期刪除；備份不在啟動時跑，避免頻繁重啟灌爆備份區。
setTimeout(runDeletionSweep, 30 * 1000);

app.listen(port, () => {
  console.log(`🚀 Server is running on http://localhost:${port}`);
  console.log(`🔗 Users API: http://localhost:${port}/api/users`);
  console.log(`🔐 Auth API: http://localhost:${port}/api/auth/login`);
  console.log(`📚 Books API: http://localhost:${port}/api/books`);
  console.log(`📂 Categories API: http://localhost:${port}/api/categories`);
  console.log(`🗄️ Cabinets API: http://localhost:${port}/api/cabinets`);
  console.log(`🛒 Cart / Orders API: http://localhost:${port}/api/cart, /api/orders`);
  console.log(`🔔 Notifications API: http://localhost:${port}/api/notifications`);
  console.log(`💬 Chat API: http://localhost:${port}/api/chat`);
  console.log(`🪙 Wallet API: http://localhost:${port}/api/wallet`);
  console.log(`🛡️ Admin API: http://localhost:${port}/api/admin`);
  console.log(`👤 公開個人頁: http://localhost:${port}/u/1`);
  console.log(`📄 API 文件 (Scalar): http://localhost:${port}/api-docs`);
  console.log(`📦 OpenAPI 原始檔: http://localhost:${port}/openapi.json`);
  console.log(`💾 備份目錄: ${backup.BACKUP_DIR}（保留 ${backup.KEEP} 份）`);
});