// 電腦上的 FreeRTOS、計時器、NVS、繼電器與 HTTPS 替身，讓 src/device.cpp 原封不動在電腦上執行。
#include "host.h"

#include <algorithm>
#include <chrono>
#include <condition_variable>
#include <cstring>
#include <deque>
#include <mutex>
#include <random>
#include <thread>
#include <vector>

#include "display.h"
#include "door.h"
#include "esp_random.h"
#include "relay.h"
#include "esp_timer.h"
#include "freertos/queue.h"
#include "freertos/task.h"
#include "http.h"
#include "relay.h"
#include "store.h"

static const auto START = std::chrono::steady_clock::now();
int64_t esp_timer_get_time(void) {
  return std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now() - START).count();
}

uint32_t esp_random(void) {
  static std::mt19937 rng{std::random_device{}()};
  return rng();
}

struct HostTask {
  std::mutex mu;
  std::condition_variable cv;
  uint32_t count = 0;
};

TaskHandle_t xTaskGetCurrentTaskHandle(void) {
  thread_local HostTask task;
  return &task;
}

BaseType_t xTaskNotifyGive(TaskHandle_t t) {
  std::lock_guard<std::mutex> g(t->mu);
  t->count++;
  t->cv.notify_all();
  return pdTRUE;
}

uint32_t ulTaskNotifyTake(BaseType_t clear, TickType_t ticks) {
  HostTask *t = xTaskGetCurrentTaskHandle();
  std::unique_lock<std::mutex> g(t->mu);
  t->cv.wait_for(g, std::chrono::milliseconds(ticks), [&] { return t->count > 0; });
  const uint32_t n = t->count;
  t->count = clear ? 0 : (n ? n - 1 : 0);
  return n;
}

void vTaskDelay(TickType_t ticks) { std::this_thread::sleep_for(std::chrono::milliseconds(ticks)); }

struct HostQueue {
  std::mutex mu;
  std::condition_variable cv;
  std::deque<std::vector<char>> items;
  size_t length, size;
};

QueueHandle_t xQueueCreate(UBaseType_t length, UBaseType_t itemSize) { return new HostQueue{{}, {}, {}, length, itemSize}; }

BaseType_t xQueueSend(QueueHandle_t q, const void *item, TickType_t) {
  std::lock_guard<std::mutex> g(q->mu);
  if (q->items.size() >= q->length) return pdFALSE;
  const char *p = static_cast<const char *>(item);
  q->items.emplace_back(p, p + q->size);
  q->cv.notify_all();
  return pdTRUE;
}

BaseType_t xQueueReceive(QueueHandle_t q, void *item, TickType_t) {
  std::unique_lock<std::mutex> g(q->mu);
  q->cv.wait(g, [&] { return !q->items.empty(); });
  memcpy(item, q->items.front().data(), q->size);
  q->items.pop_front();
  return pdTRUE;
}

// ---------- NVS ----------

namespace host {
std::mutex storeMu;
std::map<std::string, std::string> storeData[2];
std::mutex pulseMu;
std::vector<Pulse> pulses;
std::atomic<bool> doorOpen[5];
std::atomic<int> brightness{100};
static std::mutex doorCbMu;
static std::function<void(int, bool)> doorCb;
void setDoor(int channel, bool open) {
  doorOpen[channel] = open;
  std::function<void(int, bool)> cb;
  {
    std::lock_guard<std::mutex> g(doorCbMu);
    cb = doorCb;
  }
  if (cb) cb(channel, open);
}
std::function<smb::HttpResult(const char *, const char *, const std::string &, const std::string &, const std::string &)> server;
}  // namespace host

namespace smb::store {
void init() {}
std::string get(Area a, const char *key) {
  std::lock_guard<std::mutex> g(host::storeMu);
  auto it = host::storeData[a].find(key);
  return it == host::storeData[a].end() ? "" : it->second;
}
void set(Area a, const char *key, const std::string &v) {
  std::lock_guard<std::mutex> g(host::storeMu);
  host::storeData[a][key] = v;
}
void erase(Area a, const char *key) {
  std::lock_guard<std::mutex> g(host::storeMu);
  host::storeData[a].erase(key);
}
}  // namespace smb::store

// ---------- 繼電器與 HTTPS ----------

namespace smb {
void relay_init() {}
void relay_all_off() {}
void relay_pulse(int channel, int ms, const std::function<bool()> &stop) {
  const int64_t start = esp_timer_get_time() / 1000;
  for (int64_t t = 0; t < ms; t = esp_timer_get_time() / 1000 - start) {
    vTaskDelay(std::min<int64_t>(10, ms - t));
    if (stop && t >= 200 && stop()) break;
  }
  std::lock_guard<std::mutex> g(host::pulseMu);
  host::pulses.push_back({channel, start, esp_timer_get_time() / 1000});
}

void display_set_brightness(int percent) { host::brightness = percent; }
void door_init() {}
bool door_open(int channel) { return host::doorOpen[channel].load(); }
int door_raw(int) { return -1; }
void door_on_change(std::function<void(int, bool)> cb) {
  std::lock_guard<std::mutex> g(host::doorCbMu);
  host::doorCb = std::move(cb);
}

HttpResult http_request(const char *method, const char *path, const std::string &body, const std::string &token,
                        const std::string &bootId) {
  return host::server(method, path, body, token, bootId);
}
}  // namespace smb
