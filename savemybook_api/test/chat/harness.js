// 聊天測試的共用設定：沿用 test/lib 的假 Prisma，另外補上聊天功能用到的關聯查詢（include/_count）、
// 原生 SQL（JOIN、子查詢、多筆 INSERT）與各資料表預設值，以及建立帳號、聊天室、群組的輔助函式。
const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');
const Module = require('module');

const server = require('../lib/server');
const { registerModels, AUTO_KEYS, UNIQUE_KEYS, MODEL_DEFAULTS } = require('../lib/fake-prisma');

const { prisma, api, request, runSuite, onReset, onFetch, jsonResponse, fetchLog } = server;

// ---------- Prisma Client 列舉 ----------

// services/chat/transfers.js 以 $Enums 判斷 Prisma Client 是否已重新產生；測試需要能切換這個狀態。
let walletEnumReady = true;
const setWalletEnumReady = (value) => { walletEnumReady = value; };

const innerLoad = Module._load;
Module._load = function patched(requestPath, parent, isMain) {
  const loaded = innerLoad.call(this, requestPath, parent, isMain);
  if (requestPath === '@prisma/client') {
    return {
      ...loaded,
      $Enums: walletEnumReady
        ? { wallet_transactions_type: { transfer_in: 'transfer_in', transfer_out: 'transfer_out' } }
        : { wallet_transactions_type: { recharge: 'recharge' } }
    };
  }
  return loaded;
};

// ---------- 資料表設定 ----------

registerModels({
  autoKeys: {
    chat_rooms: 'room_id',
    chat_messages: 'message_id',
    chat_transfers: 'transfer_id',
    wallets: 'wallet_id',
    wallet_transactions: 'txn_id',
    books: 'book_id',
    book_images: 'image_id',
    reservations: 'reservation_id',
    push_devices: 'device_id',
    user_settings: 'setting_id'
  },
  uniqueKeys: {
    chat_room_members: [['room_id', 'user_id']],
    chat_room_pins: [['user_id', 'room_id']],
    chat_room_mutes: [['user_id', 'room_id']],
    user_blocks: [['blocker_id', 'blocked_id']],
    chat_aliases: [['owner_id', 'target_user_id']],
    chat_mentions: [['message_id', 'user_id']],
    wallets: [['user_id']],
    push_devices: [['token']]
  },
  defaults: {
    chat_rooms: { book_id: null, room_type: 'direct', name: null, avatar_url: null, created_by: null },
    chat_messages: {
      message_type: 'text', is_read: false, reply_to_id: null, edited_at: null, mentions: null
    },
    notifications: { related_id: null, related_type: null, is_read: false, pushed_at: null, actor_id: null },
    wallets: { balance: 0, frozen_amount: 0, total_income: 0, total_expense: 0 },
    wallet_transactions: { related_order_id: null, description: null }
  }
});

// ---------- where / orderBy / include ----------

const RELATIONS = {
  chat_rooms: {
    users_chat_rooms_user_a_idTousers: { table: 'users', local: 'user_a_id', foreign: 'user_id' },
    users_chat_rooms_user_b_idTousers: { table: 'users', local: 'user_b_id', foreign: 'user_id' },
    books: { table: 'books', local: 'book_id', foreign: 'book_id' },
    chat_messages: { table: 'chat_messages', local: 'room_id', foreign: 'room_id', many: true }
  },
  chat_messages: {
    users: { table: 'users', local: 'sender_id', foreign: 'user_id' },
    chat_rooms: { table: 'chat_rooms', local: 'room_id', foreign: 'room_id' }
  },
  books: {
    book_images: { table: 'book_images', local: 'book_id', foreign: 'book_id', many: true }
  },
  wallet_transactions: {
    wallets: { table: 'wallets', local: 'wallet_id', foreign: 'wallet_id' },
    orders: { table: 'orders', local: 'related_order_id', foreign: 'order_id' }
  },
  reservations: { books: { table: 'books', local: 'book_id', foreign: 'book_id' } }
};

const isPlain = (value) => value !== null && typeof value === 'object' && !Array.isArray(value) && !(value instanceof Date);

