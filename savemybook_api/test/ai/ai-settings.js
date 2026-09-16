const assert = require('assert');
const h = require('./harness');

const settingsService = h.settingsService;
const { prisma, request } = h;

const rejectsBadRequest = (input, message) => {
  assert.throws(
    () => settingsService.normalize(input, { strict: true }),
    (err) => err.status === 400 && err.message === message,
    `預期 ${message}`
  );
};

const adminToken = (permissions) => {
  const admin = h.addAdmin(permissions);
  return { admin, token: h.tokenFor(admin) };
};

module.exports = {
  name: 'AI 設定',
  tests: [
    ['未提供設定時採用預設值，且總開關預設為關閉', () => {
      const value = settingsService.normalize(null);
      assert.strictEqual(value.enabled, false);
      assert.strictEqual(value.default_provider, 'deepseek');
      assert.strictEqual(value.providers.gemini.model, 'gemini-3.1-flash-lite');
      assert.strictEqual(value.features.listing_assist.web_search, true);
      assert.strictEqual(value.features.moderation.action, 'review');
      assert.strictEqual(value.limits.monthly_budget_usd, 10);
      assert.strictEqual(value.limits.daily_per_user.listing_assist, 15);
    }],

    ['讀取資料庫時，不合法的值靜默改回預設值', () => {
      const value = settingsService.normalize({
        enabled: 'yes',
        default_provider: 'claude',
        providers: { gemini: { model: '不合法的模型名稱！', input_per_m: -1 } },
        features: { moderation: { action: 'delete' }, support: { provider: 'nobody' } },
        limits: { monthly_budget_usd: 999999, daily_per_user: { support: 1.5 } }
      });
      assert.strictEqual(value.enabled, false);
      assert.strictEqual(value.default_provider, 'deepseek');
      assert.strictEqual(value.providers.gemini.model, 'gemini-3.1-flash-lite');
      assert.strictEqual(value.providers.gemini.input_per_m, 0.25);
      assert.strictEqual(value.features.moderation.action, 'review');
      assert.strictEqual(value.features.support.provider, null);
      assert.strictEqual(value.limits.monthly_budget_usd, 10);
      assert.strictEqual(value.limits.daily_per_user.support, 30);
    }],

    ['管理員送出不合法的值時逐項回報原因', () => {
      rejectsBadRequest({ enabled: 'yes' }, 'enabled 必須是 true 或 false');
      rejectsBadRequest({ default_provider: 'claude' }, '預設服務商僅接受：deepseek, gemini, openai');
      rejectsBadRequest({ providers: { gemini: { model: '模型 名稱' } } }, 'Google Gemini 模型名稱格式不正確');
      rejectsBadRequest({ providers: { deepseek: { input_per_m: 1001 } } }, 'DeepSeek 輸入單價必須是 0 ~ 1000 之間的數值');
      rejectsBadRequest(
        { providers: { gemini: { search_free_per_month: 1.5 } } },
        'Google Gemini 每月免費搜尋次數必須是 0 ~ 1000000 之間的整數'
      );
      rejectsBadRequest({ features: { support: { enabled: 1 } } }, 'AI 客服的 enabled 必須是 true 或 false');
      rejectsBadRequest(
        { features: { listing_assist: { provider: 'claude' } } },
        '上架輔助的服務商僅接受：deepseek, gemini, openai 或 null'
      );
      rejectsBadRequest({ features: { moderation: { action: 'delete' } } }, '上架審核的處理方式僅接受：review, block');
      rejectsBadRequest({ limits: { monthly_budget_usd: -1 } }, '每月預算必須是 0 ~ 100000 之間的數值');
      rejectsBadRequest({ limits: { daily_per_user: { book_chat: 20000 } } }, '書籍顧問每人每日次數必須是 0 ~ 10000 之間的整數');
    }],

    ['功能的服務商可以是 null，代表沿用預設服務商', () => {
      const value = settingsService.normalize({ features: { support: { provider: null } } }, { strict: true });
      assert.strictEqual(value.features.support.provider, null);
      assert.strictEqual(
        settingsService.normalize({ features: { support: { provider: 'openai' } } }, { strict: true }).features.support.provider,
        'openai'
      );
    }],

    ['設定差異以中文欄位名稱與可讀值呈現', () => {
      const before = settingsService.normalize(null);
      const after = settingsService.normalize({
        enabled: true,
        providers: { gemini: { model: 'gemini-3.1-pro' } },
        features: { support: { enabled: false } },
        limits: { monthly_budget_usd: 25, daily_per_user: { support: 5 } }
      });
      const changes = settingsService.diffSettings(before, after);
      const byField = Object.fromEntries(changes.map((c) => [c.field, c]));
      assert.deepStrictEqual(byField.enabled, { field: 'enabled', label: 'AI 功能總開關', from: '否', to: '是' });
      assert.strictEqual(byField['providers.gemini.model'].label, 'Google Gemini 模型');
      assert.strictEqual(byField['features.support.enabled'].label, 'AI 客服開關');
      assert.strictEqual(byField['limits.monthly_budget_usd'].label, '每月預算（美元）');
      assert.strictEqual(byField['limits.daily_per_user.support'].label, 'AI 客服每人每日次數');
      assert.strictEqual(settingsService.diffSettings(before, before).length, 0);
    }],

    ['服務商清單會標示金鑰是否已設定與能力', () => {
      const list = settingsService.providerList();
      assert.deepStrictEqual(list.map((p) => p.id), ['deepseek', 'gemini', 'openai']);
      assert.strictEqual(list.find((p) => p.id === 'gemini').key_configured, true);
      assert.strictEqual(list.find((p) => p.id === 'openai').key_configured, false);
      assert.strictEqual(list.find((p) => p.id === 'deepseek').vision, false);
      assert.strictEqual(list.find((p) => p.id === 'gemini').web_search, true);
    }],

    ['尚未執行 011 時儲存設定回 503 AI_UNAVAILABLE', async () => {
      h.reset({ schema: h.without(h.DEFAULT_SCHEMA, ['ai_settings']) });
      await assert.rejects(
        () => settingsService.save({ enabled: true }, { adminId: 1, req: null }),
        (err) => err.status === 503
          && err.code === 'AI_UNAVAILABLE'
          && err.message === 'AI 功能目前無法使用，伺服器尚未完成資料庫更新'
      );
    }],

    ['儲存設定會寫入資料庫並留下操作紀錄', async () => {
      const admin = h.addAdmin({ can_manage_system: true });
      const saved = await settingsService.save(
        { enabled: true, limits: { monthly_budget_usd: 25 } },
        { adminId: admin.user_id, req: { ip: '10.1.2.3' } }
      );
      assert.strictEqual(saved.enabled, true);
      assert.strictEqual(saved.limits.monthly_budget_usd, 25);

      const rows = prisma.rows('ai_settings');
      assert.strictEqual(rows.length, 1);
      assert.strictEqual(JSON.parse(rows[0].config).limits.monthly_budget_usd, 25);
      assert.strictEqual(await settingsService.load().then((s) => s.enabled), true);

      const [log] = prisma.rows('admin_operation_logs');
      assert.strictEqual(log.action, '修改 AI 設定');
      assert.strictEqual(log.ip_address, '10.1.2.3');
      const detail = JSON.parse(log.detail);
      assert.ok(detail.summary.includes('AI 功能總開關'));
      assert.ok(detail.summary.includes('每月預算（美元）'));
      assert.ok(detail.changes.some((c) => c.field === 'enabled' && c.to === '是'));
    }],

    ['再次儲存相同設定時只留下「無實際變更」的紀錄', async () => {
      const admin = h.addAdmin({ can_manage_system: true });
      await settingsService.save({ enabled: true }, { adminId: admin.user_id, req: null });
      await settingsService.save({ enabled: true }, { adminId: admin.user_id, req: null });
      assert.strictEqual(prisma.rows('ai_settings').length, 1);
      const logs = prisma.rows('admin_operation_logs');
      assert.strictEqual(logs.length, 2);
      assert.strictEqual(JSON.parse(logs[1].detail).summary, '重新儲存 AI 設定（無實際變更）');
      assert.deepStrictEqual(JSON.parse(logs[1].detail).changes, []);
    }],

    ['讀取設定：沒有「系統維運」權限的管理員一律被擋下', async () => {
      const { token } = adminToken({ can_manage_system: false });
      const res = await request('GET', '/api/admin/ai/settings', { token });
      assert.strictEqual(res.status, 403);
      assert.strictEqual(res.body.code, 'ADMIN_PERMISSION_REQUIRED');
      assert.ok(res.body.message.includes('系統維運'));
    }],

    ['讀取設定：一般會員連管理員身分檢查都過不了', async () => {
      const token = h.tokenFor(h.addUser());
      const res = await request('GET', '/api/admin/ai/settings', { token });
      assert.strictEqual(res.status, 403);
      assert.strictEqual(res.body.message, '權限不足，僅限管理員執行此操作');
    }],

    ['讀取設定：具備權限時回傳設定、服務商清單與資料庫狀態', async () => {
      const { token } = adminToken({ can_manage_system: true });
      h.setSettings({ enabled: true });
      const res = await request('GET', '/api/admin/ai/settings', { token });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.data.migration_ready, true);
      assert.strictEqual(res.body.data.settings.enabled, true);
      assert.strictEqual(res.body.data.providers.length, 3);
    }],

    ['更新設定：settings 不是物件時回 400', async () => {
      const { token } = adminToken({ can_manage_system: true });
      for (const body of [{}, { settings: [] }, { settings: 'on' }]) {
        const res = await request('PUT', '/api/admin/ai/settings', { token, body });
        assert.strictEqual(res.status, 400);
        assert.strictEqual(res.body.message, '請提供 settings 設定內容');
      }
    }],

    ['更新設定：成功後回傳最新設定', async () => {
      const { token } = adminToken({ can_manage_system: true });
      const res = await request('PUT', '/api/admin/ai/settings', {
        token,
        body: { settings: { enabled: true, features: { recommend: { enabled: false } } } }
      });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.message, '已更新 AI 設定');
      assert.strictEqual(res.body.data.settings.enabled, true);
      assert.strictEqual(res.body.data.settings.features.recommend.enabled, false);
    }],

    ['用量報表：需要「營運報表」或「系統維運」其中之一', async () => {
      const denied = adminToken({ can_view_stats: false, can_manage_system: false });
      const res = await request('GET', '/api/admin/ai/usage', { token: denied.token });
      assert.strictEqual(res.status, 403);
      assert.strictEqual(res.body.code, 'ADMIN_PERMISSION_REQUIRED');
      assert.strictEqual(res.body.message, '您沒有「營運報表」或「系統維運」的權限');

      const allowed = adminToken({ can_view_stats: true, can_manage_system: false });
      h.setSettings({ enabled: true });
      const ok = await request('GET', '/api/admin/ai/usage?period=7d', { token: allowed.token });
      assert.strictEqual(ok.status, 200);
      assert.strictEqual(ok.body.data.period, '7d');
    }],

    ['用量報表：不支援的期間回 400', async () => {
      const { token } = adminToken({ can_view_stats: true });
      const res = await request('GET', '/api/admin/ai/usage?period=year', { token });
      assert.strictEqual(res.status, 400);
      assert.strictEqual(res.body.message, 'period 僅接受：today, 7d, 30d, month');
    }],

    ['上架審核清單需要「內容管理」權限', async () => {
      const denied = adminToken({ can_manage_content: false });
      const res = await request('GET', '/api/admin/ai/reviews', { token: denied.token });
      assert.strictEqual(res.status, 403);
      assert.strictEqual(res.body.message, '您沒有「內容管理」的權限');
    }]
  ]
};
