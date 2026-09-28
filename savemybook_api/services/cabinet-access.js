const prisma = require('../lib/prisma');
const { env } = require('../config/env');
const { HttpError, badRequest } = require('../lib/errors');
const policy = require('../constants/policy');
const { hasPermission } = require('./admin-permissions');

const ONLINE_WINDOW_MS = 15000;
const OFFLINE_FALLBACK_MS = 120000;
const LOCATION_MAX_ACCURACY_M = 500;
const LOCATION_MAX_AGE_MS = 60000;
const LOCATION_STATUSES = ['granted', 'denied', 'unavailable'];

const cabinetsService = () => require('./cabinets');

const isSimulatorEnabled = () => env.cabinetSimulator === true;

// 模擬器關閉後，simulator 裝置即使仍為 active 也不算有效裝置。
const isUsableDevice = (device) =>
  Boolean(device) && device.status === 'active' && (device.kind !== 'simulator' || isSimulatorEnabled());

const lastContact = (device) => device.last_seen_at ?? device.paired_at ?? null;

const isOnline = (device, now = new Date()) => {
  const seen = lastContact(device);
  return Boolean(seen) && now.getTime() - new Date(seen).getTime() <= ONLINE_WINDOW_MS;
};

// 後台以 new Date('1970-01-01THH:MM:00Z') 寫入 TIME 欄位，所以 Date 要取 UTC 時分；測試資料則是 '08:00' 字串。
const timeText = (value) => {
  if (value === null || value === undefined || value === '') return null;
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value.toISOString().slice(11, 16);
  const m = /(?:^|T)(\d{2}):(\d{2})/.exec(String(value));
  return m ? `${m[1]}:${m[2]}` : null;
};

const hoursOf = (cabinet) => ({ open_time: timeText(cabinet?.open_time), close_time: timeText(cabinet?.close_time) });

const formatters = new Map();
const wallClock = (now) => {
  const zone = env.cabinetTimezone || 'Asia/Taipei';
  if (!formatters.has(zone)) {
    formatters.set(zone, new Intl.DateTimeFormat('en-GB', {
      timeZone: zone, hour: '2-digit', minute: '2-digit', hourCycle: 'h23'
    }));
  }
  return formatters.get(zone).format(now);
};

const minutesOf = (text) => Number(text.slice(0, 2)) * 60 + Number(text.slice(3, 5));

const isOpenAt = (cabinet, now = new Date()) => {
  const { open_time: open, close_time: close } = hoursOf(cabinet);
  if (!open || !close || open === close) return true;
  const t = minutesOf(wallClock(now));
  const [o, c] = [minutesOf(open), minutesOf(close)];
  return o < c ? t >= o && t < c : t >= o || t < c;
};

const pickDevices = (devices) => {
  const byCabinet = new Map();
  for (const d of devices) {
    const key = Number(d.cabinet_id);
    if (!byCabinet.has(key)) byCabinet.set(key, []);
    byCabinet.get(key).push(d);
  }
  return byCabinet;
};

const reserveDoors = (available) =>
  (available === null ? null : Math.max(0, available - policy.CABINET_ORDER_RESERVED_DOORS));

const decide = (cabinet, devices, maintenance, now) => {
  const nowMs = now.getTime();
  const active = devices.find(isUsableDevice) ?? null;
  const hours = hoursOf(cabinet);
  const base = {
    online: active ? isOnline(active, now) : false,
    open_now: isOpenAt(cabinet, now),
    open_time: hours.open_time,
    close_time: hours.close_time,
    available_doors: active ? Number(cabinet.available_slots ?? 0) : null,
    pre_deposit_doors: active ? reserveDoors(Number(cabinet.available_slots ?? 0)) : null
  };

  if (!active) {
    const latest = devices
      .filter((d) => d.status === 'revoked' && d.revoked_at)
      .sort((a, b) => new Date(b.revoked_at) - new Date(a.revoked_at))[0];
    const selfRevoked = latest && ['device', 'cloned'].includes(latest.revoke_reason)
      && nowMs - new Date(latest.revoked_at).getTime() <= OFFLINE_FALLBACK_MS;
    return { mode: selfRevoked ? 'scan' : 'manual', reason: 'no_device', ...base };
  }
  if (!cabinet.is_active) return { mode: 'unavailable', reason: 'inactive', ...base };
  if (maintenance.has(Number(cabinet.cabinet_id))) return { mode: 'unavailable', reason: 'maintenance', ...base };

  const seen = lastContact(active);
  if (!seen || nowMs - new Date(seen).getTime() > OFFLINE_FALLBACK_MS) return { mode: 'manual', reason: 'offline', ...base };
  if (active.fault_code && active.fault_since && nowMs - new Date(active.fault_since).getTime() > OFFLINE_FALLBACK_MS) {
    return { mode: 'manual', reason: 'fault', ...base };
  }
  return { mode: 'scan', reason: null, ...base };
};

const DEVICE_FIELDS = {
  device_id: true, cabinet_id: true, kind: true, status: true, last_seen_at: true, paired_at: true,
  fault_code: true, fault_since: true, revoked_at: true, revoke_reason: true
};

