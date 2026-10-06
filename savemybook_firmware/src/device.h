#pragma once

#include <array>
#include <cstdint>
#include <map>
#include <memory>
#include <mutex>
#include <set>
#include <string>
#include <vector>

#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "freertos/task.h"
#include "http.h"
#include "view.h"

struct cJSON;

namespace smb {

// 書櫃裝置邏輯，移植自模擬書櫃 savemybook_api/views/kiosk/device-core.js，協定見 savemybook_api/docs/device.yaml。
// 網路工作與開鎖工作分在兩個 FreeRTOS 工作：開鎖不會被 HTTPS 請求卡住。共用狀態以 mu_ 保護，名稱以底線結尾的函式須在持有 mu_ 時呼叫。
// NVS 保存的螢幕亮度（10–100），沒有時為 100。
int savedBrightness();

class Device {
 public:
  // Wi-Fi 啟動後呼叫：開機代碼要在無線電啟用後以 esp_random() 產生才是真隨機。
  void begin(const std::string &resetReason);
  [[noreturn]] void runNetwork();
  [[noreturn]] void runLocks();
  View view();

 private:
  struct Event {
    std::string id, type, boot, sessionId, data;  // data 為 JSON 物件字串，可為空
    int64_t at = 0;
    int channel = 0;
  };
  struct DoorRun {
    std::string commandId, state;  // pending、open、closed、left_open
  };
  // 門磁回報的實體狀態。graceUntil：斷電後這段時間內拉開門仍算正常開啟（櫃門沒有彈簧，使用者可能稍晚才拉）。
  struct Hw {
    bool open = false, locked = true, unlocking = false, leftOpen = false;
    int64_t graceUntil = 0;
  };
  struct Local {
    std::string sessionId, action;
    int64_t openMs = 0, openedAt = -1;
    std::map<int, DoorRun> doors;
    int unlocking = 0;
    bool closing = false, expired = false, hasClose = false;
    std::string closeId, closeOutcome, refusedOutcome;
  };
  struct UnlockCmd {
    std::string id;
    int channel = 0, releaseMs = 0;
  };
  struct Batch {
    std::shared_ptr<Local> local;
    std::vector<UnlockCmd> cmds;
    uint32_t gen = 0;
  };
  struct ServerState {
    std::string screen, messageCode;
    std::map<std::string, std::string> params;
    int64_t pollMs = 0, at = 0;
    bool hasQr = false;
    std::string qrPayload;
    int64_t qrRefreshMs = 0, qrExpiresMs = 0;
    bool hasSession = false, hasRemaining = false;
    std::string sessionId, phase, action;
    int64_t remainingMs = 0, openMs = 0;
    int code = -1;
  };
  struct Pairing {
    bool active = false;
    std::string code, pollToken, error;
    int64_t expiresAt = 0, totalMs = 0, pollMs = 3000, nextAt = 0;
  };
  enum class Kind { Ok, Network, Revoked, Disabled, Stale, Maintenance, Rate, Client };

  void loadIdentity_();
  void clearIdentity_();
  void persistQueue_();
  void enqueue_(const char *type, const std::string &sessionId, int channel, const std::string &data, bool front = false);
  void flush_();
  void tick_(int64_t now);

  void cycle();
  std::string batchBody_(std::vector<std::string> &ids);
  int64_t afterEvents_(const HttpResult &res, const std::vector<std::string> &ids);
  int64_t afterState_(const HttpResult &res);
  Kind classify(const HttpResult &res, const cJSON *root) const;
  int64_t settle_(const HttpResult &res, Kind kind);
  int64_t pollMs_() const;
  void applyState_(const cJSON *state, int64_t rtt);

  void handleUnlock_(const cJSON *commands, int64_t rtt);
  void handleClose_(const cJSON *commands);
  void applyClose_();
  void onCountdownEnd_();
  void closeSession_(const char *outcome, const char *reason);
  bool sessionDoorOpen_() const;
  void onDoor(int channel, bool open);

  void startPairing_();
  void pairCycle();
  int64_t afterPairRequest_(const HttpResult &res);
  int64_t afterPairPoll_(const HttpResult &res);
  int64_t pairingFailed_(const HttpResult &res, const cJSON *root);

  void pairingView_(View &v, int64_t now) const;
  void serverView_(View &v, int64_t now) const;
  void localView_(View &v, int64_t now) const;

  std::mutex mu_;
  TaskHandle_t netTask_ = nullptr;
  QueueHandle_t lockQ_ = nullptr;
  uint32_t gen_ = 0;

  std::string token_, deviceNo_, bootId_;
  std::vector<Event> queue_;
  uint32_t seq_ = 0;
  bool bootPending_ = false, reachable_ = false, systemMaintenance_ = false, deviceDisabled_ = false;
  bool inflight_ = false, flushRequested_ = false, pollScheduled_ = false;
  int failures_ = 0;
  int64_t nextPollAt_ = 0;

  bool hasServer_ = false;
  ServerState server_;
  std::string phaseKey_;
  int64_t phaseTotal_ = 0;
  bool hasPostClose_ = false;
  std::string postCloseSession_;
  int64_t postCloseUntil_ = 0;

  std::shared_ptr<Local> local_;
  std::set<std::string> executed_;
  int64_t lastPowerOff_ = -1000000;
  int brightness_ = 100;
  std::array<Hw, 5> hw_{};
  Pairing pairing_;
};

}  // namespace smb
