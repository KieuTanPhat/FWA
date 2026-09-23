import { config } from 'dotenv';
import { resolve } from 'path';

config({ path: resolve(__dirname, '../../.env') });

const requiredKeys = ['DATABASE_URL'];
if (process.env.MQTT_ENABLED !== 'false') {
  requiredKeys.push('MQTT_URL', 'MQTT_BACKEND_USER', 'MQTT_BACKEND_PASSWORD');
}

for (const key of requiredKeys) {
  if (!process.env[key]) throw new Error(`Thiếu cấu hình ${key} trong .env`);
}

