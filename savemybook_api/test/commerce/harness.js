// 交易相關測試的共用設定：假 Prisma（見 ./fake-prisma）、假的 AI 服務商與外部書庫回應，
// 以及各測試共用的資料建構函式。
process.env.DEEPSEEK_API_KEY = 'test-deepseek-key';
process.env.GEMINI_API_KEY = '';
process.env.OPENAI_API_KEY = '';
process.env.GOOGLE_BOOKS_API_KEY = '';

const crypto = require('crypto');
const server = require('../lib/server');
const { install, registerModels } = require('./fake-prisma');

const { prisma, api, onFetch, jsonResponse, fetchLog, request, listen, close, runSuite, onReset } = server;

install(prisma);

registerModels({
  autoKeys: {
    books: 'book_id',
    book_images: 'image_id',
    book_categories: 'category_id',
    smart_cabinets: 'cabinet_id',
    cabinet_slots: 'slot_id',
    orders: 'order_id',
    order_items: 'item_id',
    shopping_cart: 'cart_id',
    favorites: 'favorite_id',
    wallets: 'wallet_id',
    wallet_transactions: 'txn_id',
    reservations: 'reservation_id',
    reports: 'report_id',
    transaction_disputes: 'dispute_id',
    refund_records: 'refund_id',
    support_tickets: 'ticket_id',
    support_ticket_messages: 'message_id',
    chat_rooms: 'room_id',
    chat_messages: 'message_id',
    recommendation_logs: 'log_id'
  },
  uniqueKeys: {
    books: [['book_id']],
    orders: [['order_id'], ['order_no']],
    wallets: [['user_id']],
    shopping_cart: [['user_id', 'book_id']],
    favorites: [['user_id', 'book_id']]
  },
  defaults: {
    books: {
      author: null, publisher: null, publish_date: null, isbn: null, description: null, condition_note: null,
      condition_level: 'good', category_id: null, cabinet_id: null, quantity: 1, view_count: 0,
      status: 'on_sale', is_approved: true, share_token: null
    },
    orders: {
      cabinet_id: null, slot_id: null, note: null, payment_at: null, deposited_at: null, picked_up_at: null,
      completed_at: null, cancelled_at: null, cancel_reason: null
    },
    wallets: { balance: 0, frozen_amount: 0, total_income: 0, total_expense: 0 },
    wallet_transactions: { related_order_id: null, description: null },
    reservations: { status: 'pending', pickup_deadline: null, note: null },
    reports: { status: 'pending', admin_id: null, admin_note: null, resolved_at: null, evidence_urls: null },
    transaction_disputes: {
      status: 'pending', result: null, admin_id: null, admin_note: null, resolved_at: null, evidence_urls: null
    },
    support_tickets: { status: 'open', closed_at: null },
    support_ticket_messages: { is_staff: false },
    notifications: { is_read: false, related_id: null, related_type: null },
    chat_rooms: { book_id: null, room_type: 'direct' }
  }
});

// ---------- 資料庫狀態 ----------

const TABLES = [
  'users', 'admin_permissions', 'admin_operation_logs', 'notifications', 'login_logs',
  'books', 'book_images', 'book_categories', 'smart_cabinets', 'cabinet_slots',
  'orders', 'order_items', 'shopping_cart', 'favorites', 'reservations', 'recommendation_logs',
  'wallets', 'wallet_transactions', 'refund_records', 'transaction_disputes', 'reports',
  'support_tickets', 'support_ticket_messages', 'chat_rooms', 'chat_room_members', 'chat_messages',
  'ai_settings', 'ai_usage_logs', 'ai_book_reviews'
];

const aiSettings = api('services/ai/settings');
const aiRunner = api('services/ai/runner');
const authToken = api('lib/auth-token');

// 迷你 SQL 直譯器會把 NULL 與 'pending' 當成字串搬進資料列，審核佇列改用自訂處理器寫入。
prisma.onSql(/^INSERT INTO ai_book_reviews/i, (sql, values) => {
  const [bookId, verdict, reasons, categories, provider, model, createdAt] = values;
  const rows = prisma.rows('ai_book_reviews');
  const row = rows.find((r) => Number(r.book_id) === Number(bookId));
  const data = {
    book_id: Number(bookId),
    verdict,
    reasons,
    categories,
    status: 'pending',
    provider,
    model,
    created_at: createdAt,
    reviewed_by: null,
    reviewed_at: null
  };
  if (row) Object.assign(row, data);
  else rows.push(data);
  return 1;
});