const ordinal = (value) => (value instanceof Date ? value.getTime() : value);

const compare = (a, b) => {
  const left = ordinal(a);
  const right = ordinal(b);
  if (left === right) return 0;
  if (left == null) return -1;
  if (right == null) return 1;
  return left < right ? -1 : 1;
};

const matchValue = (actual, expected) => {
  if (expected === null) return actual === null || actual === undefined;
  if (expected instanceof Date) return actual instanceof Date && actual.getTime() === expected.getTime();
  if (isPlain(expected)) {
    return Object.entries(expected).every(([op, value]) => {
      if (op === 'equals') return matchValue(actual, value);
      if (op === 'in') return value.some((v) => matchValue(actual, v));
      if (op === 'notIn') return !value.some((v) => matchValue(actual, v));
      if (op === 'not') return value === null ? actual != null : !matchValue(actual, value);
      if (op === 'lt') return actual != null && compare(actual, value) < 0;
      if (op === 'lte') return actual != null && compare(actual, value) <= 0;
      if (op === 'gt') return actual != null && compare(actual, value) > 0;
      if (op === 'gte') return actual != null && compare(actual, value) >= 0;
      if (op === 'contains') return String(actual ?? '').includes(String(value));
      throw new Error(`where 運算子未支援：${op}`);
    });
  }
  return actual === expected;
};

const rowsOf = (table) => prisma.rows(table);

const relatedRow = (table, row, name) => {
  const def = RELATIONS[table]?.[name];
  if (!def) return undefined;
  if (def.many) return rowsOf(def.table).filter((r) => r[def.foreign] === row[def.local]);
  return rowsOf(def.table).find((r) => r[def.foreign] === row[def.local]) ?? null;
};

const matchWhere = (table, row, where = {}) => Object.entries(where).every(([key, expected]) => {
  if (key === 'OR') return expected.some((w) => matchWhere(table, row, w));
  if (key === 'AND') return expected.every((w) => matchWhere(table, row, w));
  if (key === 'NOT') return !matchWhere(table, row, expected);
  const def = RELATIONS[table]?.[key];
  if (def && !def.many) {
    const target = relatedRow(table, row, key);
    return Boolean(target) && matchWhere(def.table, target, expected);
  }
  if (def && def.many) {
    const list = relatedRow(table, row, key);
    if (expected.some) return list.some((r) => matchWhere(def.table, r, expected.some));
    if (expected.none) return !list.some((r) => matchWhere(def.table, r, expected.none));
    return list.some((r) => matchWhere(def.table, r, expected));
  }
  return matchValue(row[key], expected);
});

const sortRows = (list, orderBy) => {
  if (!orderBy) return list;
  const specs = (Array.isArray(orderBy) ? orderBy : [orderBy]).flatMap((o) => Object.entries(o));
  return [...list].sort((a, b) => {
    for (const [field, direction] of specs) {
      const delta = compare(a[field], b[field]);
      if (delta !== 0) return direction === 'desc' ? -delta : delta;
    }
    return 0;
  });
};

const countOf = (table, row, spec) => Object.fromEntries(Object.entries(spec.select ?? spec).map(([name, args]) => {
  const list = relatedRow(table, row, name) ?? [];
  const def = RELATIONS[table][name];
  const filtered = isPlain(args) && args.where ? list.filter((r) => matchWhere(def.table, r, args.where)) : list;
  return [name, filtered.length];
}));

const project = (table, row, args = {}) => {
  if (!row) return row;
  const { select, omit, include } = args;
  if (select) {
    const out = {};
    for (const [key, want] of Object.entries(select)) {
      if (!want) continue;
      if (key === '_count') out._count = countOf(table, row, want);
      else if (RELATIONS[table]?.[key]) out[key] = resolveRelation(table, row, key, want);
      else out[key] = row[key] ?? null;
    }
    return out;
  }
  const out = { ...row };
  if (omit) for (const key of Object.keys(omit)) delete out[key];
  if (include) {
    for (const [key, want] of Object.entries(include)) {
      if (!want) continue;
      if (key === '_count') out._count = countOf(table, row, want);
      else out[key] = resolveRelation(table, row, key, want);
    }
  }
  return out;
};

