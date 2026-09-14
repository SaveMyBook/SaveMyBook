/// DATABASE_URL 內的帳密可能是百分比編碼（密碼含 @ # / : 等字元時必須編碼）。
/// 解不開就沿用原字串，避免密碼中帶有裸 % 時整個炸掉。
const decode = (value) => {
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
};

const parseDatabaseUrl = (raw) => {
  const url = new URL(raw);
  return {
    host: url.hostname,
    port: parseInt(url.port, 10) || 3306,
    user: decode(url.username),
    password: decode(url.password),
    database: decode(url.pathname.substring(1))
  };
};

module.exports = { parseDatabaseUrl };
