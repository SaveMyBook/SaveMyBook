#include "display.h"

#include <algorithm>
#include <atomic>

#include "driver/ledc.h"
#include "driver/spi_master.h"
#include "esp_attr.h"
#include "esp_heap_caps.h"
#include "esp_lcd_panel_io.h"
#include "esp_lcd_panel_ops.h"
#include "esp_lcd_panel_st7789.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"
#include "pins.h"
#include "sdkconfig.h"

namespace smb {

static const char *TAG = "display";

// 每段 24 列：兩個傳送緩衝輪流使用（畫下一段時上一段仍在 DMA 傳送），轉場時另需一個畫舊畫面的緩衝，共約 45 KB。
constexpr int BAND_H = 24;
constexpr int BANDS = SCREEN_H / BAND_H;

static esp_lcd_panel_io_handle_t s_io;
static esp_lcd_panel_handle_t s_panel;
static int64_t s_lastSetup;
static std::atomic<bool> s_recover{false};
static SemaphoreHandle_t s_done;
static uint16_t *s_bands[2];
static uint16_t *s_under;

// 轉場時的混合分一半給核心 0：混合只讀寫傳入的緩衝，兩顆核心各算各的列不會互相影響
struct BlendJob {
  uint16_t *dst;
  const uint16_t *under;
  int count, alpha;
};
static BlendJob s_job;
static TaskHandle_t s_helper;
static SemaphoreHandle_t s_helperDone;

[[noreturn]] static void blendHelper(void *) {
  for (;;) {
    ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
    blend_band(s_job.dst, s_job.under, s_job.count, s_job.alpha);
    xSemaphoreGive(s_helperDone);
  }
}

static void blendParallel(uint16_t *dst, const uint16_t *under, int count, int alpha) {
  const int half = count / 2 & ~1;  // 偶數像素：混合一次處理兩個像素（4 位元組對齊）
  s_job = {dst + half, under + half, count - half, alpha};
  xTaskNotifyGive(s_helper);
  blend_band(dst, under, half, alpha);
  xSemaphoreTake(s_helperDone, portMAX_DELAY);
}
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

// 喚醒、像素格式、反相與方向。重送不會閃爍，螢幕因接觸不良或靜電重置後靠它恢復。
static void panelSetup() {
  ESP_ERROR_CHECK(esp_lcd_panel_init(s_panel));
#if CONFIG_SMB_PANEL_ILI9341
  ili9341Init(s_io);
#endif
  ESP_ERROR_CHECK(esp_lcd_panel_invert_color(s_panel, PANEL_INVERT));
  // 橫向：1 與 3 為相反的兩個方向，依螢幕排針朝哪一側裝設選擇。
  const int rotation = CONFIG_SMB_SCREEN_ROTATION;
  ESP_ERROR_CHECK(esp_lcd_panel_swap_xy(s_panel, rotation % 2 == 1));
  // 同一款螢幕不同批次的掃描方向可能相反，畫面左右顛倒時開啟 SMB_SCREEN_MIRROR
  ESP_ERROR_CHECK(esp_lcd_panel_mirror(s_panel, (rotation == 0 || rotation == 3) != SCREEN_MIRROR, rotation >= 2));
  s_lastSetup = esp_timer_get_time();
}

static void backlightInit() {
  ledc_timer_config_t timer = {};
  timer.speed_mode = LEDC_LOW_SPEED_MODE;
  timer.duty_resolution = LEDC_TIMER_10_BIT;
  timer.timer_num = LEDC_TIMER_0;
  timer.freq_hz = 5000;
  timer.clk_cfg = LEDC_AUTO_CLK;
  ESP_ERROR_CHECK(ledc_timer_config(&timer));
  ledc_channel_config_t ch = {};
  ch.gpio_num = PIN_TFT_BL;
  ch.speed_mode = LEDC_LOW_SPEED_MODE;
  ch.channel = LEDC_CHANNEL_0;
  ch.timer_sel = LEDC_TIMER_0;
  ch.duty = 1023;
  ESP_ERROR_CHECK(ledc_channel_config(&ch));
}

void display_set_brightness(int percent) {
  const uint32_t duty = static_cast<uint32_t>(std::clamp(percent, 10, 100)) * 1023 / 100;
  ledc_set_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_0, duty);
  ledc_update_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_0);
}

