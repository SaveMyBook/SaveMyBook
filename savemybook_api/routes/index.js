const MOUNTS = [
  // 通行密鑰須排在 /api/users、/api/auth 之前，才不會被 /:id 等路由攔走。
  ['/api/users/me/passkeys', './user-passkeys'],
  ['/api/auth/passkeys', './passkeys'],
  ['/api/users', './users'],
  ['/api/auth', './auth'],
  ['/api/security', './security'],
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
  ['/api/backup-downloads', './backup-downloads'],
  ['/api/admin', './admin'],
  ['/api/uploads', './uploads'],
  ['/api/support', './support'],
  ['/api/push', './push'],
  ['/api/status', './status'],
  ['/api/ai', './ai'],
  ['/.well-known', './well-known'],
  ['/', './public']
];

const registerRoutes = (app) => {
  for (const [prefix, modulePath] of MOUNTS) {
    app.use(prefix, require(modulePath));
  }
};

module.exports = { MOUNTS, registerRoutes };
