const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');
const v = require('../lib/validate');
const { badRequest } = require('../lib/errors');

const router = express.Router();

const EARTH_RADIUS_M = 6371000;

const toRad = (deg) => (deg * Math.PI) / 180;

const distanceMeters = (lat1, lng1, lat2, lng2) => {
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return Math.round(2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(a))));
};

const readPoint = (query) => {
  if (query.lat === undefined && query.lng === undefined) return null;
  const lat = v.number(query.lat, { label: '緯度', min: -90, max: 90 });
  const lng = v.number(query.lng, { label: '經度', min: -180, max: 180 });
  if (lat === 0 && lng === 0) throw badRequest('座標不正確');
  return { lat, lng };
};

router.get('/', authenticateToken, async (req, res) => {
  const point = readPoint(req.query);
  const cabinets = await prisma.smart_cabinets.findMany({
    where: { is_active: true },
    select: {
      cabinet_id: true,
      cabinet_name: true,
      address: true,
      available_slots: true,
      latitude: true,
      longitude: true,
      open_time: true,
      close_time: true
    },
    orderBy: { cabinet_id: 'asc' }
  });

  const data = cabinets.map((c) => ({
    ...c,
    distance_m: point ? distanceMeters(point.lat, point.lng, Number(c.latitude), Number(c.longitude)) : null
  }));
  if (point) data.sort((a, b) => a.distance_m - b.distance_m);

  res.status(200).json({ success: true, data });
});

module.exports = router;
module.exports.distanceMeters = distanceMeters;
