const multer = require('multer');
const { HttpError } = require('../lib/errors');
const { removeUploaded } = require('../lib/upload');

const notFound = (req, res) => {
  res.status(404).json({ success: false, code: 'ROUTE_NOT_FOUND', message: '找不到這個端點' });
};

const MULTER_MESSAGES = {
  LIMIT_FILE_SIZE: [413, '檔案太大了'],
  LIMIT_FILE_COUNT: [400, '上傳的檔案數量超過上限'],
  LIMIT_UNEXPECTED_FILE: [400, '上傳欄位不正確或檔案數量超過上限'],
  LIMIT_FIELD_COUNT: [400, '表單欄位過多'],
  LIMIT_FIELD_VALUE: [400, '表單欄位內容過長']
};

const PRISMA_MESSAGES = {
  P2025: [404, '找不到資料'],
  P2002: [409, '資料重複，請確認後再試'],
  P2003: [409, '有其他資料關聯到這筆紀錄，無法執行'],
  P2000: [400, '欄位內容超過長度上限']
};

const classify = (err) => {
  if (err instanceof HttpError) return [err.status, err.message, err.code, err.extra];
  if (err instanceof multer.MulterError) {
    const [status, message] = MULTER_MESSAGES[err.code] ?? [400, '檔案上傳失敗'];
    return [status, message];
  }
  if (err?.type === 'entity.parse.failed') return [400, '請求內容不是合法的 JSON'];
  if (err?.type === 'entity.too.large') return [413, '請求內容太大'];
  if (err?.code && PRISMA_MESSAGES[err.code]) return PRISMA_MESSAGES[err.code];
  if (err?.name === 'PrismaClientValidationError') return [400, '提供的資料格式錯誤或包含無效的值'];
  return null;
};

// Express 以參數個數辨識錯誤處理器，next 不能省略。
const errorHandler = (err, req, res, next) => {
  removeUploaded(req);

  if (res.headersSent) return req.socket.destroy();

  const known = classify(err);
  if (!known) {
    console.error(`[${req.method} ${req.originalUrl}]`, err);
    return res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }

  const [status, message, code, extra] = known;
  // 主動丟出的 HttpError（例如推播未啟用的 503）是預期內的狀況，不寫錯誤日誌。
  if (status >= 500 && !(err instanceof HttpError)) console.error(`[${req.method} ${req.originalUrl}]`, err);
  res.status(status).json({ success: false, ...(code && { code }), message, ...extra });
};

module.exports = { notFound, errorHandler };
