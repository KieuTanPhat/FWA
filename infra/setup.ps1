$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root '.env'
$config = Join-Path $PSScriptRoot 'mosquitto'
$passwdFile = Join-Path $config 'passwd'
if ((Test-Path -LiteralPath $envFile) -and (Test-Path -LiteralPath $passwdFile)) {
  Write-Host 'Cấu hình đã tồn tại; giữ nguyên credentials cục bộ.'
  return
}

$existing = Test-Path -LiteralPath $envFile
if ($existing) {
  $values = @{}
  Get-Content -LiteralPath $envFile | ForEach-Object {
    $parts = $_.Split('=', 2)
    if ($parts.Count -eq 2) { $values[$parts[0]] = $parts[1] }
  }
  foreach ($key in @('MQTT_BACKEND_PASSWORD','MQTT_SIM_PASSWORD','MQTT_DEVICE_PASSWORD')) {
    if (-not $values.ContainsKey($key)) { throw ".env thiếu $key; sửa file trước khi chạy lại." }
  }
  $backend = $values['MQTT_BACKEND_PASSWORD']
  $sim = $values['MQTT_SIM_PASSWORD']
  $device = $values['MQTT_DEVICE_PASSWORD']
} else {
  $db = [guid]::NewGuid().ToString('N')
  $backend = [guid]::NewGuid().ToString('N')
  $sim = [guid]::NewGuid().ToString('N')
  $device = [guid]::NewGuid().ToString('N')
}

docker info --format '{{.ServerVersion}}' 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Docker engine chưa chạy. Bật Docker Desktop rồi chạy lại.' }

$volume = "${config}:/mosquitto/config"
docker run --rm -v $volume eclipse-mosquitto:2 mosquitto_passwd -b -c /mosquitto/config/passwd backend $backend
if ($LASTEXITCODE -ne 0) { throw 'Không tạo được mật khẩu backend cho broker.' }
docker run --rm -v $volume eclipse-mosquitto:2 mosquitto_passwd -b /mosquitto/config/passwd sim-01 $sim
if ($LASTEXITCODE -ne 0) { throw 'Không tạo được mật khẩu simulator cho broker.' }
docker run --rm -v $volume eclipse-mosquitto:2 mosquitto_passwd -b /mosquitto/config/passwd station-01 $device
if ($LASTEXITCODE -ne 0) { throw 'Không tạo được mật khẩu trạm cho broker.' }

if (-not $existing) {
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
}
Write-Host 'Đã tạo .env và broker credentials cục bộ. Giữ các file này ngoài Git.'
