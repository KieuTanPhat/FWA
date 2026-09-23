#include <Arduino.h>
#include <ArduinoJson.h>
#include <ArduinoMqttClient.h>
#include <DallasTemperature.h>
#include <OneWire.h>
#include <WiFi.h>
#include <time.h>
#include "A02Parser.h"
#include "AlertOutbox.h"
#include "RiskEngine.h"
#include "demo_config.h"
#if __has_include("secrets.h")
#include "secrets.h"
#else
#include "secrets.example.h"  // Biên dịch CI; credential mẫu không kết nối broker.
#endif

// Giá trị chỉ để demo trên jig cao 200 cm; không dùng cho an toàn thực địa.
static const RiskConfig kDemoRisk{200,30,50,70,5,10,15,5,3,4,3000};
static RiskEngine engine(kDemoRisk);
static A02Parser parser;
static AlertOutbox outbox;
static HardwareSerial sensorSerial(2);
static OneWire oneWire(FWA_ONEWIRE_PIN);
static DallasTemperature temperatureSensor(&oneWire);
static WiFiClient wifiClient;
static MqttClient mqtt(wifiClient);
static QueueHandle_t telemetryQueue;
static char bootId[17];
static uint32_t sequence = 0;
static uint32_t alertSequence = 0;
static uint32_t lastTelemetryMs = 0;
static uint32_t lastValidFrameMs = 0;
static float temperatureC = NAN;
static volatile uint32_t rainTicks = 0;
static volatile uint32_t lastRainPulseUs = 0;
static portMUX_TYPE rainMux = portMUX_INITIALIZER_UNLOCKED;
static bool storageFault = false;

struct TelemetryPayload { char json[768]; };

static String topic(const char* suffix) {
  return String("flood/") + FWA_STATION_ID + "/" + suffix;
}

static void IRAM_ATTR rainPulse() {
  const uint32_t now = micros();
  portENTER_CRITICAL_ISR(&rainMux);
  if (now - lastRainPulseUs > 100000) { ++rainTicks; lastRainPulseUs = now; }
  portEXIT_CRITICAL_ISR(&rainMux);
}

static uint32_t readRainTicks() {
  portENTER_CRITICAL(&rainMux);
  const uint32_t value = rainTicks;
  portEXIT_CRITICAL(&rainMux);
  return value;
}

static bool syncedClock() { return time(nullptr) > 1700000000; }

static void addDeviceTime(JsonDocument& doc) {
  if (!syncedClock()) {
    doc["device_ts"] = nullptr;
    doc["time_quality"] = "UNSYNCED";
    return;
  }
  char buffer[25];
  const time_t now = time(nullptr);
  struct tm utc;
  gmtime_r(&now, &utc);
  strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%SZ", &utc);
  doc["device_ts"] = buffer;
  doc["time_quality"] = "SYNCED";
}

static const char* waterQuality(const RiskSnapshot& risk) {
  if (risk.validity == RiskValidity::VALID) return "GOOD";
  if (!kDemoRisk.valid() || (lastValidFrameMs != 0 && millis() - lastValidFrameMs > kDemoRisk.stale_ms)) return "BAD";
  return "UNKNOWN";
}

static const char* health(const RiskSnapshot& risk) {
  if (!kDemoRisk.valid() || storageFault || outbox.full()) return "FAULT";
  if (risk.validity == RiskValidity::UNKNOWN) return "DEGRADED";
  return "OK";
}

static void addQuality(JsonDocument& doc, const RiskSnapshot& risk) {
  JsonObject q = doc["sensor_quality"].to<JsonObject>();
  q["water"] = waterQuality(risk);
  q["rain"] = FWA_RAIN_ENABLED ? "GOOD" : "UNKNOWN";
  q["temperature"] = FWA_TEMPERATURE_ENABLED && isfinite(temperatureC) ? "GOOD" : "UNKNOWN";
}

static void localOutput(const RiskSnapshot& risk, uint32_t now) {
  bool led = false;
  bool buzzer = false;
  if (risk.validity == RiskValidity::UNKNOWN || outbox.full() || storageFault) {
    led = (now % 1000) < 100;  // Lỗi: một chớp ngắn/giây, còi tắt.
  } else if (risk.level == RiskLevel::WATCH) {
    led = (now % 1000) < 500;
  } else if (risk.level == RiskLevel::WARNING) {
    led = (now % 500) < 250;
    buzzer = (now % 2000) < 300;
  } else if (risk.level == RiskLevel::EMERGENCY) {
    led = (now % 200) < 100;
    buzzer = (now % 500) < 250;
  }
  digitalWrite(FWA_LED_PIN, led ? HIGH : LOW);
  digitalWrite(FWA_BUZZER_PIN, buzzer ? HIGH : LOW);
}

