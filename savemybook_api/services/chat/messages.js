const prisma = require('../../lib/prisma');
const { badRequest, conflict, forbidden, notFound } = require('../../lib/errors');
const { hasColumn } = require('../../lib/schema-check');
const { placeholders } = require('../../lib/sql');
const { userBrief, coverImage } = require('../../lib/selects');
const reservations = require('../reservations');
const codec = require('./codec');
const controls = require('./controls');
const rooms = require('./rooms');
const schema = require('./schema');
const members = require('./members');
const aliases = require('./aliases');
const notice = require('./notice');
const transferRecords = require('./transfer-records');
const typing = require('./typing');

const RECENT_RECALL_MS = codec.RECALL_WINDOW_MS + 10 * 60 * 1000;
const RECENT_EDIT_MS = 20 * 60 * 1000;

const replySupported = () => hasColumn('chat_messages', 'reply_to_id');

const repliesFor = async (messages) => {
  if (messages.length === 0 || !(await replySupported())) return new Map();
  const ids = messages.map((m) => m.message_id);
  const links = await prisma.$queryRawUnsafe(
    `SELECT message_id, reply_to_id FROM chat_messages WHERE reply_to_id IS NOT NULL AND message_id IN (${placeholders(ids)})`,
    ...ids
  );
  if (links.length === 0) return new Map();

  const targets = await prisma.chat_messages.findMany({
    where: { message_id: { in: [...new Set(links.map((l) => Number(l.reply_to_id)))] } },
    include: { users: { select: userBrief } }
  });
  const byId = new Map(targets.map((t) => [t.message_id, t]));
  return new Map(links.map((l) => {
    const target = byId.get(Number(l.reply_to_id));
    return [Number(l.message_id), target ? codec.replyPreview(target) : { message_id: Number(l.reply_to_id), kind: 'deleted', preview: '' }];
  }));
};

const editsFor = async (messages, v2) => {
  if (messages.length === 0 || !v2) return new Map();
  const ids = messages.map((m) => m.message_id);
  const rows = await prisma.$queryRawUnsafe(
    `SELECT message_id, edited_at FROM chat_messages WHERE edited_at IS NOT NULL AND message_id IN (${placeholders(ids)})`,
    ...ids
  );
  return new Map(rows.map((r) => [Number(r.message_id), r.edited_at]));
};

const recentEdits = async (roomId) => {
  const rows = await prisma.$queryRaw`
    SELECT message_id, content, edited_at FROM chat_messages
    WHERE room_id = ${roomId} AND message_type = 'text' AND edited_at >= ${new Date(Date.now() - RECENT_EDIT_MS)}`;
  return rows.map((r) => ({ message_id: Number(r.message_id), body: r.content, edited_at: r.edited_at }));
};

const directState = async (room, roomId, myId, markRead) => {
  const partnerId = rooms.partnerIdOf(room, myId);
  const [, lastRead, reservationMap, relation, partnerStatus] = await Promise.all([
    markRead
      ? prisma.chat_messages.updateMany({
          where: { room_id: roomId, sender_id: { not: myId }, is_read: false },
          data: { is_read: true }
        })
      : Promise.resolve(null),
    prisma.chat_messages.findFirst({
      where: { room_id: roomId, sender_id: myId, is_read: true },
      orderBy: { message_id: 'desc' },
      select: { message_id: true }
    }),
    reservations.forUsers(myId, partnerId),
    controls.relation(myId, partnerId),
    prisma.users.findUnique({ where: { user_id: partnerId }, select: { is_active: true, is_blacklisted: true } })
  ]);
  const readUpto = lastRead?.message_id ?? 0;
  const visible = !relation.blocked && !relation.blockedBy;
  const partnerTyping = visible && typing.isTyping(roomId, partnerId);
  return {
    otherIds: [partnerId],
    reservationMap,
    isRead: (m) => m.is_read,
    meta: {
      read_upto: readUpto,
      my_last_read_message_id: null,
      members_read: [{ user_id: partnerId, last_read_message_id: readUpto }],
      partner_typing: partnerTyping,
      typing_user_ids: partnerTyping ? [partnerId] : [],
      blocked: relation.blocked,
      can_send: Boolean(partnerStatus?.is_active && !partnerStatus.is_blacklisted) && visible
    }
  };
};

