#include "ui.h"

#include <algorithm>
#include <cmath>
#include <functional>
#include <memory>
#include <mutex>

#include "display.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "logo.h"
#include "qrcode.h"

namespace smb {

// 版面語彙比照 iOS 即時動態：頂部動態島膠囊（品牌、時間、離線），下方為小工具卡片。
// 主角放在霧藍卡片（櫃門、比對數字、配對碼），倒數放在右側白色卡片的圓環。

namespace pal {
constexpr uint32_t BG_TOP = 0xdfe7ec, BG_BOTTOM = 0xf3f5f7;
constexpr uint16_t ISLAND = rgb(0x151e27);
constexpr uint16_t ISLAND_TEXT = rgb(0xffffff);
constexpr uint16_t ISLAND_MUTED = rgb(0xa9b6bf);
constexpr uint16_t PRIMARY = rgb(0x627d8d);
constexpr uint16_t PRIMARY_DARK = rgb(0x4d626f);
constexpr uint16_t PRIMARY_LIGHT = rgb(0xb9c7cf);
constexpr uint16_t CARD = rgb(0xffffff);
constexpr uint16_t TEXT = rgb(0x151e27);
constexpr uint16_t MUTED = rgb(0x5f6673);
constexpr uint16_t TRACK = rgb(0xe6eaed);
constexpr uint16_t SUCCESS = rgb(0x2e9e5b);
constexpr uint16_t WARN = rgb(0xd98613);
constexpr uint16_t WARN_TEXT = rgb(0xa8620a);  // 淡橘底上的文字，TN 面板上仍清楚
}  // namespace pal

static constexpr int ISLAND_Y = 6, ISLAND_H = 28, ISLAND_CY = ISLAND_Y + ISLAND_H / 2;
static constexpr int TOP = 44, BOTTOM = 228;  // 內容區（小工具卡片的上下緣）
static constexpr int M = 12, GAP = 10, RING_W = 100;
static constexpr float WR = 22;  // 小工具卡片圓角
static constexpr int TEXT_X = 16, TEXT_W = SCREEN_W - 2 * TEXT_X;
static constexpr int HEAD_LH = 28, BODY_LH = 21;
static constexpr int QR_BOX = 164;

static constexpr uint32_t OUT_MS = 130, IN_MS = 280;
static constexpr int SLIDE_PX = 14;
static constexpr uint32_t BADGE_IN_MS = 420, CHECK_DELAY_MS = 160, CHECK_MS = 340;
static constexpr uint32_t ENTER_MS = CHECK_DELAY_MS + CHECK_MS + 60;  // 結果圖示的進場動畫結束
static constexpr int SPLIT_Y = ISLAND_Y + ISLAND_H + 4;               // 轉場滑動只影響這條線以下

// ---------- 圖層 ----------

// 不會動的內容（背景、卡片、文字）先畫進 PSRAM 的整張快取，每張畫面只複製快取再畫會動的部分
// （轉圈、倒數圓環與秒數、進度條），60 fps 也只需幾毫秒。各元件依目前的繪製階段決定要不要畫。
enum class Pass { All, Static, Dynamic };
static Pass s_pass = Pass::All;
static bool staticPass() { return s_pass != Pass::Dynamic; }
static bool dynamicPass() { return s_pass != Pass::Static; }

// ---------- QR Code ----------

struct QrCode {
  std::string payload;
  std::vector<uint8_t> modules;
  int n = 0;
};
using QrPtr = std::shared_ptr<const QrCode>;
// 網路工作（核心 0）收到新內容時先產生（約 30 毫秒），畫面工作直接取用；轉場時新舊兩個同時出現
static std::mutex s_qrMu;
static QrPtr s_qr[3];
static int s_qrNext = 0;

static void onQr(esp_qrcode_handle_t q, void *user) {
  auto *c = static_cast<QrCode *>(user);
  c->n = esp_qrcode_get_size(q);
  c->modules.assign(c->n * c->n, 0);
  for (int y = 0; y < c->n; y++)
    for (int x = 0; x < c->n; x++) c->modules[y * c->n + x] = esp_qrcode_get_module(q, x, y);
}

static QrPtr qrLookup(const std::string &payload) {
  std::lock_guard<std::mutex> g(s_qrMu);
  for (const QrPtr &q : s_qr)
    if (q && q->payload == payload) return q;
  return nullptr;
}

// 書櫃 QR Code 為 47 字元，錯誤修正等級 M 時自動選用版本 4（含靜區 41×41 格，每格 4 像素為 164 像素）。
static QrPtr qrFor(const std::string &payload) {
  if (QrPtr q = qrLookup(payload)) return q;
  auto c = std::make_shared<QrCode>();
  c->payload = payload;
  esp_log_level_set("QRCODE", ESP_LOG_WARN);  // 元件會把內容印到序列埠
  esp_qrcode_config_t cfg = {};
  cfg.display_func_with_cb = onQr;
  cfg.user_data = c.get();
  cfg.max_qrcode_version = 10;
  cfg.qrcode_ecc_level = ESP_QRCODE_ECC_MED;
  esp_qrcode_generate(&cfg, payload.c_str());
  std::lock_guard<std::mutex> g(s_qrMu);
  s_qr[s_qrNext] = c;
  s_qrNext = (s_qrNext + 1) % 3;
  return c;
}

void ui_prepare_qr(const std::string &payload) {
  if (!payload.empty()) qrFor(payload);
}

// ---------- 文字 ----------

static std::vector<std::string> balancedWrap(const smb_font_t &f, const std::string &s, int width) {
  std::vector<std::string> lines = wrapText(f, s, width);
  if (lines.size() < 2) return lines;
  int lo = width / 2, hi = width;
  while (lo < hi) {
    const int mid = (lo + hi) / 2;
    if (wrapText(f, s, mid).size() == lines.size()) hi = mid;
    else lo = mid + 1;
  }
  return wrapText(f, s, hi);
}

static std::vector<std::string> wrapUncached(const smb_font_t &f, const std::string &s, int width, size_t maxLines);

// 斷行結果快取：每段畫面都會重畫整個畫面，同一段文字不必每段重算。
static std::vector<std::string> wrapped(const smb_font_t &f, const std::string &s, int width, size_t maxLines) {
  struct Entry {
    const smb_font_t *f;
    std::string s;
    int width;
    size_t maxLines;
    std::vector<std::string> lines;
  };
  static Entry cache[16];
  static size_t next = 0;
  for (const Entry &e : cache)
    if (e.f == &f && e.width == width && e.maxLines == maxLines && e.s == s) return e.lines;
  Entry &e = cache[next];
  next = (next + 1) % std::size(cache);
  e = {&f, s, width, maxLines, wrapUncached(f, s, width, maxLines)};
  return e.lines;
}

// 需要兩行時優先在全形逗號後換行，不把詞拆開；maxLines 為 0 時不平衡斷行（英文名稱留在同一行）。
static std::vector<std::string> wrapUncached(const smb_font_t &f, const std::string &s, int width, size_t maxLines) {
  if (s.empty()) return {};
  if (maxLines == 0) return wrapText(f, s, width);
  static const std::string COMMA = "，";
  if (maxLines >= 2 && textWidth(f, s) > width) {
    size_t best = std::string::npos;
    int bestDiff = 1 << 30;
    for (size_t at = s.find(COMMA); at != std::string::npos; at = s.find(COMMA, at + 1)) {
      const std::string a = s.substr(0, at + COMMA.size()), b = s.substr(at + COMMA.size());
      const int wa = textWidth(f, a), wb = textWidth(f, b);
      if (!b.empty() && wa <= width && wb <= width && std::abs(wa - wb) < bestDiff) {
        best = at + COMMA.size();
        bestDiff = std::abs(wa - wb);
      }
    }
    if (best != std::string::npos) return {s.substr(0, best), s.substr(best)};
  }
  std::vector<std::string> lines = balancedWrap(f, s, width);
  if (lines.size() > maxLines) lines.resize(maxLines);
  return lines;
}

static void drawLines(Canvas &c, const smb_font_t &f, const std::vector<std::string> &lines, int x, int y, int lineH,
                      uint16_t col, Align a) {
  for (const std::string &l : lines) {
    c.text(f, l, x, y, col, a);
    y += lineH;
  }
}

// 數字逐字排列並加字距（tracking），回傳總寬。
static int trackedWidth(const smb_font_t &f, const std::string &s, int tracking) {
  int w = 0;
  for (size_t i = 0; i < s.size(); i++) w += textWidth(f, s.substr(i, 1)) + (i + 1 < s.size() ? tracking : 0);
  return w;
}
static void trackedText(Canvas &c, const smb_font_t &f, const std::string &s, int x, int cy, int tracking, uint16_t col) {
  for (size_t i = 0; i < s.size(); i++) {
    const std::string ch = s.substr(i, 1);
    c.text(f, ch, x, cy, col);
    x += textWidth(f, ch) + tracking;
  }
}

static std::string line(const View &v, size_t i) { return i < v.lines.size() ? v.lines[i] : ""; }

static float ratioOf(int64_t remaining, int64_t total) {
  return total > 0 ? std::clamp(static_cast<float>(remaining) / total, 0.0f, 1.0f) : 0.0f;
}
static float clamp01(float t) { return std::clamp(t, 0.0f, 1.0f); }
static float easeOutCubic(float t) {
  t = 1.0f - clamp01(t);
  return 1.0f - t * t * t;
}
static float easeOutBack(float t) {
  t = clamp01(t) - 1.0f;
  return 1.0f + 2.4f * t * t * t + 1.4f * t * t;
}

// ---------- 元件 ----------

// 淡色底以白色為基底調色，避免在冷灰底上混出濁色。
static uint16_t tint(uint16_t c, int t = 40) { return mix(pal::CARD, c, t); }

static void widget(Canvas &c, int x, int y, int w, int h, uint16_t fill, int shadow = 26) {
  c.shadow(x, y, w, h, WR, 12, 4, shadow);
  c.roundRect(x, y, w, h, WR, fill);
}

// 膠囊進度條。
static void capsuleBar(Canvas &c, int x, int y, int w, int h, float ratio, uint16_t fg, uint16_t track = pal::TRACK) {
  c.roundRect(x, y, w, h, h / 2.0f, track);
  const int filled = static_cast<int>(std::lround(w * clamp01(ratio)));
  if (filled > 0) c.roundRect(x, y, std::max(filled, h), h, h / 2.0f, fg);
}

static uint16_t urgency(float ratio) { return ratio < 0.2f ? pal::WARN : pal::PRIMARY; }

enum class Glyph { None, Check, Alert, Clock, Pause, Wrench, Phone, Wifi, WifiOff, Spinner };

// iOS 樣式的轉圈：12 根輻條依序變亮，每秒一圈；tick 為 0 時畫固定的一格。（動態）
static void spinner(Canvas &c, int cx, int cy, uint32_t tick, uint16_t bg) {
  const int head = static_cast<int>((tick / 83) % 12);
  const float turn = 2.0f * static_cast<float>(M_PI);
  for (int i = 0; i < 12; i++) {
    const int age = (head - i + 12) % 12;
    const float a = i / 12.0f * turn, sx = std::sin(a), sy = -std::cos(a);
    c.line(cx + sx * 8, cy + sy * 8, cx + sx * 16, cy + sy * 16, 3.4f, mix(bg, pal::PRIMARY_DARK, 255 - age * 18));
  }
}

// s 為縮放比例（1 對應直徑約 30 像素的圖示）；bg 為圖示底色，Wi-Fi 斷線的斜線兩側以底色隔開。
static void wifiGlyph(Canvas &c, float cx, float cy, float s, uint16_t col, bool slash, uint16_t bg) {
  // 斷線時訊號弧線改淡色，斜線用原色並以底色隔開，小尺寸下仍分得清楚
  const float t = std::max(2.2f, 3.2f * s);
  const uint16_t arcs = slash ? mix(bg, col, 185) : col;
  c.arc(cx, cy + 8 * s, 16 * s, t, -0.13f, 0.13f, arcs);
  c.arc(cx, cy + 8 * s, 9 * s, t, -0.13f, 0.13f, arcs);
  c.disc(static_cast<int>(cx), static_cast<int>(cy + 8 * s), std::max(1, static_cast<int>(std::lround(2.2f * s))), arcs);
  if (slash) {
    c.line(cx - 12 * s, cy - 11 * s, cx + 11 * s, cy + 12 * s, t + 4, bg);
    c.line(cx - 12 * s, cy - 11 * s, cx + 11 * s, cy + 12 * s, t, col);
  }
}

static void glyph(Canvas &c, Glyph g, int cx, int cy, uint16_t col, uint16_t bg, uint32_t tick, float progress = 1) {
  switch (g) {
    case Glyph::Check: {
      const float x0 = cx - 11, y0 = cy + 1, x1 = cx - 3.5f, y1 = cy + 8.5f, x2 = cx + 11.5f, y2 = cy - 7.5f;
      const float l1 = std::hypot(x1 - x0, y1 - y0), l2 = std::hypot(x2 - x1, y2 - y1), len = (l1 + l2) * clamp01(progress);
      if (len <= 0) break;
      const float k1 = std::min(1.0f, len / l1);
      c.line(x0, y0, x0 + (x1 - x0) * k1, y0 + (y1 - y0) * k1, 4, col);
      if (len > l1) {
        const float k2 = (len - l1) / l2;
        c.line(x1, y1, x1 + (x2 - x1) * k2, y1 + (y2 - y1) * k2, 4, col);
      }
      break;
    }
    case Glyph::Alert:
      c.line(cx, cy - 11, cx, cy + 2, 4, col);
      c.disc(cx, cy + 10, 2, col);
      break;
    case Glyph::Clock:
      c.arc(cx, cy, 13, 3, 0, 1, col);
      c.line(cx, cy, cx, cy - 7, 3, col);
      c.line(cx, cy, cx + 5, cy + 4, 3, col);
      break;
    case Glyph::Pause:
      c.line(cx - 5, cy - 9, cx - 5, cy + 9, 4, col);
      c.line(cx + 5, cy - 9, cx + 5, cy + 9, 4, col);
      break;
    case Glyph::Wrench:
      c.line(cx - 10, cy + 10, cx + 1, cy - 1, 4.5f, col);
      c.arc(cx + 5, cy - 5, 6.5f, 4, 0.24f, 1.01f, col);
      break;
    case Glyph::Phone:
      c.roundRect(cx - 9, cy - 14, 18, 28, 4, col, 2.5f);
      c.line(cx - 3, cy + 8, cx + 3, cy + 8, 2.5f, col);
      break;
    case Glyph::Wifi:
    case Glyph::WifiOff:
      wifiGlyph(c, cx, cy, 1, col, g == Glyph::WifiOff, bg);
      break;
    case Glyph::Spinner:
      spinner(c, cx, cy, tick, bg);
      break;
    default:
      break;
  }
}

// 狀態圖示：淡色圓底配主色圖示；結果用實心圓加淡色光暈，進場時彈性放大再畫出勾勾。
static constexpr int BADGE_R = 30;
static void badge(Canvas &c, Glyph g, int cx, int cy, uint16_t col, bool solid, uint32_t tick, uint32_t enterMs) {
  if (g == Glyph::None) return;
  if (g == Glyph::Spinner) {
    if (staticPass()) {
      c.shadow(cx - BADGE_R, cy - BADGE_R, 2 * BADGE_R, 2 * BADGE_R, BADGE_R, 10, 3, 22);
      c.disc(cx, cy, BADGE_R, pal::CARD);
    }
    if (dynamicPass()) spinner(c, cx, cy, tick, pal::CARD);
    return;
  }
  // 結果圖示（實心）一律屬於動態層：進場動畫結束與否不影響快取內容，切換時不會缺一格
  if (solid ? !dynamicPass() : !staticPass()) return;
  if (!solid) {
    // 一般狀態用白色圓底（與卡片一致），警示狀態用淡橘底
    const bool neutral = col == pal::PRIMARY;
    const uint16_t bg = neutral ? pal::CARD : tint(col, 48);
    if (neutral) c.shadow(cx - BADGE_R, cy - BADGE_R, 2 * BADGE_R, 2 * BADGE_R, BADGE_R, 10, 3, 22);
    c.disc(cx, cy, BADGE_R, bg);
    glyph(c, g, cx, cy, col, bg, tick);
    return;
  }
  const float scale = easeOutBack(static_cast<float>(enterMs) / BADGE_IN_MS);
  const int halo = std::max(1, static_cast<int>(std::lround((BADGE_R + 10) * scale)));
  const int r = std::max(1, static_cast<int>(std::lround(BADGE_R * scale)));
  c.disc(cx, cy, halo, tint(col, 34));
  c.disc(cx, cy, r, col);
  if (g == Glyph::Check)
    glyph(c, g, cx, cy, pal::CARD, col, tick, easeOutCubic((static_cast<float>(enterMs) - CHECK_DELAY_MS) / CHECK_MS));
  else if (scale > 0.6f)
    glyph(c, g, cx, cy, pal::CARD, col, tick);
}

// 膠囊標籤；回傳寬度。x 依 a 對齊。
static constexpr int PILL_H = 30;
static int pillWidth(const smb_font_t &f, const std::string &t, bool icon) { return textWidth(f, t) + 28 + (icon ? 22 : 0); }
static void pill(Canvas &c, const smb_font_t &f, const std::string &t, int x, int cy, uint16_t bg, uint16_t fg, Align a,
                 Glyph icon = Glyph::None, int h = PILL_H) {
  const int w = pillWidth(f, t, icon != Glyph::None);
  const int left = a == Align::Left ? x : a == Align::Center ? x - w / 2 : x - w;
  if (bg == pal::CARD) c.shadow(left, cy - h / 2, w, h, h / 2.0f, 8, 2, 16);
  c.roundRect(left, cy - h / 2, w, h, h / 2.0f, bg);
  int tx = left + 14;
  if (icon == Glyph::Alert) {
    c.disc(tx + 8, cy, 8, fg);
    c.line(tx + 8, cy - 4, tx + 8, cy + 1, 2, bg);
    c.disc(tx + 8, cy + 4, 1, bg);
    tx += 22;
  }
  c.text(f, t, tx, cy, fg);
}

// ---------- 動態島 ----------

static void island(Canvas &c, const View &v) {
  const int padL = 12, padR = 14, logoGap = 7, clockGap = 18;
  const int titleW = textWidth(FONT_TITLE, v.header);
  const int clockW = v.clock.empty() ? 0 : textWidth(FONT_TITLE, v.clock);
  const int w = padL + LOGO_W + logoGap + titleW + (clockW ? clockGap + clockW : 0) + padR;
  const bool offline = !v.online;
  const int bubble = offline ? ISLAND_H : 0, bubbleGap = offline ? 5 : 0;
  const int x = (SCREEN_W - (w + bubbleGap + bubble)) / 2;
  c.roundRect(x, ISLAND_Y, w, ISLAND_H, ISLAND_H / 2.0f, pal::ISLAND);
  c.mask(LOGO_ALPHA, LOGO_W, LOGO_H, x + padL, ISLAND_Y + (ISLAND_H - LOGO_H) / 2, pal::PRIMARY_LIGHT);
  c.text(FONT_TITLE, v.header, x + padL + LOGO_W + logoGap, ISLAND_CY, pal::ISLAND_TEXT);
  if (clockW) c.text(FONT_TITLE, v.clock, x + w - padR, ISLAND_CY, pal::ISLAND_MUTED, Align::Right);
  if (offline) {
    // 雙膠囊：右側小圓顯示離線圖示
    const int bx = x + w + bubbleGap + ISLAND_H / 2;
    c.disc(bx, ISLAND_CY, ISLAND_H / 2, pal::ISLAND);
    // 灰色訊號弧線加上橘色斜線
    const float gx = bx, gy = ISLAND_CY + 5;
    const uint16_t dim = rgb(0x8796a1);
    c.arc(gx, gy, 10.5f, 2.2f, -0.125f, 0.125f, dim);
    c.arc(gx, gy, 6, 2.2f, -0.125f, 0.125f, dim);
    c.disc(bx, ISLAND_CY + 4, 1, dim);
    c.line(gx - 7.5f, gy - 12, gx + 6.5f, gy + 1, 5, pal::ISLAND);
    c.line(gx - 7.5f, gy - 12, gx + 6.5f, gy + 1, 2.2f, pal::WARN);
  }
}

// ---------- 小工具卡片 ----------

// 右側倒數：白色卡片中的圓環與秒數。
static void ringWidget(Canvas &c, int x, int y, int w, int h, int64_t remainingMs, int64_t totalMs) {
  const float ratio = ratioOf(remainingMs, totalMs);
  const int cx = x + w / 2, cy = y + h / 2, r = std::min(35, std::min(w, h) / 2 - 14);
  if (staticPass()) {
    widget(c, x, y, w, h, pal::CARD);
    c.arc(cx, cy, r, 7, 0, 1, pal::TRACK);
    c.text(FONT_SMALL, "秒", cx, cy + 18, pal::MUTED, Align::Center);
  }
  if (!dynamicPass()) return;
  if (ratio > 0) c.arc(cx, cy, r, 7, 0, ratio, urgency(ratio));
  const int64_t secs = (remainingMs + 999) / 1000;
  // 三位數改用較小字級並收緊字距，才不會碰到圓環內緣
  const std::string n = std::to_string(secs);
  if (secs >= 100) trackedText(c, FONT_LABEL_SM, n, cx - trackedWidth(FONT_LABEL_SM, n, -1) / 2, cy - 5, -1, pal::TEXT);
  else c.text(FONT_RING, n, cx, cy - 5, pal::TEXT, Align::Center);
}

// 櫃門編號 A01–A04 由上而下排列：卡片右側畫出書櫃示意，開啟的櫃門亮起。
static int doorIndex(const std::string &label) {
  if (label.size() != 3 || label[0] != 'A' || label[1] != '0') return -1;
  const int n = label[2] - '0';
  return n >= 1 && n <= 4 ? n - 1 : -1;
}

static void cabinetMap(Canvas &c, int x, int y, const std::vector<std::string> &labels) {
  const int slotW = 26, slotH = 10, gap = 4, pad = 5;
  const int frameW = slotW + 2 * pad, frameH = 4 * slotH + 3 * gap + 2 * pad;
  c.roundRect(x, y, frameW, frameH, 7, mix(pal::PRIMARY, pal::CARD, 90), 1.5f);
  for (int i = 0; i < 4; i++) {
    bool open = false;
    for (const std::string &l : labels) open |= doorIndex(l) == i;
    c.roundRect(x + pad, y + pad + i * (slotH + gap), slotW, slotH, 3, open ? pal::CARD : mix(pal::PRIMARY, pal::CARD, 60));
  }
}

static void doorWidget(Canvas &c, int x, int y, int w, int h, const std::vector<std::string> &labels) {
  if (!staticPass()) return;
  widget(c, x, y, w, h, pal::PRIMARY, 34);
  bool mapped = !labels.empty();
  for (const std::string &l : labels) mapped &= doorIndex(l) >= 0;
  const int mapW = 36, mapH = 4 * 10 + 3 * 4 + 10;
  const int right = mapped ? x + w - 16 - mapW - 10 : x + w - 16;
  if (mapped) cabinetMap(c, x + w - 16 - mapW, y + (h - mapH) / 2, labels);
  const int left = x + 18, cy = y + h / 2;
  if (labels.size() == 1) {
    c.text(FONT_LABEL, labels[0], left, cy, pal::CARD);
    return;
  }
  const int colW = std::max(1, (right - left + 8) / 2), rowH = 36;
  const int rows = static_cast<int>((labels.size() + 1) / 2);
  int ry = cy - (rows - 1) * rowH / 2;
  for (size_t i = 0; i < labels.size(); i++) {
    c.text(FONT_LABEL_SM, labels[i], left + static_cast<int>(i % 2) * colW, ry + static_cast<int>(i / 2) * rowH, pal::CARD);
  }
}

// ---------- 版面 ----------

struct Ctx {
  uint32_t tick, enterMs;
};

// 置中的狀態版面：選用的分類標籤、圖示、標題、說明（放得下一行時用膠囊）。
static void statusBlock(Canvas &c, const Ctx &x, Glyph g, uint16_t col, bool solid, const std::string &title,
                        const std::string &sub, const std::string &tag = "") {
  const std::vector<std::string> t = wrapped(FONT_HEAD, title, 280, 2);
  const bool subPill = !sub.empty() && pillWidth(FONT_BODY, sub, false) <= 290;
  const std::vector<std::string> s = subPill ? std::vector<std::string>{} : wrapped(FONT_BODY, sub, 280, 2);
  const int tagH = tag.empty() ? 0 : 28 + 14;
  const int iconH = g == Glyph::None ? 0 : 2 * BADGE_R + (solid ? 4 : 0);
  const int titleH = static_cast<int>(t.size()) * HEAD_LH;
  const int subH = subPill ? PILL_H + 12 : s.empty() ? 0 : static_cast<int>(s.size()) * BODY_LH + 6;
  const int total = tagH + iconH + (iconH ? 16 : 0) + titleH + subH;
  int y = TOP - 2 + (SCREEN_H - 6 - (TOP - 2) - total) / 2;
  if (tagH) {
    if (staticPass()) pill(c, FONT_BODY, tag, SCREEN_W / 2, y + 14, pal::CARD, pal::PRIMARY_DARK, Align::Center, Glyph::None, 28);
    y += tagH;
  }
  if (iconH) {
    badge(c, g, SCREEN_W / 2, y + iconH / 2, col, solid, x.tick, x.enterMs);
    y += iconH + 16;
  }
  if (!staticPass()) return;
  drawLines(c, FONT_HEAD, t, SCREEN_W / 2, y + HEAD_LH / 2, HEAD_LH, pal::TEXT, Align::Center);
  y += titleH;
  if (subPill) pill(c, FONT_BODY, sub, SCREEN_W / 2, y + 12 + PILL_H / 2, pal::CARD, pal::TEXT, Align::Center);
  else drawLines(c, FONT_BODY, s, SCREEN_W / 2, y + 6 + BODY_LH / 2, BODY_LH, pal::MUTED, Align::Center);
}

// 計時畫面上方的說明（最多兩行，靠左）；回傳下方卡片的上緣。
static int headline(Canvas &c, const std::string &text, const std::string &notice) {
  int y = TOP + 2;
  if (!notice.empty()) {
    if (staticPass()) pill(c, FONT_HEAD, notice, M, y + 18, tint(pal::WARN, 52), pal::WARN_TEXT, Align::Left, Glyph::Alert, 36);
    return y + 36 + 12;
  }
  const std::vector<std::string> ls = wrapped(FONT_HEAD, text, TEXT_W, 2);
  if (staticPass()) drawLines(c, FONT_HEAD, ls, TEXT_X, y + HEAD_LH / 2, HEAD_LH, pal::TEXT, Align::Left);
  return y + static_cast<int>(ls.size()) * HEAD_LH + 10;
}

// ---------- 各畫面 ----------

static bool drawPairing(Canvas &c, const View &v, const Ctx &x) {
  if (v.pairCode.empty()) {
    statusBlock(c, x, v.pairError ? Glyph::Alert : Glyph::Spinner, pal::WARN, false, line(v, 1), "", line(v, 0));
    return !v.pairError;
  }
  std::string digits;
  for (char ch : v.pairCode)
    if (ch >= '0' && ch <= '9') digits += ch;
  const int y = TOP + 2, h = 108, w = SCREEN_W - 2 * M;
  if (staticPass()) {
    widget(c, M, y, w, h, pal::PRIMARY, 34);
    c.text(FONT_TITLE, line(v, 0), M + 18, y + 22, mix(pal::PRIMARY, pal::CARD, 215));
    // 8 碼等距排成一列，不分組、不加短線
    const int track = 9, total = trackedWidth(FONT_LABEL, digits, track);
    trackedText(c, FONT_LABEL, digits, M + (w - total) / 2, y + 66, track, pal::CARD);
    c.text(FONT_HEAD, line(v, 2), TEXT_X, y + h + 26, pal::TEXT);
  }
  if (!dynamicPass()) return true;
  const float ratio = ratioOf(v.pairRemainingMs, v.pairTotalMs);
  const std::string remain = line(v, 3);
  const int tw = textWidth(FONT_BODY, remain), barY = BOTTOM - 10;
  capsuleBar(c, TEXT_X, barY - 3, TEXT_W - tw - 14, 6, ratio, urgency(ratio));
  c.text(FONT_BODY, remain, SCREEN_W - TEXT_X, barY, pal::MUTED, Align::Right);
  return true;
}

// QR Code 在左側白色卡片（含 4 格以上靜區），右側為 App 圖示與說明。
static void drawQrScreen(Canvas &c, const View &v, Glyph icon, const std::string &title, const std::string &body, bool bodyIsMain,
                         uint16_t bodyCol) {
  const QrPtr qp = qrFor(v.qr);
  const QrCode &q = *qp;
  int scale = 4;
  while (scale > 3 && (q.n + 8) * scale > QR_BOX) scale--;
  const int side = (q.n + 8) * scale, box = std::max(QR_BOX, side);
  const int qx = 10, qy = TOP - 2 + (SCREEN_H - 6 - (TOP - 2) - box) / 2;
  if (q.n > 0 && staticPass()) {
    widget(c, qx, qy, box, box, pal::CARD, 30);
    c.qr(q.modules, q.n, qx + (box - side) / 2, qy + (box - side) / 2, scale, false);
  }
  const int left = qx + box + 12, width = SCREEN_W - 10 - left;
  const smb_font_t &bf = bodyIsMain ? FONT_HEAD : FONT_BODY;
  const int blh = bodyIsMain ? 26 : BODY_LH;
  const std::vector<std::string> bl = wrapped(bf, body, width, 0);
  const bool hasBar = v.qrRatio >= 0;
  const int iconS = 40;
  const int h = iconS + 14 + (title.empty() ? 0 : 28) + static_cast<int>(bl.size()) * blh + (hasBar ? 16 + 6 : 0);
  int y = qy + box / 2 - h / 2;
  if (staticPass()) {
    c.roundRect(left, y, iconS, iconS, 12, pal::PRIMARY);
    if (icon == Glyph::Wifi) wifiGlyph(c, left + iconS / 2, y + iconS / 2 - 2, 0.8f, pal::CARD, false, pal::PRIMARY);
    else glyph(c, icon, left + iconS / 2, y + iconS / 2, pal::CARD, pal::PRIMARY, 0);
  }
  y += iconS + 14;
  if (!title.empty()) {
    if (staticPass()) c.text(FONT_HEAD, title, left, y + 13, pal::TEXT);
    y += 28;
  }
  if (staticPass()) drawLines(c, bf, bl, left, y + blh / 2, blh, bodyCol, Align::Left);
  y += static_cast<int>(bl.size()) * blh;
  if (hasBar && dynamicPass()) capsuleBar(c, left, y + 16, std::min(width, 118), 6, v.qrRatio, urgency(v.qrRatio));
}

static void drawNotice(Canvas &c, const View &v, const Ctx &x) {
  const Glyph g = v.icon == Icon::Check    ? Glyph::Check
                  : v.icon == Icon::Alert  ? Glyph::Alert
                  : v.icon == Icon::Clock  ? Glyph::Clock
                  : v.icon == Icon::Wrench ? Glyph::Wrench
                  : v.icon == Icon::Pause  ? Glyph::Pause
                                           : Glyph::None;
  const uint16_t col = v.icon == Icon::Check ? pal::SUCCESS : v.icon == Icon::Alert ? pal::WARN : pal::PRIMARY;
  statusBlock(c, x, g, col, v.screen == Screen::Result, line(v, 0), line(v, 1));
}

// 選擇項目：霧藍卡片放圖示與說明，右側倒數。
static void drawSelect(Canvas &c, const View &v) {
  const std::string sub = v.lines.size() > (v.hasCountdown ? 2u : 1u) ? line(v, 1) : "";
  const int y = TOP + 2, h = BOTTOM - y, w = SCREEN_W - 2 * M - (v.hasCountdown ? GAP + RING_W : 0);
  if (staticPass()) {
    widget(c, M, y, w, h, pal::PRIMARY, 34);
    c.disc(M + 18 + 20, y + 18 + 20, 20, pal::CARD);
    glyph(c, Glyph::Phone, M + 38, y + 38, pal::PRIMARY, pal::CARD, 0);
    const int tw = w - 36;
    const std::vector<std::string> t = wrapped(FONT_HEAD, line(v, 0), tw, 2), s = wrapped(FONT_BODY, sub, tw, 2);
    int ty = y + h - 18 - static_cast<int>(s.size()) * BODY_LH - static_cast<int>(t.size()) * HEAD_LH - (s.empty() ? 0 : 4);
    drawLines(c, FONT_HEAD, t, M + 18, ty + HEAD_LH / 2, HEAD_LH, pal::CARD, Align::Left);
    ty += static_cast<int>(t.size()) * HEAD_LH + 4;
    drawLines(c, FONT_BODY, s, M + 18, ty + BODY_LH / 2, BODY_LH, mix(pal::PRIMARY, pal::CARD, 225), Align::Left);
  }
  if (v.hasCountdown) ringWidget(c, SCREEN_W - M - RING_W, y, RING_W, h, v.remainingMs, v.totalMs);
}

static void drawMatch(Canvas &c, const View &v) {
  const int y = headline(c, line(v, 0), ""), h = BOTTOM - y;
  const int w = SCREEN_W - 2 * M - (v.hasCountdown ? GAP + RING_W : 0);
  if (!v.code.empty() && staticPass()) {
    widget(c, M, y, w, h, pal::PRIMARY, 34);
    const int track = 10, tw = trackedWidth(FONT_HUGE, v.code, track);
    trackedText(c, FONT_HUGE, v.code, M + (w - tw) / 2, y + h / 2 + 2, track, pal::CARD);
  }
  if (v.hasCountdown)
    ringWidget(c, v.code.empty() ? (SCREEN_W - RING_W) / 2 : SCREEN_W - M - RING_W, y, RING_W, h, v.remainingMs, v.totalMs);
}

static void drawOpen(Canvas &c, const View &v) {
  const int y = headline(c, line(v, 1), v.notice), h = BOTTOM - y;
  const int w = SCREEN_W - 2 * M - (v.hasCountdown ? GAP + RING_W : 0);
  doorWidget(c, M, y, w, h, v.doorLabels);
  if (v.hasCountdown) ringWidget(c, SCREEN_W - M - RING_W, y, RING_W, h, v.remainingMs, v.totalMs);
}

static bool drawCentered(Canvas &c, const View &v, const Ctx &x) {
  Glyph g = Glyph::None;
  uint16_t col = pal::PRIMARY;
  switch (v.screen) {
    case Screen::Booting:
    case Screen::Processing:
    case Screen::Opening:
    case Screen::WifiConnecting:
      g = Glyph::Spinner;
      break;
    case Screen::Offline:
      g = Glyph::WifiOff;
      col = pal::WARN;
      break;
    case Screen::SystemMaintenance:
      g = Glyph::Wrench;
      break;
    case Screen::DeviceDisabled:
      g = Glyph::Pause;
      break;
    default:
      break;
  }
  statusBlock(c, x, g, col, false, line(v, 0), line(v, 1));
  return g == Glyph::Spinner;
}

static bool drawContent(Canvas &c, const View &v, const Ctx &x) {
  switch (v.screen) {
    case Screen::Pairing:
      return drawPairing(c, v, x);
    case Screen::Idle:
      if (!v.qr.empty()) drawQrScreen(c, v, Glyph::Phone, "", line(v, 0), true, pal::TEXT);
      else statusBlock(c, x, Glyph::Phone, pal::PRIMARY, false, line(v, 0), line(v, 1));
      return v.qrRatio >= 0;
    case Screen::WifiSetup:
      if (v.qr.empty()) statusBlock(c, x, Glyph::Wifi, pal::PRIMARY, false, line(v, 0), line(v, 1));
      else drawQrScreen(c, v, Glyph::Wifi, line(v, 0), line(v, 1), false, v.notice.empty() ? pal::MUTED : pal::WARN_TEXT);
      return false;
    case Screen::ClosedHours:
    case Screen::Maintenance:
    case Screen::Disabled:
    case Screen::Result:
      drawNotice(c, v, x);
      return v.screen == Screen::Result && x.enterMs < CHECK_DELAY_MS + CHECK_MS + 60;
    case Screen::Select:
      drawSelect(c, v);
      return v.hasCountdown;
    case Screen::Match:
      drawMatch(c, v);
      return v.hasCountdown;
    case Screen::Open:
    case Screen::Admin:
      drawOpen(c, v);
      return v.hasCountdown;
    default:
      return drawCentered(c, v, x);
  }
}

// ---------- 轉場 ----------

// 內容改變時才轉場：倒數秒數、時鐘、進度不算。也是畫面快取的識別，畫進快取的內容都要涵蓋。
static std::string keyOf(const View &v) {
  std::string k = std::to_string(static_cast<int>(v.screen)) + '|' + std::to_string(static_cast<int>(v.icon)) + '|' + v.code +
                  '|' + v.pairCode + '|' + v.qr + '|' + v.notice + '|' + (v.pairError ? '1' : '0') + '|';
  for (const std::string &d : v.doorLabels) k += d + ',';
  // 選擇項目與比對數字的最後一行是剩餘秒數；配對畫面第 4 行是剩餘時間（都是動態，不納入）
  const bool countdownLast = v.screen == Screen::Select || v.screen == Screen::Match;
  const size_t n = v.screen == Screen::Pairing ? std::min<size_t>(3, v.lines.size()) : v.lines.size();
  for (size_t i = 0; i < n; i++) {
    if (countdownLast && v.hasCountdown && i + 1 == v.lines.size()) continue;
    k += '|' + v.lines[i];
  }
  return k;
}

struct Scene {
  View v;
  uint32_t enteredAt = 0;
};
static Scene s_cur, s_prev;
static std::string s_key;
static bool s_transition = false;
static uint32_t s_transitionAt = 0;

// ---------- 畫面快取 ----------

// 每張快取是某個 key 的不變層。分批重畫（每張畫面最多花 BUILD_BUDGET_US），畫好之前沿用舊的快取，
// 換畫面、時鐘跳分都不會讓動畫卡一下。換畫面時舊畫面淡出的 130 毫秒裡就能畫好新畫面。
struct Frame {
  uint16_t *px = nullptr;
  std::string key;
  int rows = 0;  // 已畫好的列數，SCREEN_H 表示完成
  uint32_t lastUse = 0;
  std::function<void(Canvas &)> draw;
};
static Frame s_frames[6];
static uint32_t s_useClock = 0;
static constexpr int BUILD_H = 24;
static constexpr int64_t BUILD_BUDGET_US = 5000;
static uint16_t *s_buildScratch = nullptr;

static int64_t nowUs() { return esp_timer_get_time(); }

static Frame *findFrame(const std::string &key) {
  for (Frame &f : s_frames)
    if (f.px && f.key == key) return &f;
  return nullptr;
}

// 繼續畫 f，budgetUs 小於 0 時一次畫完。先在內部記憶體畫一段再整段寫進 PSRAM：直接在 PSRAM 上逐點讀寫慢好幾倍。
static void continueBuild(Frame &f, int64_t budgetUs) {
  if (!s_buildScratch) s_buildScratch = new uint16_t[SCREEN_W * BUILD_H];
  const int64_t start = nowUs();
  s_pass = Pass::Static;
  while (f.rows < SCREEN_H && (budgetUs < 0 || nowUs() - start < budgetUs)) {
    Canvas c(s_buildScratch, f.rows, BUILD_H);
    f.draw(c);
    std::copy(s_buildScratch, s_buildScratch + SCREEN_W * BUILD_H, f.px + f.rows * SCREEN_W);
    f.rows += BUILD_H;
  }
  s_pass = Pass::All;
  if (f.rows >= SCREEN_H) f.draw = nullptr;
}

// 取得 key 的快取：已完成就回傳；否則開始或繼續分批重畫，完成前回傳 nullptr（budgetUs 小於 0 時一定畫完）。
// keep 中的快取正在顯示，不能拿來重畫。PSRAM 不足時 ok 設為 false。
static const uint16_t *frameFor(const std::string &key, const std::function<void(Canvas &)> &draw, int64_t budgetUs,
                                std::initializer_list<const uint16_t *> keep, bool &ok) {
  Frame *f = findFrame(key);
  if (!f) {
    Frame *victim = nullptr;
    for (Frame &c : s_frames) {
      if (std::find(keep.begin(), keep.end(), c.px) != keep.end() && c.px) continue;
      if (!victim || !c.px || (victim->px && c.lastUse < victim->lastUse)) victim = &c;
      if (!c.px) break;
    }
    if (!victim || (!victim->px && !(victim->px = display_alloc_frame()))) {
      ok = false;
      return nullptr;
    }
    victim->key = key;
    victim->rows = 0;
    victim->draw = draw;
    f = victim;
  }
  f->lastUse = ++s_useClock;
  if (f->rows < SCREEN_H) continueBuild(*f, budgetUs);
  return f->rows >= SCREEN_H ? f->px : nullptr;
}

static std::string headerKey(const View &v) { return v.header + '|' + v.clock + (v.online ? "|1" : "|0"); }

// 背景（漸層與動態島）。
static void drawBackground(Canvas &c, const View &hdr) {
  c.vgradient(0, SCREEN_H, pal::BG_TOP, pal::BG_BOTTOM);
  island(c, hdr);
}

static std::string sceneKey(const Scene &sc, const View &hdr) { return keyOf(sc.v) + '#' + headerKey(hdr); }

static std::function<void(Canvas &)> sceneDraw(const Scene &sc, const View &hdr, const Ctx &x) {
  return [v = sc.v, hdr, x](Canvas &c) {
    drawBackground(c, hdr);
    drawContent(c, v, x);
  };
}

// 正在顯示的快取，用來判斷要不要整張重送，以及新快取畫好前沿用
static const uint16_t *s_shownBg = nullptr, *s_shownScene = nullptr;
static bool s_full = true;
static int s_dirtyY0 = 0, s_dirtyY1 = SCREEN_H - 1;  // 上一張畫面中會動的元件所在的列

bool ui_draw(const View &v) {
  const uint32_t now = v.tick;
  const std::string key = keyOf(v);
  if (key != s_key) {
    // tick 為 0（硬體測試、預覽）時不做動畫
    s_transition = !s_key.empty() && now != 0;
    if (s_transition) {
      s_prev = s_cur;
      s_transitionAt = now;
    }
    s_key = key;
    s_cur.enteredAt = s_transition ? now + OUT_MS : now;  // 新畫面開始出現的時間
  }
  s_cur.v = v;
  const uint32_t elapsed = s_transition ? now - s_transitionAt : OUT_MS + IN_MS;
  if (elapsed >= OUT_MS + IN_MS) s_transition = false;
  auto ctxOf = [&](const Scene &sc) {
    return Ctx{now, now ? (now > sc.enteredAt ? now - sc.enteredAt : 0) : 1u << 20};
  };
  const Ctx cur = ctxOf(s_cur), prev = ctxOf(s_prev);

  // 轉場：舊畫面先淡出，再讓新畫面淡入並由下往上滑入；動態島不參與
  int alpha = 0, slide = 0;
  const bool fadingOut = s_transition && elapsed < OUT_MS;
  if (fadingOut) {
    alpha = static_cast<int>(std::lround(255 * (1.0f - easeOutCubic(static_cast<float>(elapsed) / OUT_MS))));
  } else if (s_transition) {
    const float e = easeOutCubic(static_cast<float>(elapsed - OUT_MS) / IN_MS);
    slide = static_cast<int>(std::lround((1.0f - e) * SLIDE_PX));
    alpha = static_cast<int>(std::lround(255 * (1.0f - e)));
  }
  const Scene *front = fadingOut ? &s_prev : &s_cur;  // 淡出階段畫的是舊畫面
  const Ctx &fx = fadingOut ? prev : cur;
  bool animating = s_transition;

  // 快取：背景、正在顯示的畫面；新的畫好前沿用舊的（第一次或沒有舊的時一次畫完）
  bool ok = true;
  const int64_t budget = BUILD_BUDGET_US;
  const uint16_t *bg = frameFor(headerKey(v), [hdr = v](Canvas &c) { drawBackground(c, hdr); }, s_shownBg ? budget : -1,
                                {s_shownBg, s_shownScene}, ok);
  if (bg) s_shownBg = bg;
  else if (ok) {
    bg = s_shownBg;
    animating = true;  // 還在畫新快取，盡快再進來
  }
  const uint16_t *scene = nullptr;
  if (ok && bg && fadingOut && s_shownScene) {
    scene = s_shownScene;  // 淡出時直接用螢幕上那張，不因時鐘、連線狀態同時改變而重畫舊畫面
  } else if (ok && bg) {
    // 新畫面淡入時要立即可用（淡出期間多半已畫好）；同一畫面因時鐘跳分重畫時先沿用舊快取
    const bool sameShown = front == &s_cur && !s_transition;
    scene = frameFor(sceneKey(*front, v), sceneDraw(*front, v, fx), sameShown && s_shownScene ? budget : -1,
                     {s_shownBg, s_shownScene, bg}, ok);
    if (!scene && ok) {
      scene = s_shownScene;
      animating = true;
    }
  }
  if (ok && bg) {
    // 淡出期間預先畫新畫面
    if (ok && fadingOut) frameFor(sceneKey(s_cur, v), sceneDraw(s_cur, v, cur), budget, {s_shownBg, scene, bg}, ok);
  }
  if (ok && bg && scene) {
    auto composite = [&](Canvas &c, int dy) {
      c.blit(scene, bg, dy, SPLIT_Y);
      s_pass = Pass::Dynamic;
      Canvas content = c.shifted(dy);
      const bool a = drawContent(content, front->v, fx);
      s_pass = Pass::All;
      return a;
    };
    const bool swapped = scene != s_shownScene || bg != s_shownBg;
    s_shownScene = scene;
    s_shownBg = bg;
    if (!s_transition) {
      // 只重畫上一張會動的元件所在的段（轉圈、圓環等位置固定）；換了快取或轉場剛結束則整張重畫
      const bool full = s_full || swapped;
      canvas_track_begin();
      display_frame([&](Canvas &c) { animating |= composite(c, 0); }, nullptr, 0, full ? 0 : s_dirtyY0,
                    full ? SCREEN_H : s_dirtyY1 + 1);
      canvas_track_end(s_dirtyY0, s_dirtyY1);
      s_full = false;
      return animating;
    }
    s_full = true;
    // 只有背景的那一層：動態島以下是漸層，直接算出來，不必再從 PSRAM 讀一整張
    auto bgOnly = [&](Canvas &c) {
      c.vgradient(0, SCREEN_H, pal::BG_TOP, pal::BG_BOTTOM);
      c.blit(bg, nullptr, 0, 0, SPLIT_Y);
    };
    if (fadingOut) display_frame(bgOnly, [&](Canvas &c) { composite(c, 0); }, alpha, 0, SCREEN_H, false);
    else display_frame([&](Canvas &c) { composite(c, slide); }, bgOnly, alpha, 0, SCREEN_H, false);
    return animating;
  }

  // 沒有 PSRAM 時每段整個重畫
  auto drawScene = [&](Canvas &c, const Scene *sc, const Ctx &x, int dy) {
    drawBackground(c, v);
    if (!sc) return false;
    Canvas content = c.shifted(dy);
    return drawContent(content, sc->v, x);
  };
  if (!s_transition) display_frame([&](Canvas &c) { animating |= drawScene(c, &s_cur, cur, 0); });
  else if (fadingOut)
    display_frame([&](Canvas &c) { drawScene(c, nullptr, prev, 0); }, [&](Canvas &c) { drawScene(c, &s_prev, prev, 0); }, alpha);
  else
    display_frame([&](Canvas &c) { drawScene(c, &s_cur, cur, slide); }, [&](Canvas &c) { drawScene(c, nullptr, cur, 0); }, alpha);
  return animating;
}

}  // namespace smb
