#include "relay.h"

#include <algorithm>

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

void relay_pulse(int channel, int ms) {
  if (channel < 1 || channel > DOOR_COUNT) return;
  ms = std::clamp(ms, 100, 3000);
  relay_all_off();
  ESP_LOGI(TAG, "channel %d on for %d ms", channel, ms);
  gpio_set_level(PIN_RELAY[channel - 1], RELAY_ON);
  vTaskDelay(pdMS_TO_TICKS(ms));
  gpio_set_level(PIN_RELAY[channel - 1], RELAY_OFF);
}

}  // namespace smb
