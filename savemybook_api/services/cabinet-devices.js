const crypto = require('crypto');
const prisma = require('../lib/prisma');
const publicId = require('../lib/public-id');
const { env } = require('../config/env');
const { HttpError, notFound } = require('../lib/errors');
const access = require('./cabinet-access');
const doors = require('./cabinet-doors');
const challenges = require('./cabinet-challenges');
const { recordEvent, notifyAdmins } = require('./cabinet-events');

const TOUCH_THROTTLE_MS = 5000;
const CONNECTION_LOST_MS = 60000;
const OFFLINE_ALERT_MS = 300000;
const PAIRING_TTL_MS = 600000;
const BOOT_GRACE_MS = 30000;
const EVENT_CLAIM_MS = 30000;
const UNLOCK_SERVE_MS = 8000;
const ROUNDTRIP_MAX_MS = 3000;
const LOCK_GAP_MS = 300;
const ACK_GRACE_MS = 5000;
const IDLE_POLL_MS = 2000;
const SESSION_POLL_MS = 1000;
const MAX_EVENTS = 20;
const MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000;
const EVENT_RETENTION_MS = 365 * 24 * 60 * 60 * 1000;
const PENDING_RETENTION_MS = 24 * 60 * 60 * 1000;
const MAX_DETAIL_LENGTH = 2000;

const KINDS = ['simulator', 'esp32'];
const KIND_LABELS = { simulator: '模擬書櫃', esp32: '實體書櫃' };
const EVENT_TYPES = [
  'boot', 'match_selected', 'session_cancel', 'door_opened', 'door_closed', 'session_closed',
  'fault', 'fault_cleared', 'door_forced', 'connection_restored'
];
const SESSION_EVENTS = ['match_selected', 'session_cancel', 'door_opened', 'door_closed', 'session_closed'];
const CHANNEL_EVENTS = ['door_opened', 'door_closed', 'door_forced'];
const SENSOR_STATES = ['open', 'closed'];
const EVENT_ID_RE = /^[A-Za-z0-9_-]{8,64}$/;
const BOOT_ID_RE = /^[a-z0-9]{6,16}$/;
const FAULT_CODE_RE = /^[A-Z][A-Z0-9_]{0,39}$/;
const FIRMWARE_RE = /^[\x20-\x7e]{1,40}$/;

const FAULT_LABELS = {
  LOCK_NO_RELEASE: '電磁鎖未釋放',
  DOOR_LEFT_OPEN: '櫃門未關閉',
  DOOR_FORCED: '櫃門遭強制開啟',
  SENSOR_ERROR: '感測器異常',
  POWER: '電源異常',
  SCREEN: '螢幕異常'
};

const faultLabel = (code) => FAULT_LABELS[code] ?? `故障代碼 ${code}`;

const deviceError = (status, code, message) => new HttpError(status, message, code);
const authRequired = () => deviceError(401, 'DEVICE_AUTH_REQUIRED', '缺少裝置憑證');
const revokedError = () => deviceError(401, 'DEVICE_REVOKED', '裝置憑證已失效，請重新配對');
const disabledError = () => deviceError(403, 'DEVICE_DISABLED', '模擬書櫃目前未開放');
const pairingInvalid = () => deviceError(400, 'PAIRING_CODE_INVALID', '配對碼無效或已逾時');
const payloadInvalid = () => deviceError(400, 'DEVICE_PAYLOAD_INVALID', '資料格式不正確');
const staleBoot = () => deviceError(409, 'DEVICE_STALE_BOOT', '此請求來自裝置重新啟動前，已略過');
const cabinetBusy = () => deviceError(409, 'CABINET_BUSY', '書櫃使用中，請待目前作業結束後再試');

const sha256 = (text) => crypto.createHash('sha256').update(String(text)).digest('hex');
const newToken = () => `smbd_${crypto.randomBytes(32).toString('base64url')}`;
const deviceNo = (device) => publicId.encode('cabinet_device', device.device_id);
const isValidBootId = (value) => typeof value === 'string' && BOOT_ID_RE.test(value);

const openingAckMs = (doorCount, pulseMs) =>
  UNLOCK_SERVE_MS + ROUNDTRIP_MAX_MS + doorCount * (pulseMs + LOCK_GAP_MS) + ACK_GRACE_MS;

