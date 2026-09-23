import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models.dart';

abstract class FwaRepository {
  Future<List<Station>> stations();
  Future<List<TelemetryPoint>> telemetry(String stationId);
  Future<List<AlertEvent>> alerts(String stationId);
  WebSocketChannel stream();
  String get baseUrl;
  set baseUrl(String value);
  void close();
}

abstract interface class DemoControlRepository {
  Future<DemoControl> demoControl(String stationId);
  Future<DemoControl> updateDemoControl(
    String stationId,
    Map<String, dynamic> patch,
  );
}

class HttpFwaRepository implements FwaRepository, DemoControlRepository {
  HttpFwaRepository(this.baseUrl, {http.Client? client})
    : _client = client ?? http.Client();
  @override
  String baseUrl;
  final http.Client _client;

  Uri _uri(String path) => Uri.parse(baseUrl).resolve(path);

  Future<dynamic> _get(String path) async {
    final response = await _client
        .get(_uri(path))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('API trả mã ${response.statusCode}');
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  @override
  Future<List<Station>> stations() async {
    final data = await _get('/api/v1/stations') as List;
    return data
        .map((value) => Station.fromJson(value as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<TelemetryPoint>> telemetry(String stationId) async {
    final id = Uri.encodeComponent(stationId);
    final data = await _get('/api/v1/stations/$id/telemetry?limit=100') as List;
    return data
        .map((value) => TelemetryPoint.fromJson(value as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<AlertEvent>> alerts(String stationId) async {
    final id = Uri.encodeQueryComponent(stationId);
    final data = await _get('/api/v1/alerts?station_id=$id&limit=100') as List;
    return data
        .map((value) => AlertEvent.fromJson(value as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<DemoControl> demoControl(String stationId) async {
    final id = Uri.encodeComponent(stationId);
    final data = await _get('/api/v1/demo/stations/$id/control');
    return DemoControl.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<DemoControl> updateDemoControl(
    String stationId,
    Map<String, dynamic> patch,
  ) async {
    final id = Uri.encodeComponent(stationId);
    final response = await _client
        .patch(
          _uri('/api/v1/demo/stations/$id/control'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(patch),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final message = body is Map ? body['message'] : null;
      throw Exception(message ?? 'API trả mã ${response.statusCode}');
    }
    return DemoControl.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  @override
  WebSocketChannel stream() {
    final uri = Uri.parse(baseUrl).replace(
      scheme: baseUrl.startsWith('https:') ? 'wss' : 'ws',
      path: '/api/v1/stream',
      query: '',
    );
    return WebSocketChannel.connect(uri);
  }

  @override
  void close() => _client.close();
}
