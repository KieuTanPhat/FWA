import { randomBytes } from 'crypto';
import { resolve } from 'path';
import { config } from 'dotenv';
import mqtt, { MqttClient } from 'mqtt';
import { scenarios, Step } from './scenarios';

config({ path: resolve(__dirname, '../../.env') });

const args = process.argv.slice(2);
const option = (name: string, fallback: string) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? (args[i + 1] ?? fallback) : fallback;
};
const scenarioName = option('scenario', 'full');
const steps = scenarios[scenarioName];
const interval = Number(option('interval-ms', '5000'));
if (!steps || !Number.isInteger(interval) || interval < 500) {
  process.stderr.write('Dùng --scenario normal|rise|fault|full và --interval-ms >= 500\n');
  process.exit(2);
}
for (const key of ['MQTT_URL', 'MQTT_SIM_USER', 'MQTT_SIM_PASSWORD']) {
  if (!process.env[key]) throw new Error(`Thiếu ${key} trong .env`);
}

const station = 'sim-01';
const boot = randomBytes(8).toString('hex');
const firmware = 'simulator-0.1.0';
const configVersion = 'demo-2026-09-v1';
const started = Date.now();
let sequence = 0;
let alertSequence = 0;
let lastRisk: Step['risk'] = null;
let previousLevel: Exclude<Step['risk'], null> = 'NORMAL';
let running = false;

const mqttClient = mqtt.connect(process.env.MQTT_URL!, {
  clientId: `fwa-${station}`,
  username: process.env.MQTT_SIM_USER,
  password: process.env.MQTT_SIM_PASSWORD,
  clean: false,
  protocolVersion: 4,
  reconnectPeriod: 2000,
  will: {
    topic: `flood/${station}/status`,
    payload: JSON.stringify(status('OFFLINE')),
    qos: 1,
    retain: true,
  },
});

function status(state: 'ONLINE' | 'OFFLINE') {
  return {
    schema_version: 1, station_id: station, boot_id: boot, state,
    firmware_version: firmware, uptime_ms: Date.now() - started, device_health: 'OK',
  };
}

function publish(topic: string, payload: unknown, retain = false): Promise<void> {
  return new Promise((resolvePublish, reject) => {
    mqttClient.publish(`flood/${station}/${topic}`, JSON.stringify(payload), { qos: 1, retain },
      error => error ? reject(error) : resolvePublish());
  });
}

function telemetry(step: Step) {
  const seq = ++sequence;
  const quality = step.waterLevelCm === null ? 'BAD' : 'GOOD';
  return {
    schema_version: 1,
    station_id: station,
    boot_id: boot,
    sequence: seq,
    message_id: `${station}:${boot}:${seq}`,
    device_ts: new Date().toISOString(),
    time_quality: 'SYNCED',
    uptime_ms: Date.now() - started,
    water_level_cm: step.waterLevelCm,
    rise_rate_cm_min: null, // Kịch bản rời rạc không đủ mẫu để tính tốc độ dâng thật.
    rain_tick_count: 0,
    rain_mm_per_tick: 0.2,
    temperature_c: 27.5,
    risk_level: step.risk,
    risk_validity: step.risk === null ? 'UNKNOWN' : 'VALID',
    sensor_quality: { water: quality, rain: 'GOOD', temperature: 'GOOD' },
    device_health: step.risk === null ? 'DEGRADED' : 'OK',
    outbox_lost_event_count: 0,
    firmware_version: firmware,
    config_version: configVersion,
    battery_v: null,
  };
}

async function emitAlert(step: Step) {
  if (!step.reason) return;
  const seq = ++alertSequence;
  await publish('alert', {
    schema_version: 1,
    alert_id: `${station}:${boot}:alert:${seq}`,
    station_id: station,
    boot_id: boot,
    sequence: seq,
    device_ts: new Date().toISOString(),
    time_quality: 'SYNCED',
    previous_level: previousLevel,
    current_level: step.risk,
    risk_validity: step.risk === null ? 'UNKNOWN' : 'VALID',
    reason_codes: [step.reason],
    sensor_quality: {
      water: step.waterLevelCm === null ? 'BAD' : 'GOOD',
      rain: 'GOOD', temperature: 'GOOD',
    },
    config_version: configVersion,
    firmware_version: firmware,
  });
}

async function run() {
  await publish('status', status('ONLINE'), true);
  mqttClient.subscribe(`flood/${station}/alert/ack`, { qos: 1 });
  mqttClient.on('message', (_topic, payload) => process.stdout.write(`ACK ${payload.toString()}\n`));
  process.stdout.write(`Kịch bản ${scenarioName}; trạm ${station}; nhãn MÔ PHỎNG\n`);
  for (const [index, step] of steps.entries()) {
    if (index > 0) await new Promise(done => setTimeout(done, interval));
    await publish('telemetry', telemetry(step));
    await emitAlert(step);
    if (step.risk !== null) previousLevel = step.risk;
    lastRisk = step.risk;
    process.stdout.write(`${index + 1}/${steps.length}: ${step.waterLevelCm ?? 'LỖI'} cm, ${lastRisk ?? 'UNKNOWN'}\n`);
    await publish('status', status('ONLINE'), true);
  }
  await new Promise(done => setTimeout(done, 1500));
  await publish('status', status('OFFLINE'), true);
  mqttClient.end();
}

mqttClient.on('connect', () => {
  if (running) return;
  running = true;
  void run().catch(error => { process.stderr.write(`${error}\n`); process.exitCode = 1; mqttClient.end(); });
});
mqttClient.on('error', error => process.stderr.write(`MQTT: ${error.message}\n`));