// 回傳的 is_read 與 my_last_read_message_id 須為本次標記已讀之前的狀態，App 依此放置未讀分隔線。
const groupState = async (roomId, myId, markRead, messages) => {
  const current = await members.active(roomId);
  const myLastRead = current.find((m) => m.user_id === myId)?.last_read_message_id ?? 0;
  const others = current.filter((m) => m.user_id !== myId);
  const readUpto = others.reduce((max, m) => Math.max(max, m.last_read_message_id), 0);
  const newest = messages.reduce((max, m) => Math.max(max, m.message_id), 0);
  if (markRead && newest > myLastRead) await members.markRead(prisma, roomId, myId, newest);
  return {
    otherIds: others.map((m) => m.user_id),
    reservationMap: new Map(),
    memberCount: current.length,
    isRead: (m) => m.message_id <= (m.sender_id === myId ? readUpto : myLastRead),
    meta: {
      read_upto: readUpto,
      my_last_read_message_id: myLastRead,
      members_read: others.map((m) => ({ user_id: m.user_id, last_read_message_id: m.last_read_message_id })),
      partner_typing: false,
      typing_user_ids: others.filter((m) => typing.isTyping(roomId, m.user_id)).map((m) => m.user_id),
      blocked: false,
      can_send: true
    }
  };
};

const list = async (roomId, myId, { limit, beforeId, afterId, before, markRead }) => {
  const room = await rooms.findMine(roomId, myId, {
    users_chat_rooms_user_a_idTousers: { select: userBrief },
    users_chat_rooms_user_b_idTousers: { select: userBrief },
    books: { select: { book_id: true, title: true, price: true, book_images: coverImage } }
  });
  const group = rooms.isGroup(room);
  const v2 = await schema.isV2();
  const incremental = afterId != null;

  const where = { room_id: roomId };
  if (incremental) where.message_id = { gt: afterId };
  else if (beforeId) where.message_id = { lt: beforeId };
  else if (before) where.created_at = { lt: before };

  const messages = await prisma.chat_messages.findMany({
    where,
    orderBy: { message_id: incremental ? 'asc' : 'desc' },
    take: limit,
    include: { users: { select: userBrief } }
  });
  if (!incremental) messages.reverse();

  const [state, recalled, muted, replies, edits, edited, transfers, aliasMap] = await Promise.all([
    group ? groupState(roomId, myId, markRead, messages) : directState(room, roomId, myId, markRead),
    incremental
      ? prisma.chat_messages.findMany({
          where: {
            room_id: roomId,
            created_at: { gte: new Date(Date.now() - RECENT_RECALL_MS) },
            message_type: 'system',
            content: codec.PREFIX.recalled
          },
          select: { message_id: true }
        })
      : Promise.resolve([]),
    controls.mutedRoomIds(myId),
    repliesFor(messages),
    editsFor(messages, v2),
    incremental && v2 ? recentEdits(roomId) : Promise.resolve([]),
    transferRecords.forRoom(roomId, messages),
    aliases.mine(myId)
  ]);

  const relevant = new Set([...state.otherIds, ...messages.map((m) => m.sender_id)]);
  relevant.delete(myId);
  const partner = group ? null : rooms.partnerOf(room, myId);
  const partnerAlias = partner ? aliasMap.get(partner.user_id) ?? null : null;

  return {
    partner: partner ? { ...partner, alias: partnerAlias } : null,
    book: group ? null : room.books,
    meta: {
      ...state.meta,
      aliases: Object.fromEntries([...aliasMap].filter(([id]) => relevant.has(id)).map(([id, alias]) => [String(id), alias])),
      edited,
      muted: muted.has(roomId),
      recalled_ids: recalled.map((m) => m.message_id),
      has_more: !incremental && messages.length === limit,
      reservations: [...state.reservationMap.values()],
      transfers: transfers.recent,
      room: group
        ? { type: 'group', title: room.name, avatar_url: room.avatar_url, member_count: state.memberCount }
        : { type: 'direct', title: partnerAlias ?? partner?.nickname ?? null, avatar_url: partner?.avatar_url ?? null, member_count: 2 }
    },
    data: messages.map((m) => ({
      ...codec.shapeMessage(m, { reservations: state.reservationMap, transfers: transfers.byId }),
      is_read: state.isRead(m),
      edited_at: edits.get(m.message_id) ?? null,
      reply_to: replies.get(m.message_id) ?? null
    }))
  };
};

