#include "door.h"

#include <atomic>
#include <mutex>

#include "driver/gpio.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "pins.h"

namespace smb {

static const char *TAG = "door";

// 每 20 毫秒取樣，連續 5 次相同才算改變：電磁鎖通斷的突波會在長線上感應出短暫雜訊。
constexpr int SAMPLE_MS = 20;
constexpr int STABLE_SAMPLES = 5;

static std::atomic<bool> s_open[DOOR_COUNT + 1];
static std::mutex s_cbMu;
static std::function<void(int, bool)> s_cb;

static bool readOpen(int channel) { return gpio_get_level(PIN_DOOR[channel - 1]) != DOOR_CLOSED_LEVEL; }

[[noreturn]] static void doorTask(void *) {
  int streak[DOOR_COUNT + 1] = {};
  for (;;) {
    vTaskDelay(pdMS_TO_TICKS(SAMPLE_MS));
    for (int ch = 1; ch <= DOOR_COUNT; ch++) {
      const bool now = readOpen(ch);
      if (now == s_open[ch].load()) {
        streak[ch] = 0;
        continue;
      }
      if (++streak[ch] < STABLE_SAMPLES) continue;
      streak[ch] = 0;
      s_open[ch] = now;
      ESP_LOGI(TAG, "A0%d %s (level %d)", ch, now ? "open" : "closed", gpio_get_level(PIN_DOOR[ch - 1]));
      std::function<void(int, bool)> cb;
      {
        std::lock_guard<std::mutex> g(s_cbMu);
        cb = s_cb;
      }
      if (cb) cb(ch, now);
    }
  }
}

void door_init() {
  for (int ch = 1; ch <= DOOR_COUNT; ch++) s_open[ch] = false;
  if (!DOOR_SENSOR) return;
  uint64_t mask = 0;
  for (gpio_num_t pin : PIN_DOOR) mask |= 1ULL << pin;
  gpio_config_t cfg = {};
  cfg.pin_bit_mask = mask;
  cfg.mode = GPIO_MODE_INPUT;
  cfg.pull_up_en = GPIO_PULLUP_ENABLE;
  ESP_ERROR_CHECK(gpio_config(&cfg));
  vTaskDelay(pdMS_TO_TICKS(10));
  for (int ch = 1; ch <= DOOR_COUNT; ch++) s_open[ch] = readOpen(ch);
  xTaskCreate(doorTask, "door", 3072, nullptr, 5, nullptr);
}

bool door_open(int channel) { return channel >= 1 && channel <= DOOR_COUNT && s_open[channel].load(); }

int door_raw(int channel) {
  if (!DOOR_SENSOR || channel < 1 || channel > DOOR_COUNT) return -1;
  return gpio_get_level(PIN_DOOR[channel - 1]);
}

void door_on_change(std::function<void(int, bool)> cb) {
  std::lock_guard<std::mutex> g(s_cbMu);
  s_cb = std::move(cb);
}

}  // namespace smb
