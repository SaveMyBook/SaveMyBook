const { clip } = require('../text');

// check() 為伺服器端驗證器，所有服務商的輸出都要經過（含 OpenAI 嚴格模式），長度上限也在這裡處理。
// 欄位有 default 時，缺少或型別不符都改用預設值；沒有 default 的欄位才算格式錯誤。

const node = (type, options = {}) => ({ ...options, type });

const string = (options) => node('string', options);
const integer = (options) => node('integer', options);
const number = (options) => node('number', options);
const boolean = (options) => node('boolean', options);
const enumOf = (values, options = {}) => node('string', { ...options, enum: values });
const array = (items, options = {}) => node('array', { ...options, items });
const object = (properties, options = {}) => node('object', { ...options, properties });

// OpenAI 的 json_schema 名稱只接受英數、底線與連字號。
const NAME_FORMAT = /^[A-Za-z0-9_-]{1,64}$/;

const define = (name, root) => {
  if (!NAME_FORMAT.test(name)) throw new Error(`schema 名稱不合法：${name}`);
  if (root.type !== 'object') throw new Error('schema 根節點必須是物件');
  return Object.freeze({ name, root, strict: { name, schema: toStrict(root) } });
};

// 嚴格模式要求所有欄位必填、不得有額外欄位；長度與筆數上限不一定支援，一律交給 check() 處理。
const toStrict = (spec) => {
  let out;
  if (spec.type === 'object') {
    const keys = Object.keys(spec.properties);
    out = {
      type: 'object',
      properties: Object.fromEntries(keys.map((k) => [k, toStrict(spec.properties[k])])),
      required: keys,
      additionalProperties: false
    };
  } else if (spec.type === 'array') {
    out = { type: 'array', items: toStrict(spec.items) };
  } else {
    out = { type: spec.type };
    if (spec.enum) out.enum = spec.nullable ? [...spec.enum, null] : [...spec.enum];
  }
  if (spec.description) out.description = spec.description;
  if (!spec.nullable) return out;
  if (spec.type === 'object' || spec.type === 'array') return { anyOf: [out, { type: 'null' }] };
  return { ...out, type: [spec.type, 'null'] };
};

const isPlainObject = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);

const scalar = (spec, value) => {
  switch (spec.type) {
    case 'string': {
      if (typeof value === 'number' && Number.isFinite(value)) value = String(value);
      if (typeof value !== 'string') return { ok: false };
      if (spec.enum && !spec.enum.includes(value)) return { ok: false };
      return { ok: true, value: spec.max && value.length > spec.max ? clip(value, spec.max) : value };
    }
    case 'integer':
    case 'number': {
      const n = typeof value === 'string' && value.trim() !== '' ? Number(value) : value;
      if (typeof n !== 'number' || !Number.isFinite(n)) return { ok: false };
      if (spec.type === 'integer' && !Number.isInteger(n)) return { ok: false };
      return { ok: true, value: n };
    }
    case 'boolean':
      if (typeof value === 'boolean') return { ok: true, value };
      if (value === 'true' || value === 'false') return { ok: true, value: value === 'true' };
      return { ok: false };
    default:
      return { ok: false };
  }
};

const TYPE_NAMES = { string: '字串', integer: '整數', number: '數字', boolean: '布林值', array: '陣列', object: '物件' };

const clone = (value) => (value === undefined ? undefined : JSON.parse(JSON.stringify(value)));

// 回傳 { ok, value }；ok 為 false 時 problem 為描述，只寫欄位路徑與我方判斷，不含模型輸出的內容。
const walk = (spec, raw, path, stats) => {
  const value = spec.coerce ? spec.coerce(raw) : raw;
  if (value === null && spec.nullable) return { ok: true, value: null };
  if (spec.type === 'object') {
    if (!isPlainObject(value)) return { ok: false, problem: `${path || '輸出'} 應為${TYPE_NAMES.object}` };
    const out = {};
    const problems = [];
    for (const [key, child] of Object.entries(spec.properties)) {
      const childPath = path ? `${path}.${key}` : key;
      if (value[key] === undefined) {
        if ('default' in child) {
          const fallback = clone(child.default);
          if (fallback !== undefined) out[key] = fallback;
          continue;
        }
        problems.push(`缺少 ${childPath}`);
        continue;
      }
      const result = walk(child, value[key], childPath, stats);
      if (result.ok) out[key] = result.value;
      else if ('default' in child) {
        stats.defaulted += 1;
        const fallback = clone(child.default);
        if (fallback !== undefined) out[key] = fallback;
      } else problems.push(...(result.problems ?? [result.problem]));
    }
    return problems.length ? { ok: false, problems } : { ok: true, value: out };
  }
  if (spec.type === 'array') {
    if (!Array.isArray(value)) return { ok: false, problem: `${path} 應為${TYPE_NAMES.array}` };
    const out = [];
    for (const item of value) {
      const result = walk(spec.items, item, `${path}[]`, stats);
      // 單一項目不合格時只捨棄該項，其餘照常採用。
      if (result.ok) out.push(result.value);
      else {
        stats.dropped += 1;
        stats.dropped_in[path] = (stats.dropped_in[path] ?? 0) + 1;
      }
    }
    if (spec.max && out.length > spec.max) {
      stats.truncated += out.length - spec.max;
      out.length = spec.max;
    }
    return { ok: true, value: out };
  }
  const result = scalar(spec, value);
  if (result.ok) return result;
  return { ok: false, problem: spec.enum ? `${path} 不是允許的值` : `${path} 應為${TYPE_NAMES[spec.type] ?? spec.type}` };
};

// problems 為空陣列代表可用；value 只含規格內的欄位。
// stats：defaulted 為型別不符而改用預設值的欄位數，dropped 為捨棄的陣列項目數（dropped_in 依陣列路徑分計），truncated 為超過筆數上限而截掉的項目數。
const check = (schema, json) => {
  const stats = { defaulted: 0, dropped: 0, truncated: 0, dropped_in: {} };
  const result = walk(schema.root, json, '', stats);
  if (!result.ok) return { value: null, problems: result.problems ?? [result.problem], stats };
  return { value: result.value, problems: [], stats };
};

// 清單項目全部因格式不符被捨棄時，check() 留下的空陣列與模型真的回傳空陣列無從分辨；呼叫端在 validate 中以此判斷。
// result 為 runner 的呼叫結果（json 為 check() 整理後的內容，format 為 check() 的統計），path 為清單的欄位路徑（例如 book_ids）。
const allDropped = (result, path) => {
  const list = path.split('.').reduce((value, key) => value?.[key], result.json);
  return Array.isArray(list) && list.length === 0 && (result.format?.dropped_in?.[path] ?? 0) > 0;
};

module.exports = { string, integer, number, boolean, enumOf, array, object, define, check, toStrict, allDropped };
