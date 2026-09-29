const prisma = require('../../lib/prisma');
const { HttpError, badRequest } = require('../../lib/errors');

// App 逾時後重送同一則訊息時，伺服器可能仍在處理或已完成；在開始處理時就先登記，才不會重複呼叫模型、扣次數或寫入對話。
const CLIENT_ID = /^[A-Za-z0-9_-]{8,64}$/;
// 處理中的登記超過這個時間仍未完成，視為伺服器中途重啟，允許重新處理。
const STALE_MS = 2 * 60 * 1000;
const RETENTION_MS = 24 * 60 * 60 * 1000;

const inProgress = () => new HttpError(409, '這則訊息仍在處理中，請稍後再試', 'AI_REQUEST_IN_PROGRESS');

const parseClientId = (value) => {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'string' || !CLIENT_ID.test(value)) throw badRequest('請求內容不正確');
  return value;
};

const claim = async (userId, feature, clientId, attempt = 1) => {
  const now = new Date();
  try {
    const row = await prisma.ai_message_requests.create({
      data: { user_id: userId, feature, client_id: clientId, status: 'processing', created_at: now, updated_at: now }
    });
    return { row, existing: false };
  } catch (err) {
    if (err?.code !== 'P2002') throw err;
  }
  const row = await prisma.ai_message_requests.findFirst({ where: { user_id: userId, feature, client_id: clientId } });
  // 登記剛被失敗的第一次處理刪除時再搶一次。
  if (!row) return attempt < 2 ? claim(userId, feature, clientId, attempt + 1) : { row: null, existing: true };
  return { row, existing: true };
};

const restart = (row) => prisma.ai_message_requests.update({
  where: { request_id: row.request_id },
  data: { status: 'processing', user_message_id: null, reply_message_id: null, meta: null, updated_at: new Date() }
});

const release = (requestId) => prisma.ai_message_requests.deleteMany({ where: { request_id: requestId } })
  .catch((err) => console.error('[AI 訊息登記刪除失敗]:', err.message));

const parseMeta = (value) => {
  try {
    const meta = JSON.parse(String(value ?? '{}'));
    return meta && typeof meta === 'object' && !Array.isArray(meta) ? meta : {};
  } catch {
    return {};
  }
};

const NO_TICKET = Object.freeze({ complete: async () => {} });

const execute = async ({ userId, feature, clientId, replay }, run) => {
  let { row, existing } = await claim(userId, feature, clientId);
  if (!row) throw inProgress();
  if (existing) {
    if (row.status === 'done') {
      const result = await replay({ ...row, meta: parseMeta(row.meta) });
      if (result) return result;
    } else if (Date.now() - new Date(row.updated_at).getTime() < STALE_MS) {
      throw inProgress();
    }
    row = await restart(row);
  }
  const ticket = {
    complete: (tx, { userMessageId, replyMessageId, meta = null }) => tx.ai_message_requests.update({
      where: { request_id: row.request_id },
      data: {
        status: 'done',
        user_message_id: userMessageId,
        reply_message_id: replyMessageId,
        meta: meta ? JSON.stringify(meta) : null,
        updated_at: new Date()
      }
    })
  };
  try {
    return await run(ticket);
  } catch (err) {
    await release(row.request_id);
    throw err;
  }
};

const pending = new Map();

// run(ticket) 必須在寫入對話的同一個交易內呼叫 ticket.complete(tx, { userMessageId, replyMessageId, meta })，
// 否則寫入後、登記完成前中斷會讓重送再處理一次。meta 只放重建回應所需的模型輸出（例如推薦理由），不得放使用者原文。
// replay(row) 依登記的訊息編號重建回應；訊息已不存在時回傳 null，改為重新處理。
const once = ({ userId, feature, clientId, replay }, run) => {
  if (!clientId) return run(NO_TICKET);
  const key = `${userId}|${feature}|${clientId}`;
  if (pending.has(key)) return pending.get(key);
  const job = execute({ userId, feature, clientId, replay }, run).finally(() => pending.delete(key));
  pending.set(key, job);
  return job;
};

const clientIdsOf = async (userId, feature) => {
  const rows = await prisma.ai_message_requests.findMany({
    where: { user_id: userId, feature, status: 'done' },
    select: { client_id: true, user_message_id: true }
  });
  return new Map(rows.filter((r) => r.user_message_id).map((r) => [Number(r.user_message_id), r.client_id]));
};

const purgeExpired = async (now = new Date()) => {
  const { count } = await prisma.ai_message_requests.deleteMany({ where: { created_at: { lt: new Date(now.getTime() - RETENTION_MS) } } });
  return count;
};

module.exports = { CLIENT_ID, STALE_MS, RETENTION_MS, inProgress, parseClientId, once, clientIdsOf, purgeExpired };
