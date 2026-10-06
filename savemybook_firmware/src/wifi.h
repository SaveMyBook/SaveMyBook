#pragma once

#include <string>

namespace smb {

enum class WifiState { Starting, Provisioning, ProvisionFailed, Connecting, Connected };

// 已設定過 Wi-Fi 時直接連線；尚未設定，或已設定的網路連不上超過 2 分鐘時，開啟藍牙設定
// （Espressif「ESP BLE Provisioning」App），QR Code 顯示於螢幕。
void wifi_start();
WifiState wifi_state();
// 曾經連上過網路後即改由書櫃畫面顯示連線狀態。
bool wifi_ever_connected();
// 藍牙設定用的 QR Code 內容，僅在 Provisioning、ProvisionFailed 時有值。
std::string wifi_prov_payload();
// 清除已儲存的 Wi-Fi 設定後重新開機（按住 BOOT 鍵 5 秒）。
[[noreturn]] void wifi_reset_and_restart();

}  // namespace smb
