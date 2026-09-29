const ORDER_STATUSES = [
  'pending_payment', 'pending_deposit', 'deposited', 'pending_pickup',
  'completed', 'cancelled', 'refunding', 'refunded'
];

const ORDER_OPEN_STATUSES = ['pending_payment', 'pending_deposit', 'deposited', 'pending_pickup'];

const ORDER_UNSETTLED_STATUSES = [...ORDER_OPEN_STATUSES, 'refunding'];

const ORDER_FINAL_STATUSES = ['completed', 'cancelled', 'refunded'];

// 訂單編號為 SMB 加 20 位數字，早期訂單為 17 位。
const ORDER_NO_SOURCE = 'SMB\\d{17}(?:\\d{3})?';

const ORDER_STATUS_LABELS = {
  pending_payment: '待付款',
  pending_deposit: '待存書',
  deposited: '已存書',
  pending_pickup: '待取書',
  completed: '已完成',
  cancelled: '已取消',
  refunding: '審核中',
  refunded: '已退款'
};

// App 依買賣方身分與取書進度另有顯示名稱，AI 客服檢索須認得這些說法。
const ORDER_STATUS_ALIASES = {
  pending_deposit: ['待賣家存書'],
  deposited: ['待取書', '待完成訂單', '待買家確認'],
  pending_pickup: ['待取書'],
  refunding: ['爭議處理中', '申訴中']
};

const BOOK_STATUSES = ['on_sale', 'reserved', 'sold', 'removed'];
const BOOK_STATUS_LABELS = { on_sale: '上架中', reserved: '交易中', sold: '已售出', removed: '已下架' };
const CONDITION_LEVELS = ['like_new', 'good', 'fair', 'poor'];
const CONDITION_LABELS = { like_new: '近全新', good: '良好', fair: '普通', poor: '待修補' };
const GENDERS = ['male', 'female', 'other', 'undisclosed'];
const USER_ROLES = ['buyer_seller', 'admin'];
const USER_ROLE_LABELS = { buyer_seller: '一般會員', admin: '管理員' };

const REPORT_TARGET_TYPES = ['user', 'book', 'message'];
const ANNOUNCEMENT_TYPES = ['general', 'maintenance', 'promotion', 'policy'];
const ANNOUNCEMENT_TYPE_LABELS = { general: '一般公告', maintenance: '系統維護', promotion: '優惠活動', policy: '政策更新' };
const TICKET_CATEGORIES = ['account', 'trade', 'wallet', 'cabinet', 'bug', 'other'];
const TICKET_STATUSES = ['open', 'pending', 'resolved', 'closed'];
const TICKET_STATUS_LABELS = { open: '待處理', pending: '等待使用者回覆', resolved: '已解決', closed: '已結案' };
const SLOT_STATUSES = ['empty', 'occupied', 'reserved', 'maintenance'];
const SLOT_STATUS_LABELS = { empty: '空櫃', occupied: '使用中', reserved: '已預約', maintenance: '維修中' };
const NOTIFICATION_TYPES = ['system', 'order', 'message', 'promotion', 'reservation'];
const REPORT_STATUSES = ['pending', 'reviewing', 'resolved', 'dismissed'];
const REPORT_STATUS_LABELS = { pending: '待處理', reviewing: '審核中', resolved: '違規成立', dismissed: '未違規' };
const DISPUTE_STATUSES = ['pending', 'processing', 'resolved'];
const DISPUTE_RESULT_LABELS = {
  refund_manual: '人工退款', refund_auto: '自動退款', dismissed: '駁回爭議', mediated: '協調結案'
};

const ADMIN_PERMISSIONS = {
  members: 'can_manage_members',
  levels: 'can_manage_levels',
  content: 'can_manage_content',
  reports: 'can_manage_reports',
  orders: 'can_manage_orders',
  transactions: 'can_manage_transactions',
  wallets: 'can_manage_wallets',
  cabinets: 'can_manage_cabinets',
  announcements: 'can_manage_announcements',
  support: 'can_manage_support',
  stats: 'can_view_stats',
  system: 'can_manage_system'
};

const ADMIN_PERMISSION_LABELS = {
  members: '會員管理',
  levels: '會員等級',
  content: '內容管理',
  reports: '檢舉審核',
  orders: '訂單管理',
  transactions: '交易爭議',
  wallets: '錢包管理',
  cabinets: '書櫃管理',
  announcements: '公告與文件',
  support: '客服工單',
  stats: '營運報表',
  system: '系統維運'
};

module.exports = {
  ORDER_STATUSES, ORDER_OPEN_STATUSES, ORDER_UNSETTLED_STATUSES, ORDER_FINAL_STATUSES, ORDER_NO_SOURCE, ORDER_STATUS_LABELS, ORDER_STATUS_ALIASES,
  BOOK_STATUSES, BOOK_STATUS_LABELS, CONDITION_LEVELS, CONDITION_LABELS, GENDERS, USER_ROLES, USER_ROLE_LABELS,
  REPORT_TARGET_TYPES, ANNOUNCEMENT_TYPES, ANNOUNCEMENT_TYPE_LABELS, TICKET_CATEGORIES, TICKET_STATUSES, TICKET_STATUS_LABELS,
  SLOT_STATUSES, SLOT_STATUS_LABELS, NOTIFICATION_TYPES, REPORT_STATUSES, REPORT_STATUS_LABELS,
  DISPUTE_STATUSES, DISPUTE_RESULT_LABELS, ADMIN_PERMISSIONS, ADMIN_PERMISSION_LABELS
};
