// 商務測試的資料層：在 test/lib 共用的 FakePrisma 之上補齊本組需要的 Prisma 功能
// （關聯 include/select、orderBy/skip/take、upsert、createMany、aggregate、groupBy、
//  以及 increment/decrement 等更新運算子）。以覆寫 prisma.model 的方式安裝，
//  不改動其他測試組共用的 test/lib/fake-prisma.js。
const { registerModels, AUTO_KEYS, UNIQUE_KEYS, MODEL_DEFAULTS } = require('../lib/fake-prisma');

// one：外鍵在自己身上，取第一筆；many：外鍵在對方身上，取全部。
const rel = (table, from, to = from) => ({ table, from, to, type: 'one' });
const many = (table, from, to = from) => ({ table, from, to, type: 'many' });

const RELATIONS = {
  books: {
    users: rel('users', 'seller_id', 'user_id'),
    book_images: many('book_images', 'book_id'),
    book_categories: rel('book_categories', 'category_id'),
    smart_cabinets: rel('smart_cabinets', 'cabinet_id'),
    favorites: many('favorites', 'book_id'),
    shopping_cart: many('shopping_cart', 'book_id'),
    chat_rooms: many('chat_rooms', 'book_id'),
    reports: many('reports', 'book_id', 'target_id')
  },
  users: {
    wallets: rel('wallets', 'user_id'),
    admin_permissions: rel('admin_permissions', 'user_id'),
    books: many('books', 'user_id', 'seller_id')
  },
  orders: {
    order_items: many('order_items', 'order_id'),
    smart_cabinets: rel('smart_cabinets', 'cabinet_id'),
    cabinet_slots: rel('cabinet_slots', 'slot_id'),
    users_orders_buyer_idTousers: rel('users', 'buyer_id', 'user_id'),
    users_orders_seller_idTousers: rel('users', 'seller_id', 'user_id'),
    transaction_disputes: many('transaction_disputes', 'order_id'),
    refund_records: many('refund_records', 'order_id'),
    wallet_transactions: many('wallet_transactions', 'order_id', 'related_order_id')
  },
  order_items: {
    books: rel('books', 'book_id'),
    orders: rel('orders', 'order_id')
  },
  shopping_cart: { books: rel('books', 'book_id'), users: rel('users', 'user_id') },
  favorites: { books: rel('books', 'book_id'), users: rel('users', 'user_id') },
  reservations: { books: rel('books', 'book_id') },
  wallet_transactions: { orders: rel('orders', 'related_order_id', 'order_id'), wallets: rel('wallets', 'wallet_id') },
  wallets: { users: rel('users', 'user_id') },
  reports: {
    users_reports_reporter_idTousers: rel('users', 'reporter_id', 'user_id'),
    users_reports_admin_idTousers: rel('users', 'admin_id', 'user_id')
  },
  transaction_disputes: {
    orders: rel('orders', 'order_id'),
    users_transaction_disputes_applicant_idTousers: rel('users', 'applicant_id', 'user_id')
  },
  refund_records: { orders: rel('orders', 'order_id') },
  support_tickets: {
    users: rel('users', 'user_id'),
    messages: many('support_ticket_messages', 'ticket_id')
  },
  support_ticket_messages: { users: rel('users', 'sender_id', 'user_id') },
  admin_operation_logs: { users: rel('users', 'admin_id', 'user_id') },
  chat_rooms: { books: rel('books', 'book_id') },
  smart_cabinets: {
    cabinet_slots: many('cabinet_slots', 'cabinet_id'),
    orders: many('orders', 'cabinet_id')
  }
};

// Prisma 的複合唯一鍵在 where 中是一個物件，需展開成多個欄位條件。
const COMPOUND_KEYS = {
  shopping_cart: ['user_id_book_id'],
  favorites: ['user_id_book_id'],
  chat_room_members: ['room_id_user_id']
};

const conflictError = () => Object.assign(new Error('Unique constraint failed'), { code: 'P2002' });
const missingError = () => Object.assign(new Error('Record not found'), { code: 'P2025' });

const isPlainObject = (v) => v !== null && typeof v === 'object' && !(v instanceof Date) && !Array.isArray(v);

const compare = (a, b) => {
  if (a instanceof Date || b instanceof Date) return new Date(a).getTime() - new Date(b).getTime();
  if (typeof a === 'number' || typeof b === 'number') return Number(a) - Number(b);
  const [x, y] = [String(a), String(b)];
  return x > y ? 1 : x < y ? -1 : 0;
};

