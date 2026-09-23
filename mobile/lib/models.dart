DateTime? parseTime(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;
double? parseNumber(Object? value) => value is num ? value.toDouble() : null;
int? parseInteger(Object? value) => switch (value) {
  num number => number.toInt(),
  String text => int.tryParse(text),
  _ => null,
};

class Station {
  const Station({
    required this.id,
    required this.name,
    required this.location,
    required this.origin,
    required this.lastStatus,
    required this.freshness,
    required this.linkState,
    required this.lastStatusAt,
    required this.messageId,
    required this.waterLevelCm,
    required this.distanceCm,
    required this.riseRateCmMin,
    required this.riskLevel,
    required this.riskValidity,
    required this.effectiveRiskLevel,
    required this.effectiveRiskValidity,
    required this.sensorQuality,
    required this.deviceHealth,
    required this.receivedAt,
    required this.deviceTs,
    required this.timeQuality,
    required this.temperatureC,
    required this.rainTickCount,
    required this.firmwareVersion,
    required this.configVersion,
    required this.outboxLostEventCount,
  });

  final String id, name, location, origin, lastStatus, freshness, linkState;
  final DateTime? lastStatusAt, receivedAt, deviceTs;
  final String? messageId,
      riskLevel,
      riskValidity,
      effectiveRiskLevel,
      effectiveRiskValidity,
      deviceHealth,
      timeQuality;
  final String? firmwareVersion, configVersion;
  final double? waterLevelCm, distanceCm, riseRateCmMin, temperatureC;
  final int? rainTickCount, outboxLostEventCount;
  final Map<String, String> sensorQuality;

  factory Station.fromJson(Map<String, dynamic> json) {
    final qualities = json['sensor_quality'];
    return Station(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      origin: json['data_origin'] as String? ?? 'UNKNOWN',
      lastStatus: json['last_status'] as String? ?? 'OFFLINE',
      freshness: json['freshness'] as String? ?? 'UNKNOWN',
      linkState: json['link_state'] as String? ?? 'OFFLINE',
      lastStatusAt: parseTime(json['last_status_at']),
      messageId: json['message_id'] as String?,
      waterLevelCm: parseNumber(json['water_level_cm']),
      distanceCm: parseNumber(json['distance_cm']),
      riseRateCmMin: parseNumber(json['rise_rate_cm_min']),
      riskLevel: json['risk_level'] as String?,
      riskValidity: json['risk_validity'] as String?,
      effectiveRiskLevel: json['effective_risk_level'] as String?,
      effectiveRiskValidity:
          json['effective_risk_validity'] as String? ?? 'UNKNOWN',
      sensorQuality: qualities is Map
          ? qualities.map((key, value) => MapEntry('$key', '$value'))
          : const {},
      deviceHealth: json['device_health'] as String?,
      receivedAt: parseTime(json['received_at']),
      deviceTs: parseTime(json['device_ts']),
      timeQuality: json['time_quality'] as String?,
      temperatureC: parseNumber(json['temperature_c']),
      rainTickCount: parseInteger(json['rain_tick_count']),
      firmwareVersion: json['firmware_version'] as String?,
      configVersion: json['config_version'] as String?,
      outboxLostEventCount: parseInteger(json['outbox_lost_event_count']),
    );
  }

  bool get isSimulated => origin == 'SIMULATED';
  bool get hasData => messageId != null && receivedAt != null;
  bool get isFresh => freshness == 'FRESH';
  bool get isOnline => linkState == 'ONLINE';
  bool get isRiskValid =>
      effectiveRiskValidity == 'VALID' && effectiveRiskLevel != null;
  String? get effectiveRisk => isRiskValid ? effectiveRiskLevel : null;
}

class TelemetryPoint {
  const TelemetryPoint({
    required this.receivedAt,
    required this.waterLevelCm,
    required this.distanceCm,
    required this.riskLevel,
    required this.riskValidity,
  });
  final DateTime receivedAt;
  final double? waterLevelCm, distanceCm;
  final String? riskLevel, riskValidity;
  factory TelemetryPoint.fromJson(Map<String, dynamic> json) => TelemetryPoint(
    receivedAt:
        parseTime(json['received_at']) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    waterLevelCm: parseNumber(json['water_level_cm']),
    distanceCm: parseNumber(json['distance_cm']),
    riskLevel: json['risk_level'] as String?,
    riskValidity: json['risk_validity'] as String?,
  );
}

class AlertEvent {
  const AlertEvent({
    required this.id,
    required this.stationId,
    required this.origin,
    required this.receivedAt,
    required this.deviceTs,
    required this.previousLevel,
    required this.currentLevel,
    required this.riskValidity,
    required this.reasonCodes,
  });
  final String id, stationId, origin, riskValidity;
  final DateTime receivedAt;
  final DateTime? deviceTs;
  final String? previousLevel, currentLevel;
  final List<String> reasonCodes;
  factory AlertEvent.fromJson(Map<String, dynamic> json) => AlertEvent(
    id: json['alert_id'] as String? ?? '',
    stationId: json['station_id'] as String? ?? '',
    origin: json['data_origin'] as String? ?? 'UNKNOWN',
    receivedAt:
        parseTime(json['received_at']) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    deviceTs: parseTime(json['device_ts']),
    previousLevel: json['previous_level'] as String?,
    currentLevel: json['current_level'] as String?,
    riskValidity: json['risk_validity'] as String? ?? 'UNKNOWN',
    reasonCodes: (json['reason_codes'] as List? ?? const [])
        .map((value) => '$value')
        .toList(),
  );
}

class DemoControl {
  const DemoControl({
    required this.stationId,
    required this.running,
    required this.direction,
    required this.waterLevelCm,
    required this.baselineWaterCm,
    required this.riseRateCmMin,
    required this.rainTickCount,
    required this.rainRateMmHour,
    required this.temperatureC,
    required this.watchCm,
    required this.warningCm,
    required this.emergencyCm,
  });

  final String stationId, direction;
  final bool running;
  final double waterLevelCm, baselineWaterCm, riseRateCmMin;
  final int rainTickCount;
  final double rainRateMmHour, temperatureC, watchCm, warningCm, emergencyCm;

  factory DemoControl.fromJson(Map<String, dynamic> json) => DemoControl(
    stationId: json['station_id'] as String? ?? '',
    running: json['running'] as bool? ?? false,
    direction: json['direction'] as String? ?? 'HOLD',
    waterLevelCm: parseNumber(json['water_level_cm']) ?? 0,
    baselineWaterCm: parseNumber(json['baseline_water_cm']) ?? 0,
    riseRateCmMin: parseNumber(json['rise_rate_cm_min']) ?? 0,
    rainTickCount: parseInteger(json['rain_tick_count']) ?? 0,
    rainRateMmHour: parseNumber(json['rain_rate_mm_hour']) ?? 0,
    temperatureC: parseNumber(json['temperature_c']) ?? 28,
    watchCm: parseNumber(json['watch_cm']) ?? 30,
    warningCm: parseNumber(json['warning_cm']) ?? 50,
    emergencyCm: parseNumber(json['emergency_cm']) ?? 70,
  );
}
