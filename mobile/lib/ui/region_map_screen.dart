import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import '../demo/region_demo.dart';
import '../models.dart';

const _navy = Color(0xFF12283D);
const _teal = Color(0xFF087D75);

String _demoRiskLabel(String? value) => switch (value) {
  'NORMAL' => 'Bình thường',
  'WATCH' => 'Theo dõi',
  'WARNING' => 'Cảnh báo',
  'EMERGENCY' => 'Khẩn cấp',
  _ => 'Chưa có dữ liệu',
};

Color _demoRiskColor(String? value) => switch (value) {
  'NORMAL' => const Color(0xFF07845C),
  'WATCH' => const Color(0xFFC07400),
  'WARNING' => const Color(0xFFD4541C),
  'EMERGENCY' => const Color(0xFFB22632),
  _ => const Color(0xFF667785),
};

class RegionMapScreen extends StatelessWidget {
  const RegionMapScreen({
    super.key,
    required this.region,
    required this.station,
    required this.control,
    this.error,
    required this.onRegionChanged,
    required this.onControlPatch,
  });

  final DemoRegion region;
  final Station? station;
  final DemoControl? control;
  final String? error;
  final ValueChanged<String> onRegionChanged;
  final Future<void> Function(Map<String, dynamic>) onControlPatch;

