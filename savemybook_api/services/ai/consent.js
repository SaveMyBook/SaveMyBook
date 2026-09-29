const prisma = require('../../lib/prisma');
const { HttpError } = require('../../lib/errors');
const legal = require('../legal');
const decisions = require('./decisions');

// AI 同意沿用法律文件的版本：隱私權政策重大更新（版本加一）後，先前的同意即失效。
const POLICY_DOC = 'privacy';
// 用戶端同意畫面的說明版本；說明內容變更時加一，舊版 App 顯示的舊說明不能換得新版政策的同意。
const NOTICE_VERSION = 4;
const CONVERSATION_RETENTION_DAYS = 90;
const DAY_MS = 24 * 60 * 60 * 1000;

const required = () => new HttpError(403, '使用 AI 功能前，請先同意將相關資料提供給 AI 服務商處理', 'AI_CONSENT_REQUIRED');
const noticeOutdated = () => new HttpError(409, '請更新 App 後再同意 AI 資料處理', 'AI_CONSENT_NOTICE_OUTDATED');

const stateOf = async (userId) => {
  if (!userId) return { granted: false, outdated: false };
  const rows = await prisma.$queryRaw`SELECT granted, policy_version FROM ai_consents WHERE user_id = ${userId}`;
  if (Number(rows[0]?.granted ?? 0) !== 1) return { granted: false, outdated: false };
  const current = Number(rows[0].policy_version ?? 0) >= (await legal.versionOf(POLICY_DOC));
  return { granted: current, outdated: !current };
};

const isGranted = async (userId) => (await stateOf(userId)).granted;

// 同意時用戶端顯示的說明版本，0 表示未同意或同意時尚未記錄。
const noticeVersionOf = async (userId) => {
  const rows = await prisma.$queryRaw`SELECT granted, notice_version FROM ai_consents WHERE user_id = ${userId}`;
  return Number(rows[0]?.granted ?? 0) === 1 ? Number(rows[0].notice_version ?? 0) : 0;
};

const assertGranted = async (userId) => {
  if (!(await isGranted(userId))) throw required();
};

const deleteAiData = async (db, userId) => {
  await db.$executeRaw`DELETE FROM ai_chat_sessions WHERE user_id = ${userId}`;
  await db.$executeRaw`DELETE FROM ai_support_sessions WHERE user_id = ${userId}`;
  await db.$executeRaw`DELETE FROM ai_recommendation_cache WHERE user_id = ${userId}`;
  await db.$executeRaw`DELETE FROM ai_message_requests WHERE user_id = ${userId}`;
  await db.$executeRaw`DELETE FROM ai_listing_suggestions WHERE user_id = ${userId}`;
  await decisions.deleteUser(db, userId);
};

const setGranted = async (userId, granted) => {
  const version = await legal.versionOf(POLICY_DOC);
  await prisma.$transaction(async (tx) => {
    await tx.$executeRaw`
      INSERT INTO ai_consents (user_id, granted, policy_version, notice_version, updated_at)
      VALUES (${userId}, ${granted ? 1 : 0}, ${version}, ${granted ? NOTICE_VERSION : 0}, ${new Date()})
      ON DUPLICATE KEY UPDATE granted = VALUES(granted), policy_version = VALUES(policy_version),
        notice_version = VALUES(notice_version), updated_at = VALUES(updated_at)`;
    if (!granted) await deleteAiData(tx, userId);
  });
};

// 以最後一則訊息的時間起算：結束或轉接對話會更新 updated_at，不能拿來判斷。對話訊息隨對話以外鍵連帶刪除。
const purgeExpired = async (now = new Date()) => {
  const cutoff = new Date(now.getTime() - CONVERSATION_RETENTION_DAYS * DAY_MS);
  const support = await prisma.$executeRaw`
    DELETE FROM ai_support_sessions WHERE created_at < ${cutoff}
      AND NOT EXISTS (SELECT 1 FROM ai_support_messages m WHERE m.session_id = ai_support_sessions.session_id AND m.created_at >= ${cutoff})`;
  const bookChat = await prisma.$executeRaw`
    DELETE FROM ai_chat_sessions WHERE created_at < ${cutoff}
      AND NOT EXISTS (SELECT 1 FROM ai_chat_messages m WHERE m.session_id = ai_chat_sessions.session_id AND m.created_at >= ${cutoff})`;
  return { support: Number(support), book_chat: Number(bookChat) };
};

