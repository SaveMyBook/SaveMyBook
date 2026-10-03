// 在電腦上輸出書櫃各畫面的實際像素（與韌體共用 canvas.cpp、ui.cpp、字型），用來檢查橫向版面。
// 用法：bash tools/preview/run.sh，輸出到 tools/preview/out/。
#include <cstdio>
#include <string>
#include <vector>

#include "demo.h"
#include "display.h"
#include "ui.h"

namespace smb {
static std::vector<uint16_t> s_frame(SCREEN_W *SCREEN_H);

void display_frame(const std::function<void(Canvas &)> &draw) {
  const int bandH = 40;
  std::vector<uint16_t> band(SCREEN_W * bandH);
  for (int y0 = 0; y0 < SCREEN_H; y0 += bandH) {
    Canvas c(band.data(), y0, bandH);
    draw(c);
    for (int i = 0; i < SCREEN_W * bandH; i++) s_frame[y0 * SCREEN_W + i] = static_cast<uint16_t>((band[i] << 8) | (band[i] >> 8));
  }
}
}  // namespace smb

int main(int argc, char **argv) {
  const std::string dir = argc > 1 ? argv[1] : "out";
  const std::vector<smb::View> views = smb::demo_views();
  for (size_t n = 0; n < views.size(); n++) {
    smb::ui_draw(views[n]);
    char path[512];
    snprintf(path, sizeof(path), "%s/%02zu.ppm", dir.c_str(), n);
    FILE *f = fopen(path, "wb");
    fprintf(f, "P6\n%d %d\n255\n", smb::SCREEN_W, smb::SCREEN_H);
    for (uint16_t px : smb::s_frame) {
      const unsigned char rgb[3] = {static_cast<unsigned char>((px >> 11) << 3), static_cast<unsigned char>(((px >> 5) & 0x3F) << 2),
                                    static_cast<unsigned char>((px & 0x1F) << 3)};
      fwrite(rgb, 1, 3, f);
    }
    fclose(f);
  }
  printf("%zu screens\n", views.size());
  return 0;
}
