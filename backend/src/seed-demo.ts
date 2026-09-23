import './config';
import { Pool } from 'pg';

const STATION_ID = 'sim-01';
const BOOT_ID = 'cloud-demo-2026';
const SAMPLE_COUNT = 100;
const SAMPLE_INTERVAL_MINUTES = 5;
const SAMPLE_INTERVAL_MS = SAMPLE_INTERVAL_MINUTES * 60 * 1000;

type Risk = 'NORMAL' | 'WATCH' | 'WARNING' | 'EMERGENCY' | null;
type Sample = { waterLevel: number | null; risk: Risk; fault?: boolean };

function sampleAt(index: number): Sample {
  if (index < 20) return { waterLevel: 18 + (index % 5), risk: 'NORMAL' };
  if (index < 30) return { waterLevel: 25 + index - 20, risk: 'NORMAL' };
  if (index < 45) return { waterLevel: 34 + (index - 30), risk: 'WATCH' };
  if (index < 60) return { waterLevel: 49 + (index - 45), risk: 'WARNING' };
  if (index < 65) return { waterLevel: 74 + (index - 60) * 2, risk: 'EMERGENCY' };
  if (index < 80) return { waterLevel: 64 - (index - 65), risk: 'WARNING' };
  if (index < 90) return { waterLevel: 49 - (index - 80), risk: 'WATCH' };
  if (index < 95) return { waterLevel: null, risk: null, fault: true };
  return { waterLevel: 20 + (index - 95), risk: 'NORMAL' };
}

