const prisma = require('../lib/prisma');

const VERSION = 2;

const isDecimal = (value) =>
  value !== null && typeof value === 'object' && typeof value.toFixed === 'function' && 'd' in value && 'e' in value;

const encode = (value) => {
  if (value === undefined) return null;
  if (value instanceof Date) return { $t: 'date', v: value.toISOString() };
  if (isDecimal(value)) return { $t: 'decimal', v: value.toString() };
  if (typeof value === 'bigint') return Number(value);
  return value;
};

const decode = (value) => {
  if (value && typeof value === 'object' && value.$t === 'date') return new Date(value.v);
  if (value && typeof value === 'object' && value.$t === 'decimal') return value.v;
  return value;
};

const normalize = (value) => {
  const raw = value && typeof value === 'object' && value.$t ? decode(value) : value;
  if (raw instanceof Date) return raw.getTime();
  if (isDecimal(raw)) return Number(raw.toString());
  if (typeof raw === 'bigint') return Number(raw);
  if (typeof raw === 'string' && raw.trim() !== '' && /^-?\d+(\.\d+)?$/.test(raw)) return Number(raw);
  return raw ?? null;
};

const sameValue = (a, b) => normalize(a) === normalize(b);

const TZ = 'Asia/Taipei';

const display = (value) => {
  const raw = value && typeof value === 'object' && value.$t ? decode(value) : value;
  if (raw === null || raw === undefined || raw === '') return '（空白）';
  if (typeof raw === 'boolean') return raw ? '是' : '否';
  if (raw instanceof Date) return raw.toLocaleString('zh-TW', { timeZone: TZ, hour12: false });
  const text = String(raw);
  return text.length > 120 ? `${text.slice(0, 119)}…` : text;
};

const diff = (before, after, fields) => {
  const changes = [];
  for (const [field, spec] of Object.entries(fields)) {
    if (!after || !(field in after) || after[field] === undefined) continue;
    const from = before?.[field];
    const to = after[field];
    if (sameValue(encode(from), encode(to))) continue;
    const { label, format } = typeof spec === 'string' ? { label: spec } : spec;
    const show = (v) => (format && v !== null && v !== undefined ? format(v) : display(v));
    changes.push({ field, label, from: show(from), to: show(to) });
  }
  return changes;
};

const pick = (row, fields) =>
  Object.fromEntries(fields.filter((f) => row && f in row).map((f) => [f, encode(row[f])]));

const snapshot = (row) => Object.fromEntries(Object.entries(row).map(([k, v]) => [k, encode(v)]));

const undoUpdate = (model, id, before, after, fields) => {
  const names = Array.isArray(fields) ? fields : Object.keys(fields);
  const labels = Array.isArray(fields)
    ? undefined
    : Object.fromEntries(Object.entries(fields).map(([f, s]) => [f, typeof s === 'string' ? s : s.label]));
  const changed = names.filter((f) => after && f in after && after[f] !== undefined);
  return {
    op: 'update', model, id, labels,
    before: pick(before ?? {}, changed),
    after: pick(after, changed)
  };
};
const undoCreate = (model, id) => ({ op: 'delete', model, id });
const undoDelete = (model, row) => ({ op: 'create', model, row: snapshot(row) });
const undoReorder = (model, items) => ({ op: 'reorder', model, items });
const undoWallet = (userId, amount) => ({ op: 'wallet', userId, amount });

const record = (db, {
  adminId, action, targetType = null, targetId = null, summary, changes = [], undo = null, req = null
}) =>
  (db ?? prisma).admin_operation_logs.create({
    data: {
      admin_id: adminId,
      action: String(action).slice(0, 100),
      target_type: targetType,
      target_id: targetId,
      ip_address: req?.ip ? String(req.ip).slice(0, 45) : null,
      detail: JSON.stringify({ v: VERSION, summary, changes, undo: undo && undo.length ? undo : null, reverted: null })
    }
  });

const parseDetail = (detail) => {
  if (typeof detail === 'string' && detail.startsWith('{')) {
    try {
      const parsed = JSON.parse(detail);
      if (parsed?.v === VERSION) return parsed;
    } catch {}
  }
  return { v: 1, summary: detail ?? '', changes: [], undo: null, reverted: null };
};

module.exports = {
  encode, decode, sameValue, display, diff, pick, snapshot,
  undoUpdate, undoCreate, undoDelete, undoReorder, undoWallet,
  record, parseDetail
};