static void queueTelemetry(const RiskSnapshot& risk) {
  JsonDocument doc;
  const uint32_t seq = ++sequence;
  doc["schema_version"] = 1;
  doc["station_id"] = FWA_STATION_ID;
  doc["boot_id"] = bootId;
  doc["sequence"] = seq;
  doc["message_id"] = String(FWA_STATION_ID) + ":" + bootId + ":" + seq;
  addDeviceTime(doc);
  doc["uptime_ms"] = millis();
  if (risk.has_water) doc["water_level_cm"] = risk.water_level_cm; else doc["water_level_cm"] = nullptr;
  if (risk.has_rate) doc["rise_rate_cm_min"] = risk.rise_rate_cm_min; else doc["rise_rate_cm_min"] = nullptr;
  if (FWA_RAIN_ENABLED) {
    doc["rain_tick_count"] = readRainTicks();
    doc["rain_mm_per_tick"] = FWA_RAIN_MM_PER_TICK;
  } else {
    doc["rain_tick_count"] = nullptr;
    doc["rain_mm_per_tick"] = nullptr;
  }
  if (FWA_TEMPERATURE_ENABLED && isfinite(temperatureC)) doc["temperature_c"] = temperatureC;
  else doc["temperature_c"] = nullptr;
  if (risk.validity == RiskValidity::VALID) doc["risk_level"] = riskLevelName(risk.level);
  else doc["risk_level"] = nullptr;
  doc["risk_validity"] = risk.validity == RiskValidity::VALID ? "VALID" : "UNKNOWN";
  addQuality(doc, risk);
  doc["device_health"] = health(risk);
  doc["outbox_lost_event_count"] = outbox.lostEvents();
  doc["firmware_version"] = FWA_FIRMWARE_VERSION;
  doc["config_version"] = FWA_CONFIG_VERSION;
  doc["battery_v"] = nullptr;
  TelemetryPayload item{};
  if (measureJson(doc) >= sizeof(item.json)) { storageFault = true; return; }
  serializeJson(doc, item.json, sizeof(item.json));
  xQueueOverwrite(telemetryQueue, &item);
}

static void persistAlert(const RiskSnapshot& risk, const char* reason) {
  JsonDocument doc;
  const uint32_t seq = ++alertSequence;
  doc["schema_version"] = 1;
  doc["alert_id"] = String(FWA_STATION_ID) + ":" + bootId + ":alert:" + seq;
  doc["station_id"] = FWA_STATION_ID;
  doc["boot_id"] = bootId;
  doc["sequence"] = seq;
  addDeviceTime(doc);
  doc["previous_level"] = riskLevelName(risk.previous_level);
  if (risk.validity == RiskValidity::VALID) doc["current_level"] = riskLevelName(risk.level);
  else doc["current_level"] = nullptr;
  doc["risk_validity"] = risk.validity == RiskValidity::VALID ? "VALID" : "UNKNOWN";
  JsonArray reasons = doc["reason_codes"].to<JsonArray>();
  reasons.add(reason);
  addQuality(doc, risk);
  doc["config_version"] = FWA_CONFIG_VERSION;
  doc["firmware_version"] = FWA_FIRMWARE_VERSION;
  String payload;
  serializeJson(doc, payload);
  if (!outbox.enqueue(payload)) storageFault = true;
  if (storageFault) Serial.printf("Outbox lỗi hoặc đầy; event chưa lưu: %lu\n", static_cast<unsigned long>(outbox.lostEvents()));
}

static bool publish(const String& mqttTopic, const String& body, bool retain) {
  if (!mqtt.connected()) return false;
  if (!mqtt.beginMessage(mqttTopic, body.length(), retain, 1)) return false;
  mqtt.print(body);
  return mqtt.endMessage() == 1;
}

static String statusPayload(const char* state) {
  JsonDocument doc;
  doc["schema_version"] = 1;
  doc["station_id"] = FWA_STATION_ID;
  doc["boot_id"] = bootId;
  doc["state"] = state;
  doc["firmware_version"] = FWA_FIRMWARE_VERSION;
  doc["uptime_ms"] = millis();
  doc["device_health"] = health(engine.snapshot());
  String payload;
  serializeJson(doc, payload);
  return payload;
}

static void onMqttMessage(int size) {
  if (mqtt.messageTopic() != topic("alert/ack") || size > 256) return;
  String json;
  while (mqtt.available()) json += static_cast<char>(mqtt.read());
  JsonDocument doc;
  if (deserializeJson(doc, json)) return;
  const String alertId = doc["alert_id"].as<String>();
  if (alertId.startsWith(String(FWA_STATION_ID) + ":")) outbox.ack(alertId);
}

