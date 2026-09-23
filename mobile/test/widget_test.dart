import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flood_watch_mobile/data/fwa_repository.dart';
import 'package:flood_watch_mobile/models.dart';
import 'package:flood_watch_mobile/state/dashboard_controller.dart';
import 'package:flood_watch_mobile/ui/fwa_app.dart';

class FakeRepository implements FwaRepository {
  @override
  String baseUrl = 'http://127.0.0.1:3000';
  bool failStations = false;
  @override
  Future<List<Station>> stations() async {
    if (failStations) throw Exception('API unreachable');
    return [
    Station.fromJson({
      'id': 'sim-01',
      'name': 'Trạm mô phỏng',
      'location': 'Mô hình phòng lab',
      'data_origin': 'SIMULATED',
      'last_status': 'ONLINE',
      'last_status_at': DateTime.now().toUtc().toIso8601String(),
      'freshness': 'FRESH',
      'link_state': 'ONLINE',
      'message_id': 'sim-01:boot:1',
      'water_level_cm': 18,
      'rise_rate_cm_min': null,
      'risk_level': 'NORMAL',
      'risk_validity': 'VALID',
      'effective_risk_level': 'NORMAL',
      'effective_risk_validity': 'VALID',
      'sensor_quality': {
        'water': 'GOOD',
        'rain': 'GOOD',
        'temperature': 'GOOD',
      },
      'device_health': 'OK',
      'received_at': DateTime.now().toUtc().toIso8601String(),
      'device_ts': null,
      'time_quality': 'UNSYNCED',
      'temperature_c': 27,
      'rain_tick_count': 0,
      'firmware_version': 'sim-1',
      'config_version': 'demo-1',
      'outbox_lost_event_count': 0,
    }),
    ];
  }
  @override
  Future<List<TelemetryPoint>> telemetry(String stationId) async => const [];
  @override
  Future<List<AlertEvent>> alerts(String stationId) async => [
    AlertEvent.fromJson({
      'alert_id': 'a1',
      'station_id': stationId,
      'data_origin': 'SIMULATED',
      'received_at': DateTime.now().toUtc().toIso8601String(),
      'device_ts': null,
      'previous_level': 'NORMAL',
      'current_level': 'WATCH',
      'risk_validity': 'VALID',
      'reason_codes': ['DEMO_WATER_THRESHOLD'],
    }),
  ];
  @override
  WebSocketChannel stream() => throw UnimplementedError();
  @override
  void close() {}
}

