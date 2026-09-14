#!/usr/bin/env node
const { buildSpec } = require('../config/openapi');

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...v] = a.replace(/^--/, '').split('=');
  return [k, v.join('=')];
}));

const base = (args.base || 'http://localhost:3000').replace(/\/+$/, '');
const email = args.email || process.env.SMOKE_EMAIL;
const password = args.password || process.env.SMOKE_PASSWORD;

if (!email || !password) {
  console.error('用法：node scripts/smoke-test.js --base=https://api.savemybook.today --email=<帳號> --password=<密碼>');
  process.exit(1);
}

const call = async (method, url, { token, body } = {}) => {
  const started = Date.now();
  try {
    const res = await fetch(base + url, {
      method,
      headers: {
        Accept: 'application/json',
        ...(token && { Authorization: `Bearer ${token}` }),
        ...(body && { 'Content-Type': 'application/json' })
      },
      body: body ? JSON.stringify(body) : undefined,
      signal: AbortSignal.timeout(20000)
    });
    const text = await res.text();
    let json = null;
    try { json = JSON.parse(text); } catch {}
    return { status: res.status, json, ms: Date.now() - started };
  } catch (err) {
    return { status: 0, json: { message: err.message }, ms: Date.now() - started };
  }
};

const main = async () => {
  const status = await call('GET', '/api/status');
  if (status.status === 404) {
    console.log('❌ /api/status 不存在：伺服器仍在執行舊版程式，請 git pull 並重新啟動 API');
  } else if (status.json?.data) {
    const d = status.json.data;
    console.log(`伺服器版本 commit ${d.commit ?? '未知'}，啟動於 ${d.started_at ?? '未知'}`);
    if (d.pending_migrations?.length) console.log(`❌ 尚未執行的 migration：${d.pending_migrations.join('、')}`);
  }

  const login = await call('POST', '/api/auth/login', {
    body: { email, password, device_id: 'smoke-test', device_name: 'Smoke test', platform: 'script' }
  });
  const token = login.json?.data?.token;
  if (!token) {
    console.error(`❌ 登入失敗：${login.json?.message ?? login.status}`);
    process.exit(1);
  }
  const me = await call('GET', '/api/auth/me', { token });
  const isAdmin = me.json?.data?.role === 'admin';

  const spec = buildSpec();
  const targets = [];
  for (const [p, ops] of Object.entries(spec.paths)) {
    if (!ops.get || p.includes('{') || p === '/api/users/me/export' || p.includes('/download')) continue;
    if (p.startsWith('/api/admin') && !isAdmin) continue;
    if (!p.startsWith('/api/')) continue;
    targets.push(p);
  }

  const problems = [];
  for (const p of targets) {
    const r = await call('GET', p, { token });
    const code = r.json?.code;
    const ok = r.status >= 200 && r.status < 300;
    const expected = code === 'PUSH_DISABLED' || code === 'ADMIN_PERMISSION_REQUIRED';
    const mark = ok ? '✅' : expected ? '⚠️ ' : '❌';
    console.log(`${mark} ${String(r.status).padEnd(3)} ${String(r.ms).padStart(5)}ms  GET ${p}${ok ? '' : `  ${code ?? ''} ${r.json?.message ?? ''}`}`);
    if (!ok && !expected) problems.push({ p, status: r.status, code, message: r.json?.message });
  }

  await call('POST', '/api/auth/logout', { token });

  console.log(`\n共測試 ${targets.length} 個端點（${isAdmin ? '含' : '不含'}後台），${problems.length} 個異常`);
  const outdated = problems.filter((x) => x.code === 'ROUTE_NOT_FOUND');
  if (outdated.length) console.log(`→ ${outdated.length} 個端點 404：伺服器程式版本過舊，請更新並重新啟動 API`);
  const noSchema = problems.filter((x) => x.code === 'SECURITY_UNAVAILABLE' || x.status === 503);
  if (noSchema.length) console.log('→ 有 503：請執行 migrations/007_consent_sessions_payment.sql');
  if (problems.some((x) => x.status >= 500 && x.status !== 503)) console.log('→ 有 500：請查看伺服器日誌');
  process.exit(problems.length ? 1 : 0);
};

main();