async function main() {
  if (process.env.DEMO_ONLY !== 'true') {
    throw new Error('Từ chối nạp dữ liệu demo: DEMO_ONLY phải là true.');
  }
  if (!process.env.DATABASE_URL) throw new Error('Thiếu DATABASE_URL.');

  const db = new Pool({ connectionString: process.env.DATABASE_URL, max: 1 });
  const client = await db.connect();
  const now = Date.now();
  const alerts = [
    { sample: 30, previous: 'NORMAL', current: 'WATCH', validity: 'VALID', reason: 'DEMO_WATER_THRESHOLD' },
    { sample: 45, previous: 'WATCH', current: 'WARNING', validity: 'VALID', reason: 'DEMO_WATER_THRESHOLD' },
    { sample: 60, previous: 'WARNING', current: 'EMERGENCY', validity: 'VALID', reason: 'DEMO_WATER_THRESHOLD' },
    { sample: 90, previous: 'EMERGENCY', current: null, validity: 'UNKNOWN', reason: 'DEMO_SENSOR_TIMEOUT' },
    { sample: 95, previous: null, current: 'NORMAL', validity: 'VALID', reason: 'DEMO_SENSOR_RECOVERED' },
  ] as const;

  try {
    await client.query('BEGIN');
    const station = await client.query(
      "SELECT id FROM stations WHERE id=$1 AND data_origin='SIMULATED' FOR UPDATE",
      [STATION_ID],
    );
    if (!station.rowCount) throw new Error('Không tìm thấy trạm mô phỏng sim-01.');

    await client.query(
      'INSERT INTO boot_sessions(station_id,boot_id) VALUES($1,$2) ON CONFLICT DO NOTHING',
      [STATION_ID, BOOT_ID],
    );

    for (let index = 0; index < SAMPLE_COUNT; index++) {
      const sequence = index + 1;
      const sample = sampleAt(index);
      const previousSample = index > 0 ? sampleAt(index - 1) : null;
      const riseRate = previousSample && sample.waterLevel !== null && previousSample.waterLevel !== null
        ? (sample.waterLevel - previousSample.waterLevel) / SAMPLE_INTERVAL_MINUTES
        : null;
      const sampledAt = new Date(now - (SAMPLE_COUNT - 1 - index) * SAMPLE_INTERVAL_MS);
      const messageId = `${STATION_ID}:${BOOT_ID}:${sequence}`;
      const quality = { water: sample.fault ? 'BAD' : 'GOOD', rain: 'GOOD', temperature: 'GOOD' };
      await client.query(
        `INSERT INTO telemetry
          (message_id,station_id,boot_id,sequence,device_ts,time_quality,uptime_ms,water_level_cm,
           rise_rate_cm_min,rain_tick_count,rain_mm_per_tick,temperature_c,risk_level,risk_validity,
           sensor_quality,device_health,outbox_lost_event_count,firmware_version,config_version,battery_v,data_origin,received_at)
         VALUES ($1,$2,$3,$4,$5,'SYNCED',$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,0,$16,$17,$18,'SIMULATED',$5)
         ON CONFLICT (message_id) DO UPDATE SET
           device_ts=EXCLUDED.device_ts, uptime_ms=EXCLUDED.uptime_ms, water_level_cm=EXCLUDED.water_level_cm,
           rise_rate_cm_min=EXCLUDED.rise_rate_cm_min, rain_tick_count=EXCLUDED.rain_tick_count,
           rain_mm_per_tick=EXCLUDED.rain_mm_per_tick, temperature_c=EXCLUDED.temperature_c,
           risk_level=EXCLUDED.risk_level, risk_validity=EXCLUDED.risk_validity,
           sensor_quality=EXCLUDED.sensor_quality, device_health=EXCLUDED.device_health,
           received_at=EXCLUDED.received_at`,
        [
          messageId, STATION_ID, BOOT_ID, sequence, sampledAt, sequence * SAMPLE_INTERVAL_MS,
          sample.waterLevel, riseRate,
          Math.floor(index / 20), 0.2, 27 + (index % 4) * 0.2, sample.risk,
          sample.fault ? 'UNKNOWN' : 'VALID', JSON.stringify(quality), sample.fault ? 'DEGRADED' : 'OK',
          'simulator-cloud-demo', 'cloud-demo-2026-v1', 4.05 - (index % 10) * 0.005,
        ],
      );
    }

    for (let index = 0; index < alerts.length; index++) {
      const alert = alerts[index];
      const sampledAt = new Date(now - (SAMPLE_COUNT - 1 - alert.sample) * SAMPLE_INTERVAL_MS);
      const alertSequence = index + 1;
      const sample = sampleAt(alert.sample);
      const quality = { water: sample.fault ? 'BAD' : 'GOOD', rain: 'GOOD', temperature: 'GOOD' };
      await client.query(
        `INSERT INTO alerts
          (alert_id,station_id,boot_id,sequence,device_ts,time_quality,previous_level,current_level,
           risk_validity,reason_codes,sensor_quality,config_version,firmware_version,data_origin,received_at)
         VALUES ($1,$2,$3,$4,$5,'SYNCED',$6,$7,$8,$9,$10,$11,$12,'SIMULATED',$5)
         ON CONFLICT (alert_id) DO UPDATE SET
           device_ts=EXCLUDED.device_ts, previous_level=EXCLUDED.previous_level,
           current_level=EXCLUDED.current_level, risk_validity=EXCLUDED.risk_validity,
           reason_codes=EXCLUDED.reason_codes, sensor_quality=EXCLUDED.sensor_quality,
           received_at=EXCLUDED.received_at`,
        [
          `${STATION_ID}:${BOOT_ID}:alert:${alertSequence}`, STATION_ID, BOOT_ID, alertSequence,
          sampledAt, alert.previous, alert.current, alert.validity, JSON.stringify([alert.reason]),
          JSON.stringify(quality), 'cloud-demo-2026-v1', 'simulator-cloud-demo',
        ],
      );
    }

    await client.query(
      `UPDATE stations SET latest_boot_id=$2, latest_sequence=$3, latest_message_id=$4,
         latest_status_boot_id=$2, latest_status_uptime_ms=$5, last_status='OFFLINE',
         last_status_at=now()
       WHERE id=$1 AND data_origin='SIMULATED'`,
      [STATION_ID, BOOT_ID, SAMPLE_COUNT, `${STATION_ID}:${BOOT_ID}:${SAMPLE_COUNT}`, SAMPLE_COUNT * SAMPLE_INTERVAL_MS],
    );
    await client.query('COMMIT');
    process.stdout.write(`Đã nạp ${SAMPLE_COUNT} số đo và ${alerts.length} sự kiện mô phỏng cho ${STATION_ID}.\n`);
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
    await db.end();
  }
}

void main().catch(error => {
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
  process.exitCode = 1;
});
