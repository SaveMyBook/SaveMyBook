const express = require('express');
const authenticateToken = require('../middleware/auth');
const v = require('../lib/validate');
const { badRequest } = require('../lib/errors');
const cabinets = require('../services/cabinets');

const router = express.Router();

const readPoint = (query) => {
  if (query.lat === undefined && query.lng === undefined) return null;
  const lat = v.number(query.lat, { label: '緯度', min: -90, max: 90 });
  const lng = v.number(query.lng, { label: '經度', min: -180, max: 180 });
  if (lat === 0 && lng === 0) throw badRequest('座標不正確');
  return { lat, lng };
};

router.get('/', authenticateToken, async (req, res) => {
  const data = await cabinets.listActive(readPoint(req.query));
  res.status(200).json({ success: true, data });
});

module.exports = router;
