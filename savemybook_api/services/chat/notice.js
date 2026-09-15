const { userBrief } = require('../../lib/selects');
const { notify, notifyMany } = require('../notify');

const post = async (tx, { roomId, actorId, text }) => {
  const message = await tx.chat_messages.create({
    data: { room_id: roomId, sender_id: actorId, content: text, message_type: 'system', is_read: true },
    include: { users: { select: userBrief } }
  });
  await tx.chat_rooms.update({ where: { room_id: roomId }, data: { updated_at: new Date() } });
  return message;
};

// 群組通知內文以「暱稱：」開頭，推播派送時會換成收件者為發送者設定的自訂暱稱。
const notifyMembers = (tx, { room, actor, userIds, preview, withSender = true }) => {
  if (userIds.length === 0) return null;
  const group = room.room_type === 'group';
  const payload = {
    type: 'message',
    title: group ? room.name : actor.nickname || '新訊息',
    content: group && withSender ? `${actor.nickname}：${preview}` : preview,
    relatedId: room.room_id,
    relatedType: 'chat_room',
    actorId: actor.user_id
  };
  return group ? notifyMany(tx, userIds, payload) : notify(tx, { ...payload, userId: userIds[0] });
};

module.exports = { post, notifyMembers };
