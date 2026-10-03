/** 全片共用的故事資料：書、人、編號（NMIXX 彩蛋見 memory/nmixx-members）。實際文字以 App 截圖為準。 */
export const BOOK = {
  title: '普通化學',
  price: 222,
  cover: '#4E6674',
};

/** 每支手機在各畫面上的重點區塊（App 邏輯座標 393×852），取自 assets-src/screens/rects.json。 */
export const R = {
  // 賣家上架：第 1 步書籍資料（ISBN → AI 帶入書目）
  isbnAi: { x: 16, y: 131, w: 361, h: 46 },
  fillFields: { x: 16, y: 188, w: 361, h: 306 },
  fillIntro: { x: 16, y: 582.2, w: 361, h: 99 },
  fillApply: { x: 143, y: 758, w: 234, h: 48 },
  // 第 2 步詳細資料與照片（照片 → AI 判斷書況與售價）
  photosCard: { x: 16, y: 131, w: 361, h: 273.4 },
  photosAi: { x: 33.2, y: 341.2, w: 326.6, h: 46 },
  sellCondition: { x: 16, y: 360, w: 361, h: 91 },
  sellPrice: { x: 16, y: 497, w: 361, h: 128 },
  sellApply: { x: 143, y: 758, w: 234, h: 48 },
  readyPrice: { x: 16, y: 500.4, w: 361, h: 73 },
  readySubmit: { x: 16, y: 746.4, w: 361, h: 50 },
  // 買家找書
  homeChat: { x: 338, y: 74, w: 30, h: 30 },
  homeRec: { x: 16, y: 356, w: 120, h: 270.6 },
  listAdvisor: { x: 16, y: 131, w: 361, h: 88 },
  advisorAsk: { x: 72.5, y: 129, w: 306.5, h: 62 },
  advisorAnswer: { x: 52, y: 201, w: 306.5, h: 191 },
  advisorPick: { x: 52, y: 400, w: 158, h: 208 },
  advisorBoth: { x: 52, y: 400, w: 326, h: 208 },
  // 書籍頁與聊天室
  detailChat: { x: 16, y: 758, w: 48, h: 48 },
  chatReserve: { x: 74.5, y: 436, w: 306.5, h: 238 },
  chatBuy: { x: 231.7, y: 622, w: 137.3, h: 40 },
  warnMsg: { x: 50, y: 590, w: 315, h: 108 },
  warnBanner: { x: 0, y: 115, w: 393, h: 70 },
  // 付款
  payDots: { x: 100.5, y: 450, w: 192, h: 16 },
  paySheet: { x: 0, y: 242, w: 393, h: 610 },
  payDone: { x: 28, y: 234.5, w: 337, h: 383 },
};

/** 上架書卡：上架段送出後停在此處，找書段由此飛進買家手機。 */
export const CARD_X = 1450;
export const CARD_Y = 760;
export const cardHtml = (state: string) =>
  `<i class="lcard__cover" style="background:${BOOK.cover}"><b>${BOOK.title}</b></i><p class="lcard__title">${BOOK.title}</p><p class="lcard__price">${BOOK.price} 代幣</p><p class="lcard__state">${state}</p>`;

/** 交易密碼鍵盤各數字的中心（App 邏輯座標），與輸入的 6 位數字。 */
export const KEYPAD: Record<number, [number, number]> = {
  1: [78.8, 540], 2: [196.5, 540], 3: [314.2, 540], 4: [78.8, 600], 5: [196.5, 600], 6: [314.2, 600],
  7: [78.8, 660], 8: [196.5, 660], 9: [314.2, 660], 0: [196.5, 720],
};
export const PIN = [0, 2, 2, 2, 2, 5];

/** 比對數字輸入格的中心（存書與取書的比對畫面相同）。 */
export const DIGITS: [number, number][] = [[162.5, 397], [230.5, 397]];

/** 前往書櫃長截圖（393×2414）：各卡片在長圖內的範圍。 */
export const GUIDE = {
  cabinet: { x: 20, y: 135, w: 353, h: 165 },
  mrt: { x: 20, y: 314, w: 353, h: 324 },
  bus: { x: 20, y: 652, w: 353, h: 448 },
  youbike: { x: 20, y: 1114, w: 353, h: 355 },
  drive: { x: 20, y: 1483, w: 353, h: 807 },
  banner: { x: 12, y: 56, w: 369, h: 90 },
};
export const ADMIN_R = {
  locBtn: { x: 20, y: 488, w: 171.5, h: 48 },
  coords: { x: 20, y: 318, w: 353, h: 158 },
  preview: { x: 20, y: 576, w: 353, h: 87 },
};
export const PICK = {
  ready: { x: 21.7, y: 630, w: 349.6, h: 104 },
};
export const WALLET = {
  entry: { x: 20, y: 628, w: 353, h: 94 },
  balance: { x: 150.2, y: 263, w: 92.5, h: 49 },
};
export const AFTER = {
  supAns: { x: 52, y: 249, w: 306.5, h: 135 },
  supHuman: { x: 52, y: 602, w: 306.5, h: 83 },
  dispute: { x: 20, y: 102, w: 353, h: 150 },
  disputeObs: { x: 33, y: 245, w: 330, h: 125 },
  consentTo: { x: 24, y: 568.2, w: 345, h: 99 },
};
