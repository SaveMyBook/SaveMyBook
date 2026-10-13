#pragma once

#include <string>

#include "view.h"

namespace smb {

// 依 View 繪製橫向 320×240 畫面。版面對應模擬書櫃的直式版面，內容與字串相同。
// 回傳 true 表示畫面有動畫（轉圈、倒數），應以較高頻率重畫。
bool ui_draw(const View &v);
// 畫面工作平常每 250 毫秒重畫；狀態改變時呼叫，立即重畫（實作在 main.cpp 的畫面工作）。
void ui_wake();
// 預先產生 QR Code（網路與 Wi-Fi 工作在核心 0 呼叫），畫面工作畫的時候不必再花約 30 毫秒。可在任何工作呼叫。
void ui_prepare_qr(const std::string &payload);

}  // namespace smb
