#pragma once

namespace smb {

// 自製主控板 Rev A 的整板測試（以 -DSMB_HW_TEST_BOARD=1 編譯 hwtest）：螢幕顯示色條與四個門磁的即時狀態，
// 繼電器自動輪流通電；USB 孔可下指令單獨控制，BOOT 鍵切換自動模式。
[[noreturn]] void board_test();

}  // namespace smb
