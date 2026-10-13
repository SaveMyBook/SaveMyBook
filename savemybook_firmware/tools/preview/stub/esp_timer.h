#pragma once
// 電腦上的預覽：以系統單調時鐘代替 esp_timer。
#include <cstdint>
#include <ctime>

static inline int64_t esp_timer_get_time() {
  timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return static_cast<int64_t>(ts.tv_sec) * 1000000 + ts.tv_nsec / 1000;
}
