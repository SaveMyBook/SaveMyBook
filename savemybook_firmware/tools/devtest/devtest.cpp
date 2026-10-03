// 書櫃邏輯測試：src/device.cpp 原封不動，接上模擬伺服器（行為依 savemybook_api/docs/device.yaml），以真實時間執行。
// 用法：bash tools/devtest/run.sh
#include <chrono>
#include <cstdio>
#include <string>
#include <thread>
#include <unistd.h>

#include "cJSON.h"
#include "device.h"
#include "host.h"

using namespace smb;

static int s_failed = 0;
static void check(bool ok, const std::string &what) {
  printf("%s %s\n", ok ? "  ok  " : "  FAIL", what.c_str());
  if (!ok) s_failed++;
}

template <typename F>
static bool waitFor(F pred, int ms) {
  for (int t = 0; t < ms; t += 20) {
    if (pred()) return true;
    std::this_thread::sleep_for(std::chrono::milliseconds(20));
  }
  return pred();
}

// ---------- 模擬伺服器 ----------

// 收到事件時就拆好欄位，測試執行緒不呼叫 cJSON（cJSON 的錯誤位置是全域變數）。
struct Ev {
  std::string id, type, session, commandId, reason, outcome, bootId, resetReason, firmware;
  int channel = 0;
};

struct Fake {
  std::mutex mu;
  const std::string token = "smbd_" + std::string(43, 'T');
  int pairPolls = 0;
  bool paired = false, revoked = false, down = false;
  int64_t rtt = 5;
  std::string session, phase = "idle", action = "deposit", closeId, closeOutcome;
  int64_t openMs = 5000;
  std::vector<int> channels;
  std::map<int, bool> opened;
  std::vector<std::string> requests, bootHeaders;
  std::vector<Ev> events;

  std::string state() {
    cJSON *s = cJSON_CreateObject();
    cJSON_AddStringToObject(s, "device_no", "DVTEST");
    cJSON_AddStringToObject(s, "screen", phase == "idle" ? "idle" : phase.c_str());
    cJSON_AddNumberToObject(s, "poll_ms", 150);
    cJSON *m = cJSON_AddObjectToObject(s, "message");
    cJSON_AddStringToObject(m, "code", phase == "idle" ? "IDLE_SCAN" : "OPENING");
    if (phase == "idle") {
      cJSON *qr = cJSON_AddObjectToObject(s, "qr");
      cJSON_AddStringToObject(qr, "payload", "savemybook://k/3f9c0a5e1d2b4c6a8e0f1a2b3c4d5e6f");
      cJSON_AddNumberToObject(qr, "refresh_in_ms", 20000);
      cJSON_AddNumberToObject(qr, "expires_in_ms", 35000);
    } else {
      cJSON *se = cJSON_AddObjectToObject(s, "session");
      cJSON_AddStringToObject(se, "id", session.c_str());
      cJSON_AddStringToObject(se, "phase", phase.c_str());
      cJSON_AddStringToObject(se, "action", action.c_str());
      cJSON_AddNumberToObject(se, "remaining_ms", 20000);
      cJSON_AddNumberToObject(se, "open_ms", static_cast<double>(openMs));
    }
    cJSON *cmds = cJSON_AddArrayToObject(s, "commands");
    if (phase == "opening") {
      for (int ch : channels) {
        cJSON *c = cJSON_CreateObject();
        cJSON_AddStringToObject(c, "id", (session + ":" + std::to_string(ch) + ":1").c_str());
        cJSON_AddStringToObject(c, "type", "unlock");
        cJSON_AddNumberToObject(c, "channel", ch);
        cJSON_AddNumberToObject(c, "release_ms", 300);
        cJSON_AddNumberToObject(c, "expires_in_ms", 6000);
        cJSON_AddItemToArray(cmds, c);
      }
    } else if (phase == "open" && !closeId.empty()) {
      cJSON *c = cJSON_CreateObject();
      cJSON_AddStringToObject(c, "id", closeId.c_str());
      cJSON_AddStringToObject(c, "type", "close");
      cJSON_AddStringToObject(c, "outcome", closeOutcome.c_str());
      cJSON_AddItemToArray(cmds, c);
    }
    return std::string(cJSON_PrintUnformatted(s));
  }

  HttpResult reply(int status, const std::string &body) {
    HttpResult r;
    r.status = status;
    r.body = body;
    r.rttMs = rtt;
    return r;
  }

