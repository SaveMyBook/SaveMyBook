const prisma = require('../lib/prisma');
const reviews = require('./ai/reviews');

// 等待 AI 審核的書 is_approved 也是 false，但不屬於違規；檢舉成立但未勾選下架時 is_approved 仍為 true，須一併查檢舉紀錄。
const violationLocked = async (book) => (book.is_approved === false && (await reviews.statusOf(book.book_id)) !== 'pending')
  || (await prisma.reports.count({ where: { target_type: 'book', target_id: book.book_id, status: 'resolved' } })) > 0;

module.exports = { violationLocked };
