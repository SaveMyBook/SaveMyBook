#include <algorithm>
#include <cmath>
#include <cstring>

#include "display.h"

// 與硬體無關的繪圖：字型、斷行與基本圖形，也用於電腦上的畫面預覽（tools/preview）。

namespace smb {

// ---------- UTF-8 與字型 ----------

static bool nextCodepoint(const std::string &s, size_t &i, uint32_t &cp) {
  if (i >= s.size()) return false;
  const auto c = static_cast<uint8_t>(s[i]);
  const int extra = c < 0x80 ? 0 : (c >> 5) == 0x6 ? 1 : (c >> 4) == 0xE ? 2 : (c >> 3) == 0x1E ? 3 : -1;
  if (extra < 0 || i + extra >= s.size() + (extra == 0 ? 1 : 0)) {
    i += 1;
    cp = '?';
    return true;
  }
  cp = extra == 0 ? c : extra == 1 ? (c & 0x1F) : extra == 2 ? (c & 0x0F) : (c & 0x07);
  for (int k = 1; k <= extra; k++) cp = (cp << 6) | (static_cast<uint8_t>(s[i + k]) & 0x3F);
  i += extra + 1;
  return true;
}

static const smb_glyph_t *glyphOf(const smb_font_t &f, uint32_t cp) {
  int lo = 0, hi = f.count - 1;
  while (lo <= hi) {
    int mid = (lo + hi) / 2;
    if (f.glyphs[mid].cp == cp) return &f.glyphs[mid];
    if (f.glyphs[mid].cp < cp) lo = mid + 1;
    else hi = mid - 1;
  }
  return nullptr;
}

static int advanceOf(const smb_font_t &f, uint32_t cp) {
  const smb_glyph_t *g = glyphOf(f, cp);
  return g ? g->adv : f.size / 2;
}

int textWidth(const smb_font_t &f, const std::string &s) {
  int w = 0;
  size_t i = 0;
  uint32_t cp;
  while (nextCodepoint(s, i, cp)) w += advanceOf(f, cp);
  return w;
}

// 不可出現在行首、行尾的標點。
static bool noLineStart(uint32_t cp) {
  static const char32_t set[] = U"，。、：；！？）」』》…,.:;!?)";
  for (char32_t c : set) if (c && c == cp) return true;
  return false;
}
static bool noLineEnd(uint32_t cp) { return cp == U'（' || cp == U'「' || cp == U'『' || cp == U'《' || cp == U'('; }
static bool isWordChar(uint32_t cp) { return cp < 0x80 && cp != ' '; }
static bool endsWithWordChar(const std::string &t) {
  return !t.empty() && static_cast<uint8_t>(t.back()) < 0x80 && t.back() != ' ';
}

std::vector<std::string> wrapText(const smb_font_t &f, const std::string &s, int maxWidth) {
  // 英數字連成一個單位，中文字與標點各自一個單位；行首標點併入前一個單位。
  std::vector<std::string> tokens;
  bool joinNext = false;
  size_t i = 0;
  uint32_t cp;
  while (true) {
    size_t start = i;
    if (!nextCodepoint(s, i, cp)) break;
    std::string piece = s.substr(start, i - start);
    if (cp == ' ') {
      tokens.push_back(" ");
      joinNext = false;
      continue;
    }
    const bool attach = !tokens.empty() && tokens.back() != " " &&
                        (joinNext || noLineStart(cp) || (isWordChar(cp) && endsWithWordChar(tokens.back())));
    if (attach) tokens.back() += piece;
    else tokens.push_back(piece);
    joinNext = noLineEnd(cp);
  }

  std::vector<std::string> lines;
  std::string line;
  for (const std::string &t : tokens) {
    if (t == " " && line.empty()) continue;
    if (!line.empty() && textWidth(f, line + t) > maxWidth) {
      while (!line.empty() && line.back() == ' ') line.pop_back();
      lines.push_back(line);
      line = t == " " ? "" : t;
    } else {
      line += t;
    }
  }
  while (!line.empty() && line.back() == ' ') line.pop_back();
  if (!line.empty()) lines.push_back(line);
  return lines;
}

// ---------- 繪圖 ----------

static bool s_tracking = false;
static int s_trackY0, s_trackY1;
static inline void track(int y0, int y1) {
  if (!s_tracking) return;
  s_trackY0 = std::min(s_trackY0, y0);
  s_trackY1 = std::max(s_trackY1, y1);
}
void canvas_track_begin() {
  s_tracking = true;
  s_trackY0 = SCREEN_H;
  s_trackY1 = -1;
}
void canvas_track_end(int &y0, int &y1) {
  s_tracking = false;
  y0 = s_trackY0;
  y1 = s_trackY1;
}

static inline uint16_t swap16(uint16_t v) { return static_cast<uint16_t>((v << 8) | (v >> 8)); }
// x / 255：x 在 0–65534 內與整數除法相同，更大時最多差 1（抖色以 1/16 階計算，可忽略）。ESP32 的整數除法很慢，混色每個像素要做好幾次
static inline int div255(int x) { return (x + 1 + (x >> 8)) >> 8; }

void Canvas::put(int x, int y, uint16_t c) {
  if (x < 0 || x >= SCREEN_W || y < y0_ || y >= y0_ + h_) return;
  track(y, y);
  buf_[(y - y0_) * SCREEN_W + x] = swap16(c);
}

void Canvas::blend(int x, int y, uint16_t c, int a) {
  if (a <= 0 || x < 0 || x >= SCREEN_W || y < y0_ || y >= y0_ + h_) return;
  track(y, y);
  uint16_t &px = buf_[(y - y0_) * SCREEN_W + x];
  if (a >= 255) {
    px = swap16(c);
    return;
  }
  uint16_t d = swap16(px);
  int r = div255((c >> 11) * a + (d >> 11) * (255 - a));
  int g = div255(((c >> 5) & 0x3F) * a + ((d >> 5) & 0x3F) * (255 - a));
  int b = div255((c & 0x1F) * a + (d & 0x1F) * (255 - a));
  px = swap16(static_cast<uint16_t>((r << 11) | (g << 5) | b));
}

static const uint8_t BAYER[4][4] = {{0, 8, 2, 10}, {12, 4, 14, 6}, {3, 11, 1, 9}, {15, 7, 13, 5}};

void Canvas::blendDither(int x, int y, uint16_t c, int a) {
  if (a <= 0 || x < 0 || x >= SCREEN_W || y < y0_ || y >= y0_ + h_) return;
  track(y, y);
  uint16_t &px = buf_[(y - y0_) * SCREEN_W + x];
  const uint16_t d = swap16(px);
  const int t = BAYER[y & 3][x & 3];
  // 各通道以 1/16 階為單位混色，再依抖色門檻進位
  auto ch = [&](int src, int dst, int levels) {
    const int v = div255(src * 16 * a + dst * 16 * (255 - a));
    return std::min(levels, (v + t) >> 4);
  };
  const int r = ch(c >> 11, d >> 11, 31), g = ch((c >> 5) & 0x3F, (d >> 5) & 0x3F, 63), b = ch(c & 0x1F, d & 0x1F, 31);
  px = swap16(static_cast<uint16_t>((r << 11) | (g << 5) | b));
}

void Canvas::fill(uint16_t c) {
  const uint16_t v = swap16(c);
  std::fill(buf_, buf_ + SCREEN_W * h_, v);
}

void Canvas::rect(int x, int y, int w, int h, uint16_t c) {
  const int x0 = std::max(0, x), x1 = std::min(SCREEN_W, x + w);
  const int ya = std::max(y0_, y), yb = std::min(y0_ + h_, y + h);
  if (x0 >= x1 || ya >= yb) return;
  track(ya, yb - 1);
  const uint16_t v = swap16(c);
  for (int yy = ya; yy < yb; yy++) std::fill(buf_ + (yy - y0_) * SCREEN_W + x0, buf_ + (yy - y0_) * SCREEN_W + x1, v);
}

void Canvas::text(const smb_font_t &f, const std::string &s, int x, int cy, uint16_t c, Align a) {
  // 中文字與數字的視覺中心約在基線上方 0.38 字高。
  const int baseline = cy + static_cast<int>(std::lround(f.size * 0.38));
  if (baseline - f.ascent > y0_ + h_ || baseline + f.descent < y0_) return;
  int pen = x;
  if (a != Align::Left) {
    const int w = textWidth(f, s);
    pen -= a == Align::Center ? w / 2 : w;
  }
  size_t i = 0;
  uint32_t cp;
  while (nextCodepoint(s, i, cp)) {
    const smb_glyph_t *g = glyphOf(f, cp);
    if (!g) {
      pen += f.size / 2;
      continue;
    }
    const int top = baseline + g->dy;
    for (int row = 0; row < g->h; row++) {
      const int yy = top + row;
      if (yy < y0_ || yy >= y0_ + h_) continue;
      const uint8_t *src = f.bitmap + g->off + row * g->w;
      for (int col = 0; col < g->w; col++) blend(pen + g->dx + col, yy, c, src[col]);
    }
    pen += g->adv;
  }
}

static inline int coverage(float v) { return static_cast<int>(std::clamp(v, 0.0f, 1.0f) * 255.0f); }

void Canvas::ring(int cx, int cy, int r, int thick, float ratio, uint16_t fg, uint16_t track) {
  const float ro = r + thick / 2.0f, ri = r - thick / 2.0f;
  const int ya = std::max(y0_, cy - static_cast<int>(ro) - 1), yb = std::min(y0_ + h_, cy + static_cast<int>(ro) + 2);
  for (int y = ya; y < yb; y++) {
    for (int x = cx - static_cast<int>(ro) - 1; x <= cx + static_cast<int>(ro) + 1; x++) {
      const float dx = x + 0.5f - cx, dy = y + 0.5f - cy;
      const float d = std::sqrt(dx * dx + dy * dy);
      const int a = std::min(coverage(ro - d + 0.5f), coverage(d - ri + 0.5f));
      if (!a) continue;
      float angle = std::atan2(dx, -dy);
      if (angle < 0) angle += 2.0f * static_cast<float>(M_PI);
      blend(x, y, angle / (2.0f * static_cast<float>(M_PI)) < ratio ? fg : track, a);
    }
  }
}

void Canvas::disc(int cx, int cy, int r, uint16_t c) {
  const float inner = (r - 0.5f) * (r - 0.5f), outer = (r + 0.5f) * (r + 0.5f);
  for (int y = std::max(y0_, cy - r - 1); y < std::min(y0_ + h_, cy + r + 2); y++)
    for (int x = cx - r - 1; x <= cx + r + 1; x++) {
      const float dx = x + 0.5f - cx, dy = y + 0.5f - cy, d2 = dx * dx + dy * dy;
      if (d2 >= outer) continue;
      blend(x, y, c, d2 <= inner ? 255 : coverage(r - std::sqrt(d2) + 0.5f));
    }
}

void Canvas::circle(int cx, int cy, int r, int thick, uint16_t c) { ring(cx, cy, r, thick, 1.0f, c, c); }

void Canvas::line(float x0, float y0, float x1, float y1, float thick, uint16_t c) {
  const float half = thick / 2.0f;
  const float vx = x1 - x0, vy = y1 - y0, len2 = vx * vx + vy * vy;
  const int xa = static_cast<int>(std::min(x0, x1) - half - 1), xb = static_cast<int>(std::max(x0, x1) + half + 1);
  const int ya = std::max(y0_, static_cast<int>(std::min(y0, y1) - half - 1));
  const int yb = std::min(y0_ + h_, static_cast<int>(std::max(y0, y1) + half + 2));
  for (int y = ya; y < yb; y++)
    for (int x = xa; x <= xb; x++) {
      const float px = x + 0.5f - x0, py = y + 0.5f - y0;
      const float t = len2 > 0 ? std::clamp((px * vx + py * vy) / len2, 0.0f, 1.0f) : 0.0f;
      const float ex = px - t * vx, ey = py - t * vy;
      blend(x, y, c, coverage(half - std::sqrt(ex * ex + ey * ey) + 0.5f));
    }
}

void Canvas::vgradient(int y, int h, uint32_t topHex, uint32_t bottomHex) {
  const int ya = std::max(y0_, y), yb = std::min(y0_ + h_, y + h);
  for (int yy = ya; yy < yb; yy++) {
    const int t = h > 1 ? (yy - y) * 256 / (h - 1) : 0;
    auto channel = [&](int shift, int levels) {
      const int a = (topHex >> shift) & 0xFF, b = (bottomHex >> shift) & 0xFF;
      return (a + (((b - a) * t) >> 8)) * levels * 16 / 255;  // 以 1/16 階為單位
    };
    const int r16 = channel(16, 31), g16 = channel(8, 63), b16 = channel(0, 31);
    uint16_t pattern[4];
    for (int k = 0; k < 4; k++) {
      const int d = BAYER[yy & 3][k];
      pattern[k] = swap16(static_cast<uint16_t>((std::min(31, (r16 + d) >> 4) << 11) | (std::min(63, (g16 + d) >> 4) << 5) |
                                                std::min(31, (b16 + d) >> 4)));
    }
    uint16_t *row = buf_ + (yy - y0_) * SCREEN_W;
    for (int x = 0; x < SCREEN_W; x++) row[x] = pattern[x & 3];
  }
}

// 圓角矩形的有號距離（負值在內側），q 為到中心的距離減去直線段的一半。
static inline float roundBoxDist(float qx, float qy, float r) {
  return (qx > 0 && qy > 0 ? std::sqrt(qx * qx + qy * qy) : std::max(qx, qy)) - r;
}

void Canvas::roundRect(int x, int y, int w, int h, float r, uint16_t c, float stroke) {
  r = std::min(r, std::min(w, h) / 2.0f);
  const float cx = x + w / 2.0f, cy = y + h / 2.0f, hw = w / 2.0f - r, hh = h / 2.0f - r;
  const int ya = std::max(y0_, y), yb = std::min(y0_ + h_, y + h);
  const int xa = std::max(0, x), xb = std::min(SCREEN_W, x + w);
  if (xa >= xb) return;
  const uint16_t sc = swap16(c);
  // 圓角佔的欄數：中間各欄的距離只取決於列，一列算一次
  const int corner = static_cast<int>(std::ceil(r)) + 1;
  const int midA = std::max(xa, x + corner), midB = std::min(xb, x + w - corner);
  auto coverageAt = [&](float d) {
    return stroke > 0 ? coverage(0.5f - d) - coverage(0.5f - d - stroke) : coverage(0.5f - d);
  };
  for (int yy = ya; yy < yb; yy++) {
    const float qy = std::fabs(yy + 0.5f - cy) - hh;
    uint16_t *row = buf_ + (yy - y0_) * SCREEN_W;
    if (qy <= 0 && stroke <= 0) {
      std::fill(row + xa, row + xb, sc);  // 直線段：整列都在內側
      track(yy, yy);
      continue;
    }
    auto px = [&](int xx) { blend(xx, yy, c, coverageAt(roundBoxDist(std::fabs(xx + 0.5f - cx) - hw, qy, r))); };
    if (midA >= midB) {
      for (int xx = xa; xx < xb; xx++) px(xx);
      continue;
    }
    for (int xx = xa; xx < midA; xx++) px(xx);
    for (int xx = midB; xx < xb; xx++) px(xx);
    // 中段：上下邊緣或外框的直線部分，整段同一個覆蓋率
    const int a = coverageAt(qy - r);
    if (a >= 255) {
      std::fill(row + midA, row + midB, sc);
      track(yy, yy);
    } else if (a > 0)
      for (int xx = midA; xx < midB; xx++) blend(xx, yy, c, a);
  }
}

void Canvas::shadow(int x, int y, int w, int h, float r, float blur, float dy, int alpha) {
  r = std::min(r, std::min(w, h) / 2.0f);
  const float cx = x + w / 2.0f, cy = y + h / 2.0f + dy, hw = w / 2.0f - r, hh = h / 2.0f - r;
  const int ext = static_cast<int>(std::ceil(blur));
  const int ya = std::max(y0_, static_cast<int>(y + dy) - ext), yb = std::min(y0_ + h_, static_cast<int>(y + dy) + h + ext + 1);
  const int xa = std::max(0, x - ext), xb = std::min(SCREEN_W, x + w + ext);
  // 距離 d 對應的陰影濃度：d 由 -blur 到 blur 以平方曲線淡出
  auto shade = [&](float d) {
    if (d >= blur) return 0;
    const float t = std::clamp(1.0f - (d + blur) / (2.0f * blur), 0.0f, 1.0f);
    return static_cast<int>(alpha * t * t);
  };
  const int corner = static_cast<int>(std::ceil(r)) + 1;
  const int midA = std::max(xa, x + corner), midB = std::min(xb, x + w - corner);
  for (int yy = ya; yy < yb; yy++) {
    const float qy = std::fabs(yy + 0.5f - cy) - hh;
    const bool covered = yy >= y + 1 && yy < y + h - 1;  // 卡片會蓋住中間，只畫左右兩側
    auto px = [&](int xx) { blendDither(xx, yy, color::SHADOW, shade(roundBoxDist(std::fabs(xx + 0.5f - cx) - hw, qy, r))); };
    if (midA >= midB) {
      for (int xx = xa; xx < xb; xx++) px(xx);
      continue;
    }
    // 卡片直線段的列：卡片範圍內全被蓋住，只畫卡片左右外側
    const bool straight = covered && std::fabs(yy + 0.5f - (y + h / 2.0f)) <= hh;
    for (int xx = xa; xx < (straight ? std::max(xa, x) : midA); xx++) px(xx);
    for (int xx = straight ? std::min(xb, x + w) : midB; xx < xb; xx++) px(xx);
    if (covered) continue;
    const int a = shade(qy - r);  // 上下邊緣的直線段：整段同一個濃度
    if (a > 0)
      for (int xx = midA; xx < midB; xx++) blendDither(xx, yy, color::SHADOW, a);
  }
}

void Canvas::arc(float cx, float cy, float r, float thick, float from, float to, uint16_t c) {
  if (to < from) std::swap(from, to);
  const float half = thick / 2.0f, span = to - from, turn = 2.0f * static_cast<float>(M_PI);
  const float ax = cx + r * std::sin(from * turn), ay = cy - r * std::cos(from * turn);
  const float bx = cx + r * std::sin(to * turn), by = cy - r * std::cos(to * turn);
  const float lo = std::max(0.0f, r - half - 1), hi = r + half + 1, lo2 = lo * lo, hi2 = hi * hi, cap2 = (half + 1) * (half + 1);
  const float ext = r + half + 1;
  const int ya = std::max(y0_, static_cast<int>(cy - ext)), yb = std::min(y0_ + h_, static_cast<int>(cy + ext) + 1);
  for (int y = ya; y < yb; y++)
    for (int x = static_cast<int>(cx - ext); x <= static_cast<int>(cx + ext); x++) {
      const float px = x + 0.5f, py = y + 0.5f, dx = px - cx, dy = py - cy, d2 = dx * dx + dy * dy;
      if (d2 < lo2 || d2 > hi2) continue;
      const float band = half - std::fabs(std::sqrt(d2) - r);
      int a = 0;
      if (band > -0.5f) {
        float f = std::atan2(dx, -dy) / turn - from;
        f -= std::floor(f);
        if (span >= 1.0f || f <= span) a = coverage(band + 0.5f);
      }
      // 兩端的圓頭
      const float ea2 = (px - ax) * (px - ax) + (py - ay) * (py - ay), eb2 = (px - bx) * (px - bx) + (py - by) * (py - by);
      if (ea2 < cap2) a = std::max(a, coverage(half - std::sqrt(ea2) + 0.5f));
      if (eb2 < cap2) a = std::max(a, coverage(half - std::sqrt(eb2) + 0.5f));
      blend(x, y, c, a);
    }
}

void Canvas::image(const uint16_t *rgb, const uint8_t *alpha, int w, int h, int x, int y) {
  for (int yy = std::max(y0_, y); yy < std::min(y0_ + h_, y + h); yy++)
    for (int xx = 0; xx < w; xx++) blend(x + xx, yy, rgb[(yy - y) * w + xx], alpha[(yy - y) * w + xx]);
}

void Canvas::blit(const uint16_t *frame, const uint16_t *fallback, int dy, int splitY, int maxY) {
  for (int y = y0_; y < std::min(y0_ + h_, maxY); y++) {
    const uint16_t *src = frame;
    int sy = y;
    if (dy && y >= splitY) {
      sy = y - dy;
      if (sy < splitY) {
        src = fallback ? fallback : frame;
        sy = y;
      }
    }
    if (y < 0 || y >= SCREEN_H) continue;
    std::memcpy(buf_ + (y - y0_) * SCREEN_W, src + sy * SCREEN_W, SCREEN_W * sizeof(uint16_t));
  }
}

void Canvas::mask(const uint8_t *alpha, int w, int h, int x, int y, uint16_t c) {
  for (int yy = std::max(y0_, y); yy < std::min(y0_ + h_, y + h); yy++)
    for (int xx = 0; xx < w; xx++) blend(x + xx, yy, c, alpha[(yy - y) * w + xx]);
}

void Canvas::qr(const std::vector<uint8_t> &modules, int n, int x, int y, int scale, bool background) {
  if (background) rect(x, y, (n + 8) * scale, (n + 8) * scale, color::WHITE);
  // 只處理落在這一段的模組列
  const int r0 = std::max(0, (y0_ - y) / scale - 4), r1 = std::min(n, (y0_ + h_ - y) / scale - 4 + 1);
  for (int r = r0; r < r1; r++)
    for (int col = 0; col < n; col++)
      if (modules[r * n + col]) rect(x + (col + 4) * scale, y + (r + 4) * scale, scale, scale, color::BLACK);
}

// 單一像素：RGB565 展開成 0b00000gggggg00000rrrrr000000bbbbb 後，三色一次乘以 5 位元透明度
static inline uint16_t blend565(uint16_t dstSwapped, uint16_t underSwapped, uint32_t k) {
  const uint32_t p = swap16(dstSwapped), q = swap16(underSwapped);
  const uint32_t pe = (p | (p << 16)) & 0x07E0F81F, qe = (q | (q << 16)) & 0x07E0F81F;
  const uint32_t r = (pe + (((qe - pe) * k) >> 5)) & 0x07E0F81F;
  return swap16(static_cast<uint16_t>(r | (r >> 16)));
}

void blend_band(uint16_t *dst, const uint16_t *under, int count, int a) {
  if (a <= 0) return;
  if (a >= 255) {
    std::memcpy(dst, under, count * sizeof(uint16_t));
    return;
  }
  const uint32_t k = static_cast<uint32_t>((a * 32 + 127) / 255);  // 32 階，淡入淡出已夠平順
  // 一次比較兩個像素，相同（背景等沒變的地方）整組跳過；緩衝區為 4 位元組對齊
  auto *d = reinterpret_cast<uint32_t *>(dst);
  const auto *u = reinterpret_cast<const uint32_t *>(under);
  for (int i = 0; i < count / 2; i++) {
    const uint32_t dv = d[i], uv = u[i];
    if (dv == uv) continue;
    uint16_t lo = static_cast<uint16_t>(dv), hi = static_cast<uint16_t>(dv >> 16);
    const uint16_t ulo = static_cast<uint16_t>(uv), uhi = static_cast<uint16_t>(uv >> 16);
    if (lo != ulo) lo = blend565(lo, ulo, k);
    if (hi != uhi) hi = blend565(hi, uhi, k);
    d[i] = lo | (static_cast<uint32_t>(hi) << 16);
  }
}

}  // namespace smb