function resolveRelation(table, row, name, args) {
  const def = RELATIONS[table][name];
  const options = isPlain(args) ? args : {};
  if (!def.many) {
    const target = relatedRow(table, row, name);
    return target ? project(def.table, target, options) : null;
  }
  let list = relatedRow(table, row, name);
  if (options.where) list = list.filter((r) => matchWhere(def.table, r, options.where));
  list = sortRows(list, options.orderBy);
  if (options.skip) list = list.slice(options.skip);
  if (options.take != null) list = list.slice(0, options.take);
  return list.map((r) => project(def.table, r, options));
}

// ---------- 覆寫模型 API ----------

const applyData = (row, data) => {
  for (const [key, value] of Object.entries(data)) {
    if (isPlain(value) && 'increment' in value) row[key] = Number(row[key] ?? 0) + Number(value.increment);
    else if (isPlain(value) && 'decrement' in value) row[key] = Number(row[key] ?? 0) - Number(value.decrement);
    else if (isPlain(value) && 'set' in value) row[key] = value.set;
    else row[key] = value;
  }
  return row;
};

const notFoundError = () => Object.assign(new Error('Record not found'), { code: 'P2025' });

prisma.model = (table) => {
  const all = () => rowsOf(table);
  const find = (where = {}) => all().filter((row) => matchWhere(table, row, where));
  const page = (args = {}) => {
    let list = sortRows(find(args.where), args.orderBy);
    if (args.skip) list = list.slice(args.skip);
    if (args.take != null) list = list.slice(0, args.take);
    return list;
  };
  const insert = (data) => {
    const key = AUTO_KEYS[table] ?? 'id';
    const row = { ...(MODEL_DEFAULTS[table] ?? {}), created_at: new Date(), updated_at: new Date(), ...data };
    if (row[key] === undefined) row[key] = prisma.nextId(table);
    prisma.assertUnique(table, row);
    all().push(row);
    return row;
  };

  return {
    findUnique: async (args) => project(table, find(args.where)[0] ?? null, args),
    findFirst: async (args = {}) => project(table, page(args)[0] ?? null, args),
    findMany: async (args = {}) => page(args).map((row) => project(table, row, args)),
    count: async (args = {}) => find(args.where).length,
    groupBy: async (args) => {
      const groups = new Map();
      for (const row of find(args.where)) {
        const key = args.by.map((f) => row[f]).join(' ');
        if (!groups.has(key)) groups.set(key, []);
        groups.get(key).push(row);
      }
      return [...groups.values()].map((list) => ({
        ...Object.fromEntries(args.by.map((f) => [f, list[0][f]])),
        ...(args._count && { _count: Object.fromEntries(Object.keys(args._count).map((f) => [f, list.length])) })
      }));
    },
    create: async (args) => project(table, insert(args.data), args),
    createMany: async (args) => {
      for (const data of args.data) insert(data);
      return { count: args.data.length };
    },
    update: async (args) => {
      const row = find(args.where)[0];
      if (!row) throw notFoundError();
      applyData(row, args.data);
      prisma.assertUnique(table, row, row);
      return project(table, row, args);
    },
    updateMany: async (args) => {
      const affected = find(args.where ?? {});
      affected.forEach((row) => applyData(row, args.data));
      return { count: affected.length };
    },
    upsert: async (args) => {
      const row = find(args.where)[0];
      if (row) {
        applyData(row, args.update);
        return project(table, row, args);
      }
      return project(table, insert(args.create), args);
    },
    delete: async (args) => {
      const row = find(args.where)[0];
      if (!row) throw notFoundError();
      prisma.store[table] = all().filter((r) => r !== row);
      return row;
    },
    deleteMany: async (args = {}) => {
      const removed = find(args.where ?? {});
      prisma.store[table] = all().filter((r) => !removed.includes(r));
      return { count: removed.length };
    }
  };
};

// ---------- 原生 SQL ----------

