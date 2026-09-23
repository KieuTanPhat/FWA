#pragma once
#include <cstddef>
#include <cstdint>

enum class RiskLevel : uint8_t { NORMAL, WATCH, WARNING, EMERGENCY };
enum class RiskValidity : uint8_t { VALID, UNKNOWN };

struct RiskConfig {
  float datum_cm;
  float watch_cm;
  float warning_cm;
  float emergency_cm;
  float watch_rate_cm_min;
  float warning_rate_cm_min;
  float emergency_rate_cm_min;
  float hysteresis_cm;
  uint8_t confirm_samples;
  uint8_t clear_samples;
  uint32_t stale_ms;
  bool valid() const;
};

struct RiskSnapshot {
  RiskLevel level = RiskLevel::NORMAL;
  RiskValidity validity = RiskValidity::UNKNOWN;
  float water_level_cm = 0;
  float rise_rate_cm_min = 0;
  bool has_water = false;
  bool has_rate = false;
  bool changed = false;
  bool validity_changed = false;
  RiskLevel previous_level = RiskLevel::NORMAL;
};

class RiskEngine {
 public:
  explicit RiskEngine(RiskConfig config);
  RiskSnapshot addDistance(uint16_t distance_mm, uint32_t now_ms);
  RiskSnapshot tick(uint32_t now_ms);
  RiskSnapshot snapshot() const { return state_; }

 private:
  struct Point { uint32_t ms; float cm; };
  static constexpr size_t kFilter = 5;
  static constexpr size_t kHistory = 64;
  RiskConfig config_;
  RiskSnapshot state_;
  float filter_[kFilter]{};
  size_t filter_count_ = 0;
  size_t filter_next_ = 0;
  Point history_[kHistory]{};
  size_t history_count_ = 0;
  size_t history_next_ = 0;
  uint32_t last_good_ms_ = 0;
  bool ever_good_ = false;
  uint8_t valid_sample_count_ = 0;
  RiskLevel pending_ = RiskLevel::NORMAL;
  uint8_t pending_count_ = 0;
  float median() const;
  RiskLevel target(float level, float rate, bool has_rate, float hysteresis) const;
};

const char* riskLevelName(RiskLevel level);
