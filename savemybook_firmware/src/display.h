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

// 配色與模擬書櫃 kiosk.js 相同。
namespace color {
constexpr uint16_t BG = rgb(0x0e1318);
constexpr uint16_t HEADER = rgb(0x18212a);
constexpr uint16_t TEXT = rgb(0xeef2f5);
constexpr uint16_t MUTED = rgb(0x93a2ad);
constexpr uint16_t TRACK = rgb(0x2a3540);
constexpr uint16_t ONLINE = rgb(0x3ccf8e);
constexpr uint16_t OFFLINE = rgb(0x66737d);
constexpr uint16_t ACCENT = rgb(0x46b59c);
constexpr uint16_t WARN = rgb(0xf0b429);
constexpr uint16_t DANGER = rgb(0xe0685c);
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
  void qr(const std::vector<uint8_t> &modules, int n, int x, int y, int scale);

 private:
  void put(int x, int y, uint16_t c);
  void blend(int x, int y, uint16_t c, int alpha);
  uint16_t *buf_;
  int y0_, h_;
};

int textWidth(const smb_font_t &f, const std::string &s);
std::vector<std::string> wrapText(const smb_font_t &f, const std::string &s, int maxWidth);

void display_init();
// 依段呼叫 draw 繪製整個畫面，只把內容有變的段送到螢幕。
void display_frame(const std::function<void(Canvas &)> &draw);

}  // namespace smb
