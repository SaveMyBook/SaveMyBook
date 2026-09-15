const MOUNTS = [
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
  ['/api/admin', './admin'],
  ['/api/uploads', './uploads'],
  ['/api/support', './support'],
  ['/api/push', './push'],
  ['/api/status', './status'],
  ['/api/ai', './ai'],
  ['/', './public']
];

const registerRoutes = (app) => {
  for (const [prefix, modulePath] of MOUNTS) {
    app.use(prefix, require(modulePath));
  }
};

module.exports = { MOUNTS, registerRoutes };
