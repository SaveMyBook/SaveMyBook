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

const readFile = async (filePath) => {
  try {
    const stat = await fs.promises.stat(filePath);
    if (!stat.isFile() || stat.size > MAX_BYTES) return null;
    return fromBuffer(await fs.promises.readFile(filePath));
  } catch {
    return null;
  }
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

// allowEvidence：爭議佐證照片存在 uploads/evidence，只有管理員的爭議分析會讀取。
const fromUrls = async (urls, max = 2, { allowEvidence = false } = {}) => {
  const pattern = allowEvidence ? EVIDENCE_URL_RE : UPLOAD_URL_RE;
  const out = [];
  for (const url of urls) {
    if (out.length >= max) break;
    if (typeof url !== 'string' || !pattern.test(url)) continue;
    const image = await readFile(path.join(UPLOAD_ROOT, url.slice('/uploads/'.length)));
    if (image) out.push(image);
  }
  return out;
};

module.exports = { MAX_BYTES, fromBuffer, fromUploads, fromUrls };
