const sessions = require('../services/sessions');
const security = require('../services/security');

const requireVerification = (scope) => async (req, res, next) => {
  try {
    if (!(await sessions.isAvailable())) return next();
    const decoded = security.consumeToken(req.get('x-verify-token'), req.user, scope);
    req.verification = decoded;
    if (security.SCOPES[scope].singleUse) {
      res.on('finish', () => {
        if (res.statusCode >= 400) security.releaseToken(decoded.jti);
      });
    }
    next();
  } catch (err) {
    next(err);
  }
};

module.exports = { requireVerification };
