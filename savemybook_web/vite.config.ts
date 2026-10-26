import { defineConfig, type Plugin } from 'vite';
import { Parser, zhHantModel } from 'budoux';
import { parseHTML } from 'linkedom';

const CJK = /[㐀-鿿]/;
const TEXT = 'main h1, main h2, main h3, main h4, main p, main li, main dd, main dt, main figcaption, main blockquote, main button, main label, main b, main small, main span';

// 斷詞器各有盲點（ICU 會拆「買家」，BudouX 會拆「規則」），只在兩者都認定的詞界斷行，再以詞表補強。
const KEEP = [
  '救「舊」我的書', '二手書', '智慧書櫃', '書櫃', '櫃門', '櫃體', '電磁鎖', '繼電器', '主控板', '開發板', '光耦合器', '端子台', '排母', '門磁',
  '買家', '賣家', '書況', '站外', '站內', '代幣', '聊天室', '購物車', '管理員', '通行密鑰', '交易密碼', '生物辨識', '推薦理由', '語意向量',
  '繁體中文', '圖書館大廳', '兩位數字', '服務費', '委託寄賣', '讀冊生活', '收訊方', '使用前', '倒數', '儲物櫃', '有效問卷', '交書',
  '暫管', '撥款', '撥付', '上架', '審核', '複核', '書目', '簡介', '售價', '建議售價', '近全新', '待修補', '定價', '入門教材', '大一新生',
  '統計學概論', '普通心理學', '經濟學原理', '林冠宇', '張雅婷', '明理文化', '書籍顧問', '個人化推薦', '高風險', '詐騙話術', '平台外交易',
  '索取驗證資料', '可疑連結', '付款資訊', '聯絡方式', '驗證碼', '防詐', '臺北市資料大平臺', '捷運站', '開放時間', '比對', '掃碼', '開門',
  '存書', '取書', '取書通知', '關上', '櫃門已開啟', '訂單', '錢包', '爭議', '裁決', '常開接點', '穩壓', '降壓', '逐扇', '通電', '斷電',
  '壓克力', '木作', '算圖', '實機', '每月預算', '每日次數', '自動刪除', '介面語言', '全數通過', '端點', '反向代理', '輪詢', '外部服務',
  '學校伺服器', '雲端代理', '客戶端', '推播', '社群登入', '下一位', '讀者', '介紹影片', '系統紀錄', '書櫃螢幕', '放大',
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
    .replace(/QR Code/g, 'QR Code')
    .replace(/(\d%?) (?=[㐀-鿿])/g, '$1 ')
    .replace(/([㐀-鿿]) (?=[A-Za-z0-9])/g, '$1 ');
}

function applyBreaks(document: Document, el: Element) {
  const walker = document.createTreeWalker(el, 4 /* NodeFilter.SHOW_TEXT */);
  const nodes: Text[] = [];
  for (let n = walker.nextNode(); n; n = walker.nextNode()) {
    if (CJK.test(n.textContent || '') && !(n.parentElement?.closest('.count, svg, .nobx, .nw, .q-item, .h1-b'))) nodes.push(n as Text);
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

/** 建置時標出中文詞組的斷行點，避免把「24 小時」這類詞拆到兩行。 */
function pageText(): Plugin {
  return {
    name: 'page-text',
    transformIndexHtml: {
      order: 'pre',
      handler(html) {
        const { document } = parseHTML(html);
        for (const el of document.querySelectorAll(TEXT)) {
          if (el.closest('.cover__title, .bx, .nobx') || !CJK.test(el.textContent || '')) continue;
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
