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

module.exports = {
  name: '通行密鑰：應用程式關聯檔案',
  tests: [
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