static void networkTask(void*) {
  mqtt.setId(FWA_STATION_ID);
  mqtt.setUsernamePassword(FWA_MQTT_USER, FWA_MQTT_PASSWORD);
  mqtt.setCleanSession(false);
  mqtt.setConnectionTimeout(2000);
  mqtt.onMessage(onMqttMessage);
  const String offline = statusPayload("OFFLINE");
  mqtt.beginWill(topic("status"), offline.length(), true, 1);
  mqtt.print(offline);
  mqtt.endWill();
  uint32_t lastWifiTry = 0, lastMqttTry = 0, lastStatus = 0, lastAlertTry = 0;
  bool timeConfigured = false;
  for (;;) {
    const uint32_t now = millis();
    if (WiFi.status() != WL_CONNECTED) {
      if (now - lastWifiTry > 5000) { lastWifiTry = now; WiFi.begin(FWA_WIFI_SSID, FWA_WIFI_PASSWORD); }
      vTaskDelay(pdMS_TO_TICKS(100));
      continue;
    }
    if (!timeConfigured) { configTime(0, 0, "pool.ntp.org"); timeConfigured = true; }
    if (!mqtt.connected()) {
      if (now - lastMqttTry > 3000) {
        lastMqttTry = now;
        if (mqtt.connect(FWA_MQTT_HOST, FWA_MQTT_PORT)) {
          Serial.println("MQTT đã kết nối");
          mqtt.subscribe(topic("alert/ack"), 1);
          publish(topic("status"), statusPayload("ONLINE"), true);
        }
      }
      vTaskDelay(pdMS_TO_TICKS(100));
      continue;
    }
    mqtt.poll();
    if (now - lastStatus >= 5000) {
      lastStatus = now;
      publish(topic("status"), statusPayload("ONLINE"), true);
    }
    TelemetryPayload payload{};
    if (xQueueReceive(telemetryQueue, &payload, 0) == pdTRUE) publish(topic("telemetry"), payload.json, false);
    if (now - lastAlertTry >= 1500) {
      lastAlertTry = now;
      String alert;
      if (outbox.peek(alert)) publish(topic("alert"), alert, false);
    }
    vTaskDelay(pdMS_TO_TICKS(50));
  }
}

void setup() {
  pinMode(FWA_LED_PIN, OUTPUT);
  pinMode(FWA_BUZZER_PIN, OUTPUT);
  digitalWrite(FWA_LED_PIN, LOW);
  digitalWrite(FWA_BUZZER_PIN, LOW);
  Serial.begin(115200);
  const uint64_t random = (static_cast<uint64_t>(esp_random()) << 32) | esp_random();
  snprintf(bootId, sizeof(bootId), "%08lx%08lx", static_cast<unsigned long>(random >> 32),
           static_cast<unsigned long>(random & 0xffffffff));
  sensorSerial.begin(9600, SERIAL_8N1, FWA_SENSOR_RX_PIN, -1);
  if (FWA_RAIN_ENABLED) {
    pinMode(FWA_RAIN_PIN, INPUT_PULLUP);
    attachInterrupt(digitalPinToInterrupt(FWA_RAIN_PIN), rainPulse, FALLING);
  }
  if (FWA_TEMPERATURE_ENABLED) temperatureSensor.begin();
  storageFault = !outbox.begin() || !kDemoRisk.valid();
  Serial.printf("Boot %s, cấu hình demo %s, outbox lỗi: %s\n", bootId, FWA_CONFIG_VERSION,
                storageFault ? "CÓ" : "KHÔNG");
  telemetryQueue = xQueueCreate(1, sizeof(TelemetryPayload));
  if (!telemetryQueue) storageFault = true;
  WiFi.mode(WIFI_STA);
  xTaskCreatePinnedToCore(networkTask, "network", 8192, nullptr, 1, nullptr, 0);
}

void loop() {
  const uint32_t now = millis();
  while (sensorSerial.available()) {
    uint16_t distance = 0;
    if (!parser.feed(static_cast<uint8_t>(sensorSerial.read()), distance)) continue;
    lastValidFrameMs = now;
    const auto risk = engine.addDistance(distance, now);
    localOutput(risk, now);  // Thi hành tại chỗ trước mọi thao tác mạng/lưu sự kiện.
    if (risk.changed) Serial.printf("Rủi ro đổi cấp: %s\n", riskLevelName(risk.level));
    if (risk.changed) persistAlert(risk, "WATER_OR_RISE_THRESHOLD");
    else if (risk.validity_changed) persistAlert(risk, "SENSOR_RECOVERED");
  }
  const auto risk = engine.tick(now);
  localOutput(risk, now);
  if (risk.validity_changed) persistAlert(risk, "SENSOR_TIMEOUT");
  if (FWA_TEMPERATURE_ENABLED && now % 5000 < 50) {
    temperatureSensor.requestTemperatures();
    const float value = temperatureSensor.getTempCByIndex(0);
    temperatureC = value > -55 && value < 125 ? value : NAN;
  }
  if (now - lastTelemetryMs >= 5000 && telemetryQueue) {
    lastTelemetryMs = now;
    queueTelemetry(risk);
  }
  delay(20);
}
