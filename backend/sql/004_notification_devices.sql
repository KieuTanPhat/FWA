CREATE TABLE IF NOT EXISTS notification_devices (
  fcm_token text PRIMARY KEY,
  station_id text NOT NULL REFERENCES stations(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS notification_devices_station ON notification_devices(station_id);
