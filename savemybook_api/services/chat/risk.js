const prisma = require('../../lib/prisma');
const { HttpError, conflict, notFound } = require('../../lib/errors');
const { placeholders } = require('../../lib/sql');
const { env } = require('../../config/env');
const { encode } = require('../../lib/public-id');
const { adminIdsWith } = require('../admin-permissions');
const { notifyMany } = require('../notify');

const WEIGHTS = { contact: 2, payment: 2, offsite: 2, link: 4, credential: 5, scam: 4 };
const CATEGORIES = Object.keys(WEIGHTS);
const CONFIRM_CATEGORIES = ['contact', 'payment', 'offsite'];

const HIGH_SCORE = 5;
const WINDOW_MS = 10 * 60 * 1000;
const WINDOW_MESSAGES = 5;
const NEW_ACCOUNT_MS = 7 * 24 * 60 * 60 * 1000;
const OUTREACH_MS = 60 * 60 * 1000;
const OUTREACH_ROOMS = 5;
const ALERT_MS = 24 * 60 * 60 * 1000;
const ALERT_HITS = 3;
const BANNER_MS = 30 * 24 * 60 * 60 * 1000;
const ALERT_STATUSES = ['open', 'dismissed', 'resolved'];

const APPS = 'line|ㄌㄞ|telegram|tg|wechat|微信|whatsapp|instagram|ig|facebook|fb|臉書|messenger|discord|kakao|skype';

// 英文 App 名稱要保留空白比對，去除空白後 linear algebra 會被當成 line。
const SPACED_RULES = {
  contact: [
    new RegExp(`(加|私|密|找|聯絡|聯繫|留|給|換|傳)(我|你|妳)?(的)?(${APPS})(?![a-z])`),
    new RegExp(`(?<![a-z])(${APPS}) ?(id|帳號|號碼|私訊|找我|聯絡|聯繫|加我|搜尋)`)
  ]
};

const RULES = {
  contact: [
    /(加|私|密)(我|你|妳)?(的)?賴|賴(id|帳號)/,
    /(小老鼠|\(at\)|\[at\])/,
    /(gmail|yahoo|hotmail|outlook|icloud)(com|\.com)/
  ],
  payment: [
    /(匯款|匯錢|轉帳|轉錢|打錢|付款|付錢|入帳|存款)(到|至|進|給)?(我)?(的)?(帳戶|帳號|戶頭|郵局|銀行)/,
    /(帳戶|帳號|戶頭|卡號)(是|為)?\d{8,}/,
    /(銀行代碼|代碼\d{3}|郵局局號|無卡存款|atm轉帳|街口支付|街口轉|linepay轉|全支付轉|悠遊付轉|先付(訂金|定金)|付(訂金|定金)|匯(訂金|定金)|預付(款|金))/
  ],
  offsite: [
    /(私下|場外|平台外|站外|app外|私底下)(交易|買賣|面交|匯款|轉帳|付款|聯絡)/,
    /(不走|不透過|不經過|不用透過|繞過|跳過|避開)(平台|app|系統|書櫃)/,
    /(省|避開|不想付|不用付)(平台)?(手續費|抽成|服務費)/,
    /(直接|改)(匯款|轉帳|面交)/,
    /面交/
  ],
  credential: [
    /(給|傳|提供|告訴|報|回傳|截圖|拍|念|唸|回覆)(我|一下)?(你|妳)?(的)?(手機)?(簡訊)?(驗證碼|認證碼|確認碼|otp|密碼|安全碼|cvv|提款卡密碼)/,
    /(驗證碼|認證碼|確認碼|otp|安全碼|cvv)(給我|傳給我|傳來|是多少|多少|截圖)/,
    /(信用卡|金融卡|提款卡)(號碼|卡號|背面|末三碼|有效期限|密碼)/
  ],
  scam: [
    /(解除|取消)(分期|重複扣款|自動扣款|錯誤設定)|誤設(為|成)?(分期|批發商|經銷商|高級會員|vip)|重複扣款/,
    /(帳戶|帳號|金流|款項)(被)?(凍結|異常|鎖定|卡住)/,
    /(金流|實名|誠信|賣家|收款|商家)(認證|驗證|簽署|開通)|簽署(金流|協議|同意書)/,
    /(點數卡|遊戲點數|mycard|gash|禮品卡|禮物卡|itunes卡|googleplay卡)/,
    /(超商|繳費|付款|取貨)代碼|(保證金|解凍金|手續費)(才能|才可以|先付)/,
    /(穩賺|保本|高報酬|高獲利|零風險)|帶(你|妳)(投資|操作|賺錢)|(虛擬貨幣|加密貨幣|usdt|泰達幣|比特幣|幣安)(投資|入金|出金|獲利)/,
    /(我是|這裡是|本人是)(平台|官方|銀行|超商|物流|711|全家|賣貨便|蝦皮)?(的)?(客服|專員|人員)/
  ]
};