  HttpResult handle(const char *method, const char *path, const std::string &body, const std::string &tok,
                    const std::string &boot) {
    std::lock_guard<std::mutex> g(mu);
    requests.push_back(std::string(method) + " " + path);
    if (down) {
      HttpResult r;
      r.networkError = true;
      return r;
    }
    const std::string p = path;
    if (p == "/pair/request")
      return reply(201, R"({"success":true,"data":{"code":"1234-5678","poll_token":")" + std::string(43, 'P') +
                            R"(","expires_in_ms":600000,"poll_ms":100}})");
    if (p == "/pair/poll") {
      if (++pairPolls < 3) return reply(200, R"({"success":true,"data":{"status":"pending","expires_in_ms":590000,"poll_ms":100}})");
      paired = true;
      return reply(200, R"({"success":true,"data":{"status":"paired","token":")" + token +
                            R"(","device_no":"DVTEST","cabinet":{"cabinet_name":"test"},"poll_ms":150}})");
    }
    if (revoked || tok != token) return reply(401, R"({"success":false,"code":"DEVICE_REVOKED"})");
    bootHeaders.push_back(boot);
    if (p == "/state") return reply(200, R"({"success":true,"data":)" + state() + "}");

    cJSON *root = cJSON_Parse(body.c_str());
    std::string results = "[";
    const cJSON *e;
    cJSON_ArrayForEach(e, cJSON_GetObjectItem(root, "events")) {
      auto str = [](const cJSON *o, const char *k) {
        const cJSON *v = cJSON_GetObjectItem(o, k);
        return cJSON_IsString(v) ? std::string(v->valuestring) : std::string();
      };
      const cJSON *data = cJSON_GetObjectItem(e, "data");
      const cJSON *ch = cJSON_GetObjectItem(e, "channel");
      events.push_back({str(e, "id"), str(e, "type"), str(e, "session_id"), str(data, "command_id"), str(data, "reason"),
                        str(data, "outcome"), str(data, "boot_id"), str(data, "reset_reason"), str(data, "firmware"),
                        cJSON_IsNumber(ch) ? ch->valueint : 0});
      const std::string type = cJSON_GetObjectItem(e, "type")->valuestring;
      if (type == "door_opened") {
        opened[cJSON_GetObjectItem(e, "channel")->valueint] = true;
        bool all = true;
        for (int ch : channels) all = all && opened[ch];
        if (all && phase == "opening") phase = "open";
      } else if (type == "session_closed") {
        phase = "idle";
        session.clear();
        closeId.clear();
      }
      results += std::string(results.size() > 1 ? "," : "") + R"({"id":")" + cJSON_GetObjectItem(e, "id")->valuestring +
                 R"(","status":"ok"})";
    }
    cJSON_Delete(root);
    return reply(200, R"({"success":true,"data":{"results":)" + results + R"(],"state":)" + state() + "}}");
  }

  // 依序列出符合條件的事件。
  std::vector<Ev> find(const std::string &type, const std::string &sessionId = "") {
    std::lock_guard<std::mutex> g(mu);
    std::vector<Ev> out;
    for (const Ev &e : events)
      if (e.type == type && (sessionId.empty() || e.session == sessionId)) out.push_back(e);
    return out;
  }
  bool isPaired() {
    std::lock_guard<std::mutex> g(mu);
    return paired;
  }
  int count(const std::string &request) {
    std::lock_guard<std::mutex> g(mu);
    int n = 0;
    for (const std::string &r : requests) n += r == request;
    return n;
  }
};

static Fake s_fake;

static size_t pulseCount() {
  std::lock_guard<std::mutex> g(host::pulseMu);
  return host::pulses.size();
}

static void start(Device &d, const char *reason) {
  host::server = [](const char *m, const char *p, const std::string &b, const std::string &t, const std::string &boot) {
    return s_fake.handle(m, p, b, t, boot);
  };
  d.begin(reason);
  std::thread([&d] { d.runLocks(); }).detach();
  std::thread([&d] { d.runNetwork(); }).detach();
}

static void setSession(const std::string &id, std::vector<int> channels, int64_t openMs, const char *action) {
  std::lock_guard<std::mutex> g(s_fake.mu);
  s_fake.session = id;
  s_fake.channels = channels;
  s_fake.opened.clear();
  s_fake.openMs = openMs;
  s_fake.action = action;
  s_fake.closeId.clear();
  s_fake.phase = "opening";
}

// ---------- 情境 ----------

