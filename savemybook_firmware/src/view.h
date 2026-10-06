#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace smb {

enum class Screen {
  Booting,
  WifiSetup,
  WifiConnecting,
  Pairing,
  Idle,
  ClosedHours,
  Maintenance,
  Disabled,
  Select,
  Match,
  Opening,
  Open,
  Admin,
  Result,
  Processing,
  Offline,
  SystemMaintenance,
  DeviceDisabled,
  HwTest,
};

enum class Icon { None, Clock, Wrench, Pause, Check, Alert };

// 螢幕上要顯示的內容，對應模擬書櫃 buildView() 的結果。
struct View {
  Screen screen = Screen::Booting;
  std::vector<std::string> lines;
  bool online = false;
  std::string header;
  // 標題列右側的時間（HH:MM），空字串時不顯示。
  std::string clock;
  // 閒置畫面的書櫃 QR Code，或 Wi-Fi 設定的 QR Code。
  std::string qr;
  float qrRatio = -1;  // 小於 0 時不畫倒數條
  // 配對
  std::string pairCode;
  int64_t pairRemainingMs = 0, pairTotalMs = 0;
  bool pairError = false;
  // 數字比對
  std::string code;
  // 倒數
  bool hasCountdown = false;
  int64_t remainingMs = 0, totalMs = 0;
  Icon icon = Icon::None;
  std::string notice;
  std::vector<std::string> doorLabels;
};

}  // namespace smb
