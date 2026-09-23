import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/fwa_repository.dart';
import 'demo/region_demo.dart';
import 'notifications/emergency_notifications.dart';
import 'state/dashboard_controller.dart';
import 'ui/fwa_app.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://fwa-floodwatch-demo.onrender.com',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await EmergencyNotifications.instance.initialize();
  } catch (_) {
    // Sensor reading and app navigation remain available if notifications fail.
  }
  SharedPreferences? preferences;
  try {
    preferences = await SharedPreferences.getInstance();
  } catch (_) {
    // App vẫn mở để người dùng thấy lỗi kết nối nếu bộ nhớ cấu hình lỗi.
  }
  final selectedRegion = findDemoRegion(
    preferences?.getString('selected_region_id'),
  );
  final controller = DashboardController(
    HttpFwaRepository(apiBaseUrl),
    initialStationId: selectedRegion?.sensors.single.stationId,
    requireRegionSelection: true,
  );
  runApp(
    FwaApp(
      controller: controller,
      initialRegionId: selectedRegion?.id,
      saveRegionId: (id) async {
        final store = preferences;
        if (store != null && !await store.setString('selected_region_id', id)) {
          throw StateError('Không lưu được khu vực đã chọn.');
        }
      },
    ),
  );
  unawaited(controller.start());
}
