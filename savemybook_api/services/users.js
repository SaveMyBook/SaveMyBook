const prisma = require('../lib/prisma');
const password = require('../lib/password');
const { signToken } = require('../lib/auth-token');
const { badRequest, forbidden, notFound, conflict, orNotFound } = require('../lib/errors');
const account = require('./account');
const share = require('./share');
const push = require('./push');
const audit = require('./audit');
const legal = require('./legal');
const sessions = require('./sessions');
const notificationCenter = require('./notifications');

const selfSelect = {
  user_id: true, email: true, nickname: true, avatar_url: true, bio: true,
  phone: true, birthday: true, gender: true, role: true, created_at: true
};

const publicSelect = {
  user_id: true, nickname: true, avatar_url: true, bio: true, role: true, created_at: true
};

const NOTIFICATION_SETTINGS = {
  order: 'notification_order',
  message: 'notification_message',
  promotion: 'notification_promo'
};

const stats = async (userId) => {
  const [wallet, bookCount, favoriteCount, unreadNotifications, cartCount] = await Promise.all([
    prisma.wallets.findUnique({ where: { user_id: userId }, select: { balance: true } }),
    prisma.books.count({ where: { seller_id: userId, status: { in: ['on_sale', 'reserved'] } } }),
    prisma.favorites.count({ where: { user_id: userId } }),
    notificationCenter.unreadCount(userId),
    prisma.shopping_cart.count({ where: { user_id: userId } })
  ]);

  return {
    balance: wallet?.balance ?? 0,
    book_count: bookCount,
    favorite_count: favoriteCount,
    unread_notification_count: unreadNotifications,
    cart_count: cartCount
  };
};

const updateSelf = (userId, data) => prisma.users.update({
  where: { user_id: userId },
  data: { ...data, updated_at: new Date() },
  select: selfSelect
});

const updateProfile = (userId, data) => orNotFound(updateSelf(userId, data), '找不到該使用者');

const changePassword = async (userId, sid, current, next) => {
  const user = await prisma.users.findUnique({
    where: { user_id: userId },
    select: { password_hash: true }
  });
  if (!user) throw notFound('找不到該使用者');
  // 用 400 不用 401：App 收到 401 會直接登出。
  if (!(await password.verify(current, user.password_hash))) throw badRequest('目前密碼錯誤');
  if (current === next) throw badRequest('新密碼不可與目前密碼相同');

  const updated = await prisma.users.update({
    where: { user_id: userId },
    data: { password_hash: await password.hash(next), updated_at: new Date() },
    select: { user_id: true, email: true, role: true, password_hash: true }
  });

  await push.removeUserDevices(userId);
  await sessions.revokeAll(userId, { exceptSid: sid });

  return signToken(updated, sid);
};

const profileQrCode = async (userId, baseUrl) => {
  const user = await prisma.users.findUnique({
    where: { user_id: userId },
    select: { user_id: true, nickname: true, avatar_url: true }
  });
  if (!user) throw notFound('找不到該使用者');

  // 路徑用隨機權杖而非 user_id，否則可枚舉全站使用者。
  const token = await share.ensureUserToken(user.user_id);
  const qrData = `${baseUrl}/u/${token}`;

  const existing = await prisma.user_qr_codes.findFirst({
    where: { user_id: user.user_id, qr_type: 'profile' },
    select: { qr_id: true }
  });
  if (!existing) {
    await prisma.user_qr_codes.create({
      data: { user_id: user.user_id, qr_type: 'profile', qr_code_url: '', qr_data: qrData }
    });
  }

  return { ...user, qr_data: qrData };
};

const rotateShareLink = async (userId, baseUrl) => `${baseUrl}/u/${await share.rotateUserToken(userId)}`;

const shapeNotificationSettings = (row) =>
  Object.fromEntries(Object.entries(NOTIFICATION_SETTINGS).map(([key, column]) => [key, row ? row[column] !== false : true]));

const notificationSettings = async (userId) =>
  shapeNotificationSettings(await prisma.user_settings.findUnique({ where: { user_id: userId } }));

const updateNotificationSettings = async (userId, data) => {
  const row = await prisma.user_settings.upsert({
    where: { user_id: userId },
    update: { ...data, updated_at: new Date() },
    create: { user_id: userId, ...data }
  });
  return shapeNotificationSettings(row);
};

const listAll = () => prisma.users.findMany({ select: selfSelect, orderBy: { user_id: 'asc' }, take: 1000 });

const findByShareToken = async (token) => {
  if (!share.TOKEN_RE.test(token)) throw notFound('找不到此使用者');
  const user = await prisma.users.findFirst({
    where: { share_token: token },
    select: { ...publicSelect, is_active: true, is_blacklisted: true, anonymized_at: true }
  });
  if (!user || !user.is_active || user.is_blacklisted || user.anonymized_at) throw notFound('找不到此使用者');
  return Object.fromEntries(Object.keys(publicSelect).map((key) => [key, user[key]]));
};

const profileOf = async (userId, { includePrivate }) => {
  const user = await prisma.users.findUnique({
    where: { user_id: userId },
    select: includePrivate ? selfSelect : publicSelect
  });
  if (!user) throw notFound('找不到該使用者');
  return user;
};

// role 一律由伺服器決定：過去採用 body.role 讓任何人都能註冊成管理員。
const register = async ({ email, plain, nickname, acceptLegal }) => {
  try {
    const newUser = await prisma.users.create({
      data: { email, password_hash: await password.hash(plain), nickname, role: 'buyer_seller' },
      select: selfSelect
    });
    if (acceptLegal) {
      await legal.acceptAllCurrent(newUser.user_id).catch((err) => console.error('[記錄註冊同意失敗]:', err.message));
    }
    return newUser;
  } catch (err) {
    if (err.code === 'P2002') throw badRequest('此 Email 已被註冊');
    throw err;
  }
};

const hardDelete = async (userId, { adminId, req }) => {
  if (userId === adminId) throw badRequest('無法刪除自己的帳號');

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
    adminId,
    action: '刪除使用者',
    targetType: 'user',
    targetId: userId,
    summary: `從資料庫永久刪除 ${target.nickname}（${target.email}），無法復原`,
    req
  });
};

module.exports = {
  NOTIFICATION_SETTINGS, stats, updateSelf, updateProfile, changePassword, profileQrCode, rotateShareLink,
  notificationSettings, updateNotificationSettings, listAll, findByShareToken, profileOf, register, hardDelete
};
