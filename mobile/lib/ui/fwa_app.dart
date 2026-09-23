import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../state/dashboard_controller.dart';

const _navy = Color(0xFF12283D);
const _teal = Color(0xFF087D75);
const _paper = Color(0xFFF3F7F7);

String riskLabel(String? value) => switch (value) {
  'NORMAL' => 'Bình thường',
  'WATCH' => 'Theo dõi',
  'WARNING' => 'Cảnh báo',
  'EMERGENCY' => 'Khẩn cấp',
  _ => 'Không xác định',
};

Color riskColor(String? value) => switch (value) {
  'NORMAL' => const Color(0xFF07845C),
  'WATCH' => const Color(0xFFC07400),
  'WARNING' => const Color(0xFFD4541C),
  'EMERGENCY' => const Color(0xFFB22632),
  _ => const Color(0xFF667785),
};

String timeLabel(DateTime? value) {
  if (value == null) return 'Không có';
  final offset = value.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final hours = offset.inHours.abs().toString().padLeft(2, '0');
  final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  return '${DateFormat('dd/MM/yyyy HH:mm:ss').format(value)} UTC$sign$hours:$minutes';
}

String reasonLabel(String value) => switch (value) {
  'WATER_OR_RISE_THRESHOLD' || 'DEMO_WATER_THRESHOLD' => 'Mực nước vượt ngưỡng',
  'SENSOR_TIMEOUT' || 'DEMO_SENSOR_TIMEOUT' => 'Mất tín hiệu cảm biến',
  'SENSOR_RECOVERED' || 'DEMO_SENSOR_RECOVERED' => 'Cảm biến hoạt động lại',
  _ => value,
};

class FwaApp extends StatelessWidget {
  const FwaApp({super.key, required this.controller});
  final DashboardController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'FWA Cảnh báo lũ',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: _teal, surface: _paper),
      scaffoldBackgroundColor: _paper,
      appBarTheme: const AppBarTheme(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    home: _Dashboard(controller: controller),
  );
}

class _Dashboard extends StatefulWidget {
  const _Dashboard({required this.controller});
  final DashboardController controller;
  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  int tab = 0;

  Future<void> _editApiBaseUrl(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ApiUrlDialog(controller: widget.controller),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final state = widget.controller;
      final station = state.selectedStation;
      return Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FWA',
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2),
              ),
              Text(
                'CẢNH BÁO LŨ IoT',
                style: TextStyle(fontSize: 11, letterSpacing: 1.2),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () => state.refresh(),
              icon: const Icon(Icons.refresh),
              tooltip: 'Tải lại',
            ),
            IconButton(
              onPressed: () => _editApiBaseUrl(context),
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Cấu hình địa chỉ API',
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: state.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            children: [
              if (state.error != null)
                _Banner(
                  icon: Icons.wifi_off,
                  text: state.error!,
                  color: const Color(0xFFB44A31),
                ),
              if (state.loading && state.stations.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!state.loading && state.stations.isEmpty)
                const _Banner(
                  icon: Icons.sensors_off,
                  text: 'Chưa có trạm hoặc không kết nối được API.',
                  color: _navy,
                ),
              if (state.stations.isNotEmpty) ...[
                _StationPicker(state: state),
                const SizedBox(height: 14),
                if (station != null) ...[
                  _OriginHeader(station: station),
                  const SizedBox(height: 14),
                  if (tab == 0)
                    _Overview(
                      station: station,
                      apiReachable: state.error == null,
                    ),
                  if (tab == 1)
                    _History(points: state.history, station: station),
                  if (tab == 2) _Alerts(alerts: state.alerts, station: station),
                  if (tab == 3) _Connection(state: state, station: station),
                ],
              ],
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (value) => setState(() => tab = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Tổng quan',
            ),
            NavigationDestination(
              icon: Icon(Icons.show_chart),
              label: 'Lịch sử',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications),
              label: 'Sự kiện',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_ethernet),
              label: 'Kết nối',
            ),
          ],
        ),
      );
    },
  );
}

class _ApiUrlDialog extends StatefulWidget {
  const _ApiUrlDialog({required this.controller});
  final DashboardController controller;

