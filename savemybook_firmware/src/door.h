#pragma once

#include <functional>

namespace smb {

// 四扇櫃門的微動開關（門關上時壓下）。未啟用 SMB_DOOR_SENSOR 時一律回報關上，也不會呼叫回呼。
void door_init();
// 通道 1–4 目前是否開著（已去彈跳）。
bool door_open(int channel);
// 原始電位（0 或 1），供硬體測試確認開關方向。
int door_raw(int channel);
// 去彈跳後的狀態改變時，在門偵測工作中呼叫；呼叫端自行處理鎖定。
void door_on_change(std::function<void(int channel, bool open)> cb);

}  // namespace smb
