const prisma = require('../../lib/prisma');
const publicId = require('../../lib/public-id');
const { placeholders } = require('../../lib/sql');
const codec = require('./codec');
const schema = require('./schema');
const history = require('./history');

const RECENT_LIMIT = 30;

const COLUMNS = 'transfer_id, room_id, message_id, kind, from_user_id, to_user_id, amount, note, status, created_at, responded_at, expires_at';

const isExpired = (row, now) => row.status === 'pending' && row.expires_at != null && new Date(row.expires_at) <= now;

const shape = (row, now = new Date()) => ({
  transfer_id: Number(row.transfer_id),
  transfer_no: publicId.encode('transfer', row.transfer_id),
  kind: row.kind,
  room_id: Number(row.room_id),
  message_id: row.message_id == null ? null : Number(row.message_id),
  from_user_id: Number(row.from_user_id),
  to_user_id: Number(row.to_user_id),
  amount: Number(row.amount),
  note: row.note ?? null,
  status: isExpired(row, now) ? 'expired' : row.status,
  created_at: row.created_at,
  responded_at: row.responded_at ?? null,
  expires_at: row.expires_at ?? null
});

const find = async (db, transferId) => {
  const rows = await (db ?? prisma).$queryRawUnsafe(`SELECT ${COLUMNS} FROM chat_transfers WHERE transfer_id = ?`, transferId);
  return rows[0] ?? null;
};

const insert = async (tx, { roomId, kind, fromUserId, toUserId, amount, note, status, createdAt, expiresAt = null }) => {
  await tx.$executeRaw`
    INSERT INTO chat_transfers (room_id, kind, from_user_id, to_user_id, amount, note, status, created_at, expires_at)
    VALUES (${roomId}, ${kind}, ${fromUserId}, ${toUserId}, ${amount}, ${note}, ${status}, ${createdAt}, ${expiresAt})`;
  const [row] = await tx.$queryRaw`SELECT LAST_INSERT_ID() AS id`;
  return Number(row.id);
};

const attachMessage = (tx, transferId, messageId) =>
  tx.$executeRaw`UPDATE chat_transfers SET message_id = ${messageId} WHERE transfer_id = ${transferId}`;

// 以 status = 'pending' 作為條件更新，同一筆請款並行付款時僅一筆會成功，另一筆取得 0 列。
const transition = (tx, transferId, status, now) => tx.$executeRaw`
  UPDATE chat_transfers SET status = ${status}, responded_at = ${now}
  WHERE transfer_id = ${transferId} AND status = 'pending' AND expires_at > ${now}`;

const forRoom = async (roomId, messages, floor) => {
  if (!(await schema.isV2())) return { recent: [], byId: new Map() };
  const now = new Date();
  const recent = (await prisma.$queryRawUnsafe(
    `SELECT ${COLUMNS} FROM chat_transfers WHERE room_id = ? ORDER BY transfer_id DESC LIMIT ${RECENT_LIMIT}`,
    roomId
  )).filter((r) => history.isVisible(floor, r));
  const known = new Set(recent.map((r) => Number(r.transfer_id)));
  const missing = [...new Set(messages
    .map(codec.decode)
    .filter((d) => d.kind === 'transfer')
    .map((d) => codec.transferIdOf(d.payload))
    .filter((id) => Number.isSafeInteger(id) && !known.has(id)))];
  const older = missing.length
    ? await prisma.$queryRawUnsafe(
        `SELECT ${COLUMNS} FROM chat_transfers WHERE room_id = ? AND transfer_id IN (${placeholders(missing)})`,
        roomId,
        ...missing
      )
    : [];
  return {
    recent: recent.map((r) => shape(r, now)),
    byId: new Map([...recent, ...older].map((r) => [Number(r.transfer_id), shape(r, now)]))
  };
};

const byIds = async (ids) => {
  if (ids.length === 0 || !(await schema.isV2())) return new Map();
  const rows = await prisma.$queryRawUnsafe(`SELECT ${COLUMNS} FROM chat_transfers WHERE transfer_id IN (${placeholders(ids)})`, ...ids);
  const now = new Date();
  return new Map(rows.map((r) => [Number(r.transfer_id), shape(r, now)]));
};

const expireDue = async () => {
  if (!(await schema.isV2())) return 0;
  return prisma.$executeRaw`UPDATE chat_transfers SET status = 'expired' WHERE status = 'pending' AND expires_at <= ${new Date()}`;
};

module.exports = { shape, find, insert, attachMessage, transition, forRoom, byIds, expireDue };
