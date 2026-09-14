const bcrypt = require('bcrypt');
const crypto = require('crypto');
const { badRequest } = require('./errors');

const ROUNDS = 10;

const hash = (plain) => bcrypt.hash(plain, ROUNDS);

/// 資料庫裡的雜湊若不是字串（匿名化帳號、髒資料），bcrypt 會拋錯，這裡一律當作不符。
const verify = async (plain, hashed) => {
  if (typeof plain !== 'string' || typeof hashed !== 'string') return false;
  try {
    return await bcrypt.compare(plain, hashed);
  } catch {
    return false;
  }
};

/// 與 App 端 Validators.password 一致。上限 72 是 bcrypt 的限制：
/// 超過的位元組會被默默截掉，兩組前 72 位元組相同的密碼會被視為同一組。
const assertPolicy = (plain, label = '密碼') => {
  if (typeof plain !== 'string' || plain.length < 8) throw badRequest(`${label}長度至少 8 個字元`);
  if (Buffer.byteLength(plain, 'utf8') > 72) throw badRequest(`${label}太長了`);
  if (!/[A-Za-z]/.test(plain)) throw badRequest(`${label}必須包含英文字母`);
  if (!/[0-9]/.test(plain)) throw badRequest(`${label}必須包含數字`);
};

const TEMP_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';

/// 臨時密碼由伺服器產生，管理員不能自己指定。
///
/// 讓管理員輸入密碼的話，密碼會出現在他的鍵盤、剪貼簿與記憶裡，
/// 而且多半會設成好記的那幾個。這裡用密碼學亂數，排除看起來像的字元
/// （0/O、1/l/I），因為這串字多半是用電話或口頭念給使用者的。
const temporary = () => {
  let out = '';
  // randomInt 沒有取餘數造成的分佈偏差。
  for (let i = 0; i < 12; i += 1) out += TEMP_ALPHABET[crypto.randomInt(TEMP_ALPHABET.length)];
  // 保證同時含有字母與數字，才過得了密碼規則。
  return `${out}7a`;
};

module.exports = { hash, verify, assertPolicy, temporary };