// 呼叫端須先確認作業在 opening 階段。
const unlockCommands = ({ sessionNo, matchedAt, doors: sessionDoors, pulseMs }, now = new Date()) => {
  if (!matchedAt) return [];
  const expiresIn = new Date(matchedAt).getTime() + UNLOCK_SERVE_MS - now.getTime();
  if (expiresIn <= 0) return [];
  return sessionDoors
    .filter((d) => d.state === 'pending')
    .sort((a, b) => a.lock_channel - b.lock_channel)
    .map((d) => ({
      id: `${sessionNo}:${d.lock_channel}:1`, type: 'unlock', channel: d.lock_channel, release_ms: pulseMs, expires_in_ms: expiresIn
    }));
};

// 回應即使在網路上遺失也視為已送出，之後以 DEVICE_NO_ACK 保守處理。
const markCommandsServed = (db, sessionId, slotIds, now = new Date()) => (db ?? prisma).cabinet_session_doors.updateMany({
  where: { session_id: Number(sessionId), slot_id: { in: slotIds.map(Number) }, command_served_at: null },
  data: { command_served_at: now }
});

// ---------- 作業處理器 ----------

let handler = null;

const registerSessionHandler = (next) => {
  handler = next ?? null;
};

const sessionHandler = () => handler;

const runSessionSweep = async (now = new Date()) => {
  if (handler?.sweep) await handler.sweep(now);
};

// ---------- 裝置查詢與占用 ----------

const activeDeviceOf = async (cabinetId, { tx } = {}) => {
  const device = await (tx ?? prisma).cabinet_devices.findFirst({
    where: { active_cabinet_id: Number(cabinetId), status: 'active' }
  });
  return access.isUsableDevice(device) ? device : null;
};

const lockForSession = async (tx, deviceId, sessionId) => {
  const locked = await (tx ?? prisma).cabinet_devices.updateMany({
    where: { device_id: Number(deviceId), status: 'active', active_session_id: null },
    data: { active_session_id: Number(sessionId) }
  });
  if (locked.count === 0) throw cabinetBusy();
};

const releaseSession = (tx, deviceId, sessionId) => (tx ?? prisma).cabinet_devices.updateMany({
  where: { device_id: Number(deviceId), active_session_id: Number(sessionId) },
  data: { active_session_id: null }
});

const cabinetNameOf = async (db, cabinetId) =>
  (await db.smart_cabinets.findUnique({ where: { cabinet_id: Number(cabinetId) }, select: { cabinet_name: true } }))
    ?.cabinet_name ?? '';

// ---------- 撤銷 ----------

const revoke = async (db, device, { reason, actorId = null, note = null, now = new Date(), source = 'server' }) => {
  const client = db ?? prisma;
  const done = await client.cabinet_devices.updateMany({
    where: { device_id: device.device_id, status: 'active' },
    data: {
      status: 'revoked', active_cabinet_id: null, token_hash: null, revoked_at: now, revoke_reason: reason,
      revoked_by: actorId, updated_at: now
    }
  });
  if (done.count === 0) return false;
  await recordEvent(client, {
    cabinetId: device.cabinet_id, deviceId: device.device_id, type: 'revoked', source, actorId,
    detail: { reason, ...(note ? { note } : {}) }, occurredAt: now
  });
  return true;
};

// ---------- 配對 ----------

const displayCode = (digits) => `${digits.slice(0, 4)}-${digits.slice(4)}`;

const normalizePairingCode = (value) => {
  const digits = String(value ?? '').replace(/[-\s]/g, '');
  return /^\d{8}$/.test(digits) ? digits : null;
};

const createPairingCode = async ({ cabinetId, kind, doorCount = 4, adminId = null, now = new Date() }) => {
  if (kind === 'simulator' && !access.isSimulatorEnabled()) throw disabledError();
  const cabinet = await prisma.smart_cabinets.findUnique({ where: { cabinet_id: Number(cabinetId) } });
  if (!cabinet) throw notFound('找不到該書櫃');

  let digits;
  let hash;
  for (let attempt = 0; attempt < 10; attempt += 1) {
    digits = String(crypto.randomInt(0, 100000000)).padStart(8, '0');
    hash = sha256(digits);
    const clash = await prisma.cabinet_devices.count({ where: { pairing_code_hash: hash } });
    if (clash === 0) break;
  }

  const expiresAt = new Date(now.getTime() + PAIRING_TTL_MS);
  const device = await prisma.$transaction(async (tx) => {
    await tx.cabinet_devices.deleteMany({ where: { cabinet_id: cabinet.cabinet_id, status: 'pending' } });
    return tx.cabinet_devices.create({
      data: {
        cabinet_id: cabinet.cabinet_id, kind, door_count: doorCount, status: 'pending', pairing_code_hash: hash,
        pairing_expires_at: expiresAt, created_by: adminId, created_at: now, updated_at: now
      }
    });
  });
  return { code: displayCode(digits), kind, door_count: doorCount, expires_at: expiresAt, device, cabinet };
};

