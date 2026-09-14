/// 掛載表。scripts/check-docs.js 直接讀這張表比對文件，改路徑時兩邊不必各改一次。
const MOUNTS = [
  ['/api/users', './users'],
  ['/api/auth', './auth'],
  ['/api/books', './books'],
  ['/api/categories', './categories'],
  ['/api/cabinets', './cabinets'],
  ['/api/favorites', './favorites'],
  ['/api/cart', './cart'],
  ['/api/orders', './orders'],
  ['/api/notifications', './notifications'],
  ['/api/chat', './chat'],
  ['/api/wallet', './wallet'],
  ['/api/disputes', './disputes'],
  ['/api/reports', './reports'],
  ['/api/announcements', './announcements'],
  ['/api/admin', './admin'],
  ['/api/uploads', './uploads'],
  ['/api/support', './support'],
  ['/api/push', './push'],
  ['/', './public']
];

const registerRoutes = (app) => {
  for (const [prefix, modulePath] of MOUNTS) {
    app.use(prefix, require(modulePath));
  }
};

module.exports = { MOUNTS, registerRoutes };
