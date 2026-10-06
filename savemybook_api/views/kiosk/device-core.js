(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.SmbDeviceCore = factory();
  }
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  const API = '/api/device/v1';

  const TIMING = Object.freeze({ ROUNDTRIP_MAX_MS: 3000, LOCK_GAP_MS: 300 });

  const DEFAULT_POLL_MS = 2000;
  const OFFLINE_AFTER_FAILURES = 3;
  const BACKOFF_MS = [2000, 4000, 8000, 15000];
  const MAINTENANCE_RETRY_MS = 5000;
  const DISABLED_RETRY_MS = 15000;
  const RATE_LIMIT_RETRY_MS = 5000;
  const PAIRING_POLL_MS = 3000;
  const PAIRING_RETRY_MS = 60000;
  const MAX_BATCH = 20;
  const RESULT_WAIT_MS = 4000;
  const SENSOR_OPEN_WAIT_MS = 3000;
  const QR_REFRESH_MS = 30000;
  const TICK_MS = 250;
  const DEFAULT_OPEN_MS = 30000;

  const STORAGE_KEYS = Object.freeze({
    token: 'smb.device.token',
    no: 'smb.device.no',
    cabinet: 'smb.device.cabinet',
    queue: 'smb.device.queue',
    seq: 'smb.device.seq',
    openSession: 'smb.device.openSession',
    brightness: 'smb.device.brightness'
  });

  // 與韌體相同：螢幕亮度 10–100%，來自 GET /state 的 settings，保存後下次開機先沿用。
  const brightnessOf = (value) => {
    const n = Number(value);
    return Number.isInteger(n) && n >= 10 && n <= 100 ? n : null;
  };

  const MESSAGES = Object.freeze({
    IDLE_SCAN: '請使用 SaveMyBook App 掃描',
    CLOSED_HOURS: '目前非營業時間｜營業時間 {open}–{close}',
    MAINTENANCE: '書櫃維修中，暫停服務',
    DISABLED: '書櫃暫停服務',
    SELECT_ON_PHONE: '書櫃使用中｜請於手機確認項目',
    MATCH_PROMPT: '請於手機輸入下列數字',
    OPENING: '櫃門開啟中',
    OPEN_PICKUP: '請取出 {doors} 內的書籍後關上櫃門',
    OPEN_DEPOSIT: '請將書籍放入 {doors} 後關上櫃門',
    OPEN_RETRIEVE: '請取回 {doors} 內的書籍後關上櫃門',
    OPEN_MIXED: '請依手機指示操作 {doors} 後關上櫃門',
    OPEN_ADMIN: '管理人員作業中',
    RESULT_DONE: '作業完成',
    RESULT_PARTIAL: '部分項目未完成，請查看手機',
    RESULT_CANCELLED: '本次作業已取消',
    RESULT_MATCH_FAILED: '數字不符，本次作業已取消',
    RESULT_TIMEOUT: '操作逾時，本次作業已取消',
    RESULT_DEVICE_ERROR: '櫃門未能開啟，請聯絡客服',
    RESULT_REVIEW: '本次作業待客服確認',
    TITLE: '智慧書櫃',
    PAIRING_TITLE: '配對碼',
    PAIRING_PROMPT: '請於管理後台輸入此配對碼',
    PAIRING_REMAINING: '剩餘時間 {time}',
    PAIRING_REQUESTING: '取得配對碼中',
    PAIRING_RETRY: '暫時無法取得配對碼，稍後自動重試',
    OFFLINE: '連線中斷，重新連線中',
    SYSTEM_MAINTENANCE: '系統維護中，請稍後再試',
    DEVICE_DISABLED: '模擬書櫃目前未開放',
    BOOTING: '啟動中',
    PROCESSING: '處理中',
    CLOSE_DOOR_FIRST: '請先關上櫃門',
    REMAINING_SECONDS: '剩餘 {seconds} 秒'
  });

  const rect = (x, y, w, h) => Object.freeze([x, y, w, h]);

  // 2.8 吋橫向螢幕，座標與字級同韌體 src/ui.cpp、tools/make_fonts.py；文字的 y 為視覺中線。
  const LAYOUT = Object.freeze({
    WIDTH: 320,
    HEIGHT: 240,
    HEADER_HEIGHT: 28,
    TEXT_WIDTH: 280,
    FONTS: Object.freeze({ SMALL: 13, BODY: 15, TITLE: 16, CODE: 38, LABEL: 44, LABEL_SM: 28, RING: 34, HUGE: 96 }),
    PAIRING: Object.freeze({ TITLE_Y: 60, CODE_Y: 100, PROMPT_Y: 146, REMAINING_Y: 172, BAR: rect(40, 192, 240, 4), STATUS_TITLE_Y: 92, STATUS_Y: 140 }),
    IDLE: Object.freeze({ QR_X: 16, QR_Y: 40, SCALE: 4, MIN_SCALE: 3, QUIET_ZONE: 4, BAR_GAP: 8, TEXT_GAP: 12, MARGIN: 8, LINE_HEIGHT: 24 }),
    NOTICE: Object.freeze({ ICON_X: 160, ICON_Y: 88, ICON_R: 24, TITLE_Y: 146, TEXT_Y: 182 }),
    SELECT: Object.freeze({ TITLE_Y: 84, TEXT_Y: 118, REMAINING_Y: 154, BAR: rect(40, 174, 240, 4) }),
    MATCH: Object.freeze({ TITLE_Y: 56, CODE_Y: 126, REMAINING_Y: 194, BAR: rect(40, 214, 240, 4) }),
    OPEN: Object.freeze({
      LABEL_X: 18, LABEL_WIDTH: 176, LABEL_Y: 66, LABEL_SM_Y: 54, LABEL_ROW_H: 34, LABEL_GAP: 12, LABEL_SM_GAP: 10,
      MESSAGE_X: 18, MESSAGE_Y: 132, MESSAGE_WIDTH: 184,
      RING: Object.freeze({ X: 255, Y: 131, R: 44, WIDTH: 5 })
    })
  });

  const OPEN_CODES = { pickup: 'OPEN_PICKUP', deposit: 'OPEN_DEPOSIT', retrieve: 'OPEN_RETRIEVE', mixed: 'OPEN_MIXED', admin: 'OPEN_ADMIN' };
  const SCREEN_ICONS = { closed_hours: 'clock', maintenance: 'wrench', disabled: 'pause' };

  const noop = () => {};
  const doorLabel = (channel) => 'A' + String(channel).padStart(2, '0');

  const format = (code, params) => {
    const text = MESSAGES[code];
    if (text === undefined) return '';
    return text.replace(/\{(\w+)\}/g, (m, key) => (params && params[key] != null ? String(params[key]) : ''));
  };

  const linesOf = (code, params) => format(code, params).split('｜');

  const clockText = (ms) => {
    const seconds = Math.ceil(Math.max(0, ms) / 1000);
    return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;
  };

  const parseJson = (text, fallback) => {
    if (typeof text !== 'string' || !text) return fallback;
    try {
      return JSON.parse(text);
    } catch (err) {
      return fallback;
    }
  };

  class DeviceCore {
    constructor(options) {
      const o = options || {};
      this.baseUrl = String(o.baseUrl || '').replace(/\/+$/, '');
      this.fetchFn = o.fetch;
      this.storage = o.storage;
      this.clock = o.clock;
      this.kind = o.kind || 'simulator';
      this.firmware = o.firmware || 'sim-1.0.0';
      this.doorCount = o.doorCount || 4;
      this.unlockPulseMs = o.unlockPulseMs || 800;
      this.options = { hasDoorSensor: !!o.hasDoorSensor, autoCloseOnTimeout: o.autoCloseOnTimeout !== false };
      this.random = o.random || Math.random;
      this.onView = o.onView || noop;
      this.onLog = o.onLog || noop;

      this.running = false;
      this.gen = 0;
      this.reqSeq = 0;
      this.bootId = null;
      this.offlineSim = false;
      this.latency = 0;
      this.timers = { poll: null, pair: null, tick: null, countdown: null };
      this.hw = new Map();
      for (let ch = 1; ch <= this.doorCount; ch++) {
        this.hw.set(ch, { locked: true, open: false, unlocking: false, fault: null, leftOpen: false, awaitingOpen: null });
      }
      this.lastViewJson = '';
      this.lockChain = Promise.resolve();
      this.lastPowerOff = -Infinity;
      this.resetRuntime();
      this.loadIdentity();
      this.view = this.buildView();
    }

    // ---------- 生命週期 ----------

    start(resetReason) {
      if (this.running) return;
      this.running = true;
      this.gen += 1;
      this.bootId = this.makeBootId();
      this.resetRuntime();
      this.loadIdentity();
      for (const hw of this.hw.values()) {
        hw.unlocking = false;
        hw.awaitingOpen = null;
        if (!this.options.hasDoorSensor) hw.open = false;
        hw.locked = !hw.open;
      }

      if (this.token) {
        this.queue = this.queue.filter((e) => e.type !== 'boot');
        const record = parseJson(this.store('get', STORAGE_KEYS.openSession), null);
        this.executed = new Set(record && Array.isArray(record.command_ids) ? record.command_ids : []);
        this.enqueue('boot', { data: this.bootData(resetReason || 'power_on') }, { front: true });
        if (record && record.session_id
          && !this.queue.some((e) => e.type === 'session_closed' && e.session_id === record.session_id)) {
          this.enqueue('session_closed', { session_id: record.session_id, data: { outcome: 'interrupted', reason: 'reboot' } });
        }
        this.store('remove', STORAGE_KEYS.openSession);
        this.bootPending = true;
        this.schedule(0);
      } else {
        this.startPairing();
      }
      this.render();
    }

    stop() {
      this.running = false;
      this.gen += 1;
      for (const key of Object.keys(this.timers)) this.clearTimer(key);
      this.inflight = false;
      this.local = null;
      for (const hw of this.hw.values()) {
        hw.unlocking = false;
        if (hw.awaitingOpen) hw.awaitingOpen(false);
        hw.awaitingOpen = null;
      }
    }

    reboot() {
      this.stop();
      this.start('software');
    }

    resetRuntime() {
      this.inflight = false;
      this.flushRequested = false;
      this.failures = 0;
      this.reachable = false;
      this.systemMaintenance = false;
      this.deviceDisabled = false;
      this.server = null;
      this.phaseTotal = { key: null, total: 0 };
      this.postClose = null;
      this.local = null;
      this.pairing = null;
      this.bootPending = false;
      this.executed = new Set();
    }

    loadIdentity() {
      this.token = this.store('get', STORAGE_KEYS.token) || null;
      this.deviceNo = this.store('get', STORAGE_KEYS.no) || null;
      this.cabinetName = this.store('get', STORAGE_KEYS.cabinet) || null;
      const queue = parseJson(this.store('get', STORAGE_KEYS.queue), []);
      this.queue = Array.isArray(queue) ? queue.filter((e) => e && typeof e.id === 'string' && typeof e.type === 'string') : [];
      const seq = parseInt(this.store('get', STORAGE_KEYS.seq), 10);
      this.seq = Number.isFinite(seq) && seq > 0 ? seq : 0;
      this.brightness = brightnessOf(this.store('get', STORAGE_KEYS.brightness)) ?? 100;
    }

    clearIdentity() {
      for (const key of Object.values(STORAGE_KEYS)) this.store('remove', key);
      this.clearTimer('poll');
      this.clearTimer('pair');
      this.clearTimer('countdown');
      this.gen += 1;
      this.token = null;
      this.deviceNo = null;
      this.cabinetName = null;
      this.queue = [];
      this.seq = 0;
      this.resetRuntime();
      this.startPairing();
    }

    store(op, key, value) {
      if (!this.storage) return null;
      try {
        if (op === 'get') return this.storage.get(key);
        if (op === 'set') return this.storage.set(key, value);
        return this.storage.remove(key);
      } catch (err) {
        return null;
      }
    }

    makeBootId() {
      const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
      let id = '';
      for (let i = 0; i < 8; i++) id += chars[Math.min(35, Math.floor(this.random() * 36))];
      return id;
    }

    bootData(resetReason) {
      return {
        firmware: this.firmware,
        door_count: this.doorCount,
        has_door_sensor: this.options.hasDoorSensor,
        unlock_pulse_ms: this.unlockPulseMs,
        reset_reason: resetReason,
        boot_id: this.bootId
      };
    }

    // ---------- 計時 ----------

    now() {
      return this.clock.now();
    }

    setTimer(key, fn, ms) {
      this.clearTimer(key);
      this.timers[key] = this.clock.setTimeout(() => {
        this.timers[key] = null;
        fn();
      }, Math.max(0, ms));
    }

    clearTimer(key) {
      if (this.timers[key] != null) this.clock.clearTimeout(this.timers[key]);
      this.timers[key] = null;
    }

    sleep(ms) {
      return new Promise((resolve) => this.clock.setTimeout(resolve, Math.max(0, ms)));
    }

    // ---------- 事件佇列 ----------

    enqueue(type, fields, { front = false } = {}) {
      if (!this.token || !this.bootId) return null;
      this.seq += 1;
      this.store('set', STORAGE_KEYS.seq, String(this.seq));
      const event = Object.assign({ id: `${this.bootId}-${String(this.seq).padStart(6, '0')}`, type, boot: this.bootId, at: this.now() }, fields);
      if (front) this.queue.unshift(event);
      else this.queue.push(event);
      this.persistQueue();
      return event;
    }

    persistQueue() {
      this.store('set', STORAGE_KEYS.queue, JSON.stringify(this.queue));
    }

    wireEvent(event) {
      const wire = {
        id: event.id,
        type: event.type,
        age_ms: event.boot === this.bootId ? Math.max(0, Math.round(this.now() - event.at)) : null
      };
      if (event.session_id != null) wire.session_id = event.session_id;
      if (event.channel != null) wire.channel = event.channel;
      if (event.data != null) wire.data = event.data;
      return wire;
    }

    flush() {
      if (!this.running || !this.token) return;
      if (this.inflight) {
        this.flushRequested = true;
        return;
      }
      this.schedule(0);
    }

    // ---------- 通訊 ----------

    schedule(ms) {
      if (!this.running || !this.token || ms == null) return;
      this.setTimer('poll', () => this.cycle(), ms);
    }

    async cycle() {
      if (!this.running || !this.token) return;
      if (this.inflight) {
        this.flushRequested = true;
        return;
      }
      const gen = this.gen;
      this.inflight = true;
      this.flushRequested = false;
      let next;
      try {
        next = this.queue.length || this.bootPending ? await this.sendEvents() : await this.pollState();
      } catch (err) {
        next = DEFAULT_POLL_MS;
      } finally {
        if (gen === this.gen) this.inflight = false;
      }
      if (gen !== this.gen || !this.running) return;
      if (next === undefined) return;
      if (this.flushRequested && next !== null && (this.failures === 0)) next = 0;
      this.schedule(next);
    }

    async request(method, path, body, { auth = true, summary = '' } = {}) {
      const gen = this.gen;
      const reqId = ++this.reqSeq;
      const started = this.now();
      if (summary) this.log('out', method, path, null, summary);
      let status = 0;
      let json = null;
      let networkError = false;
      let retryAfter = null;
      try {
        if (this.offlineSim) throw new Error('offline');
        const headers = { accept: 'application/json', 'x-device-boot': this.bootId };
        if (body !== undefined) headers['content-type'] = 'application/json';
        if (auth) headers.authorization = `Device ${this.token}`;
        const res = await this.fetchFn(this.baseUrl + API + path, {
          method,
          headers,
          body: body === undefined ? undefined : JSON.stringify(body)
        });
        status = res.status;
        retryAfter = res.headers && typeof res.headers.get === 'function' ? res.headers.get('retry-after') : null;
        json = parseJson(await res.text(), null);
      } catch (err) {
        networkError = true;
      }
      if (this.latency > 0) await this.sleep(this.latency);
      if (gen !== this.gen) return null;
      return { reqId, status, body: json, networkError, retryAfter, rtt: this.now() - started, method, path };
    }

    classify(res) {
      if (res.networkError) return 'network';
      const code = res.body && res.body.code;
      if (res.status >= 200 && res.status < 300) return 'ok';
      if (res.status === 401) return 'revoked';
      if (res.status === 403 && code === 'DEVICE_DISABLED') return 'disabled';
      if (res.status === 409 && code === 'DEVICE_STALE_BOOT') return 'stale';
      if (res.status === 503 && code === 'MAINTENANCE') return 'maintenance';
      if (res.status === 429) return 'rate';
      if (res.status >= 500) return 'network';
      return 'client';
    }

    // 回傳下一次請求的延遲；null 表示停止輪詢，undefined 表示已由其他流程接手。
    settle(res, kind) {
      if (kind === 'network') {
        this.failures += 1;
        this.render();
        return BACKOFF_MS[Math.min(this.failures, BACKOFF_MS.length) - 1];
      }
      this.failures = 0;
      this.reachable = true;
      this.systemMaintenance = kind === 'maintenance';
      this.deviceDisabled = kind === 'disabled';
      if (kind === 'revoked') {
        this.clearIdentity();
        this.render();
        return null;
      }
      if (kind === 'maintenance') {
        this.render();
        return MAINTENANCE_RETRY_MS;
      }
      if (kind === 'disabled') {
        this.render();
        return DISABLED_RETRY_MS;
      }
      if (kind === 'rate') {
        const seconds = parseInt(res.retryAfter, 10);
        return Number.isFinite(seconds) && seconds > 0 ? seconds * 1000 : RATE_LIMIT_RETRY_MS;
      }
      return this.pollMs();
    }

    pollMs() {
      const ms = this.server && this.server.state && Number(this.server.state.poll_ms);
      return ms > 0 ? ms : DEFAULT_POLL_MS;
    }

    async pollState() {
      const res = await this.request('GET', '/state', undefined);
      if (!res) return undefined;
      const kind = this.classify(res);
      if (kind === 'ok' && res.body && res.body.data) {
        this.log('in', 'GET', '/state', res.status, `state ${this.stateSummary(res.body.data)}`);
        this.settle(res, kind);
        this.applyState(res.body.data, res);
        return this.pollMs();
      }
      this.log('in', 'GET', '/state', res.status, this.failureSummary(res, kind));
      return this.settle(res, kind);
    }

    async sendEvents() {
      const batch = this.queue.slice(0, MAX_BATCH);
      const res = await this.request('POST', '/events', { events: batch.map((e) => this.wireEvent(e)) }, {
        summary: `events ${batch.map((e) => this.eventSummary(e)).join('、')}`
      });
      if (!res) return undefined;
      const kind = this.classify(res);
      if (kind !== 'ok' || !res.body || !res.body.data) {
        this.log('in', 'POST', '/events', res.status, this.failureSummary(res, kind));
        if (kind === 'client' && res.status === 400) {
          const dropped = new Set(batch.map((e) => e.id));
          this.queue = this.queue.filter((e) => !dropped.has(e.id));
          this.persistQueue();
          if (batch.some((e) => e.type === 'boot')) this.bootPending = false;
        }
        return this.settle(res, kind);
      }

      const results = Array.isArray(res.body.data.results) ? res.body.data.results : [];
      const byId = new Map(results.map((r) => [r && r.id, r]));
      const settled = new Set();
      let retried = false;
      for (const event of batch) {
        const result = byId.get(event.id);
        if (!result) continue;
        const code = result.code ? `（${result.code}）` : '';
        this.log('in', 'POST', '/events', res.status, `event ${this.eventSummary(event)} → ${result.status}${code}`);
        if (result.status === 'retry') {
          retried = true;
          continue;
        }
        settled.add(event.id);
        if (event.type === 'boot') this.bootPending = false;
      }
      this.queue = this.queue.filter((e) => !settled.has(e.id));
      this.persistQueue();

      this.settle(res, kind);
      if (res.body.data.state) this.applyState(res.body.data.state, res);
      return !retried && settled.size && this.queue.length ? 0 : this.pollMs();
    }

    eventSummary(event) {
      const parts = [event.type];
      if (event.channel != null) parts.push(doorLabel(event.channel));
      if ((event.type === 'fault' || event.type === 'fault_cleared' || event.type === 'close_refused') && event.data) parts.push(event.data.code);
      if (event.type === 'session_closed' && event.data) parts.push(`${event.data.outcome}/${event.data.reason}`);
      if (event.type === 'door_closed' && event.data) parts.push(event.data.reason);
      return parts.join(' ');
    }

    stateSummary(state) {
      const session = state.session;
      const phase = session && session.phase && session.phase !== state.screen ? `/${session.phase}` : '';
      const commands = Array.isArray(state.commands) && state.commands.length
        ? ` commands ${state.commands.map((c) => (c.type === 'close' ? `close ${c.outcome}` : doorLabel(c.channel))).join('、')}`
        : '';
      return `${state.screen}${phase}${commands}`;
    }

    failureSummary(res, kind) {
      if (kind === 'network') return this.offlineSim ? '模擬離線' : '連線失敗';
      return (res.body && res.body.code) || `HTTP ${res.status}`;
    }

    log(dir, method, path, status, summary) {
      try {
        this.onLog({ at: Date.now(), dir, method, path: API + path, status, summary });
      } catch (err) {
        // 紀錄顯示失敗不影響書櫃運作
      }
    }

    // ---------- 狀態套用 ----------

    applyState(state, res) {
      this.server = { state, at: this.now(), rtt: res.rtt };
      if (state.device_no && state.device_no !== this.deviceNo) {
        this.deviceNo = state.device_no;
        this.store('set', STORAGE_KEYS.no, state.device_no);
      }
      if (state.cabinet_name && state.cabinet_name !== this.cabinetName) {
        this.cabinetName = state.cabinet_name;
        this.store('set', STORAGE_KEYS.cabinet, state.cabinet_name);
      }
      const brightness = brightnessOf(state.settings && state.settings.screen_brightness);
      if (brightness !== null && brightness !== this.brightness) {
        this.brightness = brightness;
        this.store('set', STORAGE_KEYS.brightness, String(brightness));
      }
      const session = state.session;
      if (this.postClose && session && session.id === this.postClose.sessionId && session.phase === 'result') {
        this.postClose = null;
      }
      if (session && session.remaining_ms != null && session.phase !== 'open') {
        const key = `${session.id}:${session.phase}`;
        if (this.phaseTotal.key !== key) this.phaseTotal = { key, total: Number(session.remaining_ms) || 0 };
        else this.phaseTotal.total = Math.max(this.phaseTotal.total, Number(session.remaining_ms) || 0);
      }
      if (Array.isArray(state.commands) && state.commands.length) {
        this.handleUnlock(state, res.rtt);
        this.handleClose(state);
      }
      this.render();
    }

    // ---------- 開鎖 ----------

    handleUnlock(state, rtt) {
      const fresh = state.commands.filter((c) => c && c.type === 'unlock' && typeof c.id === 'string' && !this.executed.has(c.id)
        && Number.isInteger(c.channel) && this.hw.has(c.channel));
      if (!fresh.length) return;
      if (rtt > TIMING.ROUNDTRIP_MAX_MS) {
        this.log('in', 'GET', '/state', null, `往返 ${Math.round(rtt)} 毫秒，超過 ${TIMING.ROUNDTRIP_MAX_MS} 毫秒，不執行開鎖指令`);
        return;
      }
      const commands = fresh.filter((c) => Number(c.expires_in_ms) > 0);
      if (!commands.length) return;

      const session = state.session || {};
      const sessionId = session.id || commands[0].id.split(':')[0];
      if (this.local && this.local.sessionId !== sessionId) return;

      const previous = parseJson(this.store('get', STORAGE_KEYS.openSession), null);
      const priorIds = previous && previous.session_id === sessionId && Array.isArray(previous.command_ids) ? previous.command_ids : [];
      for (const c of commands) this.executed.add(c.id);
      const openMs = Number(session.open_ms) > 0 ? Number(session.open_ms) : DEFAULT_OPEN_MS;
      const action = session.action || (this.local && this.local.action) || 'mixed';
      this.store('set', STORAGE_KEYS.openSession, JSON.stringify({
        session_id: sessionId,
        command_ids: priorIds.concat(commands.map((c) => c.id)),
        action,
        open_ms: openMs
      }));

      if (!this.local) {
        this.local = {
          sessionId, action, openMs, openedAt: null, doors: new Map(), unlocking: 0, closing: false, expired: false,
          closeRequest: null, refusedOutcome: null
        };
      }
      for (const c of commands) this.local.doors.set(c.channel, { commandId: c.id, state: 'pending' });
      this.local.unlocking += 1;
      const local = this.local;
      const gen = this.gen;
      this.lockChain = this.lockChain.then(() => this.runBatch(commands, local, gen)).catch(noop);
    }

    // 以 lockChain 串接各批指令，確保任何時刻只有一個電磁鎖通電。
    async runBatch(commands, local, gen) {
      for (const cmd of commands) {
        const gap = this.lastPowerOff + TIMING.LOCK_GAP_MS - this.now();
        if (gap > 0) await this.sleep(gap);
        if (gen !== this.gen) return;
        const hw = this.hw.get(cmd.channel);
        const door = local.doors.get(cmd.channel);
        hw.unlocking = true;
        this.render();
        await this.sleep(Number(cmd.release_ms) > 0 ? Number(cmd.release_ms) : this.unlockPulseMs);
        if (gen !== this.gen) return;
        hw.unlocking = false;
        this.lastPowerOff = this.now();

        let opened = !hw.fault;
        if (opened) {
          hw.locked = false;
          hw.open = true;
        } else if (this.options.hasDoorSensor) {
          opened = await this.waitSensorOpen(hw);
          if (gen !== this.gen) return;
        }

        if (opened) {
          door.state = 'open';
          this.enqueue('door_opened', { session_id: local.sessionId, channel: cmd.channel, data: { command_id: cmd.id } });
          if (local.openedAt === null) this.beginCountdown(local);
        } else {
          door.state = 'failed';
          this.enqueue('fault', { session_id: local.sessionId, channel: cmd.channel, data: { code: 'LOCK_NO_RELEASE' } });
        }
        this.render();
        this.flush();
      }
      if (gen !== this.gen) return;
      local.unlocking -= 1;
      if (local.unlocking > 0 || this.local !== local) return;
      if (local.openedAt === null) {
        this.local = null;
        this.store('remove', STORAGE_KEYS.openSession);
      } else {
        if (local.closeRequest) this.applyClose();
        if (local.expired) this.onCountdownEnd();
      }
      this.render();
    }

    waitSensorOpen(hw) {
      return new Promise((resolve) => {
        let done = false;
        const finish = (value) => {
          if (done) return;
          done = true;
          hw.awaitingOpen = null;
          resolve(value);
        };
        hw.awaitingOpen = finish;
        this.clock.setTimeout(() => finish(hw.open), SENSOR_OPEN_WAIT_MS);
      });
    }

    beginCountdown(local) {
      local.openedAt = this.now();
      this.setTimer('countdown', () => {
        if (this.local === local) {
          local.expired = true;
          this.onCountdownEnd();
        }
      }, local.openMs);
    }

    onCountdownEnd() {
      const local = this.local;
      if (!local || local.closing || local.unlocking > 0) return;
      if (this.options.autoCloseOnTimeout) this.closeSession('completed', 'timeout');
      else this.render();
    }

    closeSession(outcome, reason) {
      const local = this.local;
      if (!local || local.closing) return;
      local.closing = true;
      const sensor = this.options.hasDoorSensor;
      const channels = [...local.doors.keys()].sort((a, b) => a - b);
      for (const channel of channels) {
        const door = local.doors.get(channel);
        if (door.state !== 'open') continue;
        const hw = this.hw.get(channel);
        if (sensor && hw.open) {
          hw.leftOpen = true;
          door.state = 'left_open';
          this.enqueue('fault', { channel, data: { code: 'DOOR_LEFT_OPEN' } });
          continue;
        }
        if (outcome === 'completed') {
          this.enqueue('door_closed', { session_id: local.sessionId, channel, data: { reason } });
        }
        door.state = 'closed';
        hw.open = false;
        hw.locked = true;
      }
      this.enqueue('session_closed', { session_id: local.sessionId, data: { outcome, reason } });
      this.store('remove', STORAGE_KEYS.openSession);
      this.clearTimer('countdown');
      this.local = null;
      this.postClose = { sessionId: local.sessionId, until: this.now() + RESULT_WAIT_MS };
      this.render();
      this.flush();
    }

    // ---------- 手機完成或取消 ----------

    handleClose(state) {
      const local = this.local;
      if (!local || local.closing) return;
      const fresh = state.commands.filter((c) => c && c.type === 'close' && typeof c.id === 'string' && !this.executed.has(c.id)
        && (c.outcome === 'completed' || c.outcome === 'cancelled') && c.id.split(':')[0] === local.sessionId);
      if (!fresh.length) return;
      for (const c of fresh) this.executed.add(c.id);
      const command = fresh[fresh.length - 1];
      local.closeRequest = { id: command.id, outcome: command.outcome };
      this.applyClose();
    }

    // 開鎖尚未全部處理完時先保留請求，由 runBatch 結束時再套用，避免關閉後才開啟後續櫃門。
    applyClose() {
      const local = this.local;
      const request = local && local.closeRequest;
      if (!request || local.closing || local.unlocking > 0) return;
      local.closeRequest = null;
      if (this.sessionDoorOpen(local)) {
        local.refusedOutcome = request.outcome;
        this.enqueue('close_refused', { session_id: local.sessionId, data: { command_id: request.id, code: 'DOOR_OPEN' } });
        this.render();
        this.flush();
        return;
      }
      this.closeSession(request.outcome, request.outcome === 'completed' ? 'user_done' : 'user_cancel');
    }

    sessionDoorOpen(local) {
      if (!this.options.hasDoorSensor) return false;
      return [...local.doors.entries()].some(([channel, door]) => door.state === 'open' && this.hw.get(channel).open);
    }

    // ---------- 配對 ----------

    // 配對請求的 X-Device-Boot 會成為裝置取得憑證後的開機代碼，重新開機後必須重新申請配對碼，不可沿用舊的 poll_token。
    startPairing() {
      if (!this.running || this.token) return;
      this.pairing = { code: null, pollToken: null, expiresAt: 0, totalMs: 0, pollMs: PAIRING_POLL_MS, error: null };
      this.setTimer('pair', () => this.pairCycle(), 0);
    }

    async pairCycle() {
      if (!this.running || this.token || !this.pairing) return;
      const gen = this.gen;
      const pairing = this.pairing;
      // 本機到期後仍以原 poll_token 再輪詢，直到回 410 才重新申請：管理員在最後幾秒綁定時，伺服器會延長效期供裝置領取憑證。
      const next = pairing.pollToken ? await this.pollPairing() : await this.requestPairing();
      if (gen !== this.gen || !this.running || this.token || next == null) return;
      const expiresIn = this.pairing.pollToken ? this.pairing.expiresAt - this.now() : 0;
      this.setTimer('pair', () => this.pairCycle(), expiresIn > 0 ? Math.min(next, expiresIn) : next);
    }

    async requestPairing() {
      this.pairing.pollToken = null;
      const res = await this.request('POST', '/pair/request', {
        kind: this.kind,
        door_count: this.doorCount,
        has_door_sensor: this.options.hasDoorSensor,
        unlock_pulse_ms: this.unlockPulseMs,
        firmware: this.firmware
      }, { auth: false, summary: 'pair/request' });
      if (!res) return undefined;
      const data = res.body && res.body.data;
      const expiresIn = data && Number(data.expires_in_ms);
      if (res.status === 201 && data && typeof data.code === 'string' && typeof data.poll_token === 'string' && expiresIn > 0) {
        this.log('in', 'POST', '/pair/request', res.status, `配對碼有效 ${Math.round(expiresIn / 1000)} 秒`);
        this.pairingReached();
        this.pairing = {
          code: data.code,
          pollToken: data.poll_token,
          expiresAt: this.now() + expiresIn,
          totalMs: expiresIn,
          pollMs: Number(data.poll_ms) > 0 ? Number(data.poll_ms) : PAIRING_POLL_MS,
          error: null
        };
        this.render();
        return this.pairing.pollMs;
      }
      this.pairing.code = null;
      return this.pairingFailed(res, '/pair/request');
    }

    async pollPairing() {
      const res = await this.request('POST', '/pair/poll', { poll_token: this.pairing.pollToken }, { auth: false });
      if (!res) return undefined;
      const data = res.body && res.body.data;
      if (res.status === 200 && data && data.status === 'paired' && typeof data.token === 'string') {
        this.log('in', 'POST', '/pair/poll', res.status, `paired ${data.device_no || ''}`.trim());
        this.store('set', STORAGE_KEYS.token, data.token);
        if (data.device_no) this.store('set', STORAGE_KEYS.no, data.device_no);
        if (data.cabinet && data.cabinet.cabinet_name) this.store('set', STORAGE_KEYS.cabinet, data.cabinet.cabinet_name);
        this.store('remove', STORAGE_KEYS.queue);
        this.store('remove', STORAGE_KEYS.openSession);
        this.clearTimer('pair');
        this.loadIdentity();
        this.resetRuntime();
        this.reachable = true;
        this.schedule(0);
        this.render();
        return null;
      }
      if (res.status === 200 && data && data.status === 'pending') {
        this.log('in', 'POST', '/pair/poll', res.status, 'pending');
        this.pairingReached();
        const expiresIn = Number(data.expires_in_ms);
        if (expiresIn >= 0) this.pairing.expiresAt = this.now() + expiresIn;
        if (Number(data.poll_ms) > 0) this.pairing.pollMs = Number(data.poll_ms);
        this.pairing.error = null;
        this.render();
        return this.pairing.pollMs;
      }
      if (res.status === 410) {
        this.log('in', 'POST', '/pair/poll', res.status, (res.body && res.body.code) || 'HTTP 410');
        this.pairingReached();
        this.pairing.code = null;
        this.pairing.pollToken = null;
        this.render();
        return 0;
      }
      return this.pairingFailed(res, '/pair/poll');
    }

    pairingReached() {
      this.failures = 0;
      this.reachable = true;
    }

    pairingFailed(res, path) {
      const kind = this.classify(res);
      this.log('in', 'POST', path, res.status, this.failureSummary(res, kind));
      let next;
      if (kind === 'network') {
        this.failures += 1;
        if (this.failures >= OFFLINE_AFTER_FAILURES) this.pairing.error = 'OFFLINE';
        next = BACKOFF_MS[Math.min(this.failures, BACKOFF_MS.length) - 1];
      } else {
        this.pairingReached();
        if (kind === 'rate') {
          const seconds = parseInt(res.retryAfter, 10);
          next = Number.isFinite(seconds) && seconds > 0 ? seconds * 1000 : RATE_LIMIT_RETRY_MS;
          if (!this.pairing.code) this.pairing.error = 'PAIRING_RETRY';
        } else if (kind === 'maintenance') {
          this.pairing.error = 'SYSTEM_MAINTENANCE';
          next = MAINTENANCE_RETRY_MS;
        } else {
          this.pairing.error = kind === 'disabled' ? 'DEVICE_DISABLED' : 'PAIRING_RETRY';
          this.pairing.code = null;
          this.pairing.pollToken = null;
          next = PAIRING_RETRY_MS;
        }
      }
      this.render();
      return next;
    }

    // ---------- 模擬控制 ----------

    async unpair() {
      let result = { ok: true, status: 0 };
      if (this.token && this.running) {
        const res = await this.request('POST', '/unpair', {}, { summary: 'unpair' });
        if (res) {
          this.log('in', 'POST', '/unpair', res.status, res.networkError ? '連線失敗' : ((res.body && res.body.code) || 'ok'));
          result = { ok: res.status >= 200 && res.status < 300, status: res.status };
        }
      }
      this.clearIdentity();
      this.render();
      return result;
    }

    setOffline(offline) {
      this.offlineSim = !!offline;
      if (!offline) this.flush();
    }

    setLatency(ms) {
      this.latency = Math.max(0, Number(ms) || 0);
    }

    setOptions(options) {
      const o = options || {};
      if (typeof o.autoCloseOnTimeout === 'boolean') {
        this.options.autoCloseOnTimeout = o.autoCloseOnTimeout;
        if (o.autoCloseOnTimeout && this.local && this.local.expired) this.onCountdownEnd();
      }
      if (typeof o.hasDoorSensor === 'boolean' && o.hasDoorSensor !== this.options.hasDoorSensor) {
        if (this.local) return false;
        this.options.hasDoorSensor = o.hasDoorSensor;
        if (!o.hasDoorSensor) {
          for (const [channel, hw] of this.hw) {
            if (hw.leftOpen) this.enqueue('fault_cleared', { channel, data: { code: 'DOOR_LEFT_OPEN' } });
            hw.leftOpen = false;
            hw.open = false;
            hw.locked = true;
          }
        }
        if (this.running && this.token) this.enqueue('boot', { data: this.bootData('config') });
        this.flush();
        if (this.running && !this.token) {
          this.gen += 1;
          this.clearTimer('pair');
          this.startPairing();
        }
      }
      this.render();
      return true;
    }

    setDoorPhysical(channel, state) {
      const hw = this.hw.get(channel);
      if (!hw || !this.options.hasDoorSensor) return false;
      if (state === 'open') {
        if (hw.open) return false;
        hw.open = true;
        if (hw.awaitingOpen) {
          hw.locked = false;
          hw.awaitingOpen(true);
        } else if (hw.locked && !hw.unlocking) {
          this.enqueue('door_forced', { channel });
        }
      } else if (state === 'closed') {
        if (!hw.open) return false;
        hw.open = false;
        hw.locked = true;
        const local = this.local;
        const door = local && local.doors.get(channel);
        if (hw.leftOpen) {
          hw.leftOpen = false;
          this.enqueue('fault_cleared', { channel, data: { code: 'DOOR_LEFT_OPEN' } });
        } else if (!(door && door.state === 'open')) {
          // 不屬於本機開門中的門（例如遭強制開啟後）關上時，仍須回報門磁狀態，否則伺服器會一直記錄為開啟。
          this.enqueue('door_closed', { channel, data: { reason: 'sensor' } });
        }
        if (door && door.state === 'open') {
          door.state = 'closed';
          this.enqueue('door_closed', { session_id: local.sessionId, channel, data: { reason: 'sensor' } });
          const stillOpen = [...local.doors.values()].some((d) => d.state === 'open' || d.state === 'pending');
          if (!stillOpen && local.unlocking === 0) {
            // 伺服器收到 close_refused 即撤回指令，不會再送一次；門關上時若不依被拒絕的取消結束，取消會變成完成。
            if (local.refusedOutcome === 'cancelled') this.closeSession('cancelled', 'user_cancel');
            else this.closeSession('completed', 'sensor');
            return true;
          }
        }
      } else {
        return false;
      }
      this.render();
      this.flush();
      return true;
    }

    injectFault(channel, code) {
      const hw = this.hw.get(channel);
      if (!hw) return false;
      const faultCode = code || 'LOCK_NO_RELEASE';
      hw.fault = faultCode;
      this.enqueue('fault', { channel, data: { code: faultCode } });
      this.render();
      this.flush();
      return true;
    }

    clearFault(channel, code) {
      const hw = this.hw.get(channel);
      if (!hw || !hw.fault) return false;
      const faultCode = code || hw.fault;
      hw.fault = null;
      this.enqueue('fault_cleared', { channel, data: { code: faultCode } });
      this.render();
      this.flush();
      return true;
    }

    // ---------- 畫面 ----------

    connection() {
      return this.reachable && this.failures < OFFLINE_AFTER_FAILURES ? 'online' : 'offline';
    }

    render() {
      const now = this.clock ? this.now() : 0;
      if (this.postClose && now >= this.postClose.until) this.postClose = null;
      this.view = this.buildView();
      const json = JSON.stringify(this.view);
      if (json !== this.lastViewJson) {
        this.lastViewJson = json;
        try {
          this.onView(this.view);
        } catch (err) {
          // 畫面繪製失敗不影響書櫃運作
        }
      }
      if (this.running && this.timers.tick == null && this.clock) {
        this.setTimer('tick', () => this.render(), TICK_MS);
      }
    }

    buildView() {
      const screen = this.screenView(this.clock ? this.now() : 0);
      const serverDoors = new Map();
      const state = this.server && this.server.state;
      if (state && Array.isArray(state.doors)) for (const d of state.doors) serverDoors.set(d.channel, d);
      return Object.assign({
        screen: 'booting',
        header: MESSAGES.TITLE,
        lines: [],
        qr: null,
        pairing: null,
        code: null,
        countdown: null,
        icon: null,
        notice: null,
        doors: [...this.hw.entries()].map(([channel, hw]) => ({
          channel,
          label: doorLabel(channel),
          locked: hw.locked,
          open: hw.open,
          unlocking: hw.unlocking,
          fault: hw.fault || (hw.leftOpen ? 'DOOR_LEFT_OPEN' : null),
          enabled: serverDoors.has(channel) ? serverDoors.get(channel).enabled !== false : true
        })),
        connection: this.connection(),
        brightness: this.brightness,
        deviceNo: this.deviceNo,
        cabinetName: this.cabinetName
      }, screen);
    }

    screenView(now) {
      if (!this.token) return this.pairingView(now);
      if (!this.running) return { screen: 'booting', lines: [MESSAGES.BOOTING] };
      if (this.local) return this.localView(now);
      if (this.failures >= OFFLINE_AFTER_FAILURES) return { screen: 'offline', lines: [MESSAGES.OFFLINE] };
      if (!this.reachable) return { screen: 'booting', lines: [MESSAGES.BOOTING] };
      if (this.postClose) return { screen: 'processing', lines: [MESSAGES.PROCESSING] };
      if (this.systemMaintenance) return { screen: 'system_maintenance', lines: [MESSAGES.SYSTEM_MAINTENANCE] };
      if (this.deviceDisabled) return { screen: 'device_disabled', lines: [MESSAGES.DEVICE_DISABLED] };
      const state = this.server && this.server.state;
      if (!state) return { screen: 'booting', lines: [MESSAGES.BOOTING] };
      return this.serverView(state, now);
    }

    pairingView(now) {
      const pairing = this.pairing;
      const title = MESSAGES.PAIRING_TITLE;
      if (!pairing) return { screen: 'pairing', lines: [title, MESSAGES.BOOTING], pairing: { code: null, remainingMs: null, totalMs: null, error: null } };
      const remainingMs = pairing.code ? Math.max(0, pairing.expiresAt - now) : null;
      if (pairing.code && !pairing.error && remainingMs > 0) {
        return {
          screen: 'pairing',
          lines: [title, pairing.code, MESSAGES.PAIRING_PROMPT, format('PAIRING_REMAINING', { time: clockText(remainingMs) })],
          pairing: { code: pairing.code, remainingMs, totalMs: Math.max(pairing.totalMs, remainingMs), error: null }
        };
      }
      return {
        screen: 'pairing',
        lines: [title, MESSAGES[pairing.error] || MESSAGES.PAIRING_REQUESTING],
        pairing: { code: null, remainingMs: null, totalMs: null, error: pairing.error }
      };
    }

    serverView(state, now) {
      const message = state.message || {};
      const session = state.session;
      const elapsed = now - this.server.at;
      const remaining = session && session.remaining_ms != null ? Math.max(0, Number(session.remaining_ms) - elapsed) : null;
      const countdown = remaining === null ? null : { remainingMs: remaining, totalMs: Math.max(this.phaseTotal.total, remaining) };
      const remainingLine = countdown ? [format('REMAINING_SECONDS', { seconds: Math.ceil(countdown.remainingMs / 1000) })] : [];

      switch (state.screen) {
        case 'idle': {
          const qr = state.qr;
          const valid = qr && typeof qr.payload === 'string' && elapsed < Number(qr.expires_in_ms);
          return {
            screen: 'idle',
            lines: linesOf(message.code || 'IDLE_SCAN', message.params),
            qr: valid
              ? { payload: qr.payload, refreshRatio: Math.min(1, Math.max(0, (Number(qr.refresh_in_ms) - elapsed) / QR_REFRESH_MS)) }
              : null
          };
        }
        case 'closed_hours':
        case 'maintenance':
        case 'disabled':
          return { screen: state.screen, icon: SCREEN_ICONS[state.screen], lines: linesOf(message.code, message.params) };
        case 'select':
          return {
            screen: 'select',
            lines: linesOf(message.code || 'SELECT_ON_PHONE', message.params).concat(remainingLine),
            countdown
          };
        case 'match': {
          const code = session && session.code != null && /^\d{2}$/.test(String(session.code)) ? String(session.code) : null;
          return {
            screen: 'match',
            lines: [format(message.code || 'MATCH_PROMPT', message.params)].concat(code ? [code] : [], remainingLine),
            code,
            countdown
          };
        }
        case 'opening':
          return { screen: 'opening', lines: [format('OPENING')] };
        case 'result': {
          const done = message.code === 'RESULT_DONE';
          return { screen: 'result', icon: done ? 'check' : 'alert', lines: linesOf(message.code, message.params) };
        }
        default:
          return { screen: 'processing', lines: [MESSAGES.PROCESSING] };
      }
    }

    localView(now) {
      const local = this.local;
      if (local.openedAt === null) return { screen: 'opening', lines: [MESSAGES.OPENING] };
      const labels = [...local.doors.entries()]
        .filter(([, d]) => d.state === 'open' || d.state === 'closed')
        .map(([ch]) => ch)
        .sort((a, b) => a - b)
        .map(doorLabel);
      return {
        screen: local.action === 'admin' ? 'admin' : 'open',
        lines: [labels.join('　'), format(OPEN_CODES[local.action] || 'OPEN_MIXED', { doors: labels.join('、') })],
        countdown: { remainingMs: Math.max(0, local.openMs - (now - local.openedAt)), totalMs: local.openMs },
        notice: local.refusedOutcome && this.sessionDoorOpen(local) ? MESSAGES.CLOSE_DOOR_FIRST : null
      };
    }
  }

  return { DeviceCore, MESSAGES, LAYOUT, TIMING, STORAGE_KEYS, doorLabel, format };
});