// 聊天室權限以 LEFT JOIN 取回成員身分，迷你直譯器不支援。
prisma.onSql(/LEFT JOIN chat_room_members m ON m\.room_id = r\.room_id/, (sql, [userId, roomId]) => {
  const room = prisma.rows('chat_rooms').find((r) => Number(r.room_id) === Number(roomId));
  if (!room) return [];
  const member = prisma.rows('chat_room_members')
    .find((m) => Number(m.room_id) === Number(roomId) && Number(m.user_id) === Number(userId));
  return [{
    room_type: room.room_type ?? 'direct',
    name: room.name ?? null,
    avatar_url: room.avatar_url ?? null,
    created_by: room.created_by ?? null,
    role: member?.role ?? null,
    left_at: member?.left_at ?? null,
    joined_at: member?.joined_at ?? null,
    history_from_id: member?.history_from_id ?? null
  }];
});

const reset = ({ tables = {} } = {}) => {
  server.reset({
    tables: Object.fromEntries(TABLES.map((name) => [name, []]))
  });
  for (const [name, rows] of Object.entries(tables)) prisma.store[name] = rows;
};

server.setDefaultReset(() => {
  reset();
  moderationReply = null;
  moderationFailure = null;
});

onReset(() => {
  aiSettings.clearCache();
  aiRunner.clearCache();
});

// ---------- 假的 AI 服務商 ----------

let moderationReply = null;
let moderationFailure = null;

// 審核走 DeepSeek（唯一設定金鑰的服務商），以攔截到的請求回覆預錄的判斷結果。
onFetch('https://api.deepseek.com', () => {
  if (moderationFailure) return jsonResponse({ error: { message: '模型暫時無法使用' } }, { status: moderationFailure });
  return jsonResponse({
    choices: [{ message: { content: JSON.stringify(moderationReply ?? { verdict: 'allow', confidence: 1 }) } }],
    usage: { prompt_tokens: 10, completion_tokens: 5 }
  });
});

const enableModeration = ({ action = 'review', ...overrides } = {}) => {
  prisma.store.ai_settings = [{
    id: 1,
    config: JSON.stringify({
      enabled: true,
      default_provider: 'deepseek',
      features: { moderation: { enabled: true, provider: 'deepseek', action } },
      // 預算設為 0 代表不限制，避免測試還要準備用量資料。
      limits: { monthly_budget_usd: 0 },
      ...overrides
    }),
    updated_by: null,
    updated_at: new Date()
  }];
  aiSettings.clearCache();
};

const stubModeration = (verdict) => {
  moderationReply = verdict;
};

const failModeration = (status = 401) => {
  moderationFailure = status;
};

// ---------- 假的外部書庫 ----------

const GOOGLE_BOOKS = 'https://www.googleapis.com/books/v1/volumes';
const OPEN_LIBRARY = 'https://openlibrary.org';

let googleHandler = () => jsonResponse({ items: [] });
let openLibraryHandler = () => jsonResponse({});

onFetch(GOOGLE_BOOKS, (url) => googleHandler(url));
onFetch(OPEN_LIBRARY, (url) => openLibraryHandler(url));

const stubGoogleBooks = (handler) => {
  googleHandler = handler;
};

const stubOpenLibrary = (handler) => {
  openLibraryHandler = handler;
};

// ---------- 資料建構 ----------

// 使用者編號不隨測試重置，讓以使用者計數的限流器不會跨測試累積。
let userSeq = 0;

const addUser = ({ nickname = '測試會員', role = 'buyer_seller', balance = null, email } = {}) => {
  userSeq += 1;
  const row = {
    user_id: userSeq,
    email: email ?? `user${userSeq}@example.com`,
    password_hash: `hash-${userSeq}`,
    nickname,
    avatar_url: null,
    bio: null,
    phone: null,
    birthday: null,
    gender: 'undisclosed',
    role,
    is_active: true,
    is_blacklisted: false,
    bonus_points: 0,
    deletion_requested_at: null,
    anonymized_at: null,
    share_token: null,
    created_at: new Date(),
    updated_at: new Date()
  };
  prisma.rows('users').push(row);
  if (balance !== null) addWallet(row.user_id, balance);
  return row;
};

