import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../demo/region_demo.dart';
import '../models.dart';
import '../notifications/emergency_notifications.dart';
import '../state/dashboard_controller.dart';
import 'emergency_alert_screen.dart';
import 'region_map_screen.dart';
import 'water_forecast.dart';

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
  return DateFormat('dd/MM/yyyy HH:mm:ss').format(value);
}

String reasonLabel(String value) => switch (value) {
  'WATER_OR_RISE_THRESHOLD' || 'DEMO_WATER_THRESHOLD' => 'Mực nước vượt ngưỡng',
  'DEMO_WATER_RECOVERED' => 'Mực nước đã hạ qua ngưỡng hồi phục',
  'SENSOR_TIMEOUT' || 'DEMO_SENSOR_TIMEOUT' => 'Mất tín hiệu cảm biến',
  'SENSOR_RECOVERED' || 'DEMO_SENSOR_RECOVERED' => 'Cảm biến hoạt động lại',
  _ => 'Có thay đổi ở trạm',
};

class FwaApp extends StatelessWidget {
  const FwaApp({
    super.key,
    required this.controller,
    this.initialRegionId,
    this.saveRegionId,
  });
  final DashboardController controller;
  final String? initialRegionId;
  final Future<void> Function(String)? saveRegionId;

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
    home: _Dashboard(
      controller: controller,
      initialRegionId: initialRegionId,
      saveRegionId: saveRegionId,
    ),
  );
}

class _Dashboard extends StatefulWidget {
  const _Dashboard({
    required this.controller,
    required this.initialRegionId,
    required this.saveRegionId,
  });
  final DashboardController controller;
  final String? initialRegionId;
  final Future<void> Function(String)? saveRegionId;
  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  int tab = 0;
  String? selectedRegionId;
  String? regionSaveError;
  StreamSubscription<EmergencyNotice>? _noticeSubscription;
  final Set<String> _presentedEmergencyIds = <String>{};

