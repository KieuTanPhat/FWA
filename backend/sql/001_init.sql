CREATE TABLE IF NOT EXISTS stations (
  id text PRIMARY KEY,
  name text NOT NULL,
  location text NOT NULL,
  data_origin text NOT NULL CHECK (data_origin IN ('PHYSICAL','SIMULATED')),
  latest_boot_id text,
  latest_sequence bigint,
  latest_message_id text,
  last_status text NOT NULL DEFAULT 'OFFLINE',
  last_status_at timestamptz
);

CREATE TABLE IF NOT EXISTS boot_sessions (
  station_id text NOT NULL REFERENCES stations(id),
  boot_id text NOT NULL,
  first_seen_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (station_id, boot_id)
);

CREATE TABLE IF NOT EXISTS telemetry (
  message_id text PRIMARY KEY,
  station_id text NOT NULL REFERENCES stations(id),
  boot_id text NOT NULL,
  sequence bigint NOT NULL,
  device_ts timestamptz,
  time_quality text NOT NULL,
  uptime_ms bigint NOT NULL,
  water_level_cm double precision,
  rise_rate_cm_min double precision,
  rain_tick_count bigint,
  rain_mm_per_tick double precision,
  temperature_c double precision,
  risk_level text,
  risk_validity text NOT NULL,
  sensor_quality jsonb NOT NULL,
  device_health text NOT NULL,
  firmware_version text NOT NULL,
  config_version text NOT NULL,
  battery_v double precision,
  data_origin text NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS telemetry_station_time ON telemetry(station_id, received_at DESC);

CREATE TABLE IF NOT EXISTS alerts (
  alert_id text PRIMARY KEY,
  station_id text NOT NULL REFERENCES stations(id),
  boot_id text NOT NULL,
  sequence bigint NOT NULL,
  device_ts timestamptz,
  time_quality text NOT NULL,
  previous_level text,
  current_level text,
  risk_validity text NOT NULL,
  reason_codes jsonb NOT NULL,
  sensor_quality jsonb NOT NULL,
  config_version text NOT NULL,
  firmware_version text NOT NULL,
  data_origin text NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS alerts_station_time ON alerts(station_id, received_at DESC);

INSERT INTO stations(id,name,location,data_origin) VALUES
  ('sim-01','Trạm mô phỏng','Mô hình phòng lab','SIMULATED'),
  ('station-01','Trạm cảm biến','Vị trí lắp đặt cần hiệu chuẩn','PHYSICAL')
ON CONFLICT (id) DO NOTHING;

