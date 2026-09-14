#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const { buildSpec } = require('../config/openapi');

const root = path.join(__dirname, '..');
const { MOUNTS } = require('../routes');

const routeFiles = (modulePath) => {
  const base = path.join(root, 'routes', modulePath);
  if (fs.existsSync(`${base}.js`)) return [`${base}.js`];

  const indexFile = path.join(base, 'index.js');
  const src = fs.readFileSync(indexFile, 'utf8');
  const block = src.match(/const SECTIONS = \[([\s\S]*?)\]/);
  if (!block) throw new Error(`${path.relative(root, indexFile)} 缺少 SECTIONS`);
  const sections = [...block[1].matchAll(/'([^']+)'/g)].map((m) => path.join(base, `${m[1]}.js`));
  return [indexFile, ...sections];
};

const actual = new Set();
for (const [prefix, modulePath] of MOUNTS) {
  for (const file of routeFiles(modulePath)) {
    const src = fs.readFileSync(file, 'utf8');
    for (const m of src.matchAll(/^router\.(get|post|put|patch|delete)\('([^']*)'/gm)) {
      const full = ((prefix.replace(/\/$/, '') + m[2]).replace(/\/$/, '') || '/')
        .replace(/:(\w+)/g, '{$1}');
      actual.add(`${m[1]} ${full}`);
    }
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
