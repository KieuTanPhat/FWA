#pragma once
#include <Arduino.h>
#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>

class AlertOutbox {
 public:
  bool begin();
  bool enqueue(const String& payload);
  bool peek(String& payload);
  bool ack(const String& alertId);
  bool full() const { return full_; }
  uint32_t lostEvents() const { return lost_events_; }

 private:
  static constexpr int kSlots = 16;
  SemaphoreHandle_t mutex_ = nullptr;
  bool ready_ = false;
  bool full_ = false;
  uint32_t lost_events_ = 0;
  uint32_t next_order_ = 0;
  String path(int slot) const;
  void recordLoss();
};