const pair = async ({
  code, kind, doorCount, hasDoorSensor = false, unlockPulseMs = 800, firmware = null, bootId, ip = null, now = new Date()
}) => {
  const digits = normalizePairingCode(code);
  if (!digits) throw pairingInvalid();
  const hash = sha256(digits);
  const row = await prisma.cabinet_devices.findFirst({
    where: { pairing_code_hash: hash, status: 'pending', pairing_expires_at: { gt: now } }
  });
  if (!row || row.kind !== kind || Number(row.door_count) !== Number(doorCount)) throw pairingInvalid();
  if (row.kind === 'simulator' && !access.isSimulatorEnabled()) throw disabledError();

  const token = newToken();
  const result = await prisma.$transaction(async (tx) => {
    const claimed = await tx.cabinet_devices.updateMany({
      where: { device_id: row.device_id, status: 'pending', pairing_code_hash: hash, pairing_expires_at: { gt: now } },
      data: { pairing_code_hash: null, pairing_expires_at: null, updated_at: now }
    });
    if (claimed.count === 0) throw pairingInvalid();

    const previous = await tx.cabinet_devices.findMany({ where: { cabinet_id: row.cabinet_id, status: 'active' } });
    let replaced = false;
    for (const old of previous) replaced = (await revoke(tx, old, { reason: 'replaced', now })) || replaced;

    await tx.cabinet_devices.updateMany({
      where: { device_id: row.device_id },
      data: {
        status: 'active', active_cabinet_id: row.cabinet_id, token_hash: sha256(token), has_door_sensor: Boolean(hasDoorSensor),
        unlock_pulse_ms: unlockPulseMs, firmware, current_boot_id: bootId, previous_boot_id: null, boot_switched_at: null,
        paired_at: now, last_seen_at: now, last_ip: ip, offline_since: null, offline_notified: false,
        fault_code: null, fault_since: null, updated_at: now
      }
    });
    await doors.syncChannels(tx, row.cabinet_id, Number(row.door_count));
    await recordEvent(tx, {
      cabinetId: row.cabinet_id, deviceId: row.device_id, type: 'paired', source: 'server',
      detail: { kind: row.kind, ip, replaced }, occurredAt: now
    });

    const cabinetName = await cabinetNameOf(tx, row.cabinet_id);
    await notifyAdmins(tx, row.cabinet_id, {
      title: '書櫃裝置已配對',
      content: `「${cabinetName}」已完成${KIND_LABELS[row.kind]}裝置配對（來源 IP：${ip ?? '不明'}）。${replaced ? '原有的有效裝置已撤銷。' : ''}`
    });
    return { cabinetName, doorList: await doors.doorsOf(row.cabinet_id, { tx }) };
  });

  return {
    token,
    device_no: deviceNo(row),
    cabinet: { cabinet_name: result.cabinetName },
    doors: result.doorList.map((d) => ({ channel: d.lock_channel, label: doors.doorLabel(d.lock_channel) })),
    poll_ms: IDLE_POLL_MS
  };
};

const unpair = async (device, now = new Date()) => {
  await prisma.$transaction(async (tx) => {
    if (!(await revoke(tx, device, { reason: 'device', now }))) return;
    const cabinetName = await cabinetNameOf(tx, device.cabinet_id);
    await notifyAdmins(tx, device.cabinet_id, {
      title: '書櫃裝置已解除配對',
      content: `「${cabinetName}」的書櫃裝置已自行解除配對，書櫃將於 2 分鐘後開放手動回報。`
    });
  });
};

// ---------- 驗證（middleware/device-auth.js 使用） ----------

const findByToken = (token) => prisma.cabinet_devices.findUnique({ where: { token_hash: sha256(token) } });

