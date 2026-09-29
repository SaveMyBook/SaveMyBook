const assert = require('assert');
const h = require('./harness');

const { request } = h;
const { env } = h.api('config/env');

const withEnv = async (values, fn) => {
  const before = Object.fromEntries(Object.keys(values).map((k) => [k, env[k]]));
  Object.assign(env, values);
  try {
    await fn();
  } finally {
    Object.assign(env, before);
  }
};

const FINGERPRINT = 'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99';
const APK_KEY_HASH = `android:apk-key-hash:${Buffer.from(FINGERPRINT.replace(/:/g, ''), 'hex').toString('base64url')}`;

const served = {};
h.onFetch('https://savemybook.today/.well-known/', (url) => {
  const file = served[url.split('/.well-known/')[1]];
  if (!file) return new Response('not found', { status: 404 });
  return file.redirect
    ? new Response(null, { status: 301, headers: { location: file.redirect } })
    : h.jsonResponse(file.body);
});

const assetLinks = (fingerprints) => [{
  relation: ['delegate_permission/common.handle_all_urls', 'delegate_permission/common.get_login_creds'],
  target: { namespace: 'android_app', package_name: 'today.savemybook.app', sha256_cert_fingerprints: fingerprints }
}];

const deployCheck = async ({ origins = ['https://savemybook.today', APK_KEY_HASH], files }) => {
  for (const key of Object.keys(served)) delete served[key];
  Object.assign(served, files);
  const results = {};
  await h.api('scripts/passkey-deploy-check').checkPasskeys(
    { passkeyRpId: 'savemybook.today', passkeyOrigins: origins },
    (ok, label, detail = '') => { results[label] = { ok, detail }; }
  );
  return results;
};

const goodFiles = () => ({
  'assetlinks.json': { body: assetLinks([FINGERPRINT]) },
  'apple-app-site-association': { body: { webcredentials: { apps: ['ABCDE12345.today.savemybook.app'] } } }
});

module.exports = {
  name: '通行密鑰：應用程式關聯檔案',
  tests: [
    ['部署檢查：關聯檔與 PASSKEY_ORIGINS 一致時全部通過', async () => {
      const results = await deployCheck({ files: goodFiles() });
      assert.deepStrictEqual(Object.entries(results).filter(([, r]) => !r.ok), []);
      assert.ok(results['assetlinks.json'] && results['apple-app-site-association']);
    }],

    ['部署檢查：PASSKEY_ORIGINS 缺少 Android 來源時不可通過', async () => {
      const results = await deployCheck({ origins: ['https://savemybook.today'], files: goodFiles() });
      assert.strictEqual(results['通行密鑰 Android 來源'].ok, false);
      assert.strictEqual(results['assetlinks.json'].ok, false);
      assert.ok(results['assetlinks.json'].detail.includes(APK_KEY_HASH), '直接列出應加入的 apk-key-hash');
    }],

    ['部署檢查：線上 assetlinks.json 仍是佔位字串、轉址或不存在時不可通過', async () => {
      const placeholder = await deployCheck({
        files: { ...goodFiles(), 'assetlinks.json': { body: assetLinks(['<RELEASE_SHA256_FINGERPRINT>']) } }
      });
      assert.strictEqual(placeholder['assetlinks.json'].ok, false);
      assert.ok(placeholder['assetlinks.json'].detail.includes('指紋格式不正確'));

      const redirected = await deployCheck({
        files: { ...goodFiles(), 'assetlinks.json': { redirect: 'https://www.savemybook.today/.well-known/assetlinks.json' } }
      });
      assert.strictEqual(redirected['assetlinks.json'].ok, false);
      assert.ok(redirected['assetlinks.json'].detail.includes('不可轉址'));

      const missing = await deployCheck({ files: { 'apple-app-site-association': goodFiles()['apple-app-site-association'] } });
      assert.strictEqual(missing['assetlinks.json'].ok, false);
    }],

    ['部署檢查：apple-app-site-association 缺少 webcredentials 時不可通過', async () => {
      const results = await deployCheck({
        files: { ...goodFiles(), 'apple-app-site-association': { body: { applinks: { details: [] } } } }
      });
      assert.strictEqual(results['apple-app-site-association'].ok, false);
    }],

    ['缺少設定時兩個路徑回 404，不回傳不完整的檔案', async () => {
      await withEnv({ appleTeamId: '', iosBundleId: 'today.savemybook.app', androidCertFingerprints: [] }, async () => {
        assert.strictEqual((await request('GET', '/.well-known/apple-app-site-association')).status, 404);
        assert.strictEqual((await request('GET', '/.well-known/assetlinks.json')).status, 404);
      });
    }],

    ['apple-app-site-association 以 application/json 回應 webcredentials，不轉址', async () => {
      await withEnv({ appleTeamId: 'ABCDE12345', iosBundleId: 'today.savemybook.app' }, async () => {
        const res = await request('GET', '/.well-known/apple-app-site-association');
        assert.strictEqual(res.status, 200);
        assert.ok(res.headers.get('content-type').startsWith('application/json'));
        assert.deepStrictEqual(res.body, { webcredentials: { apps: ['ABCDE12345.today.savemybook.app'] } });
      });
    }],

    ['assetlinks.json 宣告 get_login_creds 與簽署金鑰指紋', async () => {
      const fingerprint = 'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99';
      await withEnv({ androidPackageName: 'today.savemybook.app', androidCertFingerprints: [fingerprint] }, async () => {
        const res = await request('GET', '/.well-known/assetlinks.json');
        assert.strictEqual(res.status, 200);
        const [statement] = res.body;
        assert.ok(statement.relation.includes('delegate_permission/common.get_login_creds'));
        assert.deepStrictEqual(statement.target, {
          namespace: 'android_app', package_name: 'today.savemybook.app', sha256_cert_fingerprints: [fingerprint]
        });
      });
    }]
  ]
};
