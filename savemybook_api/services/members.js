const prisma = require('../lib/prisma');
const password = require('../lib/password');
const v = require('../lib/validate');
const { badRequest, forbidden, notFound, conflict } = require('../lib/errors');
const { ADMIN_PERMISSIONS, ADMIN_PERMISSION_LABELS, USER_ROLE_LABELS } = require('../constants/domain');
const { effectivePermissions, permissionRowOf } = require('./admin-permissions');
const levels = require('./levels');
const { notify } = require('./notify');
const audit = require('./audit');
const push = require('./push');
const sessions = require('./sessions');

const MAX_BONUS = 1000000;

const PERMISSION_COLUMNS = Object.values(ADMIN_PERMISSIONS);

const PERMISSION_LABELS = Object.fromEntries(
  Object.entries(ADMIN_PERMISSIONS).map(([name, column]) => [column, ADMIN_PERMISSION_LABELS[name]])
);

const onOff = (v) => (v ? '開啟' : '關閉');

const STATUS_FIELDS = {
  is_active: { label: '帳號啟用', format: (v) => (v ? '啟用' : '停權') },
  is_blacklisted: { label: '黑名單', format: (v) => (v ? '列入' : '未列入') },
  role: { label: '身分', format: (v) => USER_ROLE_LABELS[v] ?? v }
};

const BONUS_FIELD = { bonus_points: '手動補正點數' };

const list = async ({ keyword, status, skip, limit }) => {
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
  return { members, total };
};

const detail = async (userId, viewerId) => {
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
    permissionRowOf(viewerId)
  ]);

  if (!user) throw notFound('找不到該會員');
  const viewer = effectivePermissions(viewerRow);

  const basePoints = levels.basePointsOf(completedOrders);
  const points = levels.effectivePoints(completedOrders, user.bonus_points);

  const perms = effectivePermissions(user.admin_permissions);

  return {
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
    permissions: Object.fromEntries(PERMISSION_COLUMNS.map((k) => [k, !!perms[k]])),
    grantable: Object.fromEntries(PERMISSION_COLUMNS.map((k) => [k, !!viewer[k]]))
  };
};

const resetPassword = async (userId, { adminId, req }) => {
  const user = await prisma.users.findUnique({
    where: { user_id: userId },
    select: { user_id: true, nickname: true, role: true, anonymized_at: true }
  });
  if (!user) throw notFound('找不到此會員');

  // 禁止重設其他管理員的密碼，否則有會員權限者可接管管理員帳號。
  if (user.role === 'admin') throw forbidden('無法重設其他管理員的密碼');
  if (user.anonymized_at) throw conflict('此帳號已刪除');

  const temp = password.temporary();
  const hash = await password.hash(temp);

  await prisma.$transaction(async (tx) => {
    await tx.users.update({
      where: { user_id: userId },
      data: { password_hash: hash, updated_at: new Date() }
    });
    // 只用社群或手機登入的帳號原本沒有密碼；重設後必須標記為已設定，否則仍會被當成無密碼而無法通過驗證。
    await tx.$executeRaw`UPDATE users SET password_set = 1 WHERE user_id = ${userId}`;
    await notify(tx, {
      userId,
      title: '密碼已被重設',
      content: '客服已為您重設登入密碼。請使用客服提供的臨時密碼登入，'
        + '並立即至「設定 › 帳號安全」變更密碼。',
      relatedId: userId,
      relatedType: 'password'
    });
  });

  await push.removeUserDevices(userId);
  await sessions.revokeAll(userId);

  // 臨時密碼不可寫進操作紀錄。
  await audit.record(null, {
    adminId,
    action: '重設會員密碼',
    targetType: 'user',
    targetId: userId,
    summary: `重設 ${user.nickname} 的登入密碼，並登出該帳號的所有裝置`,
    req
  });

  return temp;
};

const updateStatus = async (userId, data, { adminId, req }) => {
  const target = await prisma.users.findUnique({
    where: { user_id: userId },
    select: { anonymized_at: true, nickname: true, email: true, is_active: true, is_blacklisted: true, role: true }
  });
  if (!target) throw notFound('找不到該會員');
  if (target.anonymized_at) throw conflict('此帳號已刪除，無法變更狀態');

  const updated = await prisma.users.update({
    where: { user_id: userId },
    data: { ...data, updated_at: new Date() },
    select: { user_id: true, nickname: true, role: true, is_active: true, is_blacklisted: true }
  });

  const changes = audit.diff(target, updated, STATUS_FIELDS);
  if (changes.length) {
    await audit.record(null, {
      adminId,
      action: '變更會員狀態',
      targetType: 'user',
      targetId: userId,
      summary: `變更 ${target.nickname}（${target.email}）的${changes.map((c) => c.label).join('、')}`,
      changes,
      undo: [audit.undoUpdate('users', userId, target, updated, STATUS_FIELDS)],
      req
    });
  }
  return updated;
};

const adjustLevel = async (userId, { reset, delta, levelId }, { adminId, req }) => {
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
    if (!level) throw notFound('找不到此等級');
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
      content: `客服已調整您的會員等級（${detail}），目前點數 ${points}。`,
      relatedType: 'member_level'
    });
  });

  const nickname = (await prisma.users.findUnique({ where: { user_id: userId }, select: { nickname: true } }))?.nickname;
  await audit.record(null, {
    adminId,
    action: '調整會員等級',
    targetType: 'user',
    targetId: userId,
    summary: `調整 ${nickname} 的會員等級（${detail}），目前點數 ${points}`,
    changes: audit.diff(user, { bonus_points: bonus }, BONUS_FIELD),
    undo: [audit.undoUpdate('users', userId, user, { bonus_points: bonus }, BONUS_FIELD)],
    req
  });
  return { points, bonus_points: bonus };
};

const setPermissions = async (userId, data, { adminId, req }) => {
  const [target, mine, before] = await Promise.all([
    prisma.users.findUnique({ where: { user_id: userId }, select: { role: true, nickname: true } }),
    permissionRowOf(adminId),
    permissionRowOf(userId)
  ]);
  if (!target) throw notFound('找不到該會員');
  if (target.role !== 'admin') throw badRequest('只有管理員帳號才需要設定細部權限');

  // 不能開啟自己沒有的權限，否則可替他人提權。
  const granter = effectivePermissions(mine);
  const beyond = Object.keys(data).filter((k) => data[k] && !granter[k]);
  if (beyond.length) {
    throw forbidden(beyond.includes('can_manage_system')
      ? '「系統維運」僅能由具備此權限的管理員開啟'
      : '無法開啟您本身未具備的權限');
  }

  const after = await prisma.admin_permissions.upsert({
    where: { user_id: userId },
    update: data,
    create: { user_id: userId, ...data }
  });

  const fields = Object.fromEntries(Object.keys(data).map((k) => [k, { label: PERMISSION_LABELS[k], format: onOff }]));
  const changes = audit.diff(effectivePermissions(before), after, fields);
  await audit.record(null, {
    adminId,
    action: '調整管理員權限',
    targetType: 'user',
    targetId: userId,
    summary: changes.length
      ? `調整 ${target.nickname} 的後台權限：${changes.map((c) => `${c.label}${c.to}`).join('、')}`
      : `重新儲存 ${target.nickname} 的後台權限（無實際變更）`,
    changes,
    undo: changes.length ? [audit.undoUpdate('admin_permissions', userId, before, after, fields)] : null,
    req
  });
};

module.exports = { PERMISSION_COLUMNS, list, detail, resetPassword, updateStatus, adjustLevel, setPermissions };
