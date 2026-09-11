const express = require('express');
const bcrypt = require('bcrypt');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');
const {
  GRACE_DAYS, graceDeadline, newShareToken, ensureShareToken, exportData
} = require('../lib/account');

const router = express.Router();

const multer = require('multer');
const path = require('path');
const fs = require('fs');

const avatarDir = path.join(__dirname, '../uploads/avatars');
if (!fs.existsSync(avatarDir)) {
  fs.mkdirSync(avatarDir, { recursive: true });
}

const avatarUpload = multer({
  storage: multer.diskStorage({
    destination: (req, file, cb) => cb(null, avatarDir),
    filename: (req, file, cb) => {
      cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}${path.extname(file.originalname)}`);
    }
  })
});

const publicUserSelect = {
  user_id: true, email: true, nickname: true, avatar_url: true, bio: true,
  phone: true, birthday: true, gender: true, role: true, created_at: true
};

const calcPoints = (completedOrders) => completedOrders * 10;

/// 實際點數 = 完成訂單自動累積 + 管理員手動加減（bonus_points 可為負）。
const effectivePoints = (completedOrders, bonus) =>
  Math.max(0, calcPoints(completedOrders) + (bonus ?? 0));

router.get('/me/stats', authenticateToken, async (req, res) => {
  const userId = req.user.userId;
  try {
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
  } catch (err) {
    console.error('[取得個人統計失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.get('/me/level', authenticateToken, async (req, res) => {
  const userId = req.user.userId;
  try {
    const [levels, completedOrders] = await Promise.all([
      prisma.member_levels.findMany({ orderBy: { min_points: 'asc' } }),
      prisma.orders.count({ where: { buyer_id: userId, status: 'completed' } })
    ]);

    const me = await prisma.users.findUnique({
      where: { user_id: userId },
      select: { bonus_points: true }
    });
    const points = effectivePoints(completedOrders, me?.bonus_points);
    const current = [...levels].reverse().find(l => points >= l.min_points) ?? levels[0] ?? null;
    const next = levels.find(l => l.min_points > points) ?? null;

    res.status(200).json({
      success: true,
      data: {
        points,
        completed_orders: completedOrders,
        current_level: current,
        next_level: next,
        points_to_next: next ? next.min_points - points : 0,
        levels
      }
    });
  } catch (err) {
    console.error('[取得會員等級失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.put('/me', authenticateToken, async (req, res) => {
  const { nickname, bio, phone, birthday, gender, avatar_url } = req.body;
  try {
    const updated = await prisma.users.update({
      where: { user_id: req.user.userId },
      data: {
        ...(nickname !== undefined && { nickname }),
        ...(bio !== undefined && { bio }),
        ...(phone !== undefined && { phone }),
        ...(avatar_url !== undefined && { avatar_url }),
        ...(gender !== undefined && ['male', 'female', 'other', 'undisclosed'].includes(gender) && { gender }),
        ...(birthday !== undefined && { birthday: birthday ? new Date(birthday) : null }),
        updated_at: new Date()
      },
      select: publicUserSelect
    });
    res.status(200).json({ success: true, message: '個人檔案已更新', data: updated });
  } catch (err) {
    console.error('[更新個人檔案失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.post('/me/avatar', authenticateToken, avatarUpload.single('avatar'), async (req, res) => {
  if (!req.file) return res.status(400).json({ success: false, message: '請選擇要上傳的圖片' });
  try {
    const avatarUrl = `/uploads/avatars/${req.file.filename}`;
    const updated = await prisma.users.update({
      where: { user_id: req.user.userId },
      data: { avatar_url: avatarUrl, updated_at: new Date() },
      select: publicUserSelect
    });
    res.status(200).json({ success: true, message: '頭像已更新', data: updated });
  } catch (err) {
    console.error('[上傳頭像失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.put('/me/password', authenticateToken, async (req, res) => {
  const { current_password, new_password } = req.body;

  if (!current_password || !new_password) {
    return res.status(400).json({ success: false, message: '請填寫目前密碼與新密碼' });
  }
  if (String(new_password).length < 6) {
    return res.status(400).json({ success: false, message: '新密碼長度至少 6 個字元' });
  }

  try {
    const user = await prisma.users.findUnique({ where: { user_id: req.user.userId } });
    if (!user) return res.status(404).json({ success: false, message: '找不到該使用者' });

    const isMatch = await bcrypt.compare(current_password, user.password_hash);
    if (!isMatch) return res.status(401).json({ success: false, message: '目前密碼錯誤' });

    const hash = await bcrypt.hash(new_password, 10);
    await prisma.users.update({
      where: { user_id: req.user.userId },
      data: { password_hash: hash, updated_at: new Date() }
    });

    res.status(200).json({ success: true, message: '密碼已更新' });
  } catch (err) {
    console.error('[更改密碼失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.get('/me/qrcode', authenticateToken, async (req, res) => {
  try {
    const user = await prisma.users.findUnique({
      where: { user_id: req.user.userId },
      select: { user_id: true, nickname: true, avatar_url: true }
    });
    if (!user) return res.status(404).json({ success: false, message: '找不到該使用者' });

    // 用 https 連結，外部相機／掃描器才掃得動（自訂 scheme 只有本 App 認得）。
    // 路徑帶的是隨機權杖不是 user_id，否則任何人都能從 1 枚舉到 N
    // 把全站使用者的公開頁掃出來。
    const base = process.env.PUBLIC_WEB_URL || `${req.protocol}://${req.get('host')}`;
    const token = await ensureShareToken(user.user_id);
    const qrData = `${base}/u/${token}`;
    const existing = await prisma.user_qr_codes.findFirst({
      where: { user_id: user.user_id, qr_type: 'profile' }
    });

    if (!existing) {
      await prisma.user_qr_codes.create({
        data: { user_id: user.user_id, qr_type: 'profile', qr_code_url: '', qr_data: qrData }
      });
    }

    res.status(200).json({ success: true, data: { ...user, qr_data: qrData } });
  } catch (err) {
    console.error('[取得個人 QR 失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

// ---------- 分享連結 ----------

router.post('/me/share-token/rotate', authenticateToken, async (req, res) => {
  try {
    const token = newShareToken();
    await prisma.users.update({
      where: { user_id: req.user.userId },
      data: { share_token: token, updated_at: new Date() }
    });
    const base = process.env.PUBLIC_WEB_URL || `${req.protocol}://${req.get('host')}`;
    res.status(200).json({
      success: true,
      message: '已產生新連結，舊連結立即失效',
      data: { qr_data: `${base}/u/${token}` }
    });
  } catch (err) {
    console.error('[重新產生分享連結失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

// ---------- 匯出個人資料 ----------

router.get('/me/export', authenticateToken, async (req, res) => {
  try {
    const data = await exportData(req.user.userId);
    const stamp = new Date().toISOString().slice(0, 10);
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.setHeader('Content-Disposition',
      `attachment; filename="savemybook-${req.user.userId}-${stamp}.json"`);
    res.status(200).send(JSON.stringify(data, null, 2));
  } catch (err) {
    console.error('[匯出個人資料失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

// ---------- 刪除帳號 ----------

router.get('/me/deletion', authenticateToken, async (req, res) => {
  try {
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
        purge_at: requested ? graceDeadline(requested) : null,
        grace_days: GRACE_DAYS
      }
    });
  } catch (err) {
    console.error('[查詢刪除狀態失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.post('/me/deletion', authenticateToken, async (req, res) => {
  const password = req.body.password || '';
  if (!password) {
    return res.status(400).json({ success: false, message: '請輸入密碼以確認身分' });
  }

  try {
    const user = await prisma.users.findUnique({ where: { user_id: req.user.userId } });
    if (!user) return res.status(404).json({ success: false, message: '找不到該使用者' });

    const match = await bcrypt.compare(password, user.password_hash);
    if (!match) return res.status(401).json({ success: false, message: '密碼錯誤' });

    // 手上還有沒走完的交易就不能刪，否則對方會卡在半途。
    const openOrders = await prisma.orders.count({
      where: {
        OR: [{ buyer_id: user.user_id }, { seller_id: user.user_id }],
        status: { in: ['pending_payment', 'pending_deposit', 'deposited', 'pending_pickup', 'refunding'] }
      }
    });
    if (openOrders > 0) {
      return res.status(400).json({
        success: false,
        code: 'OPEN_ORDERS',
        message: `還有 ${openOrders} 筆進行中的訂單，請先完成或取消後再申請刪除`
      });
    }

    const requestedAt = new Date();
    await prisma.users.update({
      where: { user_id: user.user_id },
      data: { deletion_requested_at: requestedAt, updated_at: requestedAt }
    });

    res.status(200).json({
      success: true,
      message: `已受理，${GRACE_DAYS} 天內重新登入即可取消`,
      data: { purge_at: graceDeadline(requestedAt), grace_days: GRACE_DAYS }
    });
  } catch (err) {
    console.error('[申請刪除帳號失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.delete('/me/deletion', authenticateToken, async (req, res) => {
  try {
    await prisma.users.update({
      where: { user_id: req.user.userId },
      data: { deletion_requested_at: null, updated_at: new Date() }
    });
    res.status(200).json({ success: true, message: '已取消刪除帳號' });
  } catch (err) {
    console.error('[取消刪除帳號失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.get('/', authenticateToken, async (req, res) => {
  try {
    const users = await prisma.users.findMany();
    res.status(200).json({ success: true, data: users });
  } catch (err) {
    console.error('Error fetching all users:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const user = await prisma.users.findUnique({
      where: { user_id: parseInt(req.params.id) }
    });

    if (!user) {
      return res.status(404).json({ success: false, message: '找不到該使用者' });
    }

    res.status(200).json({ success: true, data: user });
  } catch (err) {
    console.error(`Error fetching user with ID ${req.params.id}:`, err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.post('/', async (req, res) => {
  const { email, password, nickname, role = 'buyer_seller' } = req.body;

  if (!email || !password || !nickname) {
    return res.status(400).json({
      success: false,
      message: '缺少必要欄位：email, password或 nickname'
    });
  }

  try {
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(password, saltRounds);

    const newUser = await prisma.users.create({
      data: {
        email,
        password_hash: hashedPassword,
        nickname,
        role
      }
    });

    res.status(201).json({
      success: true,
      message: '使用者建立成功',
      data: newUser
    });
  } catch (err) {
    console.error('Error creating user:', err);

    if (err.name === 'PrismaClientValidationError') {
      return res.status(400).json({
        success: false,
        message: '提供的資料格式錯誤或包含無效的值（例如錯誤的角色權限）'
      });
    }

    if (err.code === 'P2002') {
      return res.status(400).json({ success: false, message: '該 Email 已經被註冊過了' });
    }
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.put('/:id', authenticateToken, async (req, res) => {
  const { nickname, bio, phone } = req.body;
  const userId = parseInt(req.params.id);

  if (req.user.userId !== userId && req.user.role !== 'admin') {
    return res.status(403).json({ success: false, message: '存取被拒，您無權限修改他人的資料' });
  }

  try {
    const updatedUser = await prisma.users.update({
      where: { user_id: userId },
      data: { nickname, bio, phone }
    });

    res.status(200).json({ success: true, message: '使用者資料更新成功', data: updatedUser });
  } catch (err) {
    console.error(`Error updating user with ID ${userId}:`, err);

    if (err.name === 'PrismaClientValidationError') {
      return res.status(400).json({
        success: false,
        message: '提供的資料格式錯誤或包含無效的值'
      });
    }

    if (err.code === 'P2025') {
      return res.status(404).json({ success: false, message: '找不到該使用者' });
    }
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.delete('/:id', authenticateToken, async (req, res) => {
  const userId = parseInt(req.params.id);

  if (req.user.userId !== userId && req.user.role !== 'admin') {
    return res.status(403).json({ success: false, message: '存取被拒，您無權限刪除他人的資料' });
  }

  try {
    await prisma.users.delete({
      where: { user_id: userId }
    });

    res.status(200).json({ success: true, message: '使用者已成功刪除' });
  } catch (err) {
    console.error(`Error deleting user with ID ${userId}:`, err);
    if (err.code === 'P2025') {
      return res.status(404).json({ success: false, message: '找不到該使用者' });
    }
    res.status(500).json({
      success: false,
      message: '伺服器發生錯誤，可能有其他關聯資料（如訂單）依賴此使用者'
    });
  }
});

module.exports = router;