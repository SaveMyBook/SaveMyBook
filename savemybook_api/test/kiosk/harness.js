process.env.CABINET_SIMULATOR = 'true';

const server = require('../lib/server');

const { DeviceCore, STORAGE_KEYS } = server.api('views/kiosk/device-core');

const TOKEN = 'smbd_kioskTestToken0000000000000000000000000000';
const PAIR_CODE = '1234-5678';
const POLL_TOKEN = 'kioskPollToken000000000000000000000000000';
const PAIR_TTL_MS = 10 * 60 * 1000;
const PAIR_CLAIM_GRACE_MS = 30000;
const MATCH_CODE = 37;
const QR_PAYLOAD = `savemybook://k/${'3f9c0a1b'.repeat(4)}`;

// fetch 與 res.text() 會經過數次 microtask，以 setImmediate 讓它們全部跑完再推進時間。
const settle = async () => {
  for (let i = 0; i < 12; i++) await new Promise((resolve) => setImmediate(resolve));
};

class FakeClock {
  constructor(start = 1000) {
    this.t = start;
    this.seq = 0;
    this.timers = new Map();
  }

  now() {
    return this.t;
  }

  setTimeout(fn, ms) {
    this.seq += 1;
    this.timers.set(this.seq, { id: this.seq, at: this.t + Math.max(0, Number(ms) || 0), fn });
    return this.seq;
  }

  clearTimeout(id) {
    this.timers.delete(id);
  }

  async advance(ms = 0) {
    const target = this.t + ms;
    for (;;) {
      await settle();
      let next = null;
      for (const timer of this.timers.values()) {
        if (timer.at <= target && (!next || timer.at < next.at || (timer.at === next.at && timer.id < next.id))) next = timer;
      }
      if (!next) break;
      this.timers.delete(next.id);
      this.t = Math.max(this.t, next.at);
      next.fn();
    }
    this.t = target;
    await settle();
  }
}

const memoryStorage = (initial = {}) => {
  const map = new Map(Object.entries(initial));
  return {
    map,
    get: (key) => (map.has(key) ? map.get(key) : null),
    set: (key, value) => map.set(key, String(value)),
    remove: (key) => map.delete(key),
    json: (key) => (map.has(key) ? JSON.parse(map.get(key)) : null)
  };
};

const doorList = () => [1, 2, 3, 4].map((channel) => ({ channel, label: `A0${channel}`, enabled: true }));

const idleState = (extra = {}) => ({
  device_no: 'DVKIOSK01',
  cabinet_name: '測試書櫃',
  screen: 'idle',
  message: { code: 'IDLE_SCAN', params: {} },
  poll_ms: 2000,
  qr: { payload: QR_PAYLOAD, refresh_in_ms: 20000, expires_in_ms: 35000 },
  session: null,
  commands: [],
  doors: doorList(),
  ...extra
});

const sessionState = (screen, session, extra = {}) => idleState({
  screen,
  poll_ms: 1000,
  qr: null,
  session: { phase: screen, action: 'pickup', remaining_ms: 60000, open_ms: 30000, doors: [], result: null, ...session },
  ...extra
});

const selectState = (id = 'CSKIOSK01', extra = {}) =>
  sessionState('select', { id, remaining_ms: 60000 }, { message: { code: 'SELECT_ON_PHONE', params: {} }, ...extra });

const matchState = (id = 'CSKIOSK01', code = MATCH_CODE) =>
  sessionState('match', { id, remaining_ms: 60000, code }, { message: { code: 'MATCH_PROMPT', params: {} } });

const openingState = ({ id = 'CSKIOSK01', channels = [2], action = 'pickup', openMs = 30000, expiresInMs = 6000, releaseMs = 800 } = {}) => {
  const labels = channels.map((ch) => `A0${ch}`).join('、');
  return sessionState('opening', {
    id,
    action,
    remaining_ms: 20000,
    open_ms: openMs,
    doors: channels.map((ch) => ({ channel: ch, label: `A0${ch}`, state: 'pending' }))
  }, {
    message: { code: 'OPENING', params: { doors: labels } },
    commands: channels.map((ch) => ({ id: `${id}:${ch}:1`, type: 'unlock', channel: ch, release_ms: releaseMs, expires_in_ms: expiresInMs }))
  });
};

const openState = ({ id = 'CSKIOSK01', action = 'pickup', openMs = 30000, commands = [] } = {}) => {
  const screen = action === 'admin' ? 'admin' : 'open';
  return sessionState(screen, { id, action, remaining_ms: openMs, open_ms: openMs }, {
    message: { code: action === 'admin' ? 'OPEN_ADMIN' : 'OPEN_PICKUP', params: {} },
    commands
  });
};

const closeCommand = (outcome = 'completed', { id = 'CSKIOSK01', at = 1760000000000 } = {}) =>
  ({ type: 'close', id: `${id}:close:${at}`, outcome });

const resultState = ({ id = 'CSKIOSK01', code = 'RESULT_DONE', outcome = 'completed' } = {}) =>
  sessionState('result', { id, remaining_ms: 4000, result: { outcome, code } }, { message: { code, params: {} } });

class FakeDeviceApi {
  constructor(clock) {
    this.clock = clock;
    this.requests = [];
    this.state = idleState();
    this.revoked = false;
    this.failures = 0;
    this.overrides = [];
    this.resultFor = () => ({ status: 'ok' });
    this.onEvents = null;
    this.pairTtlMs = PAIR_TTL_MS;
    this.pairIssued = 0;
    this.pairing = null;
    this.fetch = this.fetch.bind(this);
  }

