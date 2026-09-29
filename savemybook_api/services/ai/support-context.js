const prisma = require('../../lib/prisma');
const {
  ORDER_NO_SOURCE, ORDER_STATUS_LABELS, BOOK_STATUS_LABELS, TICKET_STATUS_LABELS, DISPUTE_RESULT_LABELS
} = require('../../constants/domain');
const timeline = require('../orders/timeline');
const { promptText } = require('./text');
const consent = require('./consent');

const RECENT_ORDERS = 5;
const RECENT_DISPUTES = 3;
const RECENT_TRANSACTIONS = 5;
const MAX_REFERENCED_ORDERS = 3;
// 同意說明第 3 版起才列出交易爭議、錢包收支與訊息中提及的訂單；以舊版說明同意的使用者不送出這三類資料。
const EXTENDED_NOTICE_VERSION = 3;

const ORDER_NO = new RegExp(`(?<![A-Za-z0-9])${ORDER_NO_SOURCE}(?!\\d)`, 'gi');
const ANY_ORDER_NO = /(?<![A-Za-z0-9])SMB\d+/gi;

const IN_CABINET = ['deposited', 'pending_pickup'];
// 與 App 訂單詳情頁的狀態名稱一致（lib/utils/app_labels.dart）。
const BUYER_STATUS = { pending_deposit: '待賣家存書', deposited: '待取書', pending_pickup: '待取書' };
const SELLER_STATUS = { pending_pickup: '待取書' };
const RESERVATION_LABELS = { pending: '待賣家回覆', confirmed: '已保留', cancelled: '已取消', expired: '已過期' };
const DISPUTE_STATUS_LABELS = { pending: '待受理', processing: '處理中', resolved: '已裁決' };
const WALLET_TYPE_LABELS = {
  deposit: '儲值', withdrawal: '提領', purchase: '購買', sale_income: '賣出',
  refund: '退款', admin_adjust: '系統調整', transfer_in: '轉入', transfer_out: '轉出'
};

const timeText = (d) => (d
  ? new Date(d).toLocaleString('zh-TW', {
    timeZone: 'Asia/Taipei', hour12: false, year: 'numeric', month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit'
  })
  : '');

const orderNosIn = (text) => [...new Set([...String(text ?? '').matchAll(ORDER_NO)].map((m) => m[0].toUpperCase()))];

const referencedOrderNos = (texts) => [...new Set(texts.flatMap(orderNosIn))].slice(0, MAX_REFERENCED_ORDERS);

// 使用者自己寫出的編號（含格式不完整的）回覆時可以照引，stripUnknownOrderNos 不移除。
const typedOrderNos = (texts) => new Set(texts.flatMap((t) => [...String(t ?? '').matchAll(ANY_ORDER_NO)].map((m) => m[0].toUpperCase())));

const REMOVED = '\u0000';
const REMOVED_GAP = /(\S?)[ \t]*\u0000(?:[ \t]*\u0000)*[ \t]*(\S?)/g;
const WORD_CHAR = /[A-Za-z0-9]/;

const stripUnknownOrderNos = (text, known) => {
  let removed = false;
  const kept = text.replace(ANY_ORDER_NO, (match) => {
    if (known.has(match.toUpperCase())) return match;
    removed = true;
    return REMOVED;
  });
  if (!removed) return text;
  return kept
    .replace(REMOVED_GAP, (_, before, after) => `${before}${WORD_CHAR.test(before) && WORD_CHAR.test(after) ? ' ' : ''}${after}`)
    .replace(/[（(][)）]|「」/g, '')
    .trim();
};

// 單一查詢失敗時略過該區塊，不讓整個客服回覆失敗。
const safely = async (label, run) => {
  try {
    return await run();
  } catch (err) {
    console.error(`[AI 客服使用者資料：${label}]`, err.message);
    return null;
  }
};

const section = (title, rows) => `${title}：\n${rows && rows.length ? rows.join('\n') : '（無）'}`;
const bookTitle = (title) => `《${promptText(title ?? '', 60)}》`;
const amountText = (value) => `${Number(value) > 0 ? '+' : ''}${Number(value)} 代幣`;

const parseReasons = (value) => {
  try {
    const list = JSON.parse(String(value ?? '[]'));
    return Array.isArray(list) ? list.filter((x) => typeof x === 'string').slice(0, 3) : [];
  } catch {
    return [];
  }
};

const statusText = (order, role) => {
  if (IN_CABINET.includes(order.status) && order.picked_up_at) {
    return role === 'buyer' ? '待完成訂單（已取書）' : '待買家確認（買家已取書）';
  }
  const override = (role === 'buyer' ? BUYER_STATUS : SELLER_STATUS)[order.status];
  return override ?? ORDER_STATUS_LABELS[order.status] ?? order.status;
};

