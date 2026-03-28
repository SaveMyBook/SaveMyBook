const express = require('express');
const bcrypt = require('bcrypt');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');

const router = express.Router();

// ==========================================
// GET /api/users
// Fetch all users from the database (保護：需登入)
// ==========================================
router.get('/', authenticateToken, async (req, res) => {
  try {
    const users = await prisma.users.findMany();
    res.status(200).json({ success: true, data: users });
  } catch (err) {
    console.error('Error fetching all users:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

// ==========================================
// GET /api/users/:id
// Fetch a specific user by their ID 
// ==========================================
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

// ==========================================
// POST /api/users
// Create a new user
// ==========================================
router.post('/', async (req, res) => {
  const { email, password, nickname, role = 'buyer_seller' } = req.body;
  
  // Basic validation
  if (!email || !password || !nickname) {
    return res.status(400).json({ 
      success: false, 
      message: '缺少必要欄位：email, password或 nickname' 
    });
  }

  try {
    // Hash the password before saving to the database
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

// ==========================================
// PUT /api/users/:id
// Update an existing user's information
// ==========================================
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

// ==========================================
// DELETE /api/users/:id
// Delete a user from the database 
// ==========================================
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