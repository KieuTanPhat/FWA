#pragma once

#include <stdint.h>
#include "RiskEngine.h"

struct LocalAlertOutput {
  bool led_on;
  bool buzzer_on;
};

LocalAlertOutput localAlertOutput(const RiskSnapshot& risk, uint32_t now_ms, bool system_fault);
