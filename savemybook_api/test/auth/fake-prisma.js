// 以記憶體資料表模擬 Prisma Client：支援本專案實際用到的 model API 與原生 SQL 子集。
const AUTO_KEYS = {
  users: 'user_id',
  login_logs: 'log_id',
  user_identities: 'identity_id',
  admin_operation_logs: 'log_id',
  notifications: 'notification_id'
};

const UNIQUE_KEYS = {
  users: [['email'], ['user_id']],
  user_identities: [['provider', 'subject']],
  auth_settings: [['id']],
  oauth_states: [['state']],
  oauth_results: [['code']],
  admin_permissions: [['user_id']]
};

// 資料表層級的預設值，Prisma 的 @default 在此自行補上。
const MODEL_DEFAULTS = {
  users: {
    avatar_url: null, bio: null, phone: null, birthday: null, gender: 'undisclosed',
    role: 'buyer_seller', is_active: true, is_blacklisted: false, bonus_points: 0,
    deletion_requested_at: null, anonymized_at: null, share_token: null, password_set: 1
  },
  login_logs: { login_at: new Date(), ip_address: null, device_info: null }
};

const conflictError = () => Object.assign(new Error('Unique constraint failed'), { code: 'P2002' });
const missingError = () => Object.assign(new Error('Record not found'), { code: 'P2025' });

const matchValue = (actual, expected) => {
  if (expected === null) return actual === null || actual === undefined;
  if (expected instanceof Date) return actual instanceof Date && actual.getTime() === expected.getTime();
  if (expected && typeof expected === 'object') {
    if ('in' in expected) return expected.in.some((v) => matchValue(actual, v));
    if ('not' in expected) {
      return expected.not === null ? actual !== null && actual !== undefined : !matchValue(actual, expected.not);
    }
    if ('lte' in expected) return actual != null && new Date(actual) <= new Date(expected.lte);
    if ('gte' in expected) return actual != null && new Date(actual) >= new Date(expected.gte);
    return false;
  }
  return actual === expected;
};

const matchWhere = (row, where = {}) => Object.entries(where).every(([key, expected]) => {
  if (key === 'OR') return expected.some((w) => matchWhere(row, w));
  if (key === 'AND') return expected.every((w) => matchWhere(row, w));
  return matchValue(row[key], expected);
});

const project = (row, { select, omit } = {}) => {
  if (!row) return row;
  if (select) {
    const out = {};
    for (const [key, want] of Object.entries(select)) if (want) out[key] = row[key] ?? null;
    return out;
  }
  if (omit) {
    const out = { ...row };
    for (const key of Object.keys(omit)) delete out[key];
    return out;
  }
  return { ...row };
};

// ---------- 原生 SQL 迷你直譯器 ----------

const splitTop = (text, separator) => {
  const parts = [];
  let depth = 0;
  let current = '';
  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i];
    if (ch === '(') depth += 1;
    if (ch === ')') depth -= 1;
    if (depth === 0 && text.slice(i, i + separator.length).toUpperCase() === separator.toUpperCase()) {
      parts.push(current);
      current = '';
      i += separator.length - 1;
      continue;
    }
    current += ch;
  }
  parts.push(current);
  return parts.map((p) => p.trim()).filter(Boolean);
};

const countPlaceholders = (text) => (text ? (text.match(/\?/g) ?? []).length : 0);

class Params {
  constructor(values) {
    this.values = values;
    this.index = 0;
  }

  next() {
    const value = this.values[this.index];
    this.index += 1;
    return value;
  }
}

const compare = (a, b, op) => {
  const left = a instanceof Date ? a.getTime() : a;
  const right = b instanceof Date || (typeof b === 'string' && a instanceof Date) ? new Date(b).getTime() : b;
  if (op === '=') return String(left) === String(right);
  if (op === '<') return left < right;
  if (op === '>') return left > right;
  return false;
};

