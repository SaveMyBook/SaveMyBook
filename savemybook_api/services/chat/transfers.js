const prisma = require('../../lib/prisma');
const { badRequest, conflict, forbidden, notFound } = require('../../lib/errors');
const { userBrief } = require('../../lib/selects');
const wallet = require('../wallet');
const codec = require('./codec');
const controls = require('./controls');
const rooms = require('./rooms');
const members = require('./members');
const notice = require('./notice');
const records = require('./transfer-records');
const realtime = require('../realtime');

const MAX_AMOUNT = 100000;
const MAX_NOTE_LENGTH = 100;
const REQUEST_TTL_MS = 72 * 60 * 60 * 1000;

const stateChanged = () => conflict('此筆請款狀態已變更，請重新整理', 'TRANSFER_STATE_CHANGED');

const counterpartIdOf = async (room, myId, requestedId, selfMessage) => {
  if (requestedId === myId) throw badRequest(selfMessage);
  if (!rooms.isGroup(room)) {
    const partnerId = rooms.partnerIdOf(room, myId);
    if (requestedId != null && requestedId !== partnerId) throw badRequest('對象不是此聊天室的成員');
    return partnerId;
  }
  if (requestedId == null) throw badRequest('請指定對象');
  if (!(await members.isActive(room.room_id, requestedId))) throw badRequest('對象不是此聊天室的成員');
  return requestedId;
};

const reachableUser = async (userId) => {
  const user = await prisma.users.findUnique({
    where: { user_id: userId },
    select: { user_id: true, nickname: true, is_active: true, is_blacklisted: true }
  });
  if (!user || !user.is_active || user.is_blacklisted) throw controls.recipientUnavailable();
  return user;
};

const nameOf = async (userId) => {
  const user = await prisma.users.findUnique({ where: { user_id: userId }, select: { nickname: true } });
  return { user_id: userId, nickname: user?.nickname ?? '' };
};

// 依 user_id 由小到大異動錢包，避免兩人同時互相轉帳時交錯鎖定而死結。
const moveFunds = async (tx, { payer, payee, amount }) => {
  const steps = [
    [payer.user_id, () => wallet.changeBalance(tx, payer.user_id, {
      amount: -amount,
      type: 'transfer_out',
      description: `轉帳給 ${payee.nickname}`,
      counters: { total_expense: { increment: amount } },
      insufficientMessage: '代幣餘額不足'
    })],
    [payee.user_id, () => wallet.changeBalance(tx, payee.user_id, {
      amount,
      type: 'transfer_in',
      description: `${payer.nickname} 轉帳`,
      counters: { total_income: { increment: amount } }
    })]
  ].sort((a, b) => a[0] - b[0]);
  for (const [, step] of steps) await step();
};

const postCard = async (tx, { roomId, senderId, transferId }) => {
  const message = await tx.chat_messages.create({
    data: { room_id: roomId, sender_id: senderId, content: codec.encodeTransfer(transferId), message_type: 'system' },
    include: { users: { select: userBrief } }
  });
  await records.attachMessage(tx, transferId, message.message_id);
  await tx.chat_rooms.update({ where: { room_id: roomId }, data: { updated_at: new Date() } });
  realtime.touchRoom(roomId, { exceptUserId: senderId });
  return message;
};

const withCard = (message, transfer) => ({
  ...codec.shapeMessage({ ...message }, { transfers: new Map([[transfer.transfer_id, transfer]]) }),
  edited_at: null,
  reply_to: null
});

const create = async (roomId, myId, { kind, counterpartId, amount, note }) => {
  const room = await rooms.findMine(roomId, myId);
  const isTransfer = kind === 'transfer';
  const otherId = await counterpartIdOf(room, myId, counterpartId, isTransfer ? '無法轉帳給自己' : '無法向自己請款');
  const other = await reachableUser(otherId);
  if (!rooms.isGroup(room)) await controls.assertCanMessage(myId, otherId);

  const me = await nameOf(myId);
  const now = new Date();

  const { transfer, message } = await prisma.$transaction(async (tx) => {
    if (isTransfer) await moveFunds(tx, { payer: me, payee: other, amount });
    const transferId = await records.insert(tx, {
      roomId,
      kind,
      fromUserId: isTransfer ? myId : otherId,
      toUserId: isTransfer ? otherId : myId,
      amount,
      note,
      status: isTransfer ? 'completed' : 'pending',
      createdAt: now,
      expiresAt: isTransfer ? null : new Date(now.getTime() + REQUEST_TTL_MS)
    });
    const card = await postCard(tx, { roomId, senderId: myId, transferId });
    await notice.notifyMembers(tx, {
      room, actor: me, userIds: [otherId], preview: `${isTransfer ? '[轉帳]' : '[請款]'} ${amount} 代幣`
    });
    const shaped = records.shape(await records.find(tx, transferId), now);
    return { transfer: shaped, message: card };
  });

  return { transfer, message: withCard(message, transfer) };
};

const RESPONSES = {
  pay: { actor: 'from_user_id', status: 'completed', denied: '僅付款方可支付此請款', preview: '已支付請款' },
  decline: { actor: 'from_user_id', status: 'declined', denied: '僅付款方可婉拒此請款', preview: '已婉拒請款' },
  cancel: { actor: 'to_user_id', status: 'cancelled', denied: '僅請款人可取消此請款', preview: null }
};

const respond = async (transferId, myId, action) => {
  const rule = RESPONSES[action];
  const row = await records.find(null, transferId);
  if (!row || (Number(row.from_user_id) !== myId && Number(row.to_user_id) !== myId)) throw notFound('找不到此筆請款');
  if (Number(row[rule.actor]) !== myId) throw forbidden(rule.denied);
  if (row.kind !== 'request' || records.shape(row).status !== 'pending') throw stateChanged();

  const amount = Number(row.amount);
  const requesterId = Number(row.to_user_id);
  const room = (await rooms.summaryOf(Number(row.room_id))) ?? { room_id: Number(row.room_id), room_type: 'direct', name: null };
  const me = await nameOf(myId);
  let payee = null;
  if (action === 'pay') {
    payee = await reachableUser(requesterId);
    if (!rooms.isGroup(room)) await controls.assertCanMessage(myId, requesterId);
  }

  const now = new Date();
  const transfer = await prisma.$transaction(async (tx) => {
    const changed = await records.transition(tx, transferId, rule.status, now);
    if (Number(changed) === 0) throw stateChanged();
    if (payee) await moveFunds(tx, { payer: me, payee, amount });
    await tx.chat_rooms.updateMany({ where: { room_id: room.room_id }, data: { updated_at: now } });
    realtime.touchRoom(room.room_id);
    if (rule.preview) {
      await notice.notifyMembers(tx, { room, actor: me, userIds: [requesterId], preview: `${rule.preview} ${amount} 代幣` });
    }
    return records.shape(await records.find(tx, transferId), now);
  });
  return { transfer };
};

const send = (roomId, myId, { toUserId, amount, note }) =>
  create(roomId, myId, { kind: 'transfer', counterpartId: toUserId, amount, note });

const request = (roomId, myId, { fromUserId, amount, note }) =>
  create(roomId, myId, { kind: 'request', counterpartId: fromUserId, amount, note });

module.exports = { MAX_AMOUNT, MAX_NOTE_LENGTH, send, request, respond, expireDue: records.expireDue };
