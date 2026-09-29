const prisma = require('../lib/prisma');
const { notifyMany } = require('./notify');
const { adminIdsWith } = require('./admin-permissions');

const detailText = (detail) => {
  if (detail === null || detail === undefined) return null;
  return typeof detail === 'string' ? detail : JSON.stringify(detail);
};

const parseDetail = (text) => {
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
};

const recordEvent = (db, {
  cabinetId, deviceId = null, sessionId = null, orderId = null, bookId = null, type, channel = null, detail = null,
  source = 'server', actorId = null, occurredAt = new Date(), eventKey = null, result = null,
  claimedAt = null, processedAt = null, receivedAt = new Date()
}) => (db ?? prisma).cabinet_events.create({
  data: {
    cabinet_id: Number(cabinetId),
    device_id: deviceId,
    session_id: sessionId,
    order_id: orderId,
    book_id: bookId,
    event_key: eventKey,
    source,
    type,
    lock_channel: channel ?? null,
    actor_id: actorId,
    detail: detailText(detail),
    result,
    occurred_at: occurredAt,
    received_at: receivedAt,
    claimed_at: claimedAt,
    processed_at: processedAt
  }
});

const notifyAdmins = async (db, cabinet, { title, content }) => {
  const cabinetId = typeof cabinet === 'object' && cabinet !== null ? cabinet.cabinet_id : cabinet;
  const adminIds = await adminIdsWith('cabinets');
  if (adminIds.length === 0) return 0;
  return notifyMany(db, adminIds, { title, content, relatedId: Number(cabinetId), relatedType: 'cabinet' });
};

module.exports = { recordEvent, notifyAdmins, parseDetail, detailText };