const evalCondition = (row, text, params) => {
  const trimmed = text.trim().replace(/^\((.*)\)$/s, '$1').trim();
  const orParts = splitTop(trimmed, ' OR ');
  if (orParts.length > 1) return orParts.map((part) => evalCondition(row, part, params)).some(Boolean);

  let m = /^(\w+)\s+IS\s+NOT\s+NULL$/i.exec(trimmed);
  if (m) return row[m[1]] !== null && row[m[1]] !== undefined;
  m = /^(\w+)\s+IS\s+NULL$/i.exec(trimmed);
  if (m) return row[m[1]] === null || row[m[1]] === undefined;
  m = /^(\w+)\s*(=|<|>)\s*\?$/.exec(trimmed);
  if (m) return compare(row[m[1]], params.next(), m[2]);
  m = /^(\w+)\s*<>\s*\?$/.exec(trimmed);
  if (m) return !compare(row[m[1]], params.next(), '=');
  m = /^(\w+)\s*=\s*'([^']*)'$/.exec(trimmed);
  if (m) return String(row[m[1]] ?? '') === m[2];
  m = /^(\w+)\s*=\s*(\d+)$/.exec(trimmed);
  if (m) return Number(row[m[1]]) === Number(m[2]);
  m = /^(\w+)\s+IN\s*\(([^)]*)\)$/i.exec(trimmed);
  if (m) {
    const wanted = m[2].split(',').map((token) => (token.trim() === '?' ? params.next() : token.trim().replace(/'/g, '')));
    return wanted.some((value) => String(row[m[1]]) === String(value));
  }
  throw new Error(`SQL 條件未支援：${trimmed}`);
};

// 不做短路求值，確保每次都固定消耗同樣數量的參數。
const evalWhere = (row, whereText, params, start) => {
  params.index = start;
  if (!whereText) return true;
  return splitTop(whereText, ' AND ').map((part) => evalCondition(row, part, params)).every(Boolean);
};

class FakePrisma {
  constructor({ tables = {} } = {}) {
    this.store = tables;
    this.sqlLog = [];
    return new Proxy(this, {
      get: (target, prop) => {
        if (prop in target) return target[prop];
        if (typeof prop !== 'string' || prop.startsWith('$') || prop === 'then') return undefined;
        return target.model(prop);
      }
    });
  }

  rows(table) {
    if (!this.store[table]) this.store[table] = [];
    return this.store[table];
  }

  nextId(table) {
    const key = AUTO_KEYS[table] ?? 'id';
    return this.rows(table).reduce((max, row) => Math.max(max, Number(row[key]) || 0), 0) + 1;
  }

  assertUnique(table, row, ignore = null) {
    for (const keys of UNIQUE_KEYS[table] ?? []) {
      const clash = this.rows(table).some((other) => other !== ignore
        && keys.every((key) => row[key] !== undefined && other[key] === row[key]));
      if (clash) throw conflictError();
    }
  }

  model(table) {
    const rows = () => this.rows(table);
    return {
      findUnique: async (args) => project(rows().find((row) => matchWhere(row, args.where)) ?? null, args),
      findFirst: async (args = {}) => project(rows().find((row) => matchWhere(row, args.where ?? {})) ?? null, args),
      findMany: async (args = {}) => rows().filter((row) => matchWhere(row, args.where ?? {})).map((row) => project(row, args)),
      count: async (args = {}) => rows().filter((row) => matchWhere(row, args.where ?? {})).length,
      create: async (args) => {
        const key = AUTO_KEYS[table] ?? 'id';
        const row = {
          ...(MODEL_DEFAULTS[table] ?? {}), created_at: new Date(), updated_at: new Date(), ...args.data
        };
        if (row[key] === undefined) row[key] = this.nextId(table);
        this.assertUnique(table, row);
        rows().push(row);
        return project(row, args);
      },
      update: async (args) => {
        const row = rows().find((item) => matchWhere(item, args.where));
        if (!row) throw missingError();
        Object.assign(row, args.data);
        this.assertUnique(table, row, row);
        return project(row, args);
      },
      updateMany: async (args) => {
        const affected = rows().filter((row) => matchWhere(row, args.where ?? {}));
        affected.forEach((row) => Object.assign(row, args.data));
        return { count: affected.length };
      },
      delete: async (args) => {
        const index = rows().findIndex((row) => matchWhere(row, args.where));
        if (index < 0) throw missingError();
        return rows().splice(index, 1)[0];
      },
      deleteMany: async (args = {}) => {
        const keep = rows().filter((row) => !matchWhere(row, args.where ?? {}));
        const removed = rows().length - keep.length;
        this.store[table] = keep;
        return { count: removed };
      }
    };
  }

  runInsert(sql, values) {
    const m = /^INSERT\s+(?:IGNORE\s+)?INTO\s+(\w+)\s*\(([^)]+)\)\s*VALUES\s*\(([^)]*)\)(?:\s+ON DUPLICATE KEY UPDATE\s+(.+))?$/i.exec(sql);
    if (!m) return null;

    const [, table, columnList, valueList, onDuplicate] = m;
    const params = new Params(values);
    const columns = columnList.split(',').map((c) => c.trim());
    const row = {};
    valueList.split(',').map((v) => v.trim()).forEach((token, i) => {
      row[columns[i]] = token === '?' ? params.next() : token.replace(/^'|'$/g, '');
    });

    const existing = (UNIQUE_KEYS[table] ?? [])
      .flatMap((keys) => this.rows(table).filter((other) => keys.every((key) => other[key] === row[key])));
    if (existing.length) {
      if (!onDuplicate) throw conflictError();
      Object.assign(existing[0], row);
      return 1;
    }
    const key = AUTO_KEYS[table];
    if (key && row[key] === undefined) row[key] = this.nextId(table);
    this.rows(table).push(row);
    return 1;
  }

  runUpdate(sql, values) {
    const m = /^UPDATE\s+(\w+)\s+SET\s+(.+?)(?:\s+WHERE\s+(.+))?$/i.exec(sql);
    if (!m) return null;

    const [, table, setText, whereText] = m;
    const params = new Params(values);
    const assignments = splitTop(setText, ',').map((part) => {
      const [, column, expression] = /^(\w+)\s*=\s*(.+)$/s.exec(part.trim());
      return { column, expression, value: expression.includes('?') ? params.next() : undefined };
    });

    const whereStart = params.index;
    let count = 0;
    for (const row of this.rows(table)) {
      if (!evalWhere(row, whereText, params, whereStart)) continue;
      for (const item of assignments) {
        const { column, expression, value } = item;
        if (expression === '?') row[column] = value;
        else if (/^COALESCE\(\?,/i.test(expression)) row[column] = value ?? row[column] ?? null;
        else if (/^\d+$/.test(expression)) row[column] = Number(expression);
        else if (/^'.*'$/.test(expression)) row[column] = expression.slice(1, -1);
        else if (expression.toUpperCase() === 'NULL') row[column] = null;
        else throw new Error(`SQL 指派未支援：${expression}`);
      }
      count += 1;
    }
    params.index = whereStart + countPlaceholders(whereText);
    return count;
  }

  runDelete(sql, values) {
    const m = /^DELETE\s+FROM\s+(\w+)(?:\s+WHERE\s+(.+))?$/i.exec(sql);
    if (!m) return null;

    const [, table, whereText] = m;
    const params = new Params(values);
    const keep = [];
    let count = 0;
    for (const row of this.rows(table)) {
      if (evalWhere(row, whereText, params, 0)) count += 1;
      else keep.push(row);
    }
    this.store[table] = keep;
    return count;
  }

  runSelect(sql, values) {
    const m = /^SELECT\s+(.+?)\s+FROM\s+(\w+)(?:\s+WHERE\s+(.+?))?(?:\s+ORDER BY\s+(.+?))?$/i.exec(sql);
    if (!m) return null;

    const [, columnText, table, whereText, orderText] = m;
    const params = new Params(values);
    let selected = this.rows(table).filter((row) => evalWhere(row, whereText, params, 0));

    if (orderText) {
      const [column, direction = 'ASC'] = orderText.trim().split(/\s+/);
      selected = [...selected].sort((a, b) => {
        const left = a[column] instanceof Date ? a[column].getTime() : a[column];
        const right = b[column] instanceof Date ? b[column].getTime() : b[column];
        const delta = left > right ? 1 : left < right ? -1 : 0;
        return direction.toUpperCase() === 'DESC' ? -delta : delta;
      });
    }

    if (/^COUNT\(\*\)/i.test(columnText.trim())) {
      const alias = /AS\s+(\w+)/i.exec(columnText)?.[1] ?? 'count';
      return [{ [alias]: BigInt(selected.length) }];
    }
    if (columnText.trim() === '*') return selected.map((row) => ({ ...row }));

    const columns = columnText.split(',').map((token) => {
      const parsed = /^\s*(\w+)(?:\s+AS\s+(\w+))?\s*$/i.exec(token);
      if (!parsed) throw new Error(`SQL 欄位未支援：${token}`);
      return { column: parsed[1], alias: parsed[2] ?? parsed[1] };
    });
    return selected.map((row) => Object.fromEntries(columns.map((c) => [c.alias, row[c.column] ?? null])));
  }

  run(rawSql, values) {
    const sql = rawSql.replace(/\s+/g, ' ').trim().replace(/;$/, '');
    this.sqlLog.push(sql);
    // 本套件只驗證登入方式相關的 SQL，其他模組的關聯查詢一律視為空結果。
    if (/\sJOIN\s/i.test(sql)) return [];

    for (const handler of [this.runInsert, this.runUpdate, this.runDelete, this.runSelect]) {
      const result = handler.call(this, sql, values);
      if (result !== null) return result;
    }
    throw new Error(`SQL 未支援：${sql}`);
  }

  $queryRaw(strings, ...values) {
    return Promise.resolve(this.run(strings.join('?'), values));
  }

  $executeRaw(strings, ...values) {
    return Promise.resolve(this.run(strings.join('?'), values));
  }

  $queryRawUnsafe(sql, ...values) {
    return Promise.resolve(this.run(sql, values));
  }

  $executeRawUnsafe(sql, ...values) {
    return Promise.resolve(this.run(sql, values));
  }

  $transaction(fn) {
    return Array.isArray(fn) ? Promise.all(fn) : fn(this);
  }

  $disconnect() {
    return Promise.resolve();
  }
}

module.exports = { FakePrisma };
