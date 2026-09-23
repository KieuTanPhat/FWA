ALTER TABLE stations ADD COLUMN IF NOT EXISTS latest_status_boot_id text;
ALTER TABLE stations ADD COLUMN IF NOT EXISTS latest_status_uptime_ms bigint;