const INSERT_RE = /^INSERT\s+(IGNORE\s+)?INTO\s+(\w+)\s*\(([^)]+)\)\s*VALUES\s*(.+?)(?:\s+ON DUPLICATE KEY UPDATE\s+(.+))?$/i;

let lastInsertId = 0;

const literal = (token, params) => {
  const text = token.trim();
  if (text === '?') return params.shift();
  if (/^'.*'$/s.test(text)) return text.slice(1, -1);
  if (/^-?\d+$/.test(text)) return Number(text);
  if (/^NULL$/i.test(text)) return null;
  throw new Error(`INSERT 值未支援：${text}`);
};

// 迷你直譯器只支援單筆 INSERT，且 INSERT IGNORE 遇到重複時會丟錯；聊天功能大量使用多筆 INSERT 與 IGNORE。
prisma.onSql(/^INSERT\s+(IGNORE\s+)?INTO/i, (sql, values) => {
  const m = INSERT_RE.exec(sql);
  if (!m) throw new Error(`INSERT 未支援：${sql}`);
  const [, ignore, table, columnText, tupleText, onDuplicate] = m;
  const columns = columnText.split(',').map((c) => c.trim());
  const params = [...values];
  const tuples = tupleText.match(/\(([^)]*)\)/g) ?? [];
  const key = AUTO_KEYS[table];
  let affected = 0;

  for (const tuple of tuples) {
    const tokens = tuple.slice(1, -1).split(',');
    const data = Object.fromEntries(tokens.map((token, i) => [columns[i], literal(token, params)]));
    const row = { ...(MODEL_DEFAULTS[table] ?? {}), ...data };
    const existing = (UNIQUE_KEYS[table] ?? [])
      .map((keys) => prisma.rows(table).find((other) => keys.every((k) => other[k] === row[k])))
      .find(Boolean);

    if (existing) {
      if (onDuplicate) {
        for (const part of onDuplicate.split(',')) {
          const assign = /^\s*(\w+)\s*=\s*VALUES\((\w+)\)\s*$/i.exec(part);
          if (assign) {
            existing[assign[1]] = data[assign[2]];
            continue;
          }
          // 重新邀請退出過的成員時會寫 left_at = NULL 這類常數指派。
          const literalAssign = /^\s*(\w+)\s*=\s*(NULL|\d+|'[^']*')\s*$/i.exec(part);
          if (!literalAssign) throw new Error(`ON DUPLICATE 未支援：${part}`);
          const [, column, value] = literalAssign;
          existing[column] = /^NULL$/i.test(value) ? null : value.startsWith("'") ? value.slice(1, -1) : Number(value);
        }
        affected += 1;
      } else if (!ignore) {
        throw Object.assign(new Error('Unique constraint failed'), { code: 'P2002' });
      }
      continue;
    }
    if (key && row[key] === undefined) row[key] = prisma.nextId(table);
    if (key) lastInsertId = Number(row[key]);
    prisma.rows(table).push(row);
    affected += 1;
  }
  return affected;
});

prisma.onSql('LAST_INSERT_ID', () => [{ id: BigInt(lastInsertId) }]);

const roomOf = (roomId) => prisma.rows('chat_rooms').find((r) => r.room_id === Number(roomId)) ?? null;

const membershipRow = (roomId, userId) => prisma.rows('chat_room_members')
  .find((m) => m.room_id === Number(roomId) && m.user_id === Number(userId)) ?? null;

const activeMembers = (roomId) => prisma.rows('chat_room_members')
  .filter((m) => m.room_id === Number(roomId) && m.left_at == null);

const JOIN_MARGIN_MS = 1000;

const visibleToMember = (message, member, v3) => (v3
  ? Number(message.message_id) >= Number(member.history_from_id ?? 0)
  : new Date(message.created_at) >= new Date(new Date(member.joined_at).getTime() - JOIN_MARGIN_MS));

