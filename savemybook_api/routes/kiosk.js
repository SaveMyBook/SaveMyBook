const express = require('express');
const path = require('path');
const { env } = require('../config/env');
const { kioskPage } = require('../views/kiosk-page');

const router = express.Router();

const ASSET_DIR = path.join(__dirname, '../views/kiosk');
const ASSETS = new Set(['device-core.js', 'kiosk.js', 'qrcode.js', 'kiosk.css', 'book-slate-128.png']);

const HEADERS = {
  'Content-Security-Policy': "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; font-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
  'Referrer-Policy': 'no-referrer',
  'X-Robots-Tag': 'noindex, nofollow',
  'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
  'X-Frame-Options': 'DENY',
  'X-Content-Type-Options': 'nosniff'
};

const notFound = (res) => res.status(404).set('Cache-Control', 'no-store').type('text/plain').send('找不到此頁面');

router.use((req, res, next) => {
  res.set(HEADERS);
  if (!env.cabinetSimulator) return notFound(res);
  next();
});

router.get('/', (req, res) => {
  res.set('Cache-Control', 'no-store');
  res.status(200).type('html').send(kioskPage({ base: req.baseUrl }));
});

router.get('/assets/:file', (req, res) => {
  const file = req.params.file;
  if (!ASSETS.has(file)) return notFound(res);
  res.set('Cache-Control', 'no-cache');
  res.sendFile(path.join(ASSET_DIR, file), (err) => {
    if (err && !res.headersSent) notFound(res);
  });
});

router.use((req, res) => notFound(res));

module.exports = router;
