process.env.CABINET_SIMULATOR = 'true';

const crypto = require('crypto');
const commerce = require('../commerce/harness');
const server = require('../lib/server');
const { install, registerModels, RELATIONS } = require('../commerce/fake-prisma');
const { UNIQUE_KEYS } = require('../lib/fake-prisma');

const { prisma, api, request } = commerce;
const { env } = api('config/env');
const publicId = api('lib/public-id');
const devices = api('services/cabinet-devices');
const doors = api('services/cabinet-doors');

const rel = (table, from, to = from) => ({ table, from, to, type: 'one' });
const many = (table, from, to = from) => ({ table, from, to, type: 'many' });

Object.assign(RELATIONS, {
  cabinet_devices: {
    smart_cabinets: rel('smart_cabinets', 'cabinet_id'),
    cabinet_challenges: many('cabinet_challenges', 'device_id'),
    cabinet_sessions: many('cabinet_sessions', 'device_id')
  },
  cabinet_challenges: { cabinet_devices: rel('cabinet_devices', 'device_id') },
  cabinet_pair_requests: { smart_cabinets: rel('smart_cabinets', 'cabinet_id') },
  cabinet_sessions: {
    smart_cabinets: rel('smart_cabinets', 'cabinet_id'),
    cabinet_devices: rel('cabinet_devices', 'device_id'),
    users: rel('users', 'user_id'),
    cabinet_session_items: many('cabinet_session_items', 'session_id'),
    cabinet_session_doors: many('cabinet_session_doors', 'session_id'),
    cabinet_slot_items: many('cabinet_slot_items', 'session_id')
  },
  cabinet_session_items: {
    cabinet_sessions: rel('cabinet_sessions', 'session_id'),
    orders: rel('orders', 'order_id'),
    books: rel('books', 'book_id'),
    cabinet_slots: rel('cabinet_slots', 'slot_id')
  },
  cabinet_session_doors: {
    cabinet_sessions: rel('cabinet_sessions', 'session_id'),
    cabinet_slots: rel('cabinet_slots', 'slot_id')
  },
  cabinet_slot_items: {
    books: rel('books', 'book_id'),
    cabinet_slots: rel('cabinet_slots', 'slot_id'),
    cabinet_sessions: rel('cabinet_sessions', 'session_id')
  },
  cabinet_manual_reports: {
    smart_cabinets: rel('smart_cabinets', 'cabinet_id'),
    users: rel('users', 'user_id'),
    orders: rel('orders', 'order_id'),
    books: rel('books', 'book_id')
  },
  cabinet_slots: {
    ...(RELATIONS.cabinet_slots ?? {}),
    smart_cabinets: rel('smart_cabinets', 'cabinet_id'),
    orders: many('orders', 'slot_id'),
    cabinet_slot_items: many('cabinet_slot_items', 'slot_id'),
    cabinet_session_items: many('cabinet_session_items', 'slot_id'),
    cabinet_session_doors: many('cabinet_session_doors', 'slot_id')
  }
});
Object.assign(RELATIONS.smart_cabinets, {
  cabinet_devices: many('cabinet_devices', 'cabinet_id'),
  cabinet_pair_requests: many('cabinet_pair_requests', 'cabinet_id'),
  cabinet_sessions: many('cabinet_sessions', 'cabinet_id'),
  cabinet_manual_reports: many('cabinet_manual_reports', 'cabinet_id')
});
Object.assign(RELATIONS.books, {
  order_items: many('order_items', 'book_id'),
  cabinet_slot_items: rel('cabinet_slot_items', 'book_id'),
  cabinet_session_items: many('cabinet_session_items', 'book_id'),
  cabinet_manual_reports: many('cabinet_manual_reports', 'book_id')
});
Object.assign(RELATIONS.orders, {
  cabinet_session_items: many('cabinet_session_items', 'order_id'),
  cabinet_manual_reports: many('cabinet_manual_reports', 'order_id')
});
Object.assign(RELATIONS.users, {
  cabinet_sessions: many('cabinet_sessions', 'user_id'),
  cabinet_manual_reports: many('cabinet_manual_reports', 'user_id')
});

