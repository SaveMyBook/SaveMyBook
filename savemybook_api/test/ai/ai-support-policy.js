const assert = require('assert');
const fs = require('fs');
const path = require('path');
const h = require('./harness');

const knowledge = h.api('services/ai/knowledge');
const support = h.api('services/ai/support');
const policy = h.api('constants/policy');
const { ORDER_STATUS_LABELS, ORDER_STATUS_ALIASES } = h.api('constants/domain');
const { prisma } = h;

// 各主題必須提到的政策數字；新增政策常數時也要指定由哪個主題說明。
const REQUIRED = {
  listing: ['LISTING_MAX_PRICE', 'LISTING_MAX_IMAGES'],
  review: ['LISTING_REVIEW_PRICE'],
  'order-flow': ['ORDER_AUTO_COMPLETE_HOURS'],
  cabinet: ['ORDER_DEPOSIT_DAYS', 'DEPOSIT_PAUSE_DAYS', 'DEPOSIT_REMIND_DAYS', 'DEPOSIT_ESCALATE_DAYS'],
  pickup: ['ORDER_DEPOSIT_DAYS', 'ORDER_PICKUP_DAYS', 'ORDER_AUTO_COMPLETE_HOURS'],
  reservation: ['RESERVATION_HOLD_HOURS', 'RESERVATION_RESPONSE_HOURS', 'RESERVATION_MAX_ACTIVE'],
  cancel: ['ORDER_CANCELLABLE_STATUSES', 'ORDER_DEPOSIT_DAYS', 'ORDER_PICKUP_DAYS'],
  dispute: ['DISPUTE_WINDOW_HOURS'],
  'chat-transfer': ['CHAT_TRANSFER_MAX_AMOUNT', 'CHAT_REQUEST_TTL_HOURS'],
  account: ['ACCOUNT_DELETION_GRACE_DAYS'],
  level: ['LEVEL_POINTS_PER_ORDER']
};

const topic = (id) => {
  const found = knowledge.PLATFORM_TOPICS.find((t) => t.id === id);
  assert.ok(found, `缺少主題 ${id}`);
  return found;
};

const unitOf = (key) => {
  if (key.endsWith('_DAYS')) return ' 天';
  if (key.endsWith('_HOURS')) return ' 小時';
  return '';
};

// 狀態清單以顯示名稱說明，其餘以「數字＋單位」說明。
const phrasesOf = (key) => {
  const value = policy[key];
  if (key.endsWith('_STATUSES')) return value.map((s) => ORDER_STATUS_LABELS[s]);
  if (Array.isArray(value)) return [`${value.join('、')}${unitOf(key)}`];
  return [`${value}${unitOf(key)}`];
};

const numbersIn = (text) => (text.match(/\d+/g) ?? []).map(Number);

const termsOfService = () => {
  const seed = fs.readFileSync(path.join(h.API_ROOT, 'prisma/seed.sql'), 'utf8');
  const match = seed.match(/\('terms',\s*'服務條款',\s*'((?:[^']|'')*)'/);
  assert.ok(match, 'seed.sql 找不到服務條款');
  return match[1].replace(/''/g, "'");
};

const setup = ({ legal = [] } = {}) => {
  knowledge.invalidate();
  prisma.store.faqs = [];
  prisma.store.legal_documents = legal;
  h.setSettings({ enabled: true });
};