const send = async (roomId, myId, { messageType, content, preview, replyToId }) => {
  const room = await rooms.findMine(roomId, myId);
  let recipients;
  if (rooms.isGroup(room)) {
    recipients = (await members.active(roomId)).map((m) => m.user_id).filter((id) => id !== myId);
  } else {
    const partnerId = rooms.partnerIdOf(room, myId);
    const partner = await prisma.users.findUnique({
      where: { user_id: partnerId },
      select: { is_active: true, is_blacklisted: true, nickname: true }
    });
    if (!partner || !partner.is_active || partner.is_blacklisted) throw controls.recipientUnavailable();
    await controls.assertCanMessage(myId, partnerId);
    recipients = [partnerId];
  }

  const me = await prisma.users.findUnique({ where: { user_id: myId }, select: { nickname: true } });

  const replyTarget = replyToId && (await replySupported())
    ? await prisma.chat_messages.findUnique({ where: { message_id: replyToId }, include: { users: { select: userBrief } } })
    : null;
  if (replyToId && (await replySupported()) && replyTarget?.room_id !== roomId) throw badRequest('找不到要回覆的訊息');

  const message = await prisma.$transaction(async (tx) => {
    const created = await tx.chat_messages.create({
      data: { room_id: roomId, sender_id: myId, content, message_type: messageType },
      include: { users: { select: userBrief } }
    });
    if (replyTarget) {
      await tx.$executeRaw`UPDATE chat_messages SET reply_to_id = ${replyTarget.message_id} WHERE message_id = ${created.message_id}`;
    }

    await tx.chat_rooms.update({ where: { room_id: roomId }, data: { updated_at: new Date() } });

    await notice.notifyMembers(tx, {
      room, actor: { user_id: myId, nickname: me?.nickname ?? '' }, userIds: recipients, preview
    });

    return created;
  });

  typing.clear(roomId, myId);
  return {
    ...codec.shapeMessage(message),
    edited_at: null,
    reply_to: replyTarget ? codec.replyPreview(replyTarget) : null
  };
};

const setTyping = async (roomId, myId, isTyping) => {
  await rooms.findMine(roomId, myId);
  if (isTyping) typing.set(roomId, myId);
  else typing.clear(roomId, myId);
};

const ownMessage = async (roomId, messageId, myId, deniedMessage) => {
  const message = await prisma.chat_messages.findUnique({ where: { message_id: messageId } });
  if (!message || message.room_id !== roomId) throw notFound('找不到此訊息');
  if (message.sender_id !== myId) throw forbidden(deniedMessage);
  return message;
};

const recall = async (roomId, messageId, myId) => {
  if (await schema.isV2()) await rooms.findMine(roomId, myId);
  const message = await ownMessage(roomId, messageId, myId, '僅能收回自己傳送的訊息');

  const { kind } = codec.decode(message);
  if (kind === 'recalled') throw conflict('此訊息已收回');
  if (!['text', 'image', 'voice'].includes(kind)) throw badRequest('此類訊息無法收回');
  if (Date.now() - new Date(message.created_at).getTime() > codec.RECALL_WINDOW_MS) {
    throw badRequest('僅能收回 24 小時內傳送的訊息');
  }

  const updated = await prisma.chat_messages.update({
    where: { message_id: messageId },
    data: { content: codec.PREFIX.recalled, message_type: 'system' },
    include: { users: { select: userBrief } }
  });
  return codec.shapeMessage(updated);
};

const edit = async (roomId, messageId, myId, content) => {
  await schema.requireV2();
  const room = await rooms.findMine(roomId, myId);
  const message = await ownMessage(roomId, messageId, myId, '僅能編輯自己傳送的訊息');

  const { kind } = codec.decode(message);
  if (kind === 'recalled') throw conflict('此訊息已收回');
  if (kind !== 'text') throw badRequest('僅能編輯文字訊息');
  if (Date.now() - new Date(message.created_at).getTime() > codec.EDIT_WINDOW_MS) {
    throw badRequest('僅能編輯 15 分鐘內傳送的訊息', 'EDIT_WINDOW_PASSED');
  }
  if (!rooms.isGroup(room)) await controls.assertCanMessage(myId, rooms.partnerIdOf(room, myId));

  const now = new Date();
  const changed = await prisma.$executeRaw`
    UPDATE chat_messages SET content = ${content}, edited_at = ${now}
    WHERE message_id = ${messageId} AND sender_id = ${myId} AND message_type = 'text'`;
  if (changed === 0) throw conflict('此訊息已收回');

  const updated = await prisma.chat_messages.findUnique({
    where: { message_id: messageId },
    include: { users: { select: userBrief } }
  });
  const replies = await repliesFor([updated]);
  return { ...codec.shapeMessage(updated), edited_at: now, reply_to: replies.get(messageId) ?? null };
};

module.exports = { list, send, setTyping, recall, edit };
