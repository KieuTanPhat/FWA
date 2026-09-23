import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { resolve } from 'node:path';
import { config } from 'dotenv';
import mqtt from 'mqtt';

config({ path: resolve(__dirname, '../../.env') });
const station = 'sim-01';
const boot = randomBytes(8).toString('hex');
const client = mqtt.connect(process.env.MQTT_URL!, {
  username: process.env.MQTT_SIM_USER,
  password: process.env.MQTT_SIM_PASSWORD,
  clientId: `fwa-check-${boot}`,
  protocolVersion: 4,
});
const base = process.env.API_BASE_URL ?? 'http://127.0.0.1:3000';
let socket: WebSocket | undefined;
const pause = (ms: number) => new Promise(done => setTimeout(done, ms));
const publish = (topic: string, value: unknown) => new Promise<void>((done, fail) =>
  client.publish(`flood/${station}/${topic}`, JSON.stringify(value), { qos: 1 }, error => error ? fail(error) : done()));

function telemetry(sequence: number, water: number, risk: 'NORMAL' | 'WARNING') {
  return {
    schema_version: 1, station_id: station, boot_id: boot, sequence,
    message_id: `${station}:${boot}:${sequence}`,
    device_ts: null, time_quality: 'UNSYNCED', uptime_ms: sequence * 1000,
    water_level_cm: water, rise_rate_cm_min: null,
    rain_tick_count: 0, rain_mm_per_tick: 0.2, temperature_c: null,
    risk_level: risk, risk_validity: 'VALID',
    sensor_quality: { water: 'GOOD', rain: 'GOOD', temperature: 'UNKNOWN' },
    device_health: 'OK', outbox_lost_event_count: 0,
    firmware_version: 'integration-1', config_version: 'demo-2026-09-v1', battery_v: null,
    data_origin: 'PHYSICAL', // Payload giả mạo phải bị backend bỏ qua.
  };
}

async function main() {
  await new Promise<void>((done, fail) => { client.once('connect', () => done()); client.once('error', fail); });
  const events: string[] = [];
  const acknowledgements: string[] = [];
  client.on('message', (_topic, body) => acknowledgements.push(body.toString()));
  client.subscribe(`flood/${station}/alert/ack`, { qos: 1 });
  const stream = new WebSocket(base.replace(/^http/, 'ws') + '/api/v1/stream');
  socket = stream;
  stream.onmessage = event => {
    const item = JSON.parse(String(event.data)) as { event: string };
    events.push(item.event);
  };
  await new Promise<void>((done, fail) => { stream.onopen = () => done(); stream.onerror = () => fail(new Error('WebSocket lỗi')); });
  const newer = telemetry(2, 55, 'WARNING');
  await publish('telemetry', newer);
  await publish('telemetry', telemetry(1, 20, 'NORMAL'));
  await publish('telemetry', newer);
  const alert = {
    schema_version: 1, alert_id: `${station}:${boot}:alert:1`, station_id: station,
    boot_id: boot, sequence: 1, device_ts: null, time_quality: 'UNSYNCED',
    previous_level: 'NORMAL', current_level: 'WARNING', risk_validity: 'VALID',
    reason_codes: ['INTEGRATION_CHECK'],
    sensor_quality: { water: 'GOOD', rain: 'GOOD', temperature: 'UNKNOWN' },
    config_version: 'demo-2026-09-v1', firmware_version: 'integration-1',
  };
  await publish('alert', alert);
  await publish('alert', alert);
  await pause(700);
  const latest = await (await fetch(`${base}/api/v1/stations/${station}/latest`)).json() as Record<string, unknown>;
  const history = await (await fetch(`${base}/api/v1/stations/${station}/telemetry?limit=200`)).json() as Array<Record<string, unknown>>;
  const alerts = await (await fetch(`${base}/api/v1/alerts?station_id=${station}&limit=200`)).json() as Array<Record<string, unknown>>;
  assert.equal(latest.message_id, newer.message_id, 'Bản tin cũ không được ghi đè latest');
  assert.equal(latest.data_origin, 'SIMULATED', 'Không được tin origin trong payload');
  assert.equal(history.filter(item => item.boot_id === boot).length, 2, 'QoS 1 phải chống trùng');
  assert.equal(alerts.filter(item => item.alert_id === alert.alert_id).length, 1, 'Alert phải chống trùng');
  assert.ok(events.includes('station.telemetry') && events.includes('station.alert'), 'WebSocket phải phát sự kiện');
  assert.ok(acknowledgements.some(item => item.includes(alert.alert_id)), 'Phải có application ACK');
  stream.close();
  client.end();
  process.stdout.write('Đạt: dedupe, out-of-order, origin, WebSocket, alert ACK sau lưu\n');
}

void main().catch(error => { process.stderr.write(`${error}\n`); socketCleanup(); process.exitCode = 1; });
function socketCleanup() { socket?.close(); client.end(); }
