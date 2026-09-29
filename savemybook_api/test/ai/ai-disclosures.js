const assert = require('assert');
const fs = require('fs');
const path = require('path');
const h = require('./harness');

const { DISCLOSURES, EMBEDDING_FEATURES } = h.api('services/ai/disclosures');
const usage = h.api('services/ai/usage');
const runner = h.api('services/ai/runner');
const consent = h.api('services/ai/consent');
const support = h.api('services/ai/support');
const { EVIDENCE_IMAGES } = h.api('services/ai/dispute-assist');

const CONSENTED_HEADING = '經您同意 AI 資料處理後，始傳送下列內容：';
const NECESSARY_HEADING = '下列處理為平台運作所必要，不以您的同意為前提：';

const sourceFiles = (dir) => fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
  const full = path.join(dir, entry.name);
  if (entry.isDirectory()) return sourceFiles(full);
  return entry.name.endsWith('.js') ? [full] : [];
});

const SOURCES = ['services', 'routes'].flatMap((dir) => sourceFiles(path.join(h.API_ROOT, dir)))
  .map((file) => ({ file: path.relative(h.API_ROOT, file), text: fs.readFileSync(file, 'utf8') }));

const calledFeatures = () => {
  const found = new Map();
  for (const { file, text } of SOURCES) {
    for (const m of text.matchAll(/runner\.call\('(\w+)'|feature: '(\w+)'/g)) {
      const feature = m[1] ?? m[2];
      if (!found.has(feature)) found.set(feature, new Set());
      found.get(feature).add(file);
    }
  }
  return found;
};

const privacyPolicy = () => {
  const seed = fs.readFileSync(path.join(h.API_ROOT, 'prisma/seed.sql'), 'utf8');
  const match = seed.match(/\('privacy',\s*'隱私權政策',\s*'((?:[^']|'')*)'/);
  assert.ok(match, 'seed.sql 找不到隱私權政策');
  return match[1].replace(/''/g, "'");
};

const bulletOf = (policy, label) => {
  const line = policy.split('\n').find((l) => l.trim().startsWith(`- ${label}：`));
  assert.ok(line, `隱私權政策缺少「${label}」條目`);
  return line;
};

// 客服【使用者資料】各區塊對應的揭露資料類別。
const SUPPORT_SECTIONS = {
  錢包餘額: '電子錢包餘額',
  錢包收支: '收支紀錄',
  交易爭議: '交易爭議',
  訂單: '訂單',
  上架的書籍: '上架書籍',
  預約: '預約',
  客服提問: '客服工單'
};

