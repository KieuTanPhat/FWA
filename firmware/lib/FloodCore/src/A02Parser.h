#pragma once
#include <cstdint>

// SEN0311: FF, high, low, checksum = (FF + high + low) & FF; đơn vị mm.
class A02Parser {
 public:
  bool feed(uint8_t byte, uint16_t& distance_mm);
  void reset();
  uint32_t invalidFrames() const { return invalid_frames_; }

 private:
  uint8_t frame_[4]{};
  uint8_t index_ = 0;
  uint32_t invalid_frames_ = 0;
};
