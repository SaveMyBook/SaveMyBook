const assert = require('assert');
const h = require('./harness');

const alerts = h.api('services/ai/budget-alerts');
const { prisma } = h;

const NOW = new Date(2026, 8, 20, 12, 0, 0);

// 迷你假 Prisma 不支援 select 關聯，改以覆寫回傳管理員與其權限列，仍由 adminIdsWith 依權限篩選。
const admins = () => {
  const system = h.addAdmin({ can_manage_system: 1 });
  const content = h.addAdmin({ can_manage_system: 0, can_manage_content: 1 });
  h.onModel('users.findMany', () => [system, content].map((a) => ({
    user_id: a.user_id,
    admin_permissions: prisma.rows('admin_permissions').find((p) => p.user_id === a.user_id)
  })));
  return { system, content };
};

const noticesOf = (userId) => prisma.rows('notifications').filter((n) => n.user_id === userId);

module.exports = {
  name: 'AI 預算通知',
  tests: [
    ['費用達預算 80% 時通知具系統維運權限的管理員，同一門檻每月只通知一次', async () => {
      h.setSettings({ enabled: true, limits: { monthly_budget_usd: 10, reserve_ratio: 0.2 } });
      const { system, content } = admins();
      h.addUsageLog({ cost_usd: 7.9, created_at: NOW });
      assert.strictEqual(await alerts.check(NOW), null);

      h.addUsageLog({ cost_usd: 0.2, created_at: NOW });
      assert.strictEqual(await alerts.check(NOW), 80);
      const [notice] = noticesOf(system.user_id);
      assert.strictEqual(notice.title, 'AI 費用已達本月預算的 80%');
      assert.strictEqual(notice.content, '本月 AI 費用 US$ 8.10，每月預算 US$ 10.00。會員端 AI 功能已暫停，上架審核與管理輔助仍可使用至預算上限。');
      assert.strictEqual(notice.related_type, 'ai_budget');
      assert.strictEqual(noticesOf(content.user_id).length, 0);

      assert.strictEqual(await alerts.check(NOW), null);
      assert.strictEqual(noticesOf(system.user_id).length, 1);

      h.addUsageLog({ cost_usd: 2, created_at: NOW });
      assert.strictEqual(await alerts.check(NOW), 100);
      assert.strictEqual(noticesOf(system.user_id)[1].content, '本月 AI 費用 US$ 10.10，每月預算 US$ 10.00。所有 AI 功能已暫停，下月起或調高預算後恢復。');
    }],

    ['同一輪跨過兩個門檻時只通知最高的一個，兩個門檻都記錄為已通知', async () => {
      h.setSettings({ enabled: true, limits: { monthly_budget_usd: 10 } });
      const { system } = admins();
      h.addUsageLog({ cost_usd: 12, created_at: NOW });
      assert.strictEqual(await alerts.check(NOW), 100);
      assert.strictEqual(noticesOf(system.user_id).length, 1);
      assert.deepStrictEqual(prisma.rows('ai_budget_alerts').map((r) => [r.month, r.threshold]), [['2026-09', 80], ['2026-09', 100]]);
      assert.strictEqual(await alerts.check(NOW), null);
    }],

    ['保留比例低於 20% 時，80% 的通知不會說會員功能已暫停', async () => {
      h.setSettings({ enabled: true, limits: { monthly_budget_usd: 10, reserve_ratio: 0.1 } });
      const { system } = admins();
      h.addUsageLog({ cost_usd: 8.5, created_at: NOW });
      assert.strictEqual(await alerts.check(NOW), 80);
      assert.strictEqual(noticesOf(system.user_id)[0].content, '本月 AI 費用 US$ 8.50，每月預算 US$ 10.00。');
    }],

    ['通知寫入失敗時門檻紀錄一併回滾，下一輪仍會通知', async () => {
      h.setSettings({ enabled: true, limits: { monthly_budget_usd: 10 } });
      const { system } = admins();
      h.addUsageLog({ cost_usd: 8.5, created_at: NOW });
      // 假 Prisma 的交易不會回滾，這裡模擬資料庫的行為：交易失敗時還原交易內寫入的門檻紀錄。
      const original = prisma.$transaction;
      prisma.$transaction = async (fn) => {
        const saved = [...prisma.rows('ai_budget_alerts')];
        try {
          return await original.call(prisma, fn);
        } catch (err) {
          prisma.store.ai_budget_alerts = saved;
          throw err;
        }
      };
      h.onModel('notifications.createMany', () => {
        throw new Error('Deadlock found when trying to get lock');
      });
      try {
        await assert.rejects(alerts.check(NOW), /Deadlock/);
        assert.strictEqual(prisma.rows('ai_budget_alerts').length, 0);

        delete h.state.models['notifications.createMany'];
        assert.strictEqual(await alerts.check(NOW), 80);
        assert.strictEqual(noticesOf(system.user_id).length, 1);
      } finally {
        prisma.$transaction = original;
      }
    }],

    ['不設預算時不通知', async () => {
      h.setSettings({ enabled: true, limits: { monthly_budget_usd: 0 } });
      admins();
      h.addUsageLog({ cost_usd: 999, created_at: NOW });
      assert.strictEqual(await alerts.check(NOW), null);
      assert.strictEqual(prisma.rows('notifications').length, 0);
    }]
  ]
};
