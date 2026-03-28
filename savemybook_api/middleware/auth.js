const jwt = require('jsonwebtoken');

// ==========================================
// JWT Authentication Middleware
// ==========================================
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    console.warn('Access denied. No token provided.');
    return res.status(401).json({ success: false, message: '存取被拒，未提供 Token' });
  }

  jwt.verify(token, process.env.JWT_SECRET, (err, decodedUser) => {
    if (err) {
      console.error('Invalid or expired token detected.');
      return res.status(403).json({ success: false, message: 'Token 無效或已過期' });
    }

    req.user = decodedUser;
    next();
  });
};

module.exports = authenticateToken;