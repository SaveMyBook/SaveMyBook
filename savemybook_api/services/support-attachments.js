const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const prisma = require('../lib/prisma');
const { env } = require('../config/env');
const { placeholders } = require('../lib/sql');
const { UPLOAD_ROOT } = require('../lib/upload');
const { badRequest } = require('../lib/errors');

const FOLDER = 'support';
const MAX_PER_MESSAGE = 4;
const MAX_FILE_BYTES = 10 * 1024 * 1024;
const MAX_PENDING = 20;
const PENDING_TTL_MS = 24 * 3600 * 1000;
const LINK_WINDOW_S = 6 * 3600;
const EXPORT_LINK_S = 7 * 24 * 3600;

const URL_RE = /^\/uploads\/support\/([\w-]+\.(?:jpg|png|gif|webp|heic|heif))$/;
const FILE_RE = /^[\w-]+\.(jpg|png|gif|webp|heic|heif)$/;

const MIME = {
  jpg: 'image/jpeg', png: 'image/png', gif: 'image/gif', webp: 'image/webp', heic: 'image/heic', heif: 'image/heif'
};

let cachedKey = null;
const signingKey = () => {
  cachedKey ??= crypto.createHmac('sha256', env.jwtSecret || 'savemybook').update('support-attachment-v1').digest();
  return cachedKey;
};

const signatureOf = (file, exp) =>
  crypto.createHmac('sha256', signingKey()).update(`${file}.${exp}`).digest('base64url').slice(0, 32);

// 到期時間取整到時段邊界：同一時段內網址不變，App 的圖片快取才不會每次重新下載。
const signedUrl = (url, { ttl } = {}) => {
  const match = URL_RE.exec(url ?? '');
  if (!match) return null;
  const now = Math.floor(Date.now() / 1000);
  const exp = ttl ? now + ttl : (Math.floor(now / LINK_WINDOW_S) + 2) * LINK_WINDOW_S;
  return `/api/support/attachments/${match[1]}?exp=${exp}&sig=${signatureOf(match[1], exp)}`;
};

const verifyLink = (file, exp, sig) => {
  if (!FILE_RE.test(file ?? '')) return false;
  const expiry = Number(exp);
  if (!Number.isSafeInteger(expiry) || expiry < Math.floor(Date.now() / 1000)) return false;
  const expected = Buffer.from(signatureOf(file, expiry));
  const given = Buffer.from(String(sig ?? ''));
  return given.length === expected.length && crypto.timingSafeEqual(given, expected);
};

const fileInfo = (file) => ({
  path: path.join(UPLOAD_ROOT, FOLDER, file),
  mime: MIME[FILE_RE.exec(file)[1]]
});

const unlinkUrls = (urls) => {
  for (const url of urls) {
    const match = URL_RE.exec(url ?? '');
    if (match) fs.promises.unlink(path.join(UPLOAD_ROOT, FOLDER, match[1])).catch(() => {});
  }
};

/** 解析請求中的 attachments 欄位；未帶或空陣列回傳空陣列。 */
const parseUrls = (value) => {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value)) throw badRequest('附件格式不正確');
  if (value.length > MAX_PER_MESSAGE) throw badRequest(`每則訊息最多附加 ${MAX_PER_MESSAGE} 張圖片`);
  const urls = value.map((item) => (typeof item === 'string' ? item.trim() : ''));
  if (urls.some((url) => !URL_RE.test(url))) throw badRequest('圖片請先透過 /api/uploads/support-image 上傳');
  if (new Set(urls).size !== urls.length) throw badRequest('附件不可重複');
  return urls;
};

const pendingCount = async (userId) => {
  const rows = await prisma.$queryRaw`
    SELECT COUNT(*) AS n FROM support_ticket_attachments
    WHERE uploader_id = ${userId} AND message_id IS NULL AND created_at > ${new Date(Date.now() - PENDING_TTL_MS)}`;
  return Number(rows[0]?.n ?? 0);
};

const assertCanUpload = async (userId) => {
  if ((await pendingCount(userId)) >= MAX_PENDING) {
    throw badRequest('尚未送出的圖片過多，請先送出或稍後再試', 'SUPPORT_ATTACHMENTS_PENDING_LIMIT');
  }
};

