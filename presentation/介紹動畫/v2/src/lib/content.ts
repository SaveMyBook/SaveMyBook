/** 書架示意用的書目皆為虛構，封面由網站自行繪製。 */
export interface ShelfBook { title: string; author: string; color: string; band?: string; text?: string; w: number; h: number; reason: string }

export const SHELF: ShelfBook[] = [
  { title: '統計學概論', author: '林志明 著', color: '#5E8068', w: 136, h: 194, reason: '與您收藏的《資料分析入門》同屬統計方法，可銜接閱讀。' },
  { title: '資料結構與演算法', author: '陳怡安 著', color: '#3B505C', w: 128, h: 206, reason: '與您近期瀏覽的程式設計書籍主題相近。' },
  { title: '會計學原理', author: '王承佑 著', color: '#A8735F', w: 140, h: 188, reason: '與購物車中的《經濟學》同為商管基礎課程用書。' },
  { title: '經濟學', author: '黃韻如 著', color: '#6F87A8', w: 132, h: 198, reason: '同校商學院賣家上架，書況為近全新。' },
  { title: '普通心理學', author: '張舒涵 著', color: '#8A7FA0', w: 126, h: 186, reason: '與您收藏的《社會心理學》作者相同。' },
  { title: '臺灣近代文學選讀', author: '吳庭瑜 編', color: '#7E8C6A', w: 122, h: 200, reason: '與您瀏覽過的文學選集屬同一系列。' },
  { title: '微積分', author: '李冠廷 著', color: '#9A876A', w: 144, h: 204, reason: '書況良好且已存放於書櫃，下單後即可取書。' },
  { title: '設計思考實務', author: '周品妍 著', color: '#B08680', w: 130, h: 190, reason: '與您收藏的《使用者經驗設計》主題相關。' },
  { title: 'Python 程式設計入門', author: '鄭宇翔 著', color: '#4E6674', w: 134, h: 196, reason: '符合您設定的預算，且為初學者適用版本。' },
  { title: '日語文法入門', author: '高橋美咲 著', color: '#C29B6C', text: '#2B3640', band: 'rgba(43,54,64,.12)', w: 120, h: 184, reason: '與您收藏的語言學習書籍難度相近。' },
];

const icon = (d: string) => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${d}</svg>`;

export const AI_FEATURES = [
  { name: '上架輔助', note: '依 ISBN 查詢書目，附建議售價與資料來源', icon: icon('<rect x="3" y="7" width="18" height="13" rx="2.5"/><path d="M8.5 7l1.6-2.5h3.8L15.5 7"/><circle cx="12" cy="13.5" r="3.4"/>') },
  { name: '上架審核', note: '規則攔截售價異常，AI 判讀照片', icon: icon('<path d="M12 3l7.5 3v5.6c0 4.6-3.2 8.2-7.5 9.4-4.3-1.2-7.5-4.8-7.5-9.4V6z"/><path d="M8.6 12.2l2.4 2.4 4.5-4.6"/>') },
  { name: '資料補齊', note: '背景依 ISBN 整理繁體中文簡介', icon: icon('<path d="M6 3h8.5L19 7.5V21H6z"/><path d="M14 3v5h5"/><path d="M9 12.5h7M9 16h5"/>') },
  { name: '個人化推薦', note: '以語意向量找出相近書籍並寫下理由', icon: icon('<path d="M7 3.5h10a1 1 0 0 1 1 1V21l-6-3.8L6 21V4.5a1 1 0 0 1 1-1z"/><path d="M12 7.2l1.1 2.2 2.4.3-1.8 1.7.5 2.4-2.2-1.2-2.2 1.2.5-2.4-1.8-1.7 2.4-.3z"/>') },
  { name: 'AI 書籍顧問', note: '理解需求，只推薦站內可購買的書', icon: icon('<path d="M4 5.5A2.5 2.5 0 0 1 6.5 3h11A2.5 2.5 0 0 1 20 5.5v8a2.5 2.5 0 0 1-2.5 2.5H10l-4.5 4v-4H6.5A2.5 2.5 0 0 1 4 13.5z"/><path d="M12 6.5v6M9 9.5h6"/>') },
  { name: 'AI 客服', note: '混合檢索作答，可一鍵轉接客服人員', icon: icon('<path d="M4.5 14v-2a7.5 7.5 0 0 1 15 0v2"/><rect x="3" y="13" width="4" height="6" rx="1.5"/><rect x="17" y="13" width="4" height="6" rx="1.5"/><path d="M19 19c0 1.4-1.6 2.2-4 2.2h-2"/>') },
  { name: '爭議分析', note: '比對證據整理摘要，僅供管理員參考', icon: icon('<path d="M12 4v16M7 20h10"/><path d="M5 7h14"/><path d="M5 7l-2.5 6a2.8 2.8 0 0 0 5 0z"/><path d="M19 7l-2.5 6a2.8 2.8 0 0 0 5 0z"/>') },
];
