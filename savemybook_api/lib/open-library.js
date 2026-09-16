const { env } = require('../config/env');

const BASE = 'https://openlibrary.org';
const TIMEOUT_MS = 8000;

// Open Library 要求程式化存取時以 User-Agent 標示應用程式與聯絡方式，未標示的請求較容易被限流。
const headers = () => ({
  'User-Agent': `SaveMyBook/1.0 (${env.publicWebUrl || 'https://github.com/SaveMyBook/SaveMyBook'})`,
  Accept: 'application/json'
});

const getJson = async (path) => {
  const response = await fetch(`${BASE}${path}`, { headers: headers(), signal: AbortSignal.timeout(TIMEOUT_MS) });
  if (response.status === 404) return null;
  if (!response.ok) throw new Error(`Open Library HTTP ${response.status}`);
  return response.json();
};

const textOf = (value) => (typeof value === 'string' ? value : typeof value?.value === 'string' ? value.value : '');

const fetchEditionByIsbn = async (isbns) => {
  const keys = isbns.map((isbn) => `ISBN:${isbn}`);
  const data = await getJson(`/api/books?bibkeys=${encodeURIComponent(keys.join(','))}&format=json&jscmd=data`);
  const key = keys.find((k) => data?.[k]);
  if (!key) return null;
  const book = data[key];
  return {
    title: book.title || '',
    authors: (book.authors ?? []).map((a) => a?.name).filter(Boolean),
    publisher: (book.publishers ?? []).map((p) => p?.name).filter(Boolean).join(', '),
    publishDate: book.publish_date || '',
    isbn: key.slice('ISBN:'.length)
  };
};

// /api/books 的 jscmd=data 只給年份層級的 publish_date，版本頁 /isbn/{isbn}.json 才可能有到日的日期。
const fetchEditionDetailByIsbn = async (isbn) => {
  const edition = await getJson(`/isbn/${encodeURIComponent(isbn)}.json`);
  if (!edition) return null;
  let description = textOf(edition.description);
  const workKey = edition.works?.[0]?.key;
  if (!description && typeof workKey === 'string' && /^\/works\/OL\d+W$/.test(workKey)) {
    const work = await getJson(`${workKey}.json`);
    description = textOf(work?.description);
  }
  const pages = Number(edition.number_of_pages);
  return {
    description,
    publishDate: typeof edition.publish_date === 'string' ? edition.publish_date : '',
    subtitle: typeof edition.subtitle === 'string' ? edition.subtitle : '',
    pageCount: Number.isFinite(pages) && pages > 0 ? Math.trunc(pages) : null,
    language: (edition.languages ?? []).map((l) => l?.key).find((k) => typeof k === 'string') ?? ''
  };
};

const fetchDescriptionByIsbn = async (isbn) => (await fetchEditionDetailByIsbn(isbn))?.description ?? '';

const searchByTitle = async (title, limit = 3) => {
  const params = new URLSearchParams({
    title,
    limit: String(limit),
    fields: 'key,title,author_name,publisher,first_publish_year,isbn'
  });
  const data = await getJson(`/search.json?${params}`);
  return (data?.docs ?? []).slice(0, limit).map((doc) => ({
    title: doc.title || '',
    author: (doc.author_name ?? []).slice(0, 3).join(', '),
    publisher: (doc.publisher ?? [])[0] || '',
    publish_date: doc.first_publish_year ? String(doc.first_publish_year) : '',
    isbn: (doc.isbn ?? []).find((i) => /^\d{13}$/.test(i)) || (doc.isbn ?? [])[0] || '',
    description: '',
    url: typeof doc.key === 'string' && /^\/works\/OL\d+W$/.test(doc.key) ? `${BASE}${doc.key}` : ''
  }));
};

module.exports = { fetchEditionByIsbn, fetchEditionDetailByIsbn, fetchDescriptionByIsbn, searchByTitle, BASE };
