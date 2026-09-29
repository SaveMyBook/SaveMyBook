const assert = require('assert');
const fs = require('fs');
const path = require('path');
const h = require('./harness');
const golden = require('./golden/eval');

const books = h.api('services/books');
const ranking = h.api('services/ranking');
const cabinets = h.api('services/cabinets');
const reservations = h.api('services/reservations');
const knowledge = h.api('services/ai/knowledge');

// ai-recommend.js 載入時會把這些函式永久換成假資料；本檔依檔名排序先載入，先留下原本的實作，每個測試前再裝回。
const originals = {
  books: { inIdOrder: books.inIdOrder, recommended: books.recommended },
  ranking: { rankedIds: ranking.rankedIds, recommendedIds: ranking.recommendedIds }
};
const restoreOriginals = () => {
  Object.assign(books, originals.books);
  Object.assign(ranking, originals.ranking);
};

const BASELINE_FILE = path.join(__dirname, 'golden', 'baseline.json');
const UPDATE = process.env.GOLDEN_UPDATE === '1';
const VERBOSE = process.env.GOLDEN_VERBOSE === '1';
const WEAK_RANK = 3;

const readBaseline = () => {
  try {
    return JSON.parse(fs.readFileSync(BASELINE_FILE, 'utf8'));
  } catch {
    return {};
  }
};

// 數值物件（指標、門檻）排成一行，名次清單逐題一行，比對版本差異時才看得出是哪一題變動。
const formatJson = (value, indent = '') => {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  const next = `${indent}  `;
  if (Array.isArray(value)) {
    return value.length === 0 ? '[]' : `[\n${value.map((v) => `${next}${formatJson(v, next)}`).join(',\n')}\n${indent}]`;
  }
  const entries = Object.entries(value);
  if (entries.length <= 8 && entries.every(([, v]) => v === null || typeof v !== 'object')) {
    return `{ ${entries.map(([k, v]) => `${JSON.stringify(k)}: ${JSON.stringify(v)}`).join(', ')} }`;
  }
  return `{\n${entries.map(([k, v]) => `${next}${JSON.stringify(k)}: ${formatJson(v, next)}`).join(',\n')}\n${indent}}`;
};

// 門檻取目前結果：命中率與涵蓋率容許少約一題，MRR 容許下降 0.01。
// 題庫不變時更新基準只會調高門檻；題庫變動時依新題庫重算，須在變更說明中註明。
const floor2 = (value) => Math.floor(value * 100 + 1e-9) / 100;
const thresholdsOf = (metrics) => Object.fromEntries(Object.entries(metrics)
  .filter(([key]) => key !== 'n')
  .map(([key, value]) => [key, Math.max(0, floor2(key === 'mrr' ? value - 0.01 : value - 1 / metrics.n))]));

const weakOf = (items) => items
  .filter((i) => i.rank == null || i.rank > WEAK_RANK)
  .map((i) => `${i.id} ${i.label}（${i.rank == null ? '未找到' : `第 ${i.rank} 名`}）`);

const describe = (metrics) => Object.entries(metrics).filter(([k]) => k !== 'n').map(([k, v]) => `${k} ${v}`).join('、');

const report = (name, result, baseline) => {
  console.log(`     ${name}（${result.metrics.n} 筆）：${describe(result.metrics)}`);
  const previous = baseline.ranks?.[name];
  if (previous) {
    const worse = (a, b) => (a ?? Infinity) > (b ?? Infinity);
    const changed = result.items.filter((i) => i.id in previous && (previous[i.id] ?? null) !== i.rank);
    const regressed = changed.filter((i) => worse(i.rank, previous[i.id]));
    const improved = changed.filter((i) => worse(previous[i.id], i.rank));
    const show = (list) => list.map((i) => `${i.id}（${previous[i.id] ?? '未找到'} → ${i.rank ?? '未找到'}）`).join('、');
    if (improved.length) console.log(`     與基準相比改善：${show(improved)}`);
    if (regressed.length) console.log(`     與基準相比退步：${show(regressed)}`);
  }
  if (VERBOSE) for (const line of weakOf(result.items)) console.log(`       弱點 ${line}`);
};

// 整體平均容許少約一題，單題完全退步要另外擋：政策關鍵題不得超過 max_rank，
// 題庫不變時，基準中排在前 3 名的題目也不得變成未找到。
const failuresOf = (name, result, baseline, thresholds) => {
  const below = Object.entries(thresholds)
    .filter(([key, min]) => (result.metrics[key] ?? 0) < min)
    .map(([key, min]) => `${key} ${result.metrics[key]} 低於門檻 ${min}`);
  const overLimit = result.items
    .filter((i) => i.max_rank != null && (i.rank == null || i.rank > i.max_rank))
    .map((i) => `${i.id} ${i.label}：${i.rank == null ? '未找到' : `第 ${i.rank} 名`}，上限為第 ${i.max_rank} 名`);
  const previous = baseline.banks?.[name] === golden.bankHash(name) ? baseline.ranks?.[name] ?? {} : {};
  const lost = result.items
    .filter((i) => previous[i.id] != null && previous[i.id] <= WEAK_RANK && i.rank == null)
    .map((i) => `${i.id} ${i.label}：基準為第 ${previous[i.id]} 名，現在未找到`);
  return [...below, ...overLimit, ...lost];
};

