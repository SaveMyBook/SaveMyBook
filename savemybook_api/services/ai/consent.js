const prisma = require('../../lib/prisma');
const { HttpError } = require('../../lib/errors');

const required = () => new HttpError(403, '使用 AI 功能前，請先同意將相關資料提供給 AI 服務商處理', 'AI_CONSENT_REQUIRED');

const isGranted = async (userId) => {
  if (!userId) return false;
  const rows = await prisma.$queryRaw`SELECT granted FROM ai_consents WHERE user_id = ${userId}`;
  return Number(rows[0]?.granted ?? 0) === 1;
};

const assertGranted = async (userId) => {
  if (!(await isGranted(userId))) throw required();
};

const setGranted = async (userId, granted) => {
  const now = new Date();
  await prisma.$executeRaw`
    INSERT INTO ai_consents (user_id, granted, updated_at) VALUES (${userId}, ${granted ? 1 : 0}, ${now})
    ON DUPLICATE KEY UPDATE granted = VALUES(granted), updated_at = VALUES(updated_at)`;
  if (!granted) await prisma.$executeRaw`DELETE FROM ai_recommendation_cache WHERE user_id = ${userId}`;
};

const bookChatSessions = async (userId) => {
  const [sessions, messages] = await Promise.all([
    prisma.$queryRaw`
      SELECT session_id, status, created_at, updated_at FROM ai_chat_sessions WHERE user_id = ${userId} ORDER BY session_id ASC`,
    prisma.$queryRaw`
      SELECT m.session_id, m.role, m.content, m.created_at FROM ai_chat_messages m
      JOIN ai_chat_sessions s ON s.session_id = m.session_id
      WHERE s.user_id = ${userId} ORDER BY m.message_id ASC`
  ]);
  return sessions.map((s) => ({
    status: s.status,
    created_at: s.created_at,
    updated_at: s.updated_at,
    messages: messages
      .filter((m) => Number(m.session_id) === Number(s.session_id))
      .map((m) => ({ role: m.role, content: m.content, created_at: m.created_at }))
  }));
};

const exportUser = async (userId) => {
  const [consents, sessions, messages, cache] = await Promise.all([
    prisma.$queryRaw`SELECT granted, updated_at FROM ai_consents WHERE user_id = ${userId}`,
    prisma.$queryRaw`
      SELECT session_id, status, created_at, updated_at FROM ai_support_sessions
      WHERE user_id = ${userId} ORDER BY session_id ASC`,
    prisma.$queryRaw`
      SELECT m.session_id, m.role, m.content, m.created_at FROM ai_support_messages m
      JOIN ai_support_sessions s ON s.session_id = m.session_id
      WHERE s.user_id = ${userId} ORDER BY m.message_id ASC`,
    prisma.$queryRaw`SELECT payload, created_at FROM ai_recommendation_cache WHERE user_id = ${userId}`
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
    consent: consents[0] ? { granted: Number(consents[0].granted) === 1, updated_at: consents[0].updated_at } : null,
    book_chat_sessions: await bookChatSessions(userId),
    support_sessions: sessions.map((s) => ({
      status: s.status,
      created_at: s.created_at,
      updated_at: s.updated_at,
      messages: messages
        .filter((m) => Number(m.session_id) === Number(s.session_id))
        .map((m) => ({ role: m.role, content: m.content, created_at: m.created_at }))
    })),
    recommendations
  };
};

const purgeUser = async (tx, userId) => {
  await tx.$executeRaw`DELETE FROM ai_chat_sessions WHERE user_id = ${userId}`;
  await tx.$executeRaw`DELETE FROM ai_support_sessions WHERE user_id = ${userId}`;
  await tx.$executeRaw`DELETE FROM ai_recommendation_cache WHERE user_id = ${userId}`;
  await tx.$executeRaw`DELETE FROM ai_consents WHERE user_id = ${userId}`;
};

module.exports = { required, isGranted, assertGranted, setGranted, exportUser, purgeUser };
