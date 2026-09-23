import 'package:flutter/material.dart';
import '../notifications/emergency_notifications.dart';

class EmergencyAlertScreen extends StatelessWidget {
  const EmergencyAlertScreen({super.key, required this.notice});

  final EmergencyNotice notice;

  @override
  Widget build(BuildContext context) {
    final water = notice.waterLevelCm;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF9F1722),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 84,
                ),
                const SizedBox(height: 16),
                const Text(
                  'CẢNH BÁO KHẨN CẤP',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  notice.area.isEmpty ? notice.stationName : notice.area,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  notice.stationName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'MỰC NƯỚC GHI NHẬN',
                        style: TextStyle(
                          color: Color(0xFF536675),
                          fontWeight: FontWeight.w700,
                          letterSpacing: .7,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        water == null
                            ? 'Chưa có số đo'
                            : '${water.toStringAsFixed(1)} cm',
                        style: const TextStyle(
                          color: Color(0xFF9F1722),
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Lúc ${TimeOfDay.fromDateTime(notice.occurredAt).format(context)}',
                        style: const TextStyle(color: Color(0xFF536675)),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Text(
                  'Hãy chú ý cảnh báo tại khu vực đã chọn và làm theo hướng dẫn của cơ quan địa phương.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF9F1722),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    await EmergencyNotifications.instance.acknowledge(
                      notice.stationId,
                    );
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text(
                    'ĐÃ NHẬN CẢNH BÁO',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
