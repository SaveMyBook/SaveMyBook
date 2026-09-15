const { text, optionalText } = require('../../lib/validate');
const { badRequest } = require('../../lib/errors');

const nickname = (value) => {
  const name = text(value, { label: '暱稱', max: 50 });
  if (name.length < 2) throw badRequest('暱稱至少需 2 個字');
  return name;
};

const avatarUrl = (value) => {
  const url = optionalText(value, { label: '頭像網址', max: 500 });
  if (url == null) return url;
  if (!/^(\/uploads\/avatars\/[\w.-]+|https?:\/\/\S+)$/.test(url)) throw badRequest('頭像網址格式不正確');
  return url;
};

const profileData = (body) => {
  const data = {};
  if (body.nickname !== undefined) data.nickname = nickname(body.nickname);
  if (body.bio !== undefined) data.bio = optionalText(body.bio, { label: '自我介紹', max: 500 });
  if (body.phone !== undefined) {
    const phone = optionalText(body.phone, { label: '電話', max: 20 });
    if (phone && !/^[\d+\-\s()]+$/.test(phone)) throw badRequest('電話格式不正確');
    data.phone = phone;
  }
  return data;
};

module.exports = { nickname, avatarUrl, profileData };
