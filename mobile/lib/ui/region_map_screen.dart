import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import '../demo/region_demo.dart';
import '../models.dart';
import 'water_forecast.dart';

const _navy = Color(0xFF12283D);
const _teal = Color(0xFF087D75);

String _riskLabel(String? value) => switch (value) {
  'NORMAL' => 'Bình thường',
  'WATCH' => 'Theo dõi',
  'WARNING' => 'Cảnh báo',
  'EMERGENCY' => 'Nguy hiểm',
  _ => 'Chưa có số liệu',
};

Color _riskColor(String? value) => switch (value) {
  'NORMAL' => const Color(0xFF07845C),
  'WATCH' => const Color(0xFFC07400),
  'WARNING' => const Color(0xFFD4541C),
  'EMERGENCY' => const Color(0xFFB22632),
  _ => const Color(0xFF667785),
};

class RegionMapScreen extends StatefulWidget {
  const RegionMapScreen({
    super.key,
    required this.region,
    required this.station,
    this.error,
    required this.onRegionChanged,
  });

  final DemoRegion region;
  final Station? station;
  final String? error;
  final ValueChanged<String> onRegionChanged;

  @override
  State<RegionMapScreen> createState() => _RegionMapScreenState();
}

class _RegionMapScreenState extends State<RegionMapScreen> {
  final _tileReset = StreamController<void>.broadcast();
  bool _tilesUnavailable = false;

  @override
  void dispose() {
    _tileReset.close();
    super.dispose();
  }

  void _tileError(TileImage tile, Object error, StackTrace? stackTrace) {
    if (!_tilesUnavailable && mounted) {
      setState(() => _tilesUnavailable = true);
    }
  }

  void _retryMap() {
    setState(() => _tilesUnavailable = false);
    _tileReset.add(null);
  }

  @override
  Widget build(BuildContext context) {
    final site = widget.region.sensors.single;
    final station = widget.station;
    final level = station?.waterLevelCm;
    final risk = station?.effectiveRisk ?? station?.riskLevel;
    final fresh = station?.isFresh == true && station?.isOnline == true;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 7, 12, 6),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                child: Row(
                  children: [
                    const Icon(Icons.place_outlined, color: _teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: widget.region.id,
                          items: demoRegions
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item.id,
                                  child: Text(
                                    item.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) widget.onRegionChanged(value);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(3, 2, 3, 6),
              child: Text(
                'Bản đồ địa lý thật · vị trí cảm biến và số đo được mô phỏng cho bài trình diễn.',
                style: const TextStyle(
                  color: Color(0xFF61717F),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (widget.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  'Chưa tải được số liệu. Hãy kiểm tra kết nối Internet.',
                  style: const TextStyle(
                    color: Color(0xFFB44A31),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                child: Row(
                  children: [
                    Icon(Icons.water_drop, color: _riskColor(risk), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mực nước hiện tại  ${level?.toStringAsFixed(1) ?? '—'} cm',
                        style: const TextStyle(
                          color: _navy,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      fresh ? _riskLabel(risk) : 'Số đo cũ',
                      style: TextStyle(
                        color: _riskColor(risk),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 7),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    FlutterMap(
                      key: ValueKey(widget.region.id),
                      options: MapOptions(
                        initialCenter: widget.region.center,
                        initialZoom: widget.region.zoom,
                        minZoom: 6,
                        maxZoom: 18,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          fallbackUrl:
                              'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
                          userAgentPackageName: 'vn.fwa.floodwatch',
                          tileProvider: NetworkTileProvider(
                            headers: const {
                              'User-Agent':
                                  'FWA Flood Watch/0.3.0 (vn.fwa.floodwatch)',
                            },
                          ),
                          errorTileCallback: _tileError,
                          reset: _tileReset.stream,
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: site.position,
                              width: 64,
                              height: 64,
                              child: Tooltip(
                                message:
                                    '${site.name}\n${level?.toStringAsFixed(1) ?? '—'} cm · ${_riskLabel(risk)}',
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => _showDetails(site, station),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _riskColor(risk),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x55000000),
                                          blurRadius: 7,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.sensors,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const RichAttributionWidget(
                          attributions: [
                            TextSourceAttribution(
                              '© OpenStreetMap contributors · tiles © FOSSGIS e.V.',
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_tilesUnavailable)
                      Positioned.fill(
                        child: ColoredBox(
                          color: const Color(0xFFF1F5F5).withValues(alpha: 0.95),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.map_outlined,
                                    size: 40,
                                    color: _teal,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Chưa tải được bản đồ. Kiểm tra kết nối Internet rồi thử lại.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: _navy),
                                  ),
                                  const SizedBox(height: 6),
                                  TextButton.icon(
                                    onPressed: _retryMap,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Thử lại'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 7),
            if (station != null)
              WaterForecast(station: station, compact: true)
            else
              const SizedBox(
                height: 68,
                child: Center(child: Text('Đang chờ số đo từ khu vực này.')),
              ),
          ],
        ),
      ),
    );
  }

  void _showDetails(DemoSensorSite site, Station? station) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final risk = station?.effectiveRisk ?? station?.riskLevel;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  site.name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: _navy,
                  ),
                ),
                Text('${site.river} · ${site.place}'),
                const SizedBox(height: 14),
                _DetailLine(
                  'Mực nước hiện tại',
                  station?.waterLevelCm == null
                      ? 'Chưa có số đo'
                      : '${station!.waterLevelCm!.toStringAsFixed(1)} cm',
                ),
                _DetailLine('Mức cảnh báo', _riskLabel(risk)),
                _DetailLine(
                  'Lượng mưa',
                  station?.rainTickCount == null
                      ? 'Chưa có số đo'
                      : '${(station!.rainTickCount! * 0.2).toStringAsFixed(1)} mm',
                ),
                _DetailLine(
                  'Nhiệt độ',
                  station?.temperatureC == null
                      ? 'Chưa có số đo'
                      : '${station!.temperatureC!.toStringAsFixed(1)} °C',
                ),
                _DetailLine(
                  'Cập nhật gần nhất',
                  station?.receivedAt == null
                      ? 'Đang chờ số đo'
                      : DateFormat(
                          'dd/MM/yyyy HH:mm:ss',
                        ).format(station!.receivedAt!.toLocal()),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Bản đồ hiển thị vị trí minh họa; số đo được mô phỏng và không đến từ cảm biến lắp ngoài thực địa.',
                  style: TextStyle(
                    color: Color(0xFF8C4D17),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Color(0xFF61717F))),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}
