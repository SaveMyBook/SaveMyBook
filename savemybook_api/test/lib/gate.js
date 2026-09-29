// 前 n 個呼叫全部抵達後才一起放行，重現併發請求都已讀到同一份舊資料的最壞交錯；逾時仍會放行，避免測試卡住。
const gate = (n, { timeoutMs = 3000 } = {}) => {
  const waiting = [];
  let opened = false;
  let timer = null;
  const open = () => {
    opened = true;
    clearTimeout(timer);
    waiting.splice(0).forEach((release) => release());
  };
  timer = setTimeout(open, timeoutMs);

  const wait = (value) => (opened ? Promise.resolve(value) : new Promise((resolve) => {
    waiting.push(() => resolve(value));
    if (waiting.length >= n) open();
  }));

  return { wait, open };
};

const concurrently = async (release, requests) => {
  try {
    return await Promise.all(requests);
  } finally {
    release();
  }
};

module.exports = { gate, concurrently };
