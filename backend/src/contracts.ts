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
  distance_cm: nullableFinite.optional(),
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

export const demoControlPatchSchema = z.object({
  running: z.boolean().optional(),
  direction: z.enum(['RISING', 'FALLING', 'HOLD']).optional(),
  water_level_cm: z.number().finite().min(0).max(197).optional(),
  baseline_water_cm: z.number().finite().min(0).max(197).optional(),
  rise_rate_cm_min: z.number().finite().min(0).max(10).optional(),
  watch_rate_cm_min: z.number().finite().min(0.1).max(100).optional(),
  warning_rate_cm_min: z.number().finite().min(0.2).max(150).optional(),
  emergency_rate_cm_min: z.number().finite().min(0.3).max(200).optional(),
  rain_tick_count: z.number().int().min(0).max(1_000_000).optional(),
  rain_rate_mm_hour: z.number().finite().min(0).max(500).optional(),
  temperature_c: z.number().finite().min(-20).max(85).optional(),
  watch_cm: z.number().finite().min(1).max(150).optional(),
  warning_cm: z.number().finite().min(2).max(180).optional(),
  emergency_cm: z.number().finite().min(3).max(196).optional(),
  rain_tip: z.boolean().optional(),
  reset: z.boolean().optional(),
}).refine(value => Object.keys(value).length > 0, 'Cần thay đổi ít nhất một thông số');

export const notificationDeviceSchema = z.object({
  station_id: stationId,
  fcm_token: z.string().min(40).max(4096),
});

export type Telemetry = z.infer<typeof telemetrySchema>;
export type Alert = z.infer<typeof alertSchema>;
export type Status = z.infer<typeof statusSchema>;
export type DemoControlPatch = z.infer<typeof demoControlPatchSchema>;
