const DEFAULT_LOCALE = 'zh-Hant';

const LANGUAGES = {
  'zh-Hant': '繁體中文',
  'zh-Hans': '简体中文',
  en: 'English',
  ja: '日本語',
  ko: '한국어'
};

const ALIASES = new Map(Object.keys(LANGUAGES).map((tag) => [tag.toLowerCase(), tag]));

const normalize = (value) => (typeof value === 'string' ? ALIASES.get(value.trim().replace(/_/g, '-').toLowerCase()) ?? null : null);

// 與 App 的 lib/i18n/app_*.arb 同名條目一致（test/ai/ai-support-locale.js 會比對），App 改名時須一併更新。
const APP_TERMS = [
  ['orderPendingPayment', '待付款', { en: 'Awaiting payment', ja: '支払い待ち', ko: '결제 대기', 'zh-Hans': '待付款' }],
  ['orderPendingDeposit', '待存書', { en: 'Awaiting drop-off', ja: '預け入れ待ち', ko: '보관 대기', 'zh-Hans': '待存书' }],
  ['orderDeposited', '已存書', { en: 'Dropped off', ja: '預け入れ済み', ko: '보관 완료', 'zh-Hans': '已存书' }],
  ['orderPendingPickup', '待取書', { en: 'Ready for pickup', ja: '受け取り待ち', ko: '수령 대기', 'zh-Hans': '待取书' }],
  ['orderCompleted', '已完成', { en: 'Completed', ja: '完了', ko: '완료', 'zh-Hans': '已完成' }],
  ['orderCancelled', '已取消', { en: 'Cancelled', ja: 'キャンセル済み', ko: '취소됨', 'zh-Hans': '已取消' }],
  ['orderRefunding', '爭議處理中', { en: 'Under dispute', ja: '異議申立中', ko: '이의 제기 중', 'zh-Hans': '争议处理中' }],
  ['orderRefunded', '已退款', { en: 'Refunded', ja: '返金済み', ko: '환불 완료', 'zh-Hans': '已退款' }],
  ['orderBuyerPendingDeposit', '待賣家存書', { en: 'Waiting for seller drop-off', ja: '出品者の預け入れ待ち', ko: '판매자 보관 대기', 'zh-Hans': '待卖家存书' }],
  ['orderBuyerRefunding', '爭議處理中', { en: 'Under dispute', ja: '異議申立中', ko: '이의 제기 중', 'zh-Hans': '争议处理中' }],
  ['awaitingCompletion', '待完成訂單', { en: 'Awaiting completion', ja: '完了待ち', ko: '완료 대기', 'zh-Hans': '待完成订单' }],
  ['awaitingBuyerConfirmation', '待買家確認', { en: 'Awaiting buyer confirmation', ja: '購入者の確認待ち', ko: '구매자 확인 대기', 'zh-Hans': '待买家确认' }],
  ['completeOrder', '完成訂單', { en: 'Complete order', ja: '注文を完了', ko: '주문 완료', 'zh-Hans': '完成订单' }],
  ['cancelOrder', '取消訂單', { en: 'Cancel order', ja: '注文をキャンセル', ko: '주문 취소', 'zh-Hans': '取消订单' }],
  ['openDispute', '申請爭議', { en: 'Open a dispute', ja: '異議を申し立てる', ko: '이의 제기', 'zh-Hans': '申请争议' }],
  ['talkPerson', '轉接客服人員', { en: 'Contact a support agent', ja: 'サポート担当者に接続', ko: '상담원 연결', 'zh-Hans': '转接客服人员' }],
  ['helpCentre2', '客服中心', { en: 'Help centre', ja: 'サポートセンター', ko: '고객센터', 'zh-Hans': '客服中心' }],
  ['pendingPayouts', '待撥款項', { en: 'Pending payouts', ja: '保留中の収益', ko: '대기 중인 정산', 'zh-Hans': '待拨款项' }],
  ['purchases', '購買紀錄', { en: 'Purchases', ja: '購入履歴', ko: '구매 내역', 'zh-Hans': '购买记录' }],
  ['sales', '銷售紀錄', { en: 'Sales', ja: '販売履歴', ko: '판매 내역', 'zh-Hans': '销售记录' }],
  ['myBooks', '書籍管理', { en: 'My books', ja: '書籍管理', ko: '도서 관리', 'zh-Hans': '书籍管理' }],
  ['relist', '重新上架', { en: 'Relist', ja: '再出品', ko: '다시 올리기', 'zh-Hans': '重新上架' }],
  ['paymentPin', '交易密碼', { en: 'Payment PIN', ja: '取引パスワード', ko: '결제 비밀번호', 'zh-Hans': '交易密码' }],
  ['membershipTier', '會員等級', { en: 'Membership tier', ja: '会員ランク', ko: '회원 등급', 'zh-Hans': '会员等级' }],
  ['faqCatWallet', '代幣', { en: 'Coins', ja: 'コイン', ko: '코인', 'zh-Hans': '代币' }],
  ['faqCatCabinet', '書櫃', { en: 'Lockers', ja: 'ロッカー', ko: '보관함', 'zh-Hans': '书柜' }],
  ['scanLockerCollect', '掃描書櫃取書', { en: 'Scan to collect', ja: 'スキャンして受取', ko: '스캔 후 수령', 'zh-Hans': '扫描书柜取书' }],
  ['scanLockerDropOff', '掃描書櫃存書', { en: 'Scan to drop off', ja: 'スキャンして預入', ko: '스캔 후 보관', 'zh-Hans': '扫描书柜存书' }],
  ['scanLockerRetrieve', '掃描書櫃取回', { en: 'Scan to retrieve', ja: 'スキャンして回収', ko: '스캔 후 회수', 'zh-Hans': '扫描书柜取回' }],
  ['preSaleDropOff', '先行存書', { en: 'Pre-sale drop-off', ja: '販売前の預け入れ', ko: '판매 전 보관', 'zh-Hans': '先行存书' }],
  ['openDoor', '開啟櫃門', { en: 'Open door', ja: '扉を開ける', ko: '문 열기', 'zh-Hans': '开启柜门' }],
  ['closeDoorFirst', '請先關上櫃門', { en: 'Close the door first', ja: '先に扉を閉めてください', ko: '먼저 문을 닫아 주세요', 'zh-Hans': '请先关上柜门' }],
  ['reportManually', '改為手動回報', { en: 'Report manually', ja: '手動で報告', ko: '수동으로 보고', 'zh-Hans': '改为手动回报' }]
];

