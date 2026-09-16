const assert = require('assert');
const h = require('./harness');

const { prisma, request } = h;
const publicId = h.api('lib/public-id');

const optionsFor = async (ctx) => (await request('POST', '/api/users/me/passkeys/options', { token: ctx.token })).body.data.options;

module.exports = {
  name: '通行密鑰：註冊與管理',
  tests: [
    ['註冊 options 使用正確的 RP、要求使用者驗證，且不含會員流水號', async () => {
      const ctx = h.signedIn();
      const options = await optionsFor(ctx);
      assert.strictEqual(options.rp.id, 'savemybook.today');
      assert.strictEqual(options.rp.name, '救「舊」我的書');
      assert.strictEqual(options.user.name, ctx.user.email);
      assert.notStrictEqual(options.user.id, String(ctx.user.user_id));
      assert.ok(options.user.id.length >= 40);
      assert.strictEqual(options.authenticatorSelection.userVerification, 'required');
      assert.strictEqual(options.authenticatorSelection.residentKey, 'required');
      assert.strictEqual(options.challenge.length, 64);
      assert.deepStrictEqual(prisma.rows('webauthn_challenges').map((r) => [r.purpose, r.user_id]), [['register', ctx.user.user_id]]);
    }],

    ['以真實的 attestation 完成註冊，清單只回傳加密編號與顯示資訊', async () => {
      const ctx = h.signedIn();
      const authenticator = new h.Authenticator();
      const options = await optionsFor(ctx);
      const res = await request('POST', '/api/users/me/passkeys', {
        token: ctx.token,
        headers: h.sensitive(ctx),
        body: { attestation: authenticator.create(options), device_label: 'iPhone 17 Pro' }
      });
      assert.strictEqual(res.status, 201);
      assert.strictEqual(res.body.message, '已新增通行密鑰');
      const [item] = res.body.data;
      assert.deepStrictEqual(Object.keys(item).sort(), ['backed_up', 'created_at', 'device_label', 'last_used_at', 'passkey_id']);
      assert.ok(/^PK[0-9A-Z]{7}$/.test(item.passkey_id));
      assert.strictEqual(item.device_label, 'iPhone 17 Pro');
      assert.strictEqual(item.backed_up, true);

      const [row] = prisma.rows('user_passkeys');
      assert.strictEqual(row.credential_id, authenticator.id);
      assert.strictEqual(Number(row.user_id), ctx.user.user_id);
      assert.strictEqual(row.transports, 'internal,hybrid');
      assert.strictEqual(prisma.rows('webauthn_challenges').length, 0, '挑戰值用過即刪');
      assert.strictEqual(prisma.rows('notifications')[0].title, '已新增通行密鑰');

      const list = await request('GET', '/api/users/me/passkeys', { token: ctx.token });
      assert.deepStrictEqual(list.body.data, res.body.data);
    }],

    ['新增通行密鑰需要 sensitive 身分驗證，驗證後重送同一份資料仍可成功', async () => {
      const ctx = h.signedIn();
      const attestation = new h.Authenticator().create(await optionsFor(ctx));
      const bare = await request('POST', '/api/users/me/passkeys', { token: ctx.token, body: { attestation } });
      assert.strictEqual(bare.status, 403);
      assert.strictEqual(bare.body.code, 'VERIFICATION_REQUIRED');
      assert.strictEqual(prisma.rows('webauthn_challenges').length, 1, '未通過身分驗證時不可消耗挑戰值');

      const retry = await request('POST', '/api/users/me/passkeys', { token: ctx.token, headers: h.sensitive(ctx), body: { attestation } });
      assert.strictEqual(retry.status, 201);
    }],

    ['第二次註冊時排除已註冊的憑證，重複註冊同一組回 409', async () => {
      const ctx = h.signedIn();
      const authenticator = await h.registerPasskey(ctx);
      const options = await optionsFor(ctx);
      assert.deepStrictEqual(options.excludeCredentials.map((c) => c.id), [authenticator.id]);

      const again = await request('POST', '/api/users/me/passkeys', {
        token: ctx.token, headers: h.sensitive(ctx), body: { attestation: authenticator.create(options) }
      });
      assert.strictEqual(again.status, 409);
      assert.strictEqual(again.body.code, 'PASSKEY_ALREADY_REGISTERED');
    }],

    ['來源或 RP ID 不符、未經使用者驗證的 attestation 一律拒絕', async () => {
      const ctx = h.signedIn();
      const cases = [
        { origin: 'https://evil.example' },
        { rpId: 'evil.example' },
        { userVerified: false }
      ];
      for (const override of cases) {
        const attestation = new h.Authenticator().create(await optionsFor(ctx), override);
        const res = await request('POST', '/api/users/me/passkeys', { token: ctx.token, headers: h.sensitive(ctx), body: { attestation } });
        assert.strictEqual(res.status, 400, JSON.stringify(override));
        assert.strictEqual(res.body.code, 'PASSKEY_VERIFICATION_FAILED');
      }
      assert.strictEqual(prisma.rows('user_passkeys').length, 0);
    }],

    ['Android 的 apk-key-hash 來源可以註冊', async () => {
      const ctx = h.signedIn();
      const attestation = new h.Authenticator({ origin: h.ANDROID_ORIGIN }).create(await optionsFor(ctx));
      const res = await request('POST', '/api/users/me/passkeys', { token: ctx.token, headers: h.sensitive(ctx), body: { attestation } });
      assert.strictEqual(res.status, 201);
    }],

    ['其他使用者的註冊挑戰值不能拿來用', async () => {
      const owner = h.signedIn();
      const other = h.signedIn();
      const attestation = new h.Authenticator().create(await optionsFor(owner));
      const res = await request('POST', '/api/users/me/passkeys', { token: other.token, headers: h.sensitive(other), body: { attestation } });
      assert.strictEqual(res.status, 400);
      assert.strictEqual(res.body.code, 'PASSKEY_CHALLENGE_INVALID');
      assert.strictEqual(prisma.rows('webauthn_challenges').length, 0, '失敗的嘗試同樣會用掉挑戰值');
    }],

    ['格式不正確的資料回 400，不會進到驗證程式庫', async () => {
      const ctx = h.signedIn();
      for (const attestation of [undefined, 'x', { id: 'abc', response: {} }, { id: '***', response: { clientDataJSON: 'a', attestationObject: 'b' } }]) {
        const res = await request('POST', '/api/users/me/passkeys', { token: ctx.token, headers: h.sensitive(ctx), body: { attestation } });
        assert.strictEqual(res.status, 400);
        assert.strictEqual(res.body.code, 'PASSKEY_INVALID_RESPONSE');
      }
      const label = await request('POST', '/api/users/me/passkeys', {
        token: ctx.token, headers: h.sensitive(ctx), body: { attestation: {}, device_label: 'x'.repeat(51) }
      });
      assert.strictEqual(label.body.message, '裝置名稱不可超過 50 個字');
    }],

    ['刪除通行密鑰需要身分驗證，只能刪自己的，編號錯誤回 404', async () => {
      const ctx = h.signedIn();
      await h.registerPasskey(ctx);
      const [row] = prisma.rows('user_passkeys');
      const code = publicId.encode('passkey', row.passkey_id);

      const bare = await request('DELETE', `/api/users/me/passkeys/${code}`, { token: ctx.token });
      assert.strictEqual(bare.status, 403);

      const other = h.signedIn();
      const foreign = await request('DELETE', `/api/users/me/passkeys/${code}`, { token: other.token, headers: h.sensitive(other) });
      assert.strictEqual(foreign.status, 404);
      const serial = await request('DELETE', `/api/users/me/passkeys/${row.passkey_id}`, { token: ctx.token, headers: h.sensitive(ctx) });
      assert.strictEqual(serial.status, 404, '流水號不可作為編號');

      const ok = await request('DELETE', `/api/users/me/passkeys/${code}`, { token: ctx.token, headers: h.sensitive(ctx) });
      assert.strictEqual(ok.status, 200);
      assert.deepStrictEqual(ok.body.data, []);
      assert.strictEqual(prisma.rows('user_passkeys').length, 0);
    }],

    ['刪除後帳號沒有任何登入方式時回 LAST_SIGN_IN_METHOD', async () => {
      const ctx = h.signedIn({ passwordSet: 0 });
      await h.registerPasskey(ctx, { label: 'iPhone' });
      await h.registerPasskey(ctx, { label: 'iPad' });
      const codes = prisma.rows('user_passkeys').map((r) => publicId.encode('passkey', r.passkey_id));
      const del = (code) => request('DELETE', `/api/users/me/passkeys/${code}`, { token: ctx.token, headers: h.sensitive(ctx) });

      assert.strictEqual((await del(codes[0])).status, 200, '還有另一組通行密鑰');
      const last = await del(codes[1]);
      assert.strictEqual(last.status, 400);
      assert.strictEqual(last.body.code, 'LAST_SIGN_IN_METHOD');

      prisma.rows('user_identities').push({
        identity_id: 1, user_id: ctx.user.user_id, provider: 'google', subject: 'g-1', created_at: new Date()
      });
      assert.strictEqual((await del(codes[1])).status, 200, '已綁定社群登入即可刪除');
    }],

    ['沒有密碼的帳號已註冊通行密鑰時，可以解除唯一的社群登入綁定', async () => {
      const ctx = h.signedIn({ passwordSet: 0 });
      prisma.rows('user_identities').push({
        identity_id: 1, user_id: ctx.user.user_id, provider: 'google', subject: 'g-1', created_at: new Date()
      });
      const unlink = () => request('DELETE', '/api/auth/link/google', { token: ctx.token, headers: h.sensitive(ctx) });

      const blocked = await unlink();
      assert.strictEqual(blocked.body.code, 'LAST_SIGN_IN_METHOD');

      await h.registerPasskey(ctx);
      const ok = await unlink();
      assert.strictEqual(ok.status, 200, ok.text);
    }],

    ['有密碼的帳號可以刪除唯一的通行密鑰', async () => {
      const ctx = h.signedIn();
      await h.registerPasskey(ctx);
      const code = publicId.encode('passkey', prisma.rows('user_passkeys')[0].passkey_id);
      const res = await request('DELETE', `/api/users/me/passkeys/${code}`, { token: ctx.token, headers: h.sensitive(ctx) });
      assert.strictEqual(res.status, 200);
    }],

    ['每個帳號最多 10 組', async () => {
      const ctx = h.signedIn();
      for (let i = 0; i < 10; i += 1) {
        prisma.rows('user_passkeys').push({
          passkey_id: i + 1, user_id: ctx.user.user_id, credential_id: `cred-${i}`, public_key: 'x', sign_count: 0,
          transports: null, backed_up: 0, device_label: null, created_at: new Date(), last_used_at: null
        });
      }
      const res = await request('POST', '/api/users/me/passkeys/options', { token: ctx.token });
      assert.strictEqual(res.status, 400);
      assert.strictEqual(res.body.code, 'PASSKEY_LIMIT');
    }],

    ['資料匯出包含通行密鑰但不含憑證編號；帳號匿名化會刪除通行密鑰與挑戰值', async () => {
      const ctx = h.signedIn();
      await h.registerPasskey(ctx, { label: 'Pixel 10' });
      const account = h.api('services/account');

      const data = await account.exportData(ctx.user.user_id);
      assert.strictEqual(data.passkeys.length, 1);
      const [item] = data.passkeys;
      assert.strictEqual(item.device_label, 'Pixel 10');
      assert.ok(item.public_key);
      assert.deepStrictEqual(item.transports, ['internal', 'hybrid']);
      assert.strictEqual(item.credential_id, undefined);
      assert.strictEqual(item.sign_count, undefined);

      await request('POST', '/api/users/me/passkeys/options', { token: ctx.token });
      ctx.user.deletion_requested_at = new Date(Date.now() - 40 * 86400000);
      await account.processDueDeletions();
      assert.ok(ctx.user.anonymized_at);
      assert.strictEqual(prisma.rows('user_passkeys').length, 0);
      assert.strictEqual(prisma.rows('webauthn_challenges').length, 0);
    }],

    ['未執行 016 時資料匯出的 passkeys 為 null', async () => {
      h.reset({ schema: h.withoutPasskeys() });
      const ctx = h.signedIn();
      const data = await h.api('services/account').exportData(ctx.user.user_id);
      assert.strictEqual(data.passkeys, null);
    }]
  ]
};