const reportClone = async (device, { got, ip, now }) => {
  await prisma.$transaction(async (tx) => {
    await recordEvent(tx, {
      cabinetId: device.cabinet_id, deviceId: device.device_id, type: 'device_cloned', source: 'server',
      detail: { expected: device.current_boot_id, got, ip }, occurredAt: now
    });
    if (!(await revoke(tx, device, { reason: 'cloned', now }))) return;
    const cabinetName = await cabinetNameOf(tx, device.cabinet_id);
    await notifyAdmins(tx, device.cabinet_id, {
      title: '書櫃裝置憑證疑遭複製',
      content: `「${cabinetName}」的裝置憑證同時由兩個來源使用，系統已撤銷此裝置，請確認書櫃後重新配對。`
    });
  });
};

const verifyBoot = async (device, { bootId, bootEventId = null, ip = null, now = new Date() }) => {
  const current = device.current_boot_id;
  if (bootId === current) return device;

  if (!current) {
    await prisma.cabinet_devices.updateMany({ where: { device_id: device.device_id, current_boot_id: null }, data: { current_boot_id: bootId } });
    return { ...device, current_boot_id: bootId };
  }

  if (bootEventId && bootEventId === bootId) {
    const switched = await prisma.cabinet_devices.updateMany({
      where: { device_id: device.device_id, current_boot_id: current },
      data: { previous_boot_id: current, current_boot_id: bootId, boot_switched_at: now }
    });
    if (switched.count > 0) return { ...device, previous_boot_id: current, current_boot_id: bootId, boot_switched_at: now };
    const fresh = await prisma.cabinet_devices.findUnique({ where: { device_id: device.device_id } });
    if (fresh?.current_boot_id === bootId) return fresh;
  }

  const switchedAt = device.boot_switched_at ? new Date(device.boot_switched_at).getTime() : 0;
  if (bootId === device.previous_boot_id && now.getTime() - switchedAt <= BOOT_GRACE_MS) throw staleBoot();

  await reportClone(device, { got: bootId, ip, now });
  throw revokedError();
};

const touch = async (device, ip, now = new Date()) => {
  const data = {};
  const lastSeen = device.last_seen_at ? new Date(device.last_seen_at).getTime() : 0;
  const ipChanged = Boolean(ip) && Boolean(device.last_ip) && device.last_ip !== ip;

  if (ipChanged) {
    await recordEvent(prisma, {
      cabinetId: device.cabinet_id, deviceId: device.device_id, type: 'ip_changed', source: 'server',
      detail: { from: device.last_ip, to: ip }, occurredAt: now
    });
  }
  if (device.offline_since) {
    await recordEvent(prisma, {
      cabinetId: device.cabinet_id, deviceId: device.device_id, type: 'connection_restored', source: 'server',
      detail: { offline_ms: Math.max(0, now.getTime() - new Date(device.offline_since).getTime()) }, occurredAt: now
    });
    data.offline_since = null;
    data.offline_notified = false;
  }
  if (now.getTime() - lastSeen >= TOUCH_THROTTLE_MS || ipChanged || !device.last_ip || data.offline_since === null) {
    data.last_seen_at = now;
    if (ip) data.last_ip = ip;
  }
  if (Object.keys(data).length === 0) return device;
  await prisma.cabinet_devices.updateMany({ where: { device_id: device.device_id }, data });
  return { ...device, ...data };
};

// ---------- 狀態 ----------

const message = (code, params = {}) => ({ code, params });

const stateFor = async (device, now = new Date()) => {
  const view = handler?.deviceView ? await handler.deviceView(device, now) : null;
  const [cabinet, doorList, maintenance] = await Promise.all([
    prisma.smart_cabinets.findUnique({ where: { cabinet_id: device.cabinet_id } }),
    doors.doorsOf(device.cabinet_id),
    require('./cabinets').maintenanceIds()
  ]);

  const base = {
    device_no: deviceNo(device),
    cabinet_name: cabinet?.cabinet_name ?? ''
  };
  const doorView = doorList.map((d) => ({
    channel: d.lock_channel,
    label: doors.doorLabel(d.lock_channel),
    enabled: doors.isUsable(d),
    sensor: device.has_door_sensor ? d.sensor_state ?? null : null
  }));
  const idleState = (screen, msg, qr = null) => ({
    ...base, screen, message: msg, poll_ms: IDLE_POLL_MS, qr, session: null, commands: [], doors: doorView
  });

  if (view) {
    return {
      ...base,
      screen: view.screen,
      message: view.message ?? message('PROCESSING'),
      poll_ms: view.poll_ms ?? SESSION_POLL_MS,
      qr: null,
      session: view.session ?? null,
      commands: view.commands ?? [],
      doors: doorView
    };
  }
  if (!cabinet?.is_active) return idleState('disabled', message('DISABLED'));
  if (maintenance.has(Number(device.cabinet_id)) || device.fault_code || !doorList.some(doors.isUsable)) {
    return idleState('maintenance', message('MAINTENANCE'));
  }
  if (!access.isOpenAt(cabinet, now)) {
    const hours = access.hoursOf(cabinet);
    return idleState('closed_hours', message('CLOSED_HOURS', { open: hours.open_time, close: hours.close_time }));
  }
  return idleState('idle', message('IDLE_SCAN'), await challenges.issue(device, now));
};

