const { env } = require('../config/env');

const fetchVolumeByIsbn = async (isbn) => {
  const url = new URL('https://www.googleapis.com/books/v1/volumes');
  url.searchParams.set('q', `isbn:${isbn}`);
  url.searchParams.set('printType', 'books');
  // projection=lite 會少掉 description、subtitle、pageCount 與完整的 publishedDate，因此查完整的 volume。
  if (env.googleBooksApiKey) url.searchParams.set('key', env.googleBooksApiKey);

  const response = await fetch(url, { signal: AbortSignal.timeout(8000) });
  if (!response.ok) throw new Error(`Google Books HTTP ${response.status}`);
  const data = await response.json();
  return data?.items?.[0]?.volumeInfo ?? null;
};

const identifierOf = (info) => {
  const ids = Array.isArray(info?.industryIdentifiers) ? info.industryIdentifiers : [];
  return (ids.find((i) => i?.type === 'ISBN_13') ?? ids.find((i) => i?.type === 'ISBN_10'))?.identifier ?? '';
};

const searchVolumesByTitle = async (title, limit = 3) => {
  const url = new URL('https://www.googleapis.com/books/v1/volumes');
  url.searchParams.set('q', `intitle:${title}`);
  url.searchParams.set('printType', 'books');
  url.searchParams.set('maxResults', String(limit));
  if (env.googleBooksApiKey) url.searchParams.set('key', env.googleBooksApiKey);

  const response = await fetch(url, { signal: AbortSignal.timeout(8000) });
  if (!response.ok) throw new Error(`Google Books HTTP ${response.status}`);
  const data = await response.json();
  return (data?.items ?? []).slice(0, limit).map((item) => {
    const info = item?.volumeInfo ?? {};
    return {
      title: info.title || '',
      author: Array.isArray(info.authors) ? info.authors.join(', ') : '',
      publisher: info.publisher || '',
      publish_date: info.publishedDate || '',
      isbn: identifierOf(info),
      description: info.description || '',
      url: info.infoLink || info.canonicalVolumeLink || ''
    };
  });
};

module.exports = { fetchVolumeByIsbn, searchVolumesByTitle, identifierOf };
