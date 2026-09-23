$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root '.env'
if (Test-Path -LiteralPath $envFile) { throw '.env đã tồn tại; không ghi đè thông tin đăng nhập.' }
$db = [guid]::NewGuid().ToString('N')
$backend = [guid]::NewGuid().ToString('N')
$sim = [guid]::NewGuid().ToString('N')
$device = [guid]::NewGuid().ToString('N')
@"
POSTGRES_DB=fwa
POSTGRES_USER=fwa
POSTGRES_PASSWORD=$db
DATABASE_URL=postgres://fwa:${db}@127.0.0.1:5432/fwa
MQTT_URL=mqtt://127.0.0.1:1883
MQTT_BACKEND_USER=backend
MQTT_BACKEND_PASSWORD=$backend
MQTT_SIM_USER=sim-01
MQTT_SIM_PASSWORD=$sim
MQTT_DEVICE_USER=station-01
MQTT_DEVICE_PASSWORD=$device
PORT=3000
STALE_AFTER_SECONDS=15
"@ | Set-Content -LiteralPath $envFile -Encoding utf8
$config = Join-Path $PSScriptRoot 'mosquitto'
$volume = "${config}:/mosquitto/config"
docker run --rm -v $volume eclipse-mosquitto:2 mosquitto_passwd -b -c /mosquitto/config/passwd backend $backend
docker run --rm -v $volume eclipse-mosquitto:2 mosquitto_passwd -b /mosquitto/config/passwd sim-01 $sim
docker run --rm -v $volume eclipse-mosquitto:2 mosquitto_passwd -b /mosquitto/config/passwd station-01 $device
Write-Host 'Đã tạo .env và broker credentials cục bộ. Giữ các file này ngoài Git.'
