const TYPING_TTL_MS = 6000;

const typing = new Map();

const keyOf = (roomId, userId) => `${roomId}:${userId}`;

const set = (roomId, userId) => typing.set(keyOf(roomId, userId), Date.now());

const clear = (roomId, userId) => typing.delete(keyOf(roomId, userId));

const isTyping = (roomId, userId) => {
  const at = typing.get(keyOf(roomId, userId));
  return Boolean(at && Date.now() - at < TYPING_TTL_MS);
};

setInterval(() => {
  const now = Date.now();
  for (const [key, at] of typing) if (now - at > TYPING_TTL_MS) typing.delete(key);
}, 60 * 1000).unref();

module.exports = { set, clear, isTyping };
