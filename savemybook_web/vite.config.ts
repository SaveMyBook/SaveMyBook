import { defineConfig, type Plugin } from 'vite';
import { Parser, zhHantModel } from 'budoux';
import { parseHTML } from 'linkedom';
import { SHELF, AI_FEATURES } from './src/data/content';

const CJK = /[㐀-鿿]/;
const TEXT = 'main h2, main p, main li, main dd, main dt, main figcaption, main aside';

// 斷詞器各有盲點（ICU 會拆「買家」，BudouX 會拆「規則」），只在兩者都認定的詞界斷行，再以詞表補強。
const KEEP = [
  '救「舊」我的書', '二手書', '智慧書櫃', '書櫃', '櫃門', '電磁鎖', '繼電器', '控制板', '買家', '賣家', '書況', '站外', '站內',
  '代幣', '聊天室', '購物車', '管理員', '通行密鑰', '交易密碼', '生物辨識', '推薦理由', '語意向量', '繁體中文', '圖書館大廳',
  '我的預約', '兩位數字', '服務費', '收訊方', '拍張照片', '哪裡', '使用前', '倒數', '儲物櫃',
  ...SHELF.flatMap((b) => [b.title, b.author.replace(/ [著編]$/, '')]),
];
const budoux = new Parser(zhHantModel);
const icu = new Intl.Segmenter('zh-Hant', { granularity: 'word' });

function boundaries(text: string, chunks: Iterable<string>) {
  const out = new Set<number>();
  let i = 0;
  for (const c of chunks) out.add((i += c.length));
  return out;
}

/** 回傳可斷行的位置。 */
function phraseBreaks(text: string) {
  const a = boundaries(text, [...icu.segment(text)].map((s) => s.segment));
  const b = boundaries(text, budoux.parse(text));
  const guarded = new Set<number>();
  for (const w of KEEP) {
    for (let k = text.indexOf(w); k >= 0; k = text.indexOf(w, k + 1)) {
      for (let p = k + 1; p < k + w.length; p++) guarded.add(p);
    }
  }
  const out: number[] = [];
  let last = 0;
  for (let p = 1; p < text.length; p++) {
    if (guarded.has(p)) continue;
    // 頓號、間隔號等標點之後一律可斷，否則整串會被視為一個詞而擠到下一行
    if (!'、・，；：）」』'.includes(text[p - 1]) && (!a.has(p) || !b.has(p))) continue;
    if (/\s/.test(text[p - 1]) || /\s/.test(text[p])) continue;
    // 單一字（與、的、並…）跟著後面的詞，不單獨留在行尾
    const piece = text.slice(last, p).trim();
    if (piece.length === 1 && CJK.test(piece)) continue;
    out.push(p);
    last = p;
  }
  return out;
}

/** 數字與單位、中文與其後的英數字之間的空格改為不斷行空格（如「24 小時」「依 ISBN」）。 */
function glueSpaces(text: string) {
  return text
    .replace(/(\d%?) (?=[㐀-鿿])/g, '$1 ')
    .replace(/([㐀-鿿]) (?=[A-Za-z0-9])/g, '$1 ');
}

function applyBreaks(document: Document, el: Element) {
  const walker = document.createTreeWalker(el, 4 /* NodeFilter.SHOW_TEXT */);
  const nodes: Text[] = [];
  for (let n = walker.nextNode(); n; n = walker.nextNode()) {
    if (CJK.test(n.textContent || '') && !(n.parentElement?.closest('.count, svg'))) nodes.push(n as Text);
  }
  for (const node of nodes) {
    const text = glueSpaces(node.textContent || '');
    const cuts = phraseBreaks(text);
    const frag = document.createDocumentFragment();
    let last = 0;
    for (const p of [...cuts, text.length]) {
      frag.append(document.createTextNode(text.slice(last, p)));
      if (p < text.length) frag.append(document.createElement('wbr'));
      last = p;
    }
    node.replaceWith(frag);
  }
  el.classList.add('bx');
}

function shelfHtml() {
  return SHELF.map((b) => `
    <li class="book" style="--c:${b.color};--w:${b.w}px;--h:${b.h}px;${b.text ? `--t:${b.text};` : ''}${b.band ? `--band:${b.band};` : ''}" tabindex="0">
      <div class="book__cover"><p class="book__title">${b.title}</p><p class="book__author">${b.author}</p></div>
      <p class="book__note"><b>推薦理由</b>${b.reason}</p>
    </li>`).join('');
}

function orbitHtml() {
  return AI_FEATURES.map((f) => `<li><span class="ico">${f.icon}</span><b>${f.name}</b><small>${f.note}</small></li>`).join('');
}

/** 建置時寫入書架與 AI 功能清單，並標出中文詞組的斷行點，避免把「24 小時」這類詞拆到兩行。 */
function pageText(): Plugin {
  return {
    name: 'page-text',
    transformIndexHtml: {
      order: 'pre',
      handler(html) {
        const filled = html
          .replace('<ol class="shelf__row"></ol>', `<ol class="shelf__row">${shelfHtml()}</ol>`)
          .replace('<ol class="orbit__ring"></ol>', `<ol class="orbit__ring">${orbitHtml()}</ol>`);
        const { document } = parseHTML(filled);
        for (const el of document.querySelectorAll(TEXT)) {
          if (el.closest('.cover__title, .bx') || !CJK.test(el.textContent || '')) continue;
          applyBreaks(document as unknown as Document, el);
        }
        return document.toString();
      },
    },
  };
}

export default defineConfig({
  base: '/',
  plugins: [pageText()],
  build: {
    target: 'es2022',
    assetsInlineLimit: 0,
    chunkSizeWarningLimit: 900,
  },
});
