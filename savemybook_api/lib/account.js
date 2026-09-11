const crypto = require('crypto');
const prisma = require('./prisma');

/// 申請刪除後的緩衝天數。期間內登入即可取消，逾期才真正匿名化。
const GRACE_DAYS = 30;

const graceDeadline = (requestedAt) =>
  new Date(new Date(requestedAt).getTime() + GRACE_DAYS * 86400000);

/// 分享連結用的權杖。UUID 與流水號都可被推測或枚舉，這裡用密碼學亂數。
const newShareToken = () => crypto.randomBytes(16).toString('hex');

const ensureShareToken = async (userId) => {
  const user = await prisma.users.findUnique({
    where: { user_id: userId },
    select: { share_token: true }
  });
  if (user?.share_token) return user.share_token;

  const token = newShareToken();
  await prisma.users.update({
    where: { user_id: userId },
    data: { share_token: token }
  });
  return token;
};

/// 清掉個資但保留交易骨架。
///
/// 完全刪除會讓對方的購買紀錄出現破洞，而且訂單、錢包異動是帳務資料，
/// 不能因為單方刪號就消失。所以是匿名化而不是 DELETE。
const anonymize = async (userId) => {
  const stamp = Date.now();

  await prisma.$transaction(async (tx) => {
    await tx.users.update({
      where: { user_id: userId },
      data: {
        // Email 必須保持唯一，用 user_id 組一個不可能撞號的值。
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

    // 還在架上的書一併下架，否則會出現找不到賣家的商品。
    await tx.books.updateMany({
      where: { seller_id: userId, status: { in: ['on_sale', 'reserved'] } },
      data: { status: 'removed', updated_at: new Date() }
    });

    await tx.shopping_cart.deleteMany({ where: { user_id: userId } });
    await tx.favorites.deleteMany({ where: { user_id: userId } });
    await tx.user_qr_codes.deleteMany({ where: { user_id: userId } });
    await tx.notifications.deleteMany({ where: { user_id: userId } });

    // 聊天訊息內容可能含個資，但整串刪掉會讓對方的對話斷裂，
    // 所以只把內容換成佔位字串。
    await tx.chat_messages.updateMany({
      where: { sender_id: userId },
      data: { content: '（使用者已刪除帳號）', message_type: 'system' }
    });
  });
};

/// 處理所有已過緩衝期的刪除申請。由 index.js 定時呼叫。
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
      await anonymize(user.user_id);
      console.log(`[帳號匿名化] user_id=${user.user_id}`);
    } catch (err) {
      console.error(`[帳號匿名化失敗] user_id=${user.user_id}:`, err);
    }
  }
  return due.length;
};

/// 使用者可以帶走的完整資料。
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

module.exports = {
  GRACE_DAYS,
  graceDeadline,
  newShareToken,
  ensureShareToken,
  anonymize,
  processDueDeletions,
  exportData
};
