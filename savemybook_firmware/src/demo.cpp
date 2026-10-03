#include "demo.h"

#include "messages.h"

namespace smb {

std::vector<View> demo_views() {
  View base;
  base.header = msg("HW_TITLE");

  std::vector<View> demos;
  View v = base;
  v.screen = Screen::Pairing;
  v.lines = {msg("PAIRING_TITLE"), "1234-5678", msg("PAIRING_PROMPT"), format("PAIRING_REMAINING", {{"time", "9:42"}})};
  v.pairCode = "1234-5678";
  v.pairRemainingMs = 582000;
  v.pairTotalMs = 600000;
  demos.push_back(v);

  v = base;
  v.screen = Screen::Idle;
  v.lines = {msg("IDLE_SCAN")};
  v.qr = "savemybook://k/3f9c0a5e1d2b4c6a8e0f1a2b3c4d5e6f";
  v.qrRatio = 0.62f;
  demos.push_back(v);

  v = base;
  v.screen = Screen::Match;
  v.lines = {msg("MATCH_PROMPT"), "25", format("REMAINING_SECONDS", {{"seconds", "52"}})};
  v.code = "25";
  v.hasCountdown = true;
  v.remainingMs = 52000;
  v.totalMs = 60000;
  demos.push_back(v);

  v = base;
  v.screen = Screen::Open;
  v.doorLabels = {"A01"};
  v.lines = {"A01", format("OPEN_DEPOSIT", {{"doors", "A01"}})};
  v.hasCountdown = true;
  v.remainingMs = 26000;
  v.totalMs = 30000;
  demos.push_back(v);

  v.doorLabels = {"A01", "A02", "A03"};
  v.lines = {"A01、A02、A03", format("OPEN_PICKUP", {{"doors", "A01、A02、A03"}})};
  v.remainingMs = 4000;
  demos.push_back(v);

  v = base;
  v.screen = Screen::ClosedHours;
  v.icon = Icon::Clock;
  v.lines = {"目前非營業時間", "營業時間 08:00–22:00"};
  demos.push_back(v);

  v = base;
  v.screen = Screen::Result;
  v.icon = Icon::Check;
  v.lines = {msg("RESULT_DONE")};
  demos.push_back(v);

  v = base;
  v.screen = Screen::WifiSetup;
  v.qr = "{\"ver\":\"v1\",\"name\":\"PROV_A1B2C3\",\"pop\":\"k7m2q9x4\",\"transport\":\"ble\"}";
  v.lines = {msg("WIFI_TITLE"), msg("WIFI_SCAN")};
  demos.push_back(v);

  v = base;
  v.screen = Screen::Select;
  v.lines = {"書櫃使用中", "請於手機確認項目", format("REMAINING_SECONDS", {{"seconds", "88"}})};
  v.hasCountdown = true;
  v.remainingMs = 88000;
  v.totalMs = 120000;
  demos.push_back(v);

  v = base;
  v.screen = Screen::Opening;
  v.lines = {msg("OPENING")};
  demos.push_back(v);

  v = base;
  v.screen = Screen::Admin;
  v.doorLabels = {"A01", "A02", "A03", "A04"};
  v.lines = {"A01、A02、A03、A04", msg("OPEN_ADMIN")};
  v.hasCountdown = true;
  v.remainingMs = 41000;
  v.totalMs = 60000;
  demos.push_back(v);

  v = base;
  v.screen = Screen::Maintenance;
  v.icon = Icon::Wrench;
  v.lines = {msg("MAINTENANCE")};
  demos.push_back(v);

  v = base;
  v.screen = Screen::Result;
  v.icon = Icon::Alert;
  v.lines = {msg("RESULT_MATCH_FAILED")};
  demos.push_back(v);

  v = base;
  v.screen = Screen::Offline;
  v.lines = {msg("OFFLINE")};
  demos.push_back(v);

  v = base;
  v.screen = Screen::Pairing;
  v.lines = {msg("PAIRING_TITLE"), msg("PAIRING_RETRY")};
  v.pairError = true;
  demos.push_back(v);

  v = base;
  v.screen = Screen::WifiConnecting;
  v.lines = {msg("WIFI_CONNECTING"), msg("WIFI_RESET_HINT")};
  demos.push_back(v);

  return demos;
}

}  // namespace smb
