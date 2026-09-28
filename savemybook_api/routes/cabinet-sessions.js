const express = require('express');
const authenticateToken = require('../middleware/auth');
const { rateLimit, byUser } = require('../middleware/rateLimit');
const { badRequest } = require('../lib/errors');
const sessions = require('../services/cabinet-sessions');

const router = express.Router();

const MINUTE = 60 * 1000;
const CODE_MAX = 200;

const createLimit = rateLimit({ windowMs: MINUTE, max: 10, key: byUser });
const actionLimit = rateLimit({ windowMs: MINUTE, max: 20, key: byUser });
const readLimit = rateLimit({ windowMs: MINUTE, max: 120, key: byUser });

router.use(authenticateToken);

const readContext = (value) => {
  if (value === undefined || value === null) return null;
  const valid = typeof value === 'object' && ['order', 'book'].includes(value.type) && Number.isSafeInteger(value.id) && value.id > 0;
  if (!valid) throw badRequest('作業情境格式不正確');
  return { type: value.type, id: value.id };
};

router.post('/', createLimit, async (req, res) => {
  const { code, location_status: locationStatus, location } = req.body;
  if (typeof code !== 'string' || code.length === 0 || code.length > CODE_MAX) throw badRequest('請提供書櫃 QR Code 內容');
  const context = readContext(req.body.context);
  const place = { location_status: locationStatus, location };
  sessions.validateLocation(place);

  const { created, session } = await sessions.create({ user: req.user, code, context, location: place, now: new Date() });
  res.status(created ? 201 : 200).json({ success: true, data: session });
});

router.get('/active', readLimit, async (req, res) => {
  res.set('Cache-Control', 'no-store');
  res.status(200).json({ success: true, data: await sessions.active(req.user) });
});

router.get('/:sessionNo', readLimit, async (req, res) => {
  res.set('Cache-Control', 'no-store');
  res.status(200).json({ success: true, data: await sessions.get(req.params.sessionNo, req.user) });
});

router.post('/:sessionNo/start', actionLimit, async (req, res) => {
  const data = await sessions.start(req.params.sessionNo, req.user, req.body.keys);
  res.status(200).json({ success: true, data });
});

router.post('/:sessionNo/cancel', actionLimit, async (req, res) => {
  const data = await sessions.cancel(req.params.sessionNo, req.user);
  res.status(200).json({ success: true, data });
});

module.exports = router;
