import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { Pool } from 'pg';
import type { Alert, Status, Telemetry } from './contracts';

@Injectable()
export class Database implements OnModuleDestroy {
  readonly pool = new Pool({ connectionString: process.env.DATABASE_URL, max: 10 });

  async onModuleDestroy() { await this.pool.end(); }

  async station(id: string) {
    const result = await this.pool.query('SELECT id, data_origin FROM stations WHERE id=$1', [id]);
    return result.rows[0] as { id: string; data_origin: 'PHYSICAL' | 'SIMULATED' } | undefined;
  }

  async saveTelemetry(v: Telemetry, origin: string): Promise<boolean> {
    const c = await this.pool.connect();
    try {
      await c.query('BEGIN');
      const prior = await c.query('SELECT latest_boot_id, latest_sequence FROM stations WHERE id=$1 FOR UPDATE', [v.station_id]);
      if (!prior.rowCount) throw new Error('Trạm chưa đăng ký');
      const boot = await c.query(
        'INSERT INTO boot_sessions(station_id,boot_id) VALUES($1,$2) ON CONFLICT DO NOTHING RETURNING boot_id',
        [v.station_id, v.boot_id],
      );
      const result = await c.query(`INSERT INTO telemetry
        (message_id,station_id,boot_id,sequence,device_ts,time_quality,uptime_ms,water_level_cm,
         rise_rate_cm_min,rain_tick_count,rain_mm_per_tick,temperature_c,risk_level,risk_validity,
         sensor_quality,device_health,firmware_version,config_version,battery_v,data_origin)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20)
        ON CONFLICT(message_id) DO NOTHING RETURNING message_id`,
        [v.message_id,v.station_id,v.boot_id,v.sequence,v.device_ts,v.time_quality,v.uptime_ms,
          v.water_level_cm,v.rise_rate_cm_min,v.rain_tick_count,v.rain_mm_per_tick,v.temperature_c,
          v.risk_level,v.risk_validity,JSON.stringify(v.sensor_quality),v.device_health,
          v.firmware_version,v.config_version,v.battery_v,origin],
      );
      const freshBoot = boot.rowCount === 1;
      const current = prior.rows[0];
      const isLatest = result.rowCount === 1 && (
        current.latest_boot_id === null ||
        (current.latest_boot_id === v.boot_id && BigInt(v.sequence) > BigInt(current.latest_sequence)) ||
        (current.latest_boot_id !== v.boot_id && freshBoot)
      );
      if (isLatest) {
        await c.query(`UPDATE stations SET latest_boot_id=$2,latest_sequence=$3,latest_message_id=$4
          WHERE id=$1`, [v.station_id,v.boot_id,v.sequence,v.message_id]);
      }
      await c.query('COMMIT');
      return isLatest;
    } catch (error) {
      await c.query('ROLLBACK');
      throw error;
    } finally { c.release(); }
  }

  async saveAlert(v: Alert, origin: string) {
    const r = await this.pool.query(`INSERT INTO alerts
      (alert_id,station_id,boot_id,sequence,device_ts,time_quality,previous_level,current_level,
       risk_validity,reason_codes,sensor_quality,config_version,firmware_version,data_origin)
      VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
      ON CONFLICT(alert_id) DO NOTHING RETURNING alert_id`,
      [v.alert_id,v.station_id,v.boot_id,v.sequence,v.device_ts,v.time_quality,v.previous_level,
        v.current_level,v.risk_validity,JSON.stringify(v.reason_codes),JSON.stringify(v.sensor_quality),
        v.config_version,v.firmware_version,origin]);
    return r.rowCount === 1;
  }

  async saveStatus(v: Status) {
    await this.pool.query('UPDATE stations SET last_status=$2,last_status_at=now() WHERE id=$1', [v.station_id,v.state]);
  }

  async stations(staleSeconds: number) {
    const r = await this.pool.query(`SELECT s.id,s.name,s.location,s.data_origin,s.last_status,s.last_status_at,
      t.message_id,t.water_level_cm,t.rise_rate_cm_min,t.risk_level,t.risk_validity,
      t.sensor_quality,t.device_health,t.received_at,t.device_ts,t.time_quality,t.temperature_c,
      t.rain_tick_count,t.rain_mm_per_tick,t.firmware_version,t.config_version
      FROM stations s LEFT JOIN telemetry t ON t.message_id=s.latest_message_id ORDER BY s.id`);
    return r.rows.map(row => presentStation(row, staleSeconds));
  }

  async telemetry(stationId: string, limit: number, from?: Date, to?: Date) {
    const r = await this.pool.query(`SELECT * FROM telemetry WHERE station_id=$1
      AND ($2::timestamptz IS NULL OR received_at >= $2)
      AND ($3::timestamptz IS NULL OR received_at <= $3)
      ORDER BY received_at DESC,message_id DESC LIMIT $4`, [stationId,from ?? null,to ?? null,limit]);
    return r.rows;
  }

  async alerts(stationId: string | undefined, limit: number, before?: Date) {
    const r = await this.pool.query(`SELECT * FROM alerts WHERE ($1::text IS NULL OR station_id=$1)
      AND ($2::timestamptz IS NULL OR received_at < $2)
      ORDER BY received_at DESC,alert_id DESC LIMIT $3`, [stationId ?? null,before ?? null,limit]);
    return r.rows;
  }
}

export function presentStation(row: Record<string, unknown>, staleSeconds: number) {
  const received = row.received_at ? new Date(String(row.received_at)) : null;
  const fresh = received !== null && Date.now() - received.getTime() <= staleSeconds * 1000;
  const online = row.last_status === 'ONLINE' && row.last_status_at != null &&
    Date.now() - new Date(String(row.last_status_at)).getTime() <= staleSeconds * 2000;
  const valid = fresh && row.risk_validity === 'VALID' &&
    (row.sensor_quality as { water?: string } | null)?.water === 'GOOD';
  return {
    ...row,
    id: String(row.id),
    freshness: fresh ? 'FRESH' : 'STALE',
    link_state: online ? 'ONLINE' : 'OFFLINE',
    effective_risk_level: valid ? row.risk_level : null,
    effective_risk_validity: valid ? 'VALID' : 'UNKNOWN',
  };
}
