const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');
const { signToken } = require('../middleware/auth');
const requireAdmin = require('../middleware/requireAdmin');
const { rateLimit, byIp, byUser } = require('../middleware/rateLimit');
const { id, int, text, optionalText, date } = require('../lib/validate');
const password = require('../lib/password');
const { imageUpload } = require('../lib/upload');
const { publicBase } = require('../lib/public-url');
const { badRequest, forbidden, notFound, conflict, orNotFound } = require('../lib/errors');
const { GENDERS } = require('../constants/domain');
const account = require('../services/account');
const share = require('../services/share');
const levels = require('../services/levels');
const push = require('../services/push');
const audit = require('../services/audit');
const legal = require('../services/legal');
const sessions = require('../services/sessions');
const { requireVerification } = require('../services/security');

const router = express.Router();

const avatars = imageUpload({ folder: 'avatars', maxFileSize: 5 * 1024 * 1024 });

const selfSelect = {
  user_id: true, email: true, nickname: true, avatar_url: true, bio: true,
  phone: true, birthday: true, gender: true, role: true, created_at: true
};

const publicSelect = {
  user_id: true, nickname: true, avatar_url: true, bio: true, role: true, created_at: true
};

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const avatarUrl = (value) => {
  const url = optionalText(value, { label: '頭像網址', max: 500 });
  if (url == null) return url;
  if (!/^(\/uploads\/avatars\/[\w.-]+|https?:\/\/\S+)$/.test(url)) throw badRequest('頭像網址格式不正確');
  return url;
};

const nickname = (value) => {
  const name = text(value, { label: '暱稱', max: 50 });
  if (name.length < 2) throw badRequest('暱稱至少需 2 個字');
  return name;
};

const profileData = (body) => {
  const data = {};
  if (body.nickname !== undefined) data.nickname = nickname(body.nickname);
  if (body.bio !== undefined) data.bio = optionalText(body.bio, { label: '自我介紹', max: 500 });
  if (body.phone !== undefined) {
    const phone = optionalText(body.phone, { label: '電話', max: 20 });
    if (phone && !/^[\d+\-\s()]+$/.test(phone)) throw badRequest('電話格式不正確');
    data.phone = phone;
  }
  return data;
};

const passwordLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  key: byUser,
  message: '嘗試次數過多，請 15 分鐘後再試'
});

const registerLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 30,
  key: byIp,
  message: '註冊次數過多，請稍後再試'
});

router.get('/me/stats', authenticateToken, async (req, res) => {
  const userId = req.user.userId;
  const [wallet, bookCount, favoriteCount, unreadNotifications, cartCount] = await Promise.all([
    prisma.wallets.findUnique({ where: { user_id: userId }, select: { balance: true } }),
    prisma.books.count({ where: { seller_id: userId, status: { in: ['on_sale', 'reserved'] } } }),
    prisma.favorites.count({ where: { user_id: userId } }),
    prisma.notifications.count({ where: { user_id: userId, is_read: false } }),
    prisma.shopping_cart.count({ where: { user_id: userId } })
  ]);

  res.status(200).json({
    success: true,
    data: {
      balance: wallet?.balance ?? 0,
      book_count: bookCount,
      favorite_count: favoriteCount,
      unread_notification_count: unreadNotifications,
      cart_count: cartCount
    }
  });
});

router.get('/me/level', authenticateToken, async (req, res) => {
  const userId = req.user.userId;
  const [allLevels, completedOrders, me] = await Promise.all([
    levels.listLevels(),
    levels.completedOrderCount(userId),
    prisma.users.findUnique({ where: { user_id: userId }, select: { bonus_points: true } })
  ]);

  const points = levels.effectivePoints(completedOrders, me?.bonus_points);
  const next = levels.nextLevelFor(allLevels, points);

  res.status(200).json({
    success: true,
    data: {
      points,
      completed_orders: completedOrders,
      current_level: levels.levelFor(allLevels, points),
      next_level: next,
      points_to_next: next ? next.min_points - points : 0,
      levels: allLevels
    }
  });
});