  @override
  void initState() {
    super.initState();
    selectedRegionId = findDemoRegion(widget.initialRegionId)?.id;
    _noticeSubscription = EmergencyNotifications.instance.openedNotices.listen(
      _openEmergencyNotice,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = EmergencyNotifications.instance.consumePendingNotice();
      if (pending != null) _openEmergencyNotice(pending);
      if (selectedRegionId != null) unawaited(_maybeExplainEmergencyAlerts());
    });
  }

  @override
  void dispose() {
    _noticeSubscription?.cancel();
    super.dispose();
  }

  void _openEmergencyNotice(EmergencyNotice notice) {
    if (!mounted || !_presentedEmergencyIds.add(notice.alertId)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EmergencyAlertScreen(notice: notice),
          fullscreenDialog: true,
        ),
      );
    });
  }

  Future<void> _maybeExplainEmergencyAlerts() async {
    final preferences = await SharedPreferences.getInstance();
    const key = 'fwa_emergency_permission_explained_v1';
    if (preferences.getBool(key) == true || !mounted) return;
    await preferences.setBool(key, true);
    if (!mounted) return;
    final enable = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.notifications_active_outlined,
          color: Color(0xFFB22632),
        ),
        title: const Text('Bật cảnh báo khẩn cấp'),
        content: const Text(
          'Khi cảm biến mô phỏng báo mức khẩn cấp, điện thoại có thể bật màn hình, rung và phát âm thanh. Hãy cho phép thông báo; trên một số máy Android cần bật thêm thông báo toàn màn hình trong Cài đặt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Thiết lập'),
          ),
        ],
      ),
    );
    if (enable == true) await _enableEmergencyAlerts();
  }

  Future<void> _enableEmergencyAlerts() async {
    final ready = await EmergencyNotifications.instance.requestPermissions();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ready
              ? 'Đã bật thông báo khẩn cấp.'
              : 'Hãy cho phép thông báo và quyền mở toàn màn hình trong Cài đặt ứng dụng.',
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _selectRegion(String id) async {
    if (id == selectedRegionId) {
      return;
    }
    final region = findDemoRegion(id);
    if (region == null) {
      return;
    }
    try {
      await widget.saveRegionId?.call(id);
    } catch (_) {
      if (mounted) {
        setState(() => regionSaveError = 'Không lưu được khu vực đã chọn.');
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      selectedRegionId = id;
      regionSaveError = null;
    });
    widget.controller.selectStation(region.sensors.single.stationId);
    unawaited(_maybeExplainEmergencyAlerts());
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final state = widget.controller;
      final region = findDemoRegion(selectedRegionId);
      final station = region == null
          ? null
          : state.stations
                .where((item) => item.id == region.sensors.single.stationId)
                .firstOrNull;
      final incomingAlert = state.consumeIncomingAlert();
      if (incomingAlert != null &&
          region?.sensors.single.stationId == incomingAlert.stationId) {
        final sensorName = region?.sensors.single.name ?? 'cảm biến';
        if (incomingAlert.currentLevel == 'EMERGENCY' &&
            station != null &&
            station.effectiveRisk == 'EMERGENCY') {
          final notice = EmergencyNotice.fromStationAlert(
            incomingAlert,
            station,
            sensorName,
            region!.administrativeArea,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(EmergencyNotifications.instance.showEmergency(notice));
            _openEmergencyNotice(notice);
          });
        } else {
          final isRecovery =
              incomingAlert.reasonCodes.contains('DEMO_WATER_RECOVERED') ||
              (incomingAlert.currentLevel == 'NORMAL' &&
                  incomingAlert.previousLevel != 'NORMAL');
          final message = isRecovery
              ? 'Mực nước đã hạ dưới ngưỡng · $sensorName'
              : 'Cảnh báo ${riskLabel(incomingAlert.currentLevel)} · $sensorName';
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final messenger = ScaffoldMessenger.of(context);
            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(
              SnackBar(
                backgroundColor: riskColor(incomingAlert.currentLevel),
                content: Text(message),
              ),
            );
          });
        }
      }
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Image.asset('assets/images/fwa_logo.webp', width: 38, height: 38),
              const SizedBox(width: 9),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FWA',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    'CẢNH BÁO LŨ',
                    style: TextStyle(fontSize: 11, letterSpacing: 1.2),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () => state.refresh(),
              icon: const Icon(Icons.refresh),
              tooltip: 'Tải lại',
            ),
          ],
        ),
        body: region == null
            ? _RegionOnboarding(
                onSelect: (id) => unawaited(_selectRegion(id)),
                error: regionSaveError,
              )
            : tab == 1
            ? RegionMapScreen(
                region: region,
                station: station,
                error: state.error,
                onRegionChanged: (id) => unawaited(_selectRegion(id)),
              )
            : RefreshIndicator(
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
                    if (tab == 0) ...[
                      _RegionSelectionCard(
                        region: region,
                        onChanged: (id) => unawaited(_selectRegion(id)),
                        onOpenMap: () => setState(() => tab = 1),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (state.loading && state.stations.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (!state.loading && state.stations.isEmpty)
                      const _Banner(
                        icon: Icons.sensors_off,
                        text:
                            'Chưa tải được số liệu. Hãy kiểm tra kết nối Internet rồi thử lại.',
                        color: _navy,
                      ),
                    if (state.stations.isNotEmpty && station == null)
                      const _Banner(
                        icon: Icons.sensors_off,
                        text: 'Chưa có số đo mới cho khu vực này.',
                        color: _navy,
                      ),
                    if (station != null) ...[
                      _OriginHeader(station: station),
                      const SizedBox(height: 14),
                      if (tab == 0)
                        _Overview(
                          station: station,
                          apiReachable: state.error == null,
                          onEnableEmergencyAlerts: _enableEmergencyAlerts,
                        ),
                      if (tab == 2)
                        _History(points: state.history, station: station),
                      if (tab == 3)
                        _Alerts(alerts: state.alerts, station: station),
                    ],
                  ],
                ),
              ),
        bottomNavigationBar: region == null
            ? null
            : NavigationBar(
                selectedIndex: tab,
                onDestinationSelected: (value) => setState(() => tab = value),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: 'Tổng quan',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.map_outlined),
                    selectedIcon: Icon(Icons.map),
                    label: 'Bản đồ',
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
                ],
              ),
      );
    },
  );
}

class _RegionOnboarding extends StatelessWidget {
  const _RegionOnboarding({required this.onSelect, this.error});

