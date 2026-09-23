#include <cstdint>
#include <unity.h>
#include "A02Parser.h"
#include "LocalAlert.h"
#include "RiskEngine.h"

static RiskConfig config{200,30,50,70,5,10,15,5,3,4,3000};

void setUp() {}
void tearDown() {}

void test_sensor_and_risk() {
  A02Parser parser;
  uint16_t mm = 0;
  TEST_ASSERT_FALSE(parser.feed(0x00, mm));
  TEST_ASSERT_FALSE(parser.feed(0xFF, mm));
  TEST_ASSERT_FALSE(parser.feed(0x07, mm));
  TEST_ASSERT_FALSE(parser.feed(0xA1, mm));
  TEST_ASSERT_TRUE(parser.feed(0xA7, mm));
  TEST_ASSERT_EQUAL_UINT16(1953, mm);
  TEST_ASSERT_FALSE(parser.feed(0xFF, mm));
  TEST_ASSERT_FALSE(parser.feed(0x07, mm));
  TEST_ASSERT_FALSE(parser.feed(0xA1, mm));
  TEST_ASSERT_FALSE(parser.feed(0x00, mm));
  TEST_ASSERT_EQUAL_UINT32(1, parser.invalidFrames());

  TEST_ASSERT_TRUE(config.valid());
  RiskEngine engine(config);
  TEST_ASSERT_TRUE(engine.snapshot().validity == RiskValidity::UNKNOWN);
  engine.addDistance(1800, 0);
  engine.addDistance(1800, 1000);
  TEST_ASSERT_TRUE(engine.snapshot().validity == RiskValidity::UNKNOWN);
  for (int i = 2; i < 6; ++i) engine.addDistance(1800, i * 1000);
  TEST_ASSERT_TRUE(engine.snapshot().level == RiskLevel::NORMAL);
  engine.addDistance(700, 6000); // Một outlier không kích hoạt mức khẩn.
  TEST_ASSERT_TRUE(engine.snapshot().level == RiskLevel::NORMAL);
  for (int i = 7; i < 14; ++i) engine.addDistance(700, i * 1000);
  TEST_ASSERT_TRUE(engine.snapshot().level == RiskLevel::EMERGENCY);
  TEST_ASSERT_TRUE(engine.snapshot().validity == RiskValidity::VALID);
  engine.tick(18000);
  TEST_ASSERT_TRUE(engine.snapshot().validity == RiskValidity::UNKNOWN);
  TEST_ASSERT_FALSE(engine.snapshot().has_water);
  engine.addDistance(1800, 19000);
  TEST_ASSERT_TRUE(engine.snapshot().validity == RiskValidity::UNKNOWN);
  engine.addDistance(1800, 20000);
  engine.addDistance(1800, 21000);
  TEST_ASSERT_TRUE(engine.snapshot().validity == RiskValidity::VALID);
}

void test_sensor_bounds_and_frame_rejection() {
  A02Parser parser;
  uint16_t mm = 0;
  // Khoảng cách 20 mm (< 30 mm, vùng mù): frame 0xFF, 0x00, 0x14, CS = 0xFF + 0x00 + 0x14 = 0x13
  TEST_ASSERT_FALSE(parser.feed(0xFF, mm));
  TEST_ASSERT_FALSE(parser.feed(0x00, mm));
  TEST_ASSERT_FALSE(parser.feed(0x14, mm));
  TEST_ASSERT_FALSE(parser.feed(0x13, mm));
  TEST_ASSERT_EQUAL_UINT32(1, parser.invalidFrames());

  // Khoảng cách 4600 mm (> 4500 mm, ngoài dải): frame 0xFF, 0x11, 0xF8, CS = (0xFF + 0x11 + 0xF8) & 0xFF = 0x08
  TEST_ASSERT_FALSE(parser.feed(0xFF, mm));
  TEST_ASSERT_FALSE(parser.feed(0x11, mm));
  TEST_ASSERT_FALSE(parser.feed(0xF8, mm));
  TEST_ASSERT_FALSE(parser.feed(0x08, mm));
  TEST_ASSERT_EQUAL_UINT32(2, parser.invalidFrames());

  // Byte rác giữa chừng và tự phục hồi khi thấy 0xFF
  TEST_ASSERT_FALSE(parser.feed(0x12, mm));
  TEST_ASSERT_FALSE(parser.feed(0x34, mm));
  TEST_ASSERT_FALSE(parser.feed(0xFF, mm)); // Bắt đầu frame mới
  TEST_ASSERT_FALSE(parser.feed(0x07, mm));
  TEST_ASSERT_FALSE(parser.feed(0xA1, mm));
  TEST_ASSERT_TRUE(parser.feed(0xA7, mm));  // Hợp lệ 1953 mm
  TEST_ASSERT_EQUAL_UINT16(1953, mm);
}

