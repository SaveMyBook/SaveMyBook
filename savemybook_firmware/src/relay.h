#pragma once

namespace smb {

// 開機後第一件事：把所有繼電器腳位設為斷電後才切成輸出，電磁鎖維持上鎖。
void relay_init();
void relay_all_off();
// 通道 1–4 通電 ms 毫秒後斷電（阻塞）。通電前先讓其他通道斷電，任何時刻只有一個電磁鎖通電；時間限制在 100–3000 毫秒，避免線圈過熱。
void relay_pulse(int channel, int ms);

}  // namespace smb
