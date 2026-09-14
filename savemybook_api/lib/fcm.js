const fs = require('fs');
const jwt = require('jsonwebtoken');

const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

/// FCM HTTP v1 的最小實作。
///
/// 不用 firebase-admin：它會拉進一整套 Google Cloud 相依套件，而這裡只需要
/// 「用服務帳戶換 access token」與「送一則訊息」兩件事。
class FcmClient {
  constructor(serviceAccount) {
    const { project_id: projectId, client_email: clientEmail, private_key: privateKey } = serviceAccount;
    if (!projectId || !clientEmail || !privateKey) {
      throw new Error('服務帳戶金鑰缺少 project_id、client_email 或 private_key');
    }
    this.projectId = projectId;
    this.clientEmail = clientEmail;
    this.privateKey = privateKey;
    this.tokenUri = serviceAccount.token_uri || 'https://oauth2.googleapis.com/token';
    this.accessToken = null;
    this.accessTokenExpiresAt = 0;
    this.pendingToken = null;
  }

  static fromFile(filePath) {
    return new FcmClient(JSON.parse(fs.readFileSync(filePath, 'utf8')));
  }

  async getAccessToken() {
    // 提早一分鐘換新，避免送到一半過期。
    if (this.accessToken && Date.now() < this.accessTokenExpiresAt - 60 * 1000) return this.accessToken;
    // 同時有很多則要送時只換一次。
    if (!this.pendingToken) {
      this.pendingToken = this.fetchAccessToken().finally(() => { this.pendingToken = null; });
    }
    return this.pendingToken;
  }

  async fetchAccessToken() {
    const now = Math.floor(Date.now() / 1000);
    const assertion = jwt.sign(
      { iss: this.clientEmail, scope: SCOPE, aud: this.tokenUri, iat: now, exp: now + 3600 },
      this.privateKey,
      { algorithm: 'RS256' }
    );

    const response = await fetch(this.tokenUri, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
      signal: AbortSignal.timeout(10 * 1000)
    });
    const body = await response.json().catch(() => ({}));
    if (!response.ok || !body.access_token) {
      throw new Error(`取得 FCM access token 失敗：${body.error_description || body.error || response.status}`);
    }

    this.accessToken = body.access_token;
    this.accessTokenExpiresAt = Date.now() + (Number(body.expires_in) || 3600) * 1000;
    return this.accessToken;
  }

  /// 回傳 { ok: true } 或 { ok: false, invalidToken, retryable, error }。
  /// invalidToken 代表這個裝置 token 已經不能用（App 被刪除、token 過期），呼叫端應刪除。
  async send(message) {
    const accessToken = await this.getAccessToken();
    let response;
    try {
      response = await fetch(`https://fcm.googleapis.com/v1/projects/${this.projectId}/messages:send`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ message }),
        signal: AbortSignal.timeout(10 * 1000)
      });
    } catch (err) {
      return { ok: false, retryable: true, error: err.message };
    }

    if (response.ok) return { ok: true };

    const body = await response.json().catch(() => ({}));
    const status = body.error?.status;
    const detailCode = (body.error?.details ?? []).map((d) => d.errorCode).find(Boolean);

    if (response.status === 401) this.accessToken = null;

    return {
      ok: false,
      invalidToken: detailCode === 'UNREGISTERED' || status === 'NOT_FOUND'
        || (status === 'INVALID_ARGUMENT' && /token/i.test(body.error?.message ?? '')),
      retryable: response.status === 429 || response.status >= 500 || response.status === 401,
      error: `${response.status} ${detailCode || status || ''} ${body.error?.message ?? ''}`.trim()
    };
  }
}

module.exports = { FcmClient };
