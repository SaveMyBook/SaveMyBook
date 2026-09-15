const { fetchVolumeByIsbn } = require('../lib/google-books');
const openLibrary = require('../lib/open-library');
const { notFound, HttpError } = require('../lib/errors');

const isbn10CheckDigit = (nine) => {
  const sum = [...nine].reduce((acc, d, i) => acc + Number(d) * (10 - i), 0);
  const check = (11 - (sum % 11)) % 11;
  return check === 10 ? 'X' : String(check);
};

const isbn13CheckDigit = (twelve) => {
  const sum = [...twelve].reduce((acc, d, i) => acc + Number(d) * (i % 2 === 0 ? 1 : 3), 0);
  return String((10 - (sum % 10)) % 10);
};

const variantsOf = (isbn) => {
  const code = isbn.toUpperCase();
  if (code.length === 10) return [code, `978${code.slice(0, 9)}${isbn13CheckDigit(`978${code.slice(0, 9)}`)}`];
  if (code.startsWith('978')) return [code, `${code.slice(3, 12)}${isbn10CheckDigit(code.slice(3, 12))}`];
  return [code];
};

const fromGoogle = (info) => info && {
  title: info.title || '',
  author: Array.isArray(info.authors) ? info.authors.join(', ') : '',
  publisher: info.publisher || '',
  publish_date: info.publishedDate || '',
  description: info.description || ''
};

const fromOpenLibrary = (book) => book && {
  title: book.title,
  author: book.authors.join(', '),
  publisher: book.publisher,
  publish_date: book.publishDate,
  description: ''
};

const FIELDS = ['title', 'author', 'publisher', 'publish_date', 'description'];

const settle = async (label, task) => {
  try {
    return { value: await task() };
  } catch (err) {
    console.error(`[查詢 ISBN 失敗：${label}]:`, err.message);
    return { failed: true };
  }
};

// Google Books 對中文書與未帶金鑰的請求常查無資料或回傳 429，因此同時查詢 Open Library，逐欄位取第一個有值的來源。
const gather = async (isbn) => {
  const variants = variantsOf(isbn);
  let googleInfo = null;
  const [google, library] = await Promise.all([
    settle('Google Books', async () => {
      googleInfo = await fetchVolumeByIsbn(isbn);
      return fromGoogle(googleInfo);
    }),
    settle('Open Library', () => openLibrary.fetchEditionByIsbn(variants))
  ]);

  const sources = [google.value, fromOpenLibrary(library.value)].filter(Boolean);
  if (sources.length === 0) {
    if (google.failed && library.failed) throw new HttpError(502, '查詢外部書籍資訊發生錯誤');
    throw notFound('外部書庫找不到此 ISBN 的書籍資訊');
  }

  const result = Object.fromEntries(FIELDS.map((field) => [field, sources.find((s) => s[field])?.[field] ?? '']));
  if (!result.description && library.value) {
    const extra = await settle('Open Library 簡介', () => openLibrary.fetchDescriptionByIsbn(library.value.isbn));
    result.description = extra.value || '';
  }

  const links = [
    google.value && { title: 'Google Books', url: googleInfo?.infoLink || googleInfo?.canonicalVolumeLink || `https://books.google.com/books?vid=ISBN${isbn}` },
    library.value && { title: 'Open Library', url: `${openLibrary.BASE}/isbn/${encodeURIComponent(library.value.isbn)}` }
  ].filter(Boolean);
  return { result, links };
};

const lookup = async (isbn) => (await gather(isbn)).result;

const lookupWithSources = async (isbn) => {
  const { result, links } = await gather(isbn);
  return { fields: result, sources: links };
};

module.exports = { lookup, lookupWithSources, variantsOf };