const addAdmin = (permissions = null) => {
  const admin = addUser({ nickname: '客服人員', role: 'admin' });
  if (permissions) prisma.rows('admin_permissions').push({ user_id: admin.user_id, ...permissions });
  return admin;
};

const addWallet = (userId, balance = 0) => {
  const row = {
    wallet_id: prisma.nextId('wallets'),
    user_id: userId,
    balance,
    frozen_amount: 0,
    total_income: 0,
    total_expense: 0,
    created_at: new Date(),
    updated_at: new Date()
  };
  prisma.rows('wallets').push(row);
  return row;
};

const addCategory = (name = '文學小說') => {
  const row = { category_id: prisma.nextId('book_categories'), category_name: name, sort_order: 0 };
  prisma.rows('book_categories').push(row);
  return row;
};

const addCabinet = ({ isActive = true, isMaintenance = false, name = '中正書櫃' } = {}) => {
  const row = {
    cabinet_id: prisma.nextId('smart_cabinets'),
    cabinet_name: name,
    address: '台北市中正區',
    open_time: '08:00',
    close_time: '22:00',
    latitude: 25.03,
    longitude: 121.51,
    is_active: isActive,
    is_maintenance: isMaintenance ? 1 : 0
  };
  prisma.rows('smart_cabinets').push(row);
  return row;
};

const addBook = ({ sellerId, title = '測試書籍', price = 100, ...overrides } = {}) => {
  const row = {
    book_id: prisma.nextId('books'),
    seller_id: sellerId,
    title,
    author: null,
    publisher: null,
    publish_date: null,
    isbn: null,
    description: null,
    price,
    quantity: 1,
    condition_level: 'good',
    condition_note: null,
    category_id: null,
    cabinet_id: null,
    status: 'on_sale',
    is_approved: true,
    view_count: 0,
    share_token: null,
    created_at: new Date(),
    updated_at: new Date(),
    ...overrides
  };
  prisma.rows('books').push(row);
  return row;
};

const addImage = (bookId, { type = 'cover', url } = {}) => {
  const imageId = prisma.nextId('book_images');
  const row = { image_id: imageId, book_id: bookId, image_url: url ?? `/uploads/books/${imageId}.jpg`, image_type: type };
  prisma.rows('book_images').push(row);
  return row;
};

const addCartItem = (userId, bookId, quantity = 1) => {
  const row = {
    cart_id: prisma.nextId('shopping_cart'), user_id: userId, book_id: bookId, quantity, added_at: new Date()
  };
  prisma.rows('shopping_cart').push(row);
  return row;
};

const addReservation = ({ bookId, buyerId, sellerId, status = 'pending', hours = 24, deadline }) => {
  const row = {
    reservation_id: prisma.nextId('reservations'),
    book_id: bookId,
    buyer_id: buyerId,
    seller_id: sellerId,
    status,
    pickup_deadline: deadline ?? (status === 'confirmed' ? new Date(Date.now() + hours * 3600 * 1000) : null),
    note: JSON.stringify({ hours, message: null }),
    created_at: new Date(),
    updated_at: new Date()
  };
  prisma.rows('reservations').push(row);
  return row;
};

const addRoom = (a, b, bookId = null) => {
  const [userA, userB] = a < b ? [a, b] : [b, a];
  const row = {
    room_id: prisma.nextId('chat_rooms'),
    user_a_id: userA,
    user_b_id: userB,
    book_id: bookId,
    room_type: 'direct',
    created_at: new Date(),
    updated_at: new Date()
  };
  prisma.rows('chat_rooms').push(row);
  for (const userId of [userA, userB]) {
    prisma.rows('chat_room_members').push({
      room_id: row.room_id, user_id: userId, role: 'member', joined_at: row.created_at, left_at: null, history_from_id: null
    });
  }
  return row;
};

