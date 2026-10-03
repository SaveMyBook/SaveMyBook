#pragma once

#include <cstdint>
#include <string>

namespace smb {

struct HttpResult {
  int status = 0;
  std::string body;
  bool networkError = false;
  int retryAfterSec = -1;
  int64_t rttMs = 0;
};

// 對裝置 API（CONFIG_SMB_API_BASE）送出請求。沿用同一條 HTTPS 長連線，以 ESP-IDF 內建憑證套件驗證伺服器。
// token 為空字串時不帶 Authorization。
HttpResult http_request(const char *method, const char *path, const std::string &body, const std::string &token,
                        const std::string &bootId);

}  // namespace smb
