const securityHeaders = (req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  next();
};

const uploadHeaders = (res) => {
  res.setHeader('Content-Security-Policy', "default-src 'none'; img-src 'self'; style-src 'unsafe-inline'; sandbox");
  res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
};

const ensureBody = (req, res, next) => {
  if (req.body === undefined || req.body === null || typeof req.body !== 'object') req.body = {};
  next();
};

module.exports = { securityHeaders, uploadHeaders, ensureBody };
