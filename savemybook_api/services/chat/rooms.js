const prisma = require('../../lib/prisma');
const { badRequest, forbidden, notFound } = require('../../lib/errors');
const { userBrief, userName, coverImage } = require('../../lib/selects');
const codec = require('./codec');
const controls = require('./controls');
const schema = require('./schema');
const members = require('./members');
const history = require('./history');
const aliases = require('./aliases');
const transferRecords = require('./transfer-records');

const MAX_PINS = 10;

const partnerOf = (room, myId) => (room.user_a_id === myId
  ? room.users_chat_rooms_user_b_idTousers
  : room.users_chat_rooms_user_a_idTousers);

const partnerIdOf = (room, myId) => (room.user_a_id === myId ? room.user_b_id : room.user_a_id);

const isGroup = (room) => room?.room_type === 'group';

const myRooms = (myId) => ({ OR: [{ user_a_id: myId }, { user_b_id: myId }] });

const between = (db, a, b) => {
  const [userA, userB] = a < b ? [a, b] : [b, a];
  return db.chat_rooms.findFirst({ where: { user_a_id: userA, user_b_id: userB }, orderBy: { updated_at: 'desc' } });
};

const DIRECT = { room_type: 'direct', name: null, avatar_url: null, created_by: null, my_role: null, history: null };

const membershipOf = async (roomId, userId, v3) => {
  const [row] = v3
    ? await prisma.$queryRaw`
        SELECT r.room_type, r.name, r.avatar_url, r.created_by, m.role, m.left_at, m.joined_at, m.history_from_id
        FROM chat_rooms r
        LEFT JOIN chat_room_members m ON m.room_id = r.room_id AND m.user_id = ${userId}
        WHERE r.room_id = ${roomId}`
    : await prisma.$queryRaw`
        SELECT r.room_type, r.name, r.avatar_url, r.created_by, m.role, m.left_at, m.joined_at
        FROM chat_rooms r
        LEFT JOIN chat_room_members m ON m.room_id = r.room_id AND m.user_id = ${userId}
        WHERE r.room_id = ${roomId}`;
  return row ?? null;
};

const findMine = async (roomId, myId, include) => {
  const room = await prisma.chat_rooms.findUnique({ where: { room_id: roomId }, include });
  if (!room) throw notFound('找不到該聊天室');

  if (!(await schema.isV2())) {
    if (room.user_a_id !== myId && room.user_b_id !== myId) throw forbidden('存取被拒');
    return { ...room, ...DIRECT };
  }

  const v3 = await schema.isV3();
  const row = await membershipOf(roomId, myId, v3);
  if (!row?.role || row.left_at) throw forbidden('存取被拒');
  const group = row.room_type === 'group';
  return {
    ...room,
    room_type: group ? 'group' : 'direct',
    name: group ? row.name : null,
    avatar_url: group ? row.avatar_url ?? null : null,
    created_by: row.created_by == null ? null : Number(row.created_by),
    my_role: group ? row.role : null,
    history: group ? history.floorOf(row, v3) : null
  };
};

const findMessageable = async (roomId, myId) => {
  const room = await findMine(roomId, myId);
  if (isGroup(room)) throw badRequest('群組聊天室不支援預約');
  await controls.assertCanMessage(myId, partnerIdOf(room, myId));
  return room;
};

const typeOf = async (roomId) => {
  if (!(await schema.isV2())) return 'direct';
  const [row] = await prisma.$queryRaw`SELECT room_type FROM chat_rooms WHERE room_id = ${roomId}`;
  return row?.room_type ?? null;
};

const summaryOf = async (roomId) => {
  const [row] = await prisma.$queryRaw`SELECT room_id, room_type, name FROM chat_rooms WHERE room_id = ${roomId}`;
  return row ? { room_id: Number(row.room_id), room_type: row.room_type, name: row.name } : null;
};

