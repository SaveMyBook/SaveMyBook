#include "boardtest.h"

#include <atomic>
#include <cstdlib>
#include <string>

#include "display.h"
#include "door.h"
#include "driver/usb_serial_jtag.h"
#include "driver/usb_serial_jtag_vfs.h"
#include "esp_chip_info.h"
#include "esp_flash.h"
#include "esp_log.h"
#include "esp_mac.h"
#include "esp_system.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "freertos/task.h"
#include "messages.h"
#include "pins.h"
#include "relay.h"

namespace smb {

static const char *TAG = "board";

// 自動模式：A01→A04 每顆通電 1 秒、間隔 2 秒，四顆跑完停 3 秒。
constexpr int AUTO_ON_MS = 1000;
constexpr int AUTO_GAP_MS = 2000;
constexpr int AUTO_ROUND_GAP_MS = 3000;

struct Pulse {
  int channel;
  int ms;
};

static QueueHandle_t s_queue;
static std::atomic<int> s_active{0};  // 目前通電的通道，0 為全部斷電
static std::atomic<bool> s_auto{true};
static std::atomic<int> s_brightness{100};
static std::atomic<int> s_pulses[DOOR_COUNT + 1];

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
    case ESP_RST_USB: return "usb";
    default: return "unknown";
  }
}

static void printStatus() {
  std::string doors;
  for (int ch = 1; ch <= DOOR_COUNT; ch++)
    doors += " A0" + std::to_string(ch) + "=" + (door_open(ch) ? "open" : "closed") + "(GPIO" +
             std::to_string(PIN_DOOR[ch - 1]) + "=" + std::to_string(door_raw(ch)) + ")";
  const int active = s_active.load();
  const std::string relay = active ? "CH" + std::to_string(active) + " ON" : "all off";
  ESP_LOGI(TAG, "doors%s | relay %s | auto %s | backlight %d%% | pulses %d/%d/%d/%d", doors.c_str(), relay.c_str(),
           s_auto ? "on" : "off",
           s_brightness.load(), s_pulses[1].load(), s_pulses[2].load(), s_pulses[3].load(), s_pulses[4].load());
}

static void printBanner() {
  esp_chip_info_t chip;
  esp_chip_info(&chip);
  uint32_t flash = 0;
  esp_flash_get_size(nullptr, &flash);
  uint8_t mac[6];
  esp_read_mac(mac, ESP_MAC_WIFI_STA);
  ESP_LOGI(TAG, "==== DoorLock Rev A board test ====");
  ESP_LOGI(TAG, "chip rev v%d.%d, %d cores, flash %lu MB, MAC %02X:%02X:%02X:%02X:%02X:%02X, reset %s",
           chip.revision / 100, chip.revision % 100, chip.cores, static_cast<unsigned long>(flash >> 20), mac[0], mac[1],
           mac[2], mac[3], mac[4], mac[5], resetReason());
  ESP_LOGI(TAG, "relay IN1-4 = GPIO%d/%d/%d/%d (active %s)", PIN_RELAY[0], PIN_RELAY[1], PIN_RELAY[2], PIN_RELAY[3],
           RELAY_ON ? "high" : "low");
  ESP_LOGI(TAG, "TFT RST/DC/CS/MOSI/SCK/LED = GPIO%d/%d/%d/%d/%d/%d", PIN_TFT_RST, PIN_TFT_DC, PIN_TFT_CS, PIN_TFT_MOSI,
           PIN_TFT_SCK, PIN_TFT_BL);
  ESP_LOGI(TAG, "door A01-A04 = GPIO%d/%d/%d/%d (closed level %d)", PIN_DOOR[0], PIN_DOOR[1], PIN_DOOR[2], PIN_DOOR[3],
           DOOR_CLOSED_LEVEL);
  ESP_LOGI(TAG, "commands: 1-4 pulse 1s | h1-h4 pulse 3s | all | a auto on | s auto off | b<10-100> backlight | d status");
}

