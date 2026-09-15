const { HttpError } = require('../../lib/errors');
const { hasTables } = require('../../lib/schema-check');

const V2_TABLES = ['chat_room_members', 'chat_room_pins', 'chat_aliases', 'chat_transfers'];

const isV2 = () => hasTables(V2_TABLES);

const unavailable = () => new HttpError(503, '伺服器尚未完成資料庫更新，請聯絡管理員', 'CHAT_V2_UNAVAILABLE');

const requireV2 = async () => {
  if (!(await isV2())) throw unavailable();
};

module.exports = { isV2, requireV2, unavailable };
