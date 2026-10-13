#include "wifi.h"

#include <atomic>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <functional>
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
#include "http.h"
#include "protocomm_ble.h"
#include "store.h"
#include "ui.h"

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

// 已設定的網路連不上超過 20 秒就開啟藍牙設定：櫃體封起來後按不到 BOOT 鍵。正常開機約 1–3 秒就會連上。
// 設定期間每 15 秒再試一次原本的網路（手機連著藍牙時不試，以免打斷 App 掃描網路），
// 停電後路由器比書櫃晚開機的情況仍會自己連回去。
static constexpr int64_t FALLBACK_AFTER_MS = 20000;
static constexpr int64_t RETRY_SAVED_MS = 15000;
static std::atomic<bool> s_hasSaved{false};
static std::atomic<bool> s_bleClient{false};
static std::atomic<int64_t> s_downSince{0};
// 開始設定時管理器會清空 RAM 中的 Wi-Fi 設定，重試原本的網路要自己帶回去。
static wifi_config_t s_saved;
static int s_lastReason = 0;
static std::function<void()> s_onConnected;

static int64_t nowMs() { return esp_timer_get_time() / 1000; }

// 平常關閉省電模式：省電時路由器要等下一個信標才把封包交給裝置，每次請求多等約 100 毫秒。
// 藍牙與 Wi-Fi 並存時必須開啟，開啟藍牙設定前先切回。
static void setPowerSave(bool on) {
  const esp_err_t err = esp_wifi_set_ps(on ? WIFI_PS_MIN_MODEM : WIFI_PS_NONE);
  if (err != ESP_OK) ESP_LOGW(TAG, "power save %s failed: %s", on ? "on" : "off", esp_err_to_name(err));
}

