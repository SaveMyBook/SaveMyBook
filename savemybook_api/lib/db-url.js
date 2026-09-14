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
