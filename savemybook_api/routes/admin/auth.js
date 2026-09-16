const express = require('express');
const requireAdmin = require('../../middleware/requireAdmin');
const { requireVerification } = require('../../middleware/verification');
const { actorOf } = require('../../lib/request-context');
const { badRequest } = require('../../lib/errors');
const authSettings = require('../../services/auth-settings');

const router = express.Router();
const canRunSystem = requireAdmin('system');

const settingsPayload = async () => {
  const ready = await authSettings.migrationReady();
  return {
    settings: ready ? await authSettings.load() : authSettings.normalize(null),
    providers: authSettings.providerList(),
    migration_ready: ready
  };
};

router.get('/auth/settings', canRunSystem, async (req, res) => {
  res.status(200).json({ success: true, data: await settingsPayload() });
});

router.put('/auth/settings', canRunSystem, requireVerification('admin'), async (req, res) => {
  const input = req.body?.settings;
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw badRequest('請提供 settings 設定內容');

  await authSettings.save(input, actorOf(req));
  res.status(200).json({ success: true, message: '已更新登入方式設定', data: await settingsPayload() });
});

module.exports = router;