const memberRooms = (myId, v3) => (v3
  ? prisma.$queryRaw`
      SELECT r.room_id, r.room_type, r.name, r.avatar_url, p.pinned_at, m.joined_at, m.history_from_id,
        (SELECT COUNT(*) FROM chat_room_members c WHERE c.room_id = r.room_id AND c.left_at IS NULL) AS member_count,
        IF(r.room_type = 'group',
          (SELECT COUNT(*) FROM chat_messages x
           WHERE x.room_id = r.room_id AND x.message_id > m.last_read_message_id AND x.message_id >= m.history_from_id
             AND x.sender_id <> ${myId}),
          0) AS group_unread,
        EXISTS(SELECT 1 FROM chat_mentions cm
          WHERE cm.user_id = m.user_id AND cm.room_id = r.room_id
            AND cm.message_id > m.last_read_message_id AND cm.message_id >= m.history_from_id) AS mention_unread
      FROM chat_room_members m
      JOIN chat_rooms r ON r.room_id = m.room_id
      LEFT JOIN chat_room_pins p ON p.user_id = m.user_id AND p.room_id = m.room_id
      WHERE m.user_id = ${myId} AND m.left_at IS NULL`
  : prisma.$queryRaw`
      SELECT r.room_id, r.room_type, r.name, r.avatar_url, p.pinned_at, m.joined_at,
        (SELECT COUNT(*) FROM chat_room_members c WHERE c.room_id = r.room_id AND c.left_at IS NULL) AS member_count,
        IF(r.room_type = 'group',
          (SELECT COUNT(*) FROM chat_messages x
           WHERE x.room_id = r.room_id AND x.message_id > m.last_read_message_id
             AND x.created_at >= m.joined_at - INTERVAL 1 SECOND AND x.sender_id <> ${myId}),
          0) AS group_unread
      FROM chat_room_members m
      JOIN chat_rooms r ON r.room_id = m.room_id
      LEFT JOIN chat_room_pins p ON p.user_id = m.user_id AND p.room_id = m.room_id
      WHERE m.user_id = ${myId} AND m.left_at IS NULL`);

const shapeRoom = (room, myId, { meta, muted, blocked, aliasMap, transfers, v3 }) => {
  const group = meta?.room_type === 'group';
  const newest = room.chat_messages[0] ?? null;
  const last = group && !history.isVisible(history.floorOf(meta, v3), newest) ? null : newest;
  const partner = group ? null : partnerOf(room, myId);
  const alias = partner ? aliasMap.get(partner.user_id) ?? null : null;
  const shaped = last ? codec.shapeMessage(last, { transfers }) : null;

  return {
    room_id: room.room_id,
    type: group ? 'group' : 'direct',
    title: group ? meta.name : alias ?? partner?.nickname ?? null,
    avatar_url: group ? meta.avatar_url ?? null : partner?.avatar_url ?? null,
    partner: partner ? { ...partner, alias } : null,
    member_count: group ? Number(meta.member_count) : 2,
    pinned: Boolean(meta?.pinned_at),
    pinned_at: meta?.pinned_at ?? null,
    muted: muted.has(room.room_id),
    blocked: !group && blocked.has(partnerIdOf(room, myId)),
    last_message: last
      ? {
          content: last.content,
          message_type: last.message_type,
          kind: shaped.kind,
          preview: codec.previewOf(last, { transfers }),
          payload: shaped.payload,
          sender_id: last.sender_id,
          sender_name: aliasMap.get(last.sender_id) ?? last.users?.nickname ?? null,
          is_read: last.is_read,
          created_at: last.created_at
        }
      : null,
    unread_count: group ? Number(meta.group_unread) : room._count?.chat_messages ?? 0,
    mention_unread: group && Boolean(Number(meta.mention_unread ?? 0)),
    updated_at: room.updated_at
  };
};

const byPinThenActivity = (a, b) => {
  if (a.pinned !== b.pinned) return a.pinned ? -1 : 1;
  const key = a.pinned ? 'pinned_at' : 'updated_at';
  return new Date(b[key]).getTime() - new Date(a[key]).getTime();
};

const list = async (myId) => {
  const v2 = await schema.isV2();
  const v3 = v2 && (await schema.isV3());
  const metaRows = v2 ? await memberRooms(myId, v3) : [];
  if (v2 && metaRows.length === 0) return [];
  const metaById = new Map(metaRows.map((r) => [Number(r.room_id), r]));

  const [rooms, muted, blocked, aliasMap] = await Promise.all([prisma.chat_rooms.findMany({
    where: v2 ? { room_id: { in: [...metaById.keys()] } } : myRooms(myId),
    orderBy: { updated_at: 'desc' },
    include: {
      users_chat_rooms_user_a_idTousers: { select: userBrief },
      users_chat_rooms_user_b_idTousers: { select: userBrief },
      books: { select: { book_id: true, title: true, book_images: coverImage } },
      chat_messages: { orderBy: { message_id: 'desc' }, take: 1, include: { users: { select: userName } } },
      _count: { select: { chat_messages: { where: { is_read: false, sender_id: { not: myId } } } } }
    }
  }), controls.mutedRoomIds(myId), controls.blockedUserIds(myId), aliases.mine(myId)]);

  const transferIds = rooms
    .map((r) => r.chat_messages[0])
    .filter(Boolean)
    .map(codec.decode)
    .filter((d) => d.kind === 'transfer')
    .map((d) => codec.transferIdOf(d.payload))
    .filter(Number.isSafeInteger);
  const transfers = await transferRecords.byIds([...new Set(transferIds)]);

  return rooms
    .map((r) => shapeRoom(r, myId, { meta: metaById.get(r.room_id), muted, blocked, aliasMap, transfers, v3 }))
    .sort(byPinThenActivity);
};

