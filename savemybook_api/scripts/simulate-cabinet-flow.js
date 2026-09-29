#!/usr/bin/env node
const crypto = require('crypto');
const readline = require('readline');
const { DeviceCore, MESSAGES } = require('../views/kiosk/device-core');

const USAGE = `用法：
  node scripts/simulate-cabinet-flow.js --base <網址> (--pair | --device-token <憑證> | --device-only)
                                        [--book <書籍編號>] [--order <訂單編號>] [--fast] [--yes]

腳本扮演 App：以書櫃座標作為手機定位建立作業，並送出比對碼與「完成」。

環境變數：
  SELLER_TOKEN  賣家測試帳號的 JWT（必填）
  BUYER_TOKEN   買家測試帳號的 JWT（第 4、5 步）
  BUYER_PIN     買家的交易密碼（第 4 步直接購買；未提供時略過第 4、5 步）

參數：
  --base          API 網址，例如 http://localhost:3000（必填，不預設正式站）
  --pair          由腳本扮演的模擬書櫃申請配對碼並顯示於終端機，管理員於後台輸入後繼續執行
  --device-token  既有的模擬書櫃憑證；只能用於沒有其他程式正在使用的憑證，否則會被判定為複製而撤銷
  --device-only   不由腳本扮演書櫃，改用實機：操作人員於終端機輸入書櫃螢幕上的數字，並實際存取書籍與開關櫃門
  --book          第 1 至 5 步使用的書籍（賣家本人上架、存放於此書櫃、目前未存書）
  --order         第 6 步使用的待存書訂單（賣家為本人、指定此書櫃）
  --fast          開門後立即送出「完成」，不等待倒數
  --yes           實際執行；未帶時只列出將執行的步驟`;

const TERMINAL = new Set(['completed', 'partial', 'cancelled', 'failed', 'expired', 'needs_review']);

const parseArgs = (argv) => {
  const flags = new Set(['yes', 'fast', 'pair', 'device-only', 'help']);
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg.startsWith('--')) throw new Error(`無法辨識的參數：${arg}`);
    const [key, inline] = arg.slice(2).split(/=(.*)/s);
    if (flags.has(key)) {
      out[key] = true;
    } else if (inline !== undefined) {
      out[key] = inline;
    } else {
      if (i + 1 >= argv.length) throw new Error(`參數 --${key} 缺少值`);
      out[key] = argv[++i];
    }
  }
  return out;
};

const positiveInt = (value, label) => {
  if (value === undefined) return null;
  const n = Number(value);
  if (!Number.isInteger(n) || n <= 0) throw new Error(`${label}必須為正整數`);
  return n;
};

const createClient = (base) => async (method, path, { token, body, headers = {} } = {}) => {
  let res;
  try {
    res = await fetch(base + path, {
      method,
      headers: {
        accept: 'application/json',
        ...(token && { authorization: `Bearer ${token}` }),
        ...(body && { 'content-type': 'application/json' }),
        ...headers
      },
      body: body ? JSON.stringify(body) : undefined,
      signal: AbortSignal.timeout(20000)
    });
  } catch (err) {
    return { status: 0, json: { message: `連線失敗：${err.message}` } };
  }
  const text = await res.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    json = { message: text.slice(0, 200) };
  }
  return { status: res.status, json };
};

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const waitFor = async (check, { timeoutMs, label, intervalMs = 100 }) => {
  const deadline = Date.now() + timeoutMs;
  for (;;) {
    const value = await check();
    if (value) return value;
    if (Date.now() > deadline) throw new Error(`等待逾時：${label}`);
    await sleep(intervalMs);
  }
};

const ask = (question, until = null) => new Promise((resolve) => {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  let settled = false;
  const finish = (value) => {
    if (settled) return;
    settled = true;
    rl.close();
    resolve(value);
  };
  rl.question(question, (answer) => finish(answer.trim()));
  if (until) until.then(() => finish(null), () => finish(null));
});

class StepError extends Error {}

const fail = (message) => {
  throw new StepError(message);
};

