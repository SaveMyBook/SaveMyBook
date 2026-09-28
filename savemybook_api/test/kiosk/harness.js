// 模擬書櫃的測試設定：device-core 以假時鐘與假 fetch 驅動，不經過伺服器；路由測試沿用 test/lib 的 Express 應用。
process.env.CABINET_SIMULATOR = 'true';

const server = require('../lib/server');

const { DeviceCore, STORAGE_KEYS } = server.api('views/kiosk/device-core');

const TOKEN = 'smbd_kioskTestToken0000000000000000000000000000';
const PAIR_CODE = '12345678';
const QR_PAYLOAD = `savemybook://k/${'3f9c0a1b'.repeat(4)}`;

// ---------- 假時鐘 ----------

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

// ---------- 本機儲存 ----------

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

// ---------- 伺服器畫面 ----------

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
  session: { phase: screen, action: 'pickup', remaining_ms: 60000, open_ms: 30000, choices: null, doors: [], result: null, ...session },
  ...extra
});

const CHOICES = [37, 12, 85, 41, 66, 90, 23, 58, 74];

const selectState = (id = 'CSKIOSK01', extra = {}) =>
  sessionState('select', { id, remaining_ms: 60000 }, { message: { code: 'SELECT_ON_PHONE', params: {} }, ...extra });

const matchState = (id = 'CSKIOSK01', extra = {}) =>
  sessionState('match', { id, remaining_ms: 60000, choices: CHOICES }, { message: { code: 'MATCH_PROMPT', params: {} }, ...extra });

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

const resultState = ({ id = 'CSKIOSK01', code = 'RESULT_DONE', outcome = 'completed' } = {}) =>
  sessionState('result', { id, remaining_ms: 4000, result: { outcome, code } }, { message: { code, params: {} } });

// ---------- 假裝置 API ----------

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
    this.fetch = this.fetch.bind(this);
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

    if (req.path === '/api/device/v1/pair') {
      const code = String(body?.code ?? '').replace(/[-\s]/g, '');
      if (code !== PAIR_CODE) return json(400, { success: false, code: 'PAIRING_CODE_INVALID', message: '配對碼無效或已逾時' });
      return json(201, {
        success: true,
        data: {
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
  const { core, api, clock } = device;
  api.state = matchState(id);
  await clock.advance(2000);
  api.onEvents = (events) => {
    if (events.some((e) => e.type === 'match_selected')) api.state = openingState({ id, channels, action, openMs });
  };
  if (!core.tap('match:37')) throw new Error('比對按鈕無法點選');
  await clock.advance(0);
  api.onEvents = null;
  await clock.advance(channels.length * 1100);
  api.state = sessionState('open', { id, action, remaining_ms: openMs, open_ms: openMs }, { message: { code: 'OPEN_PICKUP', params: {} } });
};

module.exports = {
  ...server,
  DeviceCore, STORAGE_KEYS, TOKEN, PAIR_CODE, QR_PAYLOAD, CHOICES,
  FakeClock, FakeDeviceApi, memoryStorage, seededRandom, settle, json,
  idleState, sessionState, selectState, matchState, openingState, resultState,
  makeDevice, openDoors
};
