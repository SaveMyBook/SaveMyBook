const bcrypt = require('bcrypt');
const crypto = require('crypto');
const { badRequest } = require('./errors');

const ROUNDS = 10;

const hash = (plain) => bcrypt.hash(plain, ROUNDS);

// 非字串的雜湊會讓 bcrypt 拋錯。
const verify = async (plain, hashed) => {
  if (typeof plain !== 'string' || typeof hashed !== 'string') return false;
  try {
    return await bcrypt.compare(plain, hashed);
  } catch {
    return false;
  }
};

// 上限 72 位元組是 bcrypt 的限制，超過的部分會被默默截掉。
const assertPolicy = (plain, label = '密碼') => {
  if (typeof plain !== 'string' || plain.length < 8) throw badRequest(`${label}長度至少 8 個字元`);
  if (Buffer.byteLength(plain, 'utf8') > 72) throw badRequest(`${label}太長了`);
  if (!/[A-Za-z]/.test(plain)) throw badRequest(`${label}必須包含英文字母`);
  if (!/[0-9]/.test(plain)) throw badRequest(`${label}必須包含數字`);
};

const TEMP_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';

const temporary = () => {
  let out = '';
  for (let i = 0; i < 12; i += 1) out += TEMP_ALPHABET[crypto.randomInt(TEMP_ALPHABET.length)];
  // 保證同時含有字母與數字，才過得了密碼規則。
  return `${out}7a`;
};

module.exports = { hash, verify, assertPolicy, temporary };
