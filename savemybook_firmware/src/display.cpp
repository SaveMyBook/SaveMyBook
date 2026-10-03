#include "display.h"

#include "driver/spi_master.h"
#include "esp_attr.h"
#include "esp_heap_caps.h"
#include "esp_lcd_panel_io.h"
#include "esp_lcd_panel_ops.h"
#include "esp_lcd_panel_st7789.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"
#include "pins.h"
#include "sdkconfig.h"

namespace smb {

static const char *TAG = "display";

constexpr int BAND_H = 40;
constexpr int BANDS = SCREEN_H / BAND_H;

static esp_lcd_panel_handle_t s_panel;
static SemaphoreHandle_t s_done;
static uint16_t *s_band;
static uint32_t s_hash[BANDS];
static bool s_first = true;

// ---------- 螢幕 ----------

static bool IRAM_ATTR onTransDone(esp_lcd_panel_io_handle_t, esp_lcd_panel_io_event_data_t *, void *ctx) {
  BaseType_t woken = pdFALSE;
  xSemaphoreGiveFromISR(static_cast<SemaphoreHandle_t>(ctx), &woken);
  return woken == pdTRUE;
}

#if CONFIG_SMB_PANEL_ILI9341
// ILI9341 的電源、VCOM 與 Gamma 設定（ST7789 驅動只送睡眠喚醒、MADCTL 與像素格式）。
static void ili9341Init(esp_lcd_panel_io_handle_t io) {
  struct Cmd {
    uint8_t cmd;
    uint8_t data[15];
    uint8_t len;
  };
  static const Cmd cmds[] = {
      {0xCF, {0x00, 0xC1, 0x30}, 3},
      {0xED, {0x64, 0x03, 0x12, 0x81}, 4},
      {0xE8, {0x85, 0x00, 0x78}, 3},
      {0xCB, {0x39, 0x2C, 0x00, 0x34, 0x02}, 5},
      {0xF7, {0x20}, 1},
      {0xEA, {0x00, 0x00}, 2},
      {0xC0, {0x23}, 1},
      {0xC1, {0x10}, 1},
      {0xC5, {0x3E, 0x28}, 2},
      {0xC7, {0x86}, 1},
      {0xB1, {0x00, 0x18}, 2},
      {0xB6, {0x08, 0x82, 0x27}, 3},
      {0xF2, {0x00}, 1},
      {0x26, {0x01}, 1},
      {0xE0, {0x0F, 0x31, 0x2B, 0x0C, 0x0E, 0x08, 0x4E, 0xF1, 0x37, 0x07, 0x10, 0x03, 0x0E, 0x09, 0x00}, 15},
      {0xE1, {0x00, 0x0E, 0x14, 0x03, 0x11, 0x07, 0x31, 0xC1, 0x48, 0x08, 0x0F, 0x0C, 0x31, 0x36, 0x0F}, 15},
  };
  for (const Cmd &c : cmds) ESP_ERROR_CHECK(esp_lcd_panel_io_tx_param(io, c.cmd, c.data, c.len));
}
#endif

void display_init() {
  spi_bus_config_t bus = {};
  bus.mosi_io_num = PIN_TFT_MOSI;
  bus.miso_io_num = -1;
  bus.sclk_io_num = PIN_TFT_SCK;
  bus.quadwp_io_num = -1;
  bus.quadhd_io_num = -1;
  bus.max_transfer_sz = SCREEN_W * BAND_H * 2;
  ESP_ERROR_CHECK(spi_bus_initialize(SPI2_HOST, &bus, SPI_DMA_CH_AUTO));

  s_done = xSemaphoreCreateBinary();
  esp_lcd_panel_io_spi_config_t io_cfg = {};
  io_cfg.cs_gpio_num = PIN_TFT_CS;
  io_cfg.dc_gpio_num = PIN_TFT_DC;
  io_cfg.spi_mode = 0;
  io_cfg.pclk_hz = 40 * 1000 * 1000;
  io_cfg.trans_queue_depth = 4;
  io_cfg.on_color_trans_done = onTransDone;
  io_cfg.user_ctx = s_done;
  io_cfg.lcd_cmd_bits = 8;
  io_cfg.lcd_param_bits = 8;
  esp_lcd_panel_io_handle_t io;
  ESP_ERROR_CHECK(esp_lcd_new_panel_io_spi(static_cast<esp_lcd_spi_bus_handle_t>(SPI2_HOST), &io_cfg, &io));

  esp_lcd_panel_dev_config_t panel_cfg = {};
  panel_cfg.reset_gpio_num = PIN_TFT_RST;
  panel_cfg.rgb_ele_order = PANEL_ILI9341 ? LCD_RGB_ELEMENT_ORDER_BGR : LCD_RGB_ELEMENT_ORDER_RGB;
  panel_cfg.bits_per_pixel = 16;
  ESP_ERROR_CHECK(esp_lcd_new_panel_st7789(io, &panel_cfg, &s_panel));
  ESP_ERROR_CHECK(esp_lcd_panel_reset(s_panel));
  ESP_ERROR_CHECK(esp_lcd_panel_init(s_panel));
#if CONFIG_SMB_PANEL_ILI9341
  ili9341Init(io);
  ESP_ERROR_CHECK(esp_lcd_panel_invert_color(s_panel, false));
#else
  ESP_ERROR_CHECK(esp_lcd_panel_invert_color(s_panel, true));
#endif
  // 橫向：1 與 3 為相反的兩個方向，依螢幕排針朝哪一側裝設選擇。
  const int rotation = CONFIG_SMB_SCREEN_ROTATION;
  ESP_ERROR_CHECK(esp_lcd_panel_swap_xy(s_panel, rotation % 2 == 1));
  ESP_ERROR_CHECK(esp_lcd_panel_mirror(s_panel, rotation == 0 || rotation == 3, rotation >= 2));

  s_band = static_cast<uint16_t *>(heap_caps_malloc(SCREEN_W * BAND_H * 2, MALLOC_CAP_DMA | MALLOC_CAP_INTERNAL));
  assert(s_band);
  display_frame([](Canvas &c) { c.fill(color::BG); });
  ESP_ERROR_CHECK(esp_lcd_panel_disp_on_off(s_panel, true));
  ESP_LOGI(TAG, "panel ready, rotation %d", rotation);
}

static uint32_t fnv(const uint16_t *p, size_t n) {
  uint32_t h = 2166136261u;
  for (size_t i = 0; i < n; i++) h = (h ^ p[i]) * 16777619u;
  return h;
}

void display_frame(const std::function<void(Canvas &)> &draw) {
  for (int b = 0; b < BANDS; b++) {
    Canvas canvas(s_band, b * BAND_H, BAND_H);
    draw(canvas);
    const uint32_t h = fnv(s_band, SCREEN_W * BAND_H);
    if (!s_first && h == s_hash[b]) continue;
    s_hash[b] = h;
    ESP_ERROR_CHECK(esp_lcd_panel_draw_bitmap(s_panel, 0, b * BAND_H, SCREEN_W, (b + 1) * BAND_H, s_band));
    xSemaphoreTake(s_done, portMAX_DELAY);
  }
  s_first = false;
}

}  // namespace smb