// services/chat/rooms.js membershipOf
prisma.onSql('FROM chat_rooms r LEFT JOIN chat_room_members m', (sql, [userId, roomId]) => {
  const room = roomOf(roomId);
  if (!room) return [];
  const member = membershipRow(roomId, userId);
  return [{
    room_type: room.room_type ?? 'direct',
    name: room.name ?? null,
    avatar_url: room.avatar_url ?? null,
    created_by: room.created_by ?? null,
    role: member?.role ?? null,
    left_at: member?.left_at ?? null,
    joined_at: member?.joined_at ?? null,
    ...(sql.includes('history_from_id') ? { history_from_id: member?.history_from_id ?? 0 } : {})
  }];
});

// services/chat/rooms.js memberRooms
prisma.onSql('FROM chat_room_members m JOIN chat_rooms r', (sql, values) => {
  const myId = Number(values[values.length - 1]);
  const v3 = sql.includes('history_from_id');
  return prisma.rows('chat_room_members')
    .filter((m) => m.user_id === myId && m.left_at == null)
    .map((m) => {
      const room = roomOf(m.room_id);
      const pin = prisma.rows('chat_room_pins').find((p) => p.user_id === myId && p.room_id === m.room_id);
      const messages = prisma.rows('chat_messages').filter((x) => x.room_id === m.room_id);
      const unread = room?.room_type === 'group'
        ? messages.filter((x) => x.sender_id !== myId
          && Number(x.message_id) > Number(m.last_read_message_id ?? 0) && visibleToMember(x, m, v3)).length
        : 0;
      const mentioned = v3 && prisma.rows('chat_mentions').some((c) => c.user_id === myId && c.room_id === m.room_id
        && Number(c.message_id) > Number(m.last_read_message_id ?? 0) && Number(c.message_id) >= Number(m.history_from_id ?? 0));
      return {
        room_id: m.room_id,
        room_type: room?.room_type ?? 'direct',
        name: room?.name ?? null,
        avatar_url: room?.avatar_url ?? null,
        pinned_at: pin?.pinned_at ?? null,
        joined_at: m.joined_at,
        ...(v3 ? { history_from_id: m.history_from_id ?? 0 } : {}),
        member_count: BigInt(activeMembers(m.room_id).length),
        group_unread: BigInt(unread),
        mention_unread: mentioned ? 1 : 0
      };
    });
});

// services/chat/rooms.js unreadCount
prisma.onSql('SELECT COUNT(*) AS n FROM chat_messages x JOIN chat_room_members m', (sql, [myId]) => {
  const v3 = sql.includes('history_from_id');
  const total = prisma.rows('chat_messages').filter((x) => {
    if (x.sender_id === Number(myId)) return false;
    const member = membershipRow(x.room_id, myId);
    if (!member || member.left_at != null) return false;
    const room = roomOf(x.room_id);
    if (room?.room_type !== 'group') return x.is_read === false;
    return Number(x.message_id) > Number(member.last_read_message_id ?? 0) && visibleToMember(x, member, v3);
  }).length;
  return [{ n: BigInt(total) }];
});

// services/chat/rooms.js markAllRead（一對一訊息）
prisma.onSql('UPDATE chat_messages x JOIN chat_room_members m', (sql, [myId]) => {
  let count = 0;
  for (const x of prisma.rows('chat_messages')) {
    const member = membershipRow(x.room_id, myId);
    if (!member || member.left_at != null) continue;
    if (roomOf(x.room_id)?.room_type === 'group') continue;
    if (x.is_read !== false || x.sender_id === Number(myId)) continue;
    x.is_read = true;
    count += 1;
  }
  return count;
});

// services/chat/rooms.js markAllRead（群組已讀游標）
prisma.onSql('UPDATE chat_room_members m SET m.last_read_message_id', (sql, [myId]) => {
  let count = 0;
  for (const m of prisma.rows('chat_room_members')) {
    if (m.user_id !== Number(myId) || m.left_at != null) continue;
    m.last_read_message_id = prisma.rows('chat_messages')
      .filter((x) => x.room_id === m.room_id)
      .reduce((max, x) => Math.max(max, Number(x.message_id)), 0);
    count += 1;
  }
  return count;
});

// services/chat/rooms.js setPinned 的釘選數量
prisma.onSql('FROM chat_room_pins p JOIN chat_room_members m', (sql, [myId]) => {
  const total = prisma.rows('chat_room_pins').filter((p) => p.user_id === Number(myId)
    && activeMembers(p.room_id).some((m) => m.user_id === Number(myId))).length;
  return [{ n: BigInt(total) }];
});