const DISPUTE_CLOSED_TEXT = {
  in_progress: '爭議處理中，訂單暫停進行，待管理員裁決',
  completed: '訂單已完成，不再受理爭議',
  cancelled: '已取消的訂單不可申請爭議',
  refunded: '已退款的訂單不可申請爭議',
  expired: '已超過取書後的爭議期限，不可再申請爭議'
};

const timelineText = (order, now) => {
  const t = timeline.timelineOf(order, now);
  const overdue = (deadline) => (deadline.getTime() < now.getTime() ? '（已逾期，系統將自動取消並全額退款）' : '');
  const parts = [];
  if (order.deposited_at) parts.push(`存書 ${timeText(order.deposited_at)}`);
  if (order.picked_up_at) parts.push(`取書 ${timeText(order.picked_up_at)}`);
  if (order.status === 'completed' && order.completed_at) parts.push(`完成 ${timeText(order.completed_at)}，款項已撥給賣家`);
  if (order.status === 'cancelled' && order.cancelled_at) parts.push(`取消 ${timeText(order.cancelled_at)}`);
  if (t.deposit_deadline) parts.push(`存書期限 ${timeText(t.deposit_deadline)}${overdue(t.deposit_deadline)}`);
  if (t.pickup_deadline) parts.push(`取書期限 ${timeText(t.pickup_deadline)}${overdue(t.pickup_deadline)}`);
  if (t.auto_complete_at) {
    parts.push(`買家未先完成訂單且未申請爭議時，預計 ${timeText(t.auto_complete_at)} 自動完成並撥款給賣家`);
  }
  if (t.dispute.open) {
    parts.push(t.dispute.deadline ? `爭議須於 ${timeText(t.dispute.deadline)} 前申請` : '取書前可隨時申請爭議');
  } else {
    parts.push(DISPUTE_CLOSED_TEXT[t.dispute.reason]);
  }
  return parts.join('；');
};

const ORDER_SELECT = {
  order_no: true, buyer_id: true, status: true, total_amount: true, created_at: true,
  deposited_at: true, picked_up_at: true, completed_at: true, cancelled_at: true,
  smart_cabinets: { select: { cabinet_name: true } },
  order_items: { select: { books: { select: { title: true } } } }
};

const orderLine = (order, role, now) => {
  const titles = (order.order_items ?? []).map((i) => bookTitle(i.books?.title)).join('、');
  const cabinet = order.smart_cabinets?.cabinet_name ? `，書櫃：${promptText(order.smart_cabinets.cabinet_name, 40)}` : '';
  return `- 訂單 ${order.order_no}：${statusText(order, role)}，${Number(order.total_amount)} 代幣，`
    + `${timeText(order.created_at)} 成立${cabinet}，${titles}；${timelineText(order, now)}`;
};

const bookLine = (b) => {
  const review = b.ai_book_reviews;
  let state = BOOK_STATUS_LABELS[b.status] ?? b.status;
  if (!b.is_approved && review?.status === 'pending') state = '審核中（尚未公開）';
  else if (!b.is_approved && review?.status === 'rejected') state = '未通過審核（已下架）';
  else if (!b.is_approved) state = '因違規下架';
  const reasons = !b.is_approved ? parseReasons(review?.reasons) : [];
  return `- ${bookTitle(b.title)}：${state}，售價 ${Number(b.price)} 代幣${reasons.length ? `，審核原因：${reasons.map((r) => promptText(r, 60)).join('、')}` : ''}`;
};

