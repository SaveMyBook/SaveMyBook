#include <atomic>

#include "demo.h"
#include "device.h"
#include "display.h"
#include "esp_system.h"
#include "esp_task_wdt.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "pins.h"
#include "relay.h"
#include "store.h"
#include "messages.h"
#include "ui.h"
#include "wifi.h"

using namespace smb;

static Device s_device;
static std::atomic<bool> s_deviceStarted{false};

#ifndef SMB_HW_TEST
static const char *resetReason() {
  switch (esp_reset_reason()) {
    case ESP_RST_POWERON: return "power_on";
    case ESP_RST_SW: return "software";
    case ESP_RST_PANIC: return "panic";
    case ESP_RST_INT_WDT:
    case ESP_RST_TASK_WDT:
    case ESP_RST_WDT: return "watchdog";
    case ESP_RST_BROWNOUT: return "brownout";
    case ESP_RST_EXT: return "external";
    case ESP_RST_DEEPSLEEP: return "deep_sleep";
    default: return "unknown";
  }
}

// 第一次連上網路前，畫面顯示 Wi-Fi 設定或連線中。
static View wifiView() {
  View v;
  v.header = msg("TITLE");
  const WifiState state = wifi_state();
  if (state == WifiState::Provisioning || state == WifiState::ProvisionFailed) {
    v.screen = Screen::WifiSetup;
    v.qr = wifi_prov_payload();
    const bool failed = state == WifiState::ProvisionFailed;
    v.lines = {msg("WIFI_TITLE"), msg(failed ? "WIFI_FAILED" : "WIFI_SCAN")};
    if (failed) v.notice = v.lines[1];
  } else {
    v.screen = Screen::WifiConnecting;
    v.lines = {msg("WIFI_CONNECTING"), msg("WIFI_RESET_HINT")};
  }
  return v;
}

[[noreturn]] static void uiTask(void *) {
  esp_task_wdt_add(nullptr);
  for (;;) {
    esp_task_wdt_reset();
    ui_draw(s_deviceStarted ? s_device.view() : wifiView());
    vTaskDelay(pdMS_TO_TICKS(250));
  }
}

// 按住板上的 BOOT 鍵 5 秒：清除 Wi-Fi 設定後重新開機，回到藍牙設定畫面。裝置憑證保留。
[[noreturn]] static void keyTask(void *) {
  gpio_config_t cfg = {};
  cfg.pin_bit_mask = 1ULL << PIN_BOOT_KEY;
  cfg.mode = GPIO_MODE_INPUT;
  cfg.pull_up_en = GPIO_PULLUP_ENABLE;
  gpio_config(&cfg);
  int heldMs = 0;
  for (;;) {
    vTaskDelay(pdMS_TO_TICKS(100));
    heldMs = gpio_get_level(PIN_BOOT_KEY) == 0 ? heldMs + 100 : 0;
    if (heldMs >= 5000) wifi_reset_and_restart();
  }
}

#else
// 硬體測試：不連網路。先確認開機時繼電器都沒有吸合，再逐顆通電 0.8 秒，接著輪播各畫面確認螢幕方向與字型。
[[noreturn]] static void hwTest() {
  View base;
  base.header = msg("HW_TITLE");
  base.screen = Screen::HwTest;

  const std::vector<View> demos = demo_views();

  for (;;) {
    View relay = base;
    relay.lines = {msg("HW_ALL_OFF")};
    ui_draw(relay);
    vTaskDelay(pdMS_TO_TICKS(5000));
    for (int ch = 1; ch <= DOOR_COUNT; ch++) {
      relay.lines = {format("HW_RELAY_ON", {{"n", std::to_string(ch)}})};
      ui_draw(relay);
      relay_pulse(ch, 800);
      relay.lines = {msg("HW_ALL_OFF")};
      ui_draw(relay);
      vTaskDelay(pdMS_TO_TICKS(1000));
    }
    for (const View &d : demos) {
      ui_draw(d);
      vTaskDelay(pdMS_TO_TICKS(3000));
    }
  }
}
#endif

extern "C" void app_main(void) {
  relay_init();  // 第一件事：所有電磁鎖維持上鎖
  store::init();
  display_init();
#ifdef SMB_HW_TEST
  hwTest();
#else
  xTaskCreate(uiTask, "ui", 8192, nullptr, 4, nullptr);
  wifi_start();
  xTaskCreate(keyTask, "key", 3072, nullptr, 2, nullptr);
  while (!wifi_ever_connected()) vTaskDelay(pdMS_TO_TICKS(200));

  s_device.begin(resetReason());
  xTaskCreate([](void *) { s_device.runLocks(); }, "locks", 4096, nullptr, 6, nullptr);
  xTaskCreate([](void *) { s_device.runNetwork(); }, "net", 12288, nullptr, 5, nullptr);
  s_deviceStarted = true;
#endif
}