const createDevice = ({ base, token }) => {
  const store = new Map();
  if (token) store.set('smb.device.token', token);
  const results = [];
  const core = new DeviceCore({
    baseUrl: base,
    fetch: (url, init) => fetch(url, { ...init, signal: AbortSignal.timeout(15000) }),
    storage: {
      get: (key) => (store.has(key) ? store.get(key) : null),
      set: (key, value) => store.set(key, String(value)),
      remove: (key) => store.delete(key)
    },
    clock: {
      now: () => performance.now(),
      setTimeout: (fn, ms) => setTimeout(fn, ms),
      clearTimeout: (id) => clearTimeout(id)
    },
    kind: 'simulator',
    firmware: 'sim-1.0.0',
    doorCount: 4,
    unlockPulseMs: 800,
    hasDoorSensor: false,
    autoCloseOnTimeout: true,
    random: () => crypto.randomInt(0, 2 ** 32) / 2 ** 32,
    onLog(entry) {
      const m = entry.dir === 'in' && /^event (\w+).* → (\w+)/.exec(entry.summary || '');
      if (m) results.push({ type: m[1], status: m[2] });
    }
  });
  return { core, results };
};

const main = async () => {
  let args;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (err) {
    console.error(`${err.message}\n\n${USAGE}`);
    process.exit(1);
  }
  if (args.help) {
    console.log(USAGE);
    return;
  }

  const errors = [];
  const base = typeof args.base === 'string' ? args.base.replace(/\/+$/, '') : '';
  if (!/^https?:\/\/[^/]+/.test(base)) errors.push('請以 --base 指定 API 網址（http:// 或 https://）');
  const deviceOnly = Boolean(args['device-only']);
  const sources = [Boolean(args.pair), args['device-token'] !== undefined, deviceOnly].filter(Boolean).length;
  if (sources !== 1) errors.push('請擇一指定 --pair、--device-token 或 --device-only');
  let bookId = null;
  let orderId = null;
  try {
    bookId = positiveInt(args.book, '--book ');
    orderId = positiveInt(args.order, '--order ');
  } catch (err) {
    errors.push(err.message);
  }
  if (!bookId && !orderId) errors.push('請至少指定 --book 或 --order');
  const sellerToken = process.env.SELLER_TOKEN || '';
  const buyerToken = process.env.BUYER_TOKEN || '';
  const buyerPin = process.env.BUYER_PIN || '';
  if (!sellerToken) errors.push('請設定環境變數 SELLER_TOKEN');
  if (errors.length) {
    console.error(`${errors.map((e) => `・${e}`).join('\n')}\n\n${USAGE}`);
    process.exit(1);
  }

  const canBuy = Boolean(bookId && buyerToken && buyerPin);
  const plan = [];
  if (bookId) {
    plan.push({ no: 1, title: `先行存書（書籍 ${bookId}）` });
    plan.push({ no: 2, title: `取回（書籍 ${bookId}）` });
    plan.push({ no: 3, title: `再次先行存書（書籍 ${bookId}）` });
    if (canBuy) {
      plan.push({ no: 4, title: `買家直接購買書籍 ${bookId}，訂單成立即為已存書` });
      plan.push({ no: 5, title: '買家取書' });
    }
  }
  if (orderId) plan.push({ no: 6, title: `依訂單存書（訂單 ${orderId}）` });

  console.log(`伺服器：${base}`);
  console.log(`書櫃：${deviceOnly ? '實機（由操作人員操作）' : '腳本模擬（device-core）'}${args.fast ? '，開門後立即送出「完成」' : ''}`);
  console.log('將執行的步驟：');
  for (const step of plan) console.log(`  ${step.no}. ${step.title}`);
  if (bookId && !canBuy) {
    console.log('  （未提供 BUYER_TOKEN 或 BUYER_PIN，略過第 4、5 步；請自行以買家帳號購買後再以 App 掃碼取書）');
  }
  if (!args.yes) {
    console.log('\n未帶 --yes，僅列出步驟，未執行任何操作。');
    return;
  }

  const call = createClient(base);
  let device = null;

  const stateTrace = async () => {
    const view = await waitFor(() => (device.core.view.screen === 'idle' && device.core.view.qr ? device.core.view : null), {
      timeoutMs: 30000, label: '書櫃回到閒置畫面並顯示 QR Code'
    });
    return `state ${view.screen}`;
  };

  const scanCode = async () => {
    if (device) return device.core.view.qr.payload;
    const code = await ask('請輸入書櫃螢幕 QR Code 的內容（savemybook://k/…）：');
    if (!/^savemybook:\/\/k\/[0-9a-f]{32}\/?$/i.test(code)) fail('QR Code 內容格式不正確');
    return code;
  };

  const waitDeviceEvent = async (type, from, timeoutMs = 20000) => {
    const found = await waitFor(() => device.results.slice(from).find((r) => r.type === type), {
      timeoutMs, label: `書櫃事件 ${type}`
    });
    return found.status;
  };

  const pollSession = async (token, sessionNo, until, timeoutMs, label, onSession = null) => waitFor(async () => {
    const res = await call('GET', `/api/cabinet-sessions/${sessionNo}`, { token });
    if (res.status !== 200) fail(`讀取書櫃作業失敗：HTTP ${res.status} ${res.json?.code ?? ''} ${res.json?.message ?? ''}`);
    const session = res.json.data;
    if (onSession) onSession(session);
    return until(session) ? session : null;
  }, { timeoutMs, label, intervalMs: 1000 });

  let location = null;
  const locateCabinet = async () => {
    const cabinetId = bookId ? (await bookOf()).cabinet_id : (await orderOf(orderId, sellerToken)).cabinet_id;
    const res = await call('GET', '/api/cabinets', { token: sellerToken });
    if (res.status !== 200) fail(`讀取書櫃清單失敗：HTTP ${res.status} ${res.json?.message ?? ''}`);
    const cabinet = (res.json.data ?? []).find((c) => Number(c.cabinet_id) === Number(cabinetId));
    if (!cabinet) fail(`書櫃 ${cabinetId ?? '（未指定）'} 目前停用或維修中，無法取得書櫃座標`);
    location = { lat: Number(cabinet.latitude), lng: Number(cabinet.longitude), accuracy_m: 10, age_ms: 0 };
  };

  const enterMatchCode = async (token, sessionNo) => {
    for (;;) {
      let code;
      if (device) {
        const view = await waitFor(() => (device.core.view.screen === 'match' && device.core.view.code ? device.core.view : null), {
          timeoutMs: 10000, label: '書櫃顯示比對碼'
        });
        code = view.code;
      } else {
        code = await ask('  請輸入書櫃螢幕上顯示的兩位數字：');
      }
      const res = await call('POST', `/api/cabinet-sessions/${sessionNo}/match`, { token, body: { code } });
      if (!device && res.status === 400 && res.json?.code === 'MATCH_CODE_INVALID') {
        console.log(`  ${res.json.message}`);
        continue;
      }
      return res;
    }
  };

  const requestDone = (token, sessionNo) =>
    call('POST', `/api/cabinet-sessions/${sessionNo}/close`, { token, body: { outcome: 'completed' } });

  const runSession = async ({ token, context, key, kind }) => {
    const trace = device ? [await stateTrace()] : [];
    const code = await scanCode();
    const from = device ? device.results.length : 0;

    const created = await call('POST', '/api/cabinet-sessions', { token, body: { code, context, location_status: 'granted', location } });
    trace.push(`create ${created.status}`);
    if (created.status !== 201) {
      console.log(`  ${trace.join(' → ')}`);
      fail(`建立書櫃作業失敗：${created.json?.code ?? ''} ${created.json?.message ?? ''}`);
    }
    const session = created.json.data;
    const no = session.session_no;
    const item = session.items.find((i) => i.key === key);
    if (!item || item.kind !== kind || item.blocked) {
      const listed = session.items.map((i) => `${i.key}（${i.kind}${i.blocked ? `，${i.blocked.code}` : ''}）`).join('、') || '無';
      await call('POST', `/api/cabinet-sessions/${no}/cancel`, { token });
      console.log(`  ${trace.join(' → ')}`);
      fail(`作業中沒有可辦理的 ${key}（${kind}）；伺服器列出的項目：${listed}`);
    }

    const started = await call('POST', `/api/cabinet-sessions/${no}/start`, { token, body: { keys: [key] } });
    trace.push(`start ${started.status}`);
    if (started.status !== 200 || started.json?.data?.status !== 'matching') {
      console.log(`  ${trace.join(' → ')}`);
      fail(`開始作業失敗：${started.json?.code ?? ''} ${started.json?.message ?? ''}`);
    }
    const openMs = Number(started.json.data.open_ms) || 30000;

    const matched = await enterMatchCode(token, no);
    trace.push(`match ${matched.status}`);
    if (matched.status !== 200 || !['opening', 'open'].includes(matched.json?.data?.status)) {
      console.log(`  ${trace.join(' → ')}`);
      const result = matched.json?.data?.result;
      fail(result
        ? `數字比對未通過：${result.code}（${result.message}）`
        : `數字比對失敗：${matched.json?.code ?? ''} ${matched.json?.message ?? ''}`);
    }

    let noticed = false;
    const watchNotice = (s) => {
      if (s.notice === 'CLOSE_DOOR_FIRST' && !noticed) {
        noticed = true;
        console.log('  書櫃回報櫃門尚未關上，請先關上櫃門');
      }
    };

    const waitEnd = () => pollSession(token, no, (s) => TERMINAL.has(s.status), openMs + 60000, '作業結束', watchNotice);
    let ended = null;
    if (device) {
      trace.push(`door_opened ${await waitDeviceEvent('door_opened', from)}`);
      if (args.fast) {
        trace.push(`close ${(await requestDone(token, no)).status}`);
      } else {
        console.log(`  櫃門已開啟，等待倒數 ${Math.round(openMs / 1000)} 秒後自動完成`);
      }
      trace.push(`session_closed ${await waitDeviceEvent('session_closed', from, openMs + 20000)}`);
    } else {
      const opened = await pollSession(token, no, (s) => s.status === 'open' || TERMINAL.has(s.status), 30000, '櫃門開啟');
      trace.push(opened.status === 'open' ? 'door_opened' : opened.status);
      if (opened.status === 'open' && args.fast) {
        trace.push(`close ${(await requestDone(token, no)).status}`);
      } else if (opened.status === 'open') {
        ended = waitEnd();
        const labels = opened.doors.map((d) => d.label).join('、');
        const answer = await ask(`  櫃門 ${labels} 已開啟，操作完成並關上櫃門後按 Enter 送出「完成」，或等待倒數結束：`, ended);
        if (answer === null) console.log('');
        else trace.push(`close ${(await requestDone(token, no)).status}`);
      }
    }

    const finished = await (ended ?? waitEnd());
    trace.push(finished.status);
    console.log(`  ${trace.join(' → ')}`);
    if (finished.status !== 'completed') {
      fail(`作業結果為 ${finished.status}（${finished.result?.code ?? '－'}：${finished.result?.message ?? ''}）`);
    }
    const done = finished.items.find((i) => i.key === key);
    if (done?.result !== 'done') fail(`項目 ${key} 的結果為 ${done?.result ?? '未知'}`);
    return finished;
  };

  const bookOf = async () => {
    const res = await call('GET', `/api/books/${bookId}`, { token: sellerToken });
    if (res.status !== 200) fail(`讀取書籍失敗：HTTP ${res.status} ${res.json?.message ?? ''}`);
    return res.json.data;
  };

  const orderOf = async (id, token) => {
    const res = await call('GET', `/api/orders/${id}`, { token });
    if (res.status !== 200) fail(`讀取訂單失敗：HTTP ${res.status} ${res.json?.message ?? ''}`);
    return res.json.data;
  };

  const expect = (ok, message) => {
    if (!ok) fail(message);
    console.log(`  ✓ ${message}`);
  };

  let boughtOrder = null;
  const steps = {
    1: async () => {
      await runSession({ token: sellerToken, context: { type: 'book', id: bookId }, key: `book:${bookId}`, kind: 'pre_deposit' });
      const book = await bookOf();
      expect(book.deposit != null, '書籍已登記存放於書櫃');
    },
    2: async () => {
      await runSession({ token: sellerToken, context: { type: 'book', id: bookId }, key: `book:${bookId}`, kind: 'retrieval' });
      const book = await bookOf();
      expect(book.deposit == null, '書籍的存書登記已刪除');
    },
    3: async () => steps[1](),
    4: async () => {
      const verify = await call('POST', '/api/security/verify', { token: buyerToken, body: { scope: 'payment', method: 'pin', pin: buyerPin } });
      const verifyToken = verify.json?.data?.verify_token;
      if (!verifyToken) fail(`買家交易密碼驗證失敗：${verify.json?.code ?? ''} ${verify.json?.message ?? ''}`);
      const bought = await call('POST', '/api/orders/buy-now', {
        token: buyerToken, body: { book_id: bookId }, headers: { 'x-verify-token': verifyToken }
      });
      console.log(`  buy-now ${bought.status}`);
      if (bought.status !== 201) fail(`購買失敗：${bought.json?.code ?? ''} ${bought.json?.message ?? ''}`);
      boughtOrder = bought.json.data;
      expect(boughtOrder.status === 'deposited', `訂單 ${boughtOrder.order_no} 成立即為已存書`);
    },
    5: async () => {
      if (!boughtOrder) fail('第 4 步未成立訂單');
      await runSession({ token: buyerToken, context: { type: 'order', id: boughtOrder.order_id }, key: `order:${boughtOrder.order_id}`, kind: 'pickup' });
      const order = await orderOf(boughtOrder.order_id, buyerToken);
      expect(order.picked_up_at != null, `訂單 ${order.order_no} 已記錄取書時間`);
    },
    6: async () => {
      const before = await orderOf(orderId, sellerToken);
      if (!['pending_payment', 'pending_deposit'].includes(before.status)) fail(`訂單 ${before.order_no} 目前狀態為 ${before.status}，不是待存書`);
      await runSession({ token: sellerToken, context: { type: 'order', id: orderId }, key: `order:${orderId}`, kind: 'order_deposit' });
      const order = await orderOf(orderId, sellerToken);
      expect(order.status === 'deposited', `訂單 ${order.order_no} 已改為已存書`);
    }
  };

  let exitCode = 0;
  try {
    if (!deviceOnly) {
      device = createDevice({ base, token: args['device-token'] });
      device.core.start();
      if (args.pair) {
        let shown = null;
        await waitFor(() => {
          const code = device.core.view.pairing?.code;
          if (code && code !== shown) {
            shown = code;
            console.log(`配對碼：${code}，請於管理後台的書櫃裝置頁面輸入（10 分鐘內有效，逾時將自動更新）`);
          }
          return device.core.token;
        }, { timeoutMs: 30 * 60 * 1000, label: '管理員輸入配對碼' })
          .catch(() => fail(`未完成配對（${MESSAGES[device.core.view.pairing?.error] ?? '未輸入配對碼'}），請確認模擬器已開啟後重新執行`));
        console.log(`已配對模擬書櫃 ${device.core.deviceNo ?? ''}（${device.core.cabinetName ?? ''}）`);
      }
      await waitFor(() => device.core.view.screen === 'idle' && device.core.view.qr, { timeoutMs: 30000, label: '書櫃啟動並顯示 QR Code' })
        .catch(() => fail(`書櫃未進入閒置畫面（目前為 ${device.core.view.screen}），請確認書櫃營業中、未維修且模擬器已開啟`));
      console.log(`書櫃：${device.core.view.cabinetName ?? '未知'}（${device.core.view.deviceNo ?? '未知'}）`);
    }

    await locateCabinet();

    for (const step of plan) {
      console.log(`\n第 ${step.no} 步：${step.title}`);
      await steps[step.no]();
    }
    console.log('\n全部步驟完成。');
  } catch (err) {
    exitCode = 1;
    console.error(err instanceof StepError ? `\n✗ ${err.message}` : `\n✗ 發生未預期的錯誤：${err.stack ?? err.message}`);
  } finally {
    if (device) device.core.stop();
  }
  process.exit(exitCode);
};

main();
