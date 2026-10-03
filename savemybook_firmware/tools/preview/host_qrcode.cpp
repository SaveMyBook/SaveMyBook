// 電腦預覽用：以元件內附的 qrcodegen 實作 esp_qrcode_*，參數與 esp_qrcode_main.c 相同。
#include <cstdlib>

#include "qrcode.h"
#include "qrcodegen.h"

esp_err_t esp_qrcode_generate(esp_qrcode_config_t *cfg, const char *text) {
  const int size = qrcodegen_BUFFER_LEN_FOR_VERSION(cfg->max_qrcode_version);
  uint8_t *qr = static_cast<uint8_t *>(calloc(1, size)), *tmp = static_cast<uint8_t *>(calloc(1, size));
  const qrcodegen_Ecc ecc[] = {qrcodegen_Ecc_LOW, qrcodegen_Ecc_MEDIUM, qrcodegen_Ecc_QUARTILE, qrcodegen_Ecc_HIGH};
  const bool ok = qrcodegen_encodeText(text, tmp, qr, ecc[cfg->qrcode_ecc_level], qrcodegen_VERSION_MIN,
                                       cfg->max_qrcode_version, qrcodegen_Mask_AUTO, true);
  if (ok) cfg->display_func_with_cb(qr, cfg->user_data);
  free(qr);
  free(tmp);
  return ok ? ESP_OK : ESP_FAIL;
}
int esp_qrcode_get_size(esp_qrcode_handle_t q) { return qrcodegen_getSize(q); }
bool esp_qrcode_get_module(esp_qrcode_handle_t q, int x, int y) { return qrcodegen_getModule(q, x, y); }
