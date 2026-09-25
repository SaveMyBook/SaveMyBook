const assert = require('assert');
const h = require('./harness');

const usage = h.usageService;
const runner = h.runner;
const { prisma, ai } = h;

const NOW = new Date(2026, 4, 10, 12, 0, 0);
const at = (day, hour = 9) => new Date(2026, 4, day, hour, 0, 0);

const logRow = () => prisma.rows('ai_usage_logs')[0];

module.exports = {
  name: 'AI 用量',
  tests: [
    ['寫入用量：token 數與延遲會被夾在合法範圍內，成本取到小數第六位', async () => {
      await usage.log({
        feature: 'support',
        provider: 'deepseek',
        model: 'deepseek-flash',
        userId: 7,
        usage: { input_tokens: -5, cached_tokens: 1e12, output_tokens: 12.6, search_calls: null },
        costUsd: 0.00012345678,
        latencyMs: 1234.4
      });
      const row = logRow();
      assert.strictEqual(row.input_tokens, 0);
      assert.strictEqual(row.cached_tokens, 4294967295);
      assert.strictEqual(row.output_tokens, 13);
      assert.strictEqual(row.search_calls, 0);
      assert.strictEqual(row.cost_usd, 0.000123);
      assert.strictEqual(row.latency_ms, 1234);
      assert.strictEqual(row.status, 'ok');
      assert.strictEqual(row.error_code, null);
    }],

    ['寫入用量：錯誤細節會被截斷，成本不可為負', async () => {
      await usage.log({
        feature: 'support',
        provider: 'gemini',
        model: 'gemini-3.1-flash-lite',
        costUsd: -3,
        status: 'error',
        errorCode: 'RATE_LIMITED',
        errorDetail: '錯'.repeat(500)
      });
      const row = logRow();
      assert.strictEqual(row.cost_usd, 0);
      assert.strictEqual(row.status, 'error');
      assert.strictEqual(row.error_code, 'RATE_LIMITED');
      assert.strictEqual(row.error_detail.length, 400);
    }],

    ['寫入用量失敗不會讓呼叫端拋錯', async () => {
      h.onSql(/INSERT INTO ai_usage_logs/, () => {
        throw new Error('資料表鎖定');
      });
      await usage.log({ feature: 'support', provider: 'gemini', model: 'm' });
      assert.strictEqual(prisma.rows('ai_usage_logs').length, 0);
    }],

    ['本月花費只計入當月，且每月預算為 0 時視為不限', async () => {
      h.addUsageLog({ cost_usd: 1.5, created_at: at(1) });
      h.addUsageLog({ cost_usd: 2.25, created_at: at(9) });
      h.addUsageLog({ cost_usd: 99, created_at: new Date(2026, 3, 30) });
      assert.strictEqual(await usage.monthCost(NOW), 3.75);
      assert.strictEqual(await usage.budgetExceeded(h.settings({ limits: { monthly_budget_usd: 0 } })), false);
    }],

    ['每月搜尋次數只計入同一服務商的當月紀錄', async () => {
      h.addUsageLog({ provider: 'gemini', search_calls: 30, created_at: at(2) });
      h.addUsageLog({ provider: 'gemini', search_calls: 12, created_at: at(8) });
      h.addUsageLog({ provider: 'openai', search_calls: 99, created_at: at(8) });
      h.addUsageLog({ provider: 'gemini', search_calls: 99, created_at: new Date(2026, 3, 20) });
      assert.strictEqual(await usage.monthSearchCalls('gemini', NOW), 42);
      assert.strictEqual(await usage.monthSearchCalls('openai', NOW), 99);
    }],

    ['每人每日次數只計入今日成功的同一功能', async () => {
      h.addUsageLog({ user_id: 5, feature: 'support', created_at: NOW });
      h.addUsageLog({ user_id: 5, feature: 'support', created_at: NOW });
      h.addUsageLog({ user_id: 5, feature: 'support', status: 'error', created_at: NOW });
      h.addUsageLog({ user_id: 5, feature: 'recommend', created_at: NOW });
      h.addUsageLog({ user_id: 6, feature: 'support', created_at: NOW });
      h.addUsageLog({ user_id: 5, feature: 'support', created_at: at(9) });
      assert.strictEqual(await usage.dailyCount(5, 'support', NOW), 2);
    }],

    ['超出每人每日次數時回 429 AI_DAILY_LIMIT', async () => {
      const settings = h.settings({ limits: { monthly_budget_usd: 10, daily_per_user: { support: 2, listing_assist: 15, recommend: 5, book_chat: 30 } } });
      h.addUsageLog({ user_id: 5, feature: 'support', created_at: new Date() });
      await runner.assertDailyLimit(settings, 'support', 5);
      h.addUsageLog({ user_id: 5, feature: 'support', created_at: new Date() });
      await assert.rejects(
        () => runner.assertDailyLimit(settings, 'support', 5),
        (err) => err.status === 429 && err.code === 'AI_DAILY_LIMIT' && err.message === '今日 AI 使用次數已達上限，請明日再試'
      );
      // 上限為 0 代表不限制。
      await runner.assertDailyLimit(h.settings({ limits: { daily_per_user: { support: 0 } } }), 'support', 5);
    }],

    ['本月花費達到預算時整組 AI 功能停用', async () => {
      h.setSettings({ enabled: true, limits: { monthly_budget_usd: 5 } });
      h.addUsageLog({ cost_usd: 4.999999, created_at: new Date() });
      assert.strictEqual(await runner.blocker(await h.settingsService.load(), 'support'), null);
      h.addUsageLog({ cost_usd: 0.000001, created_at: new Date() });
      assert.strictEqual(await runner.blocker(await h.settingsService.load(), 'support'), 'budget');
      await assert.rejects(
        () => runner.access('support'),
        (err) => err.status === 503 && err.code === 'AI_BUDGET_EXCEEDED' && err.message === 'AI 功能本月用量已達上限，請稍後再試'
      );
    }],

    ['未設定金鑰的服務商會回 AI_NOT_CONFIGURED', async () => {
      h.setSettings({ enabled: true, features: { support: { enabled: true, provider: 'openai' } } });
      await assert.rejects(
        () => runner.access('support'),
        (err) => err.status === 503 && err.code === 'AI_NOT_CONFIGURED' && err.message === 'AI 服務尚未完成設定'
      );
    }],

    ['呼叫成功會記錄用量與成本', async () => {
      const settings = h.settings();
      h.queueJson(() => ({
        text: '{}', json: {}, usage: { input_tokens: 1000, cached_tokens: 0, output_tokens: 1000, search_calls: 0 }, latency_ms: 42
      }));
      const result = await runner.call('support', { settings, provider: 'gemini', userId: 8, prompt: 'x' });
      assert.strictEqual(result.provider, 'gemini');
      assert.strictEqual(result.model, 'gemini-3.1-flash-lite');
      assert.strictEqual(result.cost_usd, 0.00175);

      const row = logRow();
      assert.strictEqual(row.feature, 'support');
      assert.strictEqual(row.provider, 'gemini');
      assert.strictEqual(row.user_id, 8);
      assert.strictEqual(row.latency_ms, 42);
      assert.strictEqual(row.cost_usd, 0.00175);
    }],

    ['搜尋呼叫會扣掉當月剩餘的免費額度後才計費', async () => {
      const settings = h.settings();
      h.addUsageLog({ provider: 'gemini', search_calls: 4995, created_at: new Date() });
      h.queueJson(() => ({
        text: '{}', json: {}, usage: { input_tokens: 0, cached_tokens: 0, output_tokens: 0, search_calls: 10 }, latency_ms: 5
      }));
      const result = await runner.call('listing_assist', { settings, provider: 'gemini', userId: 8, prompt: 'x', search: true });
      // 免費額度剩 5 次，其餘 5 次以每千次 14 美元計價。
      assert.strictEqual(result.cost_usd, 0.07);
      assert.strictEqual(h.calls[0].options.search, true);
    }],

    ['不支援搜尋的服務商不會送出搜尋旗標', async () => {
      const settings = h.settings();
      h.queueJson({ ok: true });
      await runner.call('listing_assist', { settings, provider: 'deepseek', userId: 8, prompt: 'x', search: true });
      assert.strictEqual(h.calls[0].options.search, false);
    }],

    ['呼叫失敗會記錄錯誤代碼與遮蔽後的服務商訊息，並原樣拋出', async () => {
      const settings = h.settings();
      const err = new ai.AiProviderError('QUOTA', { provider: 'gemini', providerMessage: 'quota for key=AIzaSecret123456 exhausted' });
      err.usage = { input_tokens: 100, output_tokens: 0 };
      err.latency_ms = 17;
      h.queueJson(err);

      await assert.rejects(
        () => runner.call('support', { settings, provider: 'gemini', userId: 8, prompt: 'x' }),
        (thrown) => thrown === err
      );
      const row = logRow();
      assert.strictEqual(row.status, 'error');
      assert.strictEqual(row.error_code, 'QUOTA');
      assert.strictEqual(row.latency_ms, 17);
      assert.strictEqual(row.input_tokens, 100);
      assert.ok(!row.error_detail.includes('AIzaSecret123456'));
      assert.ok(row.error_detail.includes('[redacted]'));
    }],

    ['非服務商錯誤一律轉成 502 並記為 INTERNAL', async () => {
      const settings = h.settings();
      h.queueJson(() => {
        throw new Error('資料庫連線中斷');
      });
      await assert.rejects(
        () => runner.call('support', { settings, provider: 'gemini', userId: 8, prompt: 'x' }),
        (err) => err instanceof ai.AiProviderError && err.status === 502 && err.reason === 'SERVER'
      );
      assert.strictEqual(logRow().error_code, 'INTERNAL');
      assert.strictEqual(logRow().error_detail, '資料庫連線中斷');
    }],

    ['期間換算：today、7d、30d 與 month 的起點', () => {
      assert.deepStrictEqual(usage.periodRange('today', NOW).from, new Date(2026, 4, 10));
      assert.deepStrictEqual(usage.periodRange('7d', NOW).from, new Date(2026, 4, 4));
      assert.deepStrictEqual(usage.periodRange('30d', NOW).from, new Date(2026, 3, 11));
      assert.deepStrictEqual(usage.periodRange('month', NOW).from, new Date(2026, 4, 1));
      assert.deepStrictEqual(usage.daysBetween(new Date(2026, 4, 8), NOW), ['2026-05-08', '2026-05-09', '2026-05-10']);
    }],

    ['月底預估花費以當月已過天數推估', () => {
      // 5 月共 31 天，10 日中午已過 9.5 天。
      assert.strictEqual(usage.projectMonth(95, NOW), Math.round((95 / 9.5) * 31 * 1e6) / 1e6);
      assert.strictEqual(usage.projectMonth(0, NOW), 0);
    }],

    ['報表：沒有用量時每一天仍會補上 0', async () => {
      const report = await usage.report('7d', { monthlyBudgetUsd: 10, now: NOW });
      assert.strictEqual(report.daily.length, 7);
      assert.deepStrictEqual(report.daily[0], { date: '2026-05-04', requests: 0, cost_usd: 0, by_feature: {} });
      assert.strictEqual(report.summary.requests, 0);
      assert.strictEqual(report.summary.cost_usd, 0);
      assert.strictEqual(report.summary.budget_used_ratio, 0);
      assert.deepStrictEqual(report.by_feature, []);
      assert.deepStrictEqual(report.top_users, []);
    }],

    ['報表：彙總請求數、錯誤數、token 與各功能花費', async () => {
      h.addUsageLog({ feature: 'support', provider: 'gemini', model: 'g', cost_usd: 1, input_tokens: 100, output_tokens: 20, latency_ms: 100, created_at: at(9) });
      h.addUsageLog({ feature: 'support', provider: 'gemini', model: 'g', cost_usd: 2, input_tokens: 200, output_tokens: 30, latency_ms: 300, created_at: at(10) });
      h.addUsageLog({ feature: 'recommend', provider: 'deepseek', model: 'd', cost_usd: 0.5, search_calls: 3, status: 'error', error_code: 'TIMEOUT', created_at: at(10) });

      const report = await usage.report('7d', { monthlyBudgetUsd: 10, now: NOW });
      assert.strictEqual(report.summary.requests, 3);
      assert.strictEqual(report.summary.errors, 1);
      assert.strictEqual(report.summary.input_tokens, 300);
      assert.strictEqual(report.summary.output_tokens, 50);
      assert.strictEqual(report.summary.search_calls, 3);
      assert.strictEqual(report.summary.cost_usd, 3.5);
      assert.strictEqual(report.summary.month_cost_usd, 3.5);
      assert.strictEqual(report.summary.monthly_budget_usd, 10);
      assert.strictEqual(report.summary.budget_used_ratio, 0.35);

      assert.deepStrictEqual(report.by_feature.map((f) => f.feature), ['support', 'recommend']);
      assert.strictEqual(report.by_feature[0].cost_usd, 3);
      assert.strictEqual(report.by_feature[1].errors, 1);
      assert.strictEqual(report.by_provider[0].provider, 'gemini');
      assert.strictEqual(report.by_provider[0].avg_latency_ms, 200);

      const days = Object.fromEntries(report.daily.map((d) => [d.date, d]));
      assert.strictEqual(days['2026-05-09'].requests, 1);
      assert.strictEqual(days['2026-05-10'].requests, 2);
      assert.strictEqual(days['2026-05-10'].by_feature.support, 2);
      assert.strictEqual(days['2026-05-08'].requests, 0);
    }],

    ['報表：用量最高的使用者只以加密編號呈現', async () => {
      const user = h.addUser({ nickname: '重度使用者' });
      h.addUsageLog({ user_id: user.user_id, cost_usd: 3, created_at: at(10) });
      h.addUsageLog({ user_id: user.user_id, cost_usd: 1, created_at: at(10) });
      h.addUsageLog({ user_id: null, cost_usd: 9, created_at: at(10) });

      const report = await usage.report('today', { monthlyBudgetUsd: 10, now: NOW });
      assert.strictEqual(report.top_users.length, 1);
      const [top] = report.top_users;
      assert.strictEqual(top.nickname, '重度使用者');
      assert.strictEqual(top.requests, 2);
      assert.strictEqual(top.cost_usd, 4);
      assert.strictEqual(top.user_public_id, h.api('lib/public-id').encode('user', user.user_id));
      assert.ok(top.user_public_id.startsWith('MB'));
      assert.strictEqual(JSON.stringify(top).includes('"user_id"'), false);
    }],

    ['報表：最近的錯誤保留代碼與細節，最多 10 筆', async () => {
      for (let i = 0; i < 12; i += 1) {
        h.addUsageLog({
          status: 'error', error_code: `E${i}`, error_detail: `細節 ${i}`, created_at: at(10, i)
        });
      }
      const report = await usage.report('today', { monthlyBudgetUsd: 0, now: NOW });
      assert.strictEqual(report.recent_errors.length, 10);
      assert.strictEqual(report.recent_errors[0].error_code, 'E11');
      assert.strictEqual(report.recent_errors[0].error_detail, '細節 11');
      assert.strictEqual(report.summary.budget_used_ratio, 0);
    }],

    ['報表：待審核書籍數量一併回報', async () => {
      prisma.store.ai_book_reviews = [
        { book_id: 1, status: 'pending' }, { book_id: 2, status: 'pending' }, { book_id: 3, status: 'approved' }
      ];
      const report = await usage.report('today', { monthlyBudgetUsd: 0, now: NOW });
      assert.strictEqual(report.pending_reviews, 2);
    }]
  ]
};