registerModels({
  autoKeys: {
    cabinet_devices: 'device_id',
    cabinet_challenges: 'challenge_id',
    cabinet_pair_requests: 'request_id',
    cabinet_sessions: 'session_id',
    cabinet_session_items: 'item_id',
    cabinet_session_doors: 'slot_id',
    cabinet_slot_items: 'book_id',
    cabinet_events: 'event_id',
    cabinet_manual_reports: 'report_id'
  },
  uniqueKeys: {
    cabinet_slots: [['slot_id'], ['cabinet_id', 'slot_number']],
    cabinet_devices: [['device_id']],
    cabinet_challenges: [['challenge_id'], ['token_hash'], ['device_id', 'qr_seq', 'epoch']],
    cabinet_pair_requests: [['request_id'], ['code_hash'], ['poll_token_hash']],
    cabinet_sessions: [['session_id']],
    cabinet_session_items: [['item_id']],
    cabinet_session_doors: [['session_id', 'slot_id']],
    cabinet_slot_items: [['book_id']],
    cabinet_events: [['event_id']],
    cabinet_manual_reports: [['report_id']]
  },
  defaults: {
    smart_cabinets: {
      total_slots: 20, available_slots: 20, is_active: true, is_maintenance: 0, open_time: null, close_time: null, screen_brightness: 100
    },
    cabinet_slots: {
      status: 'empty', current_book_id: null, current_order_id: null, lock_channel: null, fault_code: null,
      check_required_at: null, check_session_id: null, check_reason: null, sensor_state: null, sensor_at: null
    },
    cabinet_devices: {
      active_cabinet_id: null, active_session_id: null, kind: 'esp32', status: 'pending', token_hash: null,
      door_count: 4, has_door_sensor: false, unlock_pulse_ms: 800,
      firmware: null, fault_code: null, fault_since: null, qr_seq: 0, current_boot_id: null, previous_boot_id: null,
      boot_switched_at: null, last_seen_at: null, last_ip: null, offline_since: null, offline_notified: false,
      created_by: null, paired_at: null, revoked_at: null, revoked_by: null, revoke_reason: null
    },
    cabinet_challenges: { used_at: null, used_by: null },
    cabinet_pair_requests: {
      has_door_sensor: false, ip: null, cabinet_id: null, device_id: null, claimed_by: null, claimed_at: null, delivered_at: null
    },
    cabinet_sessions: {
      kind: 'user', status: 'selecting', version: 1, challenge_id: null, result_code: null, context_type: null,
      context_id: null, location_status: null, distance_m: null, accuracy_m: null, match_code: null,
      open_ms: null, phase_deadline: null, admin_reason: null, admin_force: false, close_outcome: null, close_reason: null,
      close_request: null, close_requested_at: null, close_refused_at: null, started_at: null, matched_at: null, opened_at: null,
      closed_at: null, finished_at: null, reviewed_by: null, reviewed_at: null, review_note: null
    },
    cabinet_session_items: {
      order_id: null, slot_id: null, selected: false, held_on_sale: false, blocked_code: null, note_code: null,
      result: 'pending', error_code: null
    },
    cabinet_session_doors: { state: 'pending', command_served_at: null, opened_at: null, closed_at: null, close_reason: null },
    cabinet_slot_items: { session_id: null, placed_by: 'session' },
    cabinet_events: {
      device_id: null, session_id: null, order_id: null, book_id: null, event_key: null, lock_channel: null,
      actor_id: null, detail: null, result: null, claimed_at: null, processed_at: null
    },
    cabinet_manual_reports: {
      order_id: null, book_id: null, target_status: null, reason: null, status: 'pending', pending_key: null,
      held_on_sale: false, reviewed_by: null, reviewed_at: null, review_note: null
    }
  }
});

