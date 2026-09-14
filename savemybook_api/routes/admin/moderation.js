const express = require('express');
const prisma = require('../../lib/prisma');
const requireAdmin = require('../../middleware/requireAdmin');
const v = require('../../lib/validate');
const { notFound, conflict } = require('../../lib/errors');
const { REPORT_STATUSES, DISPUTE_STATUSES } = require('../../constants/domain');
const orderFlow = require('../../services/orders');
const { notify } = require('../../services/notify');
const { logAction } = require('../../services/audit');

const router = express.Router();

// ---------- 檢舉 ----------

router.get('/reports', requireAdmin('reports'), async (req, res) => {
  const status = req.query.status ? v.oneOf(req.query.status, REPORT_STATUSES, '不支援的檢舉狀態') : null;

  const reports = await prisma.reports.findMany({
    where: { ...(status && { status }) },
    orderBy: { created_at: 'desc' },
    include: {
      users_reports_reporter_idTousers: { select: { user_id: true, nickname: true, avatar_url: true } },
      users_reports_admin_idTousers: { select: { user_id: true, nickname: true } }
    }
  });

  const bookIds = reports.filter((r) => r.target_type === 'book').map((r) => r.target_id);
  const userIds = reports.filter((r) => r.target_type === 'user').map((r) => r.target_id);

  const [books, users] = await Promise.all([
    bookIds.length
      ? prisma.books.findMany({
          where: { book_id: { in: bookIds } },
          select: { book_id: true, title: true, price: true, status: true, book_images: { select: { image_url: true }, take: 1 } }
        })
      : [],
    userIds.length
      ? prisma.users.findMany({
          where: { user_id: { in: userIds } },
          select: { user_id: true, nickname: true, avatar_url: true }
        })
      : []
  ]);

  const bookMap = new Map(books.map((b) => [b.book_id, b]));
  const userMap = new Map(users.map((u) => [u.user_id, u]));

  const data = reports.map((r) => ({
    ...r,
    target: r.target_type === 'book' ? bookMap.get(r.target_id) ?? null
      : r.target_type === 'user' ? userMap.get(r.target_id) ?? null
        : null
  }));

  res.status(200).json({ success: true, data });
});

const REPORT_RESULTS = ['reviewing', 'resolved', 'dismissed'];
const REPORT_FINAL = ['resolved', 'dismissed'];

router.patch('/reports/:id', requireAdmin('reports'), async (req, res) => {
  const reportId = v.id(req.params.id, '檢舉編號');
  const status = v.oneOf(req.body.status, REPORT_RESULTS, `status 僅接受：${REPORT_RESULTS.join(', ')}`);
  const adminNote = v.optionalText(req.body.admin_note, { label: '處理備註', max: 2000 }) ?? null;
  const removeTarget = v.bool(req.body.remove_target);

  const report = await prisma.reports.findUnique({ where: { report_id: reportId } });
  if (!report) throw notFound('找不到該檢舉');
  // 同一個結果重送一次，會讓檢舉人與被檢舉人各多收一則通知。
  if (report.status === status && REPORT_FINAL.includes(status)) throw conflict('這則檢舉已經處理過了');

  const updated = await prisma.$transaction(async (tx) => {
    const r = await tx.reports.update({
      where: { report_id: reportId },
      data: {
        status,
        admin_id: req.user.userId,
        admin_note: adminNote,
        resolved_at: REPORT_FINAL.includes(status) ? new Date() : null
      }
    });

    let ownerId = null;
    if (report.target_type === 'book') {
      const book = await tx.books.findUnique({ where: { book_id: report.target_id }, select: { seller_id: true } });
      ownerId = book?.seller_id ?? null;

      if (removeTarget && book) {
        await tx.books.update({
          where: { book_id: report.target_id },
          data: { status: 'removed', is_approved: false, updated_at: new Date() }
        });
      }
    } else if (report.target_type === 'user') {
      ownerId = report.target_id;
    }

    await notify(tx, {
      userId: report.reporter_id,
      title: '你的檢舉已處理',
      content: status === 'dismissed' ? '經審核後未違反社群規範，感謝你的回報。' : '感謝你的回報，我們已完成處理。',
      relatedId: reportId,
      relatedType: 'report'
    });

    if (ownerId && ownerId !== report.reporter_id) {
      const resolved = status === 'resolved';
      await notify(tx, {
        userId: ownerId,
        title: resolved ? '檢舉審核結果：違規成立' : '檢舉審核結果：未違規',
        content: resolved
          ? (removeTarget && report.target_type === 'book'
              ? '經審核違規成立，該商品已被下架。如有疑問請聯絡客服。'
              : '經審核違規成立，請留意社群規範，重複違規將影響帳號權益。')
          : '經審核後未違反社群規範，你的商品／帳號不受影響。',
        relatedId: report.target_id,
        relatedType: report.target_type
      });
    }

    return r;
  });

  await logAction(req.user.userId, '處理商品檢舉', 'report', reportId, status);
  res.status(200).json({ success: true, message: '檢舉已處理', data: updated });
});

// ---------- 交易爭議 ----------