const GUARDED_REPLIES = {
  'zh-Hant': '此問題需由客服人員協助處理，請轉接客服人員。',
  'zh-Hans': '此问题需由客服人员协助处理，请转接客服人员。',
  en: 'This question requires assistance from a support agent. Please contact a support agent.',
  ja: 'このご質問はサポート担当者による対応が必要です。サポート担当者にお問い合わせください。',
  ko: '이 문의는 상담원의 도움이 필요합니다. 상담원에게 연결해 주세요.'
};

const FALLBACK_LEADS = {
  'zh-Hant': '以下是相關說明：',
  'zh-Hans': '以下是相关说明：',
  en: 'Related information:',
  ja: '関連する説明は以下のとおりです：',
  ko: '관련 안내는 다음과 같습니다:'
};

const resolve = (locale) => normalize(locale) ?? DEFAULT_LOCALE;

const promptSection = (locale) => {
  const tag = resolve(locale);
  const lines = [`【回覆語言】${LANGUAGES[tag]}`];
  if (tag !== DEFAULT_LOCALE) {
    lines.push(`【介面用語】\n${APP_TERMS.map(([, zh, names]) => `${zh} → ${names[tag]}`).join('\n')}`);
  }
  return lines.join('\n\n');
};

const guardedReply = (locale) => GUARDED_REPLIES[resolve(locale)];

const fallbackLead = (locale) => FALLBACK_LEADS[resolve(locale)];

module.exports = { DEFAULT_LOCALE, LANGUAGES, APP_TERMS, GUARDED_REPLIES, FALLBACK_LEADS, normalize, resolve, promptSection, guardedReply, fallbackLead };
