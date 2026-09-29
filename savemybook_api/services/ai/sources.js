const { sanitizeLine, safeUrl } = require('./text');

const DOMAIN = /^(?:[a-z0-9-]+\.)+[a-z]{2,}$/;

const hostOf = (url) => {
  try {
    return new URL(url).hostname.replace(/^www\./, '').toLowerCase();
  } catch {
    return '';
  }
};

const domainOf = (item, url, trustDomain) => {
  const claimed = trustDomain ? sanitizeLine(item?.domain, 100).toLowerCase().replace(/^www\./, '') : '';
  return DOMAIN.test(claimed) ? claimed : hostOf(url);
};

// App 顯示 domain 而點擊開啟 url，domain 只能來自服務商的引用清單或已整理過的來源；模型輸出的 domain 可被提示注入偽造成別的網站。
const mergeSources = (lists, { max = 8, trustDomain = false } = {}) => {
  const out = [];
  for (const item of lists.flat()) {
    const url = safeUrl(item?.url);
    if (!url || out.some((s) => s.url === url)) continue;
    const domain = domainOf(item, url, trustDomain);
    out.push({ title: sanitizeLine(item.title, 100) || domain, url, domain });
    if (out.length >= max) break;
  }
  return out;
};

module.exports = { mergeSources, hostOf };