// ---------- 事件 ----------

const reject = (id, code) => ({ id, status: 'rejected', code });

const isPlainObject = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);

const parseEvent = async (device, raw, now) => {
  if (!isPlainObject(raw) || typeof raw.id !== 'string' || !EVENT_ID_RE.test(raw.id)) return { error: 'EVENT_INVALID' };
  const { id, type } = raw;
  if (!EVENT_TYPES.includes(type)) return { id, error: 'EVENT_INVALID' };

  const data = raw.data === undefined || raw.data === null ? {} : raw.data;
  if (!isPlainObject(data)) return { id, error: 'EVENT_INVALID' };

  let channel = null;
  if (raw.channel !== undefined && raw.channel !== null) {
    if (!Number.isInteger(raw.channel) || raw.channel < 1 || raw.channel > Number(device.door_count)) return { id, error: 'EVENT_INVALID' };
    channel = raw.channel;
  }
  if (CHANNEL_EVENTS.includes(type) && channel === null) return { id, error: 'EVENT_INVALID' };

  const age = raw.age_ms;
  if (age !== undefined && age !== null && (typeof age !== 'number' || !Number.isFinite(age))) return { id, error: 'EVENT_INVALID' };
  const ageKnown = typeof age === 'number';
  const occurredAt = ageKnown ? new Date(now.getTime() - Math.min(Math.max(age, 0), MAX_AGE_MS)) : now;

  let session = null;
  if (raw.session_id !== undefined && raw.session_id !== null) {
    const sessionId = publicId.decode('cabinet_session', raw.session_id);
    session = sessionId === null ? null : await prisma.cabinet_sessions.findUnique({
      where: { session_id: sessionId }, select: { session_id: true, device_id: true, status: true }
    });
    if (!session || Number(session.device_id) !== Number(device.device_id)) return { id, error: 'SESSION_MISMATCH' };
  }
  // 有門磁的書櫃在沒有作業時門被關上（例如遭強制開啟後），以不帶 session_id 的 door_closed 回報門磁狀態。
  const sensorOnly = type === 'door_closed' && !session && Boolean(device.has_door_sensor);
  if (SESSION_EVENTS.includes(type) && !session && !sensorOnly) return { id, error: 'EVENT_INVALID' };

  if (['fault', 'fault_cleared'].includes(type) && (typeof data.code !== 'string' || !FAULT_CODE_RE.test(data.code))) {
    return { id, error: 'EVENT_INVALID' };
  }

  const detail = { ...data, ...(ageKnown ? {} : { age_unknown: true }) };
  if (type === 'boot' && data.door_count !== undefined && Number(data.door_count) !== Number(device.door_count)) {
    detail.door_count_mismatch = true;
  }
  const detailText = JSON.stringify(detail);
  if (detailText.length > MAX_DETAIL_LENGTH) return { id, error: 'EVENT_INVALID' };

  return {
    event: {
      id,
      type,
      channel,
      data,
      session_id: session ? Number(session.session_id) : null,
      session_no: session ? publicId.encode('cabinet_session', session.session_id) : null,
      age_ms: ageKnown ? age : null,
      occurred_at: occurredAt,
      detailText
    }
  };
};

const doorOf = (cabinetId, channel) =>
  prisma.cabinet_slots.findFirst({ where: { cabinet_id: Number(cabinetId), lock_channel: channel } });

const SENSOR_BY_EVENT = { door_opened: 'open', door_forced: 'open', door_closed: 'closed' };

// 門磁狀態以 data.sensor 為準；未附時由事件推導（有門磁的裝置只在門磁顯示開啟或關上時送出開門與關門事件）。
const sensorStateOf = (event) => {
  if (SENSOR_STATES.includes(event.data.sensor)) return event.data.sensor;
  if (event.data.code === 'DOOR_LEFT_OPEN') {
    if (event.type === 'fault') return 'open';
    if (event.type === 'fault_cleared') return 'closed';
  }
  return SENSOR_BY_EVENT[event.type] ?? null;
};

