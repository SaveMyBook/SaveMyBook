// Prisma 的 tagged template 不會展開陣列，IN 清單改用 $queryRawUnsafe 搭配 ? 佔位符。
const placeholders = (values) => values.map(() => '?').join(',');

module.exports = { placeholders };
