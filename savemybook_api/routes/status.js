const express = require('express');
const maintenance = require('../lib/maintenance');
const backup = require('../services/backup');
const { buildInfo } = require('../lib/build-info');
const { missingSchema } = require('../lib/schema-check');

const router = express.Router();

let schemaCache = { at: 0, migrations: [] };

const pendingMigrations = async () => {
  if (Date.now() - schemaCache.at < 60 * 1000) return schemaCache.migrations;
  try {
    const missing = await missingSchema();
    schemaCache = { at: Date.now(), migrations: [...new Set(missing.map((m) => m.migration))] };
  } catch {
    schemaCache = { at: Date.now(), migrations: schemaCache.migrations };
  }
  return schemaCache.migrations;
};

// 維護期間唯一放行的端點，不可掛驗證：還原時 users 表正在重建。
router.get('/', async (req, res) => {
  const m = maintenance.current();
  const r = backup.restoreStatus();
  const migrations = m.active ? schemaCache.migrations : await pendingMigrations();
  res.set('Cache-Control', 'no-store');
  res.status(200).json({
    success: true,
    data: {
      maintenance: m.active,
      message: m.message,
      restore: { state: r.state, started_at: r.started_at ?? null, finished_at: r.finished_at ?? null },
      api_revision: buildInfo.apiRevision,
      commit: buildInfo.commit,
      started_at: buildInfo.startedAt,
      pending_migrations: migrations
    }
  });
});

module.exports = router;
