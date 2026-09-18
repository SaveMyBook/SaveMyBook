const crypto = require('crypto');
const prisma = require('../lib/prisma');
const password = require('../lib/password');
const { badRequest, forbidden, notFound, conflict } = require('../lib/errors');
const push = require('./push');
const sessions = require('./sessions');
const audit = require('./audit');
const aiSettings = require('./ai/settings');
const aiConsent = require('./ai/consent');
const authSettings = require('./auth-settings');
const { hasTables } = require('../lib/schema-check');
const supportAttachments = require('./support-attachments');
const { ORDER_UNSETTLED_STATUSES } = require('../constants/domain');

const GRACE_DAYS = 30;

const graceDeadline = (requestedAt) =>
  new Date(new Date(requestedAt).getTime() + GRACE_DAYS * 86400000);

// 匿名化而非 DELETE：訂單與錢包異動屬帳務資料，不可隨單方刪號消失。
const anonymize = async (userId) => {
  const stamp = Date.now();
  const [aiReady, authReady, passkeyReady, attachmentsReady] = await Promise.all([
    aiSettings.migrationReady(), authSettings.migrationReady(), hasTables(['user_passkeys', 'webauthn_challenges']),
    supportAttachments.ready()
  ]);
  let removedAttachments = [];

  await prisma.$transaction(async (tx) => {
    await tx.users.update({
      where: { user_id: userId },
      data: {
        email: `deleted+${userId}.${stamp}@savemybook.invalid`,
        password_hash: crypto.randomBytes(32).toString('hex'),
        nickname: '已刪除的使用者',
        avatar_url: null,
        bio: null,
        phone: null,
        birthday: null,
        gender: 'undisclosed',
        is_active: false,
        share_token: null,
        anonymized_at: new Date(),
        updated_at: new Date()
      }
    });

    await tx.books.updateMany({
      where: { seller_id: userId, status: { in: ['on_sale', 'reserved'] } },
      data: { status: 'removed', updated_at: new Date() }
    });

    await tx.shopping_cart.deleteMany({ where: { user_id: userId } });
    await tx.favorites.deleteMany({ where: { user_id: userId } });
    await tx.user_qr_codes.deleteMany({ where: { user_id: userId } });
    await tx.notifications.deleteMany({ where: { user_id: userId } });
    if (aiReady) await aiConsent.purgeUser(tx, userId);
    if (authReady) {
      await tx.$executeRaw`DELETE FROM user_identities WHERE user_id = ${userId}`;
      // 密碼雜湊已換成隨機值，登入方式一併回到「僅密碼」的狀態。
      await tx.$executeRaw`UPDATE users SET password_set = 1 WHERE user_id = ${userId}`;
    }

    if (passkeyReady) {
      await tx.$executeRaw`DELETE FROM user_passkeys WHERE user_id = ${userId}`;
      await tx.$executeRaw`DELETE FROM webauthn_challenges WHERE user_id = ${userId}`;
    }

    if (attachmentsReady) removedAttachments = await supportAttachments.purgeUser(tx, userId);

    await tx.chat_messages.updateMany({
      where: { sender_id: userId },
      data: { content: '（使用者已刪除帳號）', message_type: 'system' }
    });
  });

  // 檔案須在交易成功後才刪，否則交易回滾時資料列還在、圖片卻已消失。
  supportAttachments.unlinkUrls(removedAttachments);
  await push.removeUserDevices(userId);
  await sessions.revokeAll(userId).catch(() => {});
};

const unsettledOrderCount = (userId) =>
  prisma.orders.count({
    where: {
      OR: [{ buyer_id: userId }, { seller_id: userId }],
      status: { in: ORDER_UNSETTLED_STATUSES }
    }
  });

const processDueDeletions = async () => {
  const due = await prisma.users.findMany({
    where: {
      deletion_requested_at: { not: null, lte: new Date(Date.now() - GRACE_DAYS * 86400000) },
      anonymized_at: null
    },
    select: { user_id: true }
  });

  for (const user of due) {
    try {
      // 緩衝期內仍可交易，新成立的訂單須走完才能匿名化。
      if ((await unsettledOrderCount(user.user_id)) > 0) {
        console.log(`[帳號匿名化延後] user_id=${user.user_id}：尚有進行中的訂單`);
        continue;
      }
      await anonymize(user.user_id);
      console.log(`[帳號匿名化] user_id=${user.user_id}`);
    } catch (err) {
      console.error(`[帳號匿名化失敗] user_id=${user.user_id}:`, err);
    }
  }
  return due.length;
};

