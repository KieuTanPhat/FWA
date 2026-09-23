import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';

const _forecastTeal = Color(0xFF087D75);
const _forecastNavy = Color(0xFF12283D);

class WaterForecast extends StatelessWidget {
  const WaterForecast({super.key, required this.station, this.compact = false});

  final Station station;
  final bool compact;

  static const _horizons = <(String, int)>[
    ('+1 giờ', 60),
    ('+3 giờ', 180),
    ('+6 giờ', 360),
    ('+12 giờ', 720),
    ('+1 ngày', 1440),
  ];

  @override
  Widget build(BuildContext context) {
    final current = station.waterLevelCm;
    final rate = station.riseRateCmMin;
    final usable = station.isFresh && station.isOnline && current != null;
    final baseTime = station.receivedAt ?? DateTime.now();
    final trend = rate == null
        ? 'Chưa đủ số đo để ước tính xu hướng.'
        : rate > 0.05
        ? 'Đang dâng ${rate.toStringAsFixed(1)} cm/phút'
        : rate < -0.05
        ? 'Đang hạ ${rate.abs().toStringAsFixed(1)} cm/phút'
        : 'Mực nước đang ổn định';
    final padding = compact ? 10.0 : 14.0;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.query_stats, size: 18, color: _forecastTeal),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Mực nước trong thời gian tới',
                  style: TextStyle(
                    color: _forecastNavy,
                    fontSize: compact ? 12 : 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (current != null)
                Text(
                  'Hiện tại ${current.toStringAsFixed(1)} cm',
                  style: TextStyle(
                    color: _forecastTeal,
                    fontSize: compact ? 10 : 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            trend,
            style: TextStyle(
              color: const Color(0xFF536675),
              fontSize: compact ? 10 : 11,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: compact ? 46 : 58,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _horizons.length,
              separatorBuilder: (_, _) => SizedBox(width: compact ? 6 : 8),
              itemBuilder: (context, index) {
                final (label, minutes) = _horizons[index];
                final projection = usable && rate != null
                    ? (current + rate * minutes).clamp(0.0, 200.0).toDouble()
                    : null;
                final time = baseTime.add(Duration(minutes: minutes));
                return Container(
                  width: compact ? 64 : 76,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 5 : 8,
                    vertical: compact ? 5 : 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F7F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          color: const Color(0xFF61717F),
                          fontSize: compact ? 8 : 9,
                        ),
                      ),
                      Text(
                        projection == null
                            ? '—'
                            : '${projection.toStringAsFixed(1)} cm',
                        maxLines: 1,
                        style: TextStyle(
                          color: _forecastNavy,
                          fontSize: compact ? 10 : 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (!compact)
                        Text(
                          DateFormat('dd/MM HH:mm').format(time),
                          maxLines: 1,
                          style: const TextStyle(
                            color: Color(0xFF61717F),
                            fontSize: 8,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 7),
            const Text(
              'Ước tính kéo dài tốc độ đo gần đây; số liệu mô phỏng, không phải dự báo thời tiết.',
              style: TextStyle(color: Color(0xFF7C8A93), fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}