const applySensor = async (device, event) => {
  if (!device.has_door_sensor || event.channel === null) return;
  const state = sensorStateOf(event);
  if (!state) return;
  // 離線期間累積的事件可能晚於較新的狀態才送達，只接受不早於目前紀錄的事件。
  await prisma.cabinet_slots.updateMany({
    where: {
      cabinet_id: device.cabinet_id, lock_channel: event.channel,
      OR: [{ sensor_at: null }, { sensor_at: { lte: event.occurred_at } }]
    },
    data: { sensor_state: state, sensor_at: event.occurred_at }
  });
};

const applyBoot = async (device, event) => {
  const { data } = event;
  const update = {};
  if (typeof data.firmware === 'string' && FIRMWARE_RE.test(data.firmware)) update.firmware = data.firmware;
  if (typeof data.has_door_sensor === 'boolean') update.has_door_sensor = data.has_door_sensor;
  if (Number.isInteger(data.unlock_pulse_ms) && data.unlock_pulse_ms >= 100 && data.unlock_pulse_ms <= 10000) {
    update.unlock_pulse_ms = data.unlock_pulse_ms;
  }
  if (Object.keys(update).length > 0) {
    await prisma.cabinet_devices.updateMany({ where: { device_id: device.device_id }, data: { ...update, updated_at: event.occurred_at } });
    Object.assign(device, update);
  }
  return { status: 'ok' };
};

const forwardToSession = async (device, event, now) => {
  if (!handler?.handleEvent) return { status: 'rejected', code: 'SESSION_UNAVAILABLE' };
  const outcome = await handler.handleEvent(device, event, now);
  if (!outcome || !['ok', 'rejected', 'retry'].includes(outcome.status)) return { status: 'ok' };
  return outcome;
};

const applyFault = async (device, event, now) => {
  const { code } = event.data;
  const cabinetName = await cabinetNameOf(prisma, device.cabinet_id);

  if (event.channel !== null) {
    const slot = await doorOf(device.cabinet_id, event.channel);
    if (slot && slot.fault_code !== code) {
      await prisma.cabinet_slots.updateMany({ where: { slot_id: slot.slot_id }, data: { fault_code: code, updated_at: now } });
      await doors.recountAvailable(prisma, device.cabinet_id);
      await notifyAdmins(prisma, device.cabinet_id, {
        title: '書櫃櫃門故障',
        content: `「${cabinetName}」櫃門 ${doors.doorLabel(event.channel)} 回報故障：${faultLabel(code)}。`
      });
    }
    if (event.session_id && handler?.handleEvent) {
      const pending = await prisma.cabinet_session_doors.count({
        where: { session_id: event.session_id, lock_channel: event.channel, state: 'pending' }
      });
      if (pending > 0) return forwardToSession(device, event, now);
    }
    return { status: 'ok' };
  }

  if (device.fault_code !== code) {
    await prisma.cabinet_devices.updateMany({ where: { device_id: device.device_id }, data: { fault_code: code, updated_at: now } });
    await prisma.cabinet_devices.updateMany({ where: { device_id: device.device_id, fault_since: null }, data: { fault_since: now } });
    await notifyAdmins(prisma, device.cabinet_id, {
      title: '書櫃裝置故障',
      content: `「${cabinetName}」的書櫃裝置回報故障：${faultLabel(code)}。`
    });
  }
  return { status: 'ok' };
};

const applyFaultCleared = async (device, event, now) => {
  const { code } = event.data;
  if (event.channel !== null) {
    const slot = await doorOf(device.cabinet_id, event.channel);
    if (slot && slot.fault_code === code) {
      await prisma.cabinet_slots.updateMany({ where: { slot_id: slot.slot_id, fault_code: code }, data: { fault_code: null, updated_at: now } });
      await doors.recountAvailable(prisma, device.cabinet_id);
    }
    return { status: 'ok' };
  }
  await prisma.cabinet_devices.updateMany({
    where: { device_id: device.device_id, fault_code: code },
    data: { fault_code: null, fault_since: null, updated_at: now }
  });
  return { status: 'ok' };
};

