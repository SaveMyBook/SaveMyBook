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

// 以檔頭判斷圖片：副檔名與 Content-Type 可偽造，改名成 .jpg 的 HTML/SVG 會被瀏覽器執行。
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

const looksLikeAudio = (buf) => {
  if (buf.length < 12) return false;
  if (buf.subarray(4, 8).toString('latin1') === 'ftyp') {
    const brand = buf.subarray(8, 12).toString('latin1');
    return ['M4A ', 'M4B ', 'mp42', 'mp41', 'isom', 'iso2', 'iso5', 'iso6', 'dash', '3gp4', '3gp5'].includes(brand);
  }
  if (buf[0] === 0xff && (buf[1] & 0xf6) === 0xf0) return true;
  if (buf.subarray(0, 3).toString('latin1') === 'ID3') return true;
  if (buf[0] === 0xff && (buf[1] & 0xe0) === 0xe0) return true;
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

const KINDS = {
  image: {
    extByMime: EXT_BY_MIME,
    allowedExt: ALLOWED_EXT,
    looksValid: looksLikeImage,
    typeMessage: '只接受圖片檔（JPG、PNG、GIF、WebP、HEIC）',
    contentMessage: '檔案內容不是有效的圖片'
  },
  audio: {
    extByMime: { 'audio/mp4': '.m4a', 'audio/x-m4a': '.m4a', 'audio/m4a': '.m4a', 'audio/aac': '.aac', 'audio/mpeg': '.mp3' },
    allowedExt: new Set(['.m4a', '.aac', '.mp3']),
    looksValid: (buf) => looksLikeAudio(buf),
    typeMessage: '只接受語音檔（M4A、AAC、MP3）',
    contentMessage: '檔案內容不是有效的語音'
  }
};

const fileUpload = ({ folder, maxFileSize = 10 * 1024 * 1024, kind = 'image' }) => {
  const rule = KINDS[kind];
  const dir = path.join(UPLOAD_ROOT, folder);
  fs.mkdirSync(dir, { recursive: true });

  const extOf = (file) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    if (rule.allowedExt.has(ext)) return ext === '.jpeg' ? '.jpg' : ext;
    return rule.extByMime[file.mimetype] ?? null;
  };

  const upload = multer({
    storage: multer.diskStorage({
      destination: (req, file, cb) => cb(null, dir),
      filename: (req, file, cb) => cb(null, `${Date.now()}-${crypto.randomBytes(8).toString('hex')}${extOf(file)}`)
    }),
    limits: { fileSize: maxFileSize, fields: 30, fieldSize: 100 * 1024 },
    fileFilter: (req, file, cb) => {
      if (extOf(file)) return cb(null, true);
      cb(badRequest(rule.typeMessage));
    }
  });

  const verify = (req, res, next) => {
    const files = uploadedFiles(req);
    const bad = files.some((f) => {
      try {
        return !rule.looksValid(readHead(f.path));
      } catch {
        return true;
      }
    });
    if (bad) {
      removeUploaded(req);
      return next(badRequest(rule.contentMessage));
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

const imageUpload = (opts) => fileUpload({ ...opts, kind: 'image' });
const audioUpload = (opts) => fileUpload({ ...opts, kind: 'audio' });

module.exports = { UPLOAD_ROOT, imageUpload, audioUpload, uploadedFiles, removeUploaded };
