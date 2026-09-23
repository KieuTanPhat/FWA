import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../data/fwa_repository.dart';
import '../models.dart';

class DashboardController extends ChangeNotifier {
  DashboardController(this.repository, {this.saveBaseUrl});
  final FwaRepository repository;
  final Future<void> Function(String)? saveBaseUrl;
  List<Station> stations = const [];
  List<TelemetryPoint> history = const [];
  List<AlertEvent> alerts = const [];
  String? selectedId;
  String? error;
  String? errorDetails;
  DateTime? lastSync;
  bool loading = true;
  bool streamOnline = false;
  bool _busy = false;
  bool _pending = false;
  bool _closed = false;
  int _configGeneration = 0;
  int _reconnectAttempts = 0;
  Timer? _pollTimer, _reconnectTimer;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  Station? get selectedStation {
    for (final station in stations) {
      if (station.id == selectedId) return station;
    }
    return null;
  }

  Future<void> start({bool connectStream = true}) async {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(refresh());
    });
    await refresh();
    if (connectStream && !_closed) _openStream();
  }

  void selectStation(String id) {
    if (id == selectedId) return;
    selectedId = id;
    history = const [];
    alerts = const [];
    notifyListeners();
    unawaited(refresh());
  }

  Future<String?> changeBaseUrl(String input) async {
    final value = input.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path.isNotEmpty) {
      return 'Nhập URL dạng http(s)://IP-hoặc-tên-miền:port, không thêm đường dẫn.';
    }
    if (kReleaseMode && uri.scheme != 'https') {
      return 'Bản phát hành chỉ chấp nhận HTTPS.';
    }
    if (value == repository.baseUrl) return null;
    try {
      await saveBaseUrl?.call(value);
    } catch (_) {
      return 'Không lưu được địa chỉ API.';
    }
    _configGeneration++;
    _reconnectTimer?.cancel();
    final previousChannel = _channel;
    _channel = null;
    _subscription?.cancel();
    previousChannel?.sink.close();
    streamOnline = false;
    repository.baseUrl = value;
    selectedId = null;
    stations = const [];
    history = const [];
    alerts = const [];
    loading = true;
    error = null;
    errorDetails = null;
    notifyListeners();
    await refresh();
    _openStream();
    return null;
  }

  Future<void> refresh() async {
    if (_closed) return;
    if (_busy) {
      _pending = true;
      return;
    }
    _busy = true;
    final generation = _configGeneration;
    try {
      final updated = await repository.stations();
      if (generation != _configGeneration) {
        _pending = true;
        return;
      }
      stations = updated;
      if (selectedId == null ||
          !updated.any((station) => station.id == selectedId)) {
        final activePhysical = updated.where(
          (station) => !station.isSimulated && station.hasData,
        );
        final activeAny = updated.where((station) => station.hasData);
        selectedId = activePhysical.isNotEmpty
            ? activePhysical.first.id
            : activeAny.isNotEmpty
            ? activeAny.first.id
            : updated
                      .where((station) => !station.isSimulated)
                      .firstOrNull
                      ?.id ??
                  updated.firstOrNull?.id;
      }
      if (selectedId != null) {
        final results = await Future.wait([
          repository.telemetry(selectedId!),
          repository.alerts(selectedId!),
        ]);
        if (generation != _configGeneration) {
          _pending = true;
          return;
        }
        history = results[0] as List<TelemetryPoint>;
        alerts = results[1] as List<AlertEvent>;
      }
      error = null;
      errorDetails = null;
      lastSync = DateTime.now();
    } catch (e) {
      error = 'Không tải được dữ liệu. Kiểm tra địa chỉ API và kết nối LAN.';
      errorDetails = '$e';
    } finally {
      loading = false;
      _busy = false;
      if (!_closed) notifyListeners();
      if (_pending && !_closed) {
        _pending = false;
        unawaited(refresh());
      }
    }
  }

  void _openStream() {
    if (_closed) return;
    try {
      final channel = repository.stream();
      _channel = channel;
      Future<void> markReady() async {
        try {
          await channel.ready;
          if (_closed || !identical(_channel, channel)) return;
          streamOnline = true;
          _reconnectAttempts = 0;
          notifyListeners();
          unawaited(refresh());
        } catch (_) {
          _streamClosed(channel);
        }
      }

      unawaited(markReady());
      _subscription = channel.stream.listen(
        (event) {
          if (_closed) return;
          try {
            final data = jsonDecode(event as String) as Map<String, dynamic>;
            if (data['event'] is String) unawaited(refresh());
          } catch (_) {
            /* Bỏ frame lỗi; REST polling vẫn hoạt động. */
          }
        },
        onError: (Object _) => _streamClosed(channel),
        onDone: () => _streamClosed(channel),
      );
    } catch (_) {
      _streamClosed();
    }
  }

  void _streamClosed([WebSocketChannel? source]) {
    if (_closed ||
        (source != null && !identical(source, _channel)) ||
        (_reconnectTimer?.isActive ?? false)) {
      return;
    }
    streamOnline = false;
    notifyListeners();
    _subscription?.cancel();
    _channel?.sink.close();
    _reconnectTimer?.cancel();
    final seconds = min(30, 1 << min(_reconnectAttempts, 5));
    if (_reconnectAttempts < 5) _reconnectAttempts++;
    _reconnectTimer = Timer(Duration(seconds: seconds), _openStream);
  }

  @override
  void dispose() {
    _closed = true;
    _pollTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    repository.close();
    super.dispose();
  }
}
