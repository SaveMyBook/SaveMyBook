const { userBrief } = require('../../lib/selects');
const { notify, notifyMany } = require('../notify');

const MENTION_SEPARATOR = ' 提及了您：';

const post = async (tx, { roomId, actorId, text }) => {
  const message = await tx.chat_messages.create({
    data: { room_id: roomId, sender_id: actorId, content: text, message_type: 'system', is_read: true },
    include: { users: { select: userBrief } }
  });
  await tx.chat_rooms.update({ where: { room_id: roomId }, data: { updated_at: new Date() } });
  return message;
};

// 群組通知內文以「暱稱：」或「暱稱 提及了您：」開頭，推播派送時會換成收件者為發送者設定的自訂暱稱；
// 推播派送也依後者判斷為提及通知並略過靜音，兩種格式須與 services/push/dispatcher.js 一致。
const notifyMembers = async (tx, { room, actor, userIds, preview, withSender = true, mentionedIds = [] }) => {
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
  if (!group) return notify(tx, { ...payload, userId: userIds[0] });

  const mentioned = new Set(mentionedIds);
  const others = userIds.filter((id) => !mentioned.has(id));
  const targeted = userIds.filter((id) => mentioned.has(id));
  if (others.length > 0) await notifyMany(tx, others, payload);
  if (targeted.length > 0) {
    await notifyMany(tx, targeted, { ...payload, content: `${actor.nickname}${MENTION_SEPARATOR}${preview}` });
  }
  return userIds.length;
};

module.exports = { MENTION_SEPARATOR, post, notifyMembers };
