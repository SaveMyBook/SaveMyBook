#include "http.h"

#include <cstring>
#include <strings.h>

#include "esp_crt_bundle.h"
#include "esp_http_client.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "sdkconfig.h"

namespace smb {

static const char *TAG = "http";
static constexpr size_t MAX_BODY = 32 * 1024;

struct Context {
  std::string body;
  int retryAfterSec = -1;
};

static Context s_ctx;
static esp_http_client_handle_t s_client;

static esp_err_t onEvent(esp_http_client_event_t *evt) {
  auto *ctx = static_cast<Context *>(evt->user_data);
  if (evt->event_id == HTTP_EVENT_ON_HEADER && evt->header_key && strcasecmp(evt->header_key, "Retry-After") == 0) {
    ctx->retryAfterSec = atoi(evt->header_value);
  } else if (evt->event_id == HTTP_EVENT_ON_DATA && ctx->body.size() + evt->data_len <= MAX_BODY) {
    ctx->body.append(static_cast<const char *>(evt->data), evt->data_len);
  }
  return ESP_OK;
}

HttpResult http_request(const char *method, const char *path, const std::string &body, const std::string &token,
                        const std::string &bootId) {
  const std::string url = std::string(CONFIG_SMB_API_BASE) + path;
  if (!s_client) {
    esp_http_client_config_t cfg = {};
    cfg.url = url.c_str();
    cfg.timeout_ms = 8000;
    cfg.event_handler = onEvent;
    cfg.user_data = &s_ctx;
    cfg.crt_bundle_attach = esp_crt_bundle_attach;
    cfg.keep_alive_enable = true;
    cfg.buffer_size = 2048;
    cfg.buffer_size_tx = 1024;
    cfg.user_agent = "SaveMyBook-Cabinet/" CONFIG_SMB_FIRMWARE_VERSION;
    s_client = esp_http_client_init(&cfg);
  }

  esp_http_client_set_url(s_client, url.c_str());
  esp_http_client_set_method(s_client, strcmp(method, "POST") == 0 ? HTTP_METHOD_POST : HTTP_METHOD_GET);
  esp_http_client_set_header(s_client, "Accept", "application/json");
  esp_http_client_set_header(s_client, "X-Device-Boot", bootId.c_str());
  if (token.empty()) esp_http_client_delete_header(s_client, "Authorization");
  else esp_http_client_set_header(s_client, "Authorization", ("Device " + token).c_str());
  if (body.empty()) {
    esp_http_client_delete_header(s_client, "Content-Type");
    esp_http_client_set_post_field(s_client, nullptr, 0);
  } else {
    esp_http_client_set_header(s_client, "Content-Type", "application/json");
    esp_http_client_set_post_field(s_client, body.data(), static_cast<int>(body.size()));
  }

  s_ctx.body.clear();
  s_ctx.retryAfterSec = -1;
  HttpResult res;
  const int64_t started = esp_timer_get_time();
  const esp_err_t err = esp_http_client_perform(s_client);
  res.rttMs = (esp_timer_get_time() - started) / 1000;
  if (err != ESP_OK) {
    ESP_LOGW(TAG, "%s %s failed: %s", method, path, esp_err_to_name(err));
    res.networkError = true;
    esp_http_client_cleanup(s_client);
    s_client = nullptr;
    return res;
  }
  res.status = esp_http_client_get_status_code(s_client);
  res.body = std::move(s_ctx.body);
  res.retryAfterSec = s_ctx.retryAfterSec;
  ESP_LOGI(TAG, "%s %s -> %d (%lld ms)", method, path, res.status, res.rttMs);
  return res;
}

}  // namespace smb
