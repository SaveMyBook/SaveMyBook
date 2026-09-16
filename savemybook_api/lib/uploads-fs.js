const fs = require('fs');
const path = require('path');
const prisma = require('./prisma');
const { UPLOAD_ROOT } = require('./upload');

const CACHE_TTL_MS = 5 * 60 * 1000;
const MISSING_TTL_MS = 30 * 1000;
const MAX_CACHE = 5000;

const cache = new Map();

const isUploadUrl = (value) => typeof value === 'string' && value.startsWith('/uploads/');

// 僅允許 /uploads/<資料夾>/<檔名> 這一層，擋掉 ../ 之類的路徑穿越。
const SAFE_URL = /^\/uploads\/[\w-]+\/[\w.-]+$/;

const pathOf = (url) => (SAFE_URL.test(url) ? path.join(UPLOAD_ROOT, url.slice('/uploads/'.length)) : null);

const remember = (url, ok) => {
  if (cache.size >= MAX_CACHE) cache.clear();
  cache.set(url, { ok, at: Date.now() });
  return ok;
};

// 檔案存在的結果可以放心快取；不存在只快取短時間，剛上傳完的檔案才不會被誤判。
const exists = (url) => {
  if (!isUploadUrl(url)) return true;
  const hit = cache.get(url);
  if (hit && Date.now() - hit.at < (hit.ok ? CACHE_TTL_MS : MISSING_TTL_MS)) return hit.ok;

  const target = pathOf(url);
  if (!target) return remember(url, false);
  try {
    return remember(url, fs.statSync(target).isFile());
  } catch {
    return remember(url, false);
  }
};

const forget = (url) => cache.delete(url);

// 各資料夾對應到實際存放網址的欄位；找不到檔案時就地清除，避免畫面一直出現破圖。
const CLEANERS = {
  avatars: async (url) => {
    await prisma.$executeRaw`UPDATE users SET avatar_url = NULL WHERE avatar_url = ${url}`;
  },
  books: async (url) => {
    await prisma.$executeRaw`DELETE FROM book_images WHERE image_url = ${url}`;
  },
  chat: async (url) => {
    // 聊天圖片訊息本身保留（收件者仍看得到「圖片已不存在」），只清掉群組頭貼。
    await prisma.$executeRaw`UPDATE chat_rooms SET avatar_url = NULL WHERE avatar_url = ${url}`;
  }
};

const folderOf = (url) => (SAFE_URL.test(url) ? url.split('/')[2] : null);

const pending = new Set();

// 清理只在背景進行，不阻擋當次請求，也不讓同一個網址重複清。
const pruneLater = (url) => {
  const cleaner = CLEANERS[folderOf(url) ?? ''];
  if (!cleaner || pending.has(url)) return;
  pending.add(url);
  Promise.resolve()
    .then(() => cleaner(url))
    .catch((err) => console.error('[清除失效圖片欄位失敗]:', err.message))
    .finally(() => pending.delete(url));
};

/** 回傳可用的網址；檔案不存在時回 null，並在背景清掉資料庫欄位。 */
const usableUrl = (url) => {
  if (!isUploadUrl(url)) return url ?? null;
  if (exists(url)) return url;
  pruneLater(url);
  return null;
};

module.exports = { UPLOAD_ROOT, isUploadUrl, exists, forget, usableUrl, pruneLater, pathOf, CLEANERS };
