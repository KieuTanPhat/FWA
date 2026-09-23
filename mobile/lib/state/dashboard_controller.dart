import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../data/fwa_repository.dart';
import '../models.dart';

class DashboardController extends ChangeNotifier {
  DashboardController(
    this.repository, {
    this.saveBaseUrl,
    this.requireRegionSelection = false,
    String? initialStationId,
  }) : selectedId = initialStationId;
  final FwaRepository repository;
  final Future<void> Function(String)? saveBaseUrl;
  final bool requireRegionSelection;
  List<Station> stations = const [];
  List<TelemetryPoint> history = const [];
  List<AlertEvent> alerts = const [];
  DemoControl? demoControl;
  AlertEvent? incomingAlert;
  String? _pendingLiveAlertId;
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
    demoControl = null;
    incomingAlert = null;
    _pendingLiveAlertId = null;
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
    if (!requireRegionSelection) selectedId = null;
    stations = const [];
    history = const [];
    alerts = const [];
    demoControl = null;
    incomingAlert = null;
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
      if (!requireRegionSelection &&
          (selectedId == null ||
              !updated.any((station) => station.id == selectedId))) {
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
      if (selectedId != null &&
          updated.any((station) => station.id == selectedId)) {
        final requests = <Future<Object>>[
          repository.telemetry(selectedId!),
          repository.alerts(selectedId!),
        ];
        final controlRepository = repository is DemoControlRepository
            ? repository as DemoControlRepository
            : null;
        final controlIndex = controlRepository == null ? -1 : requests.length;
        if (controlRepository != null) {
          requests.add(controlRepository.demoControl(selectedId!));
        }
        final results = await Future.wait(requests);
        if (generation != _configGeneration) {
          _pending = true;
          return;
        }
        history = results[0] as List<TelemetryPoint>;
        alerts = results[1] as List<AlertEvent>;
        if (controlIndex >= 0) {
          demoControl = results[controlIndex] as DemoControl;
        }
        final pendingId = _pendingLiveAlertId;
        if (pendingId != null) {
          for (final alert in alerts) {
            if (alert.id == pendingId && alert.stationId == selectedId) {
              incomingAlert = alert;
              break;
            }
          }
          _pendingLiveAlertId = null;
        }
      } else if (requireRegionSelection) {
        history = const [];
        alerts = const [];
        demoControl = null;
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

  Future<void> updateDemoControl(Map<String, dynamic> patch) async {
    final id = selectedId;
    final controlRepository = repository is DemoControlRepository
        ? repository as DemoControlRepository
        : null;
    if (id == null || controlRepository == null) {
      throw StateError(
        'Cảm biến mô phỏng chưa được chọn hoặc API chưa hỗ trợ điều khiển.',
      );
    }
    demoControl = await controlRepository.updateDemoControl(id, patch);
    notifyListeners();
    await refresh();
  }

  AlertEvent? consumeIncomingAlert() {
    final alert = incomingAlert;
    incomingAlert = null;
    return alert;
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
            final eventName = data['event'];
            final eventData = data['data'];
            if (eventName == 'station.alert' && eventData is Map) {
              if (eventData['station_id'] == selectedId &&
                  eventData['alert_id'] is String) {
                _pendingLiveAlertId = eventData['alert_id'] as String;
              }
            }
            if (eventName is String &&
                (!requireRegionSelection ||
                    (eventData is Map &&
                        eventData['station_id'] == selectedId))) {
              unawaited(refresh());
            }
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
