#include "LocalAlert.h"

LocalAlertOutput localAlertOutput(const RiskSnapshot& risk, uint32_t now_ms, bool system_fault) {
  LocalAlertOutput output{false, false};
  if (risk.validity == RiskValidity::UNKNOWN) {
    output.led_on = now_ms % 1000 < 100;  // Lỗi cảm biến: chớp ngắn mỗi giây, còi lũ tắt.
  } else if (risk.level == RiskLevel::WATCH) {
    output.led_on = now_ms % 1000 < 500;
  } else if (risk.level == RiskLevel::WARNING) {
    output.led_on = now_ms % 500 < 250;
    output.buzzer_on = now_ms % 2000 < 300;
  } else if (risk.level == RiskLevel::EMERGENCY) {
    output.led_on = now_ms % 200 < 100;
    output.buzzer_on = now_ms % 500 < 250;
  }

  if (system_fault) {
    // Ba chớp nhanh mỗi hai giây báo lỗi lưu trữ mà không tắt còi theo cấp rủi ro.
    const uint32_t phase = now_ms % 2000;
    const bool fault_pulse = (phase >= 1200 && phase < 1260) ||
      (phase >= 1320 && phase < 1380) || (phase >= 1440 && phase < 1500);
    output.led_on = output.led_on != fault_pulse;
  }
  return output;
}
