const crypto = require('crypto');
const prisma = require('../../lib/prisma');
const { badRequest, conflict, notFound } = require('../../lib/errors');
const { changeBalance } = require('../wallet');
const { notify } = require('../notify');
const reservations = require('../reservations');
const cabinets = require('../cabinets');
const policy = require('../../constants/policy');
const { orderInclude } = require('./selects');

const pad = (n) => String(n).padStart(2, '0');

const buildOrderNo = () => {
  const d = new Date();
  const stamp = `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
  // 一次結帳同一秒會產生多個編號，亂數段需夠長以免撞唯一索引。
  return `SMB${stamp}${crypto.randomInt(100000, 1000000)}`;
};

const sellerContent = (orderNo, { inCabinet, stored }) => {
  if (inCabinet) return `訂單 ${orderNo} 已成立，書籍已存放於書櫃，待買家取書。`;
  if (stored > 0) return `訂單 ${orderNo} 已成立，請於七天內至書櫃以 App 掃描 QR Code，存入其餘書籍。`;
  return `訂單 ${orderNo} 已成立，請於七天內至書櫃存書。`;
};

// 逐本以刪除筆數判斷存書位置：刪除讀取的是最新資料，快照讀取會漏看結帳期間才完成的存書或取回。
// 存書登記的書櫃與書籍的書櫃不一致（資料異常）時，該書不視為已在訂單書櫃，但仍須刪除登記，以免已售出的書留有存書紀錄。
const releaseDeposits = async (tx, bookIds, cabinetId) => {
  const stored = new Set();
  for (const bookId of bookIds) {
    const same = cabinetId != null
      ? await tx.book_deposits.deleteMany({ where: { book_id: bookId, cabinet_id: cabinetId } })
      : { count: 0 };
    if (same.count > 0) stored.add(bookId);
    else await tx.book_deposits.deleteMany({ where: { book_id: bookId } });
  }
  return { stored, missing: bookIds.length - stored.size };
};


const checkout = async (buyerId, { cartIds, paymentMethod }) => {
  const cartItems = await prisma.shopping_cart.findMany({
    where: {
      user_id: buyerId,
      ...(cartIds && cartIds.length > 0 && { cart_id: { in: cartIds } })
    },
    include: { books: true }
  });

  if (cartItems.length === 0) throw badRequest('購物車沒有可結帳的項目');
  return placeOrders(buyerId, cartItems, { paymentMethod });
};

const buyNow = async (buyerId, { bookId, paymentMethod }) => {
  const book = await prisma.books.findUnique({ where: { book_id: bookId } });
  if (!book || !book.is_approved) throw notFound('找不到此書籍');
  const [order] = await placeOrders(buyerId, [{ cart_id: null, book_id: book.book_id, quantity: 1, books: book }], {
    paymentMethod,
    alsoRemoveBookIds: [book.book_id]
  });
  return order;
};

const placeOrders = async (buyerId, cartItems, { paymentMethod, alsoRemoveBookIds = [] }) => {
  const direct = alsoRemoveBookIds.length > 0;
  const hint = (cart, single) => (direct ? single : cart);

  const unavailable = cartItems.find((i) => i.books.status !== 'on_sale');
  if (unavailable) throw badRequest(`《${unavailable.books.title}》已無法購買${hint('，請先移除', '')}`);

  // 書櫃維修中時賣家無法存書，成立訂單只會卡在待存書。
  const underMaintenance = await cabinets.maintenanceIds();
  const blocked = cartItems.find((i) => i.books.cabinet_id && underMaintenance.has(Number(i.books.cabinet_id)));
  if (blocked) {
    throw badRequest(
      `《${blocked.books.title}》存放的書櫃維修中，暫時無法購買，${hint('請先移除或稍後再試', '請稍後再試')}`,
      'CABINET_MAINTENANCE'
    );
  }

  await reservations.assertNotHeldByOthers(null, cartItems.map((i) => i.books), buyerId);

  const ownBook = cartItems.find((i) => i.books.seller_id === buyerId);
  if (ownBook) throw badRequest(`《${ownBook.books.title}》為您上架的書籍，無法購買`);

  // 既有資料可能有售價 0 的書，結帳時須再擋一次。
  const invalidPrice = cartItems.find((i) => !(Number(i.books.price) > 0));
  if (invalidPrice) {
    throw badRequest(`《${invalidPrice.books.title}》的售價異常，${hint('請聯絡賣家或先移除', '請聯絡賣家')}`);
  }

  const groups = new Map();
  for (const item of cartItems) {
    const key = `${item.books.seller_id}:${item.books.cabinet_id ?? ''}`;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(item);
  }
  // 二手書一筆即一本：舊資料的購物車數量可能大於 1，一律以 1 本計價與計入每單上限。
  const oversized = [...groups.values()].find((items) => items.length > policy.ORDER_MAX_BOOKS);
  if (oversized) {
    throw badRequest(
      `同一賣家於同一書櫃之書籍，每筆訂單最多 ${policy.ORDER_MAX_BOOKS} 本，請分次結帳`,
      'ORDER_BOOK_LIMIT',
      { max_books: policy.ORDER_MAX_BOOKS, book_ids: oversized.map((i) => i.book_id) }
    );
  }

  const lineTotal = (i) => Number(i.books.price);
  const grandTotal = cartItems.reduce((sum, i) => sum + lineTotal(i), 0);

  const buyerWallet = await prisma.wallets.findUnique({ where: { user_id: buyerId } });
  const currentBalance = Number(buyerWallet?.balance ?? 0);
  if (currentBalance < grandTotal) {
    throw badRequest(
      `代幣不足，此訂單需 ${grandTotal} 代幣，目前餘額 ${currentBalance}`,
      'INSUFFICIENT_BALANCE'
    );
  }

  return prisma.$transaction(async (tx) => {
    const results = [];

    for (const items of groups.values()) {
      const sellerId = items[0].books.seller_id;
      const bookIds = items.map((i) => i.book_id);

      // 先把書鎖成保留中，兩個買家同時結帳時只有一人的 count 對得上。
      const reserved = await tx.books.updateMany({
        where: { book_id: { in: bookIds }, status: 'on_sale' },
        data: { status: 'reserved', updated_at: new Date() }
      });
      if (reserved.count !== bookIds.length) {
        throw conflict(hint('購物車中有書籍已被其他買家購買，請重新整理後再結帳', '此書籍已被其他買家購買'));
      }

      const totalAmount = items.reduce((sum, i) => sum + lineTotal(i), 0);
      const cabinetId = items[0].books.cabinet_id ?? null;

      const released = await releaseDeposits(tx, bookIds, cabinetId);
      const inCabinet = released.missing === 0
        && (await tx.smart_cabinets.count({ where: { cabinet_id: cabinetId, is_active: true } })) > 0;
      const now = new Date();

      const order = await tx.orders.create({
        data: {
          order_no: buildOrderNo(),
          buyer_id: buyerId,
          seller_id: sellerId,
          total_amount: totalAmount,
          cabinet_id: cabinetId,
          status: inCabinet ? 'deposited' : 'pending_deposit',
          ...(inCabinet && { deposited_at: now }),
          payment_method: paymentMethod,
          payment_at: now,
          order_items: {
            create: items.map((i) => ({
              book_id: i.book_id,
              quantity: 1,
              unit_price: i.books.price,
              subtotal: lineTotal(i),
              pre_deposited: released.stored.has(i.book_id)
            }))
          }
        },
        include: orderInclude
      });

      await changeBalance(tx, buyerId, {
        amount: -totalAmount,
        type: 'purchase',
        orderId: order.order_id,
        description: `購買訂單 ${order.order_no}`,
        counters: { total_expense: { increment: totalAmount } }
      });

      await notify(tx, {
        userId: sellerId,
        type: 'order',
        title: '書籍已售出',
        content: sellerContent(order.order_no, { inCabinet, stored: released.stored.size }),
        relatedId: order.order_id,
        relatedType: 'order'
      });

      if (inCabinet) {
        const cabinet = order.smart_cabinets?.cabinet_name;
        await notify(tx, {
          userId: buyerId,
          type: 'order',
          title: '書籍已存入書櫃',
          content: `訂單 ${order.order_no} 的書籍已存放於${cabinet ? `「${cabinet}」` : ''}書櫃，即日起可於營業時間內至書櫃以 App 掃描 QR Code 取書。`,
          relatedId: order.order_id,
          relatedType: 'order'
        });
      }

      results.push(order);
    }

    const cartIds = cartItems.map((i) => i.cart_id).filter((id) => id != null);
    if (cartIds.length > 0) await tx.shopping_cart.deleteMany({ where: { cart_id: { in: cartIds } } });
    if (alsoRemoveBookIds.length > 0) {
      await tx.shopping_cart.deleteMany({ where: { user_id: buyerId, book_id: { in: alsoRemoveBookIds } } });
    }
    return results;
  });
};

module.exports = { checkout, buyNow };
