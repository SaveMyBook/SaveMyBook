const { clip } = require('../../lib/text');
const { detect, isOfficialHost } = require('../chat/risk');

const isUnsafeChar = (code) => (code < 32 && code !== 9 && code !== 10 && code !== 13) || code === 127
  || (code >= 0x200b && code <= 0x200f) || (code >= 0x202a && code <= 0x202e) || (code >= 0x2060 && code <= 0x2069)
  || code === 0xfeff || code === 0x00ad || code === 0x180e;

const stripControls = (s) => Array.from(s).filter((ch) => !isUnsafeChar(ch.codePointAt(0))).join('');

// 模型輸出一律視為不可信任：移除控制字元與 HTML 標籤後再截斷。
const sanitizeText = (value, max) => {
  if (typeof value !== 'string' && typeof value !== 'number') return '';
  const s = stripControls(String(value))
    .replace(/<\/?[a-zA-Z][^>]*>/g, '')
    .replace(/\r\n?/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
  return max ? clip(s, max) : s;
};

const sanitizeLine = (value, max) => {
  const s = sanitizeText(value).replace(/\s+/g, ' ').trim();
  return max ? clip(s, max) : s;
};

// 他人或外部來源撰寫的片段放進提示詞前一律經過這裡：換行與這些符號能偽造候選行、段落標題或 <商品資料> 標籤。
const PROMPT_MARKS = { '|': ' ', '｜': ' ', '【': '〔', '】': '〕', '《': '〈', '》': '〉', '<': '＜', '>': '＞' };
const PROMPT_MARK_RE = /[|｜【】《》<>]/g;

const promptText = (value, max) => {
  if (typeof value !== 'string' && typeof value !== 'number') return '';
  const s = stripControls(String(value))
    .replace(/[\r\n\t\u0085\u2028\u2029]+/g, ' ')
    .replace(PROMPT_MARK_RE, (ch) => PROMPT_MARKS[ch])
    .replace(/\s+/g, ' ')
    .trim();
  return max ? clip(s, max) : s;
};

// 書目來源會被模型照抄進公開簡介，書名號《》須保留；段落標題用【】，替換後換行也偽造不出段落。
const SOURCE_MARK_RE = /[|｜【】<>]/g;

const sourceText = (value, max, { multiline = true } = {}) => {
  if (typeof value !== 'string' && typeof value !== 'number') return '';
  const base = stripControls(String(value)).replace(SOURCE_MARK_RE, (ch) => PROMPT_MARKS[ch]);
  const s = multiline
    ? base.replace(/\r\n?|[\u0085\u2028\u2029]/g, '\n').replace(/[^\S\n]+/g, ' ').replace(/ ?\n ?/g, '\n').replace(/\n{3,}/g, '\n\n').trim()
    : base.replace(/\s+/g, ' ').trim();
  return max ? clip(s, max) : s;
};

const OUTPUT_RISKS = ['contact', 'link'];
const WEB_URL = /(?:https?:\/\/|www\.)\S+/i;
const BARE_DOMAIN = /(?<![@\w.\/-])((?:[a-z0-9-]+\.)+(?:com|net|org|tw|cc|me|io|app|shop)(?:\.[a-z]{2})?)(?![\w-]|\.[a-z0-9])(\/[\x21-\x7e]*)?/g;
const PRODUCT_NAMES = new Set(['asp.net', 'ado.net', 'vb.net', 'socket.io']);

// strong 只認帶路徑或 .com.tw 這類複合網域的寫法，Outlook.com、ASP.NET 等書名常見字詞不算。
const hasBareDomain = (text, { strong = false } = {}) => [...text.toLowerCase().matchAll(BARE_DOMAIN)].some(([, host, path]) => {
  if (PRODUCT_NAMES.has(host)) return false;
  return !strong || (path ?? '').length > 1 || /\.(?:com|net|org)\.[a-z]{2}$/.test(host);
});

const URL_TOKEN = /(?:https?:\/\/|www\.)[\x21-\x7e]+/gi;
const HOST_TOKEN = /(?<![\w.@\/:%+-])(?:[a-z0-9-]+\.)+[a-z]{2,}(?:[\/?#][\x21-\x7e]*)?/gi;
const EMAIL_TOKEN = /(?<![\w.%+\/:@-])[a-z0-9._%+-]+@((?:[a-z0-9-]+\.)+[a-z]{2,})\b/gi;

const decoded = (s) => {
  try {
    return decodeURIComponent(s);
  } catch {
    return s;
  }
};

// 以 URL 解析後比對主機；含帳密（@）、路徑或參數中另有網址的，一律視為站外連結。
const isOfficialUrl = (token) => {
  let url;
  try {
    url = new URL(/^https?:\/\//i.test(token) ? token : `https://${token}`);
  } catch {
    return false;
  }
  if (url.username || url.password || !isOfficialHost(url.hostname)) return false;
  const rest = decoded(`${url.pathname}${url.search}${url.hash}`).toLowerCase();
  if (/[a-z][a-z0-9+.-]*:\/\/|\/\/|www\.|@/.test(rest)) return false;
  if (/[?&=#](?:[a-z0-9-]+\.)+[a-z]{2,}/.test(rest)) return false;
  return detect(rest).size === 0;
};

const CONTACT_VERB = '(?:加|私訊?|密|找|聯絡|聯繫|留|給|換|傳)(?:我|你|妳)?(?:的)?\\s*';
const ACCOUNT_NEXT = '\\s*(?:[:：]\\s*)?@?[a-z0-9][a-z0-9_.-]{2,}';
const ACCOUNT_NEAR = '[^。！？!?；;\\n]{0,12}?(?:[:：]\\s*@?[a-z0-9][a-z0-9_.-]{2,}|@\\s*[a-z0-9][a-z0-9_.-]{2,}|(?<![a-z0-9])(?=[a-z_.-]*\\d)[a-z0-9_.-]{3,})';
// 「LINE 帳號」「Discord 帳號」是本站的登入方式；前面沒有「加我」等聯絡用語、後面也沒有帳號字串時才視為登入說明。
const LOGIN_ACCOUNT = new RegExp(`(?<!${CONTACT_VERB})(?:line|discord)\\s*帳號(?!${ACCOUNT_NEXT})(?!${ACCOUNT_NEAR})`, 'gi');

const withoutSiteRefs = (text) => text
  .replace(URL_TOKEN, (m) => (isOfficialUrl(m) ? ' ' : m))
  .replace(EMAIL_TOKEN, (m, host) => (isOfficialHost(host) ? ' ' : m))
  .replace(HOST_TOKEN, (m) => (isOfficialUrl(m) ? ' ' : m))
  .replace(LOGIN_ACCOUNT, ' 登入帳號 ');

// allowSiteRefs 會放行本站網址與登入方式說明，只能用於客服回覆：套用在賣家或爭議申請人撰寫的文字上等於開了繞過的後門。
const risksIn = (value, { categories = OUTPUT_RISKS, allowSiteRefs = false, identifiersOnly = false, bareDomains = 'all' } = {}) => {
  const normalized = String(value ?? '').normalize('NFKC');
  const text = allowSiteRefs ? withoutSiteRefs(normalized) : normalized;
  if (!text.trim()) return [];
  const found = new Set([...detect(text, { identifiersOnly })].filter((c) => categories.includes(c)));
  if (categories.includes('link')) {
    if (WEB_URL.test(text) || (bareDomains && hasBareDomain(text, { strong: bareDomains === 'strong' }))) found.add('link');
  }
  return categories.filter((c) => found.has(c));
};

const SENTENCE_END = /[。！？!?；;\n]/;
const URL_SPAN = /(?:https?:\/\/|www\.)[\x21-\x7e]+|(?<![\w.-])(?:[a-z0-9-]+\.)+[a-z]{2,}\/[\x21-\x7e]*/gi;

// 網址內的 ? ! ; 不斷句，否則網址後半段（例如查詢參數）會被當成另一句留下來。
const sentencesOf = (text) => {
  const spans = [...text.matchAll(URL_SPAN)].map((m) => [m.index, m.index + m[0].length]);
  const out = [];
  let start = 0;
  for (let i = 0; i < text.length; i += 1) {
    if (!SENTENCE_END.test(text[i]) || spans.some(([a, b]) => i >= a && i < b)) continue;
    out.push(text.slice(start, i + 1));
    start = i + 1;
  }
  if (start < text.length) out.push(text.slice(start));
  return out;
};

// 以句為單位遮蔽命中的內容；拆在不同句子裡才湊得出來的聯絡資訊無法定位，整段捨棄。
const maskRisks = (value, { mask = '', feature = null, ...options } = {}) => {
  const text = String(value ?? '');
  const hits = risksIn(text, options);
  if (hits.length === 0) return text;
  if (feature) console.warn(`[AI 輸出防護：${feature}] ${hits.join(',')}`);
  const kept = [];
  for (const part of sentencesOf(text)) {
    if (risksIn(part, options).length === 0) kept.push(part);
    else if (mask && kept[kept.length - 1] !== mask) kept.push(mask);
  }
  const out = kept.join('').replace(/[ \t]+\n/g, '\n').replace(/\n{3,}/g, '\n\n').trim();
  return risksIn(out, options).length === 0 ? out : '';
};

const stringList = (value, { max = 5, maxLength = 80 } = {}) => {
  if (!Array.isArray(value)) return [];
  const out = [];
  for (const item of value) {
    const s = sanitizeLine(item, maxLength);
    if (s && !out.includes(s)) out.push(s);
    if (out.length >= max) break;
  }
  return out;
};

const clamp01 = (value) => {
  const n = Number(value);
  if (!Number.isFinite(n)) return 0;
  return Math.round(Math.min(1, Math.max(0, n)) * 100) / 100;
};

const safeUrl = (value) => {
  if (typeof value !== 'string' || value.length > 500) return null;
  try {
    const url = new URL(value.trim());
    return ['http:', 'https:'].includes(url.protocol) ? url.toString() : null;
  } catch {
    return null;
  }
};

module.exports = { OUTPUT_RISKS, sanitizeText, sanitizeLine, promptText, sourceText, risksIn, maskRisks, stringList, clamp01, safeUrl };