router.get('/disputes', requireAdmin('transactions'), async (req, res) => {
  const status = req.query.status ? v.oneOf(req.query.status, DISPUTE_STATUSES, '不支援的爭議狀態') : null;

  const disputes = await prisma.transaction_disputes.findMany({
    where: { ...(status && { status }) },
    orderBy: { created_at: 'desc' },
    include: {
      users_transaction_disputes_applicant_idTousers: { select: { user_id: true, nickname: true, avatar_url: true } },
      orders: {
        select: {
          order_id: true, order_no: true, total_amount: true, status: true,
          users_orders_buyer_idTousers: { select: { user_id: true, nickname: true } },
          users_orders_seller_idTousers: { select: { user_id: true, nickname: true } },
          order_items: {
            include: { books: { select: { title: true, book_images: { select: { image_url: true }, take: 1 } } } }
          }
        }
      }
    }
  });
  res.status(200).json({ success: true, data: disputes });
});

const DISPUTE_RESULTS = ['refund_manual', 'refund_auto', 'dismissed', 'mediated'];

/// 駁回或調解後訂單回到申訴前的位置，由時間欄位推回來：
/// 完成過就回到已完成（此時才撥款給賣家），存過書就回到已存書，否則回到待存書。
/// 過去一律改成已完成，賣家還沒存書的訂單也會被當成交易完成。
const restoredStatus = (order) => {
  if (order.completed_at) return 'completed';
  if (order.deposited_at) return 'deposited';
  return 'pending_deposit';
};

router.patch('/disputes/:id', requireAdmin('transactions'), async (req, res) => {
  const disputeId = v.id(req.params.id, '爭議編號');
  const result = v.oneOf(req.body.result, DISPUTE_RESULTS, `result 僅接受：${DISPUTE_RESULTS.join(', ')}`);
  const adminNote = v.optionalText(req.body.admin_note, { label: '處理備註', max: 2000 }) ?? null;

  const dispute = await prisma.transaction_disputes.findUnique({
    where: { dispute_id: disputeId },
    include: { orders: { include: { order_items: true } } }
  });
  if (!dispute) throw notFound('找不到該爭議案件');
  // 已結案的案件再裁決一次會重複退款，也會把訂單狀態蓋掉。
  if (dispute.status === 'resolved') throw conflict('這個爭議已經裁決過了');

  const order = dispute.orders;
  const isRefund = result === 'refund_manual' || result === 'refund_auto';

  // 客服可能在爭議期間已經手動取消或退款，那時錢已經退了，只結案不再動訂單。
  const alreadyReturned = orderFlow.phaseOf(order.status) === 'returned';
  let target = isRefund ? 'refunded' : restoredStatus(order);
  if (alreadyReturned) target = order.status;

  const { updated, money } = await prisma.$transaction(async (tx) => {
    // 以狀態為條件更新，兩位客服同時按下裁決時只有一位會成功。
    const claimed = await tx.transaction_disputes.updateMany({
      where: { dispute_id: disputeId, status: { not: 'resolved' } },
      data: {
        status: 'resolved',
        result,
        admin_id: req.user.userId,
        admin_note: adminNote,
        resolved_at: new Date()
      }
    });
    if (claimed.count === 0) throw conflict('這個爭議已經裁決過了');

    const settled = target === order.status
      ? { paidOut: 0, clawedBack: 0, refunded: 0 }
      : await orderFlow.transition(tx, order, target);

    if (isRefund) {
      await tx.refund_records.create({
        data: {
          order_id: order.order_id,
          dispute_id: disputeId,
          refund_type: result === 'refund_auto' ? 'auto' : 'manual',
          amount: settled.refunded,
          status: 'completed',
          admin_id: req.user.userId,
          reason: adminNote,
          processed_at: new Date()
        }
      });
    }

    const notice = (userId, content) => notify(tx, {
      userId,
      type: 'order',
      title: '爭議案件已裁決',
      content,
      relatedId: order.order_id,
      relatedType: 'order'
    });

    if (isRefund) {
      await notice(order.buyer_id, settled.refunded > 0
        ? `訂單 ${order.order_no} 裁決退款，${settled.refunded} 代幣已退回您的錢包。`
        : `訂單 ${order.order_no} 裁決退款，款項先前已退回您的錢包。`);
      await notice(order.seller_id, settled.clawedBack > 0
        ? `訂單 ${order.order_no} 裁決退款給買家，已從您的錢包收回 ${settled.clawedBack} 代幣。`
        : `訂單 ${order.order_no} 裁決退款給買家，交易已取消。`);
    } else {
      const content = `訂單 ${order.order_no} 經審核後維持原交易，訂單回到「${orderFlow.statusLabel(target)}」。`
        + (settled.paidOut > 0 ? `貨款 ${settled.paidOut} 代幣已撥入賣家錢包。` : '');
      await notice(order.buyer_id, content);
      await notice(order.seller_id, content);
    }

    return {
      updated: await tx.transaction_disputes.findUnique({ where: { dispute_id: disputeId } }),
      money: settled
    };
  });

  const effect = orderFlow.describeSettlement(money);
  await logAction(req.user.userId, '仲裁交易爭議', 'dispute', disputeId, effect ? `${result}｜${effect}` : result);
  res.status(200).json({ success: true, message: '爭議已裁決', data: updated });
});

module.exports = router;
