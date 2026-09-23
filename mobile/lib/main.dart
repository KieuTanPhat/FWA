import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/fwa_repository.dart';
import 'state/dashboard_controller.dart';
import 'ui/fwa_app.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences? preferences;
  try {
    preferences = await SharedPreferences.getInstance();
  } catch (_) {
    // App vẫn mở để người dùng thấy lỗi kết nối nếu bộ nhớ cấu hình lỗi.
  }
  final configuredUrl = preferences?.getString('api_base_url')?.trim();
  final initialUrl = configuredUrl == null || configuredUrl.isEmpty
      ? apiBaseUrl
      : configuredUrl;
  final scheme = Uri.tryParse(initialUrl)?.scheme;
  if (kReleaseMode && scheme != 'https') {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Bản phát hành cần API_BASE_URL dùng HTTPS. Hãy cấu hình lại khi build.',
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }
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