const addOrder = ({
  buyerId, sellerId, bookId, amount = 100, status = 'pending_deposit', cabinetId = null, quantity = 1, ...overrides
}) => {
  const orderId = prisma.nextId('orders');
  const row = {
    order_id: orderId,
    order_no: `SMB${String(orderId).padStart(6, '0')}`,
    buyer_id: buyerId,
    seller_id: sellerId,
    total_amount: amount,
    cabinet_id: cabinetId,
    slot_id: null,
    pickup_code: '123456',
    status,
    payment_method: 'wallet',
    payment_at: new Date(),
    deposited_at: null,
    picked_up_at: null,
    completed_at: null,
    cancelled_at: null,
    cancel_reason: null,
    note: null,
    created_at: new Date(),
    updated_at: new Date(),
    ...overrides
  };
  prisma.rows('orders').push(row);
  if (bookId) {
    prisma.rows('order_items').push({
      item_id: prisma.nextId('order_items'),
      order_id: orderId,
      book_id: bookId,
      quantity,
      unit_price: amount,
      subtotal: amount
    });
  }
  return row;
};

// 買家已付款的訂單：連同扣款紀錄一起建立，結算才算得出應退／應撥金額。
const addPaidOrder = ({ buyerId, sellerId, bookId, amount = 100, status = 'pending_deposit', ...rest }) => {
  const order = addOrder({ buyerId, sellerId, bookId, amount, status, ...rest });
  const wallet = walletOf(buyerId) ?? addWallet(buyerId, 0);
  wallet.balance = Number(wallet.balance) - amount;
  wallet.total_expense = Number(wallet.total_expense) + amount;
  prisma.rows('wallet_transactions').push({
    txn_id: prisma.nextId('wallet_transactions'),
    wallet_id: wallet.wallet_id,
    type: 'purchase',
    amount: -amount,
    balance_after: Number(wallet.balance),
    related_order_id: order.order_id,
    description: `購買訂單 ${order.order_no}`,
    created_at: new Date()
  });
  return order;
};

const addTicket = ({ userId, subject = '無法登入', status = 'open', category = 'account' } = {}) => {
  const ticketId = prisma.nextId('support_tickets');
  const row = {
    ticket_id: ticketId,
    user_id: userId,
    subject,
    category,
    status,
    closed_at: null,
    created_at: new Date(),
    updated_at: new Date()
  };
  prisma.rows('support_tickets').push(row);
  return row;
};

// ---------- 查詢輔助 ----------

const walletOf = (userId) => prisma.rows('wallets').find((w) => w.user_id === userId);
const balanceOf = (userId) => Number(walletOf(userId)?.balance ?? 0);
const bookOf = (bookId) => prisma.rows('books').find((b) => b.book_id === bookId);
const orderOf = (orderId) => prisma.rows('orders').find((o) => o.order_id === orderId);
const notificationsOf = (userId) => prisma.rows('notifications').filter((n) => n.user_id === userId);
const transactionsOf = (userId) => {
  const wallet = walletOf(userId);
  return wallet ? prisma.rows('wallet_transactions').filter((t) => t.wallet_id === wallet.wallet_id) : [];
};
const logs = () => prisma.rows('admin_operation_logs');
const reviewOf = (bookId) => prisma.rows('ai_book_reviews').find((r) => Number(r.book_id) === Number(bookId));

const tokenFor = (user) => authToken.signToken(user, undefined);

// 驗證權杖由 services/security 簽發，測試直接以同樣的內容簽一份：付款以交易密碼、其餘以登入密碼驗證。
const verifyHeaders = (token, scope) => {
  const { userId, sid = null } = authToken.verify(token);
  const method = scope === 'payment' ? 'pin' : 'password';
  const jti = crypto.randomBytes(12).toString('hex');
  return { 'x-verify-token': authToken.sign({ typ: 'verify', uid: userId, sid, scope, method, jti }, 300) };
};

// 部分通知刻意不 await（例如降價通知），回應送出後才寫入，測試需先讓出事件迴圈。
const flush = async (rounds = 5) => {
  for (let i = 0; i < rounds; i += 1) await new Promise((resolve) => setImmediate(resolve));
};

module.exports = {
  prisma, api, request, listen, close, runSuite, reset, fetchLog, jsonResponse,
  enableModeration, stubModeration, failModeration, stubGoogleBooks, stubOpenLibrary, GOOGLE_BOOKS, OPEN_LIBRARY,
  addUser, addAdmin, addWallet, addCategory, addCabinet, addBook, addImage, addCartItem, addReservation,
  addRoom, addOrder, addPaidOrder, addTicket,
  walletOf, balanceOf, bookOf, orderOf, notificationsOf, transactionsOf, logs, reviewOf, tokenFor, verifyHeaders, flush
};