router.put('/me', authenticateToken, async (req, res) => {
  const body = req.body;
  const data = profileData(body);
  if (body.avatar_url !== undefined) data.avatar_url = avatarUrl(body.avatar_url);
  if (body.gender !== undefined && GENDERS.includes(body.gender)) data.gender = body.gender;
  if (body.birthday !== undefined) {
    const birthday = date(body.birthday, '生日');
    if (birthday && (birthday > new Date() || birthday.getFullYear() < 1900)) {
      throw badRequest('生日不在合理範圍內');
    }
    data.birthday = birthday;
  }

  const updated = await prisma.users.update({
    where: { user_id: req.user.userId },
    data: { ...data, updated_at: new Date() },
    select: selfSelect
  });
  res.status(200).json({ success: true, message: '個人檔案已更新', data: updated });
});

router.post('/me/avatar', authenticateToken, ...avatars.single('avatar'), async (req, res) => {
  if (!req.file) throw badRequest('請選擇要上傳的圖片');

  const updated = await prisma.users.update({
    where: { user_id: req.user.userId },
    data: { avatar_url: avatars.urlOf(req.file), updated_at: new Date() },
    select: selfSelect
  });
  res.status(200).json({ success: true, message: '頭像已更新', data: updated });
});

router.put('/me/password', authenticateToken, passwordLimiter, async (req, res) => {
  const { current_password: current, new_password: next } = req.body;

  if (!current || !next) throw badRequest('請填寫目前密碼與新密碼');
  password.assertPolicy(next, '新密碼');

  const user = await prisma.users.findUnique({
    where: { user_id: req.user.userId },
    select: { password_hash: true }
  });
  if (!user) throw notFound('找不到該使用者');
  // 用 400 不用 401：App 收到 401 會直接登出。
  if (!(await password.verify(current, user.password_hash))) throw badRequest('目前密碼錯誤');
  if (current === next) throw badRequest('新密碼不可與目前密碼相同');

  const updated = await prisma.users.update({
    where: { user_id: req.user.userId },
    data: { password_hash: await password.hash(next), updated_at: new Date() },
    select: { user_id: true, email: true, role: true, password_hash: true }
  });

  await push.removeUserDevices(req.user.userId);
  await sessions.revokeAll(req.user.userId, { exceptSid: req.user.sid });

  res.status(200).json({
    success: true,
    message: '密碼已更新，其他裝置須重新登入',
    data: { token: signToken(updated, req.user.sid) }
  });
});

router.get('/me/qrcode', authenticateToken, async (req, res) => {
  const user = await prisma.users.findUnique({
    where: { user_id: req.user.userId },
    select: { user_id: true, nickname: true, avatar_url: true }
  });
  if (!user) throw notFound('找不到該使用者');

  // 路徑用隨機權杖而非 user_id，否則可枚舉全站使用者。
  const token = await share.ensureUserToken(user.user_id);
  const qrData = `${publicBase(req)}/u/${token}`;

  const existing = await prisma.user_qr_codes.findFirst({
    where: { user_id: user.user_id, qr_type: 'profile' },
    select: { qr_id: true }
  });
  if (!existing) {
    await prisma.user_qr_codes.create({
      data: { user_id: user.user_id, qr_type: 'profile', qr_code_url: '', qr_data: qrData }
    });
  }

  res.status(200).json({ success: true, data: { ...user, qr_data: qrData } });
});

router.post('/me/share-token/rotate', authenticateToken, async (req, res) => {
  const token = await share.rotateUserToken(req.user.userId);
  res.status(200).json({
    success: true,
    message: '已產生新連結，舊連結立即失效',
    data: { qr_data: `${publicBase(req)}/u/${token}` }
  });
});

