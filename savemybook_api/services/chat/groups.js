const prisma = require('../../lib/prisma');
const { badRequest, forbidden, notFound } = require('../../lib/errors');
const schema = require('./schema');
const rooms = require('./rooms');
const members = require('./members');
const notice = require('./notice');
const typing = require('./typing');

const MAX_MEMBERS = 100;
const MAX_INVITE = 50;
const MAX_NAME_LENGTH = 50;

const actorOf = async (userId) => {
  const user = await prisma.users.findUnique({ where: { user_id: userId }, select: { nickname: true } });
  return { user_id: userId, nickname: user?.nickname ?? '' };
};

const invitableUsers = async (userIds) => {
  const users = await prisma.users.findMany({
    where: { user_id: { in: userIds } },
    select: { user_id: true, nickname: true, is_active: true, is_blacklisted: true }
  });
  const byId = new Map(users.filter((u) => u.is_active && !u.is_blacklisted).map((u) => [u.user_id, u]));
  if (userIds.some((id) => !byId.has(id))) throw badRequest('成員名單包含無法加入群組的帳號');
  return userIds.map((id) => byId.get(id));
};

const loadGroup = async (roomId, myId) => {
  await schema.requireV2();
  const room = await rooms.findMine(roomId, myId);
  if (!rooms.isGroup(room)) throw badRequest('此操作僅適用於群組聊天室');
  return room;
};

const create = async (myId, { name, memberIds, avatarUrl }) => {
  await schema.requireV2();
  if (memberIds.includes(myId)) throw badRequest('成員名單不可包含自己');
  await invitableUsers(memberIds);
  const actor = await actorOf(myId);
  const v3 = await schema.isV3();
  const now = new Date();

  return prisma.$transaction(async (tx) => {
    const room = await tx.chat_rooms.create({ data: { user_a_id: myId, user_b_id: myId, created_at: now, updated_at: now } });
    const roomId = room.room_id;
    await tx.$executeRaw`
      UPDATE chat_rooms SET room_type = 'group', name = ${name}, avatar_url = ${avatarUrl}, created_by = ${myId}
      WHERE room_id = ${roomId}`;

    const text = `${actor.nickname} 建立了群組`;
    const message = await notice.post(tx, { roomId, actorId: myId, text });
    const historyFromId = v3 ? message.message_id : null;
    await members.join(tx, roomId, [{ userId: myId, role: 'owner' }], {
      joinedAt: now, lastReadId: message.message_id, historyFromId
    });
    await members.join(tx, roomId, memberIds.map((userId) => ({ userId, role: 'member' })), {
      joinedAt: now, lastReadId: message.message_id - 1, historyFromId
    });
    await notice.notifyMembers(tx, {
      room: { room_id: roomId, room_type: 'group', name }, actor, userIds: memberIds, preview: text, withSender: false
    });
    return roomId;
  });
};

const update = async (roomId, myId, { name, avatarUrl }) => {
  const room = await loadGroup(roomId, myId);
  const renamed = name !== undefined && name !== room.name;
  const newAvatar = avatarUrl !== undefined && avatarUrl !== room.avatar_url;

  if (renamed || newAvatar) {
    const actor = await actorOf(myId);
    await prisma.$transaction(async (tx) => {
      if (renamed) {
        await tx.$executeRaw`UPDATE chat_rooms SET name = ${name} WHERE room_id = ${roomId}`;
        await notice.post(tx, { roomId, actorId: myId, text: `${actor.nickname} 將群組名稱變更為「${name}」` });
      }
      if (newAvatar) {
        await tx.$executeRaw`UPDATE chat_rooms SET avatar_url = ${avatarUrl} WHERE room_id = ${roomId}`;
        await notice.post(tx, { roomId, actorId: myId, text: `${actor.nickname} 變更了群組頭貼` });
      }
    });
  }
  return rooms.detail(roomId, myId);
};

