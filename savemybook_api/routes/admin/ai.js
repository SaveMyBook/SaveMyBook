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
const semantic = require('../../services/ai/semantic');

const router = express.Router();
const canRunSystem = requireAdmin('system');
const canManageContent = requireAdmin('content');

const canViewUsage = async (req, res, next) => {
  if (await hasPermission(req.user, 'stats') || await hasPermission(req.user, 'system')) return next();
  res.status(403).json({ success: false, code: 'ADMIN_PERMISSION_REQUIRED', message: '您沒有「營運報表」或「系統維運」的權限' });
};

const testLimiter = rateLimit({ windowMs: 10 * 60 * 1000, max: 20, key: byUser, message: '測試次數過多，請稍後再試' });

const settingsPayload = async () => ({
  settings: await settingsService.load(),
  providers: settingsService.providerList(),
  retrieval: await semantic.status()
});

router.get('/ai/settings', canRunSystem, async (req, res) => {
  res.status(200).json({ success: true, data: await settingsPayload() });
});

router.put('/ai/settings', canRunSystem, requireVerification('admin'), async (req, res) => {
  const input = req.body?.settings;
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw badRequest('請提供 settings 設定內容');

  await settingsService.save(input, actorOf(req));
  runner.clearCache();
  semantic.reset();
  res.status(200).json({ success: true, message: '已更新 AI 設定', data: await settingsPayload() });
});

// 32×32 的紅色方塊：只回覆「紅」才算真的看到圖片，避免不支援影像的模型忽略圖片後仍被判為成功。
const TEST_IMAGE = {
  mimeType: 'image/png',
  data: 'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAIAAAD8GO2jAAAAKklEQVR42mO4IyJCU8QwasGoBaMWjFowasGoBaMWjFowasGoBaMWDBULAJ3LED19/LmKAAAAAElFTkSuQmCC'
};
const TEST_SYSTEM = '你是連線測試程式。';
const IMAGE_MISREAD = '回覆與測試圖片不符';

const TEST_CHECKS = [
  {
    name: 'text',
    label: '純文字',
    options: { prompt: '請只回覆「連線成功」四個字。' },
    verify: (r) => (String(r.text ?? '').trim() ? null : ai.REASON_DETAILS.INVALID_OUTPUT)
  },
  {
    name: 'json',
    label: 'JSON',
    options: { prompt: '請輸出 JSON 物件：{"status":"ok"}', json: true },
    verify: (r) => (r.json?.status === 'ok' ? null : ai.REASON_DETAILS.INVALID_OUTPUT)
  },
  {
    name: 'image',
    label: '圖片辨識',
    vision: true,
    options: { prompt: '這張圖片是什麼顏色？請只回覆顏色名稱。', images: [TEST_IMAGE] },
    verify: (r) => (/[紅红]|red/i.test(String(r.text ?? '')) ? null : IMAGE_MISREAD)
  }
];

const runCheck = async (check, { settings, provider, userId }) => {
  if (check.vision && !ai.PROVIDERS[provider].vision) return { name: check.name, status: 'skipped', latency_ms: 0, error: null };
  try {
    const result = await runner.call('test', { settings, provider, userId, system: TEST_SYSTEM, maxOutputTokens: 256, ...check.options });
    const error = check.verify(result);
    return {
      name: check.name,
      status: error ? 'failed' : 'ok',
      latency_ms: result.latency_ms,
      error,
      ...(check.name === 'text' && { reply: String(result.text ?? '').trim().slice(0, 200) })
    };
  } catch (err) {
    return { name: check.name, status: 'failed', latency_ms: err.latency_ms ?? 0, error: err.fullDetail ?? err.detail ?? ai.REASON_DETAILS.SERVER };
  }
};

router.post('/ai/test', canRunSystem, testLimiter, async (req, res) => {
  const provider = v.oneOf(req.body?.provider, ai.PROVIDER_IDS, `provider 僅接受：${ai.PROVIDER_IDS.join(', ')}`);
  const saved = await settingsService.load();
  const requested = req.body?.model;
  if (requested !== undefined && requested !== null && !settingsService.isModelName(requested)) {
    throw badRequest(`${ai.PROVIDERS[provider].name} 模型名稱格式不正確`);
  }
  const model = requested == null ? saved.providers[provider].model : requested.trim();
  const settings = { ...saved, providers: { ...saved.providers, [provider]: { ...saved.providers[provider], model } } };

  if (!ai.keyConfigured(provider)) {
    return res.status(200).json({
      success: true,
      data: { ok: false, provider, model, latency_ms: 0, error: ai.REASON_DETAILS.NOT_CONFIGURED, checks: [] }
    });
  }

  const results = await Promise.all(TEST_CHECKS.map((check) => runCheck(check, { settings, provider, userId: req.user.userId })));
  const failed = results.find((r) => r.status === 'failed');
  const text = results[0];
  res.status(200).json({
    success: true,
    data: {
      ok: !failed,
      provider,
      model,
      latency_ms: text.latency_ms,
      ...(text.reply !== undefined && { reply: text.reply }),
      ...(failed && { error: `${TEST_CHECKS.find((c) => c.name === failed.name).label}：${failed.error}` }),
      checks: results.map(({ reply, ...check }) => check)
    }
  });
});

router.get('/ai/usage', canViewUsage, async (req, res) => {
  const period = req.query.period
    ? v.oneOf(req.query.period, usage.PERIODS, `period 僅接受：${usage.PERIODS.join(', ')}`)
    : 'month';
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