void main() {
  test('Địa chỉ API được kiểm tra và lưu trước khi kết nối lại', () async {
    final repository = FakeRepository();
    String? savedUrl;
    final controller = DashboardController(
      repository,
      saveBaseUrl: (url) async {
        savedUrl = url;
      },
    );

    final invalid = await controller.changeBaseUrl(
      'http://192.168.1.20:3000/api',
    );
    expect(invalid, isNotNull);
    expect(repository.baseUrl, 'http://127.0.0.1:3000');
    expect(savedUrl, isNull);

    final accepted = await controller.changeBaseUrl(
      'http://192.168.1.20:3000/',
    );
    expect(accepted, isNull);
    expect(repository.baseUrl, 'http://192.168.1.20:3000');
    expect(savedUrl, 'http://192.168.1.20:3000');
    controller.dispose();
  });

  test('Dữ liệu cũ không được coi là trạng thái NORMAL hiện tại', () {
    final station = Station.fromJson({
      'id': 'sim-01',
      'name': 'Trạm',
      'location': 'Lab',
      'data_origin': 'SIMULATED',
      'last_status': 'OFFLINE',
      'message_id': 'm1',
      'received_at': DateTime.now()
          .subtract(const Duration(minutes: 1))
          .toUtc()
          .toIso8601String(),
      'freshness': 'STALE',
      'link_state': 'OFFLINE',
      'risk_level': 'NORMAL',
      'risk_validity': 'VALID',
      'effective_risk_level': null,
      'effective_risk_validity': 'UNKNOWN',
      'sensor_quality': {'water': 'GOOD'},
    });
    expect(station.effectiveRisk, isNull);
  });

  test(
    'Freshness và risk hiệu lực lấy từ backend, không dùng giờ điện thoại',
    () {
      final station = Station.fromJson({
        'id': 'physical-01',
        'name': 'Trạm',
        'location': 'Lab',
        'data_origin': 'PHYSICAL',
        'last_status': 'OFFLINE',
        'last_status_at': '2000-01-01T00:00:00Z',
        'message_id': 'm1',
        'received_at': DateTime.now()
            .add(const Duration(days: 1))
            .toUtc()
            .toIso8601String(),
        'freshness': 'FRESH',
        'link_state': 'ONLINE',
        'risk_level': 'WARNING',
        'risk_validity': 'VALID',
        'effective_risk_level': 'WARNING',
        'effective_risk_validity': 'VALID',
        'sensor_quality': {'water': 'GOOD'},
      });

      expect(station.isFresh, isTrue);
      expect(station.isOnline, isTrue);
      expect(station.effectiveRisk, 'WARNING');
    },
  );

  test('Bộ đếm bigint từ PostgreSQL đọc được khi API trả chuỗi', () {
    final station = Station.fromJson({
      'id': 'sim-01',
      'name': 'Trạm',
      'location': 'Lab',
      'data_origin': 'SIMULATED',
      'rain_tick_count': '12',
      'outbox_lost_event_count': '0',
    });
    expect(station.rainTickCount, 12);
    expect(station.outboxLostEventCount, 0);
  });

  test('Trạm offline không được coi là NORMAL dù số đo mới', () {
    final station = Station.fromJson({
      'id': 'sim-01',
      'name': 'Trạm',
      'location': 'Lab',
      'data_origin': 'SIMULATED',
      'last_status': 'OFFLINE',
      'message_id': 'm1',
      'received_at': DateTime.now().toUtc().toIso8601String(),
      'freshness': 'FRESH',
      'link_state': 'OFFLINE',
      'risk_level': 'NORMAL',
      'risk_validity': 'VALID',
      'effective_risk_level': null,
      'effective_risk_validity': 'UNKNOWN',
      'sensor_quality': {'water': 'GOOD'},
    });
    expect(station.effectiveRisk, isNull);
  });

  testWidgets('App luôn cho thấy nhãn mô phỏng và sự kiện', (tester) async {
    final controller = DashboardController(FakeRepository());
    await controller.start(connectStream: false);
    await tester.pumpWidget(FwaApp(controller: controller));
    expect(find.text('MÔ PHỎNG'), findsOneWidget);
    expect(find.text('Bình thường'), findsOneWidget);
    expect(find.byTooltip('Cấu hình địa chỉ API'), findsOneWidget);
    await tester.tap(find.text('Sự kiện'));
    await tester.pumpAndSettle();
    expect(find.text('Mực nước vượt ngưỡng'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('Người dùng có thể lưu URL backend từ app', (tester) async {
    final repository = FakeRepository();
    String? savedUrl;
    final controller = DashboardController(
      repository,
      saveBaseUrl: (url) async {
        savedUrl = url;
      },
    );
    await controller.start(connectStream: false);
    await tester.pumpWidget(FwaApp(controller: controller));
    await tester.tap(find.byTooltip('Cấu hình địa chỉ API'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'http://192.168.1.22:3000');
    await tester.tap(find.text('Lưu và kết nối'));
    await tester.pumpAndSettle();

    expect(repository.baseUrl, 'http://192.168.1.22:3000');
    expect(savedUrl, 'http://192.168.1.22:3000');
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('API lỗi không giữ cấp rủi ro cũ như hiện trạng', (tester) async {
    final repository = FakeRepository();
    final controller = DashboardController(repository);
    await controller.start(connectStream: false);
    repository.failStations = true;
    await controller.refresh();
    await tester.pumpWidget(FwaApp(controller: controller));

    expect(find.text('Không tải được dữ liệu. Kiểm tra địa chỉ API và kết nối LAN.'), findsOneWidget);
    expect(find.text('Không xác định'), findsOneWidget);
    expect(
      find.text('Các số đo bên dưới là lần ghi nhận cuối, không phải hiện trạng.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