// 只放請求者本人的資料，不含交易對象的任何個人資料（聊天室轉帳的說明含對方暱稱，故不帶說明文字）。
const build = async (userId, { referenced = [], now = new Date() } = {}) => {
  const extended = (await safely('同意說明版本', () => consent.noticeVersionOf(userId))) >= EXTENDED_NOTICE_VERSION;
  const lookup = extended ? referenced : [];
  const ownOrders = { OR: [{ buyer_id: userId }, { seller_id: userId }] };
  const walletQuery = safely('錢包', () => prisma.wallets.findUnique({ where: { user_id: userId }, select: { wallet_id: true, balance: true } }));

  const [bought, sold, mentioned, disputes, reservations, books, wallet, transactions, tickets] = await Promise.all([
    safely('購買訂單', () => prisma.orders.findMany({
      where: { buyer_id: userId }, orderBy: { created_at: 'desc' }, take: RECENT_ORDERS, select: ORDER_SELECT
    })),
    safely('銷售訂單', () => prisma.orders.findMany({
      where: { seller_id: userId }, orderBy: { created_at: 'desc' }, take: RECENT_ORDERS, select: ORDER_SELECT
    })),
    lookup.length === 0 ? [] : safely('提到的訂單', () => prisma.orders.findMany({
      where: { order_no: { in: lookup }, ...ownOrders }, select: ORDER_SELECT
    })),
    !extended ? null : safely('交易爭議', () => prisma.transaction_disputes.findMany({
      where: { orders: { is: ownOrders } },
      orderBy: { created_at: 'desc' },
      take: RECENT_DISPUTES,
      select: { applicant_id: true, status: true, result: true, created_at: true, resolved_at: true, orders: { select: { order_no: true } } }
    })),
    safely('預約', () => prisma.reservations.findMany({
      where: { buyer_id: userId },
      orderBy: { created_at: 'desc' },
      take: 5,
      select: { status: true, pickup_deadline: true, created_at: true, books: { select: { title: true } } }
    })),
    safely('上架書籍', () => prisma.books.findMany({
      where: { seller_id: userId },
      orderBy: { updated_at: 'desc' },
      take: 8,
      select: {
        title: true, price: true, status: true, is_approved: true, created_at: true,
        ai_book_reviews: { select: { status: true, reasons: true } }
      }
    })),
    walletQuery,
    walletQuery.then((w) => (!extended || w?.wallet_id == null ? [] : safely('錢包收支', () => prisma.wallet_transactions.findMany({
      where: { wallet_id: w.wallet_id },
      orderBy: [{ created_at: 'desc' }, { txn_id: 'desc' }],
      take: RECENT_TRANSACTIONS,
      select: { type: true, amount: true, created_at: true, orders: { select: { order_no: true } } }
    })))),
    safely('提問紀錄', () => prisma.support_tickets.findMany({
      where: { user_id: userId },
      orderBy: { updated_at: 'desc' },
      take: 3,
      select: { subject: true, status: true, updated_at: true }
    }))
  ]);

  const orderNos = new Set();
  const remember = (no) => {
    if (no) orderNos.add(String(no).toUpperCase());
  };
  const lines = (list, role) => (list ?? []).map((o) => {
    remember(o.order_no);
    return orderLine(o, role ?? (Number(o.buyer_id) === Number(userId) ? 'buyer' : 'seller'), now);
  });

  const listed = new Set([...(bought ?? []), ...(sold ?? [])].map((o) => String(o.order_no).toUpperCase()));
  const found = new Map((mentioned ?? []).map((o) => [String(o.order_no).toUpperCase(), o]));
  const mentionedLines = lookup
    .filter((no) => !listed.has(no))
    .map((no) => (found.has(no) ? lines([found.get(no)])[0] : `- 訂單 ${no}：查無資料（不存在或非本人的訂單）`));

  const disputeLines = (disputes ?? []).map((d) => {
    remember(d.orders?.order_no);
    const result = d.result ? `，結果：${DISPUTE_RESULT_LABELS[d.result] ?? d.result}` : '';
    const resolved = d.resolved_at ? `，${timeText(d.resolved_at)} 裁決` : '';
    return `- 訂單 ${d.orders?.order_no ?? '（無編號）'}：${Number(d.applicant_id) === Number(userId) ? '本人申請' : '交易對象申請'}，`
      + `${DISPUTE_STATUS_LABELS[d.status] ?? d.status}${result}，${timeText(d.created_at)} 申請${resolved}`;
  });

  const transactionLines = (transactions ?? []).map((t) => {
    remember(t.orders?.order_no);
    const order = t.orders?.order_no ? `（訂單 ${t.orders.order_no}）` : '';
    return `- ${timeText(t.created_at)}：${WALLET_TYPE_LABELS[t.type] ?? t.type}，${amountText(t.amount)}${order}`;
  });

  const text = [
    wallet ? `錢包餘額：${Number(wallet.balance)} 代幣` : '錢包餘額：（無資料）',
    ...(extended ? [section('最近的錢包收支', transactionLines)] : []),
    section('最近購買的訂單（我是買家）', lines(bought, 'buyer')),
    section('最近售出的訂單（我是賣家）', lines(sold, 'seller')),
    ...(mentionedLines.length ? [section('訊息中提到的訂單', mentionedLines)] : []),
    ...(extended ? [section('最近的交易爭議', disputeLines)] : []),
    section('我上架的書籍', books?.map(bookLine)),
    section('我的預約', reservations?.map((r) => `- 預約${bookTitle(r.books?.title)}：${RESERVATION_LABELS[r.status] ?? r.status}${r.pickup_deadline ? `，保留至 ${timeText(r.pickup_deadline)}` : ''}`)),
    section('我的客服提問', tickets?.map((t) => `- 「${promptText(t.subject, 60)}」：${TICKET_STATUS_LABELS[t.status] ?? t.status}，${timeText(t.updated_at)} 更新`))
  ].join('\n');

  return { text, orderNos };
};

module.exports = {
  MAX_REFERENCED_ORDERS, EXTENDED_NOTICE_VERSION, timeText, orderNosIn, referencedOrderNos, typedOrderNos, stripUnknownOrderNos,
  statusText, timelineText, build
};
