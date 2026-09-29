const prisma = require('../lib/prisma');
const { conflict } = require('../lib/errors');
const { ORDER_FINAL_STATUSES } = require('../constants/domain');
const deposits = require('./book-deposits');
const reservations = require('./reservations');

const orders = () => require('./orders');

// 買家已取書（待完成訂單、爭議處理中）的訂單不會因下架而取消，書須維持原狀態，訂單完成時才能正常轉為 sold。
const PICKED_UP_STATUSES = ['deposited', 'pending_pickup', 'refunding'];

const pickedUpOrderCount = (db, bookId) => db.order_items.count({
  where: { book_id: Number(bookId), orders: { status: { in: PICKED_UP_STATUSES }, picked_up_at: { not: null } } }
});

// 須在交易內呼叫；進行中的訂單於交易提交後以 cancelOrders 逐筆取消退款。
// 已完成交易或買家已取書的書只停止公開顯示（hidden），否則訂單紀錄會失去成交狀態。
// 以狀態為條件更新：讀取後才完成的交易，書已是 sold，不可被改為 removed。
const apply = async (tx, book, { now = new Date() } = {}) => {
  const keep = book.status === 'sold' || (await pickedUpOrderCount(tx, book.book_id)) > 0;
  const removed = keep
    ? { count: 0 }
    : await tx.books.updateMany({
        where: { book_id: book.book_id, status: { not: 'sold' } },
        data: { status: 'removed', is_approved: false, updated_at: now }
      });
  if (removed.count === 0) {
    await tx.books.updateMany({ where: { book_id: book.book_id }, data: { is_approved: false, updated_at: now } });
  }
  const hidden = removed.count === 0;
  await deposits.releaseAutoPause(tx, book.book_id);
  const cancelledReservations = await reservations.cancelForDelisted(tx, book, now);
  return {
    data: hidden ? { is_approved: false } : { status: 'removed', is_approved: false },
    hidden,
    reservations: cancelledReservations
  };
};

// 通知與操作紀錄用語：只停止公開顯示的書不可稱為「下架」。
const actionLabel = ({ hidden }) => (hidden ? '停止公開顯示' : '下架');

// 下架已生效，取消失敗時不回報錯誤：未取消的訂單由排程重試。
const cancelOrders = async (bookId, now = new Date()) => {
  try {
    return await orders().cancelDelisted(now, { bookIds: [Number(bookId)] });
  } catch (err) {
    console.error(`[下架書籍的訂單取消失敗] book_id=${bookId}:`, err.message);
    return { cancelled: [], held: [] };
  }
};

const describe = ({ cancelled, held }) => [
  cancelled.length ? `，已取消訂單 ${cancelled.join('、')} 並全額退款` : '',
  held.length ? `，訂單 ${held.join('、')} 書櫃作業中或有待確認紀錄，暫未取消` : ''
].join('');

const assertNoOpenOrder = async (db, bookId) => {
  const open = await (db ?? prisma).order_items.count({
    where: { book_id: bookId, orders: { status: { notIn: ORDER_FINAL_STATUSES } } }
  });
  if (open > 0) throw conflict('此書籍尚有進行中的訂單，無法重新上架', 'BOOK_HAS_OPEN_ORDER');
};

module.exports = { apply, actionLabel, cancelOrders, describe, assertNoOpenOrder };
