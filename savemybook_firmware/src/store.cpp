#include "store.h"

#include "esp_log.h"
#include "nvs.h"
#include "nvs_flash.h"

namespace smb::store {

static const char *TAG = "store";
static const char *PARTITION[] = {"nvs", "evq"};
static const char *NAMESPACE = "smb";

static void initPartition(const char *name) {
  esp_err_t err = nvs_flash_init_partition(name);
  if (err == ESP_ERR_NVS_NO_FREE_PAGES || err == ESP_ERR_NVS_NEW_VERSION_FOUND) {
    ESP_LOGW(TAG, "partition %s reformatted", name);
    ESP_ERROR_CHECK(nvs_flash_erase_partition(name));
    err = nvs_flash_init_partition(name);
  }
  ESP_ERROR_CHECK(err);
}

void init() {
  initPartition(PARTITION[Identity]);
  initPartition(PARTITION[Queue]);
}

std::string get(Area area, const char *key) {
  nvs_handle_t h;
  if (nvs_open_from_partition(PARTITION[area], NAMESPACE, NVS_READONLY, &h) != ESP_OK) return "";
  size_t len = 0;
  std::string value;
  if (nvs_get_blob(h, key, nullptr, &len) == ESP_OK && len > 0) {
    value.resize(len);
    if (nvs_get_blob(h, key, value.data(), &len) != ESP_OK) value.clear();
  }
  nvs_close(h);
  return value;
}

void set(Area area, const char *key, const std::string &value) {
  nvs_handle_t h;
  if (nvs_open_from_partition(PARTITION[area], NAMESPACE, NVS_READWRITE, &h) != ESP_OK) return;
  esp_err_t err = nvs_set_blob(h, key, value.data(), value.size());
  if (err == ESP_OK) err = nvs_commit(h);
  if (err != ESP_OK) ESP_LOGE(TAG, "write %s failed: %s", key, esp_err_to_name(err));
  nvs_close(h);
}

void erase(Area area, const char *key) {
  nvs_handle_t h;
  if (nvs_open_from_partition(PARTITION[area], NAMESPACE, NVS_READWRITE, &h) != ESP_OK) return;
  if (nvs_erase_key(h, key) == ESP_OK) nvs_commit(h);
  nvs_close(h);
}

}  // namespace smb::store
