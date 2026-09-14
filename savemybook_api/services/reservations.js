const prisma = require('../lib/prisma');
const { badRequest, conflict, forbidden, notFound } = require('../lib/errors');
const { notify } = require('./notify');
const chat = require('./chat');

const HOURS = [24, 48, 72];
const PENDING_TTL_MS = 24 * 60 * 60 * 1000;
const MAX_ACTIVE_PER_BUYER = 5;

const bookSelect = {
  book_id: true, title: true, price: true, status: true, seller_id: true, is_approved: true,
  book_images: { select: { image_url: true }, take: 1 }
};

const noteOf = (row) => {
  try {
    const value = JSON.parse(row.note ?? '{}');
    return value && typeof value === 'object' ? value : {};
  } catch {
    return {};
  }
};

const isHolding = (row, now = new Date()) =>
  row.status === 'confirmed' && row.pickup_deadline && new Date(row.pickup_deadline) > now;

const shape = (row) => {
  const note = noteOf(row);
  return {
    reservation_id: row.reservation_id,
    book: row.books && {
      book_id: row.books.book_id,
      title: row.books.title,
      price: row.books.price,
      status: row.books.status,
      image_url: row.books.book_images?.[0]?.image_url ?? null
    },
    buyer_id: row.buyer_id,
    seller_id: row.seller_id,
    status: row.status,
    hours: Number(note.hours) || null,
    message: note.message ?? null,
    closed_by: note.closed_by ?? null,
    closed_action: note.action ?? null,
    pickup_deadline: row.pickup_deadline,
    is_holding: isHolding(row),
    created_at: row.created_at,
    updated_at: row.updated_at
  };
};

const activeHold = (db, bookId) => (db ?? prisma).reservations.findFirst({
  where: { book_id: bookId, status: 'confirmed', pickup_deadline: { gt: new Date() } },
  select: { reservation_id: true, buyer_id: true, pickup_deadline: true }
});

const deadlineFormat = new Intl.DateTimeFormat('zh-TW', {
  timeZone: 'Asia/Taipei', month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false
});

const formatDeadline = (date) => deadlineFormat.format(new Date(date));

const assertNotHeldByOthers = async (db, books, buyerId) => {
  for (const book of books) {
    const hold = await activeHold(db, book.book_id);
    if (hold && hold.buyer_id !== buyerId) {
      throw conflict(`《${book.title}》已由其他買家預約，保留至 ${formatDeadline(hold.pickup_deadline)}`, 'BOOK_RESERVED');
    }
  }
};

const roomBetween = async (db, a, b) => {
  const [userA, userB] = a < b ? [a, b] : [b, a];
  return db.chat_rooms.findFirst({ where: { user_a_id: userA, user_b_id: userB }, orderBy: { updated_at: 'desc' } });
};

const postCard = async (tx, { roomId, senderId, reservationId }) => {
  await tx.chat_messages.create({
    data: { room_id: roomId, sender_id: senderId, content: chat.encodeReservation(reservationId), message_type: 'system' }
  });
  await tx.chat_rooms.update({ where: { room_id: roomId }, data: { updated_at: new Date() } });
};

const request = async ({ room, buyerId, bookId, hours, message }) => {
  if (!HOURS.includes(hours)) throw badRequest(`保留時間僅接受：${HOURS.join('、')} 小時`);

  const book = await prisma.books.findUnique({ where: { book_id: bookId }, select: bookSelect });
  if (!book) throw notFound('找不到此書籍');
  const sellerId = book.seller_id;
  if (sellerId === buyerId) throw badRequest('無法預約自己上架的書籍');
  if (![room.user_a_id, room.user_b_id].includes(sellerId)) throw badRequest('僅能於與該書賣家的聊天室中預約');
  if (book.status !== 'on_sale' || !book.is_approved) throw badRequest('此書籍目前無法預約');

  await assertNotHeldByOthers(prisma, [book], buyerId);

  const [mine, activeCount] = await Promise.all([
    prisma.reservations.findFirst({
      where: { book_id: bookId, buyer_id: buyerId, status: { in: ['pending', 'confirmed'] } },
      select: { reservation_id: true, status: true, pickup_deadline: true }
    }),
    prisma.reservations.count({ where: { buyer_id: buyerId, status: { in: ['pending', 'confirmed'] } } })
  ]);
  if (mine && (mine.status === 'pending' || isHolding(mine))) {
    throw conflict(mine.status === 'pending' ? '您已送出預約，正在等待賣家回覆' : '您已預約此書籍');
  }
  if (activeCount >= MAX_ACTIVE_PER_BUYER) throw badRequest(`同時最多僅能有 ${MAX_ACTIVE_PER_BUYER} 筆進行中的預約`);

  return prisma.$transaction(async (tx) => {
    const created = await tx.reservations.create({
      data: {
        book_id: bookId,
        buyer_id: buyerId,
        seller_id: sellerId,
        status: 'pending',
        note: JSON.stringify({ hours, message: message || null })
      },
      include: { books: { select: bookSelect } }
    });
    await postCard(tx, { roomId: room.room_id, senderId: buyerId, reservationId: created.reservation_id });
    await notify(tx, {
      userId: sellerId,
      type: 'reservation',
      title: '您的書籍收到預約申請',
      content: `對方申請預約《${book.title}》，保留 ${hours} 小時。請至聊天室回覆。`,
      relatedId: room.room_id,
      relatedType: 'chat_room'
    });
    return shape(created);
  });
};

const ACTIONS = {
  accept: { by: 'seller', from: ['pending'] },
  decline: { by: 'seller', from: ['pending'] },
  cancel: { by: 'either', from: ['pending', 'confirmed'] }
};

