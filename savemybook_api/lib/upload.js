const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const { badRequest } = require('./errors');

const UPLOAD_ROOT = path.join(__dirname, '../uploads');

const EXT_BY_MIME = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/gif': '.gif',
  'image/webp': '.webp',
  'image/heic': '.heic',
  'image/heif': '.heif'
};
const ALLOWED_EXT = new Set(['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.heif']);

/// 用檔頭判斷是不是真的圖片。
///
/// 副檔名與 Content-Type 都是用戶端自己填的。/uploads 以靜態檔案對外提供，
/// 只看副檔名的話，改名成 .jpg 的 HTML 或 SVG 仍可能被瀏覽器當成網頁執行。
const looksLikeImage = (buf) => {
  if (buf.length < 12) return false;
  if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return true;
  if (buf.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return true;
  if (buf.subarray(0, 4).toString('latin1') === 'GIF8') return true;
  if (buf.subarray(0, 4).toString('latin1') === 'RIFF' && buf.subarray(8, 12).toString('latin1') === 'WEBP') return true;
  if (buf.subarray(4, 8).toString('latin1') === 'ftyp') {
    return ['heic', 'heix', 'hevc', 'hevx', 'mif1', 'msf1', 'avif'].includes(buf.subarray(8, 12).toString('latin1'));
  }
  return false;
};

const readHead = (filePath) => {
  const fd = fs.openSync(filePath, 'r');
  try {
    const buf = Buffer.alloc(16);
    const n = fs.readSync(fd, buf, 0, 16, 0);
    return buf.subarray(0, n);
  } finally {
    fs.closeSync(fd);
  }
};

const uploadedFiles = (req) => {
  if (req.file) return [req.file];
  if (Array.isArray(req.files)) return req.files;
  if (req.files && typeof req.files === 'object') return Object.values(req.files).flat();
  return [];
};

const removeUploaded = (req) => {
  for (const f of uploadedFiles(req)) {
    fs.promises.unlink(f.path).catch(() => {});
  }
};

/// 回傳 multer 實例的 single/array/fields，每個都已串好檔頭檢查。
const imageUpload = ({ folder, maxFileSize = 10 * 1024 * 1024 }) => {
  const dir = path.join(UPLOAD_ROOT, folder);
  fs.mkdirSync(dir, { recursive: true });

  const extOf = (file) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    if (ALLOWED_EXT.has(ext)) return ext === '.jpeg' ? '.jpg' : ext;
    return EXT_BY_MIME[file.mimetype] ?? null;
  };

  const upload = multer({
    storage: multer.diskStorage({
      destination: (req, file, cb) => cb(null, dir),
      // 檔名完全由伺服器決定，原始檔名只取副檔名，避免路徑穿越與奇怪字元。
      filename: (req, file, cb) => cb(null, `${Date.now()}-${crypto.randomBytes(8).toString('hex')}${extOf(file)}`)
    }),
    limits: { fileSize: maxFileSize, fields: 30, fieldSize: 100 * 1024 },
    fileFilter: (req, file, cb) => {
      if (extOf(file)) return cb(null, true);
      cb(badRequest('只接受圖片檔（JPG、PNG、GIF、WebP、HEIC）'));
    }
  });

  const verify = (req, res, next) => {
    const files = uploadedFiles(req);
    const bad = files.some((f) => {
      try {
        return !looksLikeImage(readHead(f.path));
      } catch {
        return true;
      }
    });
    if (bad) {
      removeUploaded(req);
      return next(badRequest('檔案內容不是有效的圖片'));
    }
    next();
  };

  return {
    single: (field) => [upload.single(field), verify],
    array: (field, max) => [upload.array(field, max), verify],
    fields: (spec) => [upload.fields(spec), verify],
    urlOf: (file) => `/uploads/${folder}/${file.filename}`
  };
};

module.exports = { UPLOAD_ROOT, imageUpload, uploadedFiles, removeUploaded };