// MySQL 的唯一索引允許多個 NULL；共用的假 Prisma 會把 NULL 視為相同，這些欄位改由下方包裝檢查。
const NULLABLE_UNIQUE = {
  cabinet_devices: [['active_cabinet_id'], ['active_session_id'], ['token_hash']],
  cabinet_sessions: [['challenge_id']],
  cabinet_events: [['device_id', 'event_key']],
  cabinet_slots: [['cabinet_id', 'lock_channel']],
  cabinet_manual_reports: [['pending_key']]
};
const COMPOUND = { cabinet_session_doors: { session_id_slot_id: ['session_id', 'slot_id'] } };

for (const table of Object.keys(NULLABLE_UNIQUE)) {
  for (const keys of NULLABLE_UNIQUE[table]) {
    if ((UNIQUE_KEYS[table] ?? []).some((k) => k.join() === keys.join())) throw new Error(`${table} 的唯一鍵重複登記`);
  }
}

const store = install(prisma);
const baseModel = prisma.model;

const conflictError = () => Object.assign(new Error('Unique constraint failed'), { code: 'P2002' });
const isObject = (v) => v !== null && typeof v === 'object' && !(v instanceof Date) && !Array.isArray(v);

const flatten = (table, where) => {
  if (!where || !COMPOUND[table]) return where;
  const out = { ...where };
  for (const key of Object.keys(COMPOUND[table])) {
    if (isObject(out[key])) {
      Object.assign(out, out[key]);
      delete out[key];
    }
  }
  return out;
};

const scalars = (data = {}) => Object.fromEntries(Object.entries(data).filter(([, v]) => v !== undefined && !isObject(v)));

const assertNullableUnique = (table, candidate, ignore = null) => {
  for (const keys of NULLABLE_UNIQUE[table] ?? []) {
    if (!keys.every((k) => candidate[k] !== null && candidate[k] !== undefined)) continue;
    if (prisma.rows(table).some((other) => other !== ignore && keys.every((k) => other[k] === candidate[k]))) throw conflictError();
  }
};

const checkUpdate = (table, where, data) => {
  for (const row of store.query(table, { where: where ?? {} })) assertNullableUnique(table, { ...row, ...scalars(data) }, row);
};

prisma.model = (table) => {
  const m = baseModel(table);
  if (!NULLABLE_UNIQUE[table] && !COMPOUND[table]) return m;
  const withWhere = (args) => (args?.where ? { ...args, where: flatten(table, args.where) } : args);
  return {
    ...m,
    findUnique: (args) => m.findUnique(withWhere(args)),
    findFirst: (args) => m.findFirst(withWhere(args)),
    findMany: (args) => m.findMany(withWhere(args)),
    count: (args) => m.count(withWhere(args)),
    delete: (args) => m.delete(withWhere(args)),
    deleteMany: (args) => m.deleteMany(withWhere(args)),
    create: async (args) => {
      assertNullableUnique(table, scalars(args.data));
      return m.create(args);
    },
    createMany: async (args) => {
      for (const data of [args.data].flat()) assertNullableUnique(table, scalars(data));
      return m.createMany(args);
    },
    update: async (args) => {
      const next = withWhere(args);
      checkUpdate(table, next.where, args.data);
      return m.update(next);
    },
    updateMany: async (args) => {
      const next = withWhere(args);
      checkUpdate(table, next.where, args.data);
      return m.updateMany(next);
    },
    upsert: async (args) => {
      const next = withWhere(args);
      const exists = store.query(table, { where: next.where }).length > 0;
      if (exists) checkUpdate(table, next.where, args.update);
      else assertNullableUnique(table, scalars({ ...next.where, ...args.create }));
      return m.upsert(next);
    }
  };
};

const CABINET_TABLES = [
  'cabinet_devices', 'cabinet_challenges', 'cabinet_pair_requests', 'cabinet_sessions', 'cabinet_session_items',
  'cabinet_session_doors', 'cabinet_slot_items', 'cabinet_events', 'cabinet_manual_reports'
];

// 工作包 B 的作業處理器在載入路由時註冊；測試換成替身後，每個測試前都還原。
const baselineHandler = devices.sessionHandler();
const restores = [];

