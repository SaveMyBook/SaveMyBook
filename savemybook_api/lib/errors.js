class HttpError extends Error {
  constructor(status, message, code, extra) {
    super(message);
    this.status = status;
    this.code = code;
    this.extra = extra;
  }
}

const badRequest = (message, code, extra) => new HttpError(400, message, code, extra);
const unauthorized = (message, code) => new HttpError(401, message, code);
const forbidden = (message = '存取被拒', code) => new HttpError(403, message, code);
const notFound = (message = '找不到資料', code) => new HttpError(404, message, code);
const conflict = (message, code) => new HttpError(409, message, code);

const orNotFound = async (promise, message) => {
  try {
    return await promise;
  } catch (err) {
    if (err?.code === 'P2025') throw notFound(message);
    throw err;
  }
};

module.exports = { HttpError, badRequest, unauthorized, forbidden, notFound, conflict, orNotFound };