const accessFor = async (cabinetIds, now = new Date()) => {
  const ids = [...new Set((cabinetIds ?? []).filter((id) => id !== null && id !== undefined).map(Number))];
  const result = new Map();
  if (ids.length === 0) return result;

  const since = new Date(now.getTime() - OFFLINE_FALLBACK_MS);
  const [cabinets, devices, maintenance] = await Promise.all([
    prisma.smart_cabinets.findMany({
      where: { cabinet_id: { in: ids } },
      select: { cabinet_id: true, is_active: true, open_time: true, close_time: true, available_slots: true }
    }),
    prisma.cabinet_devices.findMany({
      where: {
        cabinet_id: { in: ids },
        OR: [{ status: 'active' }, { status: 'revoked', revoked_at: { gte: since } }]
      },
      select: DEVICE_FIELDS
    }),
    cabinetsService().maintenanceIds()
  ]);

  const byCabinet = pickDevices(devices);
  for (const cabinet of cabinets) {
    result.set(Number(cabinet.cabinet_id), decide(cabinet, byCabinet.get(Number(cabinet.cabinet_id)) ?? [], maintenance, now));
  }
  return result;
};

const publicAccess = (access) => {
  if (!access) return null;
  const { online, ...rest } = access;
  return rest;
};

const scanRequired = (cabinetId) => new HttpError(
  409, '此書櫃已啟用掃碼存取，請至書櫃以 App 掃描 QR Code 辦理', 'CABINET_SCAN_REQUIRED', { cabinet_id: cabinetId }
);

// 業主決策：手動回報一律待管理員確認後才生效（含從未配對裝置的書櫃），audited 表示須改走待確認流程。
const assertManualAllowed = async (cabinetId, user, { buyerId = null, sellerId = null } = {}) => {
  if (cabinetId === null || cabinetId === undefined) return { reason: null, audited: false };
  if (user?.role === 'admin' && user.userId !== buyerId && user.userId !== sellerId
    && await hasPermission(user, 'cabinets')) {
    return { reason: null, audited: false };
  }

  const access = (await accessFor([cabinetId])).get(Number(cabinetId));
  if (!access) return { reason: null, audited: false };
  if (access.mode === 'manual') return { reason: access.reason, audited: true };
  if (access.mode === 'unavailable') {
    throw access.reason === 'maintenance'
      ? new HttpError(409, '此書櫃維修中，暫停服務', 'CABINET_MAINTENANCE')
      : new HttpError(409, '此書櫃暫停服務', 'CABINET_UNAVAILABLE');
  }
  throw scanRequired(Number(cabinetId));
};

const invalidLocation = () => badRequest('定位資料格式不正確');

const nonNegative = (value) => typeof value === 'number' && Number.isFinite(value) && value >= 0;

const checkDistance = (cabinet, { location_status: status, location } = {}) => {
  if (!LOCATION_STATUSES.includes(status)) throw invalidLocation();
  if (status !== 'granted') return { ok: true, status, distance_m: null, accuracy_m: null };

  if (!location || typeof location !== 'object') throw invalidLocation();
  const { lat, lng, accuracy_m: accuracy, age_ms: age } = location;
  const validLat = typeof lat === 'number' && Number.isFinite(lat) && lat >= -90 && lat <= 90;
  const validLng = typeof lng === 'number' && Number.isFinite(lng) && lng >= -180 && lng <= 180;
  if (!validLat || !validLng || (lat === 0 && lng === 0) || !nonNegative(accuracy) || !nonNegative(age)) {
    throw invalidLocation();
  }

  const { distanceMeters } = cabinetsService();
  const distance = distanceMeters(lat, lng, Number(cabinet.latitude), Number(cabinet.longitude));
  const accuracyM = Math.round(accuracy);
  if (accuracy > LOCATION_MAX_ACCURACY_M || age > LOCATION_MAX_AGE_MS) {
    return { ok: true, status: 'unavailable', distance_m: distance, accuracy_m: accuracyM };
  }
  const ok = distance - Math.min(accuracy, 100) <= policy.CABINET_GEOFENCE_M;
  return { ok, status: 'granted', distance_m: distance, accuracy_m: accuracyM };
};

const decorateOrders = async (orders) => {
  const list = Array.isArray(orders) ? orders : [orders];
  if (list.length === 0) return orders;
  const doors = require('./cabinet-doors');
  const [access, doorMap] = await Promise.all([
    accessFor(list.map((o) => o.cabinet_id)),
    doors.orderDoors(list.map((o) => o.order_id))
  ]);
  const shaped = list.map((o) => ({
    ...o,
    cabinet_access: o.cabinet_id == null ? null : publicAccess(access.get(Number(o.cabinet_id))),
    doors: (doorMap.get(Number(o.order_id)) ?? []).map((d) => d.label)
  }));
  return Array.isArray(orders) ? shaped : shaped[0];
};

module.exports = {
  ONLINE_WINDOW_MS, OFFLINE_FALLBACK_MS, LOCATION_MAX_ACCURACY_M, LOCATION_MAX_AGE_MS, LOCATION_STATUSES,
  isSimulatorEnabled, isUsableDevice, isOnline, hoursOf, isOpenAt, accessFor, publicAccess,
  assertManualAllowed, checkDistance, decorateOrders
};