void display_init() {
  backlightInit();
  spi_bus_config_t bus = {};
  bus.mosi_io_num = PIN_TFT_MOSI;
  bus.miso_io_num = -1;
  bus.sclk_io_num = PIN_TFT_SCK;
  bus.quadwp_io_num = -1;
  bus.quadhd_io_num = -1;
  bus.max_transfer_sz = SCREEN_W * BAND_H * 2;
  // 傳輸完成中斷放在畫面工作所在的核心 1：核心 0 做 HTTPS 金鑰運算時會長時間關中斷，畫面曾因此卡住 0.5 秒
  bus.isr_cpu_id = ESP_INTR_CPU_AFFINITY_1;
  ESP_ERROR_CHECK(spi_bus_initialize(SPI2_HOST, &bus, SPI_DMA_CH_AUTO));

  s_done = xSemaphoreCreateCounting(8, 0);  // 每完成一筆像素傳輸加一；串流時可能連續完成好幾筆
  esp_lcd_panel_io_spi_config_t io_cfg = {};
  io_cfg.cs_gpio_num = PIN_TFT_CS;
  io_cfg.dc_gpio_num = PIN_TFT_DC;
  io_cfg.spi_mode = 0;
  // 杜邦線接到 40 MHz 時資料會出錯，整面亂碼；接線縮短或改用排線後才調高
  io_cfg.pclk_hz = CONFIG_SMB_TFT_SPI_MHZ * 1000 * 1000;
  io_cfg.trans_queue_depth = 4;
  io_cfg.on_color_trans_done = onTransDone;
  io_cfg.user_ctx = s_done;
  io_cfg.lcd_cmd_bits = 8;
  io_cfg.lcd_param_bits = 8;
  ESP_ERROR_CHECK(esp_lcd_new_panel_io_spi(static_cast<esp_lcd_spi_bus_handle_t>(SPI2_HOST), &io_cfg, &s_io));

  esp_lcd_panel_dev_config_t panel_cfg = {};
  panel_cfg.reset_gpio_num = PIN_TFT_RST;
  panel_cfg.rgb_ele_order = PANEL_ILI9341 ? LCD_RGB_ELEMENT_ORDER_BGR : LCD_RGB_ELEMENT_ORDER_RGB;
  panel_cfg.bits_per_pixel = 16;
  ESP_ERROR_CHECK(esp_lcd_new_panel_st7789(s_io, &panel_cfg, &s_panel));
  ESP_ERROR_CHECK(esp_lcd_panel_reset(s_panel));
  panelSetup();

  for (uint16_t *&b : s_bands) {
    b = static_cast<uint16_t *>(heap_caps_malloc(SCREEN_W * BAND_H * 2, MALLOC_CAP_DMA | MALLOC_CAP_INTERNAL));
    assert(b);
  }
  s_under = static_cast<uint16_t *>(heap_caps_malloc(SCREEN_W * BAND_H * 2, MALLOC_CAP_INTERNAL));
  assert(s_under);
  s_helperDone = xSemaphoreCreateBinary();
  // 優先權高於網路工作（5）：HTTPS 金鑰運算期間也能立刻幫忙，每次只做幾毫秒
  xTaskCreatePinnedToCore(blendHelper, "blend", 2048, nullptr, 6, &s_helper, 0);
  display_frame([](Canvas &c) { c.fill(color::BG); });
  ESP_ERROR_CHECK(esp_lcd_panel_disp_on_off(s_panel, true));
  ESP_LOGI(TAG, "panel ready, rotation %d, spi %d MHz", CONFIG_SMB_SCREEN_ROTATION, CONFIG_SMB_TFT_SPI_MHZ);
}