const SHORTENER = /(bit\.ly|reurl\.cc|tinyurl\.com|lihi\d?\.(cc|com|me)|ppt\.cc|pse\.is|goo\.gl|is\.gd|cutt\.ly|rb\.gy|shorturl\.at|t\.co\/)/;
const IP_LINK = /(https?:\/\/)?\d{1,3}(\.\d{1,3}){3}(:\d+)?\//;
const RISKY_TLD = /[a-z0-9-]+\.(xyz|top|cc|vip|click|icu|buzz|rest|cfd|sbs|monster|live)(\/|\b)/;

const NUMERALS = { 零: 0, 〇: 0, '○': 0, 一: 1, 壹: 1, 二: 2, 貳: 2, 兩: 2, 三: 3, 參: 3, 四: 4, 肆: 4, 五: 5, 伍: 5, 六: 6, 陸: 6, 七: 7, 柒: 7, 八: 8, 捌: 8, 九: 9, 玖: 9 };

const normalize = (text) => String(text ?? '').normalize('NFKC').toLowerCase();

const PUNCTUATION = /[\u200b-\u200d\ufeff._\-~*|·•、,，。:：;；'"「」『』()（）[\]【】<>《》/\\!！?？#＃]/g;

// 拆字、插入空白或標點是最常見的規避手法，比對前先全部去除。
const compact = (text) => normalize(text).replace(PUNCTUATION, '').replace(/\s/g, '');

const spaced = (text) => normalize(text).replace(PUNCTUATION, ' ').replace(/\s+/g, ' ')
  .replace(/ ?([\u2e80-\u9fff\uff00-\uffef]) ?/g, '$1');

const digitsOf = (text) => compact(text).replace(/[零〇○一壹二貳兩三參四肆五伍六陸七柒八捌九玖]/g, (ch) => String(NUMERALS[ch]));

const ownHost = () => {
  try {
    return env.publicWebUrl ? new URL(env.publicWebUrl).hostname.toLowerCase() : null;
  } catch {
    return null;
  }
};

const suspiciousLink = (plain) => {
  if (SHORTENER.test(plain) || IP_LINK.test(plain) || /xn--/.test(plain)) return true;
  const host = ownHost();
  if (host) {
    const hosts = [...plain.matchAll(/(?:https?:\/\/)?((?:[a-z0-9-]+\.)+[a-z]{2,})/g)].map((m) => m[1]);
    if (hosts.some((h) => h.includes('savemybook') && h !== host && !h.endsWith(`.${host}`))) return true;
  }
  return RISKY_TLD.test(plain);
};

const detect = (text) => {
  if (!text) return new Set();
  const plain = normalize(text);
  const squeezed = compact(text);
  const loose = spaced(text);
  const found = new Set();
  for (const [category, patterns] of Object.entries(RULES)) {
    if (patterns.some((re) => re.test(squeezed))) found.add(category);
  }
  for (const [category, patterns] of Object.entries(SPACED_RULES)) {
    if (patterns.some((re) => re.test(loose))) found.add(category);
  }
  const digits = digitsOf(text);
  if (/(^|\D)(09\d{8}|\+?8869\d{8})(\D|$)/.test(digits)) found.add('contact');
  if (/(^|[^a-z])l\s*i\s*n\s*e\s*(id)?\s*[:：]\s*[a-z0-9_.-]{3,}/.test(plain)) found.add('contact');
  if (/[a-z0-9._%+-]+@[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z]{2,}/.test(plain)) found.add('contact');
  if (suspiciousLink(plain)) found.add('link');
  return found;
};

const ordered = (set) => CATEGORIES.filter((c) => set.has(c));

const scoreOf = (categories) => categories.reduce((sum, c) => sum + WEIGHTS[c], 0);

const levelOf = (score) => (score >= HIGH_SCORE ? 'high' : score > 0 ? 'notice' : null);

const contentRisk = (text) => {
  const categories = ordered(detect(text));
  if (categories.length === 0) return null;
  const score = scoreOf(categories);
  return { level: levelOf(score), categories, score };
};

// 只算本則訊息「新補上」的類別：把前幾則拆開傳的內容接起來比對，但已在前幾則出現過的類別不重算。
const windowCategories = async (roomId, senderId, text) => {
  const recent = await prisma.chat_messages.findMany({
    where: { room_id: roomId, sender_id: senderId, message_type: 'text', created_at: { gte: new Date(Date.now() - WINDOW_MS) } },
    orderBy: { message_id: 'desc' },
    take: WINDOW_MESSAGES,
    select: { content: true }
  });
  const before = recent.reverse().map((m) => m.content).join(' ');
  const earlier = detect(before);
  const found = detect(text);
  for (const c of detect(`${before} ${text}`)) if (!earlier.has(c)) found.add(c);
  return ordered(found);
};

const accountFactors = async (senderId) => {
  const since = new Date(Date.now() - OUTREACH_MS);
  const [user, completed, rooms] = await Promise.all([
    prisma.users.findUnique({ where: { user_id: senderId }, select: { created_at: true } }),
    prisma.orders.count({ where: { status: 'completed', OR: [{ buyer_id: senderId }, { seller_id: senderId }] } }),
    prisma.chat_messages.groupBy({ by: ['room_id'], where: { sender_id: senderId, created_at: { gte: since } } })
  ]);
  let score = 0;
  if (user?.created_at && Date.now() - new Date(user.created_at).getTime() < NEW_ACCOUNT_MS) score += 1;
  if (completed === 0) score += 1;
  if (rooms.length >= OUTREACH_ROOMS) score += 2;
  return score;
};

const assess = async ({ roomId, senderId, text }) => {
  const categories = await windowCategories(roomId, senderId, text);
  if (categories.length === 0) return null;
  const score = scoreOf(categories) + (await accountFactors(senderId));
  return { level: levelOf(score), categories, score };
};

const confirmRequired = (categories) => {
  const hits = categories.filter((c) => CONFIRM_CATEGORIES.includes(c));
  if (hits.length === 0) return null;
  return new HttpError(409, '訊息包含聯絡方式或付款資訊，於平台外交易將不受平台保障，請確認後再傳送', 'RISK_CONFIRM_REQUIRED', { categories: hits });
};

const notifyAdmins = async (userId, nickname) => {
  const adminIds = (await adminIdsWith('reports')).filter((id) => id !== userId);
  if (adminIds.length === 0) return;
  await notifyMany(prisma, adminIds, {
    title: '聊天防詐警示',
    content: `會員「${nickname ?? encode('user', userId)}」於 24 小時內多次傳送高風險訊息，請至內容審核查看。`,
    relatedId: userId,
    relatedType: 'risk_alert'
  });
};

const raiseAlert = async (senderId) => {
  const since = new Date(Date.now() - ALERT_MS);
  const [row] = await prisma.$queryRaw`
    SELECT COUNT(*) AS n FROM chat_message_risks WHERE sender_id = ${senderId} AND level = 'high' AND created_at > ${since}`;
  const hits = Number(row?.n ?? 0);
  if (hits < ALERT_HITS) return;

  const now = new Date();
  const [open] = await prisma.$queryRaw`
    SELECT alert_id, hit_count FROM chat_risk_alerts WHERE user_id = ${senderId} AND status = 'open'`;
  if (open) {
    await prisma.$executeRaw`
      UPDATE chat_risk_alerts SET hit_count = ${Number(open.hit_count) + 1}, last_at = ${now} WHERE alert_id = ${open.alert_id}`;
    return;
  }
  await prisma.$executeRaw`
    INSERT INTO chat_risk_alerts (user_id, status, hit_count, first_at, last_at) VALUES (${senderId}, 'open', ${hits}, ${now}, ${now})`;
  const user = await prisma.users.findUnique({ where: { user_id: senderId }, select: { nickname: true } });
  await notifyAdmins(senderId, user?.nickname);
};

const record = async ({ messageId, roomId, senderId, risk, replace = false }) => {
  if (!risk && !replace) return;
  if (replace) await prisma.$executeRaw`DELETE FROM chat_message_risks WHERE message_id = ${messageId}`;
  if (!risk) return;
  await prisma.$executeRaw`
    INSERT INTO chat_message_risks (message_id, room_id, sender_id, level, categories, score, created_at)
    VALUES (${messageId}, ${roomId}, ${senderId}, ${risk.level}, ${risk.categories.join(',')}, ${Math.min(risk.score, 255)}, ${new Date()})`;
  if (risk.level === 'high') await raiseAlert(senderId);
};

const parseCategories = (value) => String(value ?? '').split(',').filter((c) => CATEGORIES.includes(c));

// 對方傳的文字訊息才附上提醒；有紀錄者以傳送當下的評分為準（含帳號因素），其餘依內容即時判斷。
const forMessages = async (messages, myId) => {
  const others = messages.filter((m) => m.sender_id !== myId && m.message_type === 'text');
  const result = new Map();
  if (others.length === 0) return result;

  const ids = others.map((m) => m.message_id);
  const rows = await prisma.$queryRawUnsafe(
    `SELECT message_id, level, categories FROM chat_message_risks WHERE message_id IN (${placeholders(ids)})`,
    ...ids
  );
  const stored = new Map(rows.map((r) => [Number(r.message_id), { level: r.level, categories: parseCategories(r.categories) }]));
  for (const m of others) {
    const risk = stored.get(m.message_id) ?? contentRisk(m.content);
    if (risk) result.set(m.message_id, { level: risk.level, categories: risk.categories });
  }
  return result;
};

const bannerFor = async (roomId, myId, loaded) => {
  const categories = new Set();
  const since = new Date(Date.now() - BANNER_MS);
  const rows = await prisma.$queryRaw`
    SELECT categories FROM chat_message_risks
    WHERE room_id = ${roomId} AND level = 'high' AND sender_id <> ${myId} AND created_at > ${since}`;
  for (const r of rows) parseCategories(r.categories).forEach((c) => categories.add(c));
  for (const risk of loaded.values()) {
    if (risk.level === 'high') risk.categories.forEach((c) => categories.add(c));
  }
  return categories.size > 0 ? { level: 'high', categories: ordered(categories) } : null;
};

const shapeAlert = (row, users, samples) => {
  const user = users.get(Number(row.user_id));
  return {
    alert_id: Number(row.alert_id),
    status: row.status,
    hit_count: Number(row.hit_count),
    first_at: row.first_at,
    last_at: row.last_at,
    handled_at: row.handled_at ?? null,
    user: user
      ? { user_id: user.user_id, user_no: encode('user', user.user_id), nickname: user.nickname, avatar_url: user.avatar_url,
          is_active: user.is_active, is_blacklisted: user.is_blacklisted, created_at: user.created_at }
      : null,
    samples: samples.get(Number(row.user_id)) ?? []
  };
};

const SAMPLE_LIMIT = 5;

const adminList = async (status) => {
  const rows = status
    ? await prisma.$queryRaw`
        SELECT alert_id, user_id, status, hit_count, first_at, last_at, handled_at FROM chat_risk_alerts
        WHERE status = ${status} ORDER BY last_at DESC LIMIT 200`
    : await prisma.$queryRaw`
        SELECT alert_id, user_id, status, hit_count, first_at, last_at, handled_at FROM chat_risk_alerts
        ORDER BY last_at DESC LIMIT 200`;
  if (rows.length === 0) return [];

  const userIds = [...new Set(rows.map((r) => Number(r.user_id)))];
  const [users, risks] = await Promise.all([
    prisma.users.findMany({
      where: { user_id: { in: userIds } },
      select: { user_id: true, nickname: true, avatar_url: true, is_active: true, is_blacklisted: true, created_at: true }
    }),
    prisma.$queryRawUnsafe(
      `SELECT message_id, sender_id, categories, created_at FROM chat_message_risks
       WHERE level = 'high' AND sender_id IN (${placeholders(userIds)}) ORDER BY created_at DESC LIMIT 500`,
      ...userIds
    )
  ]);

  const picked = new Map();
  for (const r of risks) {
    const list = picked.get(Number(r.sender_id)) ?? [];
    if (list.length < SAMPLE_LIMIT) list.push(r);
    picked.set(Number(r.sender_id), list);
  }
  const messageIds = [...picked.values()].flat().map((r) => Number(r.message_id));
  const contents = messageIds.length
    ? await prisma.chat_messages.findMany({ where: { message_id: { in: messageIds } }, select: { message_id: true, content: true, message_type: true } })
    : [];
  const contentOf = new Map(contents.filter((m) => m.message_type === 'text').map((m) => [m.message_id, m.content]));

  const samples = new Map([...picked].map(([userId, list]) => [userId, list
    .filter((r) => contentOf.has(Number(r.message_id)))
    .map((r) => ({ content: contentOf.get(Number(r.message_id)), categories: parseCategories(r.categories), created_at: r.created_at }))]));

  const userMap = new Map(users.map((u) => [u.user_id, u]));
  return rows.map((r) => shapeAlert(r, userMap, samples));
};

const ACTIONS = { dismiss: 'dismissed', resolve: 'resolved' };

const handle = async (alertId, action, adminId) => {
  const [row] = await prisma.$queryRaw`SELECT alert_id, status FROM chat_risk_alerts WHERE alert_id = ${alertId}`;
  if (!row) throw notFound('找不到此警示');
  if (row.status !== 'open') throw conflict('此警示已處理', 'ALERT_HANDLED');
  await prisma.$executeRaw`
    UPDATE chat_risk_alerts SET status = ${ACTIONS[action]}, handled_by = ${adminId}, handled_at = ${new Date()} WHERE alert_id = ${alertId}`;
  return { alert_id: alertId, status: ACTIONS[action] };
};

const openCount = async () => {
  const [row] = await prisma.$queryRaw`SELECT COUNT(*) AS n FROM chat_risk_alerts WHERE status = 'open'`;
  return Number(row?.n ?? 0);
};

module.exports = {
  CATEGORIES, CONFIRM_CATEGORIES, ALERT_STATUSES, ACTIONS, WEIGHTS,
  detect, contentRisk, assess, confirmRequired, record, forMessages, bannerFor, adminList, handle, openCount
};
