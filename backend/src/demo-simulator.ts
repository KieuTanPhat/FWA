import { Inject, Injectable, Logger, OnModuleDestroy, OnModuleInit, NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { Database } from './database';
import { demoRegions, isDemoStation } from './demo-regions';
import { Stream } from './stream';
import type { DemoControlPatch } from './contracts';

const sampleEveryMs = 5_000;
const sensorDatumCm = 200;
const watchCmDefault = 30;
const warningCmDefault = 50;
const emergencyCmDefault = 70;
const hysteresisCm = 5;
const confirmSamples = 3;
const clearSamplesRequired = 4;

type Risk = 'NORMAL' | 'WATCH' | 'WARNING' | 'EMERGENCY';
type Direction = 'RISING' | 'FALLING' | 'HOLD';

type DemoControl = {
  station_id: string;
  running: boolean;
  direction: Direction;
  water_level_cm: number;
  baseline_water_cm: number;
  rise_rate_cm_min: number;
  watch_rate_cm_min: number;
  warning_rate_cm_min: number;
  emergency_rate_cm_min: number;
  rain_tick_count: string | number;
  rain_rate_mm_hour: number;
  rain_remainder_mm: number;
  temperature_c: number;
  watch_cm: number;
  warning_cm: number;
  emergency_cm: number;
  risk_level: Risk;
  candidate_level: Risk | null;
  candidate_samples: number;
  clear_samples: number;
  updated_at: Date;
};

@Injectable()
export class DemoSimulator implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DemoSimulator.name);
  private readonly bootId = `web-${randomUUID()}`;
  private readonly startedAt = Date.now();
  private readonly sequences = new Map<string, number>();
  private readonly alertSequences = new Map<string, number>();
  private readonly operations = new Map<string, Promise<unknown>>();
  private timer?: NodeJS.Timeout;
  private lastCleanupAt = 0;

  constructor(
    @Inject(Database) private readonly db: Database,
    @Inject(Stream) private readonly stream: Stream,
  ) {}

  async onModuleInit() {
    if (process.env.DEMO_ONLY !== 'true') {
      this.logger.log('Web IoT simulator is disabled (DEMO_ONLY is not true).');
      return;
    }
    for (const region of demoRegions) {
      this.sequences.set(region.stationId, 0);
      this.alertSequences.set(region.stationId, 0);
      await this.runSerial(region.stationId, () => this.recordSample(region.stationId, false));
    }
    this.timer = setInterval(() => {
      for (const region of demoRegions) {
        void this.runSerial(region.stationId, () => this.recordSample(region.stationId, true))
          .catch(error => this.logger.error(`Sample failed for ${region.stationId}: ${this.errorText(error)}`));
      }
      void this.cleanupOldSamples();
    }, sampleEveryMs);
    this.timer.unref();
    this.logger.log(`Web IoT simulator started for ${demoRegions.length} regions.`);
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }

  async getControl(stationId: string) {
    this.assertEnabled();
    this.assertDemoStation(stationId);
    const result = await this.db.pool.query<DemoControl>(
      'SELECT * FROM demo_controls WHERE station_id=$1',
      [stationId],
    );
    if (!result.rowCount) throw new NotFoundException('Không tìm thấy cấu hình cảm biến mô phỏng.');
    return this.presentControl(result.rows[0]);
  }

  async updateControl(stationId: string, patch: DemoControlPatch) {
    this.assertEnabled();
    this.assertDemoStation(stationId);
    return this.runSerial(stationId, async () => {
      const result = await this.db.pool.query<DemoControl>(
        'SELECT * FROM demo_controls WHERE station_id=$1',
        [stationId],
      );
      const current = result.rows[0];
      if (!current) throw new NotFoundException('Không tìm thấy cấu hình cảm biến mô phỏng.');

      const reset = patch.reset === true;
      const next = {
        running: reset ? false : (patch.running ?? current.running),
        direction: reset ? 'RISING' as const : (patch.direction ?? current.direction),
        water_level_cm: reset ? current.baseline_water_cm : (patch.water_level_cm ?? current.water_level_cm),
        baseline_water_cm: patch.baseline_water_cm ?? current.baseline_water_cm,
        rise_rate_cm_min: patch.rise_rate_cm_min ?? current.rise_rate_cm_min,
        watch_rate_cm_min: patch.watch_rate_cm_min ?? current.watch_rate_cm_min,
        warning_rate_cm_min: patch.warning_rate_cm_min ?? current.warning_rate_cm_min,
        emergency_rate_cm_min: patch.emergency_rate_cm_min ?? current.emergency_rate_cm_min,
        rain_tick_count: reset ? 0 : Math.min(1_000_000,
          Number(patch.rain_tick_count ?? current.rain_tick_count) + (patch.rain_tip ? 1 : 0)),
        rain_rate_mm_hour: patch.rain_rate_mm_hour ?? current.rain_rate_mm_hour,
        rain_remainder_mm: reset ? 0 : current.rain_remainder_mm,
        temperature_c: patch.temperature_c ?? current.temperature_c,
        watch_cm: patch.watch_cm ?? current.watch_cm,
        warning_cm: patch.warning_cm ?? current.warning_cm,
        emergency_cm: patch.emergency_cm ?? current.emergency_cm,
        risk_level: current.risk_level,
        candidate_level: reset ? null : current.candidate_level,
        candidate_samples: reset ? 0 : current.candidate_samples,
        clear_samples: reset ? 0 : current.clear_samples,
      };
      if (!(next.watch_cm < next.warning_cm && next.warning_cm < next.emergency_cm)) {
        throw new Error('Ngưỡng phải tăng theo thứ tự Theo dõi < Cảnh báo < Khẩn cấp.');
      }
      if (!(next.watch_rate_cm_min < next.warning_rate_cm_min &&
          next.warning_rate_cm_min < next.emergency_rate_cm_min)) {
        throw new Error('Ngưỡng tốc độ phải tăng theo thứ tự Theo dõi < Cảnh báo < Khẩn cấp.');
      }
      if (next.water_level_cm < next.baseline_water_cm) {
        throw new Error('Mực nước không thể thấp hơn mốc nền của kịch bản.');
      }
      if (patch.direction === 'HOLD' && patch.running === undefined && !reset) next.running = false;
      if ((patch.direction === 'RISING' || patch.direction === 'FALLING') && patch.running === undefined && !reset) {
        next.running = true;
      }

      await this.db.pool.query(
        `UPDATE demo_controls SET running=$2,direction=$3,water_level_cm=$4,baseline_water_cm=$5,
          rise_rate_cm_min=$6,watch_rate_cm_min=$7,warning_rate_cm_min=$8,emergency_rate_cm_min=$9,
          rain_tick_count=$10,rain_rate_mm_hour=$11,rain_remainder_mm=$12,temperature_c=$13,
          watch_cm=$14,warning_cm=$15,emergency_cm=$16,risk_level=$17,candidate_level=$18,
          candidate_samples=$19,clear_samples=$20,updated_at=now()
         WHERE station_id=$1`,
        [stationId,next.running,next.direction,next.water_level_cm,next.baseline_water_cm,
          next.rise_rate_cm_min,next.watch_rate_cm_min,next.warning_rate_cm_min,next.emergency_rate_cm_min,
          next.rain_tick_count,next.rain_rate_mm_hour,next.rain_remainder_mm,next.temperature_c,
          next.watch_cm,next.warning_cm,next.emergency_cm,next.risk_level,next.candidate_level,
          next.candidate_samples,next.clear_samples],
      );

      await this.recordSample(stationId, false);
      const updated = await this.getControl(stationId);
      this.stream.publish('station.control', { station_id: stationId, control: updated });
      return updated;
    });
  }

  private assertEnabled() {
    if (process.env.DEMO_ONLY !== 'true') {
      throw new ServiceUnavailableException('Điều khiển chỉ bật trong môi trường DEMO_ONLY.');
    }
  }

  private assertDemoStation(stationId: string) {
    if (!isDemoStation(stationId)) throw new NotFoundException('Không tìm thấy cảm biến mô phỏng.');
  }

  private async runSerial<T>(stationId: string, action: () => Promise<T>): Promise<T> {
    const previous = this.operations.get(stationId) ?? Promise.resolve();
    const current = previous.catch(() => undefined).then(action);
    this.operations.set(stationId, current);
    try {
      return await current;
    } finally {
      if (this.operations.get(stationId) === current) this.operations.delete(stationId);
    }
  }

  private async recordSample(stationId: string, advance: boolean) {
    const result = await this.db.pool.query<DemoControl>(
      'SELECT * FROM demo_controls WHERE station_id=$1',
      [stationId],
    );
    const current = result.rows[0];
    if (!current) throw new NotFoundException('Không tìm thấy cấu hình cảm biến mô phỏng.');

    let running = current.running;
    let direction = current.direction;
    let water = current.water_level_cm;
    let rainTicks = Number(current.rain_tick_count);
    let rainRemainder = current.rain_remainder_mm;
    let measuredRate = 0;
    if (advance && running && direction !== 'HOLD') {
      const delta = current.rise_rate_cm_min * sampleEveryMs / 60_000;
      const previousWater = water;
      const signedDelta = direction === 'RISING' ? delta : -delta;
      const highWaterLimit = Math.min(sensorDatumCm - 3, Math.max(current.baseline_water_cm + 1, current.emergency_cm + 10));
      water = Math.min(highWaterLimit, Math.max(current.baseline_water_cm, water + signedDelta));
      if (water !== previousWater) {
        measuredRate = (water - previousWater) * 60_000 / sampleEveryMs;
      }
      if ((direction === 'RISING' && water >= highWaterLimit) || (direction === 'FALLING' && water <= current.baseline_water_cm)) {
        running = false;
      }
    }

    if (advance && current.rain_rate_mm_hour > 0) {
      const accumulated = rainRemainder + current.rain_rate_mm_hour * (sampleEveryMs / 3_600_000);
      const newTips = Math.floor(accumulated / 0.2);
      rainTicks = Math.min(1_000_000, rainTicks + newTips);
      rainRemainder = accumulated - newTips * 0.2;
    }

    const riskState = this.applyRiskRules(current, water, Math.max(0, measuredRate));
    const sequence = (this.sequences.get(stationId) ?? 0) + 1;
    this.sequences.set(stationId, sequence);
    const bootMs = Date.now() - this.startedAt;
    const telemetry = {
      schema_version: 1 as const,
      station_id: stationId,
      boot_id: this.bootId,
      sequence,
      message_id: `${stationId}:${this.bootId}:${sequence}`,
      device_ts: new Date().toISOString(),
      time_quality: 'SYNCED' as const,
      uptime_ms: bootMs,
      water_level_cm: Number(water.toFixed(2)),
      distance_cm: Number((sensorDatumCm - water).toFixed(2)),
      rise_rate_cm_min: measuredRate,
      rain_tick_count: rainTicks,
      rain_mm_per_tick: 0.2,
      temperature_c: Number(current.temperature_c.toFixed(1)),
      risk_level: riskState.level,
      risk_validity: 'VALID' as const,
      sensor_quality: { water: 'GOOD' as const, rain: 'GOOD' as const, temperature: 'GOOD' as const },
      device_health: 'OK' as const,
      outbox_lost_event_count: 0,
      firmware_version: 'iot-web-simulator/0.2.0',
      config_version: 'web-demo-v1',
      battery_v: null,
    };

    await this.db.pool.query(
      `UPDATE demo_controls SET running=$2,direction=$3,water_level_cm=$4,rain_tick_count=$5,
        rain_remainder_mm=$6,risk_level=$7,candidate_level=$8,candidate_samples=$9,
        clear_samples=$10,updated_at=now() WHERE station_id=$1`,
      [stationId,running,direction,water,rainTicks,rainRemainder,riskState.level,
        riskState.candidateLevel,riskState.candidateSamples,riskState.clearSamples],
    );

    const latest = await this.db.saveTelemetry(telemetry, 'SIMULATED');
    const status = {
      schema_version: 1 as const,
      station_id: stationId,
      boot_id: this.bootId,
      state: 'ONLINE' as const,
      firmware_version: telemetry.firmware_version,
      uptime_ms: bootMs,
      device_health: 'OK' as const,
    };
    await this.db.saveStatus(status);

    if (riskState.level !== current.risk_level) {
      const alertSequence = (this.alertSequences.get(stationId) ?? 0) + 1;
      this.alertSequences.set(stationId, alertSequence);
      const alert = {
        schema_version: 1 as const,
        station_id: stationId,
        boot_id: this.bootId,
        sequence: alertSequence,
        alert_id: `${stationId}:${this.bootId}:alert:${alertSequence}`,
        device_ts: telemetry.device_ts,
        time_quality: 'SYNCED' as const,
        previous_level: current.risk_level,
        current_level: riskState.level,
        risk_validity: 'VALID' as const,
        reason_codes: [this.riskRank(riskState.level) < this.riskRank(current.risk_level)
          ? 'DEMO_WATER_RECOVERED'
          : 'DEMO_WATER_THRESHOLD'],
        sensor_quality: telemetry.sensor_quality,
        config_version: telemetry.config_version,
        firmware_version: telemetry.firmware_version,
      };
      const inserted = await this.db.saveAlert(alert, 'SIMULATED');
      if (inserted) this.stream.publish('station.alert', { station_id: stationId, alert_id: alert.alert_id });
    }

    if (latest) this.stream.publish('station.telemetry', { station_id: stationId, region_id: demoRegions.find(region => region.stationId === stationId)?.id });
  }

  private applyRiskRules(current: DemoControl, water: number, riseRate: number) {
    const risingTarget = this.riskFor(water, riseRate, current, 0);
    const clearingTarget = this.riskFor(water, riseRate, current, hysteresisCm);
    const target = this.riskRank(risingTarget) > this.riskRank(current.risk_level)
      ? risingTarget
      : clearingTarget;
    let level = current.risk_level;
    let candidateLevel = current.candidate_level;
    let candidateSamples = current.candidate_samples;
    let clearSamples = current.clear_samples;

    if (this.riskRank(target) > this.riskRank(level)) {
      clearSamples = 0;
      candidateSamples = candidateLevel === target ? candidateSamples + 1 : 1;
      candidateLevel = target;
      if (candidateSamples >= confirmSamples) {
        level = target;
        candidateLevel = null;
        candidateSamples = 0;
      }
    } else {
      candidateLevel = null;
      candidateSamples = 0;
      if (this.riskRank(target) < this.riskRank(level)) {
        clearSamples++;
        if (clearSamples >= clearSamplesRequired) {
          level = target;
          clearSamples = 0;
        }
      } else {
        clearSamples = 0;
      }
    }
    return { level, candidateLevel, candidateSamples, clearSamples };
  }

  private riskFor(water: number, riseRate: number, control: DemoControl, hysteresis: number): Risk {
    if (water >= control.emergency_cm - hysteresis || riseRate >= control.emergency_rate_cm_min) return 'EMERGENCY';
    if (water >= control.warning_cm - hysteresis || riseRate >= control.warning_rate_cm_min) return 'WARNING';
    if (water >= control.watch_cm - hysteresis || riseRate >= control.watch_rate_cm_min) return 'WATCH';
    return 'NORMAL';
  }

  private riskRank(level: Risk) {
    return level === 'NORMAL' ? 0 : level === 'WATCH' ? 1 : level === 'WARNING' ? 2 : 3;
  }

  private presentControl(value: DemoControl) {
    return {
      ...value,
      rain_tick_count: Number(value.rain_tick_count),
      updated_at: value.updated_at instanceof Date ? value.updated_at.toISOString() : value.updated_at,
    };
  }

  private async cleanupOldSamples() {
    const now = Date.now();
    if (now - this.lastCleanupAt < 24 * 60 * 60 * 1000) return;
    this.lastCleanupAt = now;
    try {
      await this.db.pool.query(
        `DELETE FROM telemetry WHERE data_origin='SIMULATED' AND station_id=ANY($1::text[])
         AND received_at < now() - interval '7 days'`,
        [demoRegions.map(region => region.stationId)],
      );
    } catch (error) {
      this.logger.warn(`Log retention cleanup failed: ${this.errorText(error)}`);
    }
  }

  private errorText(error: unknown) {
    return error instanceof Error ? error.message : String(error);
  }
}
