#pragma once

#include <atomic>
#include <cstdint>
#include <functional>
#include <map>
#include <mutex>
#include <string>
#include <vector>

#include "http.h"

namespace host {

struct Pulse {
  int channel;
  int64_t startMs, endMs;
};

extern std::mutex storeMu;
extern std::map<std::string, std::string> storeData[2];  // 0 Identity、1 Queue
// 門磁：測試直接設定去彈跳後的狀態，setDoor 會呼叫裝置註冊的回呼。
extern std::atomic<bool> doorOpen[5];
void setDoor(int channel, bool open);
extern std::atomic<int> brightness;
extern std::mutex pulseMu;
extern std::vector<Pulse> pulses;
extern std::function<smb::HttpResult(const char *method, const char *path, const std::string &body,
                                     const std::string &token, const std::string &bootId)>
    server;

}  // namespace host