const applyDoorForced = async (device, event) => {
  const cabinetName = await cabinetNameOf(prisma, device.cabinet_id);
  await notifyAdmins(prisma, device.cabinet_id, {
    title: '書櫃櫃門異常開啟',
    content: `「${cabinetName}」櫃門 ${doors.doorLabel(event.channel)} 在未收到開門指令時被開啟。`
  });
  return { status: 'ok' };
};

const processEvent = async (device, event, now) => {
  await applySensor(device, event);
  switch (event.type) {
    case 'boot': return applyBoot(device, event);
    case 'fault': return applyFault(device, event, now);
    case 'fault_cleared': return applyFaultCleared(device, event, now);
    case 'door_forced': return applyDoorForced(device, event);
    case 'connection_restored': return { status: 'ok' };
    case 'door_closed': return event.session_id ? forwardToSession(device, event, now) : { status: 'ok' };
    default: return forwardToSession(device, event, now);
  }
};

const claimRow = async (device, event, now) => {
  try {
    const row = await recordEvent(prisma, {
      cabinetId: device.cabinet_id, deviceId: device.device_id, sessionId: event.session_id, type: event.type,
      channel: event.channel, detail: event.detailText, source: 'device', occurredAt: event.occurred_at,
      eventKey: event.id, receivedAt: now, claimedAt: now
    });
    return { row };
  } catch (err) {
    if (err?.code !== 'P2002') throw err;
  }

  const existing = await prisma.cabinet_events.findFirst({ where: { device_id: device.device_id, event_key: event.id } });
  if (!existing) return { outcome: { status: 'retry' } };
  if (existing.type !== event.type || (existing.session_id ?? null) !== event.session_id
    || (existing.lock_channel ?? null) !== event.channel) {
    return { outcome: { status: 'rejected', code: 'EVENT_ID_REUSED' } };
  }
  if (existing.processed_at) return { outcome: { status: 'duplicate', result: existing.result ?? null } };
  if (existing.claimed_at && now.getTime() - new Date(existing.claimed_at).getTime() < EVENT_CLAIM_MS) {
    return { outcome: { status: 'retry' } };
  }
  const reclaimed = await prisma.cabinet_events.updateMany({
    where: { event_id: existing.event_id, claimed_at: existing.claimed_at ?? null },
    data: { claimed_at: now }
  });
  return reclaimed.count > 0 ? { row: existing } : { outcome: { status: 'retry' } };
};

const handleEvents = async (device, events, now = new Date()) => {
  const results = [];
  const retrying = new Set();

  for (const raw of events) {
    const rawSession = isPlainObject(raw) && typeof raw.session_id === 'string' ? raw.session_id.toUpperCase() : null;
    const rawId = isPlainObject(raw) && typeof raw.id === 'string' ? raw.id : null;
    if (rawSession && retrying.has(rawSession)) {
      results.push({ id: rawId, status: 'retry' });
      continue;
    }

    const parsed = await parseEvent(device, raw, now);
    if (parsed.error) {
      results.push(reject(parsed.id ?? rawId, parsed.error));
      continue;
    }
    const { event } = parsed;

    const claim = await claimRow(device, event, now);
    if (claim.outcome) {
      if (claim.outcome.status === 'retry' && rawSession) retrying.add(rawSession);
      results.push({ id: event.id, ...claim.outcome });
      continue;
    }

    let outcome;
    try {
      outcome = await processEvent(device, { ...event, event_id: claim.row.event_id }, now);
    } catch (err) {
      await prisma.cabinet_events.updateMany({ where: { event_id: claim.row.event_id }, data: { claimed_at: null } }).catch(() => {});
      throw err;
    }

    if (outcome.status === 'retry') {
      await prisma.cabinet_events.updateMany({ where: { event_id: claim.row.event_id }, data: { claimed_at: null } });
      if (rawSession) retrying.add(rawSession);
      results.push({ id: event.id, status: 'retry' });
      continue;
    }
    await prisma.cabinet_events.updateMany({
      where: { event_id: claim.row.event_id },
      data: { processed_at: new Date(), result: outcome.status === 'ok' ? 'ok' : outcome.code ?? 'rejected' }
    });
    results.push(outcome.status === 'ok' ? { id: event.id, status: 'ok' } : { id: event.id, status: 'rejected', code: outcome.code });
  }
  return results;
};

// ---------- 排程 ----------

