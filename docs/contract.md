# Hợp đồng dữ liệu v1

MQTT: `flood/{station_id}/telemetry`, `flood/{station_id}/alert`, `flood/{station_id}/status`, `flood/{station_id}/alert/ack`. QoS 1; chỉ status được retain. `message_id` và `alert_id` giữ nguyên khi gửi lại. `boot_id` đổi sau mỗi boot, `sequence` tăng trong một boot.

Telemetry bắt buộc có `schema_version: 1`, `station_id`, `boot_id`, `sequence`, `message_id`, `device_ts` (UTC hoặc null), `time_quality` (`SYNCED`/`UNSYNCED`), `uptime_ms`, `water_level_cm` (số hoặc null), `rise_rate_cm_min` (số hoặc null), `rain_tick_count` (số hoặc null), `rain_mm_per_tick` (số hoặc null), `temperature_c` (số hoặc null), `risk_level` (enum hoặc null), `risk_validity` (`VALID`/`UNKNOWN`), `sensor_quality` (`water`, `rain`, `temperature`), `device_health`, `firmware_version`, `config_version`, `battery_v` (số hoặc null). Backend bổ sung `received_at`, `data_origin` từ danh tính trạm đã đăng ký. Không tin `data_origin` trong payload.

Alert mang `alert_id`, `station_id`, `boot_id`, `sequence`, `device_ts`, `time_quality`, `previous_level`, `current_level`, `risk_validity`, `reason_codes`, `sensor_quality`, `config_version`, `firmware_version`. Backend chỉ gửi application ACK sau khi alert được lưu thành công. MQTT PUBACK không đồng nghĩa DB commit.

`risk_level`: NORMAL, WATCH, WARNING, EMERGENCY. `risk_validity`: VALID hoặc UNKNOWN. `sensor_quality`: GOOD, SUSPECT, BAD, UNKNOWN. `device_health`: OK, DEGRADED, FAULT. `data_origin`: PHYSICAL hoặc SIMULATED, do server gán theo trạm/ACL. Thiết bị mất giờ UTC thì gửi `device_ts: null`, `time_quality: UNSYNCED`; server giữ nguyên và dùng `received_at` riêng.

