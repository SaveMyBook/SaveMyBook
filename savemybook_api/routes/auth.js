const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const prisma = require('../lib/prisma');

const router = express.Router();

router.post('/login', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ success: false, message: '請提供 email 與密碼' });
  }

  try {
    const user = await prisma.users.findUnique({
      where: { email: email }
    });

    if (!user) {
      return res.status(401).json({ success: false, message: '帳號或密碼錯誤' });
    }

    const isMatch = await bcrypt.compare(password, user.password_hash);
    
    if (!isMatch) {
      return res.status(401).json({ success: false, message: '帳號或密碼錯誤' });
    }

    const payload = {
      userId: user.user_id,
      role: user.role,
      email: user.email
    };

    const token = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: '24h' });

    console.log(`User ${user.email} logged in successfully.`);
    
    res.status(200).json({
      success: true,
      message: '登入成功',
      data: { token }
    });

  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

const authenticateToken = require('../middleware/auth');

router.get('/me', authenticateToken, async (req, res) => {
  try {
    const user = await prisma.users.findUnique({
      where: { user_id: req.user.userId }
    });

    if (!user) {
      return res.status(404).json({ success: false, message: '找不到使用者' });
    }

    res.status(200).json({ success: true, data: user });
  } catch (err) {
    console.error('Error fetching current user:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

module.exports = router;