"""產生頁首的書本標誌 src/logo.c、src/logo.h（取自模擬書櫃的 book-slate-128.png，RGB565 加 8 位元透明度）。

用法：python3 tools/make_logo.py（需要 Pillow）。
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT.parent / "savemybook_api" / "views" / "kiosk" / "book-slate-128.png"
HEIGHT = 16


def main():
    img = Image.open(SOURCE).convert("RGBA")
    img = img.crop(img.getchannel("A").getbbox())
    width = round(img.width * HEIGHT / img.height)
    # 以預乘透明度縮小，邊緣不會混入透明像素的顏色
    small = img.convert("RGBa").resize((width, HEIGHT), Image.LANCZOS).convert("RGBA")
    rgb, alpha = [], []
    data = small.tobytes()
    for i in range(0, len(data), 4):
        r, g, b, a = data[i:i + 4]
        rgb.append(((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3))
        alpha.append(a)
    out = [
        "// 由 tools/make_logo.py 產生，請勿手動修改。",
        '#include "logo.h"',
        "",
        "const uint16_t LOGO_RGB[] = {",
        *("  " + ",".join(f"0x{v:04X}" for v in rgb[i:i + 12]) + "," for i in range(0, len(rgb), 12)),
        "};",
        "const uint8_t LOGO_ALPHA[] = {",
        *("  " + ",".join(str(v) for v in alpha[i:i + 24]) + "," for i in range(0, len(alpha), 24)),
        "};",
        "",
    ]
    (ROOT / "src" / "logo.c").write_text("\n".join(out), encoding="utf-8")
    header = [
        "// 由 tools/make_logo.py 產生，請勿手動修改。",
        "#pragma once",
        "#include <stdint.h>",
        "",
        "#ifdef __cplusplus",
        'extern "C" {',
        "#endif",
        "",
        f"#define LOGO_W {width}",
        f"#define LOGO_H {HEIGHT}",
        "extern const uint16_t LOGO_RGB[];",
        "extern const uint8_t LOGO_ALPHA[];",
        "",
        "#ifdef __cplusplus",
        "}",
        "#endif",
        "",
    ]
    (ROOT / "src" / "logo.h").write_text("\n".join(header), encoding="utf-8")
    print(f"logo {width}x{HEIGHT}")


if __name__ == "__main__":
    main()