// services/chat/members.js active
prisma.onSql('FROM chat_room_members m JOIN users u', (sql, [roomId]) => activeMembers(roomId)
  .map((m) => {
    const user = prisma.rows('users').find((u) => u.user_id === m.user_id);
    return {
      user_id: m.user_id,
      role: m.role,
      joined_at: m.joined_at,
      last_read_message_id: m.last_read_message_id ?? 0,
      nickname: user?.nickname ?? null,
      avatar_url: user?.avatar_url ?? null
    };
  })
  .sort((a, b) => compare(a.joined_at, b.joined_at) || a.user_id - b.user_id));

// services/chat/members.js markRead
prisma.onSql('SET last_read_message_id = GREATEST', (sql, [messageId, roomId, userId]) => {
  const member = membershipRow(roomId, userId);
  if (!member) return 0;
  member.last_read_message_id = Math.max(Number(member.last_read_message_id ?? 0), Number(messageId));
  return 1;
});

// services/chat/controls.js relation
prisma.onSql('SELECT blocker_id FROM user_blocks', (sql, [myId, partnerId]) => prisma.rows('user_blocks')
  .filter((b) => (b.blocker_id === Number(myId) && b.blocked_id === Number(partnerId))
    || (b.blocker_id === Number(partnerId) && b.blocked_id === Number(myId)))
  .map((b) => ({ blocker_id: b.blocker_id })));

// services/chat/controls.js listBlocks
prisma.onSql('FROM user_blocks b JOIN users u', (sql, [myId]) => prisma.rows('user_blocks')
  .filter((b) => b.blocker_id === Number(myId))
  .sort((a, b) => compare(b.created_at, a.created_at))
  .map((b) => {
    const user = prisma.rows('users').find((u) => u.user_id === b.blocked_id);
    return {
      user_id: b.blocked_id, nickname: user?.nickname ?? null, avatar_url: user?.avatar_url ?? null, blocked_at: b.created_at
    };
  }));

// services/chat/messages.js recentEdits
prisma.onSql(/FROM chat_messages WHERE room_id = \? AND message_type = 'text' AND edited_at >=/, (sql, [roomId, since]) => prisma
  .rows('chat_messages')
  .filter((m) => m.room_id === Number(roomId) && m.message_type === 'text' && m.edited_at != null
    && new Date(m.edited_at) >= new Date(since))
  .map((m) => ({
    message_id: m.message_id,
    content: m.content,
    edited_at: m.edited_at,
    created_at: m.created_at,
    ...(sql.includes('mentions') ? { mentions: m.mentions ?? null } : {})
  })));

// services/chat/transfer-records.js expireDue
prisma.onSql("UPDATE chat_transfers SET status = 'expired'", (sql, [now]) => {
  let count = 0;
  for (const row of prisma.rows('chat_transfers')) {
    if (row.status !== 'pending' || row.expires_at == null) continue;
    if (new Date(row.expires_at) > new Date(now)) continue;
    row.status = 'expired';
    count += 1;
  }
  return count;
});

// services/push/setup.js init 以字面值查 information_schema，迷你直譯器無法解析。
prisma.onSql("TABLE_NAME = 'push_devices'", () => [{ n: BigInt(1) }]);
prisma.onSql("COLUMN_NAME = 'pushed_at'", () => [{ n: BigInt(1) }]);

// services/push/dispatcher.js claimBatch
prisma.onSql('FROM notifications n JOIN (SELECT MAX(created_at)', (sql, [minutes, now, limit]) => {
  const rows = prisma.rows('notifications');
  const latest = rows.reduce((max, n) => Math.max(max, new Date(n.created_at).getTime()), 0);
  const floor = latest - Number(minutes) * 60 * 1000;
  return rows
    .filter((n) => n.pushed_at == null
      && new Date(n.created_at).getTime() >= floor
      && new Date(n.created_at) <= new Date(now))
    .sort((a, b) => a.notification_id - b.notification_id)
    .slice(0, Number(limit))
    .map((n) => ({
      notification_id: n.notification_id,
      user_id: n.user_id,
      type: n.type,
      title: n.title,
      content: n.content,
      related_id: n.related_id,
      related_type: n.related_type,
      ...(sql.includes('n.actor_id') ? { actor_id: n.actor_id ?? null } : {})
    }));
});

