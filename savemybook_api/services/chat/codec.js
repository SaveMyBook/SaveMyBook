const PREFIX = {
  book: '[book]',
  voice: '[voice]',
  reservation: '[reservation]',
  transfer: '[transfer]',
  album: '[album]',
  recalled: '[recalled]'
};

const RECALL_WINDOW_MS = 60 * 60 * 1000;
const EDIT_WINDOW_MS = 15 * 60 * 1000;
const MAX_VOICE_SECONDS = 120;
const MIN_ALBUM_IMAGES = 2;
const MAX_ALBUM_IMAGES = 20;
const RECALLABLE_KINDS = ['text', 'image', 'voice', 'album'];

const parseJson = (text) => {
  try {
    const value = JSON.parse(text);
    return value && typeof value === 'object' ? value : null;
  } catch {
    return null;
  }
};

const decode = (message) => {
  const content = String(message.content ?? '');
  if (message.message_type === 'image') return { kind: 'image', body: content, payload: null };
  if (message.message_type !== 'system') return { kind: 'text', body: content, payload: null };

  for (const [kind, prefix] of Object.entries(PREFIX)) {
    if (!content.startsWith(prefix)) continue;
    if (kind === 'recalled') {
      if (content === prefix) return { kind, body: null, payload: null };
      continue;
    }
    const payload = parseJson(content.slice(prefix.length));
    if (payload) return { kind, body: null, payload };
  }
  return { kind: 'notice', body: content, payload: null };
};

const encodeVoice = ({ url, duration }) => `${PREFIX.voice}${JSON.stringify({ url, duration })}`;
const encodeReservation = (reservationId) => `${PREFIX.reservation}${JSON.stringify({ reservation_id: reservationId })}`;
const encodeTransfer = (transferId) => `${PREFIX.transfer}${JSON.stringify({ transfer_id: transferId })}`;
const encodeAlbum = (urls) => `${PREFIX.album}${JSON.stringify({ urls })}`;
const encodeBook = (book) => PREFIX.book + JSON.stringify({
  book_id: book.book_id,
  title: book.title,
  price: book.price,
  image_url: book.book_images?.[0]?.image_url ?? null
});

const PREVIEW = {
  image: '[圖片]',
  voice: '[語音]',
  book: '[商品]',
  reservation: '[預約]',
  transfer: '[轉帳]',
  recalled: '訊息已收回'
};

const transferIdOf = (payload) => Number(payload?.transfer_id);

const albumUrlsOf = (payload) => (Array.isArray(payload?.urls) ? payload.urls.filter((u) => typeof u === 'string') : []);

const albumPreview = (count) => `[圖片] ${count} 張`;

const toMentions = (value) => {
  let list = value;
  if (typeof value === 'string') {
    try {
      list = JSON.parse(value);
    } catch {
      return [];
    }
  }
  if (!Array.isArray(list)) return [];
  return list
    .filter((m) => m && typeof m === 'object')
    .map((m) => ({ user_id: Number(m.user_id), start: Number(m.start), length: Number(m.length) }))
    .filter((m) => [m.user_id, m.start, m.length].every(Number.isSafeInteger));
};

const previewOf = (message, { transfers } = {}) => {
  const { kind, body, payload } = decode(message);
  if (kind === 'text' || kind === 'notice') return String(body ?? '').slice(0, 100);
  if (kind === 'book' && payload?.title) return `[商品] ${payload.title}`;
  if (kind === 'album') return albumPreview(albumUrlsOf(payload).length);
  if (kind === 'transfer' && transfers?.get(transferIdOf(payload))?.kind === 'request') return '[請款]';
  return PREVIEW[kind] ?? '';
};

const replyPreview = (message) => {
  const { kind, body, payload } = decode(message);
  let imageUrl = null;
  if (kind === 'image') imageUrl = body;
  if (kind === 'album') imageUrl = albumUrlsOf(payload)[0] ?? null;
  return {
    message_id: message.message_id,
    sender_id: message.sender_id,
    sender_nickname: message.users?.nickname ?? null,
    kind,
    preview: previewOf(message),
    image_url: imageUrl
  };
};

const shapeMessage = (message, { reservations, transfers } = {}) => {
  const { kind, body, payload } = decode(message);
  let data = payload;
  if (kind === 'reservation') data = reservations?.get(Number(payload.reservation_id)) ?? payload;
  if (kind === 'transfer') data = transfers?.get(transferIdOf(payload)) ?? payload;
  if (kind === 'album') data = { urls: albumUrlsOf(payload) };
  return { ...message, kind, body, payload: data, mentions: kind === 'text' ? toMentions(message.mentions) : [] };
};

module.exports = {
  PREFIX, RECALL_WINDOW_MS, EDIT_WINDOW_MS, MAX_VOICE_SECONDS, MIN_ALBUM_IMAGES, MAX_ALBUM_IMAGES, RECALLABLE_KINDS,
  decode, previewOf, shapeMessage, replyPreview, transferIdOf, albumPreview, toMentions,
  encodeVoice, encodeReservation, encodeTransfer, encodeAlbum, encodeBook
};