static void flow() {
  puts("配對、開鎖、手機結束、倒數逾時、往返過久、取消、憑證撤銷");
  static Device d;
  start(d, "power_on");
  check(waitFor([] { return s_fake.isPaired() && s_fake.count("GET /state") > 0; }, 5000), "配對完成後開始輪詢狀態");
  {
    std::lock_guard<std::mutex> g(host::storeMu);
    check(host::storeData[0]["token"] == s_fake.token, "裝置憑證寫入 NVS");
  }
  check(waitFor([] { return d.view().screen == Screen::Idle && !d.view().qr.empty(); }, 2000), "閒置畫面顯示 QR Code");

  setSession("CS1", {2, 3}, 5000, "deposit");
  check(waitFor([] { return s_fake.find("door_opened", "CS1").size() == 2; }, 5000), "兩扇門都回報 door_opened");
  {
    std::lock_guard<std::mutex> g(host::pulseMu);
    check(host::pulses.size() == 2 && host::pulses[0].channel == 2 && host::pulses[1].channel == 3, "依指令順序開 A02、A03");
    if (host::pulses.size() == 2) {
      const int64_t gap = host::pulses[1].startMs - host::pulses[0].endMs;
      const int64_t len = host::pulses[0].endMs - host::pulses[0].startMs;
      check(gap >= 295, "前一扇斷電 300 毫秒後才通電下一扇（實際 " + std::to_string(gap) + " 毫秒）");
      check(len >= 295 && len < 400, "通電時間等於 release_ms（實際 " + std::to_string(len) + " 毫秒）");
    }
  }
  auto opened = s_fake.find("door_opened", "CS1");
  check(opened.size() == 2 && opened[0].commandId == "CS1:2:1", "door_opened 附 command_id");
  View v = d.view();
  check(v.screen == Screen::Open && v.doorLabels == std::vector<std::string>{"A02", "A03"}, "開門畫面顯示 A02、A03");
  check(v.lines.size() > 1 && v.lines[1] == "請將書籍放入 A02、A03 後關上櫃門", "存書說明文字");
  std::this_thread::sleep_for(std::chrono::milliseconds(700));
  check(pulseCount() == 2, "伺服器重複列出的指令不再執行");

  {
    std::lock_guard<std::mutex> g(s_fake.mu);
    s_fake.closeId = "CS1:close:1700000000000";
    s_fake.closeOutcome = "completed";
  }
  check(waitFor([] { return !s_fake.find("session_closed", "CS1").empty(); }, 3000), "手機按完成後結束作業");
  auto closed = s_fake.find("door_closed", "CS1");
  auto sessionClosed = s_fake.find("session_closed", "CS1");
  check(closed.size() == 2 && closed[0].reason == "user_done", "兩扇門回報 door_closed(user_done)");
  check(sessionClosed[0].outcome == "completed" && sessionClosed[0].reason == "user_done",
        "session_closed(completed, user_done)");
  check(d.view().screen == Screen::Processing, "結束後顯示處理中，等待伺服器的結果畫面");

  setSession("CS2", {1}, 1200, "pickup");
  check(waitFor([] { return s_fake.find("door_opened", "CS2").size() == 1; }, 3000), "第二次作業開啟 A01");
  check(waitFor([] { return d.view().screen == Screen::Open && d.view().lines[1] == "請取出 A01 內的書籍後關上櫃門"; }, 1000),
        "取書說明文字");
  check(waitFor([] { return !s_fake.find("session_closed", "CS2").empty(); }, 3000), "倒數結束自動結束作業");
  auto timeout = s_fake.find("door_closed", "CS2");
  check(timeout.size() == 1 && timeout[0].reason == "timeout", "door_closed(timeout)");
  check(s_fake.find("session_closed", "CS2")[0].reason == "timeout", "session_closed(completed, timeout)");

  {
    std::lock_guard<std::mutex> g(s_fake.mu);
    s_fake.rtt = 3500;
  }
  setSession("CS3", {4}, 5000, "retrieve");
  std::this_thread::sleep_for(std::chrono::milliseconds(1200));
  check(pulseCount() == 3, "往返超過 3000 毫秒時不執行開鎖");
  {
    std::lock_guard<std::mutex> g(s_fake.mu);
    s_fake.rtt = 5;
  }
  check(waitFor([] { return s_fake.find("door_opened", "CS3").size() == 1; }, 2000), "往返恢復正常後執行同一個指令");
  {
    std::lock_guard<std::mutex> g(s_fake.mu);
    s_fake.closeId = "CS3:close:1700000000001";
    s_fake.closeOutcome = "cancelled";
  }
  check(waitFor([] { return !s_fake.find("session_closed", "CS3").empty(); }, 3000), "手機按取消後結束作業");
  check(s_fake.find("session_closed", "CS3")[0].outcome == "cancelled" &&
            s_fake.find("session_closed", "CS3")[0].reason == "user_cancel",
        "session_closed(cancelled, user_cancel)");
  check(s_fake.find("door_closed", "CS3").empty(), "取消時不送 door_closed");

  {
    std::lock_guard<std::mutex> g(s_fake.mu);
    std::set<std::string> ids;
    for (const Ev &e : s_fake.events) ids.insert(e.id);
    check(ids.size() == s_fake.events.size(), "事件 id 不重複（共 " + std::to_string(ids.size()) + " 筆）");
  }

  {
    std::lock_guard<std::mutex> g(s_fake.mu);
    s_fake.revoked = true;
  }
  check(waitFor([] { return d.view().screen == Screen::Pairing && s_fake.count("POST /pair/request") >= 2; }, 3000),
        "憑證撤銷後重新申請配對碼");
  {
    std::lock_guard<std::mutex> g(host::storeMu);
    check(host::storeData[0].count("token") == 0, "撤銷後清除 NVS 中的憑證");
  }
}