// 繼電器只由這個工作驅動，序列埠指令與自動模式不會同時通電兩顆。
[[noreturn]] static void relayTask(void *) {
  int next = 1;
  int64_t due = esp_timer_get_time() + 3000 * 1000LL;  // 開機先停 3 秒，確認全部斷電
  for (;;) {
    Pulse p;
    if (xQueueReceive(s_queue, &p, pdMS_TO_TICKS(50)) != pdTRUE) {
      if (!s_auto || esp_timer_get_time() < due) continue;
      p = {next, AUTO_ON_MS};
      next = next % DOOR_COUNT + 1;
      due = esp_timer_get_time() + (AUTO_ON_MS + (next == 1 ? AUTO_ROUND_GAP_MS : AUTO_GAP_MS)) * 1000LL;
    }
    ESP_LOGI(TAG, "CH%d (A0%d, GPIO%d) ON %d ms", p.channel, p.channel, PIN_RELAY[p.channel - 1], p.ms);
    s_active = p.channel;
    s_pulses[p.channel]++;
    relay_pulse(p.channel, p.ms);
    s_active = 0;
    ESP_LOGI(TAG, "CH%d OFF", p.channel);
  }
}

static void handleCommand(std::string cmd) {
  while (!cmd.empty() && (cmd.back() == ' ' || cmd.back() == '\r')) cmd.pop_back();
  if (cmd.empty()) return;
  if (cmd.size() == 1 && cmd[0] >= '1' && cmd[0] <= '4') {
    Pulse p{cmd[0] - '0', 1000};
    xQueueSend(s_queue, &p, 0);
  } else if (cmd.size() == 2 && cmd[0] == 'h' && cmd[1] >= '1' && cmd[1] <= '4') {
    Pulse p{cmd[1] - '0', 3000};
    xQueueSend(s_queue, &p, 0);
  } else if (cmd == "all") {
    for (int ch = 1; ch <= DOOR_COUNT; ch++) {
      Pulse p{ch, 1000};
      xQueueSend(s_queue, &p, 0);
    }
  } else if (cmd == "a") {
    s_auto = true;
    ESP_LOGI(TAG, "auto on");
  } else if (cmd == "s") {
    s_auto = false;
    ESP_LOGI(TAG, "auto off");
  } else if (cmd[0] == 'b' && cmd.size() > 1) {
    s_brightness = std::atoi(cmd.c_str() + 1);
    display_set_brightness(s_brightness);
    ESP_LOGI(TAG, "backlight %d%%", s_brightness.load());
  } else if (cmd == "d") {
    printStatus();
  } else {
    ESP_LOGW(TAG, "unknown command '%s'", cmd.c_str());
  }
}

// 指令從 USB 孔（USB Serial/JTAG）輸入，每行一個。
[[noreturn]] static void serialTask(void *) {
  std::string line;
  uint8_t buf[32];
  for (;;) {
    const int n = usb_serial_jtag_read_bytes(buf, sizeof(buf), pdMS_TO_TICKS(100));
    for (int i = 0; i < n; i++) {
      if (buf[i] == '\n') {
        handleCommand(line);
        line.clear();
      } else if (line.size() < 32) {
        line += static_cast<char>(buf[i]);
      }
    }
  }
}

// 板上的 BOOT 鍵：按一下切換自動模式，方便只測門磁時讓繼電器停下來。
[[noreturn]] static void keyTask(void *) {
  gpio_config_t cfg = {};
  cfg.pin_bit_mask = 1ULL << PIN_BOOT_KEY;
  cfg.mode = GPIO_MODE_INPUT;
  cfg.pull_up_en = GPIO_PULLUP_ENABLE;
  gpio_config(&cfg);
  int last = 1;
  for (;;) {
    vTaskDelay(pdMS_TO_TICKS(50));
    const int now = gpio_get_level(PIN_BOOT_KEY);
    if (last == 1 && now == 0) {
      s_auto = !s_auto;
      ESP_LOGI(TAG, "BOOT key: auto %s", s_auto ? "on" : "off");
    }
    last = now;
  }
}

