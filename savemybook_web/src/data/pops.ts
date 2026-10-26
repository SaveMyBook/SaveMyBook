// 由 scripts/pops.mjs 產生，請勿手動修改
export const POPS = {
  notice: { src: '/pops/notice@3x.webp', srcset: '/pops/notice@1x.webp 360w, /pops/notice@2x.webp 721w, /pops/notice@3x.webp 1081w', screen: 'notifications', x: 16.33, y: 226.33, w: 360.33, h: 136.33, r: 16, slot: '#F3F5F7' },
  price: { src: '/pops/price@3x.webp', srcset: '/pops/price@1x.webp 361w, /pops/price@2x.webp 722w, /pops/price@3x.webp 1083w', screen: 'sell_price', x: 16, y: 514, w: 361, h: 111, r: 12, slot: '#FFFFFF' },
  advisor: { src: '/pops/advisor@3x.webp', srcset: '/pops/advisor@1x.webp 156w, /pops/advisor@2x.webp 312w, /pops/advisor@3x.webp 468w', screen: 'ai_chat', x: 53, y: 378, w: 156, h: 206, r: 12, slot: '#F3F5F7' },
  banner: { src: '/pops/banner@3x.webp', srcset: '/pops/banner@1x.webp 393w, /pops/banner@2x.webp 786w, /pops/banner@3x.webp 1179w', screen: 'chat_room', x: 0, y: 116, w: 393, h: 68, r: 0, slot: '#F3F5F7' },
  progress: { src: '/pops/progress@3x.webp', srcset: '/pops/progress@1x.webp 353w, /pops/progress@2x.webp 706w, /pops/progress@3x.webp 1059w', screen: 'order_detail', x: 20, y: 227, w: 353, h: 252, r: 16, slot: '#F3F5F7' },
} as const;

export type PopKey = keyof typeof POPS;
