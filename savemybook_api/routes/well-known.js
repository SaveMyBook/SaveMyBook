const express = require('express');
const { env } = require('../config/env');
const { notFound } = require('../lib/errors');

const router = express.Router();

// 兩個檔案都不得轉址，iOS 與 Android 抓取時不會跟隨 3xx；缺少設定時回 404，不可回傳不完整的內容。
const sendJson = (res, body) => {
  res.setHeader('Cache-Control', 'public, max-age=3600');
  res.status(200).type('application/json').send(JSON.stringify(body));
};

router.get('/apple-app-site-association', async (req, res) => {
  if (!env.appleTeamId || !env.iosBundleId) throw notFound('找不到資料');
  sendJson(res, { webcredentials: { apps: [`${env.appleTeamId}.${env.iosBundleId}`] } });
});

router.get('/assetlinks.json', async (req, res) => {
  if (!env.androidPackageName || env.androidCertFingerprints.length === 0) throw notFound('找不到資料');
  sendJson(res, [{
    relation: ['delegate_permission/common.handle_all_urls', 'delegate_permission/common.get_login_creds'],
    target: {
      namespace: 'android_app',
      package_name: env.androidPackageName,
      sha256_cert_fingerprints: env.androidCertFingerprints
    }
  }]);
});

module.exports = router;