void display_recover() { s_recover = true; }

uint16_t *display_alloc_frame() {
  return static_cast<uint16_t *>(heap_caps_malloc(SCREEN_W * SCREEN_H * 2, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT));
}

static uint32_t fnv(const uint16_t *p, size_t n) {
  uint32_t h = 2166136261u;
  for (size_t i = 0; i < n; i++) h = (h ^ p[i]) * 16777619u;
  return h;
}

// 設定寫入範圍：整列寬，y0 到畫面底部（之後的資料依序往下寫，下一個指令前都有效）。
static void setWindow(int y0) {
  const uint8_t caset[] = {0, 0, static_cast<uint8_t>((SCREEN_W - 1) >> 8), static_cast<uint8_t>((SCREEN_W - 1) & 0xFF)};
  const uint8_t raset[] = {static_cast<uint8_t>(y0 >> 8), static_cast<uint8_t>(y0 & 0xFF), static_cast<uint8_t>((SCREEN_H - 1) >> 8),
                           static_cast<uint8_t>((SCREEN_H - 1) & 0xFF)};
  ESP_ERROR_CHECK(esp_lcd_panel_io_tx_param(s_io, 0x2A, caset, sizeof(caset)));
  ESP_ERROR_CHECK(esp_lcd_panel_io_tx_param(s_io, 0x2B, raset, sizeof(raset)));
}

void display_frame(const std::function<void(Canvas &)> &draw, const std::function<void(Canvas &)> &under, int underAlpha,
                   int fromY, int toY, bool compare) {
  // 螢幕無法回讀狀態：電磁鎖動作後與每 10 秒重送設定並整面重畫，鬆脫或重置後自動恢復
  if (!s_first && (s_recover.exchange(false) || esp_timer_get_time() - s_lastSetup > 10 * 1000000LL)) {
    panelSetup();
    ESP_ERROR_CHECK(esp_lcd_panel_disp_on_off(s_panel, true));
    s_first = true;
  }
  // 連續變動的段落一次設定寫入範圍後串流送出（不帶指令的資料傳輸會直接排入 DMA 佇列），
  // 送出這段時同時畫下一段；兩個緩衝輪流使用，畫之前確認該緩衝已傳完。
  int cur = 0, inflight = 0, last = -2;
  auto waitOne = [&] {
    xSemaphoreTake(s_done, portMAX_DELAY);
    inflight--;
  };
  for (int b = 0; b < BANDS; b++) {
    if (!s_first && ((b + 1) * BAND_H <= fromY || b * BAND_H >= toY)) continue;
    if (inflight >= 2) waitOne();  // 最舊的一筆就是這個緩衝
    uint16_t *buf = s_bands[cur];
    Canvas canvas(buf, b * BAND_H, BAND_H);
    draw(canvas);
    if (under && underAlpha > 0) {
      Canvas old(s_under, b * BAND_H, BAND_H);
      under(old);
      blendParallel(buf, s_under, SCREEN_W * BAND_H, underAlpha);
    }
    if (compare) {
      const uint32_t h = fnv(buf, SCREEN_W * BAND_H);
      if (!s_first && h == s_hash[b]) continue;
      s_hash[b] = h;
    } else {
      s_hash[b] = 0;  // 未記錄內容：下一次比對一定視為改變而重送
    }
    if (last == b - 1) {
      ESP_ERROR_CHECK(esp_lcd_panel_io_tx_color(s_io, -1, buf, SCREEN_W * BAND_H * 2));
    } else {
      setWindow(b * BAND_H);  // 送指令前驅動程式會先等佇列清空
      ESP_ERROR_CHECK(esp_lcd_panel_io_tx_color(s_io, 0x2C, buf, SCREEN_W * BAND_H * 2));
    }
    inflight++;
    last = b;
    cur ^= 1;
  }
  while (inflight > 0) waitOne();
  s_first = false;
}

}  // namespace smb
