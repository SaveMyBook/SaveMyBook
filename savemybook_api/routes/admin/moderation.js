const express = require('express');
const prisma = require('../../lib/prisma');
const requireAdmin = require('../../middleware/requireAdmin');
const v = require('../../lib/validate');
const { notFound, conflict } = require('../../lib/errors');
const { REPORT_STATUSES, DISPUTE_STATUSES } = require('../../constants/domain');
const orderFlow = require('../../services/orders');
const { notify } = require('../../services/notify');
const audit = require('../../services/audit');

const REPORT_STATUS_LABELS = { pending: '待處理', reviewing: '審核中', resolved: '違規成立', dismissed: '未違規' };
const DISPUTE_RESULT_LABELS = {
  refund_manual: '人工退款', refund_auto: '自動退款', dismissed: '駁回申訴', mediated: '協調結案'
};

const router = express.Router();

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
  if (report.status === status && REPORT_FINAL.includes(status)) throw conflict('此檢舉已處理');

  let bookBefore = null;
  let bookAfter = null;

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
      const book = await tx.books.findUnique({ where: { book_id: report.target_id } });
      ownerId = book?.seller_id ?? null;

      if (removeTarget && book) {
        bookBefore = book;
        bookAfter = { status: 'removed', is_approved: false };
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
      title: '您的檢舉已處理',
      content: status === 'dismissed' ? '經審核未違反社群規範，感謝您的回報。' : '感謝您的回報，我們已完成處理。',
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
              ? '經審核違規成立，該商品已下架。如有疑問請聯絡客服。'
              : '經審核違規成立，請留意社群規範，重複違規將影響帳號權益。')
          : '經審核未違反社群規範，您的商品／帳號不受影響。',
        relatedId: report.target_id,
        relatedType: report.target_type
      });
    }

    return r;
  });

  const reportFields = {
    status: { label: '檢舉狀態', format: (s) => REPORT_STATUS_LABELS[s] ?? s },
    admin_note: '處理備註'
  };
  const bookFields = { status: '書籍狀態', is_approved: '審核通過' };
  await audit.record(null, {
    adminId: req.user.userId,
    action: '處理檢舉',
    targetType: 'report',
    targetId: reportId,
    summary: `將檢舉 #${reportId} 標為「${REPORT_STATUS_LABELS[status]}」`
      + `${bookBefore ? `，並下架《${bookBefore.title}》` : ''}。已通知檢舉人與被檢舉人（通知無法收回）`,
    changes: [
      ...audit.diff(report, updated, reportFields),
      ...(bookBefore ? audit.diff(bookBefore, bookAfter, bookFields) : [])
    ],
    undo: [
      audit.undoUpdate('reports', reportId, report, updated, ['status', 'admin_id', 'admin_note', 'resolved_at']),
      ...(bookBefore ? [audit.undoUpdate('books', bookBefore.book_id, bookBefore, bookAfter, bookFields)] : [])
    ],
    req
  });
  res.status(200).json({ success: true, message: '檢舉已處理', data: updated });
});

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

// 依時間欄位推回申訴前狀態，不可一律改成已完成（會替未存書的訂單撥款）。
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
  // 已結案的案件再裁決會重複退款。
  if (dispute.status === 'resolved') throw conflict('此爭議已裁決');

  const order = dispute.orders;
  const isRefund = result === 'refund_manual' || result === 'refund_auto';

  // 爭議期間若已手動取消或退款，只結案不動訂單，避免重複退款。
  const alreadyReturned = orderFlow.phaseOf(order.status) === 'returned';
  let target = isRefund ? 'refunded' : restoredStatus(order);
  if (alreadyReturned) target = order.status;

  const { updated, money } = await prisma.$transaction(async (tx) => {
    // 以狀態為條件更新，避免兩位客服同時裁決。
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
    if (claimed.count === 0) throw conflict('此爭議已裁決');

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
      const content = `訂單 ${order.order_no} 經審核維持原交易，訂單恢復為「${orderFlow.statusLabel(target)}」。`
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
  await audit.record(null, {
    adminId: req.user.userId,
    action: '仲裁交易爭議',
    targetType: 'dispute',
    targetId: disputeId,
    summary: `裁決訂單 ${order.order_no} 的爭議：${DISPUTE_RESULT_LABELS[result]}`
      + `${effect ? `，${effect}` : ''}${adminNote ? `。備註：${adminNote}` : ''}`,
    changes: [
      { label: '裁決結果', from: '（未裁決）', to: DISPUTE_RESULT_LABELS[result] },
      ...(target !== order.status
        ? [{ label: '訂單狀態', from: orderFlow.statusLabel(order.status), to: orderFlow.statusLabel(target) }]
        : [])
    ],
    req
  });
  res.status(200).json({ success: true, message: '爭議已裁決', data: updated });
});

module.exports = router;