const invite = async (roomId, myId, userIds) => {
  const room = await loadGroup(roomId, myId);
  const current = await members.active(roomId);
  const currentIds = new Set(current.map((m) => m.user_id));
  const newIds = userIds.filter((id) => !currentIds.has(id));
  if (newIds.length === 0) return { room_id: roomId, added_user_ids: [] };
  if (current.length + newIds.length > MAX_MEMBERS) {
    throw badRequest(`群組成員上限為 ${MAX_MEMBERS} 人`, 'GROUP_MEMBER_LIMIT');
  }

  const invitees = await invitableUsers(newIds);
  const actor = await actorOf(myId);
  const v3 = await schema.isV3();
  const now = new Date();
  const text = `${actor.nickname} 邀請 ${invitees.map((u) => u.nickname).join('、')} 加入群組`;

  await prisma.$transaction(async (tx) => {
    const message = await notice.post(tx, { roomId, actorId: myId, text });
    await members.join(tx, roomId, newIds.map((userId) => ({ userId, role: 'member' })), {
      joinedAt: now, lastReadId: message.message_id - 1, historyFromId: v3 ? message.message_id : null
    });
    await notice.notifyMembers(tx, { room, actor, userIds: newIds, preview: text, withSender: false });
  });
  return { room_id: roomId, added_user_ids: newIds };
};

const activeTarget = async (roomId, targetId) => {
  const target = (await members.active(roomId)).find((m) => m.user_id === targetId);
  if (!target) throw notFound('此使用者不是群組成員');
  return target;
};

const setRole = async (roomId, myId, targetId, role) => {
  const room = await loadGroup(roomId, myId);
  if (room.my_role !== 'owner') throw forbidden('僅群組管理員可變更成員權限');
  if (targetId === myId) throw badRequest('無法變更自己的管理員身分');

  const target = await activeTarget(roomId, targetId);
  if (target.role !== role) {
    const actor = await actorOf(myId);
    const text = role === 'owner'
      ? `${actor.nickname} 將 ${target.nickname} 設為管理員`
      : `${actor.nickname} 解除 ${target.nickname} 的管理員身分`;
    await prisma.$transaction(async (tx) => {
      await members.setRole(tx, roomId, targetId, role);
      await notice.post(tx, { roomId, actorId: myId, text });
    });
  }
  return rooms.detail(roomId, myId);
};

const removeMember = async (roomId, myId, targetId) => {
  const room = await loadGroup(roomId, myId);
  if (room.my_role !== 'owner') throw forbidden('僅群組管理員可移除成員');
  if (targetId === myId) throw badRequest('無法將自己移出群組，請改用退出群組');

  const target = await activeTarget(roomId, targetId);
  if (target.role === 'owner') throw badRequest('無法移除管理員，請先解除其管理員身分');

  const actor = await actorOf(myId);
  const now = new Date();
  await prisma.$transaction(async (tx) => {
    await members.leave(tx, roomId, targetId, now);
    await members.clearRoomPreferences(tx, roomId, targetId);
    await notice.post(tx, { roomId, actorId: myId, text: `${actor.nickname} 將 ${target.nickname} 移出群組` });
  });
  typing.clear(roomId, targetId);
  return { room_id: roomId, user_id: targetId };
};

const leave = async (roomId, myId) => {
  const room = await loadGroup(roomId, myId);
  const others = (await members.active(roomId)).filter((m) => m.user_id !== myId);
  const now = new Date();

  if (others.length === 0) {
    await prisma.$transaction([
      prisma.chat_messages.deleteMany({ where: { room_id: roomId } }),
      prisma.chat_rooms.delete({ where: { room_id: roomId } })
    ]);
    typing.clear(roomId, myId);
    return { room_id: roomId, deleted: true };
  }

  const actor = await actorOf(myId);
  await prisma.$transaction(async (tx) => {
    await members.leave(tx, roomId, myId, now);
    if (room.my_role === 'owner' && !others.some((m) => m.role === 'owner')) {
      await members.setRole(tx, roomId, others[0].user_id, 'owner');
    }
    await members.clearRoomPreferences(tx, roomId, myId);
    await notice.post(tx, { roomId, actorId: myId, text: `${actor.nickname} 已退出群組` });
  });
  typing.clear(roomId, myId);
  return { room_id: roomId, deleted: false };
};

const removeRoom = async (roomId, myId) => {
  if ((await rooms.typeOf(roomId)) === 'group') {
    await leave(roomId, myId);
    return 'left';
  }
  await rooms.remove(roomId, myId);
  return 'deleted';
};

module.exports = {
  MAX_MEMBERS, MAX_INVITE, MAX_NAME_LENGTH, create, update, invite, setRole, removeMember, leave, removeRoom
};
