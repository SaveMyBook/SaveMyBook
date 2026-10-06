#include "clock.h"

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <sys/time.h>

#include "esp_log.h"

namespace smb {

static const char *TAG = "clock";
static bool s_synced = false;

// 公曆日期換算成 1970-01-01 起算的天數（newlib 沒有 timegm）。
static int64_t daysFromCivil(int y, int m, int d) {
  y -= m <= 2;
  const int64_t era = (y >= 0 ? y : y - 399) / 400;
  const int64_t yoe = y - era * 400;
  const int64_t doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1;
  const int64_t doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
  return era * 146097 + doe - 719468;
}

void clock_set_from_http_date(const char *date) {
  // 格式：Tue, 06 Oct 2026 08:12:34 GMT
  static const char MONTHS[] = "JanFebMarAprMayJunJulAugSepOctNovDec";
  char mon[4] = {};
  int d, y, hh, mm, ss;
  if (!date || sscanf(date, "%*3s, %d %3s %d %d:%d:%d", &d, mon, &y, &hh, &mm, &ss) != 6) return;
  const char *p = strstr(MONTHS, mon);
  if (!p || strlen(mon) != 3 || (p - MONTHS) % 3) return;
  const int64_t epoch = daysFromCivil(y, static_cast<int>(p - MONTHS) / 3 + 1, d) * 86400 + hh * 3600 + mm * 60 + ss;

  timeval now;
  gettimeofday(&now, nullptr);
  if (s_synced && llabs(static_cast<int64_t>(now.tv_sec) - epoch) < 2) return;
  const timeval tv = {static_cast<time_t>(epoch), 0};
  settimeofday(&tv, nullptr);
  if (!s_synced) ESP_LOGI(TAG, "synced from server: %s", date);
  s_synced = true;
}

std::string clock_hhmm() {
  if (!s_synced) return "";
  // 臺灣不實施日光節約時間，固定 UTC+8
  const time_t t = time(nullptr) + 8 * 3600;
  tm local;
  gmtime_r(&t, &local);
  char buf[8];
  snprintf(buf, sizeof buf, "%02d:%02d", local.tm_hour, local.tm_min);
  return buf;
}

}  // namespace smb