// 尚未執行 014 時沒有這些資料表，匯出內容以 null 表示「本站未保存」。
const exportIdentities = async (userId) => {
  if (!(await authSettings.migrationReady())) return null;
  const [rows, user] = await Promise.all([
    prisma.$queryRaw`
      SELECT provider, email, phone, display_name, created_at, last_login_at
      FROM user_identities WHERE user_id = ${userId} ORDER BY created_at ASC`,
    prisma.$queryRaw`SELECT password_set FROM users WHERE user_id = ${userId}`
  ]);
  return {
    password_set: Number(user[0]?.password_set ?? 1) === 1,
    items: rows.map((row) => ({
      provider: row.provider,
      email: row.email,
      phone: row.phone,
      display_name: row.display_name,
      created_at: row.created_at,
      last_login_at: row.last_login_at
    }))
  };
};

// 匯出不含憑證編號與簽章計數；公鑰本身不是秘密，保留供使用者核對。未執行 016 時為 null。
const exportPasskeys = async (userId) => {
  if (!(await hasTables(['user_passkeys', 'webauthn_challenges']))) return null;
  const rows = await prisma.$queryRaw`
    SELECT device_label, public_key, transports, aaguid, backed_up, created_at, last_used_at
    FROM user_passkeys WHERE user_id = ${userId} ORDER BY created_at ASC`;
  return rows.map((row) => ({
    device_label: row.device_label ?? null,
    public_key: row.public_key,
    transports: row.transports ? String(row.transports).split(',') : [],
    aaguid: row.aaguid ?? null,
    backed_up: Boolean(Number(row.backed_up)),
    created_at: row.created_at,
    last_used_at: row.last_used_at ?? null
  }));
};

// 附件以效期七天的簽章網址提供，使用者可在匯出後自行下載；未執行 017 時每則訊息為空陣列。
const exportTickets = async (userId) => {
  const tickets = await prisma.support_tickets.findMany({
    where: { user_id: userId },
    include: { messages: { orderBy: { created_at: 'asc' } } }
  });
  const files = await supportAttachments.forMessages(
    tickets.flatMap((t) => (t.messages ?? []).map((m) => m.message_id)),
    { ttl: supportAttachments.EXPORT_LINK_S }
  );
  return tickets.map((t) => ({
    ...t,
    messages: (t.messages ?? []).map((m) => ({ ...m, attachments: files.get(m.message_id) ?? [] }))
  }));
};

const exportData = async (userId) => {
  const [user, books, boughtOrders, soldOrders, wallet, disputes, reports, tickets, ai, identities, passkeys] =
    await Promise.all([
      prisma.users.findUnique({
        where: { user_id: userId },
        select: {
          user_id: true, email: true, nickname: true, bio: true, phone: true,
          birthday: true, gender: true, role: true, created_at: true
        }
      }),
      prisma.books.findMany({
        where: { seller_id: userId },
        include: { book_images: { select: { image_url: true, image_type: true } } }
      }),
      prisma.orders.findMany({
        where: { buyer_id: userId },
        include: { order_items: { include: { books: { select: { title: true } } } } }
      }),
      prisma.orders.findMany({
        where: { seller_id: userId },
        include: { order_items: { include: { books: { select: { title: true } } } } }
      }),
      prisma.wallets.findUnique({
        where: { user_id: userId },
        include: { wallet_transactions: { orderBy: { created_at: 'desc' } } }
      }),
      prisma.transaction_disputes.findMany({ where: { applicant_id: userId } }),
      prisma.reports.findMany({ where: { reporter_id: userId } }),
      exportTickets(userId),
      aiConsent.exportUser(userId),
      exportIdentities(userId),
      exportPasskeys(userId)
    ]);

  return {
    exported_at: new Date().toISOString(),
    format_version: 1,
    profile: user,
    books,
    orders_as_buyer: boughtOrders,
    orders_as_seller: soldOrders,
    wallet,
    disputes,
    reports,
    support_tickets: tickets,
    ai,
    sign_in_methods: identities,
    passkeys
  };
};

const deletionStatus = (requestedAt) => ({
  requested_at: requestedAt,
  purge_at: graceDeadline(requestedAt),
  grace_days: GRACE_DAYS
});

