#include "ui.h"

#include <algorithm>

#include "display.h"
#include "esp_log.h"
#include "qrcode.h"

namespace smb {

static constexpr int HEADER_H = 28;
static constexpr int MID_Y = (HEADER_H + SCREEN_H) / 2;
static constexpr int QR_X = 16, QR_Y = 40, QR_SCALE = 4;

struct QrCache {
  std::string payload;
  std::vector<uint8_t> modules;
  int n = 0;
};
static QrCache s_qr;

static void onQr(esp_qrcode_handle_t q, void *user) {
  auto *c = static_cast<QrCache *>(user);
  c->n = esp_qrcode_get_size(q);
  c->modules.assign(c->n * c->n, 0);
  for (int y = 0; y < c->n; y++)
    for (int x = 0; x < c->n; x++) c->modules[y * c->n + x] = esp_qrcode_get_module(q, x, y);
}

// 書櫃 QR Code 為 47 字元，錯誤修正等級 M 時自動選用版本 4（含靜區 41×41 格，每格 4 像素為 164 像素）。
static const QrCache &qrFor(const std::string &payload) {
  if (payload != s_qr.payload) {
    s_qr = QrCache{};
    s_qr.payload = payload;
    esp_log_level_set("QRCODE", ESP_LOG_WARN);  // 元件會把內容印到序列埠
    esp_qrcode_config_t cfg = {};
    cfg.display_func_with_cb = onQr;
    cfg.user_data = &s_qr;
    cfg.max_qrcode_version = 10;
    cfg.qrcode_ecc_level = ESP_QRCODE_ECC_MED;
    esp_qrcode_generate(&cfg, payload.c_str());
  }
  return s_qr;
}

static void bar(Canvas &c, int x, int y, int w, float ratio, uint16_t fg = color::ACCENT) {
  const int filled = static_cast<int>(w * std::clamp(ratio, 0.0f, 1.0f) + 0.5f);
  c.rect(x, y, w, 4, color::TRACK);
  c.rect(x, y, filled, 4, fg);
}

// 斷成同樣行數下最窄的寬度，各行長度接近，避免最後一行只剩一兩個字。
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

// 多行文字，cy 為整段的中線。
static void paragraph(Canvas &c, const smb_font_t &f, const std::string &s, int cx, int cy, int width, uint16_t col,
                      int lineH, int maxLines = 3, Align a = Align::Center) {
  std::vector<std::string> lines = balancedWrap(f, s, width);
  if (static_cast<int>(lines.size()) > maxLines) lines.resize(maxLines);
  int y = cy - (static_cast<int>(lines.size()) - 1) * lineH / 2;
  for (const std::string &line : lines) {
    c.text(f, line, cx, y, col, a);
    y += lineH;
  }
}

static void icon(Canvas &c, Icon kind, int cx, int cy) {
  const int r = 24;
  const uint16_t col = kind == Icon::Check ? color::ACCENT : kind == Icon::Alert ? color::WARN : color::MUTED;
  c.circle(cx, cy, r, 3, col);
  switch (kind) {
    case Icon::Check:
      c.line(cx - 10, cy + 1, cx - 3, cy + 8, 3, col);
      c.line(cx - 3, cy + 8, cx + 11, cy - 7, 3, col);
      break;
    case Icon::Alert:
      c.line(cx, cy - 11, cx, cy + 3, 3.5f, col);
      c.disc(cx, cy + 10, 2, col);
      break;
    case Icon::Clock:
      c.line(cx, cy, cx, cy - 13, 3, col);
      c.line(cx, cy, cx + 9, cy + 5, 3, col);
      break;
    case Icon::Pause:
      c.line(cx - 6, cy - 10, cx - 6, cy + 10, 4, col);
      c.line(cx + 6, cy - 10, cx + 6, cy + 10, 4, col);
      break;
    case Icon::Wrench:
      c.line(cx - 11, cy + 11, cx + 3, cy - 3, 5, col);
      c.disc(cx + 6, cy - 6, 8, col);
      c.line(cx + 6, cy - 6, cx + 14, cy - 14, 5, color::BG);  // 開口
      break;
    default:
      break;
  }
}

static void header(Canvas &c, const View &v) {
  c.rect(0, 0, SCREEN_W, HEADER_H, color::HEADER);
  c.text(FONT_TITLE, v.header, 10, HEADER_H / 2, color::TEXT);
  c.disc(SCREEN_W - 14, HEADER_H / 2, 4, v.online ? color::ONLINE : color::OFFLINE);
}

static std::string line(const View &v, size_t i) { return i < v.lines.size() ? v.lines[i] : ""; }

static void drawPairing(Canvas &c, const View &v) {
  if (v.pairCode.empty()) {
    c.text(FONT_TITLE, line(v, 0), SCREEN_W / 2, 92, color::MUTED, Align::Center);
    paragraph(c, FONT_BODY, line(v, 1), SCREEN_W / 2, 140, 280, v.pairError ? color::WARN : color::TEXT, 24, 2);
    return;
  }
  c.text(FONT_TITLE, line(v, 0), SCREEN_W / 2, 60, color::MUTED, Align::Center);
  c.text(FONT_CODE, v.pairCode, SCREEN_W / 2, 100, color::TEXT, Align::Center);
  c.text(FONT_BODY, line(v, 2), SCREEN_W / 2, 146, color::TEXT, Align::Center);
  c.text(FONT_SMALL, line(v, 3), SCREEN_W / 2, 172, color::MUTED, Align::Center);
  bar(c, 40, 192, 240, v.pairTotalMs > 0 ? static_cast<float>(v.pairRemainingMs) / v.pairTotalMs : 0);
}

// QR Code 在左、說明在右。
static void drawQrScreen(Canvas &c, const View &v, const std::string &title, const std::vector<std::string> &body,
                         uint16_t bodyColor) {
  const QrCache &q = qrFor(v.qr);
  int side = 0;
  if (q.n > 0) {
    const int scale = (q.n + 8) * QR_SCALE <= SCREEN_H - QR_Y - 8 ? QR_SCALE : 3;
    side = (q.n + 8) * scale;
    c.qr(q.modules, q.n, QR_X, QR_Y, scale);
    if (v.qrRatio >= 0) bar(c, QR_X, QR_Y + side + 8, side, v.qrRatio);
  }
  const int left = QR_X + side + 12, width = SCREEN_W - 8 - left, cx = left + width / 2;
  std::vector<std::string> lines;
  for (const std::string &b : body) {
    std::vector<std::string> wrapped = wrapText(FONT_BODY, b, width);
    lines.insert(lines.end(), wrapped.begin(), wrapped.end());
  }
  const int titleH = title.empty() ? 0 : 32;
  int y = QR_Y + side / 2 - (titleH + static_cast<int>(lines.size()) * 24) / 2 + 12;
  if (!title.empty()) {
    c.text(FONT_TITLE, title, cx, y, color::TEXT, Align::Center);
    y += titleH;
  }
  for (const std::string &l : lines) {
    c.text(FONT_BODY, l, cx, y, bodyColor, Align::Center);
    y += 24;
  }
}

static void drawNotice(Canvas &c, const View &v) {
  icon(c, v.icon, SCREEN_W / 2, 88);
  paragraph(c, FONT_TITLE, line(v, 0), SCREEN_W / 2, 146, 280, color::TEXT, 24, 2);
  if (v.lines.size() > 1) paragraph(c, FONT_BODY, line(v, 1), SCREEN_W / 2, 182, 280, color::MUTED, 22, 2);
}

static void drawSelect(Canvas &c, const View &v) {
  paragraph(c, FONT_TITLE, line(v, 0), SCREEN_W / 2, 84, 280, color::TEXT, 24, 2);
  paragraph(c, FONT_BODY, line(v, 1), SCREEN_W / 2, 118, 280, color::TEXT, 22, 2);
  if (v.hasCountdown) {
    c.text(FONT_SMALL, v.lines.back(), SCREEN_W / 2, 154, color::MUTED, Align::Center);
    bar(c, 40, 174, 240, v.totalMs > 0 ? static_cast<float>(v.remainingMs) / v.totalMs : 0);
  }
}

static void drawMatch(Canvas &c, const View &v) {
  c.text(FONT_TITLE, line(v, 0), SCREEN_W / 2, 56, color::TEXT, Align::Center);
  if (!v.code.empty()) c.text(FONT_HUGE, v.code, SCREEN_W / 2, 126, color::TEXT, Align::Center);
  if (v.hasCountdown) {
    c.text(FONT_SMALL, v.lines.back(), SCREEN_W / 2, 194, color::MUTED, Align::Center);
    bar(c, 40, 214, 240, v.totalMs > 0 ? static_cast<float>(v.remainingMs) / v.totalMs : 0);
  }
}

// 櫃門編號與說明在左，倒數在右。
static void drawOpen(Canvas &c, const View &v) {
  const int areaW = 176;
  const smb_font_t *f = &FONT_LABEL;
  int gap = 12;
  auto rowWidth = [&](const smb_font_t &font, size_t from, size_t count) {
    int w = 0;
    for (size_t i = from; i < from + count && i < v.doorLabels.size(); i++) w += textWidth(font, v.doorLabels[i]) + (i > from ? gap : 0);
    return w;
  };
  const size_t count = std::max<size_t>(1, v.doorLabels.size());
  size_t perRow = count;
  if (rowWidth(*f, 0, perRow) > areaW) {
    f = &FONT_LABEL_SM;
    gap = 10;
    while (perRow > 1 && rowWidth(*f, 0, perRow) > areaW) perRow--;
    const size_t rows = (count + perRow - 1) / perRow;
    perRow = (count + rows - 1) / rows;  // 各列數量平均，例如 4 扇排成 2＋2
  }
  int y = f == &FONT_LABEL ? 66 : 54, lastRow = y;
  for (size_t i = 0; i < v.doorLabels.size(); i += perRow) {
    int x = 18;
    for (size_t k = i; k < i + perRow && k < v.doorLabels.size(); k++) {
      c.text(*f, v.doorLabels[k], x, y, color::TEXT);
      x += textWidth(*f, v.doorLabels[k]) + gap;
    }
    lastRow = y;
    y += 34;
  }
  const int msgY = f == &FONT_LABEL ? 132 : std::max(132, lastRow + 44);
  if (!v.notice.empty()) paragraph(c, FONT_TITLE, v.notice, 18, msgY, 184, color::WARN, 24, 2, Align::Left);
  else paragraph(c, FONT_BODY, line(v, 1), 18, msgY, 184, color::TEXT, 24, 3, Align::Left);

  if (v.hasCountdown) {
    const float ratio = v.totalMs > 0 ? static_cast<float>(v.remainingMs) / v.totalMs : 0;
    c.ring(255, 131, 44, 5, ratio, ratio < 0.2f ? color::WARN : color::ACCENT, color::TRACK);
    c.text(FONT_RING, std::to_string((v.remainingMs + 999) / 1000), 255, 131, color::TEXT, Align::Center);
  }
}

static void drawCentered(Canvas &c, const View &v) {
  paragraph(c, FONT_TITLE, line(v, 0), SCREEN_W / 2, MID_Y - (v.lines.size() > 1 ? 14 : 0), 280, color::TEXT, 24, 2);
  if (v.lines.size() > 1) paragraph(c, FONT_SMALL, line(v, 1), SCREEN_W / 2, MID_Y + 22, 280, color::MUTED, 20, 2);
}

void ui_draw(const View &v) {
  display_frame([&](Canvas &c) {
    c.fill(color::BG);
    header(c, v);
    switch (v.screen) {
      case Screen::Pairing:
        drawPairing(c, v);
        break;
      case Screen::Idle:
        if (!v.qr.empty()) drawQrScreen(c, v, "", v.lines, color::TEXT);
        else paragraph(c, FONT_TITLE, line(v, 0), SCREEN_W / 2, MID_Y, 280, color::TEXT, 24, 2);
        break;
      case Screen::WifiSetup:
        drawQrScreen(c, v, line(v, 0), {v.lines.begin() + std::min<size_t>(1, v.lines.size()), v.lines.end()},
                     v.notice.empty() ? color::TEXT : color::WARN);
        break;
      case Screen::ClosedHours:
      case Screen::Maintenance:
      case Screen::Disabled:
      case Screen::Result:
        drawNotice(c, v);
        break;
      case Screen::Select:
        drawSelect(c, v);
        break;
      case Screen::Match:
        drawMatch(c, v);
        break;
      case Screen::Open:
      case Screen::Admin:
        drawOpen(c, v);
        break;
      default:
        drawCentered(c, v);
        break;
    }
  });
}

}  // namespace smb
