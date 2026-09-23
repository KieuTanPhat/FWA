import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';

class EmergencyNotice {
  const EmergencyNotice({
    required this.alertId,
    required this.stationId,
    required this.stationName,
    required this.area,
    required this.waterLevelCm,
    required this.occurredAt,
  });

  final String alertId;
  final String stationId;
  final String stationName;
  final String area;
  final double? waterLevelCm;
  final DateTime occurredAt;

  String toPayload() => jsonEncode({
    'alert_id': alertId,
    'station_id': stationId,
    'station_name': stationName,
    'area': area,
    'water_level_cm': waterLevelCm,
    'occurred_at': occurredAt.toIso8601String(),
  });

  static EmergencyNotice? fromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final occurredAt = DateTime.tryParse(
        data['occurred_at'] as String? ?? '',
      );
      if (occurredAt == null) return null;
      return EmergencyNotice(
        alertId: data['alert_id'] as String? ?? '',
        stationId: data['station_id'] as String? ?? '',
        stationName: data['station_name'] as String? ?? 'Trạm cảnh báo lũ',
        area: data['area'] as String? ?? '',
        waterLevelCm: parseNumber(data['water_level_cm']),
        occurredAt: occurredAt.toLocal(),
      );
    } catch (_) {
      return null;
    }
  }

  factory EmergencyNotice.fromStationAlert(
    AlertEvent alert,
    Station? station,
    String stationName,
    String area,
  ) => EmergencyNotice(
    alertId: alert.id,
    stationId: alert.stationId,
    stationName: stationName,
    area: area,
    waterLevelCm: station?.waterLevelCm,
    occurredAt: alert.receivedAt,
  );
}

class EmergencyNotifications {
  EmergencyNotifications._();

  static final instance = EmergencyNotifications._();
  static const _channelId = 'fwa_flood_emergency_v1';
  static const _channelName = 'Cảnh báo lũ khẩn cấp';
  static final _vibration = Int64List.fromList([0, 800, 250, 800, 300, 1200]);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<EmergencyNotice> _openedNotices =
      StreamController<EmergencyNotice>.broadcast();
  bool _initialized = false;
  EmergencyNotice? _pendingNotice;

  Stream<EmergencyNotice> get openedNotices => _openedNotices.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    const initialization = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
    );
    await _plugin.initialize(
      settings: initialization,
      onDidReceiveNotificationResponse: (response) {
        final notice = EmergencyNotice.fromPayload(response.payload);
        if (notice != null) {
          _pendingNotice = notice;
          _openedNotices.add(notice);
        }
      },
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        _channelId,
        _channelName,
        description:
            'Đánh thức màn hình, rung và phát âm thanh khi mực nước đạt mức khẩn cấp.',
        importance: Importance.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('fwa_alarm'),
        enableVibration: true,
        vibrationPattern: _vibration,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
    _initialized = true;

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      final notice = EmergencyNotice.fromPayload(
        launch?.notificationResponse?.payload,
      );
      if (notice != null) _pendingNotice = notice;
    }
  }

  Future<bool> notificationsEnabled() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.areNotificationsEnabled() ?? true;
  }

  Future<bool> requestPermissions() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return false;

    var enabled = await android.areNotificationsEnabled() ?? false;
    if (!enabled) {
      await android.requestNotificationsPermission();
      enabled = await android.areNotificationsEnabled() ?? false;
    }
    if (!enabled) {
      await _plugin.openAppNotificationSettings();
      return false;
    }

    final fullScreenAllowed =
        await android.requestFullScreenIntentPermission() ?? false;
    return enabled && fullScreenAllowed;
  }

  Future<bool> showEmergency(EmergencyNotice notice) async {
    await initialize();
    if (notice.alertId.isEmpty) return false;

    final preferences = await SharedPreferences.getInstance();
    final key = 'fwa_last_emergency_${notice.stationId}';
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final enabled = await android?.areNotificationsEnabled() ?? true;
    if (enabled && preferences.getString(key) != notice.alertId) {
      await _plugin.show(
        id: _notificationId(notice.stationId),
        title: 'KHẨN CẤP · CẢNH BÁO LŨ',
        body: notice.waterLevelCm == null
            ? '${notice.stationName} · ${notice.area}'
            : '${notice.stationName} · mực nước ${notice.waterLevelCm!.toStringAsFixed(1)} cm',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Cảnh báo khẩn cấp tại khu vực đã chọn.',
            icon: 'ic_notification',
            color: Color(0xFFB22632),
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
            fullScreenIntent: true,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('fwa_alarm'),
            enableVibration: true,
            vibrationPattern: _vibration,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            ongoing: true,
            autoCancel: false,
          ),
        ),
        payload: notice.toPayload(),
      );
      await preferences.setString(key, notice.alertId);
    }
    return true;
  }

  Future<void> acknowledge(String stationId) async {
    await initialize();
    await _plugin.cancel(id: _notificationId(stationId));
  }

  EmergencyNotice? consumePendingNotice() {
    final notice = _pendingNotice;
    _pendingNotice = null;
    return notice;
  }

  int _notificationId(String stationId) => switch (stationId) {
    'sim-01' => 101,
    'sim-02' => 102,
    'sim-03' => 103,
    _ => 199,
  };
}
