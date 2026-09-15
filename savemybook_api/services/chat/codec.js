const PREFIX = {
  book: '[book]',
  voice: '[voice]',
  reservation: '[reservation]',
  transfer: '[transfer]',
  recalled: '[recalled]'
};

const RECALL_WINDOW_MS = 24 * 60 * 60 * 1000;
const EDIT_WINDOW_MS = 15 * 60 * 1000;
const MAX_VOICE_SECONDS = 120;

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

const previewOf = (message, { transfers } = {}) => {
  const { kind, body, payload } = decode(message);
  if (kind === 'text' || kind === 'notice') return String(body ?? '').slice(0, 100);
  if (kind === 'book' && payload?.title) return `[商品] ${payload.title}`;
  if (kind === 'transfer' && transfers?.get(transferIdOf(payload))?.kind === 'request') return '[請款]';
  return PREVIEW[kind] ?? '';
};

const replyPreview = (message) => {
  const { kind, body } = decode(message);
  return {
    message_id: message.message_id,
    sender_id: message.sender_id,
    sender_nickname: message.users?.nickname ?? null,
    kind,
    preview: previewOf(message),
    image_url: kind === 'image' ? body : null
  };
};

const shapeMessage = (message, { reservations, transfers } = {}) => {
  const { kind, body, payload } = decode(message);
  let data = payload;
  if (kind === 'reservation') data = reservations?.get(Number(payload.reservation_id)) ?? payload;
  if (kind === 'transfer') data = transfers?.get(transferIdOf(payload)) ?? payload;
  return { ...message, kind, body, payload: data };
};

module.exports = {
  PREFIX, RECALL_WINDOW_MS, EDIT_WINDOW_MS, MAX_VOICE_SECONDS, decode, previewOf, shapeMessage, replyPreview,
  transferIdOf, encodeVoice, encodeReservation, encodeTransfer, encodeBook
};