// ---------- 資料庫版本 ----------

const TABLES_008 = ['chat_room_mutes', 'user_blocks'];
const TABLES_009 = ['chat_room_members', 'chat_room_pins', 'chat_aliases', 'chat_transfers'];
const TABLES_010 = ['chat_mentions'];
const COLUMNS_008 = ['chat_messages.reply_to_id'];
const COLUMNS_009 = ['chat_messages.edited_at', 'notifications.actor_id', 'chat_rooms.room_type'];
const COLUMNS_010 = ['chat_room_members.history_from_id', 'chat_messages.mentions'];
const BASE_TABLES = ['push_devices', 'notifications'];
const BASE_COLUMNS = ['notifications.pushed_at'];

const SCHEMA = {
  v3: {
    tables: [...BASE_TABLES, ...TABLES_008, ...TABLES_009, ...TABLES_010],
    columns: [...BASE_COLUMNS, ...COLUMNS_008, ...COLUMNS_009, ...COLUMNS_010]
  },
  v2: {
    tables: [...BASE_TABLES, ...TABLES_008, ...TABLES_009],
    columns: [...BASE_COLUMNS, ...COLUMNS_008, ...COLUMNS_009]
  },
  v1: { tables: [...BASE_TABLES, ...TABLES_008], columns: [...BASE_COLUMNS, ...COLUMNS_008] },
  v0: { tables: [...BASE_TABLES], columns: [...BASE_COLUMNS] }
};

const EMPTY_TABLES = [
  'users', 'chat_rooms', 'chat_messages', 'chat_room_members', 'chat_room_pins', 'chat_aliases',
  'chat_room_mutes', 'user_blocks', 'chat_transfers', 'chat_mentions', 'notifications', 'wallets',
  'wallet_transactions', 'books', 'book_images', 'reservations', 'push_devices', 'user_settings', 'login_logs'
];

const schemaCheck = api('lib/schema-check');
const authToken = api('lib/auth-token');

const reset = ({ schema = SCHEMA.v3, tables = {} } = {}) => {
  server.reset({
    schema,
    tables: { ...Object.fromEntries(EMPTY_TABLES.map((t) => [t, []])), ...tables }
  });
  walletEnumReady = true;
};

server.setDefaultReset(() => reset());

onReset(() => {
  schemaCheck.resetCache();
});

// ---------- 測試資料 ----------

// 傳訊、群組與轉帳共用同一個以使用者編號計數的限流器，編號不重置才不會讓後面的測試被擋下。
let userSeq = 1000;

const addUser = ({ nickname, isActive = true, isBlacklisted = false, balance = null, avatarUrl = null } = {}) => {
  userSeq += 1;
  const row = {
    user_id: userSeq,
    email: `chat${userSeq}@example.com`,
    password_hash: 'not-a-bcrypt-hash',
    nickname: nickname ?? `使用者${userSeq}`,
    avatar_url: avatarUrl,
    bio: null,
    phone: null,
    birthday: null,
    gender: 'undisclosed',
    role: 'buyer_seller',
    is_active: isActive,
    is_blacklisted: isBlacklisted,
    bonus_points: 0,
    created_at: new Date(),
    updated_at: new Date()
  };
  prisma.rows('users').push(row);
  if (balance != null) {
    prisma.rows('wallets').push({
      wallet_id: prisma.nextId('wallets'),
      user_id: row.user_id,
      balance,
      frozen_amount: 0,
      total_income: 0,
      total_expense: 0,
      updated_at: new Date()
    });
  }
  row.token = authToken.signToken(row, undefined);
  return row;
};

