import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import mqtt, { MqttClient } from 'mqtt';
import { alertSchema, statusSchema, telemetrySchema } from './contracts';
import { Database } from './database';
import { Stream } from './stream';

@Injectable()
export class MqttIngest implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(MqttIngest.name);
  private client?: MqttClient;
  constructor(private readonly db: Database, private readonly stream: Stream) {}

  onModuleInit() {
    this.client = mqtt.connect(process.env.MQTT_URL ?? 'mqtt://127.0.0.1:1883', {
      username: process.env.MQTT_BACKEND_USER,
      password: process.env.MQTT_BACKEND_PASSWORD,
      clientId: 'fwa-backend',
      reconnectPeriod: 2000,
      clean: false,
      protocolVersion: 4,
    });
    this.client.on('connect', () => {
      this.client?.subscribe(['flood/+/telemetry','flood/+/alert','flood/+/status'], { qos: 1 });
      this.logger.log('Đã kết nối broker');
    });
    this.client.on('message', (topic, payload) => { void this.handle(topic, payload); });
    this.client.on('error', error => this.logger.error(error.message));
  }

  async onModuleDestroy() { await new Promise<void>(resolve => this.client?.end(false, {}, () => resolve()) ?? resolve()); }

  private async handle(topic: string, payload: Buffer) {
    const match = /^flood\/([a-z0-9-]{1,32})\/(telemetry|alert|status)$/.exec(topic);
    if (!match || payload.length > 8192) return;
    const [, stationId, kind] = match;
    try {
      const station = await this.db.station(stationId);
      if (!station) { this.logger.warn(`Trạm không đăng ký: ${stationId}`); return; }
      const raw: unknown = JSON.parse(payload.toString('utf8'));
      if (kind === 'telemetry') {
        const value = telemetrySchema.parse(raw);
        if (value.station_id !== stationId) throw new Error('station_id không khớp topic');
        const latest = await this.db.saveTelemetry(value, station.data_origin);
        if (latest) this.stream.publish('station.telemetry', { station_id: stationId });
      } else if (kind === 'alert') {
        const value = alertSchema.parse(raw);
        if (value.station_id !== stationId) throw new Error('station_id không khớp topic');
        const inserted = await this.db.saveAlert(value, station.data_origin);
        if (inserted) this.stream.publish('station.alert', { station_id: stationId, alert_id: value.alert_id });
        // ACK chỉ sau khi DB INSERT thành công; duplicate đã lưu cũng được ACK.
        this.client?.publish(`flood/${stationId}/alert/ack`, JSON.stringify({ alert_id: value.alert_id }), { qos: 1 });
      } else {
        const value = statusSchema.parse(raw);
        if (value.station_id !== stationId) throw new Error('station_id không khớp topic');
        await this.db.saveStatus(value);
        this.stream.publish('station.status', { station_id: stationId, state: value.state });
      }
    } catch (error) {
      this.logger.warn(`Bỏ bản tin ${topic}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }
}

