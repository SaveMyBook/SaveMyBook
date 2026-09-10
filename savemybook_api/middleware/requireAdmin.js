const requireAdmin = (req, res, next) => {
  if (!req.user || req.user.role !== 'admin') {
    return res.status(403).json({ success: false, message: '權限不足，僅限管理員執行此操作' });
  }
  next();
};

module.exports = requireAdmin;
