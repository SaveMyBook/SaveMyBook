#!/usr/bin/env node
/**
 * 檢查 docs/*.yaml 與實際路由是否同步。
 *
 * 直接讀 index.js 的掛載表與各 routes/*.js 的 router.<method>('...')，
 * 跟組出來的 OpenAPI 文件比對。新增路由卻忘了寫文件時會在這裡被抓到。
 *
 *   node scripts/check-docs.js
 */
const fs = require('fs');
const path = require('path');
const { buildSpec } = require('../config/openapi');

const root = path.join(__dirname, '..');
const indexSrc = fs.readFileSync(path.join(root, 'index.js'), 'utf8');

const mounts = {};
for (const m of indexSrc.matchAll(/app\.use\('([^']+)',\s*(\w+)\)/g)) {
  mounts[m[2]] = m[1];
}
const requires = {};
for (const m of indexSrc.matchAll(/const (\w+) = require\('\.\/routes\/(\w+)'\)/g)) {
  requires[m[1]] = m[2];
}

const actual = new Set();
for (const [variable, prefix] of Object.entries(mounts)) {
  const file = requires[variable];
  if (!file) continue;
  const src = fs.readFileSync(path.join(root, 'routes', `${file}.js`), 'utf8');
  for (const m of src.matchAll(/^router\.(get|post|put|patch|delete)\('([^']*)'/gm)) {
    const full = ((prefix.replace(/\/$/, '') + m[2]).replace(/\/$/, '') || '/')
      .replace(/:(\w+)/g, '{$1}');
    actual.add(`${m[1]} ${full}`);
  }
}

const spec = buildSpec();
const documented = new Set();
for (const [p, ops] of Object.entries(spec.paths)) {
  for (const method of Object.keys(ops)) {
    if (['get', 'post', 'put', 'patch', 'delete'].includes(method)) {
      documented.add(`${method} ${p}`);
    }
  }
}

// $ref 有沒有指到不存在的元件
const broken = [];
const walk = (node) => {
  if (!node || typeof node !== 'object') return;
  if (Array.isArray(node)) return node.forEach(walk);
  for (const [key, value] of Object.entries(node)) {
    if (key === '$ref' && typeof value === 'string') {
      let cur = spec;
      for (const seg of value.replace(/^#\//, '').split('/')) cur = cur?.[seg];
      if (cur === undefined) broken.push(value);
    } else {
      walk(value);
    }
  }
};
walk(spec);

// operationId 撞名會讓產生出來的 SDK 出問題
const ids = [];
for (const ops of Object.values(spec.paths)) {
  for (const op of Object.values(ops)) {
    if (op && op.operationId) ids.push(op.operationId);
  }
}
const duplicateIds = [...new Set(ids.filter((v, i) => ids.indexOf(v) !== i))];

const missing = [...actual].filter((k) => !documented.has(k)).sort();
const stale = [...documented].filter((k) => !actual.has(k)).sort();

const show = (label, items) => {
  if (items.length === 0) return;
  console.log(`\n${label}`);
  for (const item of items) console.log(`  ${item}`);
};

console.log(`實際端點 ${actual.size}｜已記錄 ${documented.size}｜$ref ${broken.length === 0 ? '全部可解析' : '有問題'}`);
show('❌ 沒有寫進文件的端點：', missing);
show('⚠️  文件有但程式裡找不到的端點：', stale);
show('❌ 指向不存在元件的 $ref：', [...new Set(broken)]);
show('❌ 重複的 operationId：', duplicateIds);

const ok = !missing.length && !stale.length && !broken.length && !duplicateIds.length;
console.log(ok ? '\n✅ 文件與路由一致' : '\n請修正上述問題');
process.exit(ok ? 0 : 1);