const deletionInfo = async (userId) => {
  const user = await prisma.users.findUnique({
    where: { user_id: userId },
    select: { deletion_requested_at: true }
  });
  const requested = user?.deletion_requested_at ?? null;
  return {
    pending: requested != null,
    requested_at: requested,
    purge_at: requested ? graceDeadline(requested) : null,
    grace_days: GRACE_DAYS
  };
};

const requestDeletion = async (userId, plain) => {
  const user = await prisma.users.findUnique({
    where: { user_id: userId },
    select: { user_id: true, password_hash: true, role: true, deletion_requested_at: true }
  });
  if (!user) throw notFound('找不到該使用者');
  if (!(await password.verify(plain, user.password_hash))) throw badRequest('密碼錯誤');

  const openOrders = await unsettledOrderCount(user.user_id);
  if (openOrders > 0) {
    throw badRequest(`尚有 ${openOrders} 筆進行中的訂單，請先完成或取消後再申請刪除`, 'OPEN_ORDERS');
  }

  // 重複申請沿用第一次的時間，否則緩衝期會被重新計算。
  const requestedAt = user.deletion_requested_at ?? new Date();
  if (!user.deletion_requested_at) {
    await prisma.users.update({
      where: { user_id: user.user_id },
      data: { deletion_requested_at: requestedAt, updated_at: new Date() }
    });
  }
  return { purge_at: graceDeadline(requestedAt), grace_days: GRACE_DAYS };
};

const cancelDeletion = (userId) => prisma.users.update({
  where: { user_id: userId },
  data: { deletion_requested_at: null, updated_at: new Date() }
});

const pendingDeletions = async () => {
  const pending = await prisma.users.findMany({
    where: { deletion_requested_at: { not: null }, anonymized_at: null },
    orderBy: { deletion_requested_at: 'asc' },
    select: { user_id: true, nickname: true, email: true, avatar_url: true, deletion_requested_at: true }
  });
  return pending.map((u) => ({ ...u, purge_at: graceDeadline(u.deletion_requested_at) }));
};

const cancelDeletionByAdmin = async (userId, { adminId, req }) => {
  const before = await prisma.users.findUnique({
    where: { user_id: userId },
    select: { nickname: true, email: true, deletion_requested_at: true }
  });
  if (!before) throw notFound('找不到該會員');

  const after = { deletion_requested_at: null };
  await prisma.users.update({ where: { user_id: userId }, data: { ...after, updated_at: new Date() } });

  const fields = { deletion_requested_at: '申請刪除時間' };
  await audit.record(null, {
    adminId,
    action: '取消會員刪除申請',
    targetType: 'user',
    targetId: userId,
    summary: `取消 ${before.nickname}（${before.email}）的刪除帳號申請`,
    changes: audit.diff(before, after, fields),
    undo: before.deletion_requested_at ? [audit.undoUpdate('users', userId, before, after, fields)] : null,
    req
  });
};

// 匿名化無法復原，只能對本人已申請刪除的帳號執行。
const anonymizeByAdmin = async (userId, { adminId, req }) => {
  if (userId === adminId) throw badRequest('無法對自己執行此操作');

  const user = await prisma.users.findUnique({
    where: { user_id: userId },
    select: { role: true, deletion_requested_at: true, anonymized_at: true }
  });
  if (!user) throw notFound('找不到該會員');
  if (user.anonymized_at) throw conflict('此帳號已匿名化');
  if (!user.deletion_requested_at) throw conflict('此會員未申請刪除帳號，無法匿名化');
  if (user.role === 'admin') throw forbidden('無法匿名化管理員帳號，請先移除管理員身分');
  if ((await unsettledOrderCount(userId)) > 0) {
    throw conflict('此會員尚有進行中的訂單，請處理完成後再匿名化');
  }

  const who = await prisma.users.findUnique({ where: { user_id: userId }, select: { nickname: true, email: true } });
  await anonymize(userId);
  await audit.record(null, {
    adminId,
    action: '立即匿名化會員',
    targetType: 'user',
    targetId: userId,
    summary: `提前匿名化 ${who.nickname}（${who.email}）的帳號，個資已清除，無法復原`,
    req
  });
};

module.exports = {
  GRACE_DAYS,
  deletionStatus,
  unsettledOrderCount,
  processDueDeletions,
  exportData,
  deletionInfo,
  requestDeletion,
  cancelDeletion,
  pendingDeletions,
  cancelDeletionByAdmin,
  anonymizeByAdmin
};