// 記住連上的頻道，下次開機從這個頻道快速掃描。
static void rememberChannel() {
  wifi_ap_record_t ap;
  if (esp_wifi_sta_get_ap_info(&ap) != ESP_OK || ap.primary == s_saved.sta.channel) return;
  s_saved.sta.channel = ap.primary;
  store::set(store::Identity, "wifi_ch", std::to_string(ap.primary));
  ESP_LOGI(TAG, "channel %d remembered", ap.primary);
}

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
        esp_wifi_get_config(WIFI_IF_STA, &s_saved);  // 新設定的網路，或連回的原網路
        if (s_state == WifiState::Connected) setPowerSave(false);
        break;
      default:
        break;
    }
  } else if (base == WIFI_EVENT) {
    if (id == WIFI_EVENT_STA_START && !s_provisioning) {
      esp_wifi_connect();
    } else if (id == WIFI_EVENT_STA_DISCONNECTED) {
      const int reason = static_cast<wifi_event_sta_disconnected_t *>(data)->reason;
      if (reason != s_lastReason) ESP_LOGW(TAG, "disconnected (reason %d)", reason);
      s_lastReason = reason;
      if (s_downSince == 0) s_downSince = nowMs();
      http_invalidate();
      if (!s_provisioning) {
        if (s_state == WifiState::Connected) s_state = WifiState::Connecting;
        esp_wifi_connect();
      }
    }
  } else if (base == PROTOCOMM_TRANSPORT_BLE_EVENT) {
    s_bleClient = id == PROTOCOMM_TRANSPORT_BLE_CONNECTED;
    // 手機連上時中止正在重試的原網路，App 掃描網路才不會失敗
    if (s_bleClient && s_state != WifiState::Connected) esp_wifi_disconnect();
  } else if (base == IP_EVENT && id == IP_EVENT_STA_GOT_IP) {
    s_state = WifiState::Connected;
    s_everConnected = true;
    s_downSince = 0;
    s_lastReason = 0;
    ESP_LOGI(TAG, "connected");
    rememberChannel();
    if (!s_provisioning) setPowerSave(false);
    else if (s_hasSaved && !s_bleClient) {
      ESP_LOGI(TAG, "saved network is back, provisioning stopped");
      network_prov_mgr_stop_provisioning();
    }
    if (s_onConnected) s_onConnected();
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

// 呼叫前 network_prov_mgr 須已初始化。Wi-Fi 正在連線時管理器無法清空設定（"sta is connecting"），
// 先中止連線再重試；仍失敗時回傳 false，由呼叫端稍後再試。
static bool startProvisioning() {
  s_provisioning = true;  // 斷線事件不再自動重連
  setPowerSave(true);
  esp_wifi_disconnect();
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
  esp_err_t err = ESP_FAIL;
  for (int i = 0; i < 20 && err != ESP_OK; i++) {
    if (i) vTaskDelay(pdMS_TO_TICKS(100));
    err = network_prov_mgr_start_provisioning(NETWORK_PROV_SECURITY_2, &s_sec2, name, nullptr);
  }
  if (err != ESP_OK) {
    ESP_LOGE(TAG, "provisioning start failed: %s", esp_err_to_name(err));
    s_provisioning = false;
    if (s_hasSaved) esp_wifi_connect();
    return false;
  }
  const std::string payload = std::string("{\"ver\":\"v1\",\"name\":\"") + name + "\",\"username\":\"" + PROV_USER +
                              "\",\"pop\":\"" + password + "\",\"transport\":\"ble\"}";
  ui_prepare_qr(payload);
  {
    std::lock_guard<std::mutex> g(s_mu);
    s_payload = payload;
  }
  s_bleClient = false;
  s_state = WifiState::Provisioning;
  ESP_LOGI(TAG, "provisioning as %s", name);
  return true;
}

[[noreturn]] static void watchTask(void *) {
  int64_t lastRetry = 0;
  for (;;) {
    vTaskDelay(pdMS_TO_TICKS(1000));
    const int64_t down = s_downSince, now = nowMs();
    if (!s_provisioning && down != 0 && now - down >= FALLBACK_AFTER_MS) {
      ESP_LOGW(TAG, "saved network unreachable for %lld s, starting provisioning", (now - down) / 1000);
      ESP_ERROR_CHECK(network_prov_mgr_init(provConfig()));
      if (startProvisioning()) lastRetry = now;
      else network_prov_mgr_deinit();
    } else if (s_provisioning && s_hasSaved && !s_bleClient &&
               (s_state == WifiState::Provisioning || s_state == WifiState::ProvisionFailed) &&
               now - lastRetry >= RETRY_SAVED_MS) {
      lastRetry = now;
      // 設定期間管理器已把 Wi-Fi 設定改存 RAM，帶回原網路不會寫入 NVS
      esp_wifi_set_config(WIFI_IF_STA, &s_saved);
      esp_wifi_connect();
    }
  }
}

void wifi_start() {
  ESP_ERROR_CHECK(esp_netif_init());
  ESP_ERROR_CHECK(esp_event_loop_create_default());
  esp_netif_create_default_wifi_sta();
  // 驅動程式初始化參數的紀錄每次開機約 20 行，只留警告
  for (const char *tag : {"wifi_init", "phy_init", "pp", "net80211"}) esp_log_level_set(tag, ESP_LOG_WARN);
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
    esp_wifi_get_config(WIFI_IF_STA, &s_saved);
    // 設定管理器存的是全頻道掃描（13 個頻道掃完再挑訊號最強的，約 2.4 秒）。連上過之後改為從記住的頻道快速掃描，
    // 找到就連；那個頻道找不到時仍會繼續掃其他頻道
    const int channel = std::atoi(store::get(store::Identity, "wifi_ch").c_str());
    if (channel >= 1 && channel <= 14 && (channel != s_saved.sta.channel || s_saved.sta.scan_method != WIFI_FAST_SCAN)) {
      s_saved.sta.channel = channel;
      s_saved.sta.scan_method = WIFI_FAST_SCAN;
      esp_wifi_set_config(WIFI_IF_STA, &s_saved);
    }
    ESP_LOGI(TAG, "saved network, channel hint %d", s_saved.sta.channel);
    ESP_ERROR_CHECK(esp_wifi_start());
  } else if (!startProvisioning()) {
    network_prov_mgr_deinit();
    s_downSince = nowMs();  // watchTask 稍後再試
  }
  xTaskCreatePinnedToCore(watchTask, "wifiwatch", 3072, nullptr, 3, nullptr, 0);  // 開啟設定時要算 SRP，不佔畫面的核心
}

void wifi_on_connected(std::function<void()> cb) { s_onConnected = std::move(cb); }

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