const reset = () => {
  commerce.reset();
  for (const table of CABINET_TABLES) prisma.store[table] = [];
  env.cabinetSimulator = true;
  devices.registerSessionHandler(baselineHandler);
  while (restores.length) restores.pop()();
  eventSeq = 0;
};

server.setDefaultReset(reset);

let eventSeq = 0;

const addCabinet = ({ openTime = null, closeTime = null, ...options } = {}) => {
  const row = commerce.addCabinet(options);
  Object.assign(row, { open_time: openTime, close_time: closeTime, total_slots: 20, available_slots: 20 });
  return row;
};

const cabinetRow = (cabinetId) => prisma.rows('smart_cabinets').find((c) => Number(c.cabinet_id) === Number(cabinetId));

const recount = (cabinetId) => {
  const channelDoors = prisma.rows('cabinet_slots').filter((s) => Number(s.cabinet_id) === Number(cabinetId) && s.lock_channel != null);
  const cabinet = cabinetRow(cabinetId);
  if (cabinet && channelDoors.length) cabinet.available_slots = channelDoors.filter(doors.isFree).length;
};

const syncDoors = (cabinetId, doorCount) => {
  const slots = prisma.rows('cabinet_slots');
  for (const slot of slots) if (Number(slot.cabinet_id) === Number(cabinetId)) slot.lock_channel = null;
  for (let channel = 1; channel <= doorCount; channel += 1) {
    const label = doors.doorLabel(channel);
    let slot = slots.find((s) => Number(s.cabinet_id) === Number(cabinetId) && s.slot_number === label);
    if (!slot) {
      slot = {
        slot_id: prisma.nextId('cabinet_slots'), cabinet_id: cabinetId, slot_number: label, status: 'empty',
        current_book_id: null, current_order_id: null, fault_code: null, check_required_at: null, check_session_id: null,
        check_reason: null, sensor_state: null, sensor_at: null, updated_at: new Date()
      };
      slots.push(slot);
    }
    slot.lock_channel = channel;
  }
  const cabinet = cabinetRow(cabinetId);
  if (cabinet) cabinet.total_slots = doorCount;
  recount(cabinetId);
};

const bootIdOf = () => crypto.randomBytes(6).toString('hex').slice(0, 8).replace(/[^a-z0-9]/g, 'a');

const addDevice = ({
  cabinetId, kind = 'esp32', doorCount = 4, lastSeenAt = new Date(), status = 'active', unlockPulseMs = 800,
  hasDoorSensor = false, pairedAt = new Date()
}) => {
  const token = devices.newToken();
  const bootId = bootIdOf();
  const device = {
    device_id: prisma.nextId('cabinet_devices'),
    cabinet_id: cabinetId,
    active_cabinet_id: status === 'active' ? cabinetId : null,
    active_session_id: null,
    kind,
    status,
    token_hash: devices.sha256(token),
    door_count: doorCount,
    has_door_sensor: hasDoorSensor,
    unlock_pulse_ms: unlockPulseMs,
    firmware: 'test-1.0.0',
    fault_code: null,
    fault_since: null,
    qr_seq: 0,
    current_boot_id: bootId,
    previous_boot_id: null,
    boot_switched_at: null,
    last_seen_at: lastSeenAt,
    last_ip: null,
    offline_since: null,
    offline_notified: false,
    created_by: null,
    paired_at: pairedAt,
    revoked_at: status === 'revoked' ? new Date() : null,
    revoked_by: null,
    revoke_reason: status === 'revoked' ? 'admin' : null,
    created_at: new Date(),
    updated_at: new Date()
  };
  prisma.rows('cabinet_devices').push(device);
  syncDoors(cabinetId, doorCount);
  return { device, token, bootId };
};

const PAIR_BODY = { kind: 'esp32', door_count: 4, has_door_sensor: false, unlock_pulse_ms: 800, firmware: 'esp-1.0.0' };

const requestPairing = (body = {}, { boot = 'k3v9aa01' } = {}) => request('POST', '/api/device/v1/pair/request', {
  headers: boot ? { 'x-device-boot': boot } : {}, body: { ...PAIR_BODY, ...body }
});

