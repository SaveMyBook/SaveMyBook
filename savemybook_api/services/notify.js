const prisma = require('../lib/prisma');

/// notifications.title 是 VARCHAR(255)。標題常由使用者輸入組成（書名、工單主旨），
/// 超長時 MySQL 嚴格模式會讓整個交易失敗。
const clip = (value, max) => (value.length > max ? `${value.slice(0, max - 1)}…` : value);

const toRow = ({ userId, type = 'system', title, content, relatedId = null, relatedType = null }) => ({
  user_id: userId,
  type,
  title: clip(String(title), 255),
  content: String(content),
  related_id: relatedId,
  related_type: relatedType
});

/// db 傳入交易物件 tx 時會跟著同一個交易提交或回滾。
const notify = (db, payload) => (db ?? prisma).notifications.create({ data: toRow(payload) });

const notifyMany = async (db, userIds, payload, batchSize = 500) => {
  const client = db ?? prisma;
  // 單次寫入過多列會長時間鎖表，切批寫入。
  for (let i = 0; i < userIds.length; i += batchSize) {
    await client.notifications.createMany({
      data: userIds.slice(i, i + batchSize).map((userId) => toRow({ ...payload, userId }))
    });
  }
  return userIds.length;
};

module.exports = { notify, notifyMany };
