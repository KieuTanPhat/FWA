#include "RiskEngine.h"
#include <cmath>

bool RiskConfig::valid() const {
  return std::isfinite(datum_cm) && datum_cm >= 3 && datum_cm <= 450 &&
    0 <= watch_cm && watch_cm < warning_cm && warning_cm < emergency_cm &&
    emergency_cm < datum_cm - 3 &&
    0 < watch_rate_cm_min && watch_rate_cm_min < warning_rate_cm_min &&
    warning_rate_cm_min < emergency_rate_cm_min &&
    hysteresis_cm > 0 && hysteresis_cm < watch_cm &&
    confirm_samples >= 2 && clear_samples >= 2 && stale_ms >= 1000;
}

RiskEngine::RiskEngine(RiskConfig config) : config_(config) {}

float RiskEngine::median() const {
  float copy[kFilter]{};
  for (size_t i = 0; i < filter_count_; ++i) copy[i] = filter_[i];
  for (size_t i = 1; i < filter_count_; ++i) {
    float value = copy[i];
    size_t j = i;
    while (j > 0 && copy[j - 1] > value) { copy[j] = copy[j - 1]; --j; }
    copy[j] = value;
  }
  return copy[filter_count_ / 2];
}

RiskLevel RiskEngine::target(float level, float rate, bool has_rate, float hysteresis) const {
  if (level >= config_.emergency_cm - hysteresis ||
      (has_rate && rate >= config_.emergency_rate_cm_min)) return RiskLevel::EMERGENCY;
  if (level >= config_.warning_cm - hysteresis ||
      (has_rate && rate >= config_.warning_rate_cm_min)) return RiskLevel::WARNING;
  if (level >= config_.watch_cm - hysteresis ||
      (has_rate && rate >= config_.watch_rate_cm_min)) return RiskLevel::WATCH;
  return RiskLevel::NORMAL;
}

RiskSnapshot RiskEngine::addDistance(uint16_t distance_mm, uint32_t now_ms) {
  state_.changed = false;
  state_.validity_changed = false;
  if (!config_.valid() || distance_mm < 30 || distance_mm > 4500) return tick(now_ms);
  const float raw = config_.datum_cm - static_cast<float>(distance_mm) / 10.0f;
  filter_[filter_next_] = raw;
  filter_next_ = (filter_next_ + 1) % kFilter;
  if (filter_count_ < kFilter) ++filter_count_;
  const float filtered = median();
  const size_t last_index = (history_next_ + kHistory - 1) % kHistory;
  if (history_count_ == 0 || now_ms - history_[last_index].ms >= 1000) {
    history_[history_next_] = {now_ms, filtered};
    history_next_ = (history_next_ + 1) % kHistory;
    if (history_count_ < kHistory) ++history_count_;
  }
  state_.water_level_cm = filtered;
  state_.has_rate = false;
  // Điểm đầu tiên trong cửa sổ tối đa 60 giây, ít nhất 5 giây cách mẫu hiện tại.
  for (size_t i = 0; i < history_count_; ++i) {
    const size_t index = (history_next_ + kHistory - history_count_ + i) % kHistory;
    const auto& point = history_[index];
    const uint32_t age = now_ms - point.ms;
    if (age >= 5000 && age <= 60000) {
      state_.rise_rate_cm_min = (filtered - point.cm) * 60000.0f / age;
      state_.has_rate = true;
      break;
    }
  }
  last_good_ms_ = now_ms;
  ever_good_ = true;
  if (valid_sample_count_ < config_.confirm_samples) ++valid_sample_count_;
  if (valid_sample_count_ < config_.confirm_samples) {
    state_.has_water = false;
    return state_;
  }
  state_.has_water = true;
  if (state_.validity != RiskValidity::VALID) {
    state_.validity = RiskValidity::VALID;
    state_.validity_changed = true;
    pending_count_ = 0;
  }
  const auto up = target(filtered, state_.rise_rate_cm_min, state_.has_rate, 0);
  const auto down = target(filtered, state_.rise_rate_cm_min, state_.has_rate, config_.hysteresis_cm);
  const auto desired = static_cast<uint8_t>(up) > static_cast<uint8_t>(state_.level) ? up : down;
  if (desired == state_.level) { pending_count_ = 0; return state_; }
  if (desired != pending_) { pending_ = desired; pending_count_ = 1; }
  else if (pending_count_ < 255) ++pending_count_;
  const bool rising = static_cast<uint8_t>(desired) > static_cast<uint8_t>(state_.level);
  if (pending_count_ >= (rising ? config_.confirm_samples : config_.clear_samples)) {
    state_.previous_level = state_.level;
    state_.level = desired;
    state_.changed = true;
    pending_count_ = 0;
  }
  return state_;
}

RiskSnapshot RiskEngine::tick(uint32_t now_ms) {
  state_.changed = false;
  state_.validity_changed = false;
  if (!config_.valid() || !ever_good_ || now_ms - last_good_ms_ > config_.stale_ms) {
    if (state_.validity != RiskValidity::UNKNOWN) {
      state_.validity_changed = true;
      valid_sample_count_ = 0;
      filter_count_ = 0;
      filter_next_ = 0;
      history_count_ = 0;
      history_next_ = 0;
    }
    state_.validity = RiskValidity::UNKNOWN;
    state_.has_water = false;
    state_.has_rate = false;
    pending_count_ = 0;
  }
  return state_;
}

const char* riskLevelName(RiskLevel level) {
  switch (level) {
    case RiskLevel::NORMAL: return "NORMAL";
    case RiskLevel::WATCH: return "WATCH";
    case RiskLevel::WARNING: return "WARNING";
    case RiskLevel::EMERGENCY: return "EMERGENCY";
  }
  return "NORMAL";
}
