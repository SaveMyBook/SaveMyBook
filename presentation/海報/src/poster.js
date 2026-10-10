// 海報共用腳本：處理網址旗標、寫入 @page 尺寸、內嵌 SVG、等字型載入完成後設定 window.__ready。
//   ?bleed=0   輸出完成尺寸（不含出血）
//   ?guides=1  疊上完成線（洋紅虛線）、內容範圍（藍線）與中線，只供審稿，輸出工具不會帶這個旗標
(async () => {
  const q = new URLSearchParams(location.search);
  const root = document.documentElement;
  if (q.get('bleed') === '0') root.classList.add('no-bleed');

  // 讀取各海報設定的完成尺寸（mm）並寫入 @page
  const cs = getComputedStyle(root);
  const mm = (name) => {
    const v = cs.getPropertyValue(name).trim();
    const m = v.match(/^([\d.]+)mm$/);
    if (!m) throw new Error(`${name} 必須以 mm 表示，目前為 "${v}"`);
    return parseFloat(m[1]);
  };
  const bleed = root.classList.contains('no-bleed') ? 0 : mm('--bleed-max');
  const page = { trimW: mm('--trim-w'), trimH: mm('--trim-h'), bleed };
  page.w = +(page.trimW + 2 * bleed).toFixed(3);
  page.h = +(page.trimH + 2 * bleed).toFixed(3);
  const style = document.createElement('style');
  style.textContent = `@page { size: ${page.w}mm ${page.h}mm; margin: 0; }`;
  document.head.append(style);
  window.__page = page;

  // 內嵌 SVG：<div class="inline-svg" data-src="assets/logo.svg"></div>
  // 內嵌後 PDF 內為向量；id 加上前綴，避免同頁多份時 url(#…) 互相指錯
  let n = 0;
  await Promise.all([...document.querySelectorAll('[data-src]')].map(async (host) => {
    const k = `s${++n}-`;
    const txt = await (await fetch(host.dataset.src)).text();
    const doc = new DOMParser().parseFromString(txt, 'image/svg+xml');
    const svg = doc.documentElement;
    svg.querySelectorAll('[id]').forEach((e) => { e.id = k + e.id; });
    svg.querySelectorAll('*').forEach((e) => {
      for (const a of [...e.attributes]) if (a.value.includes('url(#')) e.setAttribute(a.name, a.value.replace(/url\(#/g, `url(#${k}`));
    });
    svg.removeAttribute('width');
    svg.removeAttribute('height');
    svg.setAttribute('preserveAspectRatio', host.dataset.align || 'xMidYMid meet');
    host.replaceChildren(document.importNode(svg, true));
  }));

  if (q.get('guides') === '1') {
    const sheet = document.querySelector('.sheet') || document.body;
    for (const c of ['trim', 'safe', 'cx', 'cy']) {
      const g = document.createElement('div');
      g.className = `guide guide--${c}`;
      sheet.append(g);
    }
  }

  // 等所有用到的字重載入（含頁面上實際出現的字），再等圖片
  const text = document.body.innerText;
  await Promise.all(['400', '500', '700', '900'].map((w) => document.fonts.load(`${w} 40px "Noto Sans TC"`, text)));
  if (document.querySelector('.mono, .door-no')) await document.fonts.load('500 40px "IBM Plex Mono"', 'A01');
  await document.fonts.ready;

  // 漸層字：<i data-grad="#7C97A6,#4A6372">「舊」</i>
  // CSS background-clip:text 在 Chrome 的 PDF 會被點陣化，改疊一層 SVG <text>（漸層填色、PDF 仍為向量），
  // 原本的 HTML 文字保留排版、改為透明，所以版面不會位移。
  for (const el of document.querySelectorAll('[data-grad]')) {
    const [c0, c1] = el.dataset.grad.split(',').map((s) => s.trim());
    const box = el.getBoundingClientRect();
    const scale = box.width / el.offsetWidth || 1;
    const probe = document.createElement('span');
    probe.style.cssText = 'display:inline-block;width:0;height:0;vertical-align:baseline';
    el.prepend(probe);
    const baseline = (probe.getBoundingClientRect().top - box.top) / scale;
    probe.remove();
    const w = el.offsetWidth, h = el.offsetHeight;
    const s = getComputedStyle(el);
    const NS = 'http://www.w3.org/2000/svg';
    const svg = document.createElementNS(NS, 'svg');
    const id = `grad-${Math.random().toString(36).slice(2, 8)}`;
    svg.setAttribute('width', w);
    svg.setAttribute('height', h);
    svg.setAttribute('viewBox', `0 0 ${w} ${h}`);
    svg.setAttribute('aria-hidden', 'true');
    svg.style.cssText = 'position:absolute;left:0;top:0;overflow:visible;pointer-events:none';
    svg.innerHTML = `<defs><linearGradient id="${id}" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="0" y2="${h}">`
      + `<stop offset="0" stop-color="${c0}"/><stop offset="1" stop-color="${c1}"/></linearGradient></defs>`;
    const t = document.createElementNS(NS, 'text');
    t.setAttribute('x', '0');
    t.setAttribute('y', String(baseline));
    t.setAttribute('fill', `url(#${id})`);
    t.style.cssText = `font-family:${s.fontFamily};font-weight:${s.fontWeight};font-size:${s.fontSize};`
      + `letter-spacing:${s.letterSpacing};font-feature-settings:${s.fontFeatureSettings};white-space:pre`;
    t.textContent = el.textContent;
    svg.append(t);
    el.style.position = 'relative';
    el.style.color = 'transparent';
    el.append(svg);
  }

  await Promise.all([...document.images].map((img) => (img.complete ? null : new Promise((r) => { img.onload = img.onerror = r; }))));
  await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
  window.__ready = true;
})().catch((e) => {
  window.__error = String(e && e.stack || e);
  console.error(e);
});
