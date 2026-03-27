const express = require('express');
const prisma = require('../lib/prisma'); // Import the shared Prisma instance

const router = express.Router();

// ==========================================
// GET /api/users
// Fetch all users from the database
// ==========================================
router.get('/', async (req, res) => {
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
router.get('/:id', async (req, res) => {
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
  const { email, password_hash, nickname, role = 'buyer_seller' } = req.body;
  
  // Basic validation
  if (!email || !password_hash || !nickname) {
    return res.status(400).json({ 
      success: false, 
      message: '缺少必要欄位：email, password_hash 或 nickname' 
    });
  }

  try {
    const newUser = await prisma.users.create({
      data: { email, password_hash, nickname, role }
    });
    
    res.status(201).json({ 
      success: true, 
      message: '使用者建立成功',
      data: newUser 
    });
  } catch (err) {
    console.error('Error creating user:', err);
    
    // Handle Prisma Validation Error (e.g., invalid enum value, wrong data type)
    if (err.name === 'PrismaClientValidationError') {
      return res.status(400).json({ 
        success: false, 
        message: '提供的資料格式錯誤或包含無效的值（例如錯誤的角色權限）' 
      });
    }

    // Handle unique constraint violation (e.g., duplicated email)
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
router.put('/:id', async (req, res) => {
  const { nickname, bio, phone } = req.body;
  const userId = parseInt(req.params.id);

  try {
    const updatedUser = await prisma.users.update({
      where: { user_id: userId },
      data: { nickname, bio, phone }
    });
    
    res.status(200).json({ success: true, message: '使用者資料更新成功', data: updatedUser });
  } catch (err) {
    console.error(`Error updating user with ID ${userId}:`, err);
    
    // Handle Prisma Validation Error (e.g., invalid data types)
    if (err.name === 'PrismaClientValidationError') {
      return res.status(400).json({ 
        success: false, 
        message: '提供的資料格式錯誤或包含無效的值' 
      });
    }

    // Handle case where user does not exist
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
router.delete('/:id', async (req, res) => {
  const userId = parseInt(req.params.id);
  
  try {
    await prisma.users.delete({
      where: { user_id: userId }
    });
    
    res.status(200).json({ success: true, message: '使用者已成功刪除' });
  } catch (err) {
    console.error(`Error deleting user with ID ${userId}:`, err);
    // Handle case where user does not exist
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