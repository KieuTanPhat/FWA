import assert from 'node:assert/strict';
import { test } from 'node:test';
import { scenarios } from './scenarios';

test('mọi kịch bản định danh lỗi sensor và không gọi NORMAL khi mất số đo', () => {
  for (const [name, steps] of Object.entries(scenarios)) {
    assert.ok(steps.length > 0, name);
    for (const step of steps) {
      assert.equal(step.waterLevelCm === null, step.risk === null, name);
    }
  }
});

test('kịch bản tăng nước có đủ các cấp', () => {
  assert.deepEqual([...new Set(scenarios.rise.map(s => s.risk))], ['NORMAL', 'WATCH', 'WARNING', 'EMERGENCY']);
});
