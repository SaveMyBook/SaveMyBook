const { HttpError } = require('../lib/errors');

/// 行程內的固定視窗限流。
///
/// 服務是單一行程，不需要為此引入 Redis；重啟會清空計數，對防暴力破解影響有限。
/// 若日後改成多行程部署，這裡要換成共用儲存。
const rateLimit = ({ windowMs, max, key, message = '操作太頻繁，請稍後再試' }) => {
  const hits = new Map();

  const sweep = setInterval(() => {
    const now = Date.now();
    for (const [k, v] of hits) if (v.resetAt <= now) hits.delete(k);
  }, windowMs);
  sweep.unref();

  return (req, res, next) => {
    const k = key(req);
    const now = Date.now();
    let entry = hits.get(k);
    if (!entry || entry.resetAt <= now) {
      entry = { count: 0, resetAt: now + windowMs };
      hits.set(k, entry);
    }
    entry.count += 1;
    if (entry.count > max) {
      res.setHeader('Retry-After', Math.ceil((entry.resetAt - now) / 1000));
      return next(new HttpError(429, message, 'RATE_LIMITED'));
    }
    next();
  };
};

const byIp = (req) => req.ip || 'unknown';
const byUser = (req) => `u:${req.user?.userId ?? req.ip}`;

module.exports = { rateLimit, byIp, byUser };