const respond = async (reservationId, userId, action) => {
  const rule = ACTIONS[action];
  if (!rule) throw badRequest('action 僅接受：accept, decline, cancel');

  const row = await prisma.reservations.findUnique({
    where: { reservation_id: reservationId },
    include: { books: { select: bookSelect } }
  });
  if (!row) throw notFound('找不到此預約');
  const isSeller = row.seller_id === userId;
  const isBuyer = row.buyer_id === userId;
  if (!isSeller && !isBuyer) throw forbidden('此預約不屬於您');
  if (rule.by === 'seller' && !isSeller) throw forbidden('僅賣家可回覆預約');
  if (!rule.from.includes(row.status) || (row.status === 'confirmed' && !isHolding(row))) {
    throw conflict('此預約狀態已變更，請重新整理');
  }

  const now = new Date();
  const note = noteOf(row);
  const title = row.books?.title ?? '';

  if (action === 'accept') {
    if (row.books.status !== 'on_sale') throw conflict('此書籍已下架，無法接受預約');
    await assertNotHeldByOthers(prisma, [row.books], row.buyer_id);
  }

  return prisma.$transaction(async (tx) => {
    const data = { updated_at: now };
    if (action === 'accept') {
      data.status = 'confirmed';
      data.pickup_deadline = new Date(now.getTime() + (Number(note.hours) || 24) * 60 * 60 * 1000);
    } else {
      data.status = 'cancelled';
      data.note = JSON.stringify({ ...note, closed_by: isSeller ? 'seller' : 'buyer', action });
    }

    const result = await tx.reservations.updateMany({
      where: { reservation_id: reservationId, status: row.status },
      data
    });
    if (result.count === 0) throw conflict('此預約狀態已變更，請重新整理');

    if (action === 'accept') {
      const others = await tx.reservations.findMany({
        where: { book_id: row.book_id, status: 'pending', reservation_id: { not: reservationId } },
        select: { reservation_id: true, buyer_id: true }
      });
      if (others.length > 0) {
        await tx.reservations.updateMany({
          where: { reservation_id: { in: others.map((o) => o.reservation_id) } },
          data: { status: 'cancelled', updated_at: now }
        });
        for (const other of others) {
          await notify(tx, {
            userId: other.buyer_id,
            type: 'reservation',
            title: '預約未成立',
            content: `《${title}》已保留給其他買家。`,
            relatedId: row.book_id,
            relatedType: 'book'
          });
        }
      }
    }

    const room = await roomBetween(tx, row.buyer_id, row.seller_id);
    if (room) await tx.chat_rooms.update({ where: { room_id: room.room_id }, data: { updated_at: now } });

    const target = isSeller ? row.buyer_id : row.seller_id;
    const [notifyTitle, notifyContent] = {
      accept: () => ['賣家已接受您的預約', `《${title}》已為您保留至 ${formatDeadline(data.pickup_deadline)}，請於期限內完成購買。`],
      decline: () => ['賣家已婉拒預約', `賣家目前無法保留《${title}》。`],
      cancel: () => ['預約已取消', `《${title}》的預約已被${isSeller ? '賣家' : '買家'}取消。`]
    }[action]();
    await notify(tx, {
      userId: target,
      type: 'reservation',
      title: notifyTitle,
      content: notifyContent,
      relatedId: room?.room_id ?? null,
      relatedType: room ? 'chat_room' : null
    });

    const updated = await tx.reservations.findUnique({
      where: { reservation_id: reservationId },
      include: { books: { select: bookSelect } }
    });
    return shape(updated);
  });
};

const forUsers = async (a, b) => {
  const rows = await prisma.reservations.findMany({
    where: { OR: [{ buyer_id: a, seller_id: b }, { buyer_id: b, seller_id: a }] },
    orderBy: { created_at: 'desc' },
    take: 30,
    include: { books: { select: bookSelect } }
  });
  return new Map(rows.map((r) => [r.reservation_id, shape(r)]));
};

const holdForViewer = async (bookId, viewerId) => {
  const hold = await activeHold(null, bookId);
  if (!hold) return null;
  return { reserved_until: hold.pickup_deadline, reserved_for_me: viewerId != null && hold.buyer_id === viewerId };
};

const expireDue = async () => {
  const now = new Date();
  const stalePending = new Date(now.getTime() - PENDING_TTL_MS);
  const due = await prisma.reservations.findMany({
    where: {
      OR: [
        { status: 'pending', created_at: { lt: stalePending } },
        { status: 'confirmed', pickup_deadline: { lte: now } }
      ]
    },
    include: { books: { select: bookSelect } },
    take: 200
  });

  for (const row of due) {
    const result = await prisma.reservations.updateMany({
      where: { reservation_id: row.reservation_id, status: row.status },
      data: { status: 'expired', updated_at: now }
    });
    if (result.count === 0 || row.books?.status !== 'on_sale') continue;

    const title = row.books.title;
    const wasPending = row.status === 'pending';
    await notify(null, {
      userId: row.buyer_id,
      type: 'reservation',
      title: wasPending ? '預約未獲回覆' : '預約已到期',
      content: wasPending ? `賣家未於 24 小時內回覆《${title}》的預約。` : `《${title}》的保留期限已屆滿，其他買家現已可購買。`,
      relatedId: row.book_id,
      relatedType: 'book'
    }).catch(() => {});
  }
  return due.length;
};

module.exports = {
  HOURS, shape, activeHold, assertNotHeldByOthers, request, respond, forUsers, holdForViewer, expireDue
};
