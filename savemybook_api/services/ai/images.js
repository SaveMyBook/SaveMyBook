const fs = require('fs');
const path = require('path');
const { imageMimeOf, UPLOAD_ROOT } = require('../../lib/upload');
const { stripImageMetadata } = require('../../lib/image-metadata');

const MAX_BYTES = 5 * 1024 * 1024;
const UPLOAD_URL_RE = /^\/uploads\/books\/[\w.-]+$/;
const EVIDENCE_URL_RE = /^\/uploads\/(books|evidence)\/[\w.-]+$/;

const fromBuffer = (buffer) => {
  if (!Buffer.isBuffer(buffer) || buffer.length === 0 || buffer.length > MAX_BYTES) return null;
  const mimeType = imageMimeOf(buffer);
  const clean = mimeType ? stripImageMetadata(buffer, mimeType) : null;
  return clean ? { mimeType, data: clean.toString('base64') } : null;
};

// 無法清除中繼資料的格式（HEIC、AVIF 等）不送出，以免夾帶拍攝位置；回傳略過原因，呼叫端才能如實告知張數。
const loadFile = async (filePath) => {
  try {
    const stat = await fs.promises.stat(filePath);
    if (!stat.isFile()) return { skipped: 'missing' };
    if (stat.size > MAX_BYTES) return { skipped: 'too_large' };
    const image = fromBuffer(await fs.promises.readFile(filePath));
    return image ? { image } : { skipped: 'unsupported' };
  } catch {
    return { skipped: 'missing' };
  }
};

const readFile = async (filePath) => (await loadFile(filePath)).image ?? null;

// allowEvidence：爭議佐證照片存在 uploads/evidence，只有管理員的爭議分析會讀取。
const loadUrl = async (url, { allowEvidence = false } = {}) => {
  const pattern = allowEvidence ? EVIDENCE_URL_RE : UPLOAD_URL_RE;
  if (typeof url !== 'string' || !pattern.test(url)) return { skipped: 'invalid' };
  return loadFile(path.join(UPLOAD_ROOT, url.slice('/uploads/'.length)));
};

const fromUploads = async (files, max = 2) => {
  const out = [];
  for (const f of files) {
    if (out.length >= max) break;
    const image = f.buffer ? fromBuffer(f.buffer) : f.path ? await readFile(f.path) : null;
    if (image) out.push(image);
  }
  return out;
};

const fromUrls = async (urls, max = 2, { allowEvidence = false } = {}) => {
  const out = [];
  for (const url of urls) {
    if (out.length >= max) break;
    const { image } = await loadUrl(url, { allowEvidence });
    if (image) out.push(image);
  }
  return out;
};

module.exports = { MAX_BYTES, fromBuffer, fromUploads, fromUrls, loadUrl };
