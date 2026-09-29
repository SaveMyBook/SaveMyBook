const { toSimplified } = require('./hanzi');

const DICE_MIN = 0.5;
const SUBTITLE_SPLIT = /\s*(?:[:|｜]|——|--|\s[-–—]\s)\s*/;
const BRACKETED = /[(【〔[][^)】〕\]]*[)】〕\]]/g;
const ROMAN = /[Ⅰ-Ⅻ]/g;

const prep = (value) => String(value ?? '').replace(ROMAN, (ch) => String(ch.charCodeAt(0) - 0x215f)).normalize('NFKC');

const keyOf = (value) => toSimplified(prep(value).toLowerCase()).replace(/[\s\p{P}\p{S}]/gu, '');

const partsOf = (title, subtitle = '') => {
  const [main, ...rest] = prep(title).replace(BRACKETED, ' ').split(SUBTITLE_SPLIT);
  const whole = `${main}${rest.join('')}`;
  return {
    main: keyOf(main),
    sub: keyOf([...rest, subtitle].join(' ')),
    full: [keyOf(whole), subtitle ? keyOf(`${whole}${subtitle}`) : ''].filter(Boolean)
  };
};

const bigrams = (key) => {
  const chars = Array.from(key);
  return new Set(chars.length < 2 ? chars : chars.slice(1).map((ch, i) => `${chars[i]}${ch}`));
};

const dice = (a, b) => {
  const [x, y] = [bigrams(a), bigrams(b)];
  const shared = [...x].filter((gram) => y.has(gram)).length;
  return (2 * shared) / (x.size + y.size);
};

const editDistance = (a, b) => {
  const [x, y] = [Array.from(a), Array.from(b)];
  let prev = Array.from({ length: y.length + 1 }, (_, j) => j);
  for (let i = 1; i <= x.length; i += 1) {
    const row = [i];
    for (let j = 1; j <= y.length; j += 1) {
      row[j] = Math.min(prev[j] + 1, row[j - 1] + 1, prev[j - 1] + (x[i - 1] === y[j - 1] ? 0 : 1));
    }
    prev = row;
  }
  return prev[y.length];
};

const allowedEdits = (length) => (length >= 10 ? 2 : length >= 4 ? 1 : 0);

const containable = (key) => Array.from(key).length >= (/^[a-z0-9]+$/.test(key) ? 4 : 2);

const similar = (a, b) => {
  if (!a || !b) return false;
  const [short, long] = a.length <= b.length ? [a, b] : [b, a];
  if (containable(short) && long.includes(short)) return true;
  return dice(a, b) >= DICE_MIN && editDistance(a, b) <= allowedEdits(Array.from(long).length);
};

// 同一套書的各集常共用書名、只差集數，上面的相似度比對會判定相符，因此集數、冊次、版次另外比對。
const CN_DIGITS = { 零: 0, 〇: 0, 一: 1, 二: 2, 兩: 2, 两: 2, 三: 3, 四: 4, 五: 5, 六: 6, 七: 7, 八: 8, 九: 9 };
const ROMAN_VALUES = { i: 1, v: 5, x: 10, l: 50, c: 100 };
const NUMERAL = '(\\d{1,3}|[零〇一二兩两三四五六七八九十百]{1,4})';
const OPEN = '[(【〔\\[〈《]';
const CLOSE = '[)】〕\\]〉》]';

const numberOf = (text) => {
  if (/^\d+$/.test(text)) return Number(text);
  if (/^[ivxlc]+$/.test(text)) {
    const values = Array.from(text, (ch) => ROMAN_VALUES[ch]);
    return values.reduce((sum, v, i) => sum + (v < (values[i + 1] ?? 0) ? -v : v), 0);
  }
  let total = 0;
  let digit = 0;
  for (const ch of text) {
    if (ch === '十' || ch === '百') {
      total += (digit || 1) * (ch === '十' ? 10 : 100);
      digit = 0;
    } else {
      digit = CN_DIGITS[ch];
    }
  }
  return total + digit;
};

const MARKERS = {
  volume: [
    new RegExp(`第\\s*${NUMERAL}\\s*[集冊册卷巻部輯辑彈弹季]`, 'gu'),
    new RegExp(`[卷巻]\\s*${NUMERAL}`, 'gu'),
    /\b(?:vol|volume|book|part|tome)\.?\s*(\d{1,3}|[ivxlc]{1,6})\b/gu,
    new RegExp(`${OPEN}\\s*${NUMERAL}\\s*${CLOSE}`, 'gu')
  ],
  part: [
    new RegExp(`${OPEN}\\s*([上中下])\\s*[冊册卷巻集部]?\\s*${CLOSE}`, 'gu'),
    /([上中下])[冊册卷巻集]/gu,
    /\s([上中下])$/gu
  ],
  edition: [
    new RegExp(`(?<!\\d)${NUMERAL}\\s*版`, 'gu'),
    /\b(\d{1,2})\s*(?:st|nd|rd|th)\s*(?:ed\b|ed\.|edition)/gu
  ]
};

// 書名中單獨的數字視為集數（「鬼滅之刃 23」「三體2：黑暗森林」「進擊的巨人 5 近全新」）。數字前須是空白或漢字、後須是空白或結尾，
// 避免把「1Q84」「Catch-22」「3分鐘」這類書名的一部分當成集數。
const LONE_NUMBER = /(?<=^|[\s\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}])(\d{1,3}|ii|iii|iv|vi|vii|viii|ix)(?=\s|$)/gu;

const markersOf = (title, subtitle = '') => {
  const text = `${prep(title)} ${prep(subtitle)}`.toLowerCase().trim();
  const found = Object.fromEntries(Object.entries(MARKERS).map(([kind, patterns]) => [
    kind,
    new Set(patterns.flatMap((pattern) => [...text.matchAll(pattern)].map((m) => (kind === 'part' ? m[1] : numberOf(m[1])))))
  ]));
  const main = prep(title).toLowerCase().replace(BRACKETED, ' ').split(SUBTITLE_SPLIT)[0].trim();
  for (const m of main.matchAll(LONE_NUMBER)) found.volume.add(numberOf(m[1]));
  return found;
};

const markersConflict = (a, b) => Object.keys(MARKERS).some((kind) =>
  a[kind].size > 0 && b[kind].size > 0 && ![...a[kind]].some((value) => b[kind].has(value)));

const titleMatches = (listed, source, { subtitle = '' } = {}) => {
  if (markersConflict(markersOf(listed), markersOf(source, subtitle))) return false;
  const ours = partsOf(listed);
  const theirs = partsOf(source, subtitle);
  if (ours.full.some((a) => theirs.full.some((b) => similar(a, b)))) return true;
  if (!similar(ours.main, theirs.main)) return false;
  return !ours.sub || !theirs.sub || similar(ours.sub, theirs.sub);
};

module.exports = { titleMatches, keyOf };