  bindPairing() {
    this.pairing.bound = true;
    this.pairing.expiresAt = Math.max(this.pairing.expiresAt, this.clock.now() + PAIR_CLAIM_GRACE_MS);
  }

  expirePairing() {
    this.pairing.expired = true;
  }

  pairPaths() {
    return this.requests.filter((r) => r.path.startsWith('/api/device/v1/pair/')).map((r) => r.path.slice('/api/device/v1/'.length));
  }

  respondOnce(match, respond) {
    this.overrides.push({ match, respond });
  }

  events() {
    return this.requests.filter((r) => r.path === '/api/device/v1/events').flatMap((r) => r.body.events);
  }

  eventsOf(type) {
    return this.events().filter((e) => e.type === type);
  }

  async fetch(url, init = {}) {
    const { pathname } = new URL(url);
    const body = init.body ? JSON.parse(init.body) : null;
    const req = { at: this.clock.now(), method: init.method || 'GET', path: pathname, headers: { ...init.headers }, body };
    if (this.failures > 0) {
      this.failures -= 1;
      req.failed = true;
      this.requests.push(req);
      throw new TypeError('fetch failed');
    }
    this.requests.push(req);

    const idx = this.overrides.findIndex((o) => o.match(req));
    if (idx >= 0) {
      const [override] = this.overrides.splice(idx, 1);
      return override.respond(req);
    }

    if (req.path === '/api/device/v1/pair/request' && req.method === 'POST') {
      this.pairIssued += 1;
      const digits = String(12345677 + this.pairIssued);
      this.pairing = {
        code: `${digits.slice(0, 4)}-${digits.slice(4)}`,
        pollToken: `${POLL_TOKEN}${this.pairIssued}`,
        expiresAt: req.at + this.pairTtlMs,
        bound: false,
        delivered: false,
        expired: false
      };
      return json(201, { success: true, data: { code: this.pairing.code, poll_token: this.pairing.pollToken, expires_in_ms: this.pairTtlMs, poll_ms: 3000 } });
    }
    if (req.path === '/api/device/v1/pair/poll' && req.method === 'POST') {
      const pairing = this.pairing;
      const left = pairing ? pairing.expiresAt - req.at : 0;
      if (!pairing || body?.poll_token !== pairing.pollToken || pairing.delivered || pairing.expired || left <= 0) {
        return json(410, { success: false, code: 'PAIRING_EXPIRED', message: '配對碼已逾時，請重新取得' });
      }
      if (!pairing.bound) return json(200, { success: true, data: { status: 'pending', expires_in_ms: left, poll_ms: 3000 } });
      pairing.delivered = true;
      return json(200, {
        success: true,
        data: {
          status: 'paired',
          token: TOKEN,
          device_no: 'DVKIOSK01',
          cabinet: { cabinet_name: '測試書櫃' },
          doors: doorList().map(({ channel, label }) => ({ channel, label })),
          poll_ms: 2000
        }
      });
    }

    if (this.revoked || req.headers.authorization !== `Device ${TOKEN}`) {
      return json(401, { success: false, code: 'DEVICE_REVOKED', message: '裝置憑證已失效，請重新配對' });
    }

    if (req.path === '/api/device/v1/state' && req.method === 'GET') {
      return json(200, { success: true, data: this.state });
    }
    if (req.path === '/api/device/v1/events' && req.method === 'POST') {
      const results = body.events.map((event) => ({ id: event.id, ...this.resultFor(event) }));
      if (this.onEvents) this.onEvents(body.events.filter((e, i) => results[i].status !== 'retry'), req);
      return json(200, { success: true, data: { results, state: this.state } });
    }
    if (req.path === '/api/device/v1/unpair' && req.method === 'POST') {
      return json(200, { success: true });
    }
    return json(404, { success: false, code: 'ROUTE_NOT_FOUND', message: '找不到此端點' });
  }
}

const json = (status, body, headers = {}) => new Response(JSON.stringify(body), {
  status,
  headers: { 'content-type': 'application/json', ...headers }
});

const seededRandom = (seed = 7) => {
  let s = seed;
  return () => {
    s = (s * 1103515245 + 12345) % 2147483648;
    return s / 2147483648;
  };
};

const makeDevice = ({ paired = true, storage = memoryStorage(), clock = new FakeClock(), options = {} } = {}) => {
  if (paired && !storage.get(STORAGE_KEYS.token)) storage.set(STORAGE_KEYS.token, TOKEN);
  const api = new FakeDeviceApi(clock);
  const views = [];
  const logs = [];
  const core = new DeviceCore({
    baseUrl: 'http://device.test',
    fetch: api.fetch,
    storage,
    clock,
    random: seededRandom(options.seed),
    onView: (view) => views.push({ at: clock.now(), view }),
    onLog: (entry) => logs.push(entry),
    ...options
  });
  return { core, api, storage, clock, views, logs };
};

const openDoors = async (device, { channels = [2], action = 'pickup', openMs = 30000, id = 'CSKIOSK01' } = {}) => {
  const { api, clock } = device;
  api.state = openingState({ id, channels, action, openMs });
  await clock.advance(2000);
  await clock.advance(channels.length * 1100);
  api.state = openState({ id, action, openMs });
};

module.exports = {
  ...server,
  DeviceCore, STORAGE_KEYS, TOKEN, PAIR_CODE, POLL_TOKEN, PAIR_TTL_MS, QR_PAYLOAD, MATCH_CODE,
  FakeClock, FakeDeviceApi, memoryStorage, seededRandom, settle, json,
  idleState, sessionState, selectState, matchState, openingState, openState, closeCommand, resultState,
  makeDevice, openDoors
};
