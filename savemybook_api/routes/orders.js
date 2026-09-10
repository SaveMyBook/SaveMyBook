const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');

const router = express.Router();

// 前端頁籤 -> orders.status 對照表
const BUYER_TABS = {
  pending_pickup: ['pending_payment', 'pending_deposit', 'deposited', 'pending_pickup'],
  completed: ['completed'],
  cancelled: ['cancelled', 'refunded'],
  disputing: ['refunding']
};

const SELLER_TABS = {
  pending_deposit: ['pending_payment', 'pending_deposit'],
  on_sale: ['deposited', 'pending_pickup'],
  cancelled: ['cancelled', 'refunded'],
  completed: ['completed']
};

const orderInclude = {
  order_items: {
    include: {
      books: {
        include: {
          book_images: { select: { image_id: true, image_url: true, image_type: true } },
          book_categories: { select: { category_name: true } }
        }
      }
    }
  },
  smart_cabinets: {
    select: { cabinet_id: true, cabinet_name: true, address: true, open_time: true, close_time: true }
  },
  cabinet_slots: { select: { slot_id: true, slot_number: true } },
  users_orders_buyer_idTousers: { select: { user_id: true, nickname: true, avatar_url: true } },
  users_orders_seller_idTousers: { select: { user_id: true, nickname: true, avatar_url: true } },
  transaction_disputes: { select: { dispute_id: true, status: true, result: true } }
};