void test_stationary_water_vs_sensor_timeout() {
  RiskEngine engine(config);
  uint32_t now = 0;
  // Mặt nước đứng yên hoàn toàn: 30 mẫu liên tiếp cùng 1850 mm
  for (int i = 0; i < 30; ++i) {
    engine.addDistance(1850, now);
    now += 1000;
  }
  // Mặt nước đứng yên là hiện tượng vật lý bình thường, rủi ro là NORMAL và validity là VALID
  TEST_ASSERT_TRUE(engine.snapshot().level == RiskLevel::NORMAL);
  TEST_ASSERT_TRUE(engine.snapshot().validity == RiskValidity::VALID);
  TEST_ASSERT_TRUE(engine.snapshot().has_water);

  // Mất tín hiệu cảm biến quá stale_ms (3000 ms)
  now += 3500;
  engine.tick(now);
  // Khi timeout: chuyển sang UNKNOWN, không giữ NORMAL an toàn giả
  TEST_ASSERT_TRUE(engine.snapshot().validity == RiskValidity::UNKNOWN);
  TEST_ASSERT_FALSE(engine.snapshot().has_water);
}

void test_storage_fault_does_not_mute_flood_alarm() {
  RiskSnapshot risk{};
  risk.validity = RiskValidity::VALID;
  risk.level = RiskLevel::EMERGENCY;
  const auto normal = localAlertOutput(risk, 1200, false);
  const auto storageFault = localAlertOutput(risk, 1200, true);
  TEST_ASSERT_TRUE(normal.buzzer_on);
  TEST_ASSERT_TRUE(storageFault.buzzer_on);
  TEST_ASSERT_TRUE(normal.led_on);
  TEST_ASSERT_FALSE(storageFault.led_on);

  risk.validity = RiskValidity::UNKNOWN;
  const auto sensorFault = localAlertOutput(risk, 0, false);
  TEST_ASSERT_TRUE(sensorFault.led_on);
  TEST_ASSERT_FALSE(sensorFault.buzzer_on);
}

void test_risk_confirmation_and_hysteresis() {
  RiskEngine engine(config);
  uint32_t now = 0;
  for (int i = 0; i < 6; ++i) {
    engine.addDistance(1800, now);
    now += 1000;
  }
  TEST_ASSERT_TRUE(engine.snapshot().level == RiskLevel::NORMAL);

  uint16_t distance = 1800;
  for (int step = 0; step < 110; ++step) {
    --distance;
    for (int sample = 0; sample < 6; ++sample) {
      engine.addDistance(distance, now);
      now += 1000;
    }
  }
  TEST_ASSERT_TRUE(engine.snapshot().level == RiskLevel::WATCH);

  for (int sample = 0; sample < 8; ++sample) {
    engine.addDistance(1709, now);  // 29.1 cm: under WATCH threshold, above clear hysteresis.
    now += 1000;
  }
  TEST_ASSERT_TRUE(engine.snapshot().level == RiskLevel::WATCH);

  for (int sample = 0; sample < 12; ++sample) {
    engine.addDistance(1760, now);  // 24 cm: clear only after filter and clear samples.
    now += 1000;
  }
  TEST_ASSERT_TRUE(engine.snapshot().level == RiskLevel::NORMAL);
}

int main() {
  UNITY_BEGIN();
  RUN_TEST(test_sensor_and_risk);
  RUN_TEST(test_sensor_bounds_and_frame_rejection);
  RUN_TEST(test_stationary_water_vs_sensor_timeout);
  RUN_TEST(test_storage_fault_does_not_mute_flood_alarm);
  RUN_TEST(test_risk_confirmation_and_hysteresis);
  return UNITY_END();
}
