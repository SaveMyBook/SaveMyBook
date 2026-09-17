const assert = require('assert');
const h = require('./harness');

const { prisma, request } = h;

const verifiedAs = (admin) => ({ 'x-verify-token': h.verifyTokenFor({ user: admin, scope: 'admin' }) });

const addLevel = (id, name, minPoints, extra = {}) => {
  const row = { level_id: id, level_name: name, min_points: minPoints, max_points: null, benefits: null, ...extra };
  prisma.rows('member_levels').push(row);
  return row;
};

const seedLevels = () => [
  addLevel(1, '一般會員', 0, { benefits: '基本功能' }),
  addLevel(2, '白銀會員', 100, { max_points: 5 }),
  addLevel(3, '黃金會員', 500)
];

const completedOrders = (buyerId, count) => {
  for (let i = 0; i < count; i += 1) {
    prisma.rows('orders').push({ order_id: prisma.nextId('orders'), buyer_id: buyerId, status: 'completed' });
  }
};

const as = (admin) => ({ token: h.tokenFor(admin), headers: verifiedAs(admin) });

module.exports = {
  name: '平台：會員等級管理',
  tests: [
    ['等級清單附上推算的點數上限與各等級會員人數', async () => {
      seedLevels();
      const admin = h.addUser({ role: 'admin' });
      h.addUser();
      const silver = h.addUser();
      completedOrders(silver.user_id, 12);
      const gold = h.addUser();
      gold.bonus_points = 600;
      const gone = h.addUser();
      gone.anonymized_at = new Date();
      gone.bonus_points = 900;

      const res = await request('GET', '/api/admin/levels', { token: h.tokenFor(admin) });
      assert.strictEqual(res.status, 200);
      assert.deepStrictEqual(
        res.body.data.map((l) => [l.level_name, l.min_points, l.max_points, l.member_count]),
        [['一般會員', 0, 99, 1], ['白銀會員', 100, 499, 1], ['黃金會員', 500, null, 1]]
      );
    }],

    ['新增等級：名稱與門檻不可與其他等級重複', async () => {
      seedLevels();
      const admin = h.addUser({ role: 'admin' });

      const sameName = await request('POST', '/api/admin/levels', {
        ...as(admin), body: { level_name: ' 黃金會員 ', min_points: 800 }
      });
      assert.strictEqual(sameName.status, 409);
      assert.strictEqual(sameName.body.code, 'LEVEL_NAME_TAKEN');

      const sameThreshold = await request('POST', '/api/admin/levels', {
        ...as(admin), body: { level_name: '鑽石會員', min_points: 500 }
      });
      assert.strictEqual(sameThreshold.status, 409);
      assert.strictEqual(sameThreshold.body.code, 'LEVEL_THRESHOLD_TAKEN');
      assert.strictEqual(sameThreshold.body.message, '「黃金會員」已使用 500 點作為門檻，每個等級的門檻須不同');

      const blank = await request('POST', '/api/admin/levels', { ...as(admin), body: { level_name: '  ', min_points: 900 } });
      assert.strictEqual(blank.status, 400);
      assert.strictEqual(blank.body.message, '請輸入等級名稱');

      const ok = await request('POST', '/api/admin/levels', {
        ...as(admin), body: { level_name: '鑽石會員', min_points: 1000, max_points: 3 }
      });
      assert.strictEqual(ok.status, 201);
      const created = prisma.rows('member_levels').find((l) => l.level_name === '鑽石會員');
      assert.strictEqual(created.min_points, 1000);
      assert.strictEqual(created.max_points, undefined);
      assert.strictEqual(h.prisma.rows('admin_operation_logs').length, 1);
    }],

    ['第一個等級的門檻須為 0 點', async () => {
      const admin = h.addUser({ role: 'admin' });
      const first = await request('POST', '/api/admin/levels', { ...as(admin), body: { level_name: '白銀會員', min_points: 100 } });
      assert.strictEqual(first.status, 400);
      assert.strictEqual(first.body.code, 'LEVEL_BASE_REQUIRED');
      assert.strictEqual(prisma.rows('member_levels').length, 0);

      seedLevels();
      const raised = await request('PUT', '/api/admin/levels/1', { ...as(admin), body: { level_name: '一般會員', min_points: 50 } });
      assert.strictEqual(raised.status, 400);
      assert.strictEqual(raised.body.code, 'LEVEL_BASE_REQUIRED');
      assert.strictEqual(prisma.rows('member_levels')[0].min_points, 0);
    }],

    ['編輯等級：保留自己的名稱與門檻不算重複，並記錄操作', async () => {
      seedLevels();
      const admin = h.addUser({ role: 'admin' });

      const res = await request('PUT', '/api/admin/levels/2', {
        ...as(admin), body: { level_name: '白銀會員', min_points: 200, benefits: '免運' }
      });
      assert.strictEqual(res.status, 200);
      const row = prisma.rows('member_levels').find((l) => l.level_id === 2);
      assert.strictEqual(row.min_points, 200);
      assert.strictEqual(row.benefits, '免運');

      const clash = await request('PUT', '/api/admin/levels/2', { ...as(admin), body: { level_name: '一般會員', min_points: 200 } });
      assert.strictEqual(clash.status, 409);

      const log = JSON.parse(prisma.rows('admin_operation_logs')[0].detail);
      assert.strictEqual(log.summary, '修改會員等級「白銀會員」的門檻點數、福利說明');
    }],

    ['刪除等級：回報會員改列的等級，起始等級不可刪除', async () => {
      seedLevels();
      const admin = h.addUser({ role: 'admin' });
      const member = h.addUser();
      member.bonus_points = 150;

      const base = await request('DELETE', '/api/admin/levels/1', as(admin));
      assert.strictEqual(base.status, 409);
      assert.strictEqual(base.body.code, 'LEVEL_BASE_REQUIRED');

      const res = await request('DELETE', '/api/admin/levels/2', as(admin));
      assert.strictEqual(res.status, 200);
      assert.deepStrictEqual(res.body.data, { moved_members: 1, moved_to: '一般會員' });
      const log = JSON.parse(prisma.rows('admin_operation_logs')[0].detail);
      assert.strictEqual(log.summary, '刪除會員等級「白銀會員」，1 位會員改列「一般會員」');

      prisma.store.member_levels = [];
      addLevel(9, '唯一等級', 0);
      const last = await request('DELETE', '/api/admin/levels/9', as(admin));
      assert.strictEqual(last.status, 200);
    }],

    ['調整順序：門檻依位置保留，名稱與福利隨等級移動', async () => {
      seedLevels();
      const admin = h.addUser({ role: 'admin' });

      const partial = await request('PUT', '/api/admin/levels/reorder', { ...as(admin), body: { order: [1, 2] } });
      assert.strictEqual(partial.status, 400);
      assert.strictEqual(partial.body.message, '排序資料須包含所有等級');

      const res = await request('PUT', '/api/admin/levels/reorder', { ...as(admin), body: { order: [1, 3, 2] } });
      assert.strictEqual(res.status, 200);
      const byId = Object.fromEntries(prisma.rows('member_levels').map((l) => [l.level_id, l.min_points]));
      assert.deepStrictEqual(byId, { 1: 0, 2: 500, 3: 100 });

      const log = JSON.parse(prisma.rows('admin_operation_logs')[0].detail);
      assert.strictEqual(log.summary, '調整會員等級順序為「一般會員」→「黃金會員」→「白銀會員」');
      assert.strictEqual(log.undo.length, 2);
    }],

    ['會員等級管理需要等級權限', async () => {
      const admin = h.addAdmin({ can_manage_levels: false });
      const res = await request('PUT', '/api/admin/levels/reorder', { ...as(admin), body: { order: [1] } });
      assert.strictEqual(res.status, 403);
    }]
  ]
};
