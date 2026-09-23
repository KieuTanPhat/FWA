#include "A02Parser.h"

bool A02Parser::feed(uint8_t byte, uint16_t& distance_mm) {
  if (index_ == 0) {
    if (byte == 0xFF) { frame_[0] = byte; index_ = 1; }
    return false;
  }
  frame_[index_++] = byte;
  if (index_ < 4) return false;
  index_ = 0;
  const uint8_t checksum = static_cast<uint8_t>(frame_[0] + frame_[1] + frame_[2]);
  if (checksum != frame_[3]) { ++invalid_frames_; return false; }
  const uint16_t value = (static_cast<uint16_t>(frame_[1]) << 8) | frame_[2];
  if (value < 30 || value > 4500) { ++invalid_frames_; return false; }
  distance_mm = value;
  return true;
}

void A02Parser::reset() { index_ = 0; }
