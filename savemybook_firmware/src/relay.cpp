#include "relay.h"

#include <algorithm>

#include "display.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "pins.h"

namespace smb {

static const char *TAG = "relay";

void relay_init() {
  uint64_t mask = 0;
  for (gpio_num_t pin : PIN_RELAY) {
    gpio_set_level(pin, RELAY_OFF);
    mask |= 1ULL << pin;
  }
  gpio_config_t cfg = {};
  cfg.pin_bit_mask = mask;
  cfg.mode = GPIO_MODE_OUTPUT;
  ESP_ERROR_CHECK(gpio_config(&cfg));
  relay_all_off();
}

void relay_all_off() {
  for (gpio_num_t pin : PIN_RELAY) gpio_set_level(pin, RELAY_OFF);
}

void relay_pulse(int channel, int ms, const std::function<bool()> &stop) {
  if (channel < 1 || channel > DOOR_COUNT) return;
  ms = std::clamp(ms, 100, 3000);
  relay_all_off();
  ESP_LOGI(TAG, "channel %d on for up to %d ms", channel, ms);
  gpio_set_level(PIN_RELAY[channel - 1], RELAY_ON);
  int elapsed = 0;
  while (elapsed < ms) {
    const int step = std::min(20, ms - elapsed);
    vTaskDelay(pdMS_TO_TICKS(step));
    elapsed += step;
    if (elapsed == 100) display_recover();
    // 先通電至少 200 毫秒讓鎖舌確實縮回，之後門一拉開就斷電，線圈少發熱
    if (stop && elapsed >= 200 && stop()) break;
  }
  gpio_set_level(PIN_RELAY[channel - 1], RELAY_OFF);
  if (elapsed < ms) ESP_LOGI(TAG, "channel %d off after %d ms (door opened)", channel, elapsed);
  vTaskDelay(pdMS_TO_TICKS(50));
  display_recover();
}

}  // namespace smb