module.exports = {
  name: 'AI 功能與隱私揭露對照',
  tests: [
    ['每項 AI 功能都有揭露條目，且程式中呼叫 AI 的功能代碼都在用量功能清單中', () => {
      assert.deepStrictEqual(Object.keys(DISCLOSURES).sort(), [...usage.FEATURES].sort());
      const unknown = [...calledFeatures().keys()].filter((f) => !usage.FEATURES.includes(f));
      assert.deepStrictEqual(unknown, []);
      for (const [feature, entry] of Object.entries(DISCLOSURES)) {
        if (entry.privacy) assert.ok(entry.data.length > 0, `${feature} 未列出送出的資料`);
        else assert.ok(entry.exempt, `${feature} 未列入隱私權政策時須說明理由`);
      }
    }],

    ['使用者端功能都需要同意，且呼叫模型的服務會先檢查同意', () => {
      for (const feature of runner.USER_FEATURES) assert.strictEqual(DISCLOSURES[feature].consent, true, feature);
      const called = calledFeatures();
      for (const [feature, entry] of Object.entries(DISCLOSURES)) {
        if (!entry.consent) continue;
        for (const file of called.get(feature) ?? []) {
          const text = SOURCES.find((s) => s.file === file).text;
          assert.match(text, /consent\.(assertGranted|isGranted)\(/, `${file} 呼叫 ${feature} 前未檢查同意`);
        }
      }
    }],

    ['隱私權政策範本：每個揭露條目列在正確的分組，並提到實際送出的資料類別', () => {
      const policy = privacyPolicy();
      const consentedAt = policy.indexOf(CONSENTED_HEADING);
      const necessaryAt = policy.indexOf(NECESSARY_HEADING);
      assert.ok(consentedAt > 0 && necessaryAt > consentedAt, '隱私權政策缺少同意與必要處理的分組');
      for (const [feature, entry] of Object.entries(DISCLOSURES)) {
        if (!entry.privacy) continue;
        const line = bulletOf(policy, entry.privacy);
        const at = policy.indexOf(line);
        if (entry.consent) assert.ok(at > consentedAt && at < necessaryAt, `${feature} 應列在須同意的分組`);
        else assert.ok(at > necessaryAt, `${feature} 應列在平台必要處理的分組`);
        for (const item of entry.data) assert.ok(line.includes(item), `「${entry.privacy}」條目未提到${item}`);
      }
    }],

    ['隱私權政策範本：保存期限、爭議照片張數與嵌入服務商和程式一致，且不再宣稱未送出錢包餘額', () => {
      const policy = privacyPolicy();
      assert.ok(policy.includes(`保存 ${consent.CONVERSATION_RETENTION_DAYS} 日`));
      assert.ok(bulletOf(policy, '交易爭議分析').includes(`最多 ${EVIDENCE_IMAGES} 張佐證照片`));
      const embedding = bulletOf(policy, '語意檢索');
      for (const name of ['OpenAI', 'Google Gemini']) assert.ok(embedding.includes(name));
      for (const feature of EMBEDDING_FEATURES) {
        assert.ok(embedding.includes(DISCLOSURES[feature].privacy), `語意檢索條目未提到${DISCLOSURES[feature].privacy}`);
      }
      assert.doesNotMatch(policy, /不包含[^。]*電子錢包餘額/);
      assert.match(policy, /撤回後[^。]*刪除您的 AI 客服與 AI 書籍顧問對話紀錄/);
    }],

    ['客服提示詞帶入的每一類使用者資料都已揭露', async () => {
      h.setSettings({ enabled: true });
      h.setConsent(1, true);
      h.onModel('orders.findMany', () => [{ order_no: 'SMB001', status: 'completed', total_amount: 90, created_at: new Date(), order_items: [] }]);
      h.onModel('reservations.findMany', () => [{ status: 'confirmed', created_at: new Date(), books: { title: '白夜行' } }]);
      h.onModel('books.findMany', () => [{
        title: '畫冊', price: 900, status: 'on_sale', is_approved: false, created_at: new Date(),
        ai_book_reviews: { status: 'rejected', reasons: JSON.stringify(['疑似非書籍']) }
      }]);
      h.onModel('wallets.findUnique', () => ({ wallet_id: 1, balance: 50 }));
      h.onModel('wallet_transactions.findMany', () => [{ type: 'purchase', amount: -90, created_at: new Date(), orders: { order_no: 'SMB001' } }]);
      h.onModel('transaction_disputes.findMany', () => [{ applicant_id: 1, status: 'pending', result: null, created_at: new Date(), orders: { order_no: 'SMB001' } }]);
      h.onModel('support_tickets.findMany', () => [{ subject: '退款', status: 'open', updated_at: new Date() }]);

      const system = await support.buildSystem(1, { question: '我的書 SMB20260920100000000001' });
      const userData = system.slice(system.lastIndexOf('【使用者資料】\n'));
      const titles = [...userData.matchAll(/^([^\s\-【][^：\n]*)：/gm)].map((m) => m[1]);
      for (const title of titles) {
        assert.ok(Object.keys(SUPPORT_SECTIONS).some((k) => title.includes(k)), `客服使用者資料新增了未揭露的區塊「${title}」`);
      }
      for (const [key, item] of Object.entries(SUPPORT_SECTIONS)) {
        assert.ok(titles.some((t) => t.includes(key)), `客服使用者資料找不到「${key}」區塊`);
        assert.ok(DISCLOSURES.support.data.includes(item));
      }
      assert.match(userData, /審核原因：疑似非書籍/);
      assert.ok(DISCLOSURES.support.data.includes('審核原因'));
    }],

    ['爭議分析提示詞的每一個段落都已揭露', async () => {
      h.setSettings({ enabled: true });
      h.onModel('transaction_disputes.findUnique', () => ({
        dispute_id: 1, applicant_id: 1, reason: '書況不符', evidence_urls: '', created_at: new Date(),
        orders: {
          buyer_id: 1, seller_id: 2, status: 'refunding', created_at: new Date(), deposited_at: new Date(), picked_up_at: new Date(),
          order_items: [{ unit_price: 200, books: { title: '小王子', author: '聖修伯里', condition_level: 'good', description: '', book_images: [] } }]
        }
      }));
      h.queueJson({ summary: '摘要', findings: [], suggestion: 'dismiss', confidence: 0.5, rationale: '理由' });
      await h.api('services/ai/dispute-assist').analyze(1, 99);
      const { prompt } = h.calls[h.calls.length - 1].options;
      const DISPUTE_SECTIONS = { 上架資料: ['上架資料'], 訂單經過: ['訂單的狀態', '取書時間'], 爭議說明: ['爭議說明', '申請人', '申請時間'], 照片: ['佐證照片'] };
      const headings = [...prompt.matchAll(/^【([^】]+)】/gm)].map((m) => m[1]);
      assert.deepStrictEqual(headings.sort(), Object.keys(DISPUTE_SECTIONS).sort(), '爭議分析提示詞新增了未揭露的段落');
      assert.match(prompt, /【訂單經過】狀態：[^；]+；成立 [^；]+；存書 [^；]+；取書 /);
      assert.match(prompt, /【爭議說明】申請人：買家；時間 /);
      const line = bulletOf(privacyPolicy(), '交易爭議分析');
      for (const items of Object.values(DISPUTE_SECTIONS)) {
        for (const item of items) {
          assert.ok(DISCLOSURES.admin_assist.data.includes(item), item);
          assert.ok(line.includes(item), `交易爭議分析條目未提到${item}`);
        }
      }
    }],

    ['推薦提示詞的每一類使用者紀錄都已揭露', () => {
      const text = SOURCES.find((s) => s.file === path.join('services', 'ai', 'recommend.js')).text;
      const sections = [...new Set([...text.matchAll(/`【([^】]+)】\\n\$\{list\(/g)].map((m) => m[1]))];
      assert.deepStrictEqual(sections.sort(), [...DISCLOSURES.recommend.data].sort());
    }]
  ]
};