const addBook = ({ sellerId, title = '測試書籍', price = 120, imageUrl = '/uploads/books/cover.jpg' } = {}) => {
  const book = {
    book_id: prisma.nextId('books'),
    seller_id: sellerId,
    title,
    price,
    status: 'on_sale',
    quantity: 1,
    created_at: new Date(),
    updated_at: new Date()
  };
  prisma.rows('books').push(book);
  if (imageUrl) {
    prisma.rows('book_images').push({
      image_id: prisma.nextId('book_images'), book_id: book.book_id, image_url: imageUrl, image_type: 'cover', sort_order: 0
    });
  }
  return book;
};

const balanceOf = (userId) => Number(prisma.rows('wallets').find((w) => w.user_id === userId)?.balance ?? 0);

const messagesIn = (roomId) => prisma.rows('chat_messages').filter((m) => m.room_id === roomId);

const notificationsFor = (userId) => prisma.rows('notifications').filter((n) => n.user_id === userId);

const ok = (result) => {
  if (result.status >= 400) throw new Error(`預期成功，卻收到 ${result.status}：${result.text}`);
  return result.body;
};

const openRoom = async (user, partnerId, bookId) => {
  const body = ok(await request('POST', '/api/chat/rooms', {
    token: user.token, body: { user_id: partnerId, ...(bookId ? { book_id: bookId } : {}) }
  }));
  return body.data.room_id;
};

const createGroup = async (owner, memberIds, { name = '讀書會', avatarUrl } = {}) => {
  const body = ok(await request('POST', '/api/chat/groups', {
    token: owner.token, body: { name, member_ids: memberIds, ...(avatarUrl ? { avatar_url: avatarUrl } : {}) }
  }));
  return body.data.room_id;
};

const say = async (user, roomId, content, extra = {}) => {
  const body = ok(await request('POST', `/api/chat/rooms/${roomId}/messages`, {
    token: user.token, body: { content, ...extra }
  }));
  return body.data;
};

// 把訊息的建立時間往前調，用來測試編輯／收回的時間窗。
const ageMessage = (messageId, ms) => {
  const row = prisma.rows('chat_messages').find((m) => m.message_id === messageId);
  row.created_at = new Date(new Date(row.created_at).getTime() - ms);
  return row;
};

// ---------- 推播 ----------

const { privateKey } = crypto.generateKeyPairSync('rsa', {
  modulusLength: 2048,
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
  publicKeyEncoding: { type: 'spki', format: 'pem' }
});

const fcmDir = fs.mkdtempSync(path.join(os.tmpdir(), 'smb-chat-push-'));
const fcmFile = path.join(fcmDir, 'service-account.json');
fs.writeFileSync(fcmFile, JSON.stringify({
  project_id: 'savemybook-test', client_email: 'push@savemybook-test.iam.gserviceaccount.com', private_key: privateKey
}));

const sentPushes = [];

onFetch('https://oauth2.googleapis.com/token', () => jsonResponse({ access_token: 'test-token', expires_in: 3600 }));
onFetch('https://fcm.googleapis.com/', (url, init) => {
  sentPushes.push(JSON.parse(init.body).message);
  return jsonResponse({ name: 'projects/savemybook-test/messages/1' });
});

const push = api('services/push/dispatcher');
const pushSetup = api('services/push/setup');
const { env } = api('config/env');

let pushStarted = false;

const enablePush = async () => {
  if (!pushStarted) {
    env.pushEnabled = true;
    env.fcmServiceAccountFile = fcmFile;
    await pushSetup.init();
    pushStarted = true;
  }
  sentPushes.length = 0;
};

const addDevice = (userId, { platform = 'ios', token } = {}) => {
  const row = {
    device_id: prisma.nextId('push_devices'),
    user_id: userId,
    token: token ?? `token-${userId}-${platform}`,
    platform,
    created_at: new Date(),
    last_seen_at: new Date()
  };
  prisma.rows('push_devices').push(row);
  return row;
};

module.exports = {
  request, runSuite, prisma, api, reset, SCHEMA, ok,
  addUser, addBook, addDevice, openRoom, createGroup, say, ageMessage,
  balanceOf, messagesIn, notificationsFor, setWalletEnumReady,
  enablePush, sentPushes, push, fetchLog
};