router.get('/me/export', authenticateToken, requireVerification('sensitive'), async (req, res) => {
  const data = await account.exportData(req.user.userId);
  const stamp = new Date().toISOString().slice(0, 10);
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename="savemybook-${req.user.userId}-${stamp}.json"`);
  res.setHeader('Cache-Control', 'no-store');
  res.status(200).send(JSON.stringify(data, null, 2));
});

router.get('/me/deletion', authenticateToken, async (req, res) => {
  const user = await prisma.users.findUnique({
    where: { user_id: req.user.userId },
    select: { deletion_requested_at: true }
  });
  const requested = user?.deletion_requested_at ?? null;
  res.status(200).json({
    success: true,
    data: {
      pending: requested != null,
      requested_at: requested,
      purge_at: requested ? account.graceDeadline(requested) : null,
      grace_days: account.GRACE_DAYS
    }
  });
});

router.post('/me/deletion', authenticateToken, passwordLimiter, async (req, res) => {
  const plain = typeof req.body.password === 'string' ? req.body.password : '';
  if (!plain) throw badRequest('請輸入密碼以確認身分');

  const user = await prisma.users.findUnique({
    where: { user_id: req.user.userId },
    select: { user_id: true, password_hash: true, role: true, deletion_requested_at: true }
  });
  if (!user) throw notFound('找不到該使用者');
  if (!(await password.verify(plain, user.password_hash))) throw badRequest('密碼錯誤');

  const openOrders = await account.unsettledOrderCount(user.user_id);
  if (openOrders > 0) {
    throw badRequest(`尚有 ${openOrders} 筆進行中的訂單，請先完成或取消後再申請刪除`, 'OPEN_ORDERS');
  }

  // 重複申請沿用第一次的時間，否則緩衝期會被重新計算。
  const requestedAt = user.deletion_requested_at ?? new Date();
  if (!user.deletion_requested_at) {
    await prisma.users.update({
      where: { user_id: user.user_id },
      data: { deletion_requested_at: requestedAt, updated_at: new Date() }
    });
  }

  res.status(200).json({
    success: true,
    message: `已受理，${account.GRACE_DAYS} 天內重新登入即可取消`,
    data: { purge_at: account.graceDeadline(requestedAt), grace_days: account.GRACE_DAYS }
  });
});

router.delete('/me/deletion', authenticateToken, async (req, res) => {
  await prisma.users.update({
    where: { user_id: req.user.userId },
    data: { deletion_requested_at: null, updated_at: new Date() }
  });
  res.status(200).json({ success: true, message: '已取消刪除帳號' });
});

// ---------- 通知偏好 ----------

const NOTIFICATION_SETTINGS = {
  order: 'notification_order',
  message: 'notification_message',
  promotion: 'notification_promo'
};

const shapeNotificationSettings = (row) =>
  Object.fromEntries(Object.entries(NOTIFICATION_SETTINGS).map(([key, column]) => [key, row ? row[column] !== false : true]));

router.get('/me/notification-settings', authenticateToken, async (req, res) => {
  const row = await prisma.user_settings.findUnique({ where: { user_id: req.user.userId } });
  res.status(200).json({ success: true, data: shapeNotificationSettings(row) });
});

router.put('/me/notification-settings', authenticateToken, async (req, res) => {
  const data = {};
  for (const [key, column] of Object.entries(NOTIFICATION_SETTINGS)) {
    if (req.body[key] !== undefined) {
      if (typeof req.body[key] !== 'boolean') throw badRequest(`${key} 必須是 true 或 false`);
      data[column] = req.body[key];
    }
  }
  if (Object.keys(data).length === 0) throw badRequest('沒有要更新的設定');

  const row = await prisma.user_settings.upsert({
    where: { user_id: req.user.userId },
    update: { ...data, updated_at: new Date() },
    create: { user_id: req.user.userId, ...data }
  });
  res.status(200).json({ success: true, message: '已更新通知設定', data: shapeNotificationSettings(row) });
});

// ---------- 法律文件同意 ----------

router.get('/me/legal-consents/pending', authenticateToken, async (req, res) => {
  const docs = await legal.pendingFor(req.user.userId);
  res.status(200).json({
    success: true,
    data: docs.map((d) => ({
      doc_id: Number(d.doc_id),
      doc_key: d.doc_key,
      title: d.title,
      content: d.content,
      version: Number(d.version),
      updated_at: d.updated_at
    }))
  });
});

router.post('/me/legal-consents', authenticateToken, async (req, res) => {
  const docKey = text(req.body.doc_key, { label: '文件代碼', max: 50 });
  const version = int(req.body.version, { label: '版本', min: 1, max: 1000000 });

  const meta = (await legal.metaByKey()).get(docKey);
  if (!meta) throw notFound('找不到此文件');
  if (meta.version !== version) throw conflict('此文件已更新，請重新閱讀後再同意', 'LEGAL_VERSION_CHANGED');

  await legal.accept(req.user.userId, docKey, version);
  res.status(200).json({ success: true, message: '已同意' });
});

// ---------- 早期的泛用端點 ----------

router.get('/', authenticateToken, requireAdmin('members'), async (req, res) => {
  const users = await prisma.users.findMany({ select: selfSelect, orderBy: { user_id: 'asc' }, take: 1000 });
  res.status(200).json({ success: true, data: users });
});

router.get('/share/:token', authenticateToken, async (req, res) => {
  const token = String(req.params.token || '').toLowerCase();
  if (!share.TOKEN_RE.test(token)) throw notFound('找不到此使用者');
  const user = await prisma.users.findFirst({
    where: { share_token: token },
    select: { ...publicSelect, is_active: true, is_blacklisted: true, anonymized_at: true }
  });
  if (!user || !user.is_active || user.is_blacklisted || user.anonymized_at) throw notFound('找不到此使用者');
  const visible = Object.fromEntries(Object.keys(publicSelect).map((key) => [key, user[key]]));
  res.status(200).json({ success: true, data: visible });
});

router.get('/:id', authenticateToken, async (req, res) => {
  const userId = id(req.params.id, '使用者編號');
  const canSeePrivate = userId === req.user.userId || req.user.role === 'admin';

  const user = await prisma.users.findUnique({
    where: { user_id: userId },
    select: canSeePrivate ? selfSelect : publicSelect
  });
  if (!user) throw notFound('找不到該使用者');

  res.status(200).json({ success: true, data: user });
});

router.post('/', registerLimiter, async (req, res) => {
  const email = text(req.body.email, { label: 'Email', max: 255 }).toLowerCase();
  const plain = req.body.password;
  const name = text(req.body.nickname, { label: '暱稱', max: 50 });

  if (!email || !plain || !name) throw badRequest('缺少必要欄位：email、password 或 nickname');
  if (!EMAIL_RE.test(email)) throw badRequest('Email 格式不正確');
  password.assertPolicy(plain);
  nickname(name);

  // role 一律由伺服器決定：過去採用 body.role 讓任何人都能註冊成管理員。
  try {
    const newUser = await prisma.users.create({
      data: { email, password_hash: await password.hash(plain), nickname: name, role: 'buyer_seller' },
      select: selfSelect
    });
    if (req.body.accept_legal === true) {
      await legal.acceptAllCurrent(newUser.user_id).catch((err) => console.error('[記錄註冊同意失敗]:', err.message));
    }
    res.status(201).json({ success: true, message: '使用者建立成功', data: newUser });
  } catch (err) {
    if (err.code === 'P2002') throw badRequest('此 Email 已被註冊');
    throw err;
  }
});

router.put('/:id', authenticateToken, async (req, res) => {
  const userId = id(req.params.id, '使用者編號');
  if (req.user.userId !== userId && req.user.role !== 'admin') {
    throw forbidden('存取被拒，您無權限修改他人的資料');
  }

  const updated = await orNotFound(
    prisma.users.update({
      where: { user_id: userId },
      data: { ...profileData(req.body), updated_at: new Date() },
      select: selfSelect
    }),
    '找不到該使用者'
  );
  res.status(200).json({ success: true, message: '使用者資料更新成功', data: updated });
});

// 實體刪除僅限管理員，否則可繞過 /me/deletion「有進行中訂單不能刪」的檢查。
router.delete('/:id', authenticateToken, requireAdmin('members'), requireVerification('sensitive'), async (req, res) => {
  const userId = id(req.params.id, '使用者編號');
  if (userId === req.user.userId) throw badRequest('無法刪除自己的帳號');

  const target = await prisma.users.findUnique({ where: { user_id: userId }, select: { role: true, nickname: true, email: true } });
  if (!target) throw notFound('找不到該使用者');
  if (target.role === 'admin') throw forbidden('無法刪除管理員帳號');
  if ((await account.unsettledOrderCount(userId)) > 0) throw conflict('此使用者還有進行中的訂單，無法刪除');

  try {
    await prisma.users.delete({ where: { user_id: userId } });
  } catch (err) {
    if (err.code === 'P2003') throw conflict('此使用者仍有訂單等關聯資料，請改用停權或匿名化');
    throw err;
  }
  await audit.record(null, {
    adminId: req.user.userId,
    action: '刪除使用者',
    targetType: 'user',
    targetId: userId,
    summary: `從資料庫永久刪除 ${target.nickname}（${target.email}），無法復原`,
    req
  });
  res.status(200).json({ success: true, message: '使用者已成功刪除' });
});

module.exports = router;
