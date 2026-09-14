const express = require('express');
const prisma = require('../../lib/prisma');
const requireAdmin = require('../../middleware/requireAdmin');
const v = require('../../lib/validate');
const password = require('../../lib/password');
const { badRequest, forbidden, notFound, conflict } = require('../../lib/errors');
const { USER_ROLES } = require('../../constants/domain');
const levels = require('../../services/levels');
const { notify } = require('../../services/notify');
const { logAction } = require('../../services/audit');
const push = require('../../services/push');

const router = express.Router();
const canManage = requireAdmin('members');

const PERMISSION_KEYS = [
  'can_manage_members',
  'can_manage_levels',
  'can_manage_content',
  'can_manage_reports',
  'can_manage_orders',
  'can_manage_transactions',
  'can_manage_wallets',
  'can_manage_cabinets',
  'can_manage_announcements',
  'can_manage_support',
  'can_view_stats',
  'can_manage_system'
];

const MAX_BONUS = 1000000;

const assertNotSelf = (req, userId, message) => {
  if (userId === req.user.userId) throw badRequest(message);
};

router.get('/members', canManage, async (req, res) => {
  const keyword = v.text(req.query.keyword, { label: '關鍵字', max: 100 });
  const status = req.query.status;
  const { page, limit, skip } = v.pagination(req.query);

  const where = {
    ...(keyword && {
      OR: [{ nickname: { contains: keyword } }, { email: { contains: keyword } }]
    }),
    ...(status === 'blacklisted' && { is_blacklisted: true }),
    ...(status === 'inactive' && { is_active: false }),
    ...(status === 'active' && { is_active: true, is_blacklisted: false })
  };

  const [members, total] = await Promise.all([
    prisma.users.findMany({
      where,
      skip,
      take: limit,
      orderBy: { created_at: 'desc' },
      select: {
        user_id: true, email: true, nickname: true, avatar_url: true, phone: true,
        role: true, is_active: true, is_blacklisted: true, created_at: true,
        _count: {
          select: {
            books: true,
            orders_orders_buyer_idTousers: true,
            orders_orders_seller_idTousers: true
          }
        }
      }
    }),
    prisma.users.count({ where })
  ]);

  res.status(200).json({ success: true, pagination: v.pageMeta(total, { page, limit }), data: members });
});

router.get('/members/:id', canManage, async (req, res) => {
  const userId = v.id(req.params.id, '會員編號');

  const [user, allLevels, completedOrders, viewerRow] = await Promise.all([
    prisma.users.findUnique({
      where: { user_id: userId },
      select: {
        user_id: true, nickname: true, email: true, avatar_url: true, phone: true,
        role: true, is_active: true, is_blacklisted: true, bonus_points: true,
        created_at: true, admin_permissions: true,
        _count: { select: { books: true } }
      }
    }),
    levels.listLevels(),
    levels.completedOrderCount(userId),
    prisma.admin_permissions.findUnique({ where: { user_id: req.user.userId } })
  ]);

  if (!user) throw notFound('找不到該會員');
  const viewer = requireAdmin.effectivePermissions(viewerRow);

  const basePoints = levels.basePointsOf(completedOrders);
  const points = levels.effectivePoints(completedOrders, user.bonus_points);

  const perms = requireAdmin.effectivePermissions(user.admin_permissions);

  res.status(200).json({
    success: true,
    data: {
      user_id: user.user_id,
      nickname: user.nickname,
      email: user.email,
      phone: user.phone,
      avatar_url: user.avatar_url,
      role: user.role,
      is_active: user.is_active,
      is_blacklisted: user.is_blacklisted,
      created_at: user.created_at,
      book_count: user._count.books,
      completed_orders: completedOrders,
      base_points: basePoints,
      bonus_points: user.bonus_points,
      points,
      current_level: levels.levelFor(allLevels, points),
      levels: allLevels,
      permissions: Object.fromEntries(PERMISSION_KEYS.map((k) => [k, !!perms[k]])),
      // 目前登入的管理員能不能開啟這項權限。App 用來把開不了的開關標成停用並說明原因。
      grantable: Object.fromEntries(PERMISSION_KEYS.map((k) => [k, !!viewer[k]]))
    }
  });
});

router.post('/members/:id/reset-password', canManage, async (req, res) => {
  const userId = v.id(req.params.id, '會員編號');
  assertNotSelf(req, userId, '不能重設自己的密碼，請用「更改密碼」');

  const user = await prisma.users.findUnique({
    where: { user_id: userId },
    select: { user_id: true, nickname: true, role: true, anonymized_at: true }
  });
  if (!user) throw notFound('找不到這位會員');

  // 擋掉管理員互相重設密碼：否則任何有會員權限的人都能接管其他管理員的帳號，
  // 等於繞過所有權限設定。
  if (user.role === 'admin') throw forbidden('不能重設其他管理員的密碼');
  if (user.anonymized_at) throw conflict('這個帳號已刪除');

  const temp = password.temporary();
  const hash = await password.hash(temp);

  await prisma.$transaction(async (tx) => {
    await tx.users.update({
      where: { user_id: userId },
      data: { password_hash: hash, updated_at: new Date() }
    });
    await notify(tx, {
      userId,
      title: '密碼已被重設',
      content: '客服已為你重設登入密碼。請用客服提供的臨時密碼登入，'
        + '並立即到「設定 → 更改密碼」改成你自己的密碼。',
      relatedId: userId,
      relatedType: 'user'
    });
  });

  await push.removeUserDevices(userId);

  // 臨時密碼本身不進操作紀錄——紀錄是給稽核看的，不該存明文密碼。
  await logAction(req.user.userId, '重設會員密碼', 'user', userId, user.nickname);

  res.set('Cache-Control', 'no-store');
  res.status(200).json({
    success: true,
    message: '已重設，請把臨時密碼交給使用者',
    data: { temp_password: temp }
  });
});

