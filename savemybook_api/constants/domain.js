const ORDER_STATUSES = [
  'pending_payment', 'pending_deposit', 'deposited', 'pending_pickup',
  'completed', 'cancelled', 'refunding', 'refunded'
];

const ORDER_OPEN_STATUSES = ['pending_payment', 'pending_deposit', 'deposited', 'pending_pickup'];

const ORDER_UNSETTLED_STATUSES = [...ORDER_OPEN_STATUSES, 'refunding'];

const ORDER_FINAL_STATUSES = ['completed', 'cancelled', 'refunded'];

const ORDER_STATUS_LABELS = {
  pending_payment: '待付款',
  pending_deposit: '待存書',
  deposited: '已存書',
  pending_pickup: '待取貨',
  completed: '已完成',
  cancelled: '已取消',
  refunding: '退款處理中',
  refunded: '已退款'
};

const BOOK_STATUSES = ['on_sale', 'reserved', 'sold', 'removed'];
const CONDITION_LEVELS = ['like_new', 'good', 'fair', 'poor'];
const GENDERS = ['male', 'female', 'other', 'undisclosed'];
const USER_ROLES = ['buyer_seller', 'admin'];

const REPORT_TARGET_TYPES = ['user', 'book', 'message'];
const ANNOUNCEMENT_TYPES = ['general', 'maintenance', 'promotion', 'policy'];
const TICKET_CATEGORIES = ['account', 'trade', 'wallet', 'cabinet', 'bug', 'other'];
const TICKET_STATUSES = ['open', 'pending', 'resolved', 'closed'];
const SLOT_STATUSES = ['empty', 'occupied', 'reserved', 'maintenance'];
const NOTIFICATION_TYPES = ['system', 'order', 'message', 'promotion', 'reservation'];
const REPORT_STATUSES = ['pending', 'reviewing', 'resolved', 'dismissed'];
const DISPUTE_STATUSES = ['pending', 'processing', 'resolved'];

module.exports = {
  ORDER_STATUSES, ORDER_OPEN_STATUSES, ORDER_UNSETTLED_STATUSES, ORDER_FINAL_STATUSES, ORDER_STATUS_LABELS,
  BOOK_STATUSES, CONDITION_LEVELS, GENDERS, USER_ROLES,
  REPORT_TARGET_TYPES, ANNOUNCEMENT_TYPES, TICKET_CATEGORIES, TICKET_STATUSES, SLOT_STATUSES,
  NOTIFICATION_TYPES, REPORT_STATUSES, DISPUTE_STATUSES
};
