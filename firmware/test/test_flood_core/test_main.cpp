#include <cstdint>
#include <unity.h>
#include "A02Parser.h"
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

int main() {
  UNITY_BEGIN();
  RUN_TEST(test_sensor_and_risk);
  return UNITY_END();
}
