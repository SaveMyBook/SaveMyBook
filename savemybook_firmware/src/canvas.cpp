#include <algorithm>
#include <cmath>

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

static inline uint16_t swap16(uint16_t v) { return static_cast<uint16_t>((v << 8) | (v >> 8)); }

void Canvas::put(int x, int y, uint16_t c) {
  if (x < 0 || x >= SCREEN_W || y < y0_ || y >= y0_ + h_) return;
  buf_[(y - y0_) * SCREEN_W + x] = swap16(c);
}

void Canvas::blend(int x, int y, uint16_t c, int a) {
  if (a <= 0 || x < 0 || x >= SCREEN_W || y < y0_ || y >= y0_ + h_) return;
  uint16_t &px = buf_[(y - y0_) * SCREEN_W + x];
  if (a >= 255) {
    px = swap16(c);
    return;
  }
  uint16_t d = swap16(px);
  int r = ((c >> 11) * a + (d >> 11) * (255 - a)) / 255;
  int g = (((c >> 5) & 0x3F) * a + ((d >> 5) & 0x3F) * (255 - a)) / 255;
  int b = ((c & 0x1F) * a + (d & 0x1F) * (255 - a)) / 255;
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
  for (int y = std::max(y0_, cy - r - 1); y < std::min(y0_ + h_, cy + r + 2); y++)
    for (int x = cx - r - 1; x <= cx + r + 1; x++) {
      const float dx = x + 0.5f - cx, dy = y + 0.5f - cy;
      blend(x, y, c, coverage(r - std::sqrt(dx * dx + dy * dy) + 0.5f));
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

void Canvas::qr(const std::vector<uint8_t> &modules, int n, int x, int y, int scale) {
  rect(x, y, (n + 8) * scale, (n + 8) * scale, color::WHITE);
  for (int r = 0; r < n; r++)
    for (int col = 0; col < n; col++)
      if (modules[r * n + col]) rect(x + (col + 4) * scale, y + (r + 4) * scale, scale, scale, color::BLACK);
}

}  // namespace smb