static void draw(Canvas &c) {
  c.fill(color::BG);
  c.rect(0, 0, SCREEN_W, 28, color::HEADER);
  c.text(FONT_TITLE, msg("HW_TITLE"), 10, 14, color::TEXT);
  c.text(FONT_SMALL, "DoorLock Rev A", SCREEN_W - 10, 14, color::MUTED, Align::Right);

  // 色條：文字標示應有的顏色，R、B 對調或反相時一眼看得出來
  struct Bar {
    uint16_t c;
    const char *label;
    uint16_t ink;
  };
  static const Bar bars[] = {{rgb(0xff0000), "R", color::WHITE}, {rgb(0x00ff00), "G", color::BLACK},
                             {rgb(0x0000ff), "B", color::WHITE}, {color::WHITE, "W", color::BLACK},
                             {color::BLACK, "K", color::WHITE},  {rgb(0x808080), "50%", color::BLACK}};
  const int bw = SCREEN_W / 6;
  for (int i = 0; i < 6; i++) {
    const int x = i * bw, w = i == 5 ? SCREEN_W - x : bw;
    c.rect(x, 32, w, 22, bars[i].c);
    c.text(FONT_SMALL, bars[i].label, x + w / 2, 43, bars[i].ink, Align::Center);
  }

  // 四扇門：底色為門磁狀態（關＝綠、開＝黃），通電中的那格加白框
  const int active = s_active.load();
  for (int ch = 1; ch <= DOOR_COUNT; ch++) {
    const int x = 4 + (ch - 1) * 79, y = 60, w = 74, h = 104;
    const bool open = door_open(ch);
    if (ch == active) c.rect(x - 3, y - 3, w + 6, h + 6, color::WHITE);
    c.rect(x, y, w, h, open ? color::WARN : color::ACCENT);
    c.text(FONT_LABEL_SM, "A0" + std::to_string(ch), x + w / 2, y + 22, color::BLACK, Align::Center);
    c.text(FONT_BODY, msg(open ? "HW_DOOR_OPEN" : "HW_DOOR_CLOSED"), x + w / 2, y + 54, color::BLACK, Align::Center);
    c.text(FONT_SMALL, "IO" + std::to_string(PIN_DOOR[ch - 1]) + "=" + std::to_string(door_raw(ch)), x + w / 2, y + 82,
           color::BLACK, Align::Center);
  }

  const std::string relay = active ? format("HW_RELAY_ON", {{"n", std::to_string(active)}}) : msg("HW_ALL_OFF");
  c.text(FONT_BODY, relay, SCREEN_W / 2, 190, active ? color::WARN : color::TEXT, Align::Center);

  const int up = static_cast<int>(esp_timer_get_time() / 1000000);
  c.text(FONT_SMALL, std::string(s_auto ? "AUTO" : "MANUAL") + "  BL " + std::to_string(s_brightness.load()) + "%", 10,
         224, color::MUTED);
  c.text(FONT_SMALL, "up " + std::to_string(up) + "s", SCREEN_W - 10, 224, color::MUTED, Align::Right);
}

void board_test() {
  usb_serial_jtag_driver_config_t usj = USB_SERIAL_JTAG_DRIVER_CONFIG_DEFAULT();
  if (usb_serial_jtag_driver_install(&usj) == ESP_OK) usb_serial_jtag_vfs_use_driver();
  printBanner();
  s_queue = xQueueCreate(8, sizeof(Pulse));
  xTaskCreate(relayTask, "relay", 4096, nullptr, 6, nullptr);
  xTaskCreate(serialTask, "serial", 4096, nullptr, 3, nullptr);
  xTaskCreate(keyTask, "key", 2048, nullptr, 2, nullptr);
  int64_t lastStatus = 0;
  for (;;) {
    display_frame(draw);
    if (esp_timer_get_time() - lastStatus > 5000000) {
      lastStatus = esp_timer_get_time();
      printStatus();
    }
    vTaskDelay(pdMS_TO_TICKS(100));
  }
}

}  // namespace smb
