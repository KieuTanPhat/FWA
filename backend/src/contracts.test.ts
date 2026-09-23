import { describe, expect, it } from 'vitest';
import { statusSchema, telemetrySchema } from './contracts';
import { presentStation } from './database';

const message = {
  schema_version: 1,
  station_id: 'sim-01',
  boot_id: 'boot-1',
  sequence: 3,
  message_id: 'sim-01:boot-1:3',
  device_ts: null,
  time_quality: 'UNSYNCED',
  uptime_ms: 1500,
  water_level_cm: 40,
  rise_rate_cm_min: 2,
  rain_tick_count: 0,
  rain_mm_per_tick: 0.2,
  temperature_c: null,
  risk_level: 'NORMAL',
  risk_validity: 'VALID',
  sensor_quality: { water: 'GOOD', rain: 'GOOD', temperature: 'UNKNOWN' },
  device_health: 'OK',
  outbox_lost_event_count: 0,
  firmware_version: 'demo-1',
  config_version: 'demo-1',
  battery_v: null,
};

describe('telemetry contract', () => {
  it('phân biệt mưa 0 hợp lệ với thiếu dữ liệu', () => {
    expect(telemetrySchema.parse(message).rain_tick_count).toBe(0);
  });
  it('từ chối trạng thái an toàn khi cảm biến nước hỏng', () => {
    const bad = { ...message, sensor_quality: { ...message.sensor_quality, water: 'BAD' } };
    expect(telemetrySchema.safeParse(bad).success).toBe(false);
  });
  it('từ chối giờ thiết bị không đồng bộ nhưng có UTC', () => {
    expect(telemetrySchema.safeParse({ ...message, device_ts: '2026-01-01T00:00:00Z' }).success).toBe(false);
  });
  it('từ chối message_id sai', () => {
    expect(telemetrySchema.safeParse({ ...message, message_id: 'wrong' }).success).toBe(false);
  });
});

describe('status contract', () => {
  it('xác thực payload status hợp lệ', () => {
    const statusPayload = {
      schema_version: 1,
      station_id: 'sim-01',
      boot_id: 'boot-status-1',
      state: 'ONLINE',
      firmware_version: '0.1.0',
      uptime_ms: 12000,
      device_health: 'OK',
    };
    expect(statusSchema.safeParse(statusPayload).success).toBe(true);
  });
  it('từ chối status có uptime_ms âm hoặc sai định dạng', () => {
    const invalidStatus = {
      schema_version: 1,
      station_id: 'sim-01',
      boot_id: 'boot-status-1',
      state: 'ONLINE',
      firmware_version: '0.1.0',
      uptime_ms: -5,
      device_health: 'OK',
    };
    expect(statusSchema.safeParse(invalidStatus).success).toBe(false);
  });
});

describe('effective risk', () => {
  it('không hiển thị NORMAL là hiện hành nếu dữ liệu cũ', () => {
    const row = {
      last_status: 'ONLINE', last_status_at: new Date(0), received_at: new Date(0),
      risk_level: 'NORMAL', risk_validity: 'VALID', sensor_quality: { water: 'GOOD' },
    };
    expect(presentStation(row, 15).effective_risk_validity).toBe('UNKNOWN');
    expect(presentStation(row, 15).effective_risk_level).toBeNull();
  });
  it('không hiển thị NORMAL là hiện hành khi trạm OFFLINE', () => {
    const row = {
      last_status: 'OFFLINE', last_status_at: new Date(), received_at: new Date(),
      risk_level: 'NORMAL', risk_validity: 'VALID', sensor_quality: { water: 'GOOD' },
    };
    expect(presentStation(row, 15).effective_risk_validity).toBe('UNKNOWN');
  });
});