static void reboot() {
  puts("開門中斷電後重新開機");
  host::storeData[0]["token"] = s_fake.token;
  host::storeData[0]["device_no"] = "DVTEST";
  host::storeData[1]["seq"] = "41";
  host::storeData[1]["open"] = R"({"session_id":"CS9","command_ids":["CS9:1:1"],"action":"pickup","open_ms":30000})";
  s_fake.paired = true;
  setSession("CS9", {1}, 30000, "pickup");
  static Device d;
  start(d, "software");
  check(waitFor([] { return s_fake.find("boot").size() == 1; }, 3000), "送出 boot 事件");
  {
    std::lock_guard<std::mutex> g(s_fake.mu);
    check(!s_fake.requests.empty() && s_fake.requests[0] == "POST /events", "開機後第一個請求是 POST /events");
  }
  const Ev boot = s_fake.find("boot")[0];
  {
    std::lock_guard<std::mutex> g(s_fake.mu);
    check(boot.bootId == s_fake.bootHeaders[0], "boot_id 等於 X-Device-Boot");
  }
  check(boot.resetReason == "software" && boot.firmware == "esp-1.0.0", "boot 附韌體版本與重開原因");
  check(boot.id.size() > 7 && boot.id.substr(boot.id.size() - 6) == "000042", "事件序號延續上次開機");
  auto interrupted = s_fake.find("session_closed", "CS9");
  check(interrupted.size() == 1 && interrupted[0].outcome == "interrupted" && interrupted[0].reason == "reboot",
        "回報 session_closed(interrupted, reboot)");
  std::this_thread::sleep_for(std::chrono::milliseconds(800));
  check(pulseCount() == 0, "斷電前已執行的指令不再執行");
  {
    std::lock_guard<std::mutex> g(host::storeMu);
    check(host::storeData[1].count("open") == 0, "清除開門中紀錄");
  }
}

static void offline() {
  puts("斷線與恢復");
  host::storeData[0]["token"] = s_fake.token;
  s_fake.paired = true;
  s_fake.down = true;
  static Device d;
  start(d, "power_on");
  check(waitFor([] { return d.view().screen == Screen::Offline; }, 9000), "連續 3 次失敗顯示連線中斷");
  check(!d.view().online, "標題列顯示離線");
  {
    std::lock_guard<std::mutex> g(s_fake.mu);
    s_fake.down = false;
  }
  check(waitFor([] { return d.view().screen == Screen::Idle && d.view().online; }, 12000), "恢復後回到閒置畫面");
  check(s_fake.find("boot").size() == 1, "離線期間的 boot 事件於恢復後送出");
}

int main(int argc, char **argv) {
  const std::string which = argc > 1 ? argv[1] : "flow";
  if (which == "flow") flow();
  else if (which == "reboot") reboot();
  else if (which == "offline") offline();
  printf("%s：%s\n", which.c_str(), s_failed ? "有失敗" : "全部通過");
  fflush(stdout);
  _exit(s_failed ? 1 : 0);
}
