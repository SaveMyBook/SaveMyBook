const policy = require('../../constants/policy');

const HOUR_MS = 60 * 60 * 1000;
const PRE_DEPOSIT = ['pending_payment', 'pending_deposit'];
const IN_CABINET = ['deposited', 'pending_pickup'];
const DISPUTE_CLOSED = ['completed', 'cancelled', 'refunded'];

const plusHours = (value, hours) => (value ? new Date(new Date(value).getTime() + hours * HOUR_MS) : null);

// 起算點須與 services/orders 的排程條件一致：未存書以成立時間、未取書以存書時間、取書後以取書時間起算。
const depositDeadline = (order) => (PRE_DEPOSIT.includes(order.status)
  ? plusHours(order.created_at, policy.ORDER_DEPOSIT_DAYS * 24)
  : null);

const pickupDeadline = (order) => (IN_CABINET.includes(order.status) && !order.picked_up_at
  ? plusHours(order.deposited_at, policy.ORDER_PICKUP_DAYS * 24)
  : null);

const autoCompleteAt = (order) => (IN_CABINET.includes(order.status) && order.picked_up_at
  ? plusHours(order.picked_up_at, policy.ORDER_AUTO_COMPLETE_HOURS)
  : null);

const disputeDeadline = (order) => plusHours(order.picked_up_at, policy.DISPUTE_WINDOW_HOURS);

// 訂單完成（含買家提早按下完成訂單）即不再受理爭議，不能只看取書後的時限。
const disputeState = (order, now = new Date()) => {
  if (order.status === 'refunding') return { open: false, reason: 'in_progress', deadline: null };
  if (DISPUTE_CLOSED.includes(order.status)) return { open: false, reason: order.status, deadline: null };
  const deadline = disputeDeadline(order);
  if (deadline && now.getTime() > deadline.getTime()) return { open: false, reason: 'expired', deadline };
  return { open: true, reason: null, deadline };
};

const timelineOf = (order, now = new Date()) => ({
  deposit_deadline: depositDeadline(order),
  pickup_deadline: pickupDeadline(order),
  auto_complete_at: autoCompleteAt(order),
  dispute: disputeState(order, now)
});

module.exports = { depositDeadline, pickupDeadline, autoCompleteAt, disputeDeadline, disputeState, timelineOf };
