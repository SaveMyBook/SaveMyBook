const express = require('express');
const authenticateToken = require('../middleware/auth');
const { rateLimit, byUser } = require('../middleware/rateLimit');
const v = require('../lib/validate');
const { badRequest, HttpError } = require('../lib/errors');
const cabinets = require('../services/cabinets');
const transit = require('../services/transit');

const router = express.Router();

const MINUTE = 60 * 1000;
const transitLimit = rateLimit({ windowMs: MINUTE, max: 60, key: byUser, message: '查詢交通資訊過於頻繁，請稍後再試' });

const readPoint = (query) => {
  if (query.lat === undefined && query.lng === undefined) return null;
  const lat = v.number(query.lat, { label: '緯度', min: -90, max: 90 });
  const lng = v.number(query.lng, { label: '經度', min: -180, max: 180 });
  if (lat === 0 && lng === 0) throw badRequest('座標不正確');
  return { lat, lng };
};

const unavailable = () => new HttpError(503, '暫時無法取得捷運資料，請稍後再試', 'TRANSIT_UNAVAILABLE');

router.get('/', authenticateToken, async (req, res) => {
  const data = await cabinets.listActive(readPoint(req.query));
  res.status(200).json({ success: true, data });
});

// 起站清單附座標，由 App 在手機上算出使用者最近的車站，使用者位置不傳到伺服器。
router.get('/mrt-stations', authenticateToken, transitLimit, async (req, res) => {
  const data = await transit.stations();
  if (!data) throw unavailable();
  res.status(200).json({ success: true, data });
});

router.get('/mrt-fares', authenticateToken, transitLimit, async (req, res) => {
  const from = v.text(req.query.from, { label: '起站', max: 20 });
  const to = v.text(req.query.to, { label: '訖站', max: 100 }).split(',').map((s) => s.trim()).filter(Boolean);
  if (!from || !to.length) throw badRequest('請提供起站與訖站');
  if (to.length > 3) throw badRequest('訖站最多 3 站');
  const data = await transit.fares(from, to);
  if (!data) throw unavailable();
  if (data.unknown_station) throw badRequest('查無此捷運站');
  res.status(200).json({ success: true, data });
});

router.get('/:id/nearby', authenticateToken, transitLimit, async (req, res) => {
  const { lat, lng } = await cabinets.locationOf(v.id(req.params.id, '書櫃編號'));
  res.status(200).json({ success: true, data: { cabinet: { latitude: lat, longitude: lng }, ...await transit.nearby(lat, lng) } });
});

module.exports = router;
