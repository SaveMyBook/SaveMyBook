/**
 * v3（NTUB_SIS 宣傳片風格）的固定數值：字級、顏色、安全範圍、浮出與轉場。各段一律引用這裡，不要在場景裡另寫數字。
 * 規則說明見 DESIGN.md「v3 規則」。座標為 1920×1080（4K 輸出時整體放大兩倍）。
 */
export const V3 = {
  font: `'PingFang TC', -apple-system, 'Noto Sans TC', sans-serif`,
  color: {
    ink: '#1D1D1F',
    sub: '#4D626F',
    accent: '#627D8D',
    bgTop: '#FFFFFF',
    bgBottom: '#DFE6EA',
  },
  title: {
    /** 第一行上緣 */
    top: 44,
    /** 大標 60px（4K 120px）、行高 1.27；副標 27px（4K 54px）、字重 500 */
    size: 60,
    lineH: 60 * 1.27,
    sub: 27,
    subLineH: 27 * 1.3,
    subGap: 10,
    /** 進場：整塊由下 40px 上移並淡入；離場：再上移 40px 並淡出 */
    lift: 40,
    inDur: 0.55,
    outDur: 0.4,
  },
  /** 物件旁的名稱標籤（LabelV3）：36px（4K 72px）、字重 600、距物件外框 40px */
  label: { size: 36, gap: 40 },
  subtitle: {
    size: 32,
    weight: 500,
    /** 字幕帶：y ≥ bandTop 只留給字幕，手機、書櫃、浮出元件都不得進入 */
    bandTop: 976,
    /** 字幕單行的垂直中心 */
    centerY: 1028,
  },
  safe: {
    /** 浮出元件距畫面邊緣 */
    margin: 56,
    /** 手機、書櫃、浮出元件距標題文字 */
    titleGap: 40,
  },
  pop: {
    /** 浮出 0.5 秒、完全浮出至少停 1.5 秒、落回 0.35 秒 */
    rise: 0.5,
    hold: 1.5,
    fall: 0.35,
    /** 手機去背元件的預設放大量（NTUB PopStyle grow 1.06–1.4） */
    grow: 0.18,
    /** 書櫃螢幕浮出的放大倍率範圍 */
    kioskScale: [1.6, 2.2],
  },
  trans: {
    move: 0.95,
    whip: 0.5,
  },
} as const;

/** 標題區塊（兩行大標＋副標）的下緣 */
export const TITLE_BOTTOM = V3.title.top + 2 * V3.title.lineH + V3.title.subGap + V3.title.subLineH;
/** 手機、書櫃可用的垂直範圍：標題下方 40px 到字幕帶上緣（與標題左右錯開時可以更高） */
export const SUBJECT_TOP = TITLE_BOTTOM + V3.safe.titleGap;
export const SUBJECT_BOTTOM = V3.subtitle.bandTop;

/** 蘋方的 ASCII 連字號是 0.6 字寬的減號造形（ESP32-S3 會像 ESP32–S3），畫面文字中字與字之間的連字號改用 U+2010（0.33 字寬） */
export const hyphen = (s: string) => s.replace(/(?<=\w)-(?=\w)/g, '‐');