module.exports = {
  name: 'AI 客服知識庫與政策常數一致性',
  tests: [
    ['每個政策常數都有主題說明，且主題文字含有對應數值', () => {
      const covered = new Set(Object.values(REQUIRED).flat());
      assert.deepStrictEqual(Object.keys(policy).filter((k) => !covered.has(k)), []);
      for (const [id, keys] of Object.entries(REQUIRED)) {
        const { text } = topic(id);
        for (const key of keys) {
          for (const phrase of phrasesOf(key)) assert.ok(text.includes(phrase), `${id} 未提到 ${key}（${phrase}）`);
        }
      }
    }],

    ['主題文字中的數字都來自政策常數', () => {
      const allowed = new Set([0, 1, ...Object.values(policy).flat().filter((v) => typeof v === 'number')]);
      for (const t of knowledge.PLATFORM_TOPICS) {
        const stray = numbersIn(t.text).filter((n) => !allowed.has(n));
        assert.deepStrictEqual(stray, [], `${t.id} 含有未定義於 constants/policy.js 的數字`);
      }
    }],

    ['服務使用的期限與上限等於政策常數', () => {
      const orders = h.api('services/orders');
      assert.strictEqual(orders.CONFIRM_WINDOW_HOURS, policy.ORDER_AUTO_COMPLETE_HOURS);
      assert.strictEqual(orders.DEPOSIT_DAYS, policy.ORDER_DEPOSIT_DAYS);
      assert.strictEqual(orders.PICKUP_DAYS, policy.ORDER_PICKUP_DAYS);
      assert.strictEqual(h.api('services/disputes').DISPUTE_WINDOW_MS, policy.DISPUTE_WINDOW_HOURS * 60 * 60 * 1000);
      const deposits = h.api('services/book-deposits');
      assert.deepStrictEqual(
        [deposits.PAUSE_DAYS, deposits.REMIND_DAYS, deposits.ESCALATE_DAYS],
        [policy.DEPOSIT_PAUSE_DAYS, policy.DEPOSIT_REMIND_DAYS, policy.DEPOSIT_ESCALATE_DAYS]
      );
      assert.strictEqual(h.api('services/listing-screening').PRICE_CEILING, policy.LISTING_REVIEW_PRICE);
      assert.strictEqual(h.api('services/chat/transfers').MAX_AMOUNT, policy.CHAT_TRANSFER_MAX_AMOUNT);
      assert.strictEqual(h.api('services/account').GRACE_DAYS, policy.ACCOUNT_DELETION_GRACE_DAYS);
    }],

    ['服務條款範本的期限與政策常數一致', () => {
      const terms = termsOfService();
      const expected = [
        new RegExp(`訂單成立後\\s*${policy.ORDER_DEPOSIT_DAYS}\\s*日內`),
        new RegExp(`「已存書」時起\\s*${policy.ORDER_PICKUP_DAYS}\\s*日內`),
        new RegExp(`滿\\s*${policy.DEPOSIT_PAUSE_DAYS}\\s*日仍未售出`),
        new RegExp(`滿\\s*${policy.DEPOSIT_ESCALATE_DAYS}\\s*日仍未取回`),
        new RegExp(`取書滿\\s*${policy.ORDER_AUTO_COMPLETE_HOURS}\\s*小時`),
        new RegExp(`取件後\\s*${policy.DISPUTE_WINDOW_HOURS}\\s*小時內、訂單完成前`)
      ];
      for (const pattern of expected) assert.match(terms, pattern);
    }],

    ['服務條款範本：只有訂單內書籍全部預先存放於訂單指定的書櫃時，訂單成立即視為已存書', () => {
      const terms = termsOfService();
      assert.ok(terms.includes(
        '訂單內書籍均已預先存放於訂單指定之智慧書櫃者，訂單成立時即視為已存書，買賣雙方均不得自行取消；僅部分書籍已預先存放者，依一般存書流程辦理。'
      ));
      assert.doesNotMatch(terms, /書籍已預先存書者，訂單成立時即為/);
      assert.doesNotMatch(terms, /含已預先存書之訂單/);
    }],

    ['取消、爭議與撥款的說明符合現行規則', () => {
      const cancel = topic('cancel').text;
      assert.doesNotMatch(cancel, /完成前(都)?可取消/);
      assert.match(cancel, /賣家存書後雙方皆無法自行取消/);
      assert.match(cancel, /書籍皆已預先存入訂單指定的書櫃時，訂單成立即為已存書，因此也無法取消/);

      const dispute = topic('dispute').text;
      assert.match(dispute, /訂單狀態變成已完成後不再受理爭議/);
      assert.match(dispute, /按下「完成訂單」即視為放棄爭議權利/);
      assert.match(dispute, new RegExp(`取書後須在 ${policy.DISPUTE_WINDOW_HOURS} 小時內、且訂單完成前提出`));

      const flow = topic('order-flow').text;
      assert.match(flow, /訂單完成時款項才撥入賣家錢包/);
      assert.match(flow, new RegExp(`取書滿 ${policy.ORDER_AUTO_COMPLETE_HOURS} 小時且未提出爭議時，訂單自動完成`));
      assert.match(flow, new RegExp(`${ORDER_STATUS_LABELS.refunding}（買家的訂單分頁顯示「申訴中」）`));

      assert.doesNotMatch(support.PLATFORM_KNOWLEDGE, /取書後款項才撥給賣家/);
      assert.match(support.PLATFORM_KNOWLEDGE, /訂單完成時款項才撥給賣家/);
      assert.match(support.PLATFORM_KNOWLEDGE, new RegExp(`取書滿 ${policy.ORDER_AUTO_COMPLETE_HOURS} 小時`));
    }],

    // checkout.placeOrders 只有在每本書都已預先存入訂單指定的書櫃時才直接成立為已存書。
    ['預先存書只在訂單內書籍皆已存入指定書櫃時才成立即為已存書，部分預先存書仍可取消', () => {
      const ALL_STORED = /書籍皆已預先存入訂單指定的書櫃時/;
      const PARTIAL = /僅部分書籍預先存書或有書籍存放於其他書櫃/;
      for (const id of ['order-flow', 'cabinet', 'pickup', 'cancel']) {
        const { text } = topic(id);
        assert.doesNotMatch(text, /賣家已預先(把書)?存書的訂單|已先存書的書，買家下單後/, `${id} 未附條件`);
        assert.match(text, ALL_STORED, `${id} 未說明全部預先存書的條件`);
      }
      for (const id of ['order-flow', 'cabinet', 'cancel']) assert.match(topic(id).text, PARTIAL, `${id} 未說明部分預先存書`);
      assert.match(topic('order-flow').text, /訂單仍為待存書/);
      assert.match(topic('cancel').text, /賣家完成存書前雙方仍可取消/);
    }],

    ['上架與書櫃段落不承諾做不到的事', () => {
      const listing = topic('listing').text;
      assert.doesNotMatch(listing, /隨時編輯或下架/);
      assert.match(listing, /預約保留期間或已有訂單的書籍無法編輯或下架/);
      assert.match(listing, /存書期間無法變更書櫃/);
      assert.match(listing, /須先取回並在 App 中回報才能重新上架/);

      const cabinet = topic('cabinet').text;
      assert.doesNotMatch(cabinet, /由客服人員取出並下架/);
      assert.match(cabinet, new RegExp(`滿 ${policy.DEPOSIT_ESCALATE_DAYS} 天仍未取回者，平台得派員取出並下架`));
    }],

    ['爭議分析的提示詞使用政策常數的申訴期限', () => {
      const { SYSTEM } = h.api('services/ai/dispute-assist');
      assert.ok(SYSTEM.includes(`取書後 ${policy.DISPUTE_WINDOW_HOURS} 小時內`));
      const periods = [...SYSTEM.matchAll(/(\d+)\s*(?:小時|天|日)/g)].map((m) => Number(m[1]));
      assert.deepStrictEqual(periods, [policy.DISPUTE_WINDOW_HOURS]);
    }],

    ['訂單流程與爭議主題的關鍵字含所有訂單狀態顯示名稱', () => {
      const names = [...Object.values(ORDER_STATUS_LABELS), ...Object.values(ORDER_STATUS_ALIASES).flat()];
      for (const id of ['order-flow', 'dispute']) {
        const keywords = topic(id).keywords.split(/\s+/);
        for (const name of names) assert.ok(keywords.includes(name), `${id} 缺少關鍵字「${name}」`);
      }
    }],

    ['檢索：訂單顯示審核中時，排第一的是訂單流程', async () => {
      for (const legal of [[], [{ doc_id: 1, title: '服務條款', content: termsOfService() }]]) {
        setup({ legal });
        const [top] = await knowledge.search('我的訂單顯示審核中是什麼意思');
        assert.strictEqual(top.id, 'platform:order-flow');
      }
    }],

    ['檢索：詢問取書期限時找到期限段落', async () => {
      for (const legal of [[], [{ doc_id: 1, title: '服務條款', content: termsOfService() }]]) {
        setup({ legal });
        const [top] = await knowledge.search('取書期限是幾天');
        assert.strictEqual(top.id, 'platform:pickup');
        assert.ok(top.text.includes(`${policy.ORDER_PICKUP_DAYS} 天內到書櫃取書`));
      }
    }],

    ['檢索：已完成訂單能否申訴，排第一的是交易爭議', async () => {
      setup();
      const [top] = await knowledge.search('已完成的訂單還可以申訴嗎');
      assert.strictEqual(top.id, 'platform:dispute');
    }]
  ]
};
