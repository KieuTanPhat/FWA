ALTER TABLE stations ADD COLUMN IF NOT EXISTS region_id text;
ALTER TABLE telemetry ADD COLUMN IF NOT EXISTS distance_cm double precision;

UPDATE telemetry SET distance_cm = 200 - water_level_cm
WHERE data_origin='SIMULATED' AND water_level_cm IS NOT NULL AND distance_cm IS NULL;

UPDATE stations
SET name = 'Cảm biến mô phỏng · Sông Thao – sông Chảy',
    location = 'Yên Bái · Lào Cai',
    region_id = 'thao-chay'
WHERE id = 'sim-01' AND data_origin = 'SIMULATED';

INSERT INTO stations(id, name, location, data_origin, region_id) VALUES
  ('sim-02', 'Cảm biến mô phỏng · Sông Hương – sông Bồ', 'Thành phố Huế', 'SIMULATED', 'huong-bo'),
  ('sim-03', 'Cảm biến mô phỏng · Vu Gia – Thu Bồn', 'Đà Nẵng · Quảng Nam cũ', 'SIMULATED', 'vu-gia-thu-bon')
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  location = EXCLUDED.location,
  region_id = EXCLUDED.region_id
WHERE stations.data_origin = 'SIMULATED';

CREATE TABLE IF NOT EXISTS demo_controls (
  station_id text PRIMARY KEY REFERENCES stations(id),
  running boolean NOT NULL DEFAULT true,
  direction text NOT NULL DEFAULT 'RISING' CHECK (direction IN ('RISING', 'FALLING', 'HOLD')),
  water_level_cm double precision NOT NULL DEFAULT 20 CHECK (water_level_cm BETWEEN 0 AND 197),
  baseline_water_cm double precision NOT NULL DEFAULT 20 CHECK (baseline_water_cm BETWEEN 0 AND 197),
  rise_rate_cm_min double precision NOT NULL DEFAULT 0.5 CHECK (rise_rate_cm_min BETWEEN 0 AND 10),
  watch_rate_cm_min double precision NOT NULL DEFAULT 5 CHECK (watch_rate_cm_min BETWEEN 0.1 AND 100),
  warning_rate_cm_min double precision NOT NULL DEFAULT 10 CHECK (warning_rate_cm_min BETWEEN 0.2 AND 150),
  emergency_rate_cm_min double precision NOT NULL DEFAULT 15 CHECK (emergency_rate_cm_min BETWEEN 0.3 AND 200),
  rain_tick_count bigint NOT NULL DEFAULT 0 CHECK (rain_tick_count BETWEEN 0 AND 1000000),
  rain_rate_mm_hour double precision NOT NULL DEFAULT 0 CHECK (rain_rate_mm_hour BETWEEN 0 AND 500),
  rain_remainder_mm double precision NOT NULL DEFAULT 0 CHECK (rain_remainder_mm BETWEEN 0 AND 1),
  temperature_c double precision NOT NULL DEFAULT 28 CHECK (temperature_c BETWEEN -20 AND 85),
  watch_cm double precision NOT NULL DEFAULT 30 CHECK (watch_cm BETWEEN 1 AND 150),
  warning_cm double precision NOT NULL DEFAULT 50 CHECK (warning_cm BETWEEN 2 AND 180),
  emergency_cm double precision NOT NULL DEFAULT 70 CHECK (emergency_cm BETWEEN 3 AND 196),
  risk_level text NOT NULL DEFAULT 'NORMAL' CHECK (risk_level IN ('NORMAL', 'WATCH', 'WARNING', 'EMERGENCY')),
  candidate_level text,
  candidate_samples integer NOT NULL DEFAULT 0,
  clear_samples integer NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (watch_cm < warning_cm AND warning_cm < emergency_cm),
  CHECK (watch_rate_cm_min < warning_rate_cm_min AND warning_rate_cm_min < emergency_rate_cm_min)
);

INSERT INTO demo_controls(station_id, water_level_cm, baseline_water_cm) VALUES
  ('sim-01', 20, 20),
  ('sim-02', 22, 22),
  ('sim-03', 18, 18)
ON CONFLICT (station_id) DO NOTHING;