const OPERATORS = {
  in: (actual, want) => want.some((v) => matchValue(actual, v)),
  notIn: (actual, want) => !want.some((v) => matchValue(actual, v)),
  not: (actual, want) => !matchValue(actual, want),
  contains: (actual, want) => String(actual ?? '').toLowerCase().includes(String(want).toLowerCase()),
  lt: (actual, want) => actual != null && compare(actual, want) < 0,
  lte: (actual, want) => actual != null && compare(actual, want) <= 0,
  gt: (actual, want) => actual != null && compare(actual, want) > 0,
  gte: (actual, want) => actual != null && compare(actual, want) >= 0
};

function matchValue(actual, expected) {
  if (expected === undefined) return true;
  if (expected === null) return actual === null || actual === undefined;
  if (expected instanceof Date) return actual != null && new Date(actual).getTime() === expected.getTime();
  if (isPlainObject(expected)) {
    return Object.entries(expected).every(([op, want]) => {
      if (!OPERATORS[op]) throw new Error(`測試假 Prisma 未支援的查詢運算子：${op}`);
      return OPERATORS[op](actual, want);
    });
  }
  return actual === expected;
}

class Store {
  constructor(prisma) {
    this.prisma = prisma;
  }

  rows(table) {
    return this.prisma.rows(table);
  }

  related(spec, row) {
    if (row[spec.from] === null || row[spec.from] === undefined) return [];
    return this.rows(spec.table).filter((other) => other[spec.to] === row[spec.from]);
  }

  match(table, row, where = {}) {
    return Object.entries(where).every(([key, expected]) => {
      if (expected === undefined) return true;
      if (key === 'OR') return expected.some((w) => this.match(table, row, w));
      if (key === 'AND') return expected.every((w) => this.match(table, row, w));
      if (key === 'NOT') return !this.match(table, row, expected);
      if ((COMPOUND_KEYS[table] ?? []).includes(key)) return this.match(table, row, expected);

      const spec = RELATIONS[table]?.[key];
      if (spec && isPlainObject(expected) && !(key in row)) {
        const rows = this.related(spec, row);
        return spec.type === 'one'
          ? rows.length > 0 && this.match(spec.table, rows[0], expected)
          : rows.some((other) => this.match(spec.table, other, expected));
      }
      return matchValue(row[key], expected);
    });
  }

  query(table, args = {}) {
    return this.arrange(this.rows(table).filter((row) => this.match(table, row, args.where ?? {})), args);
  }

  arrange(input, args = {}) {
    let rows = input;
    const orderBy = Array.isArray(args.orderBy) ? args.orderBy : args.orderBy ? [args.orderBy] : [];
    if (orderBy.length > 0) {
      const indexOf = new Map(rows.map((row, i) => [row, i]));
      rows = [...rows].sort((a, b) => {
        for (const clause of orderBy) {
          const [field, direction] = Object.entries(clause)[0];
          const delta = compare(a[field], b[field]);
          if (delta !== 0) return direction === 'desc' ? -delta : delta;
        }
        return indexOf.get(a) - indexOf.get(b);
      });
    }

    if (args.skip) rows = rows.slice(args.skip);
    if (args.take !== undefined) rows = rows.slice(0, args.take);
    return rows;
  }

  counts(table, row, select) {
    return Object.fromEntries(Object.entries(select ?? {}).map(([key, want]) => {
      if (!want) return [key, 0];
      const spec = RELATIONS[table]?.[key];
      if (!spec) throw new Error(`測試假 Prisma 未登記的關聯：${table}._count.${key}`);
      return [key, this.related(spec, row).length];
    }));
  }

  // select 與 include 都可能帶關聯，關聯本身又可再帶 where／orderBy／take。
  expand(table, row, key, spec) {
    const relation = RELATIONS[table]?.[key];
    if (!relation) throw new Error(`測試假 Prisma 未登記的關聯：${table}.${key}`);
    const args = spec === true ? {} : spec;
    const rows = this.arrange(
      this.related(relation, row).filter((other) => this.match(relation.table, other, args.where ?? {})),
      args
    );
    const shaped = rows.map((other) => this.shape(relation.table, other, args));
    return relation.type === 'one' ? shaped[0] ?? null : shaped;
  }

  shape(table, row, args = {}) {
    if (!row) return row;
    const { select, include, omit } = args;

    if (select) {
      const out = {};
      for (const [key, spec] of Object.entries(select)) {
        if (!spec) continue;
        if (key === '_count') out._count = this.counts(table, row, spec.select);
        else if (RELATIONS[table]?.[key] && !(key in row)) out[key] = this.expand(table, row, key, spec);
        else out[key] = row[key] ?? null;
      }
      return out;
    }

    const out = { ...row };
    if (omit) for (const key of Object.keys(omit)) delete out[key];
    for (const [key, spec] of Object.entries(include ?? {})) {
      if (!spec) continue;
      if (key === '_count') out._count = this.counts(table, row, spec.select);
      else out[key] = this.expand(table, row, key, spec);
    }
    return out;
  }