const pollPairing = (pollToken) => request('POST', '/api/device/v1/pair/poll', { body: { poll_token: pollToken } });

const claimPairing = (adminToken, cabinetId, code, { verified = true } = {}) =>
  request('POST', `/api/admin/cabinets/${cabinetId}/device/pair`, {
    token: adminToken, body: { code }, headers: verified ? commerce.verifyHeaders(adminToken, 'admin') : {}
  });

const pairRequestOf = (code) =>
  prisma.rows('cabinet_pair_requests').find((r) => r.code_hash === devices.sha256(String(code).replace(/[-\s]/g, ''))) ?? null;

const deviceHeaders = (token, bootId) => ({ authorization: `Device ${token}`, 'x-device-boot': bootId });

const deviceState = (token, bootId) => request('GET', '/api/device/v1/state', { headers: deviceHeaders(token, bootId) });

const nextEventId = (bootId) => {
  eventSeq += 1;
  return `${bootId}-${String(eventSeq).padStart(6, '0')}`;
};

const postEvents = (token, bootId, events) => request('POST', '/api/device/v1/events', {
  headers: deviceHeaders(token, bootId),
  body: { events: events.map((e) => ({ id: nextEventId(bootId), age_ms: 0, ...e })) }
});

const scanCode = async (token, bootId) => {
  const res = await deviceState(token, bootId);
  return res.body?.data?.qr?.payload ?? null;
};

const doorOf = (cabinetId, channel) =>
  prisma.rows('cabinet_slots').find((s) => Number(s.cabinet_id) === Number(cabinetId) && s.lock_channel === channel);

const addPlaced = (bookId, slotId) => {
  const slot = prisma.rows('cabinet_slots').find((s) => Number(s.slot_id) === Number(slotId));
  const row = {
    book_id: bookId, slot_id: slotId, cabinet_id: slot.cabinet_id, session_id: null, placed_by: 'admin', placed_at: new Date()
  };
  prisma.rows('cabinet_slot_items').push(row);
  if (slot.status !== 'maintenance') slot.status = 'occupied';
  recount(slot.cabinet_id);
  return row;
};

const sessionOf = (sessionNo) => {
  const id = publicId.decode('cabinet_session', sessionNo);
  return prisma.rows('cabinet_sessions').find((s) => Number(s.session_id) === Number(id)) ?? null;
};

const expireSession = (sessionNo) => {
  const row = sessionOf(sessionNo);
  if (row) row.phase_deadline = new Date(Date.now() - 1000);
  return row;
};

// fnPath 為「模組路徑#函式名稱」，例如 'services/orders#markDepositedInTx'；被測程式須以模組物件呼叫該函式才攔得到。
const failNext = (fnPath, error = new Error('測試注入的錯誤')) => {
  const [modulePath, fnName] = fnPath.split('#');
  const mod = api(modulePath);
  const original = mod[fnName];
  if (typeof original !== 'function') throw new Error(`找不到函式：${fnPath}`);
  const restore = () => { mod[fnName] = original; };
  mod[fnName] = async () => {
    restore();
    throw error;
  };
  restores.push(restore);
  return restore;
};

const setSessionHandler = (handler) => devices.registerSessionHandler(handler);

const adminVerifyHeaders = (token) => commerce.verifyHeaders(token, 'admin');

const eventsOf = (type) => prisma.rows('cabinet_events').filter((e) => !type || e.type === type);

const deviceRow = (deviceId) => prisma.rows('cabinet_devices').find((d) => Number(d.device_id) === Number(deviceId));

module.exports = {
  ...commerce,
  env, publicId, devices, doors, reset, clientIp: server.clientIp,
  addCabinet, cabinetRow, addDevice, syncDoors, deviceHeaders, deviceState, postEvents, scanCode, addPlaced, doorOf,
  requestPairing, pollPairing, claimPairing, pairRequestOf,
  sessionOf, expireSession, failNext, setSessionHandler, adminVerifyHeaders, eventsOf, deviceRow, nextEventId
};
