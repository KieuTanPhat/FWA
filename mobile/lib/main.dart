import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/fwa_repository.dart';
import 'state/dashboard_controller.dart';
import 'ui/fwa_app.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://fwa-floodwatch-demo.onrender.com',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences? preferences;
  try {
    preferences = await SharedPreferences.getInstance();
  } catch (_) {
    // App vẫn mở để người dùng thấy lỗi kết nối nếu bộ nhớ cấu hình lỗi.
  }
  var configuredUrl = preferences?.getString('api_base_url')?.trim();
  // Nếu chưa cấu hình hoặc URL cũ là localhost/10.0.2.2 thì tự động dùng Cloud URL
  if (configuredUrl == null ||
      configuredUrl.isEmpty ||
      configuredUrl.contains('10.0.2.2') ||
      configuredUrl.contains('localhost')) {
    configuredUrl = apiBaseUrl;
  }
  final initialUrl = configuredUrl;

  final controller = DashboardController(
    HttpFwaRepository(initialUrl),
    saveBaseUrl: (url) async {
      final store = preferences;
      if (store == null || !await store.setString('api_base_url', url)) {
        throw StateError('Không lưu được địa chỉ API.');
      }
    },
  );
  runApp(FwaApp(controller: controller));
  unawaited(controller.start());
}