// 關閉模擬器必須撤銷模擬書櫃的憑證，而非只是暫停：憑證可能已隨同源的外部腳本外洩，日後為測試重新開啟時不得恢復效力。
const revokeDisabledSimulators = async (now) => {
  if (access.isSimulatorEnabled()) return 0;
  const rows = await prisma.cabinet_devices.findMany({
    where: { kind: 'simulator', status: 'active' },
    include: { smart_cabinets: { select: { cabinet_name: true } } }
  });
  let revoked = 0;
  for (const device of rows) {
    const done = await prisma.$transaction(async (tx) => {
      if (!(await revoke(tx, device, { reason: 'simulator_off', now }))) return false;
      await notifyAdmins(tx, device.cabinet_id, {
        title: '模擬書櫃裝置已撤銷',
        content: `「${device.smart_cabinets?.cabinet_name ?? ''}」的模擬書櫃裝置已因模擬書櫃功能關閉而撤銷；如需再次使用，請於開啟後重新配對。`
      });
      return true;
    });
    if (done) revoked += 1;
  }
  return revoked;
};

const sweep = async (now = new Date()) => {
  const revoked = await revokeDisabledSimulators(now);
  const lostBefore = new Date(now.getTime() - CONNECTION_LOST_MS);
  const alertBefore = new Date(now.getTime() - OFFLINE_ALERT_MS);
  const devices = await prisma.cabinet_devices.findMany({
    where: { status: 'active', last_seen_at: { lt: lostBefore } },
    include: { smart_cabinets: { select: { cabinet_name: true } } }
  });
  let lost = 0;
  let alerted = 0;

  for (const device of devices) {
    if (!access.isUsableDevice(device)) continue;
    if (!device.offline_since) {
      const marked = await prisma.cabinet_devices.updateMany({
        where: { device_id: device.device_id, offline_since: null },
        data: { offline_since: device.last_seen_at }
      });
      if (marked.count > 0) {
        lost += 1;
        await recordEvent(prisma, {
          cabinetId: device.cabinet_id, deviceId: device.device_id, type: 'connection_lost', source: 'server',
          detail: { last_seen_at: device.last_seen_at }, occurredAt: now
        });
      }
    }
    if (new Date(device.last_seen_at) < alertBefore && !device.offline_notified) {
      const flagged = await prisma.cabinet_devices.updateMany({
        where: { device_id: device.device_id, offline_notified: false },
        data: { offline_notified: true }
      });
      if (flagged.count > 0) {
        alerted += 1;
        await notifyAdmins(prisma, device.cabinet_id, {
          title: '書櫃裝置離線',
          content: `「${device.smart_cabinets?.cabinet_name ?? ''}」的書櫃裝置已離線超過 5 分鐘。`
        });
      }
    }
  }
  return { lost, alerted, revoked };
};

const purge = async (now = new Date(), { daily = false } = {}) => {
  const { count: challengesRemoved } = await challenges.purge(now);
  if (!daily) return { challenges: challengesRemoved, events: 0, pending: 0 };
  const [{ count: events }, { count: pending }] = await Promise.all([
    prisma.cabinet_events.deleteMany({ where: { occurred_at: { lt: new Date(now.getTime() - EVENT_RETENTION_MS) } } }),
    prisma.cabinet_devices.deleteMany({
      where: { status: 'pending', pairing_expires_at: { lt: new Date(now.getTime() - PENDING_RETENTION_MS) } }
    })
  ]);
  return { challenges: challengesRemoved, events, pending };
};

module.exports = {
  TOUCH_THROTTLE_MS, CONNECTION_LOST_MS, OFFLINE_ALERT_MS, PAIRING_TTL_MS, BOOT_GRACE_MS, EVENT_CLAIM_MS,
  UNLOCK_SERVE_MS, ROUNDTRIP_MAX_MS, LOCK_GAP_MS, ACK_GRACE_MS, IDLE_POLL_MS, SESSION_POLL_MS, MAX_EVENTS,
  KINDS, KIND_LABELS, EVENT_TYPES, FAULT_LABELS,
  sha256, newToken, deviceNo, isValidBootId, openingAckMs, faultLabel, unlockCommands, markCommandsServed,
  authRequired, revokedError, disabledError, pairingInvalid, payloadInvalid, staleBoot, cabinetBusy,
  registerSessionHandler, sessionHandler, runSessionSweep,
  activeDeviceOf, lockForSession, releaseSession, revoke,
  normalizePairingCode, createPairingCode, pair, unpair,
  findByToken, verifyBoot, touch, stateFor, handleEvents, sweep, purge,
  recordEvent, notifyAdmins
};
