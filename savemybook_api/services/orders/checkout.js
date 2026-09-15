const crypto = require('crypto');
const prisma = require('../../lib/prisma');
const { badRequest, conflict } = require('../../lib/errors');
const { changeBalance } = require('../wallet');
const { notify } = require('../notify');
const reservations = require('../reservations');
const { orderInclude } = require('./selects');

const pad = (n) => String(n).padStart(2, '0');

const buildOrderNo = () => {
  const d = new Date();
  const stamp = `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
  // 一次結帳同一秒會產生多個編號，亂數段需夠長以免撞唯一索引。
  return `SMB${stamp}${crypto.randomInt(100000, 1000000)}`;
};

const buildPickupCode = () => String(crypto.randomInt(100000, 1000000));

const itemQuantity = (item) => Math.max(1, Math.min(item.quantity, item.books.quantity || 1));

const checkout = async (buyerId, { cartIds, paymentMethod }) => {
  const cartItems = await prisma.shopping_cart.findMany({
    where: {
      user_id: buyerId,
      ...(cartIds && cartIds.length > 0 && { cart_id: { in: cartIds } })
    },
    include: { books: true }
  });

  if (cartItems.length === 0) throw badRequest('購物車沒有可結帳的項目');

  const unavailable = cartItems.find((i) => i.books.status !== 'on_sale');
  if (unavailable) throw badRequest(`《${unavailable.books.title}》已無法購買，請先移除`);

  await reservations.assertNotHeldByOthers(null, cartItems.map((i) => i.books), buyerId);

  const ownBook = cartItems.find((i) => i.books.seller_id === buyerId);
  if (ownBook) throw badRequest(`《${ownBook.books.title}》為您上架的書籍，無法購買`);

  // 既有資料可能有售價 0 的書，結帳時須再擋一次。
  const invalidPrice = cartItems.find((i) => !(Number(i.books.price) > 0));
  if (invalidPrice) {
    throw badRequest(`《${invalidPrice.books.title}》的售價異常，請聯絡賣家或先移除`);
  }

  const bySeller = new Map();
  for (const item of cartItems) {
    const sellerId = item.books.seller_id;
    if (!bySeller.has(sellerId)) bySeller.set(sellerId, []);
    bySeller.get(sellerId).push(item);
  }

  const lineTotal = (i) => Number(i.books.price) * itemQuantity(i);
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

    for (const [sellerId, items] of bySeller) {
      const bookIds = items.map((i) => i.book_id);

      // 先把書鎖成保留中，兩個買家同時結帳時只有一人的 count 對得上。
      const reserved = await tx.books.updateMany({
        where: { book_id: { in: bookIds }, status: 'on_sale' },
        data: { status: 'reserved', updated_at: new Date() }
      });
      if (reserved.count !== bookIds.length) {
        throw conflict('購物車中有書籍已被其他買家購買，請重新整理後再結帳');
      }

      const totalAmount = items.reduce((sum, i) => sum + lineTotal(i), 0);

      const order = await tx.orders.create({
        data: {
          order_no: buildOrderNo(),
          buyer_id: buyerId,
          seller_id: sellerId,
          total_amount: totalAmount,
          cabinet_id: items[0].books.cabinet_id ?? null,
          pickup_code: buildPickupCode(),
          status: 'pending_deposit',
          payment_method: paymentMethod,
          payment_at: new Date(),
          order_items: {
            create: items.map((i) => ({
              book_id: i.book_id,
              quantity: itemQuantity(i),
              unit_price: i.books.price,
              subtotal: lineTotal(i)
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
        title: '您的書已售出',
        content: `訂單 ${order.order_no} 已成立，請於七天內至書櫃存書。`,
        relatedId: order.order_id,
        relatedType: 'order'
      });

      results.push(order);
    }

    await tx.shopping_cart.deleteMany({ where: { cart_id: { in: cartItems.map((i) => i.cart_id) } } });
    return results;
  });
};

module.exports = { checkout };
