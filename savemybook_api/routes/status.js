const express = require('express');
const maintenance = require('../lib/maintenance');
const backup = require('../services/backup');

const router = express.Router();

// 維護期間唯一放行的端點，不可掛驗證：還原時 users 表正在重建。
router.get('/', (req, res) => {
  const m = maintenance.current();
  const r = backup.restoreStatus();
  res.set('Cache-Control', 'no-store');
  res.status(200).json({
    success: true,
    data: {
      maintenance: m.active,
      message: m.message,
      restore: { state: r.state, started_at: r.started_at ?? null, finished_at: r.finished_at ?? null }
    }
  });
});

module.exports = router;
