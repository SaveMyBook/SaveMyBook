// AI 功能共用的關鍵字檢索：中文沒有空白分詞，採「單字＋相鄰雙字」的 BM25，
// 不需要向量資料庫或額外的嵌入費用。客服知識庫、書籍顧問與個人化推薦都用這一套排序。

const BM25_K1 = 1.4;
const BM25_B = 0.6;

const CJK_CLASS = '[\\u3400-\\u9fff\\uf900-\\ufaff]';
const CJK = new RegExp(CJK_CLASS);
const CJK_SPLIT = new RegExp(`(${CJK_CLASS}+)`);

const STOP_CHARS = new Set('的了嗎呢吧啊呀喔哦是我你他她它們在有要會能可以就都也還很請問想這那個和與或及但而為被把讓給對從到於一不本書'.split(''));
// 疑問與語氣用語在短文件裡出現就會拿到很高的分數，但不代表主題相關。
const STOP_BIGRAMS = new Set([
  '怎麼', '麼辦', '麼樣', '怎樣', '如何', '什麼', '甚麼', '麼時', '為什', '可以', '以嗎', '請問', '問一', '一下', '我的', '我要',
  '我想', '想要', '要怎', '一直', '還沒', '沒有', '不能', '能不', '是不', '不是', '有沒', '幫我', '你們', '我們', '這個', '那個',
  '時候', '候可', '了嗎', '的書', '推薦', '薦我', '一本', '一些', '有什', '最近'
]);

const normalize = (text) => String(text ?? '')
  .normalize('NFKC')
  .toLowerCase()
  .replace(/臺/g, '台');

const isCjkChar = (token) => token.length === 1 && CJK.test(token);

// 中文取單字與雙字，英數取整個詞。
const tokenize = (text) => {
  const tokens = [];
  for (const part of normalize(text).split(CJK_SPLIT)) {
    if (!part) continue;
    if (CJK.test(part[0])) {
      for (let i = 0; i < part.length; i += 1) {
        if (!STOP_CHARS.has(part[i])) tokens.push(part[i]);
        const bigram = part.slice(i, i + 2);
        if (bigram.length === 2 && !STOP_BIGRAMS.has(bigram)) tokens.push(bigram);
      }
    } else {
      for (const w of part.split(/[^a-z0-9]+/)) if (w.length >= 2 || /\d/.test(w)) tokens.push(w);
    }
  }
  return tokens;
};

// 單字權重較低，避免「書」「錢」這類字壓過整個詞。
const tokenWeight = (token) => (isCjkChar(token) ? 0.35 : 1);

// fields 為 [{ text, weight }]，權重高的欄位（例如書名）等同重複出現數次。
const termFrequencies = (fields) => {
  const tf = new Map();
  let length = 0;
  for (const { text, weight = 1 } of fields) {
    for (const t of tokenize(text)) {
      tf.set(t, (tf.get(t) ?? 0) + weight);
      length += weight;
    }
  }
  return { tf, length };
};

// docs 為 [{ id, fields: [{ text, weight }], ...任意資料 }]。
const buildIndex = (docs) => {
  const entries = docs.map((doc) => ({ doc, ...termFrequencies(doc.fields) }));
  const df = new Map();
  for (const e of entries) for (const t of e.tf.keys()) df.set(t, (df.get(t) ?? 0) + 1);
  const avgLength = entries.reduce((sum, e) => sum + e.length, 0) / Math.max(1, entries.length);
  return { entries, df, avgLength: avgLength || 1, size: entries.length };
};

// parts 為 [{ text, weight }]；同一詞取最高權重，較不重要的部分（例如前文）給較低權重。
const queryWeights = (parts, expand = (t) => t) => {
  const weights = new Map();
  for (const { text, weight } of parts) {
    if (!text) continue;
    for (const t of tokenize(expand(text))) weights.set(t, Math.max(weights.get(t) ?? 0, weight * tokenWeight(t)));
  }
  return weights;
};

const idf = (index, token) => {
  const n = index.df.get(token) ?? 0;
  return Math.log(1 + (index.size - n + 0.5) / (n + 0.5));
};

const score = (index, entry, weights) => {
  let total = 0;
  for (const [token, qWeight] of weights) {
    const f = entry.tf.get(token);
    if (!f) continue;
    const norm = (f * (BM25_K1 + 1)) / (f + BM25_K1 * (1 - BM25_B + BM25_B * (entry.length / index.avgLength)));
    total += qWeight * idf(index, token) * norm;
  }
  return total;
};

// 至少要有一個多字詞（雙字或英數詞）命中才算相關，只有零星單字相同的文件不列入。
const hasStrongMatch = (entry, weights) => {
  for (const token of weights.keys()) if (!isCjkChar(token) && entry.tf.has(token)) return true;
  return false;
};

const rank = (index, weights, { filter = null, strong = false } = {}) => {
  if (weights.size === 0) return [];
  return index.entries
    .filter((e) => !filter || filter(e.doc))
    .filter((e) => !strong || hasStrongMatch(e, weights))
    .map((e) => ({ doc: e.doc, score: score(index, e, weights) }))
    .filter((r) => r.score > 0)
    .sort((a, b) => b.score - a.score);
};

module.exports = { normalize, tokenize, tokenWeight, buildIndex, queryWeights, score, rank };
