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
const history = require('./history');
const mentionStore = require('./mentions');
const riskService = require('./risk');
const notificationCenter = require('../notifications');
const realtime = require('../realtime');

const RECENT_RECALL_MS = codec.RECALL_WINDOW_MS + 10 * 60 * 1000;
const RECENT_EDIT_MS = 20 * 60 * 1000;

const replySupported = () => hasColumn('chat_messages', 'reply_to_id');

const repliesFor = async (messages, floor) => {
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
    return [Number(l.message_id), target && history.isVisible(floor, target)
      ? codec.replyPreview(target)
      : { message_id: Number(l.reply_to_id), kind: 'deleted', preview: '' }];
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

const recentEdits = async (roomId, floor, v3) => {
  const since = new Date(Date.now() - RECENT_EDIT_MS);
  const rows = v3
    ? await prisma.$queryRaw`
        SELECT message_id, content, edited_at, created_at, mentions FROM chat_messages
        WHERE room_id = ${roomId} AND message_type = 'text' AND edited_at >= ${since}`
    : await prisma.$queryRaw`
        SELECT message_id, content, edited_at, created_at FROM chat_messages
        WHERE room_id = ${roomId} AND message_type = 'text' AND edited_at >= ${since}`;
  return rows
    .filter((r) => history.isVisible(floor, r))
    .map((r) => ({
      message_id: Number(r.message_id), body: r.content, edited_at: r.edited_at, mentions: codec.toMentions(r.mentions)
    }));
};

const directState = async (room, roomId, myId, markRead) => {
  const partnerId = rooms.partnerIdOf(room, myId);
  const [marked, lastRead, reservationMap, relation, partnerStatus] = await Promise.all([
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
  if (marked?.count > 0) realtime.touchRoom(roomId, { exceptUserId: myId });
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
  if (markRead && newest > myLastRead) {
    await members.markRead(prisma, roomId, myId, newest);
    realtime.touchRoom(roomId, { exceptUserId: myId });
  }
  return {
    otherIds: others.map((m) => m.user_id),
    nicknames: new Map(current.filter((m) => m.group_nickname).map((m) => [m.user_id, m.group_nickname])),
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
  const floor = room.history;
  const v2 = await schema.isV2();
  const v3 = v2 && (await schema.isV3());
  const incremental = afterId != null;

  const where = { room_id: roomId };
  if (incremental) where.message_id = { gt: afterId };
  else if (beforeId) where.message_id = { lt: beforeId };
  else if (before) where.created_at = { lt: before };

  const messages = await prisma.chat_messages.findMany({
    where: history.applyToWhere(where, floor),
    orderBy: { message_id: incremental ? 'asc' : 'desc' },
    take: limit,
    include: { users: { select: userBrief } }
  });
  if (!incremental) messages.reverse();

  const [state, recalled, muted, replies, edits, edited, transfers, aliasMap, mentionMap, risks] = await Promise.all([
    group ? groupState(roomId, myId, markRead, messages) : directState(room, roomId, myId, markRead),
    incremental
      ? prisma.chat_messages.findMany({
          where: history.applyToWhere({
            room_id: roomId,
            created_at: { gte: new Date(Date.now() - RECENT_RECALL_MS) },
            message_type: 'system',
            content: codec.PREFIX.recalled
          }, floor),
          select: { message_id: true }
        })
      : Promise.resolve([]),
    controls.mutedRoomIds(myId),
    repliesFor(messages, floor),
    editsFor(messages, v2),
    incremental && v2 ? recentEdits(roomId, floor, v3) : Promise.resolve([]),
    transferRecords.forRoom(roomId, messages, floor),
    aliases.mine(myId),
    v3 ? mentionStore.forMessages(messages) : new Map(),
    riskService.forMessages(messages, myId)
  ]);
  const riskBanner = await riskService.bannerFor(roomId, myId, risks);
  if (markRead) await notificationCenter.clearChatRoom(myId, roomId);

  const relevant = new Set([...state.otherIds, ...messages.map((m) => m.sender_id)]);
  relevant.delete(myId);
  const partner = group ? null : rooms.partnerOf(room, myId);
  const partnerAlias = partner ? aliasMap.get(partner.user_id) ?? null : null;

  return {
    partner: partner ? { ...partner, alias: partnerAlias } : null,
    book: group ? null : room.books,
    meta: {
      ...state.meta,
      aliases: Object.fromEntries([...(group ? state.nicknames : aliasMap)]
        .filter(([id]) => relevant.has(id) || (group && id === myId))
        .map(([id, alias]) => [String(id), alias])),
      edited,
      muted: muted.has(roomId),
      recalled_ids: recalled.map((m) => m.message_id),
      risk_banner: riskBanner,
      has_more: !incremental && messages.length === limit,
      reservations: [...state.reservationMap.values()],
      transfers: transfers.recent,
      room: group
        ? { type: 'group', title: room.name, avatar_url: room.avatar_url, member_count: state.memberCount }
        : { type: 'direct', title: partnerAlias ?? partner?.nickname ?? null, avatar_url: partner?.avatar_url ?? null, member_count: 2 }
    },
    data: messages.map((m) => ({
      ...codec.shapeMessage(
        { ...m, mentions: mentionMap.get(m.message_id) ?? m.mentions },
        { reservations: state.reservationMap, transfers: transfers.byId }
      ),
      is_read: state.isRead(m),
      edited_at: edits.get(m.message_id) ?? null,
      reply_to: replies.get(m.message_id) ?? null,
      risk: risks.get(m.message_id) ?? null
    }))
  };
};

const send = async (roomId, myId, { messageType, content, preview, replyToId, mentions = [], confirmRisk = false }) => {
  const room = await rooms.findMine(roomId, myId);
  if (mentions.length > 0) {
    if (!rooms.isGroup(room)) throw mentionStore.directOnly();
    await schema.requireV3();
  }

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
  const mentionedIds = mentionStore.targetsOf(mentions, recipients);

  const me = await prisma.users.findUnique({ where: { user_id: myId }, select: { nickname: true } });
  const senderName = rooms.isGroup(room)
    ? (await members.groupNicknames([roomId])).get(`${roomId}:${myId}`) ?? me?.nickname ?? ''
    : me?.nickname ?? '';

  const replyTarget = replyToId && (await replySupported())
    ? await prisma.chat_messages.findUnique({ where: { message_id: replyToId }, include: { users: { select: userBrief } } })
    : null;
  if (replyToId && (await replySupported()) && (replyTarget?.room_id !== roomId || !history.isVisible(room.history, replyTarget))) {
    throw badRequest('找不到要回覆的訊息');
  }

  const risk = messageType === 'text' ? await riskService.assess({ roomId, senderId: myId, text: content }) : null;
  if (risk && !confirmRisk) {
    const pending = riskService.confirmRequired(risk.categories);
    if (pending) throw pending;
  }

  const message = await prisma.$transaction(async (tx) => {
    const created = await tx.chat_messages.create({
      data: { room_id: roomId, sender_id: myId, content, message_type: messageType },
      include: { users: { select: userBrief } }
    });
    if (replyTarget) {
      await tx.$executeRaw`UPDATE chat_messages SET reply_to_id = ${replyTarget.message_id} WHERE message_id = ${created.message_id}`;
    }
    if (mentions.length > 0) {
      await mentionStore.save(tx, { messageId: created.message_id, roomId, mentions, userIds: mentionedIds });
    }

    await tx.chat_rooms.update({ where: { room_id: roomId }, data: { updated_at: new Date() } });
    realtime.touchRoom(roomId, { exceptUserId: myId });

    await notice.notifyMembers(tx, {
      room, actor: { user_id: myId, nickname: senderName }, userIds: recipients, preview, mentionedIds
    });

    return created;
  });

  typing.clear(roomId, myId);
  await riskService.record({ messageId: message.message_id, roomId, senderId: myId, risk })
    .catch((err) => console.error('[聊天風險紀錄失敗]:', err.message));
  return {
    ...codec.shapeMessage({ ...message, mentions }),
    edited_at: null,
    reply_to: replyTarget ? codec.replyPreview(replyTarget) : null
  };
};

const setTyping = async (roomId, myId, isTyping) => {
  await rooms.findMine(roomId, myId);
  if (isTyping) typing.set(roomId, myId);
  else typing.clear(roomId, myId);
  realtime.emitTyping(roomId, myId, isTyping).catch(() => {});
};

const ownMessage = async (roomId, messageId, myId, deniedMessage, floor) => {
  const message = await prisma.chat_messages.findUnique({ where: { message_id: messageId } });
  if (!message || message.room_id !== roomId || !history.isVisible(floor, message)) throw notFound('找不到此訊息');
  if (message.sender_id !== myId) throw forbidden(deniedMessage);
  return message;
};

const recall = async (roomId, messageId, myId) => {
  const room = (await schema.isV2()) ? await rooms.findMine(roomId, myId) : null;
  const message = await ownMessage(roomId, messageId, myId, '僅能收回自己傳送的訊息', room?.history);

  const { kind } = codec.decode(message);
  if (kind === 'recalled') throw conflict('此訊息已收回');
  if (!codec.RECALLABLE_KINDS.includes(kind)) throw badRequest('此類訊息無法收回');
  if (Date.now() - new Date(message.created_at).getTime() > codec.RECALL_WINDOW_MS) {
    throw badRequest('僅能收回 1 小時內傳送的訊息', 'RECALL_WINDOW_PASSED');
  }

  const clearMentions = kind === 'text' && (await schema.isV3());
  const updated = await prisma.$transaction(async (tx) => {
    const row = await tx.chat_messages.update({
      where: { message_id: messageId },
      data: { content: codec.PREFIX.recalled, message_type: 'system' },
      include: { users: { select: userBrief } }
    });
    if (clearMentions) await mentionStore.clear(tx, messageId);
    return row;
  });
  realtime.touchRoom(roomId, { exceptUserId: myId });
  return codec.shapeMessage(updated);
};

const edit = async (roomId, messageId, myId, { content, mentions = [], confirmRisk = false }) => {
  await schema.requireV2();
  const room = await rooms.findMine(roomId, myId);
  const message = await ownMessage(roomId, messageId, myId, '僅能編輯自己傳送的訊息', room.history);

  const { kind } = codec.decode(message);
  if (kind === 'recalled') throw conflict('此訊息已收回');
  if (kind !== 'text') throw badRequest('僅能編輯文字訊息');
  if (Date.now() - new Date(message.created_at).getTime() > codec.EDIT_WINDOW_MS) {
    throw badRequest('僅能編輯 15 分鐘內傳送的訊息', 'EDIT_WINDOW_PASSED');
  }
  if (!rooms.isGroup(room)) await controls.assertCanMessage(myId, rooms.partnerIdOf(room, myId));

  if (mentions.length > 0) {
    if (!rooms.isGroup(room)) throw mentionStore.directOnly();
    await schema.requireV3();
  }
  const risk = riskService.contentRisk(content);
  if (risk && !confirmRisk && !riskService.contentRisk(message.content)) {
    const pending = riskService.confirmRequired(risk.categories);
    if (pending) throw pending;
  }

  const v3 = await schema.isV3();
  const mentionedIds = mentions.length > 0
    ? mentionStore.targetsOf(mentions, (await members.active(roomId)).map((m) => m.user_id).filter((id) => id !== myId))
    : [];

  const now = new Date();
  const stored = mentions.length > 0 ? JSON.stringify(mentions) : null;
  const updated = await prisma.$transaction(async (tx) => {
    const changed = v3
      ? await tx.$executeRaw`
          UPDATE chat_messages SET content = ${content}, edited_at = ${now}, mentions = ${stored}
          WHERE message_id = ${messageId} AND sender_id = ${myId} AND message_type = 'text'`
      : await tx.$executeRaw`
          UPDATE chat_messages SET content = ${content}, edited_at = ${now}
          WHERE message_id = ${messageId} AND sender_id = ${myId} AND message_type = 'text'`;
    if (Number(changed) === 0) throw conflict('此訊息已收回');
    if (v3) await mentionStore.replaceRows(tx, { messageId, roomId, userIds: mentionedIds });
    return tx.chat_messages.findUnique({
      where: { message_id: messageId },
      include: { users: { select: userBrief } }
    });
  });
  realtime.touchRoom(roomId, { exceptUserId: myId });
  await riskService.record({ messageId, roomId, senderId: myId, risk, replace: true })
    .catch((err) => console.error('[聊天風險紀錄失敗]:', err.message));
  const replies = await repliesFor([updated], room.history);
  return { ...codec.shapeMessage({ ...updated, mentions }), edited_at: now, reply_to: replies.get(messageId) ?? null };
};

module.exports = { list, send, setTyping, recall, edit };