router.patch('/members/:id', canManage, async (req, res) => {
  const userId = v.id(req.params.id, '會員編號');
  assertNotSelf(req, userId, '無法變更自己的帳號狀態');

  const { is_active: isActive, is_blacklisted: isBlacklisted, role } = req.body;
  const data = {
    ...(isActive !== undefined && { is_active: v.bool(isActive) }),
    ...(isBlacklisted !== undefined && { is_blacklisted: v.bool(isBlacklisted) }),
    ...(role !== undefined && { role: v.oneOf(role, USER_ROLES, '不支援的身分') })
  };
  if (Object.keys(data).length === 0) throw badRequest('沒有要變更的欄位');

  const target = await prisma.users.findUnique({ where: { user_id: userId }, select: { anonymized_at: true } });
  if (!target) throw notFound('找不到該會員');
  if (target.anonymized_at) throw conflict('這個帳號已刪除，無法變更狀態');

  const updated = await prisma.users.update({
    where: { user_id: userId },
    data: { ...data, updated_at: new Date() },
    select: { user_id: true, nickname: true, role: true, is_active: true, is_blacklisted: true }
  });

  await logAction(req.user.userId, '變更會員狀態', 'user', userId, JSON.stringify(data));
  res.status(200).json({ success: true, message: '會員狀態已更新', data: updated });
});

router.patch('/members/:id/level', canManage, async (req, res) => {
  const userId = v.id(req.params.id, '會員編號');
  const { level_id: levelId, reset, delta } = req.body;

  const user = await prisma.users.findUnique({ where: { user_id: userId }, select: { bonus_points: true } });
  if (!user) throw notFound('找不到該會員');

  const basePoints = levels.basePointsOf(await levels.completedOrderCount(userId));

  let bonus;
  let detail;

  if (reset === true) {
    bonus = 0;
    detail = '恢復自動計算';
  } else if (delta !== undefined) {
    const amount = v.toInt(delta);
    if (!Number.isSafeInteger(amount) || amount === 0) throw badRequest('請輸入非零的點數');
    if (Math.abs(amount) > MAX_BONUS) throw badRequest(`單次調整不可超過 ${MAX_BONUS} 點`);
    bonus = user.bonus_points + amount;
    detail = `點數 ${amount > 0 ? '+' : ''}${amount}`;
  } else {
    const level = await prisma.member_levels.findUnique({ where: { level_id: v.id(levelId, '等級編號') } });
    if (!level) throw notFound('找不到這個等級');
    // 把補正值調到剛好踩在該等級的門檻上。
    bonus = level.min_points - basePoints;
    detail = `指定等級：${level.level_name}`;
  }

  bonus = Math.min(Math.max(bonus, -basePoints), MAX_BONUS * 100);
  const points = Math.max(0, basePoints + bonus);

  await prisma.$transaction(async (tx) => {
    await tx.users.update({ where: { user_id: userId }, data: { bonus_points: bonus, updated_at: new Date() } });
    await notify(tx, {
      userId,
      title: '會員等級已調整',
      content: `客服調整了您的會員等級（${detail}），目前點數 ${points}。`,
      relatedType: 'user'
    });
  });

  await logAction(req.user.userId, '調整會員等級', 'user', userId, detail);
  res.status(200).json({ success: true, message: '已調整等級', data: { points, bonus_points: bonus } });
});

router.put('/members/:id/permissions', canManage, async (req, res) => {
  const userId = v.id(req.params.id, '會員編號');
  assertNotSelf(req, userId, '無法變更自己的權限');

  const data = {};
  for (const key of PERMISSION_KEYS) {
    if (req.body[key] !== undefined) data[key] = v.bool(req.body[key]);
  }
  if (Object.keys(data).length === 0) throw badRequest('沒有要更新的權限');

  const [target, mine] = await Promise.all([
    prisma.users.findUnique({ where: { user_id: userId }, select: { role: true } }),
    prisma.admin_permissions.findUnique({ where: { user_id: req.user.userId } })
  ]);
  if (!target) throw notFound('找不到該會員');
  if (target.role !== 'admin') throw badRequest('只有管理員帳號才需要設定細部權限');

  // 不能把自己沒有的權限開給別人，否則只有會員權限的管理員可以替同夥開全部權限。
  const granter = requireAdmin.effectivePermissions(mine);
  const beyond = Object.keys(data).filter((k) => data[k] && !granter[k]);
  if (beyond.length) {
    throw forbidden(beyond.includes('can_manage_system')
      ? '「系統維運」只能由已有這項權限的管理員開啟'
      : '不能開啟你自己沒有的權限');
  }

  await prisma.admin_permissions.upsert({
    where: { user_id: userId },
    update: data,
    create: { user_id: userId, ...data }
  });

  await logAction(req.user.userId, '調整管理員權限', 'user', userId, JSON.stringify(data));
  res.status(200).json({ success: true, message: '已更新權限' });
});

module.exports = router;
