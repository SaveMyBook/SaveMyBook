const express = require('express');
const prisma = require('../lib/prisma');
const { rateLimit, byIp } = require('../middleware/rateLimit');
const { deviceAuth } = require('../middleware/device-auth');
const devices = require('../services/cabinet-devices');

const router = express.Router();

const MINUTE = 60 * 1000;
const FIRMWARE_RE = /^[\x20-\x7e]{1,40}$/;

const byDevice = (req) => `d:${req.device.device_id}`;

const pairPerIp = rateLimit({ windowMs: 10 * MINUTE, max: 10, key: byIp });
const pairGlobal = rateLimit({ windowMs: MINUTE, max: 30, key: () => 'pair' });
const stateLimit = rateLimit({ windowMs: MINUTE, max: 240, key: byDevice });
const eventsLimit = rateLimit({ windowMs: MINUTE, max: 120, key: byDevice });
const unpairLimit = rateLimit({ windowMs: MINUTE, max: 10, key: byDevice });

const freshDevice = async (device) =>
  (await prisma.cabinet_devices.findUnique({ where: { device_id: device.device_id } })) ?? device;

const readPairing = (req) => {
  const body = req.body;
  const bootId = req.get('x-device-boot');
  const valid = devices.isValidBootId(bootId)
    && typeof body.code === 'string'
    && devices.KINDS.includes(body.kind)
    && Number.isInteger(body.door_count) && body.door_count >= 1 && body.door_count <= 8
    && (body.has_door_sensor === undefined || typeof body.has_door_sensor === 'boolean')
    && Number.isInteger(body.unlock_pulse_ms) && body.unlock_pulse_ms >= 100 && body.unlock_pulse_ms <= 10000
    && typeof body.firmware === 'string' && FIRMWARE_RE.test(body.firmware);
  if (!valid) throw devices.payloadInvalid();
  return {
    code: body.code,
    kind: body.kind,
    doorCount: body.door_count,
    hasDoorSensor: body.has_door_sensor === true,
    unlockPulseMs: body.unlock_pulse_ms,
    firmware: body.firmware,
    bootId
  };
};

router.post('/pair', pairPerIp, pairGlobal, async (req, res) => {
  const data = await devices.pair({ ...readPairing(req), ip: req.ip, now: new Date() });
  res.status(201).json({ success: true, data });
});

router.post('/unpair', deviceAuth, unpairLimit, async (req, res) => {
  await devices.unpair(req.device, new Date());
  res.status(200).json({ success: true });
});

router.get('/state', deviceAuth, stateLimit, async (req, res) => {
  res.set('Cache-Control', 'no-store');
  const data = await devices.stateFor(req.device, new Date());
  res.status(200).json({ success: true, data });
});

router.post('/events', deviceAuth, eventsLimit, async (req, res) => {
  const { events } = req.body;
  if (!Array.isArray(events) || events.length === 0 || events.length > devices.MAX_EVENTS) throw devices.payloadInvalid();

  const results = await devices.handleEvents(req.device, events, new Date());
  const state = await devices.stateFor(await freshDevice(req.device), new Date());
  res.set('Cache-Control', 'no-store');
  res.status(200).json({ success: true, data: { results, state } });
});

module.exports = router;
