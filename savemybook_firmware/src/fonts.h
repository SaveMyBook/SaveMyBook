// 由 tools/make_fonts.py 產生，請勿手動修改。
#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// dx、dy 為點陣左上角相對於基線起點的位移，dy 為負代表在基線之上。
typedef struct { uint16_t cp; uint8_t w, h; int8_t dx, dy; uint8_t adv; uint32_t off; } smb_glyph_t;
typedef struct { uint8_t size, ascent, descent; uint16_t count; const smb_glyph_t *glyphs; const uint8_t *bitmap; } smb_font_t;

extern const smb_font_t FONT_SMALL;
extern const smb_font_t FONT_BODY;
extern const smb_font_t FONT_TITLE;
extern const smb_font_t FONT_CODE;
extern const smb_font_t FONT_LABEL;
extern const smb_font_t FONT_LABEL_SM;
extern const smb_font_t FONT_RING;
extern const smb_font_t FONT_HUGE;

#ifdef __cplusplus
}
#endif