const pinnedAtOf = async (myId, roomId) => {
  const [row] = await prisma.$queryRaw`SELECT pinned_at FROM chat_room_pins WHERE user_id = ${myId} AND room_id = ${roomId}`;
  return row?.pinned_at ?? null;
};

const detail = async (roomId, myId) => {
  const room = await findMine(roomId, myId, {
    users_chat_rooms_user_a_idTousers: { select: userBrief },
    users_chat_rooms_user_b_idTousers: { select: userBrief }
  });
  const group = isGroup(room);
  const v2 = await schema.isV2();
  const [memberRows, muted, pinnedAt, aliasMap, relation] = await Promise.all([
    group ? members.active(roomId) : [],
    controls.mutedRoomIds(myId),
    v2 ? pinnedAtOf(myId, roomId) : null,
    aliases.mine(myId),
    group ? { blocked: false } : controls.relation(myId, partnerIdOf(room, myId))
  ]);
  const aliasOf = (userId) => (userId === myId ? null : aliasMap.get(userId) ?? null);

  const people = group
    ? memberRows.map((m) => ({
        user_id: m.user_id, nickname: m.nickname, avatar_url: m.avatar_url, alias: aliasOf(m.user_id), role: m.role, joined_at: m.joined_at
      }))
    : [room.users_chat_rooms_user_a_idTousers, room.users_chat_rooms_user_b_idTousers].map((u) => ({
        ...u, alias: aliasOf(u.user_id), role: 'member', joined_at: room.created_at
      }));
  const partner = group ? null : people.find((p) => p.user_id !== myId);

  return {
    room_id: room.room_id,
    type: room.room_type,
    name: room.name,
    title: group ? room.name : partner?.alias ?? partner?.nickname ?? null,
    avatar_url: group ? room.avatar_url : partner?.avatar_url ?? null,
    created_by: room.created_by,
    my_role: room.my_role,
    member_count: people.length,
    members: people,
    partner: partner ? { user_id: partner.user_id, nickname: partner.nickname, avatar_url: partner.avatar_url, alias: partner.alias } : null,
    muted: muted.has(roomId),
    blocked: relation.blocked,
    pinned: Boolean(pinnedAt),
    pinned_at: pinnedAt
  };
};

const unreadCount = async (myId) => {
  if (!(await schema.isV2())) {
    return prisma.chat_messages.count({
      where: { is_read: false, sender_id: { not: myId }, chat_rooms: myRooms(myId) }
    });
  }
  const [row] = (await schema.isV3())
    ? await prisma.$queryRaw`
        SELECT COUNT(*) AS n
        FROM chat_messages x
        JOIN chat_room_members m ON m.room_id = x.room_id AND m.user_id = ${myId} AND m.left_at IS NULL
        JOIN chat_rooms r ON r.room_id = x.room_id
        WHERE x.sender_id <> ${myId}
          AND IF(r.room_type = 'group', x.message_id > m.last_read_message_id AND x.message_id >= m.history_from_id, x.is_read = 0)`
    : await prisma.$queryRaw`
        SELECT COUNT(*) AS n
        FROM chat_messages x
        JOIN chat_room_members m ON m.room_id = x.room_id AND m.user_id = ${myId} AND m.left_at IS NULL
        JOIN chat_rooms r ON r.room_id = x.room_id
        WHERE x.sender_id <> ${myId}
          AND IF(r.room_type = 'group',
            x.message_id > m.last_read_message_id AND x.created_at >= m.joined_at - INTERVAL 1 SECOND, x.is_read = 0)`;
  return Number(row?.n ?? 0);
};

