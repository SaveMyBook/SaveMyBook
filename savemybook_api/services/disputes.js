const prisma = require('../lib/prisma');
const { badRequest, forbidden, notFound, conflict } = require('../lib/errors');
const { userBrief, userName, orderItemsWithCover } = require('../lib/selects');
const { DISPUTE_RESULT_LABELS } = require('../constants/domain');
const { DISPUTE_WINDOW_HOURS } = require('../constants/policy');
const { notify } = require('./notify');
const audit = require('./audit');
const settlement = require('./orders/settlement');
const disputeAnalyses = require('./ai/dispute-analyses');

const RESULTS = ['refund_manual', 'refund_auto', 'dismissed', 'mediated'];

// 已取消或已退款的訂單不可申請爭議，否則裁決退款會退第二次。
const NOT_DISPUTABLE = ['cancelled', 'refunded'];

const DISPUTE_WINDOW_MS = DISPUTE_WINDOW_HOURS * 60 * 60 * 1000;

const EVIDENCE_IMAGE = /^\/uploads\/(evidence|books)\/\w[\w.-]*$/;

const evidenceImagesOf = (value) => String(value ?? '')
  .split(',')
  .map((url) => url.trim())
  .filter((url) => EVIDENCE_IMAGE.test(url));

const disputeInclude = {
  orders: {
    select: {
      order_id: true,
      order_no: true,
      total_amount: true,
      status: true,
      order_items: orderItemsWithCover
    }
  },
  users_transaction_disputes_applicant_idTousers: { select: userBrief }
};

const listMine = (userId) => prisma.transaction_disputes.findMany({
  where: { applicant_id: userId },
  orderBy: { created_at: 'desc' },
  include: disputeInclude
});

const create = async (userId, { orderId: givenId, orderNo, reason, evidenceUrls }) => {
  const order = await prisma.orders.findUnique({
    where: orderNo ? { order_no: orderNo } : { order_id: givenId },
    select: { order_id: true, buyer_id: true, seller_id: true, status: true, order_no: true, picked_up_at: true, completed_at: true }
  });
  if (!order) throw notFound('找不到該訂單');
  const orderId = order.order_id;
  if (order.buyer_id !== userId && order.seller_id !== userId) throw forbidden();
  if (NOT_DISPUTABLE.includes(order.status)) throw badRequest('此訂單已取消或已退款，無法申請爭議');
  // 完成訂單即撥款給賣家，之後不再受理爭議。
  if (order.status === 'completed') throw badRequest('訂單已完成，無法再申請爭議', 'DISPUTE_WINDOW_PASSED');
  if (order.picked_up_at && Date.now() - new Date(order.picked_up_at).getTime() > DISPUTE_WINDOW_MS) {
    throw badRequest(`已超過取書後 ${DISPUTE_WINDOW_HOURS} 小時的爭議申請期限`, 'DISPUTE_WINDOW_PASSED');
  }

  // 以訂單為範圍：一方申請後另一方再申請，兩案分別裁決會各自改動同一筆訂單並重複結算。
  const existing = await prisma.transaction_disputes.findFirst({
    where: { order_id: orderId, status: { in: ['pending', 'processing'] } },
    select: { dispute_id: true }
  });
  if (existing) throw conflict('此訂單已有處理中的爭議申請');
  // 開門後改為退款處理中會使取書提交失敗，書在買家手上卻仍記錄在櫃內，裁決退款時又會重建存書登記。
  await require('./cabinet-release').assertNotInSession(orderId);

  return prisma.$transaction(async (tx) => {
    const created = await tx.transaction_disputes.create({
      data: { order_id: orderId, applicant_id: userId, reason, evidence_urls: evidenceUrls },
      include: disputeInclude
    });

    // 以讀取時的狀態為條件，雙方同時申請時只有一方成立。
    const moved = await tx.orders.updateMany({
      where: { order_id: orderId, status: order.status },
      data: { status: 'refunding', updated_at: new Date() }
    });
    if (moved.count === 0) throw conflict('訂單狀態已變更，請重新整理後再試');

    const isBuyer = order.buyer_id === userId;
    await notify(tx, {
      userId: isBuyer ? order.seller_id : order.buyer_id,
      type: 'order',
      title: `${isBuyer ? '買家' : '賣家'}已對訂單申請爭議`,
      content: `訂單 ${order.order_no} 有一筆爭議申請，客服將協助處理，處理期間訂單暫停進行。`,
      relatedId: orderId,
      relatedType: 'order'
    });

    return created;
  });
};

