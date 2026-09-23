import { config } from 'dotenv';
import { resolve } from 'path';

config({ path: resolve(__dirname, '../../.env') });

for (const key of ['DATABASE_URL', 'MQTT_URL', 'MQTT_BACKEND_USER', 'MQTT_BACKEND_PASSWORD']) {
  if (!process.env[key]) throw new Error(`Thiếu cấu hình ${key} trong .env`);
}

