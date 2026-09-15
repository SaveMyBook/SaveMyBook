const { env } = require('../config/env');

const fetchVolumeByIsbn = async (isbn) => {
  const url = new URL('https://www.googleapis.com/books/v1/volumes');
  url.searchParams.set('q', `isbn:${isbn}`);
  url.searchParams.set('printType', 'books');
  url.searchParams.set('projection', 'lite');
  if (env.googleBooksApiKey) url.searchParams.set('key', env.googleBooksApiKey);

  const response = await fetch(url, { signal: AbortSignal.timeout(8000) });
  if (!response.ok) throw new Error(`Google Books HTTP ${response.status}`);
  const data = await response.json();
  return data?.items?.[0]?.volumeInfo ?? null;
};

module.exports = { fetchVolumeByIsbn };
