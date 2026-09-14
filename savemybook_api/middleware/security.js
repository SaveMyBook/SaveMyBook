/// 不引入 helmet，只設這個 API 真正用得到的幾個標頭。
const securityHeaders = (req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  next();
};

/// 上傳區只該被當成圖片讀取。sandbox 讓就算有漏網的 HTML 也無法執行腳本或讀到本站 cookie。
const uploadHeaders = (res) => {
  res.setHeader('Content-Security-Policy', "default-src 'none'; img-src 'self'; style-src 'unsafe-inline'; sandbox");
  res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
};

/// Express 5 在沒有 body 或 Content-Type 不符時 req.body 是 undefined，
/// 解構 req.body 會直接拋 TypeError。
const ensureBody = (req, res, next) => {
  if (req.body === undefined || req.body === null || typeof req.body !== 'object') req.body = {};
  next();
};

module.exports = { securityHeaders, uploadHeaders, ensureBody };
