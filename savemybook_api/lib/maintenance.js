let state = { active: false, message: null, since: null };

const enter = (message) => {
  state = { active: true, message, since: new Date() };
};

const leave = () => {
  state = { active: false, message: null, since: null };
};

const current = () => state;

const middleware = (req, res, next) => {
  if (!state.active || req.path === '/api/status') return next();
  res.setHeader('Retry-After', '30');
  res.status(503).json({ success: false, code: 'MAINTENANCE', message: state.message || '系統維護中，請稍後再試' });
};

module.exports = { enter, leave, current, middleware };
