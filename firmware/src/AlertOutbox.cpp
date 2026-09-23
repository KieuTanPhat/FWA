#include "AlertOutbox.h"
#include <ArduinoJson.h>
#include <LittleFS.h>
#include <Preferences.h>

String AlertOutbox::path(int slot) const {
  char buffer[20];
  snprintf(buffer, sizeof(buffer), "/alert-%02d.json", slot);
  return String(buffer);
}

bool AlertOutbox::begin() {
  mutex_ = xSemaphoreCreateMutex();
  ready_ = mutex_ && LittleFS.begin(false);
  Preferences p;
  if (p.begin("fwa-outbox", true)) {
    lost_events_ = p.getUInt("lost", 0);
    next_order_ = p.getUInt("next", 0);
    p.end();
  }
  if (ready_) {
    int occupied = 0;
    for (int i = 0; i < kSlots; ++i) if (LittleFS.exists(path(i))) ++occupied;
    full_.store(occupied >= kSlots);
  }
  return ready_;
}

void AlertOutbox::recordLoss() {
  ++lost_events_;
  Preferences p;
  if (p.begin("fwa-outbox", false)) { p.putUInt("lost", lost_events_); p.end(); }
}

bool AlertOutbox::enqueue(const String& payload) {
  if (!ready_ || xSemaphoreTake(mutex_, pdMS_TO_TICKS(200)) != pdTRUE) {
    recordLoss();
    return false;
  }
  int slot = -1;
  for (int i = 0; i < kSlots; ++i) {
    if (!LittleFS.exists(path(i))) { slot = i; break; }
  }
  if (slot < 0) {
    full_.store(true);
    recordLoss();
    xSemaphoreGive(mutex_);
    return false;
  }
  const uint32_t order = ++next_order_;
  Preferences p;
  if (p.begin("fwa-outbox", false)) { p.putUInt("next", next_order_); p.end(); }
  File f = LittleFS.open("/alert-tmp.json", "w");
  bool ok = f && f.println(order) > 0 && f.print(payload) == payload.length();
  if (f) f.close();
  if (ok) ok = LittleFS.rename("/alert-tmp.json", path(slot));
  if (!ok) LittleFS.remove("/alert-tmp.json");
  if (!ok) recordLoss();
  if (ok) {
    int occupied = 0;
    for (int i = 0; i < kSlots; ++i) if (LittleFS.exists(path(i))) ++occupied;
    full_.store(occupied >= kSlots);
  }
  xSemaphoreGive(mutex_);
  return ok;
}

bool AlertOutbox::peek(String& payload) {
  if (!ready_ || xSemaphoreTake(mutex_, pdMS_TO_TICKS(200)) != pdTRUE) return false;
  bool found = false;
  uint32_t oldest = UINT32_MAX;
  for (int i = 0; i < kSlots; ++i) {
    if (!LittleFS.exists(path(i))) continue;
    File f = LittleFS.open(path(i), "r");
    if (!f) continue;
    const uint32_t order = f.readStringUntil('\n').toInt();
    const String body = f.readString();
    f.close();
    if (order < oldest && body.length() > 0) { oldest = order; payload = body; found = true; }
  }
  xSemaphoreGive(mutex_);
  return found;
}

bool AlertOutbox::ack(const String& alertId) {
  if (!ready_ || xSemaphoreTake(mutex_, pdMS_TO_TICKS(200)) != pdTRUE) return false;
  bool removed = false;
  for (int i = 0; i < kSlots; ++i) {
    if (!LittleFS.exists(path(i))) continue;
    File f = LittleFS.open(path(i), "r");
    if (!f) continue;
    f.readStringUntil('\n');
    JsonDocument doc;
    const auto error = deserializeJson(doc, f);
    f.close();
    if (!error && doc["alert_id"].as<String>() == alertId) {
      removed = LittleFS.remove(path(i));
      if (removed) {
        int occupied = 0;
        for (int slot = 0; slot < kSlots; ++slot) if (LittleFS.exists(path(slot))) ++occupied;
        full_.store(occupied >= kSlots);
      }
      break;
    }
  }
  xSemaphoreGive(mutex_);
  return removed;
}
