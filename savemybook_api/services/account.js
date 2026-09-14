const crypto = require('crypto');
const prisma = require('../lib/prisma');
const push = require('./push');
const sessions = require('./sessions');
const { ORDER_UNSETTLED_STATUSES } = require('../constants/domain');

const GRACE_DAYS = 30;

const graceDeadline = (requestedAt) =>
  new Date(new Date(requestedAt).getTime() + GRACE_DAYS * 86400000);

// 匿名化而非 DELETE：訂單與錢包異動屬帳務資料，不可隨單方刪號消失。
const anonymize = async (userId) => {
  const stamp = Date.now();

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

    await tx.chat_messages.updateMany({
      where: { sender_id: userId },
      data: { content: '（使用者已刪除帳號）', message_type: 'system' }
    });
  });

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

const exportData = async (userId) => {
  const [user, books, boughtOrders, soldOrders, wallet, disputes, reports, tickets] =
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
      prisma.support_tickets.findMany({
        where: { user_id: userId },
        include: { messages: { orderBy: { created_at: 'asc' } } }
      })
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
    support_tickets: tickets
  };
};

const deletionStatus = (requestedAt) => ({
  requested_at: requestedAt,
  purge_at: graceDeadline(requestedAt),
  grace_days: GRACE_DAYS
});

module.exports = {
  GRACE_DAYS,
  graceDeadline,
  deletionStatus,
  unsettledOrderCount,
  anonymize,
  processDueDeletions,
  exportData
};
