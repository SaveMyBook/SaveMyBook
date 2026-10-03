#pragma once

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
extern std::mutex pulseMu;
extern std::vector<Pulse> pulses;
extern std::function<smb::HttpResult(const char *method, const char *path, const std::string &body,
                                     const std::string &token, const std::string &bootId)>
    server;

}  // namespace host