const check = (name, result) => {
  const baseline = readBaseline();
  report(name, result, baseline);
  const bank = golden.bankHash(name);
  const sameBank = baseline.banks?.[name] === bank;
  let thresholds = baseline.thresholds?.[name];
  if (UPDATE) {
    const computed = thresholdsOf(result.metrics);
    thresholds = sameBank && thresholds
      ? Object.fromEntries(Object.entries(computed).map(([k, v]) => [k, Math.max(v, thresholds[k] ?? 0)]))
      : computed;
    if (!sameBank) console.log(`     ${name} 的題庫已變更，門檻依新題庫重新計算`);
  } else {
    assert.ok(sameBank, `${name} 的題庫已變更，請以 GOLDEN_UPDATE=1 執行 AI 測試重新產生 test/ai/golden/baseline.json`);
  }
  assert.ok(thresholds, `缺少 ${name} 的基準，請以 GOLDEN_UPDATE=1 執行 AI 測試產生 test/ai/golden/baseline.json`);
  // 先判定再寫檔，退步的結果不會覆寫基準。
  assert.deepStrictEqual(failuresOf(name, result, baseline, thresholds), [], `${name} 未通過`);
  if (UPDATE) {
    const next = {
      note: '由 test/ai/ai-golden.js 以 GOLDEN_UPDATE=1 產生。banks 為題庫雜湊值，thresholds 為測試門檻，metrics 為當次結果，ranks 為各題第一個正確答案的名次（null 表示未找到），weak 為排在第 3 名之後或未找到的題目。',
      updated_at: new Date().toISOString().slice(0, 10),
      banks: { ...baseline.banks, [name]: bank },
      thresholds: { ...baseline.thresholds, [name]: thresholds },
      metrics: { ...baseline.metrics, [name]: { ...result.metrics, by_tag: result.by_tag } },
      weak: { ...baseline.weak, [name]: weakOf(result.items) },
      ranks: { ...baseline.ranks, [name]: Object.fromEntries(result.items.map((i) => [i.id, i.rank])) }
    };
    fs.writeFileSync(BASELINE_FILE, `${formatJson(next)}\n`);
  }
};

const docIds = () => new Set([
  ...knowledge.PLATFORM_TOPICS.map((t) => t.id),
  ...golden.seedDocuments(h.API_ROOT).faqs.map((f) => `faq:${f.faq_id}`)
]);

