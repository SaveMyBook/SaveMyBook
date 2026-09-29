#!/usr/bin/env node
// 關聯檔一律向正式網域實際抓取：只看環境變數無法發現 nginx 上的佔位內容或轉址。
const ANDROID_PREFIX = 'android:apk-key-hash:';
const FINGERPRINT_RE = /^([0-9A-F]{2}:){31}[0-9A-F]{2}$/;
const APP_ID_RE = /^[A-Z0-9]{10}\.[\w.-]+$/;

const apkKeyHashOf = (fingerprint) => Buffer.from(fingerprint.replace(/:/g, ''), 'hex').toString('base64url');

const wellKnown = async (host, name) => {
  const res = await fetch(`https://${host}/.well-known/${name}`, { redirect: 'manual', signal: AbortSignal.timeout(10000) });
  if (res.status >= 300 && res.status < 400) throw new Error(`HTTP ${res.status}，此路徑不可轉址`);
  if (res.status !== 200) throw new Error(`HTTP ${res.status}`);
  try {
    return await res.json();
  } catch {
    throw new Error('內容不是合法的 JSON');
  }
};

const checkAssetLinks = async (rpId, origins, report) => {
  const label = 'assetlinks.json';
  try {
    const statements = await wellKnown(rpId, 'assetlinks.json');
    const fingerprints = (Array.isArray(statements) ? statements : [])
      .filter((s) => s?.target?.namespace === 'android_app' && s.relation?.includes('delegate_permission/common.get_login_creds'))
      .flatMap((s) => s.target.sha256_cert_fingerprints ?? []);
    const malformed = fingerprints.filter((fp) => !FINGERPRINT_RE.test(fp));
    const unmatched = fingerprints.filter((fp) => FINGERPRINT_RE.test(fp) && !origins.includes(`${ANDROID_PREFIX}${apkKeyHashOf(fp)}`));
    let detail = `${fingerprints.length} 組指紋，皆已列入 PASSKEY_ORIGINS`;
    if (fingerprints.length === 0) detail = '沒有宣告 get_login_creds 的 android_app 指紋';
    else if (malformed.length) detail = `指紋格式不正確（須為 32 組大寫十六進位並以冒號分隔）：${malformed.join('、')}`;
    else if (unmatched.length) {
      detail = `PASSKEY_ORIGINS 缺少：${unmatched.map((fp) => `${ANDROID_PREFIX}${apkKeyHashOf(fp)}（${fp}）`).join('、')}`;
    }
    report(fingerprints.length > 0 && malformed.length === 0 && unmatched.length === 0, label, detail);
  } catch (err) {
    report(false, label, err.message);
  }
};

const checkAppleAssociation = async (rpId, report) => {
  const label = 'apple-app-site-association';
  try {
    const apps = (await wellKnown(rpId, 'apple-app-site-association'))?.webcredentials?.apps ?? [];
    const valid = Array.isArray(apps) && apps.length > 0 && apps.every((app) => APP_ID_RE.test(app));
    report(valid, label, Array.isArray(apps) && apps.length ? apps.join('、') : '缺少 webcredentials.apps');
  } catch (err) {
    report(false, label, err.message);
  }
};

const checkPasskeys = async ({ passkeyRpId: rpId, passkeyOrigins: origins }, report) => {
  const badOrigins = origins.filter((o) => !/^https:\/\/[^/]+$/.test(o) && !/^android:apk-key-hash:[A-Za-z0-9_-]{43}$/.test(o));
  report(Boolean(rpId) && origins.length > 0 && badOrigins.length === 0, '通行密鑰 RP ID 與來源',
    badOrigins.length
      ? `PASSKEY_ORIGINS 格式不正確：${badOrigins.join('、')}`
      : `RP ID ${rpId || '（未設定）'}，來源 ${origins.length} 組`);
  if (!rpId) return;

  report(origins.includes(`https://${rpId}`), '通行密鑰 iOS 來源',
    origins.includes(`https://${rpId}`) ? '已設定' : `PASSKEY_ORIGINS 須包含 https://${rpId}`);
  const android = origins.some((o) => o.startsWith(ANDROID_PREFIX));
  report(android, '通行密鑰 Android 來源',
    android ? '已設定' : `PASSKEY_ORIGINS 未包含 ${ANDROID_PREFIX}<指紋>，Android 將無法使用通行密鑰`);

  await checkAssetLinks(rpId, origins, report);
  await checkAppleAssociation(rpId, report);
};

if (require.main === module) {
  const { env } = require('../config/env');
  const results = [];
  checkPasskeys(env, (ok, label, detail = '') => results.push({ ok, label, detail })).then(() => {
    for (const r of results) console.log(`${r.ok ? '✅' : '❌'} ${r.label}  ${r.detail}`);
    process.exit(results.every((r) => r.ok) ? 0 : 1);
  });
}

module.exports = { checkPasskeys, apkKeyHashOf };
