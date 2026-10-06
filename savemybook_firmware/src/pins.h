#pragma once

// GOOUUU ESP32-S3（與 YD-ESP32-S3、ESP32-S3-DevKitC-1 同腳位）。以下腳位都在有 5V、3V3 的那一排排針上。
// 避開：GPIO0、3、45、46（開機設定）、19、20（USB）、26–37（Flash 與 PSRAM）、43、44（序列埠）。

#include "driver/gpio.h"
#include "sdkconfig.h"

namespace smb {

constexpr int DOOR_COUNT = 4;

// 四路繼電器 IN1–IN4，依序對應櫃門 A01–A04（電磁鎖通道 1–4）。開機重置期間為高阻抗，低電平觸發的模組不會吸合。
constexpr gpio_num_t PIN_RELAY[DOOR_COUNT] = {GPIO_NUM_4, GPIO_NUM_5, GPIO_NUM_6, GPIO_NUM_7};

// 2.8 吋 TFT（SPI2 的 IO MUX 腳位）。SDO、觸控與 SD 卡都不接。
constexpr gpio_num_t PIN_TFT_RST = GPIO_NUM_8;
constexpr gpio_num_t PIN_TFT_DC = GPIO_NUM_9;
constexpr gpio_num_t PIN_TFT_CS = GPIO_NUM_10;
constexpr gpio_num_t PIN_TFT_MOSI = GPIO_NUM_11;
constexpr gpio_num_t PIN_TFT_SCK = GPIO_NUM_12;
// 背光 LED 以 PWM 調亮度。螢幕模組 LED 腳若沒有電晶體（板上標 Q1），背光電流超過 GPIO 上限，須另加電晶體。
constexpr gpio_num_t PIN_TFT_BL = GPIO_NUM_13;

// 櫃門微動開關 A01–A04（右側排針）。避開 GPIO38、48：部分開發板接了 RGB 燈。
constexpr gpio_num_t PIN_DOOR[DOOR_COUNT] = {GPIO_NUM_39, GPIO_NUM_40, GPIO_NUM_41, GPIO_NUM_42};

// 板上的 BOOT 鍵，按住 5 秒重設 Wi-Fi。
constexpr gpio_num_t PIN_BOOT_KEY = GPIO_NUM_0;

#if CONFIG_SMB_PANEL_ILI9341
constexpr bool PANEL_ILI9341 = true;
#else
constexpr bool PANEL_ILI9341 = false;
#endif

#if CONFIG_SMB_PANEL_INVERT
constexpr bool PANEL_INVERT = true;
#else
constexpr bool PANEL_INVERT = false;
#endif

#if CONFIG_SMB_SCREEN_MIRROR
constexpr bool SCREEN_MIRROR = true;
#else
constexpr bool SCREEN_MIRROR = false;
#endif

#if CONFIG_SMB_DOOR_SENSOR
constexpr bool DOOR_SENSOR = true;
constexpr int DOOR_CLOSED_LEVEL = CONFIG_SMB_DOOR_CLOSED_LEVEL;
#else
constexpr bool DOOR_SENSOR = false;
constexpr int DOOR_CLOSED_LEVEL = 0;
#endif

#if CONFIG_SMB_RELAY_ACTIVE_LOW
constexpr int RELAY_ON = 0;
#else
constexpr int RELAY_ON = 1;
#endif
constexpr int RELAY_OFF = 1 - RELAY_ON;

}  // namespace smb
