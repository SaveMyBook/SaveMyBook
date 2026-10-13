// 在電腦上輸出書櫃各畫面的實際像素（與韌體共用 canvas.cpp、ui.cpp、字型），用來檢查橫向版面。
// 用法：bash tools/preview/run.sh，輸出到 tools/preview/out/。
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>

#include "demo.h"
#include "display.h"
#include "ui.h"

namespace smb {
static std::vector<uint16_t> s_frame(SCREEN_W *SCREEN_H);

// 環境變數 NOCACHE 設定時模擬沒有 PSRAM（每段整個重畫），用來比對兩種畫法結果相同。
uint16_t *display_alloc_frame() { return getenv("NOCACHE") ? nullptr : new uint16_t[SCREEN_W * SCREEN_H]; }

void display_frame(const std::function<void(Canvas &)> &draw, const std::function<void(Canvas &)> &under, int underAlpha, int,
                   int, bool) {
  const int bandH = 24;
  std::vector<uint16_t> band(SCREEN_W * bandH), old(SCREEN_W * bandH);
  for (int y0 = 0; y0 < SCREEN_H; y0 += bandH) {
    Canvas c(band.data(), y0, bandH);
    draw(c);
    if (under && underAlpha > 0) {
      Canvas o(old.data(), y0, bandH);
      under(o);
      blend_band(band.data(), old.data(), SCREEN_W * bandH, underAlpha);
    }
    for (int i = 0; i < SCREEN_W * bandH; i++) s_frame[y0 * SCREEN_W + i] = static_cast<uint16_t>((band[i] << 8) | (band[i] >> 8));
  }
}
}  // namespace smb

// RGB565 換回 8 位元時補上低位元（白色為 255，不是 248），顏色才與螢幕一致。
static void savePpm(const std::string &path) {
  FILE *f = fopen(path.c_str(), "wb");
  fprintf(f, "P6\n%d %d\n255\n", smb::SCREEN_W, smb::SCREEN_H);
  for (uint16_t px : smb::s_frame) {
    const int r = px >> 11, g = (px >> 5) & 0x3F, b = px & 0x1F;
    const unsigned char rgb[3] = {static_cast<unsigned char>((r << 3) | (r >> 2)), static_cast<unsigned char>((g << 2) | (g >> 4)),
                                  static_cast<unsigned char>((b << 3) | (b >> 2))};
    fwrite(rgb, 1, 3, f);
  }
  fclose(f);
}

int main(int argc, char **argv) {
  const std::string dir = argc > 1 ? argv[1] : "out";
  const std::vector<smb::View> views = smb::demo_views();
  for (size_t n = 0; n < views.size(); n++) {
    smb::ui_draw(views[n]);
    char path[512];
    snprintf(path, sizeof(path), "%s/%02zu.ppm", dir.c_str(), n);
    savePpm(path);
  }
  printf("%zu screens\n", views.size());
  // 動畫：待機畫面轉到選擇項目、再轉到作業完成，每 40 毫秒一格，輸出到 anim/
  if (argc > 2) {
    const std::string anim = argv[2];
    const size_t seq[] = {1, 8, 6};
    uint32_t tick = 1000;
    int frame = 0;
    for (size_t k = 0; k < 3; k++) {
      for (int i = 0; i < (k == 0 ? 1 : 16); i++, tick += 40) {
        smb::View v = views[seq[k]];
        v.tick = tick;
        smb::ui_draw(v);
        char path[512];
        snprintf(path, sizeof(path), "%s/%03d.ppm", anim.c_str(), frame++);
        savePpm(path);
      }
    }
    printf("%d animation frames\n", frame);
  }
  return 0;
}
