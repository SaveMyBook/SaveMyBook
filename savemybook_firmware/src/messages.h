#pragma once

// 書櫃螢幕的字串表：與模擬書櫃 savemybook_api/views/kiosk/device-core.js 的 MESSAGES 相同，另加 Wi-Fi 設定與硬體測試用字。
// tools/make_fonts.py 只從這個檔案收集要放進字型的字，新增字串後要重新產生 fonts.c。

#include <map>
#include <string>

namespace smb {

inline const std::map<std::string, std::string>& messages() {
  static const std::map<std::string, std::string> m = {
      {"IDLE_SCAN", "請使用 SaveMyBook App 掃描"},
      {"CLOSED_HOURS", "目前非營業時間｜營業時間 {open}–{close}"},
      {"MAINTENANCE", "書櫃維修中，暫停服務"},
      {"DISABLED", "書櫃暫停服務"},
      {"SELECT_ON_PHONE", "書櫃使用中｜請於手機確認項目"},
      {"MATCH_PROMPT", "請於手機輸入下列數字"},
      {"OPENING", "櫃門開啟中"},
      {"OPEN_PICKUP", "請取出 {doors} 內的書籍後關上櫃門"},
      {"OPEN_DEPOSIT", "請將書籍放入 {doors} 後關上櫃門"},
      {"OPEN_RETRIEVE", "請取回 {doors} 內的書籍後關上櫃門"},
      {"OPEN_MIXED", "請依手機指示操作 {doors} 後關上櫃門"},
      {"OPEN_ADMIN", "管理人員作業中"},
      {"RESULT_DONE", "作業完成"},
      {"RESULT_PARTIAL", "部分項目未完成，請查看手機"},
      {"RESULT_CANCELLED", "本次作業已取消"},
      {"RESULT_MATCH_FAILED", "數字不符，本次作業已取消"},
      {"RESULT_TIMEOUT", "操作逾時，本次作業已取消"},
      {"RESULT_DEVICE_ERROR", "櫃門未能開啟，請聯絡客服"},
      {"RESULT_REVIEW", "本次作業待客服確認"},
      {"TITLE", "智慧書櫃"},
      {"PAIRING_TITLE", "配對碼"},
      {"PAIRING_PROMPT", "請於管理後台輸入此配對碼"},
      {"PAIRING_REMAINING", "剩餘時間 {time}"},
      {"PAIRING_REQUESTING", "取得配對碼中"},
      {"PAIRING_RETRY", "暫時無法取得配對碼，稍後自動重試"},
      {"OFFLINE", "連線中斷，重新連線中"},
      {"SYSTEM_MAINTENANCE", "系統維護中，請稍後再試"},
      {"DEVICE_DISABLED", "書櫃裝置目前未開放"},
      {"BOOTING", "啟動中"},
      {"PROCESSING", "處理中"},
      {"CLOSE_DOOR_FIRST", "請先關上櫃門"},
      {"REMAINING_SECONDS", "剩餘 {seconds} 秒"},
      {"WIFI_TITLE", "Wi-Fi 設定"},
      {"WIFI_SCAN", "請以 ESP BLE Provisioning App 掃描"},
      {"WIFI_FAILED", "Wi-Fi 連線失敗，請重新設定"},
      {"WIFI_CONNECTING", "Wi-Fi 連線中"},
      {"WIFI_RESET_HINT", "按住 BOOT 鍵 5 秒可重設 Wi-Fi"},
      {"HW_TITLE", "硬體測試"},
      {"HW_ALL_OFF", "繼電器全部斷電"},
      {"HW_RELAY_ON", "繼電器 {n} 通電"},
      {"HW_SCREENS", "畫面版面測試"},
  };
  return m;
}

inline std::string msg(const std::string &code) {
  auto it = messages().find(code);
  return it == messages().end() ? std::string() : it->second;
}

// 以 params 代入字串中的 {name}。
inline std::string format(const std::string &code, const std::map<std::string, std::string> &params) {
  const std::string text = msg(code);
  std::string out;
  for (size_t i = 0; i < text.size();) {
    const size_t end = text[i] == '{' ? text.find('}', i) : std::string::npos;
    if (end != std::string::npos) {
      auto it = params.find(text.substr(i + 1, end - i - 1));
      if (it != params.end()) out += it->second;
      i = end + 1;
    } else {
      out += text[i++];
    }
  }
  return out;
}

}  // namespace smb
