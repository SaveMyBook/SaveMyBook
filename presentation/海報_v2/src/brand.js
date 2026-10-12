// 展版海報 v3 共用圖形（在 base.js 之前載入）：
//   <svg class="waffle" data-pct="57.9"></svg>  10×10 方格，亮色格數＝百分比（四捨五入），由下往上填
//   <svg class="flow"></svg>                     綠色向下箭頭（問題 → 技術解法）
(() => {
  const acc = getComputedStyle(document.documentElement).getPropertyValue('--accent').trim() || '#2E749E';
  for (const w of document.querySelectorAll('.waffle')) {
    const n = Math.round(parseFloat(w.dataset.pct));
    let h = '';
    for (let i = 0; i < 100; i++) {
      const r = 9 - Math.floor(i / 10), c = i % 10;
      h += `<rect x="${c * 10 + 1}" y="${r * 10 + 1}" width="8" height="8" rx="1.2" fill="${i < n ? acc : '#627D8D'}" fill-opacity="${i < n ? 1 : 0.16}"/>`;
    }
    w.setAttribute('viewBox', '0 0 100 100');
    w.innerHTML = h;
  }
  for (const f of document.querySelectorAll('.flow')) {
    f.setAttribute('viewBox', '0 0 10 18');
    f.innerHTML = '<path d="M5 1V16" stroke="#2E9E5B" stroke-width="1.6" fill="none" stroke-linecap="round"/>'
      + '<path d="M1.6 12.4L5 16.6L8.4 12.4" stroke="#2E9E5B" stroke-width="1.6" fill="none" stroke-linecap="round" stroke-linejoin="round"/>';
  }
})();