module.exports = {
  name: 'AI 固定答案評測（檢索命中率與 MRR）',
  before: restoreOriginals,
  tests: [
    ['題庫：預期答案存在，且不是依規則不可推薦的書；必須出現的書依規則確實可購買', () => {
      const ids = docIds();
      const { questions } = golden.load('support');
      for (const q of questions) {
        assert.ok(q.expect.length > 0, q.id);
        for (const id of q.expect) assert.ok(ids.has(id), `${q.id} 的 ${id} 不存在`);
        assert.ok(q.max_rank == null || (Number.isInteger(q.max_rank) && q.max_rank >= 1), `${q.id} 的 max_rank 無效`);
      }
      const holdsOf = (catalog, viewer) => new Set(catalog.reservations
        .filter((r) => r.status !== 'confirmed' || !(r.hours > 0) || r.buyer_id === viewer)
        .map((r) => r.book_id));

      const { catalog, byId, blocked } = golden.seedCatalog(h.prisma);
      const { queries } = golden.load('book-chat');
      const mustShow = [];
      for (const q of queries) {
        const unavailable = blocked(q.viewer ?? 120);
        for (const id of q.must_show ?? []) {
          assert.ok(byId.has(id) && !unavailable.has(id), `${q.id} 的必須出現書 ${id} 依規則不可購買`);
          mustShow.push(...(holdsOf(catalog, q.viewer ?? 120).has(id) ? [id] : []));
        }
        const { max_price: max, min_price: min, condition_levels: levels = [] } = q.search;
        for (const id of q.expect) {
          const book = byId.get(id);
          assert.ok(book && !unavailable.has(id), `${q.id} 的書 ${id} 不可推薦`);
          assert.ok((max == null || book.price <= max) && (min == null || book.price >= min), `${q.id} 的書 ${id} 不符預算`);
          assert.ok(levels.length === 0 || levels.includes(book.condition_level), `${q.id} 的書 ${id} 不符書況`);
        }
      }

      const { personas } = golden.load('recommend');
      for (const p of personas) {
        const unavailable = blocked(p.user);
        const own = new Set([...(p.favorites ?? []), ...(p.cart ?? []), ...(p.purchases ?? []).map(([id]) => id), ...(p.viewed ?? [])]);
        for (const id of [...p.expect, ...(p.must_show ?? [])]) {
          assert.ok(byId.has(id) && !unavailable.has(id) && !own.has(id), `${p.id} 的書 ${id} 不可推薦`);
        }
        for (const id of p.must_show ?? []) mustShow.push(...(holdsOf(catalog, p.user).has(id) ? [id] : []));
      }

      // 已過期、待回覆與本人的預約都要各有一題檢查，否則過度排除這類書不會被發現。
      const kinds = catalog.reservations.map((r) => [r.book_id, r.status !== 'confirmed' ? 'pending' : r.hours > 0 ? 'own' : 'expired']);
      const covered = new Set(kinds.filter(([id]) => mustShow.includes(id)).map(([, kind]) => kind));
      assert.deepStrictEqual(['expired', 'own', 'pending'].filter((k) => !covered.has(k)), []);
    }],

    ['客服：知識庫檢索的命中率與 MRR 不低於基準', async () => {
      check('support', await golden.evaluateSupport(h));
    }],

    ['書籍顧問（依模型的搜尋條件）：不列出不可購買或不符條件的書，命中率不低於基準', async () => {
      const result = await golden.evaluateBookChat(h, 'planned');
      assert.deepStrictEqual(result.violations, []);
      check('book_chat_planned', result);
    }],

    ['書籍顧問（只用使用者原話）：不列出不可購買的書，命中率不低於基準', async () => {
      const result = await golden.evaluateBookChat(h, 'raw');
      assert.deepStrictEqual(result.violations, []);
      check('book_chat_raw', result);
    }],

    ['推薦：他人保留中、書櫃維修中、本人上架與非在售的書一律不出現，命中率不低於基準', async () => {
      const result = await golden.evaluateRecommend(h);
      assert.deepStrictEqual(result.violations, []);
      check('recommend', result);
    }],

    ['評測本身：可購買判斷失效時，書籍顧問與推薦都會抓到他人保留中與維修中的書', async () => {
      const { maintenanceIds } = cabinets;
      const { heldByOthers } = reservations;
      cabinets.maintenanceIds = async () => new Set();
      reservations.heldByOthers = async () => new Set();
      try {
        for (const [name, run] of [['書籍顧問', () => golden.evaluateBookChat(h, 'planned')], ['推薦', () => golden.evaluateRecommend(h)]]) {
          const { violations } = await run();
          assert.ok(violations.some((v) => v.includes('他人預約保留中')), `${name}未偵測到他人保留中的書`);
          assert.ok(violations.some((v) => v.includes('書櫃維修中')), `${name}未偵測到維修中的書`);
        }
      } finally {
        cabinets.maintenanceIds = maintenanceIds;
        reservations.heldByOthers = heldByOthers;
      }
    }],

    ['評測本身：保留判斷過度排除時（忽略期限與待回覆、或未區分本人），書籍顧問與推薦都會抓到', async () => {
      const { heldByOthers } = reservations;
      const rows = () => h.prisma.store.reservations;
      const variants = [
        ['忽略期限且把待回覆算成保留', async (viewer) => new Set(rows().filter((r) => r.buyer_id !== viewer).map((r) => Number(r.book_id)))],
        ['未區分本人的保留', async () => heldByOthers(null)]
      ];
      try {
        for (const [variant, impl] of variants) {
          reservations.heldByOthers = impl;
          for (const [name, run] of [['書籍顧問', () => golden.evaluateBookChat(h, 'planned')], ['推薦', () => golden.evaluateRecommend(h)]]) {
            const { violations } = await run();
            assert.ok(violations.some((v) => v.includes('可購買卻被排除')), `${variant}：${name}未偵測到過度排除`);
          }
        }
      } finally {
        reservations.heldByOthers = heldByOthers;
      }
    }],

    ['評測本身：單題完全退步時，即使整體平均仍在門檻內也判定失敗', async () => {
      const baseline = readBaseline();
      const result = await golden.evaluateSupport(h);
      const drop = (id) => ({ ...result, items: result.items.map((i) => (i.id === id ? { ...i, rank: null } : i)) });
      const guarded = result.items.find((i) => i.max_rank != null && i.rank === 1);
      const unguarded = result.items.find((i) => i.max_rank == null && i.rank === 1);
      for (const item of [guarded, unguarded]) {
        const failures = failuresOf('support', drop(item.id), baseline, {});
        assert.ok(failures.some((f) => f.startsWith(item.id)), `${item.id} 退步未被偵測`);
      }
    }]
  ]
};