const recordUpload = async (userId, { url, size }) => {
  await prisma.$executeRaw`
    INSERT INTO support_ticket_attachments (uploader_id, url, byte_size, created_at)
    VALUES (${userId}, ${url}, ${Math.max(0, Number(size) || 0)}, ${new Date()})`;
};

// 送出前先檢查，避免工單或訊息已建立才發現附件無效。
const assertClaimable = async (userId, urls) => {
  if (urls.length === 0) return;
  const rows = await prisma.$queryRawUnsafe(
    `SELECT url FROM support_ticket_attachments
     WHERE uploader_id = ? AND message_id IS NULL AND url IN (${placeholders(urls)})`,
    userId, ...urls
  );
  if (rows.length !== urls.length) throw badRequest('部分圖片無法使用，請重新上傳後再送出', 'SUPPORT_ATTACHMENT_INVALID');
};

// 逐張以條件更新並核對筆數：同一張圖片被兩則訊息同時使用時，後到者整筆交易會回滾。
const claim = async (tx, userId, urls, messageId) => {
  for (const [index, url] of urls.entries()) {
    const count = await tx.$executeRaw`
      UPDATE support_ticket_attachments SET message_id = ${messageId}, sort_order = ${index}
      WHERE url = ${url} AND uploader_id = ${userId} AND message_id IS NULL`;
    if (Number(count) !== 1) throw badRequest('部分圖片無法使用，請重新上傳後再送出', 'SUPPORT_ATTACHMENT_INVALID');
  }
};

/** 依訊息編號取得附件，回傳 Map<message_id, [{ url }]>。 */
const forMessages = async (messageIds, { ttl } = {}) => {
  const map = new Map();
  if (messageIds.length === 0) return map;
  const rows = await prisma.$queryRawUnsafe(
    `SELECT message_id, url, sort_order FROM support_ticket_attachments
     WHERE message_id IN (${placeholders(messageIds)}) ORDER BY sort_order`,
    ...messageIds
  );
  for (const row of rows) {
    const url = signedUrl(row.url, { ttl });
    if (!url) continue;
    const id = Number(row.message_id);
    if (!map.has(id)) map.set(id, []);
    map.get(id).push({ url });
  }
  return map;
};

// 本人上傳的附件，以及本人工單內的所有附件（含客服回覆的截圖）一併移除。
const purgeUser = async (tx, userId) => {
  const rows = await tx.$queryRaw`
    SELECT a.url AS url FROM support_ticket_attachments a
    LEFT JOIN support_ticket_messages m ON m.message_id = a.message_id
    LEFT JOIN support_tickets t ON t.ticket_id = m.ticket_id
    WHERE a.uploader_id = ${userId} OR t.user_id = ${userId}`;
  const urls = rows.map((r) => r.url);
  if (urls.length > 0) {
    await tx.$executeRawUnsafe(`DELETE FROM support_ticket_attachments WHERE url IN (${placeholders(urls)})`, ...urls);
  }
  return urls;
};

const purgeStale = async () => {
  const rows = await prisma.$queryRaw`
    SELECT attachment_id, url FROM support_ticket_attachments
    WHERE message_id IS NULL AND created_at < ${new Date(Date.now() - PENDING_TTL_MS)}`;
  if (rows.length === 0) return 0;
  const ids = rows.map((r) => Number(r.attachment_id));
  await prisma.$executeRawUnsafe(
    `DELETE FROM support_ticket_attachments WHERE attachment_id IN (${placeholders(ids)}) AND message_id IS NULL`,
    ...ids
  );
  unlinkUrls(rows.map((r) => r.url));
  return rows.length;
};

module.exports = {
  FOLDER, MAX_PER_MESSAGE, MAX_FILE_BYTES, EXPORT_LINK_S,
  parseUrls, assertCanUpload, recordUpload, assertClaimable, claim,
  forMessages, signedUrl, verifyLink, fileInfo, purgeUser, purgeStale, unlinkUrls
};