const metaOf = (value) => {
  if (value == null) return null;
  try {
    const meta = JSON.parse(String(value));
    return meta && typeof meta === 'object' && !Array.isArray(meta) ? meta : null;
  } catch {
    return null;
  }
};

const exportMessage = (m) => ({
  role: m.role,
  content: m.content,
  ...(m.role === 'assistant' && { meta: metaOf(m.meta) }),
  ...(m.feedback && { feedback: { rating: m.feedback, reason: m.feedback_reason ?? null } }),
  created_at: m.created_at
});

const bookChatSessions = async (userId) => {
  const [sessions, messages] = await Promise.all([
    prisma.$queryRaw`
      SELECT session_id, status, created_at, updated_at FROM ai_chat_sessions WHERE user_id = ${userId} ORDER BY session_id ASC`,
    prisma.$queryRaw`
      SELECT m.session_id, m.role, m.content, m.meta, m.feedback, m.feedback_reason, m.created_at FROM ai_chat_messages m
      JOIN ai_chat_sessions s ON s.session_id = m.session_id
      WHERE s.user_id = ${userId} ORDER BY m.message_id ASC`
  ]);
  return sessions.map((s) => ({
    status: s.status,
    created_at: s.created_at,
    updated_at: s.updated_at,
    messages: messages.filter((m) => Number(m.session_id) === Number(s.session_id)).map(exportMessage)
  }));
};

const exportUser = async (userId) => {
  const [consents, sessions, messages, cache, decisionLogs] = await Promise.all([
    prisma.$queryRaw`SELECT granted, policy_version, notice_version, updated_at FROM ai_consents WHERE user_id = ${userId}`,
    prisma.$queryRaw`
      SELECT session_id, status, created_at, updated_at FROM ai_support_sessions
      WHERE user_id = ${userId} ORDER BY session_id ASC`,
    prisma.$queryRaw`
      SELECT m.session_id, m.role, m.content, m.meta, m.feedback, m.feedback_reason, m.created_at FROM ai_support_messages m
      JOIN ai_support_sessions s ON s.session_id = m.session_id
      WHERE s.user_id = ${userId} ORDER BY m.message_id ASC`,
    prisma.$queryRaw`SELECT payload, created_at FROM ai_recommendation_cache WHERE user_id = ${userId}`,
    decisions.exportUser(userId)
  ]);

  let recommendations = null;
  if (cache[0]) {
    try {
      recommendations = { items: JSON.parse(String(cache[0].payload)).items ?? [], created_at: cache[0].created_at };
    } catch {
      recommendations = null;
    }
  }
  return {
    consent: consents[0]
      ? {
        granted: Number(consents[0].granted) === 1,
        policy_version: Number(consents[0].policy_version ?? 0),
        notice_version: Number(consents[0].notice_version ?? 0),
        updated_at: consents[0].updated_at
      }
      : null,
    book_chat_sessions: await bookChatSessions(userId),
    support_sessions: sessions.map((s) => ({
      status: s.status,
      created_at: s.created_at,
      updated_at: s.updated_at,
      messages: messages.filter((m) => Number(m.session_id) === Number(s.session_id)).map(exportMessage)
    })),
    recommendations,
    decision_logs: decisionLogs
  };
};

const purgeUser = async (tx, userId) => {
  await deleteAiData(tx, userId);
  await tx.$executeRaw`DELETE FROM ai_listing_tokens WHERE user_id = ${userId}`;
  await tx.$executeRaw`DELETE FROM ai_consents WHERE user_id = ${userId}`;
};

module.exports = {
  POLICY_DOC, NOTICE_VERSION, CONVERSATION_RETENTION_DAYS, required, noticeOutdated, stateOf, isGranted, noticeVersionOf, assertGranted, setGranted,
  purgeExpired, exportUser, purgeUser
};