const markAllRead = async (myId) => {
  if (!(await schema.isV2())) {
    await prisma.chat_messages.updateMany({
      where: { is_read: false, sender_id: { not: myId }, chat_rooms: myRooms(myId) },
      data: { is_read: true }
    });
    return;
  }
  await prisma.$transaction([
    prisma.$executeRaw`
      UPDATE chat_messages x
      JOIN chat_room_members m ON m.room_id = x.room_id AND m.user_id = ${myId} AND m.left_at IS NULL
      JOIN chat_rooms r ON r.room_id = x.room_id AND r.room_type = 'direct'
      SET x.is_read = 1
      WHERE x.is_read = 0 AND x.sender_id <> ${myId}`,
    prisma.$executeRaw`
      UPDATE chat_room_members m
      SET m.last_read_message_id = (SELECT COALESCE(MAX(x.message_id), 0) FROM chat_messages x WHERE x.room_id = m.room_id)
      WHERE m.user_id = ${myId} AND m.left_at IS NULL`
  ]);
};

const remove = async (roomId, myId) => {
  const room = await prisma.chat_rooms.findUnique({
    where: { room_id: roomId },
    select: { user_a_id: true, user_b_id: true }
  });
  if (!room) throw notFound('找不到此聊天室');
  if (room.user_a_id !== myId && room.user_b_id !== myId) throw forbidden('您沒有權限刪除此聊天室');

  await prisma.$transaction([
    prisma.chat_messages.deleteMany({ where: { room_id: roomId } }),
    prisma.chat_rooms.delete({ where: { room_id: roomId } })
  ]);
};

const open = async (myId, partnerId, bookId) => {
  if (partnerId === myId) throw badRequest('無法與自己建立聊天室');

  const partner = await prisma.users.findUnique({
    where: { user_id: partnerId },
    select: { is_active: true, is_blacklisted: true }
  });
  if (!partner) throw notFound('找不到該使用者');
  if (!partner.is_active || partner.is_blacklisted) throw controls.recipientUnavailable();

  const { blocked, blockedBy } = await controls.relation(myId, partnerId);

  const book = bookId && !blocked && !blockedBy
    ? await prisma.books.findUnique({
        where: { book_id: bookId },
        select: { book_id: true, title: true, price: true, book_images: coverImage }
      })
    : null;

  let room = await between(prisma, myId, partnerId);

  if (!room) {
    if (blockedBy) throw controls.recipientUnavailable();
    const [userA, userB] = myId < partnerId ? [myId, partnerId] : [partnerId, myId];
    room = await prisma.chat_rooms.create({
      data: { user_a_id: userA, user_b_id: userB, book_id: book?.book_id ?? null }
    });
  }

  if (await schema.isV2()) {
    await members.addDirect(prisma, room.room_id, [room.user_a_id, room.user_b_id], room.created_at ?? new Date());
  }

  if (book) {
    const card = codec.encodeBook(book);
    const latest = await prisma.chat_messages.findFirst({
      where: { room_id: room.room_id },
      orderBy: { message_id: 'desc' },
      select: { message_type: true, content: true }
    });

    if (!latest || latest.message_type !== 'system' || latest.content !== card) {
      await prisma.$transaction([
        prisma.chat_messages.create({
          data: { room_id: room.room_id, sender_id: myId, content: card, message_type: 'system', is_read: true }
        }),
        prisma.chat_rooms.update({
          where: { room_id: room.room_id },
          data: { book_id: book.book_id, updated_at: new Date() }
        })
      ]);
    }
  }

  return room.room_id;
};

const setMuted = async (roomId, myId, muted) => {
  await findMine(roomId, myId);
  await controls.setMuted(myId, roomId, muted);
};

const setPinned = async (roomId, myId, pinned) => {
  await schema.requireV2();
  await findMine(roomId, myId);

  if (!pinned) {
    await members.unpin(prisma, roomId, myId);
    return { room_id: roomId, pinned: false, pinned_at: null };
  }

  const existing = await pinnedAtOf(myId, roomId);
  if (existing) return { room_id: roomId, pinned: true, pinned_at: existing };

  const [row] = await prisma.$queryRaw`
    SELECT COUNT(*) AS n FROM chat_room_pins p
    JOIN chat_room_members m ON m.room_id = p.room_id AND m.user_id = p.user_id AND m.left_at IS NULL
    WHERE p.user_id = ${myId}`;
  if (Number(row?.n ?? 0) >= MAX_PINS) throw badRequest(`最多僅能釘選 ${MAX_PINS} 個聊天室`, 'PIN_LIMIT');

  const now = new Date();
  await prisma.$executeRaw`INSERT IGNORE INTO chat_room_pins (user_id, room_id, pinned_at) VALUES (${myId}, ${roomId}, ${now})`;
  return { room_id: roomId, pinned: true, pinned_at: now };
};

module.exports = {
  MAX_PINS, partnerOf, partnerIdOf, isGroup, between, findMine, findMessageable, typeOf, summaryOf, list, detail,
  unreadCount, markAllRead, remove, open, setMuted, setPinned
};
