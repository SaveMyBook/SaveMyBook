const { clip } = require('../../lib/text');
const { maskRisks } = require('./text');

const PRIVATE_RISKS = ['contact', 'link', 'payment', 'credential'];
const ORDER_NO = /(?<![A-Za-z0-9])SMB\d+/gi;
const LONG_NUMBER = /\d{8,}/g;
const ISBN13 = /^97[89]\d{10}$/;

// 移除含聯絡、連結、付款或帳密資訊的句子、訂單編號與 8 位以上的數字（ISBN 保留），用於會離開原對話情境的文字：
// 公開的常見問題草稿、評測集候選案例。無法辨識人名，使用前仍須人工確認。
const deidentify = (value, max = 500) => clip(
  maskRisks(String(value ?? ''), { categories: PRIVATE_RISKS })
    .replace(ORDER_NO, '')
    .replace(LONG_NUMBER, (m) => (ISBN13.test(m) ? m : ''))
    .replace(/[ \t]{2,}/g, ' ')
    .trim(),
  max
);

module.exports = { deidentify };