const buildOrderNo = () => {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  const stamp = `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
  return `SMB${stamp}${Math.floor(Math.random() * 900 + 100)}`;
};

const buildPickupCode = () => String(Math.floor(Math.random() * 900000 + 100000));

router.get('/', authenticateToken, async (req, res) => {
  const role = req.query.role === 'seller' ? 'seller' : 'buyer';
  const tab = req.query.tab;
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 20;

  const tabMap = role === 'seller' ? SELLER_TABS : BUYER_TABS;
  const statuses = tab ? tabMap[tab] : null;

  if (tab && !statuses) {
    return res.status(400).json({ success: false, message: `不支援的 tab：${tab}` });
  }

  try {
    const where = {
      ...(role === 'seller' ? { seller_id: req.user.userId } : { buyer_id: req.user.userId }),
      ...(statuses && { status: { in: statuses } })
    };

    const [orders, totalCount] = await Promise.all([
      prisma.orders.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { created_at: 'desc' },
        include: orderInclude
      }),
      prisma.orders.count({ where })
    ]);

    res.status(200).json({
      success: true,
      pagination: { total: totalCount, page, limit, total_pages: Math.ceil(totalCount / limit) },
      data: orders
    });
  } catch (err) {
    console.error('[取得訂單列表失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.get('/:id', authenticateToken, async (req, res) => {
  const orderId = parseInt(req.params.id);
  try {
    const order = await prisma.orders.findUnique({ where: { order_id: orderId }, include: orderInclude });
    if (!order) return res.status(404).json({ success: false, message: '找不到該訂單' });
    if (order.buyer_id !== req.user.userId && order.seller_id !== req.user.userId && req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: '存取被拒' });
    }
    res.status(200).json({ success: true, data: order });
  } catch (err) {
    console.error('[取得訂單失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.post('/checkout', authenticateToken, async (req, res) => {
  const cartIds = Array.isArray(req.body.cart_ids) ? req.body.cart_ids.map(Number).filter(Boolean) : null;
  const paymentMethod = req.body.payment_method === 'bank_transfer' ? 'bank_transfer' : 'wallet';

  try {
    const cartItems = await prisma.shopping_cart.findMany({
      where: {
        user_id: req.user.userId,
        ...(cartIds && cartIds.length > 0 && { cart_id: { in: cartIds } })
      },
      include: { books: true }
    });

    if (cartItems.length === 0) {
      return res.status(400).json({ success: false, message: '購物車沒有可結帳的項目' });
    }

    const unavailable = cartItems.find(i => i.books.status !== 'on_sale');
    if (unavailable) {
      return res.status(400).json({ success: false, message: `《${unavailable.books.title}》已無法購買，請先移除` });
    }

    // 舊資料可能存在 0 元的書，這裡再擋一次，避免零元購。
    const invalidPrice = cartItems.find(i => Number(i.books.price) <= 0);
    if (invalidPrice) {
      return res.status(400).json({
        success: false,
        message: `《${invalidPrice.books.title}》的售價異常，請聯絡賣家或先移除`
      });
    }

    const bySeller = new Map();
    for (const item of cartItems) {
      const sellerId = item.books.seller_id;
      if (!bySeller.has(sellerId)) bySeller.set(sellerId, []);
      bySeller.get(sellerId).push(item);
    }

    const grandTotal = cartItems.reduce(
      (sum, i) => sum + Number(i.books.price) * i.quantity,
      0
    );

    const buyerWallet = await prisma.wallets.findUnique({
      where: { user_id: req.user.userId }
    });
    const currentBalance = Number(buyerWallet?.balance ?? 0);

    if (currentBalance < grandTotal) {
      return res.status(400).json({
        success: false,
        code: 'INSUFFICIENT_BALANCE',
        message: `代幣不足，這筆訂單需要 ${grandTotal} 代幣，目前只有 ${currentBalance}`
      });
    }

    const createdOrders = await prisma.$transaction(async (tx) => {
      const results = [];

      // 先把錢從買家帳上扣掉；沒扣成功就不該建立訂單。
      const wallet = await tx.wallets.upsert({
        where: { user_id: req.user.userId },
        update: {},
        create: { user_id: req.user.userId, balance: 0 }
      });

      if (Number(wallet.balance) < grandTotal) throw new Error('INSUFFICIENT_BALANCE');

      let runningBalance = Number(wallet.balance);

      for (const [sellerId, items] of bySeller) {
        const totalAmount = items.reduce((sum, i) => sum + Number(i.books.price) * i.quantity, 0);

        const order = await tx.orders.create({
          data: {
            order_no: buildOrderNo(),
            buyer_id: req.user.userId,
            seller_id: sellerId,
            total_amount: totalAmount,
            cabinet_id: items[0].books.cabinet_id ?? null,
            pickup_code: buildPickupCode(),
            status: 'pending_deposit',
            payment_method: paymentMethod,
            payment_at: new Date(),
            order_items: {
              create: items.map(i => ({
                book_id: i.book_id,
                quantity: i.quantity,
                unit_price: i.books.price,
                subtotal: Number(i.books.price) * i.quantity
              }))
            }
          },
          include: orderInclude
        });

        runningBalance -= Number(totalAmount);

        await tx.wallets.update({
          where: { wallet_id: wallet.wallet_id },
          data: {
            balance: runningBalance,
            total_expense: { increment: Number(totalAmount) },
            updated_at: new Date()
          }
        });

        await tx.wallet_transactions.create({
          data: {
            wallet_id: wallet.wallet_id,
            type: 'purchase',
            amount: -Number(totalAmount),
            balance_after: runningBalance,
            related_order_id: order.order_id,
            description: `購買訂單 ${order.order_no}`
          }
        });

        await tx.books.updateMany({
          where: { book_id: { in: items.map(i => i.book_id) } },
          data: { status: 'reserved', updated_at: new Date() }
        });

        await tx.notifications.create({
          data: {
            user_id: sellerId,
            type: 'order',
            title: '您的書已售出',
            content: `訂單 ${order.order_no} 已成立，請於七天內至書櫃存書。`,
            related_id: order.order_id,
            related_type: 'order'
          }
        });

        results.push(order);
      }

      await tx.shopping_cart.deleteMany({ where: { cart_id: { in: cartItems.map(i => i.cart_id) } } });

      return results;
    });

    res.status(201).json({ success: true, message: '結帳成功', data: createdOrders });
  } catch (err) {
    // 交易內再檢查一次餘額是為了防併發，兩支請求同時結帳時會落在這裡。
    if (err instanceof Error && err.message === 'INSUFFICIENT_BALANCE') {
      return res.status(400).json({
        success: false,
        code: 'INSUFFICIENT_BALANCE',
        message: '代幣不足，請先儲值後再結帳'
      });
    }
    console.error('[結帳失敗]:', err);
    res.status(500).json({ success: false, message: '結帳失敗，請稍後再試' });
  }
});

router.patch('/:id/cancel', authenticateToken, async (req, res) => {
  const orderId = parseInt(req.params.id);
  const reason = req.body.reason || null;

  try {
    const order = await prisma.orders.findUnique({ where: { order_id: orderId }, include: { order_items: true } });
    if (!order) return res.status(404).json({ success: false, message: '找不到該訂單' });
    if (order.buyer_id !== req.user.userId && order.seller_id !== req.user.userId && req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: '存取被拒' });
    }
    if (['completed', 'cancelled', 'refunded'].includes(order.status)) {
      return res.status(400).json({ success: false, message: '此訂單狀態無法取消' });
    }

    const updated = await prisma.$transaction(async (tx) => {
      const o = await tx.orders.update({
        where: { order_id: orderId },
        data: { status: 'cancelled', cancelled_at: new Date(), cancel_reason: reason, updated_at: new Date() },
        include: orderInclude
      });

      await tx.books.updateMany({
        where: { book_id: { in: order.order_items.map(i => i.book_id) } },
        data: { status: 'on_sale', updated_at: new Date() }
      });

      // 結帳時已經從買家帳上扣款，取消就要原路退回。
      const refundable = ['pending_payment', 'pending_deposit', 'deposited', 'pending_pickup'];
      if (refundable.includes(order.status)) {
        const wallet = await tx.wallets.upsert({
          where: { user_id: order.buyer_id },
          update: {},
          create: { user_id: order.buyer_id, balance: 0 }
        });

        const refunded = Number(wallet.balance) + Number(order.total_amount);

        await tx.wallets.update({
          where: { wallet_id: wallet.wallet_id },
          data: {
            balance: refunded,
            total_expense: { decrement: Number(order.total_amount) },
            updated_at: new Date()
          }
        });

        await tx.wallet_transactions.create({
          data: {
            wallet_id: wallet.wallet_id,
            type: 'refund',
            amount: Number(order.total_amount),
            balance_after: refunded,
            related_order_id: orderId,
            description: `訂單 ${order.order_no} 取消退款`
          }
        });

        await tx.notifications.create({
          data: {
            user_id: order.buyer_id,
            type: 'order',
            title: '訂單已退款',
            content: `訂單 ${order.order_no} 已取消，${order.total_amount} 代幣已退回您的帳戶。`,
            related_id: orderId,
            related_type: 'order'
          }
        });
      }

      const notifyUserId = req.user.userId === order.buyer_id ? order.seller_id : order.buyer_id;
      await tx.notifications.create({
        data: {
          user_id: notifyUserId,
          type: 'order',
          title: '訂單已取消',
          content: `訂單 ${order.order_no} 已被取消。${reason ? `原因：${reason}` : ''}`,
          related_id: orderId,
          related_type: 'order'
        }
      });

      return o;
    });

    res.status(200).json({ success: true, message: '訂單已取消', data: updated });
  } catch (err) {
    console.error('[取消訂單失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.patch('/:id/status', authenticateToken, async (req, res) => {
  const orderId = parseInt(req.params.id);
  const status = req.body.status;
  const allowed = ['deposited', 'pending_pickup', 'completed'];

  if (!allowed.includes(status)) {
    return res.status(400).json({ success: false, message: `status 僅接受：${allowed.join(', ')}` });
  }

  try {
    const order = await prisma.orders.findUnique({ where: { order_id: orderId }, include: { order_items: true } });
    if (!order) return res.status(404).json({ success: false, message: '找不到該訂單' });
    if (order.buyer_id !== req.user.userId && order.seller_id !== req.user.userId && req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: '存取被拒' });
    }

    const updated = await prisma.$transaction(async (tx) => {
      const data = { status, updated_at: new Date() };
      if (status === 'deposited') data.deposited_at = new Date();
      if (status === 'completed') {
        data.picked_up_at = order.picked_up_at ?? new Date();
        data.completed_at = new Date();
      }

      const o = await tx.orders.update({ where: { order_id: orderId }, data, include: orderInclude });

      if (status === 'completed') {
        await tx.books.updateMany({
          where: { book_id: { in: order.order_items.map(i => i.book_id) } },
          data: { status: 'sold', updated_at: new Date() }
        });

        const wallet = await tx.wallets.upsert({
          where: { user_id: order.seller_id },
          update: {},
          create: { user_id: order.seller_id }
        });

        const newBalance = Number(wallet.balance) + Number(order.total_amount);
        await tx.wallets.update({
          where: { wallet_id: wallet.wallet_id },
          data: {
            balance: newBalance,
            total_income: Number(wallet.total_income) + Number(order.total_amount),
            updated_at: new Date()
          }
        });

        await tx.wallet_transactions.create({
          data: {
            wallet_id: wallet.wallet_id,
            type: 'sale_income',
            amount: order.total_amount,
            balance_after: newBalance,
            related_order_id: orderId,
            description: '賣出'
          }
        });
      }

      return o;
    });

    res.status(200).json({ success: true, message: '訂單狀態已更新', data: updated });
  } catch (err) {
    console.error('[更新訂單狀態失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

module.exports = router;
