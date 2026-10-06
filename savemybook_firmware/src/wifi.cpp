#include "wifi.h"

#include <atomic>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <mutex>

#include "bootloader_random.h"
#include "esp_event.h"
#include "esp_log.h"
#include "esp_mac.h"
#include "esp_timer.h"
#include "esp_netif.h"
#include "esp_random.h"
#include "esp_system.h"
#include "esp_wifi.h"
#include "network_provisioning/manager.h"
#include "network_provisioning/scheme_ble.h"
#include "esp_srp.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "protocomm_ble.h"

namespace smb {

static const char *TAG = "wifi";

static std::atomic<WifiState> s_state{WifiState::Starting};
static std::atomic<bool> s_everConnected{false};
static std::atomic<bool> s_provisioning{false};
static std::mutex s_mu;
static std::string s_payload;
// Security 2 的參數須保留到設定結束（NETWORK_PROV_END）。
static network_prov_security2_params_t s_sec2;
static char *s_salt, *s_verifier;
static constexpr const char *PROV_USER = "wifiprov";

// 已設定的網路連不上超過 2 分鐘就開啟藍牙設定：櫃體封起來後按不到 BOOT 鍵。
// 設定期間每分鐘再試一次原本的網路（手機連著藍牙時不試，以免打斷 App 掃描網路），
// 停電後路由器比書櫃晚開機的情況仍會自己連回去。
static constexpr int64_t FALLBACK_AFTER_MS = 120000;
static constexpr int64_t RETRY_SAVED_MS = 60000;
static std::atomic<bool> s_hasSaved{false};
static std::atomic<bool> s_bleClient{false};
static std::atomic<int64_t> s_downSince{0};

static int64_t nowMs() { return esp_timer_get_time() / 1000; }

static void onEvent(void *, esp_event_base_t base, int32_t id, void *data) {
  if (base == NETWORK_PROV_EVENT) {
    switch (id) {
      case NETWORK_PROV_WIFI_CRED_RECV:
        s_state = WifiState::Connecting;
        break;
      case NETWORK_PROV_WIFI_CRED_FAIL:
        ESP_LOGW(TAG, "credentials rejected (%s)",
                 *static_cast<network_prov_wifi_sta_fail_reason_t *>(data) == NETWORK_PROV_WIFI_STA_AUTH_ERROR
                     ? "auth error"
                     : "access point not found");
        // 讓同一組藍牙連線可以重新輸入，不必重新開機。
        network_prov_mgr_reset_wifi_sm_state_on_failure();
        s_state = WifiState::ProvisionFailed;
        break;
      case NETWORK_PROV_END:
        s_hasSaved = true;
        network_prov_mgr_deinit();
        free(s_salt);
        free(s_verifier);
        s_salt = s_verifier = nullptr;
        s_provisioning = false;
        {
          std::lock_guard<std::mutex> g(s_mu);
          s_payload.clear();
        }
        break;
      default:
        break;
    }
  } else if (base == WIFI_EVENT) {
    if (id == WIFI_EVENT_STA_START && !s_provisioning) {
      esp_wifi_connect();
    } else if (id == WIFI_EVENT_STA_DISCONNECTED) {
      if (s_downSince == 0) s_downSince = nowMs();
      if (!s_provisioning) {
        if (s_state == WifiState::Connected) s_state = WifiState::Connecting;
        esp_wifi_connect();
      }
    }
  } else if (base == PROTOCOMM_TRANSPORT_BLE_EVENT) {
    s_bleClient = id == PROTOCOMM_TRANSPORT_BLE_CONNECTED;
  } else if (base == IP_EVENT && id == IP_EVENT_STA_GOT_IP) {
    s_state = WifiState::Connected;
    s_everConnected = true;
    s_downSince = 0;
    ESP_LOGI(TAG, "connected");
    if (s_provisioning && s_hasSaved && !s_bleClient) {
      ESP_LOGI(TAG, "saved network is back, provisioning stopped");
      network_prov_mgr_stop_provisioning();
    }
  }
}

// 藍牙設定密碼每次開機隨機產生，只出現在螢幕上的 QR Code，必須在書櫃前才能設定。
static std::string randomPassword() {
  static const char chars[] = "abcdefghijkmnpqrstuvwxyz23456789";
  bootloader_random_enable();
  std::string pop;
  for (int i = 0; i < 8; i++) pop += chars[esp_random() % (sizeof(chars) - 1)];
  bootloader_random_disable();
  return pop;
}

static network_prov_mgr_config_t provConfig() {
  network_prov_mgr_config_t prov = {};
  prov.scheme = network_prov_scheme_ble;
  // 只釋放傳統藍牙的記憶體，保留 BLE：之後連不上時還要再開啟設定
  prov.scheme_event_handler = NETWORK_PROV_SCHEME_BLE_EVENT_HANDLER_FREE_BT;
  return prov;
}

// 呼叫前 network_prov_mgr 須已初始化。
static void startProvisioning() {
  uint8_t mac[6];
  esp_read_mac(mac, ESP_MAC_WIFI_STA);
  char name[16];
  snprintf(name, sizeof(name), "PROV_%02X%02X%02X", mac[3], mac[4], mac[5]);
  const std::string password = randomPassword();
  int verifierLen = 0;
  free(s_salt);
  free(s_verifier);
  ESP_ERROR_CHECK(esp_srp_gen_salt_verifier(PROV_USER, strlen(PROV_USER), password.c_str(), password.size(), &s_salt, 16,
                                            &s_verifier, &verifierLen));
  s_sec2.salt = s_salt;
  s_sec2.salt_len = 16;
  s_sec2.verifier = s_verifier;
  s_sec2.verifier_len = static_cast<uint16_t>(verifierLen);
  {
    std::lock_guard<std::mutex> g(s_mu);
    s_payload = std::string("{\"ver\":\"v1\",\"name\":\"") + name + "\",\"username\":\"" + PROV_USER +
                "\",\"pop\":\"" + password + "\",\"transport\":\"ble\"}";
  }
  s_bleClient = false;
  s_provisioning = true;
  s_state = WifiState::Provisioning;
  ESP_LOGI(TAG, "provisioning as %s", name);
  ESP_ERROR_CHECK(network_prov_mgr_start_provisioning(NETWORK_PROV_SECURITY_2, &s_sec2, name, nullptr));
}

[[noreturn]] static void watchTask(void *) {
  int64_t lastRetry = 0;
  for (;;) {
    vTaskDelay(pdMS_TO_TICKS(1000));
    const int64_t down = s_downSince, now = nowMs();
    if (!s_provisioning && down != 0 && now - down >= FALLBACK_AFTER_MS) {
      ESP_LOGW(TAG, "saved network unreachable for %lld s, starting provisioning", (now - down) / 1000);
      ESP_ERROR_CHECK(network_prov_mgr_init(provConfig()));
      startProvisioning();
      lastRetry = now;
    } else if (s_provisioning && s_hasSaved && s_state == WifiState::Provisioning && !s_bleClient &&
               now - lastRetry >= RETRY_SAVED_MS) {
      lastRetry = now;
      esp_wifi_connect();
    }
  }
}

void wifi_start() {
  ESP_ERROR_CHECK(esp_netif_init());
  ESP_ERROR_CHECK(esp_event_loop_create_default());
  esp_netif_create_default_wifi_sta();
  wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
  ESP_ERROR_CHECK(esp_wifi_init(&cfg));
  ESP_ERROR_CHECK(esp_event_handler_register(NETWORK_PROV_EVENT, ESP_EVENT_ANY_ID, onEvent, nullptr));
  ESP_ERROR_CHECK(esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, onEvent, nullptr));
  ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, onEvent, nullptr));
  ESP_ERROR_CHECK(esp_event_handler_register(PROTOCOMM_TRANSPORT_BLE_EVENT, ESP_EVENT_ANY_ID, onEvent, nullptr));

  ESP_ERROR_CHECK(network_prov_mgr_init(provConfig()));
  bool provisioned = false;
  ESP_ERROR_CHECK(network_prov_mgr_is_wifi_provisioned(&provisioned));
  if (provisioned) {
    network_prov_mgr_deinit();
    s_hasSaved = true;
    s_downSince = nowMs();
    s_state = WifiState::Connecting;
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_start());
  } else {
    startProvisioning();
  }
  xTaskCreate(watchTask, "wifiwatch", 3072, nullptr, 3, nullptr);
}

WifiState wifi_state() { return s_state; }
bool wifi_ever_connected() { return s_everConnected; }

std::string wifi_prov_payload() {
  std::lock_guard<std::mutex> g(s_mu);
  return s_payload;
}

void wifi_reset_and_restart() {
  ESP_LOGW(TAG, "Wi-Fi settings cleared by BOOT key");
  esp_wifi_restore();
  esp_restart();
}

}  // namespace smb
