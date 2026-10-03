"""產生書櫃螢幕用的點陣字型 src/fonts.c、src/fonts.h。

只收錄 src/messages.h 用到的字與 ASCII，字型取自 App 使用的 Noto Sans TC。
用法：python3 tools/make_fonts.py（需要 Pillow）。
"""
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONT_DIR = ROOT.parent / "savemybook_app" / "assets" / "fonts"
REGULAR = FONT_DIR / "NotoSansTC-Regular.ttf"
MEDIUM = FONT_DIR / "NotoSansTC-Medium.ttf"

DIGITS = "0123456789"
ASCII = "".join(chr(c) for c in range(0x20, 0x7F))
# 執行時才組出的字：多扇櫃門的標籤以「、」連接（與模擬書櫃相同）。
RUNTIME = "、"


def text_chars():
    source = (ROOT / "src" / "messages.h").read_text(encoding="utf-8")
    chars = set(ASCII)
    for literal in re.findall(r'"((?:[^"\\]|\\.)*)"', source):
        chars.update(literal)
    chars.discard("｜")  # 斷行標記，不繪製
    chars.update(RUNTIME)
    return "".join(sorted(chars))


FONTS = [
    ("FONT_SMALL", REGULAR, 13, None),
    ("FONT_BODY", REGULAR, 15, None),
    ("FONT_TITLE", MEDIUM, 16, None),
    ("FONT_CODE", MEDIUM, 38, DIGITS + "-"),
    ("FONT_LABEL", MEDIUM, 44, "A" + DIGITS),
    ("FONT_LABEL_SM", MEDIUM, 28, "A" + DIGITS),
    ("FONT_RING", MEDIUM, 34, DIGITS),
    ("FONT_HUGE", MEDIUM, 96, DIGITS),
]


def render(path, size, chars):
    font = ImageFont.truetype(str(path), size)
    ascent, descent = font.getmetrics()
    glyphs, bitmap = [], bytearray()
    for ch in sorted(set(chars)):
        adv = round(font.getlength(ch))
        left, top, right, bottom = font.getbbox(ch, anchor="ls")
        w, h = right - left, bottom - top
        if w <= 0 or h <= 0:
            glyphs.append((ord(ch), 0, 0, 0, 0, adv, len(bitmap)))
            continue
        img = Image.new("L", (w, h), 0)
        ImageDraw.Draw(img).text((-left, -top), ch, font=font, fill=255, anchor="ls")
        glyphs.append((ord(ch), w, h, left, top, adv, len(bitmap)))
        bitmap.extend(img.tobytes())
    for cp, w, h, dx, dy, adv, _ in glyphs:
        assert cp <= 0xFFFF and w <= 255 and h <= 255 and -128 <= dx <= 127 and -128 <= dy <= 127 and adv <= 255, chr(cp)
    return ascent, descent, glyphs, bitmap


def main():
    chars = text_chars()
    out = [
        "// 由 tools/make_fonts.py 產生，請勿手動修改。",
        '#include "fonts.h"',
        "",
    ]
    for name, path, size, subset in FONTS:
        ascent, descent, glyphs, bitmap = render(path, size, subset or chars)
        ident = name.lower()
        out.append(f"static const uint8_t {ident}_bitmap[] = {{")
        for i in range(0, len(bitmap), 24):
            out.append("  " + ",".join(str(b) for b in bitmap[i:i + 24]) + ",")
        out.append("};")
        out.append(f"static const smb_glyph_t {ident}_glyphs[] = {{")
        for cp, w, h, dx, dy, adv, off in glyphs:
            out.append(f"  {{0x{cp:04X}, {w}, {h}, {dx}, {dy}, {adv}, {off}}},")
        out.append("};")
        out.append(
            f"const smb_font_t {name} = {{{size}, {ascent}, {descent}, {len(glyphs)}, {ident}_glyphs, {ident}_bitmap}};"
        )
        out.append("")
        print(f"{name}: {size}px, {len(glyphs)} glyphs, {len(bitmap)} bytes")
    (ROOT / "src" / "fonts.c").write_text("\n".join(out), encoding="utf-8")

    header = [
        "// 由 tools/make_fonts.py 產生，請勿手動修改。",
        "#pragma once",
        "#include <stdint.h>",
        "",
        "#ifdef __cplusplus",
        'extern "C" {',
        "#endif",
        "",
        "// dx、dy 為點陣左上角相對於基線起點的位移，dy 為負代表在基線之上。",
        "typedef struct { uint16_t cp; uint8_t w, h; int8_t dx, dy; uint8_t adv; uint32_t off; } smb_glyph_t;",
        "typedef struct { uint8_t size, ascent, descent; uint16_t count; const smb_glyph_t *glyphs; const uint8_t *bitmap; } smb_font_t;",
        "",
    ]
    header += [f"extern const smb_font_t {name};" for name, *_ in FONTS]
    header += ["", "#ifdef __cplusplus", "}", "#endif", ""]
    (ROOT / "src" / "fonts.h").write_text("\n".join(header), encoding="utf-8")


if __name__ == "__main__":
    main()
