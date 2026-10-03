#include "device.h"

#include <algorithm>
#include <cinttypes>
#include <cmath>
#include <cstdio>
#include <iterator>

#include "cJSON.h"
#include "esp_log.h"
#include "esp_random.h"
#include "esp_task_wdt.h"
#include "esp_timer.h"
#include "pins.h"
#include "relay.h"
#include "sdkconfig.h"
#include "store.h"
#include "messages.h"

namespace smb {

static const char *TAG = "device";

// 與 device-core.js 相同的時間設定。
static constexpr int64_t DEFAULT_POLL_MS = 2000;
static constexpr int OFFLINE_AFTER_FAILURES = 3;
static constexpr int64_t BACKOFF_MS[] = {2000, 4000, 8000, 15000};
static constexpr int64_t MAINTENANCE_RETRY_MS = 5000;
static constexpr int64_t DISABLED_RETRY_MS = 15000;
static constexpr int64_t RATE_LIMIT_RETRY_MS = 5000;
static constexpr int64_t PAIRING_POLL_MS = 3000;
static constexpr int64_t PAIRING_RETRY_MS = 60000;
static constexpr size_t MAX_BATCH = 20;
static constexpr int64_t RESULT_WAIT_MS = 4000;
static constexpr int64_t QR_REFRESH_MS = 30000;
static constexpr int64_t DEFAULT_OPEN_MS = 30000;
static constexpr int64_t ROUNDTRIP_MAX_MS = 3000;
static constexpr int64_t LOCK_GAP_MS = 300;
static constexpr int UNLOCK_PULSE_MS = 800;

static int64_t nowMs() { return esp_timer_get_time() / 1000; }

// ---------- 小工具 ----------

static std::string str(const cJSON *o, const char *key) {
  const cJSON *v = cJSON_GetObjectItemCaseSensitive(o, key);
  return cJSON_IsString(v) && v->valuestring ? v->valuestring : "";
}

static bool num(const cJSON *o, const char *key, double &out) {
  const cJSON *v = cJSON_GetObjectItemCaseSensitive(o, key);
  if (!cJSON_IsNumber(v)) return false;
  out = v->valuedouble;
  return true;
}

static std::string toJson(cJSON *o) {
  char *s = cJSON_PrintUnformatted(o);
  std::string out = s ? s : "";
  cJSON_free(s);
  cJSON_Delete(o);
  return out;
}

static std::string prefixOf(const std::string &id) { return id.substr(0, id.find(':')); }

static std::string doorLabel(int channel) {
  char buf[8];
  snprintf(buf, sizeof(buf), "A%02d", channel);
  return buf;
}

static std::vector<std::string> linesOf(const std::string &code, const std::map<std::string, std::string> &params) {
  static const std::string SEP = "｜";
  std::vector<std::string> lines;
  std::string text = format(code, params);
  size_t start = 0, at;
  while ((at = text.find(SEP, start)) != std::string::npos) {
    lines.push_back(text.substr(start, at - start));
    start = at + SEP.size();
  }
  lines.push_back(text.substr(start));
  return lines;
}

static std::string clockText(int64_t ms) {
  const int64_t seconds = (std::max<int64_t>(0, ms) + 999) / 1000;
  char buf[32];
  snprintf(buf, sizeof(buf), "%" PRId64 ":%02" PRId64, seconds / 60, seconds % 60);
  return buf;
}

static std::string seconds(int64_t ms) { return std::to_string((std::max<int64_t>(0, ms) + 999) / 1000); }

// ---------- 開機與身分 ----------

void Device::begin(const std::string &resetReason) {
  std::lock_guard<std::mutex> g(mu_);
  lockQ_ = xQueueCreate(8, sizeof(Batch *));
  static const char chars[] = "0123456789abcdefghijklmnopqrstuvwxyz";
  bootId_.clear();
  for (int i = 0; i < 8; i++) bootId_ += chars[esp_random() % 36];
  loadIdentity_();
  ESP_LOGI(TAG, "boot %s, %s", bootId_.c_str(), token_.empty() ? "not paired" : "paired");

  if (token_.empty()) {
    startPairing_();
    return;
  }
  queue_.erase(std::remove_if(queue_.begin(), queue_.end(), [](const Event &e) { return e.type == "boot"; }), queue_.end());

  // 上次開機在開門中斷電：已執行的指令不再執行，並回報作業因重新開機中斷。
  cJSON *record = cJSON_Parse(store::get(store::Queue, "open").c_str());
  std::string recordSession = str(record, "session_id");
  const cJSON *ids = cJSON_GetObjectItemCaseSensitive(record, "command_ids");
  const cJSON *id;
  cJSON_ArrayForEach(id, ids) if (cJSON_IsString(id)) executed_.insert(id->valuestring);
  cJSON_Delete(record);

  cJSON *boot = cJSON_CreateObject();
  cJSON_AddStringToObject(boot, "firmware", CONFIG_SMB_FIRMWARE_VERSION);
  cJSON_AddNumberToObject(boot, "door_count", DOOR_COUNT);
  cJSON_AddBoolToObject(boot, "has_door_sensor", false);
  cJSON_AddNumberToObject(boot, "unlock_pulse_ms", UNLOCK_PULSE_MS);
  cJSON_AddStringToObject(boot, "reset_reason", resetReason.c_str());
  cJSON_AddStringToObject(boot, "boot_id", bootId_.c_str());
  enqueue_("boot", "", 0, toJson(boot), true);

  const bool closed = std::any_of(queue_.begin(), queue_.end(), [&](const Event &e) {
    return e.type == "session_closed" && e.sessionId == recordSession;
  });
  if (!recordSession.empty() && !closed) {
    enqueue_("session_closed", recordSession, 0, R"({"outcome":"interrupted","reason":"reboot"})");
  }
  store::erase(store::Queue, "open");
  bootPending_ = true;
  pollScheduled_ = true;
  nextPollAt_ = nowMs();
}

void Device::loadIdentity_() {
  token_ = store::get(store::Identity, "token");
  deviceNo_ = store::get(store::Identity, "device_no");
  const std::string seq = store::get(store::Queue, "seq");
  seq_ = seq.empty() ? 0 : static_cast<uint32_t>(strtoul(seq.c_str(), nullptr, 10));
  queue_.clear();
  cJSON *arr = cJSON_Parse(store::get(store::Queue, "queue").c_str());
  const cJSON *item;
  cJSON_ArrayForEach(item, arr) {
    Event e;
    e.id = str(item, "id");
    e.type = str(item, "type");
    if (e.id.empty() || e.type.empty()) continue;
    e.boot = str(item, "boot");
    e.sessionId = str(item, "session_id");
    e.data = str(item, "data");
    double v;
    if (num(item, "channel", v)) e.channel = static_cast<int>(v);
    queue_.push_back(e);
  }
  cJSON_Delete(arr);
}

// 憑證失效：清除身分後重新申請配對碼。事件序號保留，跨開機持續遞增。
void Device::clearIdentity_() {
  store::erase(store::Identity, "token");
  store::erase(store::Identity, "device_no");
  store::erase(store::Queue, "queue");
  store::erase(store::Queue, "open");
  gen_ += 1;
  token_.clear();
  deviceNo_.clear();
  queue_.clear();
  local_.reset();
  executed_.clear();
  bootPending_ = false;
  reachable_ = false;
  failures_ = 0;
  hasServer_ = false;
  hasPostClose_ = false;
  pollScheduled_ = false;
  startPairing_();
}

// ---------- 事件佇列 ----------

void Device::persistQueue_() {
  cJSON *arr = cJSON_CreateArray();
  for (const Event &e : queue_) {
    cJSON *o = cJSON_CreateObject();
    cJSON_AddStringToObject(o, "id", e.id.c_str());
    cJSON_AddStringToObject(o, "type", e.type.c_str());
    cJSON_AddStringToObject(o, "boot", e.boot.c_str());
    if (!e.sessionId.empty()) cJSON_AddStringToObject(o, "session_id", e.sessionId.c_str());
    if (e.channel) cJSON_AddNumberToObject(o, "channel", e.channel);
    if (!e.data.empty()) cJSON_AddStringToObject(o, "data", e.data.c_str());
    cJSON_AddItemToArray(arr, o);
  }
  store::set(store::Queue, "queue", toJson(arr));
}

void Device::enqueue_(const char *type, const std::string &sessionId, int channel, const std::string &data, bool front) {
  if (token_.empty() || bootId_.empty()) return;
  seq_ += 1;
  store::set(store::Queue, "seq", std::to_string(seq_));
  char id[48];
  snprintf(id, sizeof(id), "%s-%06" PRIu32, bootId_.c_str(), seq_);
  Event e{id, type, bootId_, sessionId, data, nowMs(), channel};
  if (front) queue_.insert(queue_.begin(), e);
  else queue_.push_back(e);
  persistQueue_();
  ESP_LOGI(TAG, "event %s %s", id, type);
}

void Device::flush_() {
  if (token_.empty()) return;
  if (inflight_) flushRequested_ = true;
  else nextPollAt_ = nowMs();
  if (netTask_) xTaskNotifyGive(netTask_);
}

void Device::tick_(int64_t now) {
  if (local_ && local_->openedAt >= 0 && !local_->expired && now >= local_->openedAt + local_->openMs) {
    local_->expired = true;
    onCountdownEnd_();
  }
  if (hasPostClose_ && now >= postCloseUntil_) hasPostClose_ = false;
}

// ---------- 通訊 ----------

[[noreturn]] void Device::runNetwork() {
  netTask_ = xTaskGetCurrentTaskHandle();
  esp_task_wdt_add(nullptr);
  for (;;) {
    esp_task_wdt_reset();
    const int64_t now = nowMs();
    bool doCycle = false, doPair = false;
    int64_t due;
    {
      std::lock_guard<std::mutex> g(mu_);
      tick_(now);
      if (token_.empty()) {
        doPair = pairing_.active && now >= pairing_.nextAt;
        due = pairing_.nextAt;
      } else {
        doCycle = pollScheduled_ && now >= nextPollAt_;
        due = pollScheduled_ ? nextPollAt_ : now + 250;
      }
    }
    if (doPair) {
      pairCycle();
    } else if (doCycle) {
      cycle();
    } else {
      ulTaskNotifyTake(pdTRUE, pdMS_TO_TICKS(std::clamp<int64_t>(due - now, 10, 250)));
    }
  }
}

std::string Device::batchBody_(std::vector<std::string> &ids) {
  const int64_t now = nowMs();
  cJSON *root = cJSON_CreateObject();
  cJSON *events = cJSON_AddArrayToObject(root, "events");
  for (size_t i = 0; i < queue_.size() && i < MAX_BATCH; i++) {
    const Event &e = queue_[i];
    ids.push_back(e.id);
    cJSON *o = cJSON_CreateObject();
    cJSON_AddStringToObject(o, "id", e.id.c_str());
    cJSON_AddStringToObject(o, "type", e.type.c_str());
    // 前一次開機留下的事件無法以單調時鐘計算經過時間。
    if (e.boot == bootId_) cJSON_AddNumberToObject(o, "age_ms", static_cast<double>(std::max<int64_t>(0, now - e.at)));
    else cJSON_AddNullToObject(o, "age_ms");
    if (!e.sessionId.empty()) cJSON_AddStringToObject(o, "session_id", e.sessionId.c_str());
    if (e.channel) cJSON_AddNumberToObject(o, "channel", e.channel);
    if (!e.data.empty()) {
      cJSON *data = cJSON_Parse(e.data.c_str());
      if (data) cJSON_AddItemToObject(o, "data", data);
    }
    cJSON_AddItemToArray(events, o);
  }
  return toJson(root);
}

void Device::cycle() {
  std::string body, token, boot;
  std::vector<std::string> ids;
  bool events;
  uint32_t gen;
  {
    std::lock_guard<std::mutex> g(mu_);
    if (token_.empty()) return;
    inflight_ = true;
    flushRequested_ = false;
    events = !queue_.empty();
    if (events) body = batchBody_(ids);
    token = token_;
    boot = bootId_;
    gen = gen_;
  }
  const HttpResult res = events ? http_request("POST", "/events", body, token, boot)
                                : http_request("GET", "/state", "", token, boot);
  std::lock_guard<std::mutex> g(mu_);
  inflight_ = false;
  if (gen != gen_) return;
  int64_t next = events ? afterEvents_(res, ids) : afterState_(res);
  if (next < 0) return;
  if (flushRequested_ && failures_ == 0) next = 0;
  nextPollAt_ = nowMs() + next;
  pollScheduled_ = true;
}

Device::Kind Device::classify(const HttpResult &res, const cJSON *root) const {
  if (res.networkError) return Kind::Network;
  const std::string code = str(root, "code");
  if (res.status >= 200 && res.status < 300) return Kind::Ok;
  if (res.status == 401) return Kind::Revoked;
  if (res.status == 403 && code == "DEVICE_DISABLED") return Kind::Disabled;
  if (res.status == 409 && code == "DEVICE_STALE_BOOT") return Kind::Stale;
  if (res.status == 503 && code == "MAINTENANCE") return Kind::Maintenance;
  if (res.status == 429) return Kind::Rate;
  if (res.status >= 500) return Kind::Network;
  return Kind::Client;
}

// 回傳下一次請求的延遲；-1 表示停止輪詢（已改為配對流程）。
int64_t Device::settle_(const HttpResult &res, Kind kind) {
  if (kind == Kind::Network) {
    failures_ += 1;
    return BACKOFF_MS[std::min<int>(failures_, std::size(BACKOFF_MS)) - 1];
  }
  failures_ = 0;
  reachable_ = true;
  systemMaintenance_ = kind == Kind::Maintenance;
  deviceDisabled_ = kind == Kind::Disabled;
  switch (kind) {
    case Kind::Revoked:
      ESP_LOGW(TAG, "credential revoked, pairing again");
      clearIdentity_();
      return -1;
    case Kind::Maintenance:
      return MAINTENANCE_RETRY_MS;
    case Kind::Disabled:
      return DISABLED_RETRY_MS;
    case Kind::Rate:
      return res.retryAfterSec > 0 ? res.retryAfterSec * 1000LL : RATE_LIMIT_RETRY_MS;
    default:
      return pollMs_();
  }
}

int64_t Device::pollMs_() const { return hasServer_ && server_.pollMs > 0 ? server_.pollMs : DEFAULT_POLL_MS; }

int64_t Device::afterState_(const HttpResult &res) {
  cJSON *root = cJSON_Parse(res.body.c_str());
  const Kind kind = classify(res, root);
  const cJSON *data = cJSON_GetObjectItemCaseSensitive(root, "data");
  int64_t next;
  if (kind == Kind::Ok && cJSON_IsObject(data)) {
    settle_(res, kind);
    applyState_(data, res.rttMs);
    next = pollMs_();
  } else {
    next = settle_(res, kind);
  }
  cJSON_Delete(root);
  return next;
}

int64_t Device::afterEvents_(const HttpResult &res, const std::vector<std::string> &ids) {
  cJSON *root = cJSON_Parse(res.body.c_str());
  const Kind kind = classify(res, root);
  const cJSON *data = cJSON_GetObjectItemCaseSensitive(root, "data");
  auto typeOf = [&](const std::string &id) {
    for (const Event &e : queue_) if (e.id == id) return e.type;
    return std::string();
  };

  if (kind != Kind::Ok || !cJSON_IsObject(data)) {
    if (kind == Kind::Client && res.status == 400) {
      // 整批格式錯誤，重送也不會成功。
      for (const std::string &id : ids) if (typeOf(id) == "boot") bootPending_ = false;
      queue_.erase(std::remove_if(queue_.begin(), queue_.end(), [&](const Event &e) {
        return std::find(ids.begin(), ids.end(), e.id) != ids.end();
      }), queue_.end());
      persistQueue_();
    }
    const int64_t next = settle_(res, kind);
    cJSON_Delete(root);
    return next;
  }

  std::map<std::string, std::string> status;
  const cJSON *r;
  cJSON_ArrayForEach(r, cJSON_GetObjectItemCaseSensitive(data, "results")) status[str(r, "id")] = str(r, "status");
  std::set<std::string> settled;
  bool retried = false;
  for (const std::string &id : ids) {
    auto it = status.find(id);
    if (it == status.end()) continue;
    ESP_LOGI(TAG, "event %s -> %s", id.c_str(), it->second.c_str());
    if (it->second == "retry") {
      retried = true;
      continue;
    }
    settled.insert(id);
    if (typeOf(id) == "boot") bootPending_ = false;
  }
  queue_.erase(std::remove_if(queue_.begin(), queue_.end(), [&](const Event &e) { return settled.count(e.id) > 0; }),
               queue_.end());
  persistQueue_();

  settle_(res, kind);
  const cJSON *state = cJSON_GetObjectItemCaseSensitive(data, "state");
  if (cJSON_IsObject(state)) applyState_(state, res.rttMs);
  const int64_t next = !retried && !settled.empty() && !queue_.empty() ? 0 : pollMs_();
  cJSON_Delete(root);
  return next;
}

void Device::applyState_(const cJSON *state, int64_t rtt) {
  ServerState s;
  s.at = nowMs();
  s.screen = str(state, "screen");
  double v;
  if (num(state, "poll_ms", v)) s.pollMs = static_cast<int64_t>(v);
  const cJSON *message = cJSON_GetObjectItemCaseSensitive(state, "message");
  s.messageCode = str(message, "code");
  const cJSON *p;
  cJSON_ArrayForEach(p, cJSON_GetObjectItemCaseSensitive(message, "params")) {
    if (cJSON_IsString(p)) s.params[p->string] = p->valuestring;
    else if (cJSON_IsNumber(p)) s.params[p->string] = std::to_string(static_cast<long long>(p->valuedouble));
  }
  const cJSON *qr = cJSON_GetObjectItemCaseSensitive(state, "qr");
  if (cJSON_IsObject(qr) && !str(qr, "payload").empty()) {
    s.hasQr = true;
    s.qrPayload = str(qr, "payload");
    if (num(qr, "refresh_in_ms", v)) s.qrRefreshMs = static_cast<int64_t>(v);
    if (num(qr, "expires_in_ms", v)) s.qrExpiresMs = static_cast<int64_t>(v);
  }
  const cJSON *session = cJSON_GetObjectItemCaseSensitive(state, "session");
  if (cJSON_IsObject(session)) {
    s.hasSession = true;
    s.sessionId = str(session, "id");
    s.phase = str(session, "phase");
    s.action = str(session, "action");
    if (num(session, "remaining_ms", v)) {
      s.hasRemaining = true;
      s.remainingMs = static_cast<int64_t>(v);
    }
    if (num(session, "open_ms", v)) s.openMs = static_cast<int64_t>(v);
    if (num(session, "code", v)) s.code = static_cast<int>(v);
  }
  server_ = s;
  hasServer_ = true;

  const std::string no = str(state, "device_no");
  if (!no.empty() && no != deviceNo_) {
    deviceNo_ = no;
    store::set(store::Identity, "device_no", no);
  }
  if (hasPostClose_ && s.hasSession && s.sessionId == postCloseSession_ && s.phase == "result") hasPostClose_ = false;
  if (s.hasSession && s.hasRemaining && s.phase != "open") {
    const std::string key = s.sessionId + ":" + s.phase;
    if (key != phaseKey_) {
      phaseKey_ = key;
      phaseTotal_ = s.remainingMs;
    } else {
      phaseTotal_ = std::max(phaseTotal_, s.remainingMs);
    }
  }
  const cJSON *commands = cJSON_GetObjectItemCaseSensitive(state, "commands");
  if (cJSON_GetArraySize(commands) > 0) {
    handleUnlock_(commands, rtt);
    handleClose_(commands);
  }
}

// ---------- 開鎖 ----------

void Device::handleUnlock_(const cJSON *commands, int64_t rtt) {
  std::vector<UnlockCmd> fresh;
  const cJSON *c;
  cJSON_ArrayForEach(c, commands) {
    double channel, expires, release;
    const std::string id = str(c, "id");
    if (str(c, "type") != "unlock" || id.empty() || executed_.count(id) || !num(c, "channel", channel)) continue;
    if (channel != std::floor(channel) || channel < 1 || channel > DOOR_COUNT) continue;
    // 只在收到回應的當下檢查一次效期，之後即使逾時或離線也照常執行。
    if (!num(c, "expires_in_ms", expires) || expires <= 0) continue;
    const int ms = num(c, "release_ms", release) && release > 0 ? static_cast<int>(release) : UNLOCK_PULSE_MS;
    fresh.push_back({id, static_cast<int>(channel), ms});
  }
  if (fresh.empty()) return;
  if (rtt > ROUNDTRIP_MAX_MS) {
    ESP_LOGW(TAG, "round trip %" PRId64 " ms exceeds %" PRId64 " ms, unlock ignored", rtt, ROUNDTRIP_MAX_MS);
    return;
  }

  const std::string sessionId = server_.hasSession && !server_.sessionId.empty() ? server_.sessionId : prefixOf(fresh[0].id);
  if (local_ && local_->sessionId != sessionId) return;

  cJSON *previous = cJSON_Parse(store::get(store::Queue, "open").c_str());
  cJSON *ids = cJSON_CreateArray();
  if (str(previous, "session_id") == sessionId) {
    const cJSON *id;
    cJSON_ArrayForEach(id, cJSON_GetObjectItemCaseSensitive(previous, "command_ids")) {
      if (cJSON_IsString(id)) cJSON_AddItemToArray(ids, cJSON_CreateString(id->valuestring));
    }
  }
  cJSON_Delete(previous);
  for (const UnlockCmd &cmd : fresh) {
    executed_.insert(cmd.id);
    cJSON_AddItemToArray(ids, cJSON_CreateString(cmd.id.c_str()));
  }
  const int64_t openMs = server_.openMs > 0 ? server_.openMs : DEFAULT_OPEN_MS;
  const std::string action = server_.hasSession && !server_.action.empty() ? server_.action
                             : local_ ? local_->action
                                      : "mixed";
  // 通電前先寫入開門中紀錄：中途斷電重開時不會再執行同一個指令。
  cJSON *record = cJSON_CreateObject();
  cJSON_AddStringToObject(record, "session_id", sessionId.c_str());
  cJSON_AddItemToObject(record, "command_ids", ids);
  cJSON_AddStringToObject(record, "action", action.c_str());
  cJSON_AddNumberToObject(record, "open_ms", static_cast<double>(openMs));
  store::set(store::Queue, "open", toJson(record));

  if (!local_) {
    local_ = std::make_shared<Local>();
    local_->sessionId = sessionId;
    local_->action = action;
    local_->openMs = openMs;
  }
  for (const UnlockCmd &cmd : fresh) local_->doors[cmd.channel] = {cmd.id, "pending"};
  local_->unlocking += 1;
  auto *batch = new Batch{local_, fresh, gen_};
  if (xQueueSend(lockQ_, &batch, 0) != pdTRUE) {
    ESP_LOGE(TAG, "unlock queue full");
    local_->unlocking -= 1;
    delete batch;
  }
}

// 依序逐扇開鎖，斷電後再等 300 毫秒才對下一扇通電，任何時刻只有一個電磁鎖通電。
[[noreturn]] void Device::runLocks() {
  for (;;) {
    Batch *batch = nullptr;
    xQueueReceive(lockQ_, &batch, portMAX_DELAY);
    bool aborted = false;
    for (const UnlockCmd &cmd : batch->cmds) {
      int64_t gap;
      {
        std::lock_guard<std::mutex> g(mu_);
        aborted = batch->gen != gen_;
        gap = lastPowerOff_ + LOCK_GAP_MS - nowMs();
      }
      if (aborted) break;
      if (gap > 0) vTaskDelay(pdMS_TO_TICKS(gap));
      relay_pulse(cmd.channel, cmd.releaseMs);
      std::lock_guard<std::mutex> g(mu_);
      lastPowerOff_ = nowMs();
      if (batch->gen != gen_) {
        aborted = true;
        break;
      }
      // 沒有門磁，斷電即視為已開啟（門板有彈簧會自動彈開）。
      batch->local->doors[cmd.channel].state = "open";
      cJSON *data = cJSON_CreateObject();
      cJSON_AddStringToObject(data, "command_id", cmd.id.c_str());
      enqueue_("door_opened", batch->local->sessionId, cmd.channel, toJson(data));
      if (batch->local->openedAt < 0) batch->local->openedAt = nowMs();
      flush_();
    }
    if (!aborted) {
      std::lock_guard<std::mutex> g(mu_);
      if (batch->gen == gen_) {
        batch->local->unlocking -= 1;
        if (batch->local->unlocking == 0 && local_ == batch->local) {
          if (local_->openedAt < 0) {
            local_.reset();
            store::erase(store::Queue, "open");
          } else {
            if (local_->hasClose) applyClose_();
            if (local_ && local_->expired) onCountdownEnd_();
          }
        }
      }
    }
    delete batch;
  }
}

void Device::onCountdownEnd_() {
  if (!local_ || local_->closing || local_->unlocking > 0) return;
  closeSession_("completed", "timeout");
}

void Device::closeSession_(const char *outcome, const char *reason) {
  if (!local_ || local_->closing) return;
  local_->closing = true;
  const bool completed = std::string(outcome) == "completed";
  for (auto &[channel, door] : local_->doors) {
    if (door.state != "open") continue;
    if (completed) {
      cJSON *data = cJSON_CreateObject();
      cJSON_AddStringToObject(data, "reason", reason);
      enqueue_("door_closed", local_->sessionId, channel, toJson(data));
    }
    door.state = "closed";
  }
  cJSON *data = cJSON_CreateObject();
  cJSON_AddStringToObject(data, "outcome", outcome);
  cJSON_AddStringToObject(data, "reason", reason);
  enqueue_("session_closed", local_->sessionId, 0, toJson(data));
  store::erase(store::Queue, "open");
  hasPostClose_ = true;
  postCloseSession_ = local_->sessionId;
  postCloseUntil_ = nowMs() + RESULT_WAIT_MS;
  local_.reset();
  flush_();
}

// 使用者在手機按完成或取消。開鎖尚未全部執行完時先保留，由 runLocks 結束時再套用。
void Device::handleClose_(const cJSON *commands) {
  if (!local_ || local_->closing) return;
  std::string id, outcome;
  const cJSON *c;
  cJSON_ArrayForEach(c, commands) {
    const std::string cid = str(c, "id"), out = str(c, "outcome");
    if (str(c, "type") != "close" || cid.empty() || executed_.count(cid)) continue;
    if ((out != "completed" && out != "cancelled") || prefixOf(cid) != local_->sessionId) continue;
    executed_.insert(cid);
    id = cid;
    outcome = out;
  }
  if (id.empty()) return;
  local_->hasClose = true;
  local_->closeId = id;
  local_->closeOutcome = outcome;
  applyClose_();
}

void Device::applyClose_() {
  if (!local_ || !local_->hasClose || local_->closing || local_->unlocking > 0) return;
  local_->hasClose = false;
  const bool completed = local_->closeOutcome == "completed";
  closeSession_(completed ? "completed" : "cancelled", completed ? "user_done" : "user_cancel");
}

// ---------- 配對 ----------

void Device::startPairing_() {
  pairing_ = Pairing{};
  pairing_.active = true;
  pairing_.pollMs = PAIRING_POLL_MS;
  pairing_.nextAt = nowMs();
}

void Device::pairCycle() {
  std::string pollToken, boot;
  uint32_t gen;
  {
    std::lock_guard<std::mutex> g(mu_);
    if (!token_.empty() || !pairing_.active) return;
    pollToken = pairing_.pollToken;
    boot = bootId_;
    gen = gen_;
  }
  HttpResult res;
  if (pollToken.empty()) {
    cJSON *body = cJSON_CreateObject();
    cJSON_AddStringToObject(body, "kind", "esp32");
    cJSON_AddNumberToObject(body, "door_count", DOOR_COUNT);
    cJSON_AddBoolToObject(body, "has_door_sensor", false);
    cJSON_AddNumberToObject(body, "unlock_pulse_ms", UNLOCK_PULSE_MS);
    cJSON_AddStringToObject(body, "firmware", CONFIG_SMB_FIRMWARE_VERSION);
    res = http_request("POST", "/pair/request", toJson(body), "", boot);
  } else {
    cJSON *body = cJSON_CreateObject();
    cJSON_AddStringToObject(body, "poll_token", pollToken.c_str());
    res = http_request("POST", "/pair/poll", toJson(body), "", boot);
  }

  std::lock_guard<std::mutex> g(mu_);
  if (gen != gen_ || !token_.empty() || !pairing_.active) return;
  const int64_t next = pollToken.empty() ? afterPairRequest_(res) : afterPairPoll_(res);
  if (next < 0) return;
  // 本機到期後仍以原 poll_token 再查詢，直到回 410 才重新申請：管理員在最後幾秒綁定時，伺服器會延長效期供裝置領取憑證。
  const int64_t now = nowMs();
  const int64_t expiresIn = pairing_.pollToken.empty() ? 0 : pairing_.expiresAt - now;
  pairing_.nextAt = now + (expiresIn > 0 ? std::min(next, expiresIn) : next);
}

int64_t Device::afterPairRequest_(const HttpResult &res) {
  cJSON *root = cJSON_Parse(res.body.c_str());
  const cJSON *data = cJSON_GetObjectItemCaseSensitive(root, "data");
  double expires = 0, poll = 0;
  int64_t next;
  if (res.status == 201 && !str(data, "code").empty() && !str(data, "poll_token").empty() &&
      num(data, "expires_in_ms", expires) && expires > 0) {
    failures_ = 0;
    reachable_ = true;
    pairing_.code = str(data, "code");
    pairing_.pollToken = str(data, "poll_token");
    pairing_.expiresAt = nowMs() + static_cast<int64_t>(expires);
    pairing_.totalMs = static_cast<int64_t>(expires);
    pairing_.pollMs = num(data, "poll_ms", poll) && poll > 0 ? static_cast<int64_t>(poll) : PAIRING_POLL_MS;
    pairing_.error.clear();
    ESP_LOGI(TAG, "pairing code %s", pairing_.code.c_str());
    next = pairing_.pollMs;
  } else {
    pairing_.code.clear();
    next = pairingFailed_(res, root);
  }
  cJSON_Delete(root);
  return next;
}

int64_t Device::afterPairPoll_(const HttpResult &res) {
  cJSON *root = cJSON_Parse(res.body.c_str());
  const cJSON *data = cJSON_GetObjectItemCaseSensitive(root, "data");
  const std::string status = str(data, "status");
  int64_t next;
  double v;
  if (res.status == 200 && status == "paired" && !str(data, "token").empty()) {
    token_ = str(data, "token");
    deviceNo_ = str(data, "device_no");
    store::set(store::Identity, "token", token_);
    store::set(store::Identity, "device_no", deviceNo_);
    store::erase(store::Queue, "queue");
    store::erase(store::Queue, "open");
    queue_.clear();
    executed_.clear();
    local_.reset();
    hasServer_ = false;
    hasPostClose_ = false;
    pairing_.active = false;
    failures_ = 0;
    reachable_ = true;
    // 配對請求的 X-Device-Boot 已是本次開機代碼，不需先送 boot 事件。
    pollScheduled_ = true;
    nextPollAt_ = nowMs();
    ESP_LOGI(TAG, "paired as %s", deviceNo_.c_str());
    next = -1;
  } else if (res.status == 200 && status == "pending") {
    failures_ = 0;
    reachable_ = true;
    if (num(data, "expires_in_ms", v) && v >= 0) pairing_.expiresAt = nowMs() + static_cast<int64_t>(v);
    if (num(data, "poll_ms", v) && v > 0) pairing_.pollMs = static_cast<int64_t>(v);
    pairing_.error.clear();
    next = pairing_.pollMs;
  } else if (res.status == 410) {
    failures_ = 0;
    reachable_ = true;
    pairing_.code.clear();
    pairing_.pollToken.clear();
    next = 0;
  } else {
    next = pairingFailed_(res, root);
  }
  cJSON_Delete(root);
  return next;
}

int64_t Device::pairingFailed_(const HttpResult &res, const cJSON *root) {
  const Kind kind = classify(res, root);
  if (kind == Kind::Network) {
    failures_ += 1;
    if (failures_ >= OFFLINE_AFTER_FAILURES) pairing_.error = "OFFLINE";
    return BACKOFF_MS[std::min<int>(failures_, std::size(BACKOFF_MS)) - 1];
  }
  failures_ = 0;
  reachable_ = true;
  if (kind == Kind::Rate) {
    if (pairing_.code.empty()) pairing_.error = "PAIRING_RETRY";
    return res.retryAfterSec > 0 ? res.retryAfterSec * 1000LL : RATE_LIMIT_RETRY_MS;
  }
  if (kind == Kind::Maintenance) {
    pairing_.error = "SYSTEM_MAINTENANCE";
    return MAINTENANCE_RETRY_MS;
  }
  pairing_.error = kind == Kind::Disabled ? "DEVICE_DISABLED" : "PAIRING_RETRY";
  pairing_.code.clear();
  pairing_.pollToken.clear();
  return PAIRING_RETRY_MS;
}

// ---------- 畫面 ----------

View Device::view() {
  std::lock_guard<std::mutex> g(mu_);
  const int64_t now = nowMs();
  View v;
  v.header = msg("TITLE");
  v.online = reachable_ && failures_ < OFFLINE_AFTER_FAILURES;
  if (token_.empty()) {
    pairingView_(v, now);
  } else if (local_) {
    localView_(v, now);
  } else if (failures_ >= OFFLINE_AFTER_FAILURES) {
    v.screen = Screen::Offline;
    v.lines = {msg("OFFLINE")};
  } else if (!reachable_) {
    v.screen = Screen::Booting;
    v.lines = {msg("BOOTING")};
  } else if (hasPostClose_) {
    v.screen = Screen::Processing;
    v.lines = {msg("PROCESSING")};
  } else if (systemMaintenance_) {
    v.screen = Screen::SystemMaintenance;
    v.lines = {msg("SYSTEM_MAINTENANCE")};
  } else if (deviceDisabled_) {
    v.screen = Screen::DeviceDisabled;
    v.lines = {msg("DEVICE_DISABLED")};
  } else if (!hasServer_) {
    v.screen = Screen::Booting;
    v.lines = {msg("BOOTING")};
  } else {
    serverView_(v, now);
  }
  return v;
}

void Device::pairingView_(View &v, int64_t now) const {
  v.screen = Screen::Pairing;
  const std::string title = msg("PAIRING_TITLE");
  const int64_t remaining = pairing_.code.empty() ? 0 : std::max<int64_t>(0, pairing_.expiresAt - now);
  if (!pairing_.code.empty() && pairing_.error.empty() && remaining > 0) {
    v.lines = {title, pairing_.code, msg("PAIRING_PROMPT"), format("PAIRING_REMAINING", {{"time", clockText(remaining)}})};
    v.pairCode = pairing_.code;
    v.pairRemainingMs = remaining;
    v.pairTotalMs = std::max(pairing_.totalMs, remaining);
    return;
  }
  const std::string status = pairing_.error.empty() ? msg("PAIRING_REQUESTING") : msg(pairing_.error);
  v.lines = {title, status};
  v.pairError = !pairing_.error.empty();
}

void Device::serverView_(View &v, int64_t now) const {
  const ServerState &s = server_;
  const int64_t elapsed = now - s.at;
  if (s.hasSession && s.hasRemaining) {
    v.hasCountdown = true;
    v.remainingMs = std::max<int64_t>(0, s.remainingMs - elapsed);
    v.totalMs = std::max(phaseTotal_, v.remainingMs);
  }
  const std::vector<std::string> remainingLine =
      v.hasCountdown ? std::vector<std::string>{format("REMAINING_SECONDS", {{"seconds", seconds(v.remainingMs)}})}
                     : std::vector<std::string>{};
  const std::string code = s.messageCode;

  if (s.screen == "idle") {
    v.screen = Screen::Idle;
    v.lines = linesOf(code.empty() ? "IDLE_SCAN" : code, s.params);
    if (s.hasQr && elapsed < s.qrExpiresMs) {
      v.qr = s.qrPayload;
      v.qrRatio = std::clamp(static_cast<float>(s.qrRefreshMs - elapsed) / QR_REFRESH_MS, 0.0f, 1.0f);
    }
  } else if (s.screen == "closed_hours" || s.screen == "maintenance" || s.screen == "disabled") {
    v.screen = s.screen == "closed_hours" ? Screen::ClosedHours : s.screen == "maintenance" ? Screen::Maintenance : Screen::Disabled;
    v.icon = s.screen == "closed_hours" ? Icon::Clock : s.screen == "maintenance" ? Icon::Wrench : Icon::Pause;
    v.lines = linesOf(code, s.params);
  } else if (s.screen == "select") {
    v.screen = Screen::Select;
    v.lines = linesOf(code.empty() ? "SELECT_ON_PHONE" : code, s.params);
    v.lines.insert(v.lines.end(), remainingLine.begin(), remainingLine.end());
  } else if (s.screen == "match") {
    v.screen = Screen::Match;
    v.lines = {format(code.empty() ? "MATCH_PROMPT" : code, s.params)};
    if (s.code >= 10 && s.code <= 99) v.code = std::to_string(s.code);
    v.lines.insert(v.lines.end(), remainingLine.begin(), remainingLine.end());
  } else if (s.screen == "opening") {
    v.screen = Screen::Opening;
    v.lines = {msg("OPENING")};
  } else if (s.screen == "result") {
    v.screen = Screen::Result;
    v.icon = code == "RESULT_DONE" ? Icon::Check : Icon::Alert;
    v.lines = linesOf(code, s.params);
  } else {
    v.screen = Screen::Processing;
    v.lines = {msg("PROCESSING")};
  }
}

void Device::localView_(View &v, int64_t now) const {
  const Local &l = *local_;
  if (l.openedAt < 0) {
    v.screen = Screen::Opening;
    v.lines = {msg("OPENING")};
    return;
  }
  std::string joined;
  for (const auto &[channel, door] : l.doors) {
    if (door.state != "open" && door.state != "closed") continue;
    v.doorLabels.push_back(doorLabel(channel));
    joined += (joined.empty() ? "" : "、") + doorLabel(channel);
  }
  static const std::map<std::string, std::string> OPEN_CODES = {
      {"pickup", "OPEN_PICKUP"}, {"deposit", "OPEN_DEPOSIT"}, {"retrieve", "OPEN_RETRIEVE"},
      {"mixed", "OPEN_MIXED"},   {"admin", "OPEN_ADMIN"},
  };
  auto it = OPEN_CODES.find(l.action);
  v.screen = l.action == "admin" ? Screen::Admin : Screen::Open;
  v.lines = {joined, format(it == OPEN_CODES.end() ? "OPEN_MIXED" : it->second, {{"doors", joined}})};
  v.hasCountdown = true;
  v.remainingMs = std::max<int64_t>(0, l.openMs - (now - l.openedAt));
  v.totalMs = l.openMs;
}

}  // namespace smb
