const { isUploadUrl, usableUrl } = require('../lib/uploads-fs');

// 這些欄位存的是單一張圖片的網址；其餘欄位即使是字串也不動，避免誤改訊息內容。
const IMAGE_KEYS = new Set(['avatar_url', 'image_url', 'cover_url', 'sender_avatar', 'sender_avatar_url']);
const MAX_NODES = 5000;

const sanitize = (value, budget) => {
  if (budget.count > MAX_NODES) return value;

  if (Array.isArray(value)) {
    const out = [];
    for (const item of value) {
      budget.count += 1;
      // 圖片清單中的失效項目直接移除，前端就不會出現空白格子。
      if (item && typeof item === 'object' && !Array.isArray(item)
          && isUploadUrl(item.image_url) && usableUrl(item.image_url) === null) {
        continue;
      }
      out.push(sanitize(item, budget));
    }
    return out;
  }

  if (value && typeof value === 'object' && !(value instanceof Date)) {
    for (const [key, item] of Object.entries(value)) {
      budget.count += 1;
      if (IMAGE_KEYS.has(key) && isUploadUrl(item)) value[key] = usableUrl(item);
      else if (item && typeof item === 'object') value[key] = sanitize(item, budget);
    }
  }

  return value;
};

// 讀取時若檔案已不存在（例如伺服器上的 uploads 被刪除），回傳 null 並在背景清掉資料庫欄位。
const uploadsGuard = (req, res, next) => {
  const json = res.json.bind(res);
  res.json = (body) => json(body && typeof body === 'object' ? sanitize(body, { count: 0 }) : body);
  next();
};

module.exports = { uploadsGuard, IMAGE_KEYS };