  @override
  Widget build(BuildContext context) {
    final site = region.sensors.single;
    final level = station?.waterLevelCm ?? control?.waterLevelCm;
    final risk = station?.effectiveRiskLevel ?? station?.riskLevel;
    final rainMm =
        (station?.rainTickCount ?? control?.rainTickCount ?? 0) * 0.2;
    final temperature = station?.temperatureC ?? control?.temperatureC;
    final currentControl = control;
    final controlStatus = currentControl == null
        ? '${site.name} · đang kết nối…'
        : currentControl.running
        ? 'Tự động ${currentControl.direction == 'RISING' ? 'dâng' : 'hạ'} · ${currentControl.riseRateCmMin.toStringAsFixed(1)} cm/phút mô phỏng'
        : 'Tạm dừng · đã đồng bộ với web';

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 5,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.place_outlined, color: _teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: region.id,
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
                            if (value != null) onRegionChanged(value);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E8),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Text(
                'DEMO IoT · Số đo dùng chung với web và được lưu trên máy chủ. Pin là vị trí tham khảo; không phải cảm biến thật ngoài thực địa.',
                style: TextStyle(
                  color: Color(0xFF8C4D17),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Text(
                'Máy chủ chưa đồng bộ được dữ liệu hoặc điều khiển: $error',
                style: const TextStyle(
                  color: Color(0xFFB44A31),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 7, 13, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${level?.toStringAsFixed(1) ?? '--.-'} cm  ·  ${_demoRiskLabel(risk)}',
                    style: TextStyle(
                      color: _demoRiskColor(risk),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  'Mưa ${rainMm.toStringAsFixed(1)} mm',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF61717F),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  temperature == null
                      ? '--.- °C'
                      : '${temperature.toStringAsFixed(1)} °C',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF61717F),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 0, 13, 5),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'd ${station?.distanceCm?.toStringAsFixed(1) ?? '--.-'} cm · Mưa ${rainMm.toStringAsFixed(1)} mm · ${temperature?.toStringAsFixed(1) ?? '--.-'} °C · ngưỡng ${control?.watchCm.toInt() ?? 30}/${control?.warningCm.toInt() ?? 50}/${control?.emergencyCm.toInt() ?? 70} cm',
                style: const TextStyle(fontSize: 9, color: Color(0xFF61717F)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: FlutterMap(
                  key: ValueKey(region.id),
                  options: MapOptions(
                    initialCenter: region.center,
                    initialZoom: region.zoom,
                    minZoom: 6,
                    maxZoom: 18,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'vn.fwa.floodwatch',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: site.position,
                          width: 64,
                          height: 64,
                          child: Tooltip(
                            message:
                                '${site.name}\n${level?.toStringAsFixed(1) ?? '--.-'} cm · ${_demoRiskLabel(risk)} · MÔ PHỎNG',
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => _showDetails(
                                context,
                                site,
                                station,
                                control,
                                rainMm,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _demoRiskColor(risk),
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
                        TextSourceAttribution('© OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            controlStatus,
                            style: const TextStyle(
                              color: _navy,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Ghi một nhịp mưa',
                          onPressed: control == null
                              ? null
                              : () => onControlPatch({'rain_tip': true}),
                          icon: const Icon(
                            Icons.umbrella_outlined,
                            color: _teal,
                          ),
                        ),
                      ],
                    ),
                    _WaterLevelSlider(
                      value: level ?? site.initialWaterLevelCm,
                      minimum: control?.baselineWaterCm ?? 0,
                      enabled: control != null,
                      onCommit: (value) =>
                          onControlPatch({'water_level_cm': value}),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      alignment: WrapAlignment.center,
                      children: [
                        _ActionButton(
                          icon: Icons.trending_up,
                          label: 'Nước dâng',
                          onPressed: control == null
                              ? null
                              : () => onControlPatch({
                                  'direction': 'RISING',
                                  'running': true,
                                }),
                        ),
                        _ActionButton(
                          icon: Icons.trending_down,
                          label: 'Nước hạ',
                          onPressed: control == null
                              ? null
                              : () => onControlPatch({
                                  'direction': 'FALLING',
                                  'running': true,
                                }),
                        ),
                        _ActionButton(
                          icon: Icons.pause,
                          label: 'Dừng',
                          onPressed: control == null
                              ? null
                              : () => onControlPatch({'running': false}),
                        ),
                        _ActionButton(
                          icon: Icons.restart_alt,
                          label: 'Đặt lại',
                          onPressed: control == null
                              ? null
                              : () => onControlPatch({'reset': true}),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetails(
    BuildContext context,
    DemoSensorSite site,
    Station? station,
    DemoControl? control,
    double rainMm,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final water = station?.waterLevelCm ?? control?.waterLevelCm;
        final temp = station?.temperatureC ?? control?.temperatureC;
        final risk = station?.effectiveRiskLevel ?? station?.riskLevel;
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
                  'Mực nước mô phỏng',
                  water == null ? '--' : '${water.toStringAsFixed(1)} cm',
                ),
                _DetailLine(
                  'Khoảng cách siêu âm',
                  station?.distanceCm == null
                      ? '--'
                      : '${station!.distanceCm!.toStringAsFixed(1)} cm (H₀ = 200 cm)',
                ),
                _DetailLine('Cấp rủi ro', _demoRiskLabel(risk)),
                _DetailLine('Mưa tích lũy', '${rainMm.toStringAsFixed(1)} mm'),
                _DetailLine(
                  'Nhiệt độ',
                  temp == null ? '--' : '${temp.toStringAsFixed(1)} °C',
                ),
                _DetailLine('Thiết bị', 'Cảm biến siêu âm · sơ đồ IoT project'),
                _DetailLine(
                  'Cập nhật',
                  station?.receivedAt == null
                      ? 'Đang chờ dữ liệu'
                      : DateFormat(
                          'dd/MM/yyyy HH:mm:ss',
                        ).format(station!.receivedAt!.toLocal()),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Số đo và tọa độ pin được mô phỏng phục vụ trình diễn; không đại diện cảm biến lắp ngoài thực địa.',
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 15),
    label: Text(label, style: const TextStyle(fontSize: 10)),
    style: OutlinedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      foregroundColor: _teal,
      side: const BorderSide(color: Color(0xFFD8E5E6)),
    ),
  );
}

class _WaterLevelSlider extends StatefulWidget {
  const _WaterLevelSlider({
    required this.value,
    required this.minimum,
    required this.enabled,
    required this.onCommit,
  });

  final double value;
  final double minimum;
  final bool enabled;
  final ValueChanged<double> onCommit;

  @override
  State<_WaterLevelSlider> createState() => _WaterLevelSliderState();
}

class _WaterLevelSliderState extends State<_WaterLevelSlider> {
  late double value = widget.value.clamp(widget.minimum, 197).toDouble();

  @override
  void didUpdateWidget(covariant _WaterLevelSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.value.isNaN && oldWidget.value != widget.value) {
      value = widget.value.clamp(widget.minimum, 197).toDouble();
    }
  }

  @override
  Widget build(BuildContext context) => Slider(
    min: widget.minimum,
    max: 197,
    divisions: 394,
    value: value,
    label: '${value.toStringAsFixed(1)} cm',
    onChanged: widget.enabled ? (next) => setState(() => value = next) : null,
    onChangeEnd: widget.enabled ? widget.onCommit : null,
  );
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
