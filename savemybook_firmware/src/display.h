#pragma once

#include <cstdint>
#include <functional>
#include <string>
#include <vector>

#include "fonts.h"

namespace smb {

constexpr int SCREEN_W = 320;
constexpr int SCREEN_H = 240;

constexpr uint16_t rgb(uint32_t hex) {
  return ((hex >> 8) & 0xF800) | ((hex >> 5) & 0x07E0) | ((hex >> 3) & 0x001F);
}

// 依 t（0–255）由 a 混合到 b，用來調出淡色底。
constexpr uint16_t mix(uint16_t a, uint16_t b, int t) {
  return static_cast<uint16_t>(((((a >> 11) * (255 - t) + (b >> 11) * t) / 255) << 11) |
                               (((((a >> 5) & 0x3F) * (255 - t) + ((b >> 5) & 0x3F) * t) / 255) << 5) |
                               (((a & 0x1F) * (255 - t) + (b & 0x1F) * t) / 255));
}

// 配色與模擬書櫃 kiosk.js 相同：亮色系，淺灰底、白色卡片。
namespace color {
constexpr uint16_t BG = rgb(0xeff3f7);      // 轉成 RGB565 後仍是中性冷灰（不偏紫）
constexpr uint16_t HEADER = rgb(0xe6e9ed);  // 硬體測試畫面的標題列
constexpr uint16_t CARD = rgb(0xffffff);
constexpr uint16_t SHADOW = rgb(0x1c2a35);
constexpr uint16_t LINE = rgb(0xd9dce1);  // 分隔線、格子外框
constexpr uint16_t TEXT = rgb(0x1d1d1f);
constexpr uint16_t MUTED = rgb(0x6e6e73);
constexpr uint16_t TRACK = rgb(0xe1e4e8);
constexpr uint16_t OFFLINE = rgb(0xa8a8ad);
constexpr uint16_t ACCENT = rgb(0x12a083);
constexpr uint16_t INFO = rgb(0x557a91);  // 品牌石板藍，用於非營業、維修等一般狀態
constexpr uint16_t WARN = rgb(0xf09000);
constexpr uint16_t DANGER = rgb(0xe5483d);
constexpr uint16_t WHITE = 0xFFFF;
constexpr uint16_t BLACK = 0x0000;
}  // namespace color

enum class Align { Left, Center, Right };

// 一段畫面（全寬、y0 起 h 列）。繪圖指令以整個螢幕座標下達，超出本段的部分自動略過。
class Canvas {
 public:
  Canvas(uint16_t *buf, int y0, int h) : buf_(buf), y0_(y0), h_(h) {}
  void fill(uint16_t c);
  void rect(int x, int y, int w, int h, uint16_t c);
  // cy 為文字的視覺中線。
  void text(const smb_font_t &f, const std::string &s, int x, int cy, uint16_t c, Align a = Align::Left);
  void ring(int cx, int cy, int r, int thick, float ratio, uint16_t fg, uint16_t track);
  void disc(int cx, int cy, int r, uint16_t c);
  void circle(int cx, int cy, int r, int thick, uint16_t c);
  void line(float x0, float y0, float x1, float y1, float thick, uint16_t c);
  // 含 4 格靜區；modules 為 n×n，非 0 為深色。
  void qr(const std::vector<uint8_t> &modules, int n, int x, int y, int scale, bool background = true);
  // 全寬垂直漸層（24 位元色），以 4×4 有序抖色避免 RGB565 的色帶。
  void vgradient(int y, int h, uint32_t topHex, uint32_t bottomHex);
  // 圓角矩形，邊緣抗鋸齒；stroke 大於 0 時只畫向內 stroke 像素寬的外框。
  void roundRect(int x, int y, int w, int h, float r, uint16_t c, float stroke = 0);
  // 圓頭弧線，from、to 為圈數（0 在正上方，順時針）。
  void arc(float cx, float cy, float r, float thick, float from, float to, uint16_t c);
  // RGB565 點陣加 8 位元透明度。
  void image(const uint16_t *rgb, const uint8_t *alpha, int w, int h, int x, int y);
  // 只用 8 位元透明度、以單一顏色繪製（例如把標誌畫成白色剪影）。
  void mask(const uint8_t *alpha, int w, int h, int x, int y, uint16_t c);
  // 圓角矩形下方的柔和陰影（先畫陰影再畫卡片）：向外 blur 像素淡出，dy 為向下位移，alpha 為最深處的不透明度。
  void shadow(int x, int y, int w, int h, float r, float blur, float dy, int alpha);
  // 內容整體下移 dy 像素的畫布（轉場時新畫面由下往上滑入）。
  Canvas shifted(int dy) const { return Canvas(buf_, y0_ - dy, h_); }
  // 從整張畫面快取（display_alloc_frame）複製本段（maxY 以下不複製）。dy 大於 0 時 splitY 以下的內容下移 dy 像素，
  // 移出的空缺改取 fallback 的同一列（例如只有背景的畫面）。
  void blit(const uint16_t *frame, const uint16_t *fallback = nullptr, int dy = 0, int splitY = 0, int maxY = SCREEN_H);

 private:
  void put(int x, int y, uint16_t c);
  void blend(int x, int y, uint16_t c, int alpha);
  // 以 8 位元計算混色後加有序抖色再轉回 RGB565，陰影這類緩慢漸層才不會出現色階。
  void blendDither(int x, int y, uint16_t c, int alpha);
  uint16_t *buf_;
  int y0_, h_;
};

int textWidth(const smb_font_t &f, const std::string &s);
std::vector<std::string> wrapText(const smb_font_t &f, const std::string &s, int maxWidth);

// 兩張同一段的畫面依 a（0–255，對應 under 的比例）混合，結果寫回 dst；像素為送往螢幕的位元組順序。
void blend_band(uint16_t *dst, const uint16_t *under, int count, int a);

// 整張畫面大小的緩衝（送往螢幕的位元組順序），放在 PSRAM；配置失敗時回傳 nullptr。
uint16_t *display_alloc_frame();

void display_init();
// 電磁鎖通斷的突波可能讓螢幕重置成白畫面：呼叫後下一次畫面更新會重送設定並整面重畫。
void display_recover();
// 背光亮度 10–100%（LED 腳接 PIN_TFT_BL）。
void display_set_brightness(int percent);
// 依段呼叫 draw 繪製整個畫面，只把內容有變的段送到螢幕。轉場時另以 under 畫出舊畫面，依 underAlpha 疊在上面。
// fromY、toY 限定只重畫與這個範圍重疊的段（其他段螢幕上已是正確內容）；需要整面重送時會忽略。
// compare 為 false 時不比對內容、每段都送（轉場時每段都在變，省下雜湊計算）。
void display_frame(const std::function<void(Canvas &)> &draw, const std::function<void(Canvas &)> &under = nullptr,
                   int underAlpha = 0, int fromY = 0, int toY = SCREEN_H, bool compare = true);

// 記錄期間實際寫入像素的列範圍（只算 blend、put、rect 與圓角矩形的整列填色），用來找出會動的元件在哪幾列。
void canvas_track_begin();
// 沒有寫入任何像素時 y0 大於 y1。
void canvas_track_end(int &y0, int &y1);

}  // namespace smb
