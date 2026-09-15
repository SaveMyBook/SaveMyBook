const express = require('express');
const requireAdmin = require('../../middleware/requireAdmin');
const { requireVerification } = require('../../middleware/verification');
const { rateLimit, byUser } = require('../../middleware/rateLimit');
const v = require('../../lib/validate');
const { actorOf } = require('../../lib/request-context');
const { badRequest } = require('../../lib/errors');
const { hasPermission } = require('../../services/admin-permissions');
const ai = require('../../lib/ai');
const settingsService = require('../../services/ai/settings');
const runner = require('../../services/ai/runner');
const usage = require('../../services/ai/usage');
const reviews = require('../../services/ai/reviews');

const router = express.Router();
const canRunSystem = requireAdmin('system');
const canManageContent = requireAdmin('content');

const canViewUsage = async (req, res, next) => {
  if (await hasPermission(req.user, 'stats') || await hasPermission(req.user, 'system')) return next();
  res.status(403).json({ success: false, code: 'ADMIN_PERMISSION_REQUIRED', message: '您沒有「營運報表」或「系統維運」的權限' });
};

const testLimiter = rateLimit({ windowMs: 10 * 60 * 1000, max: 20, key: byUser, message: '測試次數過多，請稍後再試' });

const settingsPayload = async () => {
  const ready = await settingsService.migrationReady();
  return {
    settings: ready ? await settingsService.load() : settingsService.normalize(null),
    providers: settingsService.providerList(),
    migration_ready: ready
  };
};

router.get('/ai/settings', canRunSystem, async (req, res) => {
  res.status(200).json({ success: true, data: await settingsPayload() });
});

router.put('/ai/settings', canRunSystem, requireVerification('sensitive'), async (req, res) => {
  const input = req.body?.settings;
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw badRequest('請提供 settings 設定內容');

  await settingsService.save(input, actorOf(req));
  runner.clearCache();
  res.status(200).json({ success: true, message: '已更新 AI 設定', data: await settingsPayload() });
});

router.post('/ai/test', canRunSystem, testLimiter, async (req, res) => {
  const provider = v.oneOf(req.body?.provider, ai.PROVIDER_IDS, `provider 僅接受：${ai.PROVIDER_IDS.join(', ')}`);
  const ready = await settingsService.migrationReady();
  const settings = ready ? await settingsService.load() : settingsService.normalize(null);
  const model = settings.providers[provider].model;

  if (!ai.keyConfigured(provider)) {
    return res.status(200).json({
      success: true,
      data: { ok: false, provider, model, latency_ms: 0, error: ai.REASON_DETAILS.NOT_CONFIGURED }
    });
  }

  const options = { system: '你是連線測試程式。', prompt: '請只回覆「連線成功」四個字。', maxOutputTokens: 256 };
  try {
    const result = ready
      ? await runner.call('test', { settings, provider, userId: req.user.userId, ...options })
      : { ...(await ai.generate(provider, { ...options, model })), model };
    res.status(200).json({
      success: true,
      data: { ok: true, provider, model: result.model, latency_ms: result.latency_ms, reply: String(result.text ?? '').trim().slice(0, 200) }
    });
  } catch (err) {
    res.status(200).json({
      success: true,
      data: { ok: false, provider, model, latency_ms: err.latency_ms ?? 0, error: err.detail ?? ai.REASON_DETAILS.SERVER }
    });
  }
});

router.get('/ai/usage', canViewUsage, async (req, res) => {
  const period = req.query.period
    ? v.oneOf(req.query.period, usage.PERIODS, `period 僅接受：${usage.PERIODS.join(', ')}`)
    : 'month';
  if (!(await settingsService.migrationReady())) throw settingsService.unavailable();
  const settings = await settingsService.load();
  const data = await usage.report(period, { monthlyBudgetUsd: settings.limits.monthly_budget_usd });
  res.status(200).json({ success: true, data });
});

router.get('/ai/reviews', canManageContent, async (req, res) => {
  const status = req.query.status === 'all'
    ? null
    : v.oneOf(req.query.status ?? 'pending', reviews.STATUSES, `status 僅接受：${reviews.STATUSES.join(', ')}, all`);
  res.status(200).json({ success: true, data: await reviews.adminList(status) });
});

router.patch('/ai/reviews/:bookId', canManageContent, async (req, res) => {
  const bookId = v.id(req.params.bookId, '書籍編號');
  const decision = v.oneOf(req.body?.decision, reviews.DECISIONS, 'decision 僅接受：approve, reject');
  const note = v.optionalText(req.body?.note, { label: '備註', max: 500 }) ?? null;

  const data = await reviews.decide(bookId, { decision, note }, actorOf(req));
  res.status(200).json({ success: true, message: decision === 'approve' ? '已核准上架' : '已駁回並下架', data });
});

module.exports = router;