const adminList = async (status) => {
  const rows = await prisma.transaction_disputes.findMany({
    where: { ...(status && { status }) },
    orderBy: { created_at: 'desc' },
    include: {
      users_transaction_disputes_applicant_idTousers: { select: userBrief },
      orders: {
        select: {
          order_id: true, order_no: true, total_amount: true, status: true,
          users_orders_buyer_idTousers: { select: userName },
          users_orders_seller_idTousers: { select: userName },
          order_items: orderItemsWithCover
        }
      }
    }
  });
  return rows.map((d) => ({ ...d, evidence_images: evidenceImagesOf(d.evidence_urls) }));
};

// 依時間欄位推回申請爭議前的狀態，不可一律改成已完成（會替未存書的訂單撥款）。
const restoredStatus = (order) => {
  if (order.completed_at || order.picked_up_at) return 'completed';
  if (order.deposited_at) return 'deposited';
  return 'pending_deposit';
};

const resolve = async (disputeId, { result, adminNote }, { adminId, req }) => {
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
  const alreadyReturned = settlement.phaseOf(order.status) === 'returned';
  let target = isRefund ? 'refunded' : restoredStatus(order);
  if (alreadyReturned) target = order.status;

  const { updated, money } = await prisma.$transaction(async (tx) => {
    // 以狀態為條件更新，避免兩位客服同時裁決。
    const claimed = await tx.transaction_disputes.updateMany({
      where: { dispute_id: disputeId, status: { not: 'resolved' } },
      data: {
        status: 'resolved',
        result,
        admin_id: adminId,
        admin_note: adminNote,
        resolved_at: new Date()
      }
    });
    if (claimed.count === 0) throw conflict('此爭議已裁決');
    await disputeAnalyses.recordResolution(tx, disputeId, result);

    const settled = target === order.status
      ? { paidOut: 0, clawedBack: 0, refunded: 0 }
      : await settlement.transition(tx, order, target);

    if (isRefund) {
      await tx.refund_records.create({
        data: {
          order_id: order.order_id,
          dispute_id: disputeId,
          refund_type: result === 'refund_auto' ? 'auto' : 'manual',
          amount: settled.refunded,
          status: 'completed',
          admin_id: adminId,
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
      await notice(order.seller_id, (settled.clawedBack > 0
        ? `訂單 ${order.order_no} 裁決退款給買家，已從您的錢包收回 ${settled.clawedBack} 代幣。`
        : `訂單 ${order.order_no} 裁決退款給買家，交易已取消。`) + settlement.storedNotice(settled));
    } else {
      const content = `訂單 ${order.order_no} 經審核維持原交易，訂單恢復為「${settlement.statusLabel(target)}」。`
        + (settled.paidOut > 0 ? `貨款 ${settled.paidOut} 代幣已撥入賣家錢包。` : '');
      await notice(order.buyer_id, content);
      await notice(order.seller_id, content);
    }

    return {
      updated: await tx.transaction_disputes.findUnique({ where: { dispute_id: disputeId } }),
      money: settled
    };
  });

  const effect = settlement.describeSettlement(money);
  await audit.record(null, {
    adminId,
    action: '裁決交易爭議',
    targetType: 'dispute',
    targetId: disputeId,
    summary: `裁決訂單 ${order.order_no} 的爭議：${DISPUTE_RESULT_LABELS[result]}`
      + `${effect ? `，${effect}` : ''}${adminNote ? `。備註：${adminNote}` : ''}`,
    changes: [
      { label: '裁決結果', from: '（未裁決）', to: DISPUTE_RESULT_LABELS[result] },
      ...(target !== order.status
        ? [{ label: '訂單狀態', from: settlement.statusLabel(order.status), to: settlement.statusLabel(target) }]
        : [])
    ],
    req
  });
  return updated;
};

module.exports = { DISPUTE_WINDOW_MS, RESULTS, listMine, create, adminList, resolve };
