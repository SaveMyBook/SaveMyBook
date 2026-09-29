const googleBooks = require('../lib/google-books');
const openLibrary = require('../lib/open-library');
const isbnCodes = require('../lib/isbn');
const { titleMatches } = require('../lib/book-match');
const { notFound, HttpError } = require('../lib/errors');

const variantsOf = (isbn) => isbnCodes.forms(isbn);

const positiveInt = (value) => {
  const n = Number(value);
  return Number.isFinite(n) && n > 0 ? String(Math.trunc(n)) : '';
};

const fromGoogle = (info) => info && {
  title: info.title || '',
  subtitle: info.subtitle || '',
  author: Array.isArray(info.authors) ? info.authors.join(', ') : '',
  publisher: info.publisher || '',
  publish_date: info.publishedDate || '',
  description: info.description || '',
  page_count: positiveInt(info.pageCount),
  language: typeof info.language === 'string' ? info.language : ''
};

const fromOpenLibrary = (book) => book && {
  title: book.title,
  subtitle: '',
  author: book.authors.join(', '),
  publisher: book.publisher,
  publish_date: book.publishDate,
  description: '',
  page_count: '',
  language: ''
};

const fromOpenLibraryDetail = (detail) => detail && {
  title: '',
  subtitle: detail.subtitle || '',
  author: '',
  publisher: '',
  publish_date: detail.publishDate || '',
  description: detail.description || '',
  page_count: positiveInt(detail.pageCount),
  language: ''
};

const FIELDS = ['title', 'subtitle', 'author', 'publisher', 'publish_date', 'description', 'page_count', 'language'];

// 到日的出版日期（例如 2003-08-01）優於只到月或只到年的值，逐欄位取第一個有值的來源會漏掉較精確的那個。
const DAY_GRAIN = [/\d{4}[-/.年]\s*\d{1,2}[-/.月]\s*\d{1,2}/, /[A-Za-z]{3,}\.?\s+\d{1,2},?\s+\d{4}/, /\d{1,2}\s+[A-Za-z]{3,}\.?\s+\d{4}/];
const MONTH_GRAIN = [/\d{4}[-/.年]\s*\d{1,2}/, /[A-Za-z]{3,}\.?\s+\d{4}/];

const dateGrain = (value) => {
  const s = String(value);
  if (DAY_GRAIN.some((re) => re.test(s))) return 2;
  return MONTH_GRAIN.some((re) => re.test(s)) ? 1 : 0;
};

const settle = async (label, task) => {
  try {
    return { value: await task() };
  } catch (err) {
    console.error(`[查詢 ISBN 失敗：${label}]:`, err.message);
    return { failed: true };
  }
};

// Google Books 對中文書與未帶金鑰的請求常查無資料或回傳 429，因此同時查詢 Open Library，逐欄位取第一個有值的來源。
const gather = async (isbn, { title = '' } = {}) => {
  const code = isbnCodes.compact(isbn);
  let googleInfo = null;
  const [google, library] = await Promise.all([
    settle('Google Books', async () => {
      googleInfo = await googleBooks.fetchVolumeByIsbn(code);
      return fromGoogle(googleInfo);
    }),
    settle('Open Library', async () => {
      const edition = await openLibrary.fetchEditionByIsbn(variantsOf(code));
      const listed = edition?.isbns ?? [];
      return edition && (listed.length === 0 || isbnCodes.sameBook(code, listed)) ? edition : null;
    })
  ]);

  const libraryFields = fromOpenLibrary(library.value);
  if (!google.value && !libraryFields) {
    // Open Library 幾乎沒有中文書，Google Books 被限流（429）時不能當成查無此書，否則背景補齊會永久略過。
    if (google.failed || library.failed) throw new HttpError(502, '查詢外部書籍資訊發生錯誤');
    throw notFound('找不到此 ISBN 的書籍資訊');
  }
  const trusted = (fields) => Boolean(fields) && (!title || titleMatches(title, fields.title, { subtitle: fields.subtitle }));
  const useGoogle = trusted(google.value);
  const useLibrary = trusted(libraryFields);
  if (!useGoogle && !useLibrary) throw new HttpError(409, '此 ISBN 的書目與書名不符', 'ISBN_TITLE_MISMATCH');

  const sources = [useGoogle && google.value, useLibrary && libraryFields].filter(Boolean);
  if (useLibrary) {
    const detail = await settle('Open Library 版本頁', () => openLibrary.fetchEditionDetailByIsbn(library.value.isbn));
    const extra = fromOpenLibraryDetail(detail.value);
    if (extra) sources.push(extra);
  }

  const result = Object.fromEntries(FIELDS.map((field) => [field, sources.find((s) => s[field])?.[field] ?? '']));
  const bestDate = sources.map((s) => s.publish_date).filter(Boolean).sort((a, b) => dateGrain(b) - dateGrain(a))[0];
  if (bestDate) result.publish_date = bestDate;

  const links = [
    useGoogle && { title: 'Google Books', url: googleInfo?.infoLink || googleInfo?.canonicalVolumeLink || `https://books.google.com/books?vid=ISBN${code}` },
    useLibrary && { title: 'Open Library', url: `${openLibrary.BASE}/isbn/${encodeURIComponent(library.value.isbn)}` }
  ].filter(Boolean);
  return { result, links };
};

const lookup = async (isbn) => (await gather(isbn)).result;

const lookupWithSources = async (isbn, options) => {
  const { result, links } = await gather(isbn, options);
  return { fields: result, sources: links };
};

module.exports = { lookup, lookupWithSources, variantsOf };