  final ValueChanged<String> onSelect;
  final String? error;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
      children: [
        Center(
          child: Image.asset(
            'assets/images/fwa_logo.webp',
            width: 112,
            height: 112,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Chọn khu vực quan tâm',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _navy,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ứng dụng chỉ hiển thị số đo và cảnh báo của một vùng bạn chọn. Có thể đổi khu vực bất cứ lúc nào.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF61717F), fontSize: 13),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ],
        const SizedBox(height: 22),
        for (final region in demoRegions) ...[
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onSelect(region.id),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFE8F4F2),
                      foregroundColor: _teal,
                      child: Icon(Icons.water),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            region.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: _navy,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            region.administrativeArea,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF61717F),
                            ),
                          ),
                          Text(
                            '${region.sensors.single.name} · dữ liệu mô phỏng',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF8C4D17),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: _teal),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
        ],
        const SizedBox(height: 8),
        const Text(
          'Chọn khu vực để xem số đo và nhận thông báo. Các số liệu trong bài trình diễn đều được mô phỏng.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF7C8A93), fontSize: 11),
        ),
      ],
    ),
  );
}

class _RegionSelectionCard extends StatelessWidget {
  const _RegionSelectionCard({
    required this.region,
    required this.onChanged,
    required this.onOpenMap,
  });

  final DemoRegion region;
  final ValueChanged<String> onChanged;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'KHU VỰC MÔ PHỎNG',
            style: TextStyle(
              color: Color(0xFF61717F),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: region.id,
              items: demoRegions
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  region.administrativeArea,
                  style: const TextStyle(color: Color(0xFF536675)),
                ),
              ),
              TextButton.icon(
                onPressed: onOpenMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Bản đồ'),
              ),
            ],
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
            label: station.isSimulated ? 'TRẠM MÔ PHỎNG' : 'TRẠM THẬT',
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
  const _Overview({
    required this.station,
    required this.apiReachable,
    required this.onEnableEmergencyAlerts,
  });
  final Station station;
  final bool apiReachable;
  final VoidCallback onEnableEmergencyAlerts;
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
                  ? 'CHƯA TẢI ĐƯỢC SỐ LIỆU'
                  : station.isOnline
                  ? 'TRẠM ĐANG HOẠT ĐỘNG'
                  : 'MẤT KẾT NỐI',
              icon: apiReachable && station.isOnline
                  ? Icons.link
                  : Icons.link_off,
              color: apiReachable && station.isOnline
                  ? _teal
                  : const Color(0xFF9A5A25),
            ),
            _Badge(
              label: !stale && station.sensorQuality['water'] == 'GOOD'
                  ? 'CẢM BIẾN HOẠT ĐỘNG TỐT'
                  : 'CẦN KIỂM TRA SỐ ĐO',
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
                  title: 'Mực nước hiện tại',
                  value: station.waterLevelCm == null
                      ? '—'
                      : '${station.waterLevelCm!.toStringAsFixed(1)} cm',
                  icon: Icons.water,
                ),
                _Metric(
                  width: width,
                  title: 'Tốc độ thay đổi',
                  value: station.riseRateCmMin == null
                      ? '—'
                      : '${station.riseRateCmMin!.toStringAsFixed(1)} cm/phút',
                  icon: Icons.trending_up,
                ),
                _Metric(
                  width: width,
                  title: 'Lượng mưa',
                  value: station.rainTickCount == null
                      ? '—'
                      : '${(station.rainTickCount! * 0.2).toStringAsFixed(1)} mm',
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
        WaterForecast(station: station),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  color: Color(0xFFB22632),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Cho phép thông báo để nhận cảnh báo khẩn cấp khi màn hình đang tắt.',
                    style: TextStyle(color: _navy, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onEnableEmergencyAlerts,
                  child: const Text('Bật'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cập nhật số đo',
                  style: TextStyle(fontWeight: FontWeight.w800, color: _navy),
                ),
                const SizedBox(height: 8),
                _Line('Nhận số đo lúc', timeLabel(station.receivedAt)),
                _Line(
                  'Tình trạng',
                  station.isFresh && station.isOnline
                      ? 'Đang cập nhật'
                      : 'Đây là lần ghi nhận gần nhất',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _Banner(
          icon: Icons.campaign_outlined,
          text:
              'Ứng dụng chỉ theo dõi và gửi thông báo khi có thay đổi mức cảnh báo. Bạn không thể chỉnh số đo trong ứng dụng.',
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
          '100 lần đo gần đây',
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
        'Các cảnh báo đã ghi nhận cho khu vực đang chọn.',
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
                _Line('Ghi nhận lúc', timeLabel(event.receivedAt)),
                if (event.deviceTs != null)
                  _Line('Thời gian trên thiết bị', timeLabel(event.deviceTs)),
              ],
            ),
          ),
        ),
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
