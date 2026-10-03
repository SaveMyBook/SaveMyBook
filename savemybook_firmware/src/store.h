#pragma once

#include <string>

namespace smb::store {

// Identity：裝置憑證與裝置編號，放在預設的 nvs 分區。
// Queue：事件佇列、事件序號與開門中紀錄，寫入頻繁，放在獨立的 evq 分區分散磨耗。
enum Area { Identity = 0, Queue = 1 };

void init();
std::string get(Area area, const char *key);
void set(Area area, const char *key, const std::string &value);
void erase(Area area, const char *key);

}  // namespace smb::store
