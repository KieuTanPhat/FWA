import { z } from 'zod';

const stationId = z.string().regex(/^[a-z0-9-]{1,32}$/);
const bootId = z.string().regex(/^[A-Za-z0-9-]{1,64}$/);
const quality = z.enum(['GOOD', 'SUSPECT', 'BAD', 'UNKNOWN']);
const level = z.enum(['NORMAL', 'WATCH', 'WARNING', 'EMERGENCY']);
const validity = z.enum(['VALID', 'UNKNOWN']);
const finite = z.number().finite();
const nullableFinite = finite.nullable();
const time = z.iso.datetime({ offset: true }).nullable();

const base = z.object({
  schema_version: z.literal(1),
  station_id: stationId,
  boot_id: bootId,
  sequence: z.number().int().nonnegative().safe(),
  device_ts: time,
  time_quality: z.enum(['SYNCED', 'UNSYNCED']),
  sensor_quality: z.object({ water: quality, rain: quality, temperature: quality }),
  firmware_version: z.string().min(1).max(64),
  config_version: z.string().min(1).max(64),
}).refine(v => (v.time_quality === 'SYNCED') === (v.device_ts !== null), {
  message: 'device_ts phải có khi SYNCED và null khi UNSYNCED',
});

export const telemetrySchema = base.safeExtend({
  message_id: z.string().min(1).max(160),
  uptime_ms: z.number().int().nonnegative().safe(),
  water_level_cm: nullableFinite,
  rise_rate_cm_min: nullableFinite,
  rain_tick_count: z.number().int().nonnegative().safe().nullable(),
  rain_mm_per_tick: finite.nonnegative().nullable(),
  temperature_c: nullableFinite,
  risk_level: level.nullable(),
  risk_validity: validity,
  device_health: z.enum(['OK', 'DEGRADED', 'FAULT']),
  outbox_lost_event_count: z.number().int().nonnegative().safe(),
  battery_v: finite.nonnegative().nullable(),
}).superRefine((v, ctx) => {
  if (v.message_id !== `${v.station_id}:${v.boot_id}:${v.sequence}`) {
    ctx.addIssue({ code: 'custom', message: 'message_id không khớp station/boot/sequence' });
  }
  if ((v.risk_validity === 'VALID') !== (v.risk_level !== null)) {
    ctx.addIssue({ code: 'custom', message: 'risk_level phải null khi risk_validity UNKNOWN' });
  }
  if (v.sensor_quality.water === 'BAD' || v.sensor_quality.water === 'UNKNOWN') {
    if (v.risk_validity !== 'UNKNOWN' || v.water_level_cm !== null) {
      ctx.addIssue({ code: 'custom', message: 'Số đo nước lỗi không thể tạo rủi ro hợp lệ' });
    }
  }
});

export const alertSchema = base.safeExtend({
  alert_id: z.string().min(1).max(160),
  previous_level: level.nullable(),
  current_level: level.nullable(),
  risk_validity: validity,
  reason_codes: z.array(z.string().min(1).max(64)).min(1).max(16),
}).superRefine((v, ctx) => {
  if (v.alert_id !== `${v.station_id}:${v.boot_id}:alert:${v.sequence}`) {
    ctx.addIssue({ code: 'custom', message: 'alert_id không khớp station/boot/sequence' });
  }
  if (v.risk_validity === 'UNKNOWN' && v.current_level !== null) {
    ctx.addIssue({ code: 'custom', message: 'current_level phải null khi UNKNOWN' });
  }
});

export const statusSchema = z.object({
  schema_version: z.literal(1),
  station_id: stationId,
  boot_id: bootId,
  state: z.enum(['ONLINE', 'OFFLINE']),
  firmware_version: z.string().min(1).max(64),
  uptime_ms: z.number().int().nonnegative().safe(),
  device_health: z.enum(['OK', 'DEGRADED', 'FAULT']),
});

export type Telemetry = z.infer<typeof telemetrySchema>;
export type Alert = z.infer<typeof alertSchema>;
export type Status = z.infer<typeof statusSchema>;