  assertUnique(table, row, ignore = null) {
    for (const keys of UNIQUE_KEYS[table] ?? []) {
      const clash = this.rows(table).some((other) => other !== ignore
        && keys.every((key) => row[key] !== undefined && other[key] === row[key]));
      if (clash) throw conflictError();
    }
  }

  applyData(table, row, data) {
    for (const [key, value] of Object.entries(data)) {
      // Prisma 視 undefined 為「未提供」，寫入會把欄位清成 undefined。
      if (value === undefined) continue;
      if (!isPlainObject(value)) {
        row[key] = value;
        continue;
      }
      if ('increment' in value) row[key] = Number(row[key] ?? 0) + Number(value.increment);
      else if ('decrement' in value) row[key] = Number(row[key] ?? 0) - Number(value.decrement);
      else if ('set' in value) row[key] = value.set;
      else throw new Error(`測試假 Prisma 未支援的更新運算子：${table}.${key}`);
    }
  }

  create(table, data) {
    const key = AUTO_KEYS[table] ?? 'id';
    const nested = [];
    const scalars = {};
    for (const [field, value] of Object.entries(data)) {
      if (value === undefined) continue;
      if (RELATIONS[table]?.[field] && isPlainObject(value) && value.create) nested.push([field, value.create]);
      else scalars[field] = value;
    }

    const row = { ...(MODEL_DEFAULTS[table] ?? {}), created_at: new Date(), updated_at: new Date(), ...scalars };
    if (row[key] === undefined) row[key] = this.prisma.nextId(table);
    this.assertUnique(table, row);
    this.rows(table).push(row);

    for (const [field, children] of nested) {
      const spec = RELATIONS[table][field];
      for (const child of [children].flat()) this.create(spec.table, { ...child, [spec.to]: row[spec.from] });
    }
    return row;
  }
}

const model = (store, table) => ({
  findUnique: async (args) => store.shape(table, store.query(table, { where: args.where })[0] ?? null, args),
  findFirst: async (args = {}) => store.shape(table, store.query(table, args)[0] ?? null, args),
  findMany: async (args = {}) => store.query(table, args).map((row) => store.shape(table, row, args)),
  count: async (args = {}) => store.query(table, { where: args.where }).length,

  create: async (args) => store.shape(table, store.create(table, args.data), args),
  createMany: async (args) => {
    for (const data of [args.data].flat()) store.create(table, data);
    return { count: [args.data].flat().length };
  },
  upsert: async (args) => {
    const row = store.query(table, { where: args.where })[0];
    if (!row) return store.shape(table, store.create(table, { ...args.where, ...args.create }), args);
    store.applyData(table, row, args.update ?? {});
    return store.shape(table, row, args);
  },

  update: async (args) => {
    const row = store.query(table, { where: args.where })[0];
    if (!row) throw missingError();
    store.applyData(table, row, args.data);
    store.assertUnique(table, row, row);
    return store.shape(table, row, args);
  },
  updateMany: async (args) => {
    const rows = store.query(table, { where: args.where ?? {} });
    for (const row of rows) store.applyData(table, row, args.data);
    return { count: rows.length };
  },

  delete: async (args) => {
    const row = store.query(table, { where: args.where })[0];
    if (!row) throw missingError();
    const rows = store.rows(table);
    rows.splice(rows.indexOf(row), 1);
    return row;
  },
  deleteMany: async (args = {}) => {
    const doomed = new Set(store.query(table, { where: args.where ?? {} }));
    store.prisma.store[table] = store.rows(table).filter((row) => !doomed.has(row));
    return { count: doomed.size };
  },

  aggregate: async (args = {}) => {
    const rows = store.query(table, { where: args.where ?? {} });
    const out = {};
    if (args._sum) {
      out._sum = Object.fromEntries(Object.keys(args._sum)
        .map((field) => [field, rows.length ? rows.reduce((sum, row) => sum + Number(row[field] ?? 0), 0) : null]));
    }
    if (args._count) out._count = rows.length;
    return out;
  },
  groupBy: async (args) => {
    const groups = new Map();
    for (const row of store.query(table, { where: args.where ?? {} })) {
      const key = JSON.stringify(args.by.map((field) => row[field]));
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key).push(row);
    }
    return [...groups.values()].map((rows) => ({
      ...Object.fromEntries(args.by.map((field) => [field, rows[0][field]])),
      ...(args._count && {
        _count: args._count === true || args._count._all
          ? { _all: rows.length }
          : Object.fromEntries(Object.keys(args._count).map((field) => [field, rows.length]))
      })
    }));
  }
});

const install = (prisma) => {
  const store = new Store(prisma);
  // FakePrisma 的 Proxy 會優先回傳自有屬性，指派後所有 model 存取都改走這裡。
  prisma.model = (table) => model(store, table);
  return store;
};

module.exports = { install, registerModels, RELATIONS };
