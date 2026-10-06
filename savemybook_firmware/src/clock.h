#pragma once

#include <string>

namespace smb {

// 以後端回應的 Date 標頭校時。不另外連 NTP：校園網路常擋 UDP 123，而書櫃本來就持續與後端連線。
void clock_set_from_http_date(const char *date);

// 臺灣時間「HH:MM」；尚未校時回傳空字串。
std::string clock_hhmm();

}  // namespace smb