  @override
  State<_ApiUrlDialog> createState() => _ApiUrlDialogState();
}

class _ApiUrlDialogState extends State<_ApiUrlDialog> {
  late final TextEditingController input;
  String? error;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    input = TextEditingController(text: widget.controller.repository.baseUrl);
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    setState(() => saving = true);
    final problem = await widget.controller.changeBaseUrl(input.text);
    if (!mounted) return;
    if (problem != null) {
      setState(() {
        error = problem;
        saving = false;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Địa chỉ backend'),
    content: TextField(
      controller: input,
      enabled: !saving,
      keyboardType: TextInputType.url,
      autocorrect: false,
      onChanged: (_) {
        if (error != null) setState(() => error = null);
      },
      decoration: InputDecoration(
        labelText: 'URL API',
        hintText: 'http://192.168.1.10:3000',
        errorText: error,
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.of(context).pop(),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: saving ? null : save,
        child: Text(saving ? 'Đang lưu…' : 'Lưu và kết nối'),
      ),
    ],
  );
}

class _StationPicker extends StatelessWidget {
  const _StationPicker({required this.state});
  final DashboardController state;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.sensors, color: _teal),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: state.selectedId,
                items: state.stations
                    .map(
                      (s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(
                          '${s.name} · ${s.isSimulated ? 'MÔ PHỎNG' : 'THIẾT BỊ THẬT'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  if (id != null) state.selectStation(id);
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _OriginHeader extends StatelessWidget {
  const _OriginHeader({required this.station});
  final Station station;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              station.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: _navy,
              ),
            ),
          ),
          _Badge(
            label: station.isSimulated ? 'MÔ PHỎNG' : 'THIẾT BỊ THẬT',
            icon: station.isSimulated ? Icons.science_outlined : Icons.memory,
            color: station.isSimulated ? const Color(0xFFAB5A1B) : _teal,
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(station.location, style: const TextStyle(color: Color(0xFF536675))),
    ],
  );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.station, required this.apiReachable});
  final Station station;
  final bool apiReachable;
  @override
  Widget build(BuildContext context) {
    final effective = apiReachable ? station.effectiveRisk : null;
    final valid = effective != null;
    final color = riskColor(effective);
    final stale = !apiReachable || !station.isFresh;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                valid ? 'MỨC RỦI RO HIỆN TẠI' : 'CHƯA THỂ KẾT LUẬN RỦI RO',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    valid ? Icons.water_drop : Icons.help_outline,
                    color: Colors.white,
                    size: 34,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      riskLabel(effective),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 29,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (!valid) ...[
                const SizedBox(height: 10),
                Text(
                  stale
                      ? 'Dữ liệu đã cũ hoặc chưa có số đo.'
                      : 'Chất lượng cảm biến không đủ để kết luận.',
                  style: const TextStyle(color: Colors.white),
                ),
                if (station.riskLevel != null)
                  Text(
                    'Ghi nhận cuối: ${riskLabel(station.riskLevel)} (không phải hiện trạng)',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Badge(
              label: stale ? 'DỮ LIỆU CŨ' : 'DỮ LIỆU MỚI',
              icon: stale ? Icons.history : Icons.update,
              color: stale ? const Color(0xFF9A5A25) : _teal,
            ),
            _Badge(
              label: !apiReachable
                  ? 'LIÊN KẾT CHƯA XÁC MINH'
                  : station.isOnline
                  ? 'TRẠM ONLINE'
                  : 'TRẠM OFFLINE',
              icon: apiReachable && station.isOnline
                  ? Icons.link
                  : Icons.link_off,
              color: apiReachable && station.isOnline
                  ? _teal
                  : const Color(0xFF9A5A25),
            ),
            _Badge(
              label:
                  '${stale ? 'CHẤT LƯỢNG CUỐI' : 'CẢM BIẾN'} ${station.sensorQuality['water'] ?? 'UNKNOWN'}',
              icon: Icons.sensors,
              color: !stale && station.sensorQuality['water'] == 'GOOD'
                  ? _teal
                  : const Color(0xFF9A5A25),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (stale)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Các số đo bên dưới là lần ghi nhận cuối, không phải hiện trạng.',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF9A5A25),
              ),
            ),
          ),
        LayoutBuilder(
          builder: (context, size) {
            final width = (size.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Metric(
                  width: width,
                  title: 'Mực nước',
                  value: station.waterLevelCm == null
                      ? '—'
                      : '${station.waterLevelCm!.toStringAsFixed(1)} cm',
                  icon: Icons.water,
                ),
                _Metric(
                  width: width,
                  title: 'Tốc độ dâng',
                  value: station.riseRateCmMin == null
                      ? '—'
                      : '${station.riseRateCmMin!.toStringAsFixed(1)} cm/phút',
                  icon: Icons.trending_up,
                ),
                _Metric(
                  width: width,
                  title: 'Xung mưa',
                  value: station.rainTickCount?.toString() ?? '—',
                  icon: Icons.grain,
                ),
                _Metric(
                  width: width,
                  title: 'Nhiệt độ',
                  value: station.temperatureC == null
                      ? '—'
                      : '${station.temperatureC!.toStringAsFixed(1)} °C',
                  icon: Icons.thermostat,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thời gian & tình trạng trạm',
                  style: TextStyle(fontWeight: FontWeight.w800, color: _navy),
                ),
                const SizedBox(height: 8),
                _Line('Backend nhận', timeLabel(station.receivedAt)),
                _Line(
                  'Thiết bị đo',
                  station.timeQuality == 'UNSYNCED'
                      ? 'Đồng hồ chưa đồng bộ'
                      : timeLabel(station.deviceTs),
                ),
                _Line('Sức khỏe thiết bị', station.deviceHealth ?? 'Chưa có'),
                _Line(
                  'Sự kiện mất ở outbox',
                  station.outboxLostEventCount?.toString() ?? 'Chưa có',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _Banner(
          icon: Icons.campaign_outlined,
          text:
              'Còi và đèn cảnh báo do ESP32 điều khiển tại trạm. Ứng dụng chỉ theo dõi, không gửi lệnh điều khiển.',
          color: _teal,
        ),
      ],
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.points, required this.station});
  final List<TelemetryPoint> points;
  final Station station;
  @override
  Widget build(BuildContext context) {
    final ordered = points.reversed.toList();
    final valid = ordered.where((p) => p.waterLevelCm != null).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Lịch sử mực nước',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: _navy,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '100 mẫu gần nhất theo thời gian backend nhận',
          style: TextStyle(color: Color(0xFF61717F)),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: valid.length < 2
                ? const SizedBox(
                    height: 160,
                    child: Center(
                      child: Text('Chưa đủ dữ liệu để vẽ biểu đồ.'),
                    ),
                  )
                : Column(
                    children: [
                      SizedBox(
                        height: 190,
                        width: double.infinity,
                        child: CustomPaint(painter: _WaterChart(ordered)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${timeLabel(ordered.first.receivedAt)}  →  ${timeLabel(ordered.last.receivedAt)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF61717F),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        ...points
            .take(30)
            .map(
              (p) => Card(
                child: ListTile(
                  leading: Icon(
                    p.waterLevelCm == null
                        ? Icons.sensors_off
                        : Icons.water_drop,
                    color: riskColor(
                      p.riskValidity == 'VALID' ? p.riskLevel : null,
                    ),
                  ),
                  title: Text(
                    p.waterLevelCm == null
                        ? 'Cảm biến không có số đo'
                        : '${p.waterLevelCm!.toStringAsFixed(1)} cm · ${riskLabel(p.riskLevel)}',
                  ),
                  subtitle: Text(timeLabel(p.receivedAt)),
                ),
              ),
            ),
        if (points.isEmpty)
          const _Banner(
            icon: Icons.show_chart,
            text: 'Chưa có lịch sử số đo cho trạm này.',
            color: _navy,
          ),
      ],
    );
  }
}

class _WaterChart extends CustomPainter {
  _WaterChart(this.points);
  final List<TelemetryPoint> points;
  @override
  void paint(Canvas canvas, Size size) {
    final values = points
        .where((p) => p.waterLevelCm != null)
        .map((p) => p.waterLevelCm!)
        .toList();
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final span = math.max(10.0, maxValue - minValue);
    final lower = minValue - (span - (maxValue - minValue)) / 2;
    final grid = Paint()
      ..color = const Color(0xFFE5ECEE)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final line = Paint()
      ..color = _teal
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    var hasSegment = false;
    for (var i = 0; i < points.length; i++) {
      final value = points[i].waterLevelCm;
      if (value == null) {
        hasSegment = false;
        continue;
      }
      final x = size.width * i / (points.length - 1);
      final y = size.height - (value - lower) / span * size.height;
      if (!hasSegment) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      hasSegment = true;
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _WaterChart oldDelegate) =>
      oldDelegate.points != points;
}

class _Alerts extends StatelessWidget {
  const _Alerts({required this.alerts, required this.station});
  final List<AlertEvent> alerts;
  final Station station;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Sự kiện cảnh báo',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: _navy,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Sự kiện lưu trên server, không xóa mức rủi ro của trạm.',
        style: TextStyle(color: Color(0xFF61717F)),
      ),
      const SizedBox(height: 12),
      if (alerts.isEmpty)
        const _Banner(
          icon: Icons.notifications_none,
          text: 'Chưa có sự kiện cho trạm này.',
          color: _navy,
        ),
      ...alerts.map(
        (event) => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      event.currentLevel == null
                          ? Icons.sensors_off
                          : Icons.warning_amber_rounded,
                      color: riskColor(event.currentLevel),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event.currentLevel == null
                            ? 'Không xác định · lỗi cảm biến'
                            : riskLabel(event.currentLevel),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    if (event.origin == 'SIMULATED')
                      const _Badge(
                        label: 'MÔ PHỎNG',
                        icon: Icons.science_outlined,
                        color: Color(0xFFAB5A1B),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${riskLabel(event.previousLevel)} → ${riskLabel(event.currentLevel)}',
                ),
                Text(
                  event.reasonCodes.map(reasonLabel).join(', '),
                  style: const TextStyle(color: Color(0xFF536675)),
                ),
                const SizedBox(height: 8),
                _Line('Server nhận', timeLabel(event.receivedAt)),
                _Line('Thiết bị đo', timeLabel(event.deviceTs)),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _Connection extends StatelessWidget {
  const _Connection({required this.state, required this.station});
  final DashboardController state;
  final Station station;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Kết nối & trợ giúp',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: _navy,
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Line('API', state.repository.baseUrl),
              _Line(
                'Cập nhật trực tiếp',
                state.streamOnline
                    ? 'WebSocket đang kết nối'
                    : 'WebSocket mất kết nối; REST vẫn thử tải lại',
              ),
              _Line('Đồng bộ cuối', timeLabel(state.lastSync)),
              if (state.errorDetails != null)
                _Line('Chi tiết lỗi', state.errorDetails!),
              _Line('Mã trạm', station.id),
              _Line('Firmware', station.firmwareVersion ?? 'Chưa có'),
              _Line('Cấu hình', station.configVersion ?? 'Chưa có'),
              _Line(
                'Nguồn',
                station.isSimulated ? 'MÔ PHỎNG' : 'THIẾT BỊ THẬT',
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      const _Banner(
        icon: Icons.info_outline,
        text:
            'Điện thoại thật phải dùng IP LAN của máy chạy backend. Android emulator dùng 10.0.2.2. Bản debug cho phép HTTP trong LAN demo; bản phát hành yêu cầu HTTPS.',
        color: _teal,
      ),
      const SizedBox(height: 10),
      const _Banner(
        icon: Icons.shield_outlined,
        text:
            'Khi trạm mất uplink, ứng dụng không thể nhận cảnh báo mới. Hãy nhìn còi/đèn tại trạm; dữ liệu cũ trong app không được coi là hiện trạng.',
        color: Color(0xFF9A5A25),
      ),
    ],
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
  });
  final double width;
  final String title, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _teal),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(color: Color(0xFF61717F), fontSize: 12),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: _navy,
                fontSize: 17,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF61717F), fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(color: _navy, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
