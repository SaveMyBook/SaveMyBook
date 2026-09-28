const assert = require('assert');
const fs = require('fs');
const path = require('path');
const h = require('./harness');

const { request, API_ROOT } = h;
const { env } = h.api('config/env');
const { MOUNTS } = h.api('routes');
const { buildSpec } = h.api('config/openapi');

const CSP = "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; font-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'";
const ASSETS = ['device-core.js', 'kiosk.js', 'qrcode.js', 'kiosk.css'];

const withSimulator = async (enabled, fn) => {
  const before = env.cabinetSimulator;
  env.cabinetSimulator = enabled;
  try {
    await fn();
  } finally {
    env.cabinetSimulator = before;
  }
};

const assertSecurityHeaders = (res) => {
  assert.strictEqual(res.headers.get('content-security-policy'), CSP);
  assert.strictEqual(res.headers.get('referrer-policy'), 'no-referrer');
  assert.strictEqual(res.headers.get('x-robots-tag'), 'noindex, nofollow');
  assert.strictEqual(res.headers.get('permissions-policy'), 'camera=(), microphone=(), geolocation=()');
  assert.strictEqual(res.headers.get('x-frame-options'), 'DENY');
  assert.strictEqual(res.headers.get('x-content-type-options'), 'nosniff');
};

const tests = [
  ['/kiosk 掛載於 /.well-known 之前', () => {
    const prefixes = MOUNTS.map(([prefix]) => prefix);
    const index = prefixes.indexOf('/kiosk');
    assert.ok(index >= 0, 'routes/index.js 尚未掛載 /kiosk');
    assert.deepStrictEqual(MOUNTS[index], ['/kiosk', './kiosk']);
    assert.ok(index < prefixes.indexOf('/.well-known'));
  }],

  ['模擬器關閉時 /kiosk 與資產都回 404，且不透露頁面內容', () => withSimulator(false, async () => {
    for (const url of ['/kiosk', '/kiosk/', '/kiosk/assets/device-core.js', '/kiosk/assets/kiosk.css']) {
      const res = await request('GET', url);
      assert.strictEqual(res.status, 404, url);
      assert.strictEqual(res.text, '找不到此頁面');
      assert.strictEqual(res.headers.get('cache-control'), 'no-store');
      assertSecurityHeaders(res);
    }
  })],

  ['頁面：安全標頭、no-store、只引用同源資產，沒有行內腳本或樣式', () => withSimulator(true, async () => {
    const res = await request('GET', '/kiosk');
    assert.strictEqual(res.status, 200);
    assert.match(res.headers.get('content-type'), /^text\/html/);
    assert.strictEqual(res.headers.get('cache-control'), 'no-store');
    assertSecurityHeaders(res);

    const html = res.text;
    assert.match(html, /<html lang="zh-Hant">/);
    assert.match(html, /<title>模擬書櫃｜救「舊」我的書<\/title>/);
    assert.match(html, /<meta name="robots" content="noindex">/);
    assert.match(html, /測試用模擬書櫃，非實體書櫃/);
    assert.doesNotMatch(html, /<style/i);
    assert.doesNotMatch(html, /\sstyle=/i);
    assert.doesNotMatch(html, /\son[a-z]+=/i);
    const scripts = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)];
    assert.strictEqual(scripts.length, 3);
    for (const [, attrs, body] of scripts) {
      assert.match(attrs, /\ssrc="\/kiosk\/assets\/[a-z-]+\.js"/);
      assert.strictEqual(body.trim(), '');
    }
    const refs = [...html.matchAll(/(?:src|href)="([^"]+)"/g)].map((m) => m[1]).filter((u) => u !== 'data:,');
    assert.deepStrictEqual(refs.sort(), ASSETS.map((f) => `/kiosk/assets/${f}`).sort());

    const slash = await request('GET', '/kiosk/');
    assert.strictEqual(slash.status, 200);
  })],

  ['白名單資產：no-cache、正確的內容類型與安全標頭', () => withSimulator(true, async () => {
    for (const file of ASSETS) {
      const res = await request('GET', `/kiosk/assets/${file}`);
      assert.strictEqual(res.status, 200, file);
      assert.strictEqual(res.headers.get('cache-control'), 'no-cache', file);
      assert.match(res.headers.get('content-type'), file.endsWith('.css') ? /^text\/css/ : /javascript/, file);
      assertSecurityHeaders(res);
      assert.strictEqual(res.text, fs.readFileSync(path.join(API_ROOT, 'views/kiosk', file), 'utf8'));
    }
  })],

  ['白名單以外的檔名與路徑穿越一律 404', () => withSimulator(true, async () => {
    const urls = [
      '/kiosk/assets/app.js',
      '/kiosk/assets/Kiosk.js',
      '/kiosk/assets/kiosk.js.map',
      '/kiosk/assets/..%2Fkiosk-page.js',
      '/kiosk/assets/..%2F..%2Froutes%2Fkiosk.js',
      '/kiosk/assets/%2e%2e%2fkiosk-page.js',
      '/kiosk/assets/kiosk%2Fkiosk.js',
      '/kiosk/assets/sub/kiosk.js',
      '/kiosk/assets/kiosk.js%00',
      '/kiosk/assets/',
      '/kiosk/other'
    ];
    for (const url of urls) {
      const res = await request('GET', url);
      assert.strictEqual(res.status, 404, url);
      assert.strictEqual(res.text, '找不到此頁面', url);
      assertSecurityHeaders(res);
    }
  })],

  ['模擬頁程式不使用 eval、new Function、行內事件處理器或外部網址', () => {
    for (const file of ['device-core.js', 'kiosk.js', 'qrcode.js']) {
      const src = fs.readFileSync(path.join(API_ROOT, 'views/kiosk', file), 'utf8');
      assert.doesNotMatch(src, /\beval\s*\(/, file);
      assert.doesNotMatch(src, /new\s+Function\b/, file);
      assert.doesNotMatch(src, /\.on[a-z]+\s*=/, file);
      assert.doesNotMatch(src, /setAttribute\(\s*['"](?:on[a-z]+|style)['"]/, file);
      assert.doesNotMatch(src, /innerHTML|outerHTML|insertAdjacentHTML|document\.write/, file);
      assert.doesNotMatch(src, /https?:\/\/(?!www\.(?:opensource\.org|d-project\.com|denso-wave\.com))/, file);
    }
    const css = fs.readFileSync(path.join(API_ROOT, 'views/kiosk/kiosk.css'), 'utf8');
    assert.doesNotMatch(css, /@import|url\(\s*['"]?https?:/);
    const qr = fs.readFileSync(path.join(API_ROOT, 'views/kiosk/qrcode.js'), 'utf8');
    assert.match(qr, /Copyright \(c\) 2009 Kazuhiko Arase/);
    assert.match(qr, /Licensed under the MIT license/);
  }],

  ['OpenAPI 記錄 /kiosk 與 /kiosk/assets/{file}', () => {
    const spec = buildSpec();
    assert.deepStrictEqual(spec.paths['/kiosk'].get.tags, ['public']);
    const assets = spec.paths['/kiosk/assets/{file}'].get;
    assert.deepStrictEqual(assets.tags, ['public']);
    assert.deepStrictEqual(assets.parameters[0].schema.enum.slice().sort(), ASSETS.slice().sort());
  }]
];

module.exports = { name: 'kiosk 路由', tests };
