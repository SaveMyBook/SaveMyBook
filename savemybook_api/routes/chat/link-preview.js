const express = require('express');
const { rateLimit, byUser } = require('../../middleware/rateLimit');
const v = require('../../lib/validate');
const { badRequest } = require('../../lib/errors');
const linkPreview = require('../../services/link-preview');

const router = express.Router();

const previewLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  key: byUser,
  message: '連結預覽請求過於頻繁，請稍後再試'
});

const imageLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 120,
  key: byUser,
  message: '圖片載入請求過於頻繁，請稍後再試'
});

router.get('/link-preview', previewLimiter, async (req, res) => {
  const url = v.text(req.query.url, { label: '網址', max: linkPreview.MAX_URL_LENGTH });
  if (!url) throw badRequest('請提供網址');
  const data = await linkPreview.preview(url);
  res.status(200).json({ success: true, data });
});

router.get('/link-preview/image', imageLimiter, async (req, res) => {
  const { contentType, body } = await linkPreview.image(req.query.u);
  res.set({
    'Content-Type': contentType,
    'Content-Length': String(body.length),
    'Cache-Control': 'private, max-age=86400, immutable',
    'Content-Disposition': 'inline',
    'Content-Security-Policy': "default-src 'none'; sandbox",
    'X-Content-Type-Options': 'nosniff'
  });
  res.status(200).end(body);
});

module.exports = router;
