const { HttpError } = require('../../lib/errors');
const { hasTables, hasColumn } = require('../../lib/schema-check');

const V2_TABLES = ['chat_room_members', 'chat_room_pins', 'chat_aliases', 'chat_transfers'];

const isV2 = () => hasTables(V2_TABLES);

const isV3 = async () => (await isV2())
  && (await hasTables(['chat_mentions']))
  && (await hasColumn('chat_room_members', 'history_from_id'))
  && hasColumn('chat_messages', 'mentions');

const unavailable = () => new HttpError(503, '此功能暫時無法使用，請稍後再試', 'CHAT_V2_UNAVAILABLE');

const v3Unavailable = () => new HttpError(503, '此功能暫時無法使用，請稍後再試', 'CHAT_V3_UNAVAILABLE');

const requireV2 = async () => {
  if (!(await isV2())) throw unavailable();
};

const requireV3 = async () => {
  if (!(await isV3())) throw v3Unavailable();
};

module.exports = { isV2, isV3, requireV2, requireV3, unavailable };
