import 'package:latlong2/latlong.dart';

const defaultDemoRegionId = 'thao-chay';
const demoWatchCm = 30.0;
const demoWarningCm = 50.0;
const demoEmergencyCm = 70.0;
const demoHysteresisCm = 5.0;
const demoConfirmSamples = 3;
const demoClearSamples = 4;
const demoSamplePeriod = Duration(seconds: 2);
const demoSimulatedRisePerMinuteCm = 0.5;

class DemoSensorSite {
  const DemoSensorSite({
    required this.id,
    required this.name,
    required this.river,
    required this.place,
    required this.position,
    required this.initialWaterLevelCm,
  });

  final String id;
  final String name;
  final String river;
  final String place;
  final LatLng position;
  final double initialWaterLevelCm;
}

class DemoRegion {
  const DemoRegion({
    required this.id,
    required this.name,
    required this.administrativeArea,
    required this.center,
    required this.zoom,
    required this.sensors,
  });

  final String id;
  final String name;
  final String administrativeArea;
  final LatLng center;
  final double zoom;
  final List<DemoSensorSite> sensors;
}

const demoRegions = <DemoRegion>[
  DemoRegion(
    id: 'thao-chay',
    name: 'Sông Thao – sông Chảy',
    administrativeArea: 'Lào Cai · khu vực Yên Bái cũ',
    center: LatLng(21.73, 104.87),
    zoom: 8.5,
    sensors: [
      DemoSensorSite(
        id: 'thao-yen-bai',
        name: 'Điểm đo Yên Bái',
        river: 'Sông Thao',
        place: 'Khu vực thành phố Yên Bái cũ',
        position: LatLng(21.7168, 104.8986),
        initialWaterLevelCm: 20,
      ),
      DemoSensorSite(
        id: 'chay-bao-yen',
        name: 'Điểm đo Bảo Yên',
        river: 'Sông Chảy',
        place: 'Khu vực Bảo Yên',
        position: LatLng(22.245, 104.438),
        initialWaterLevelCm: 22,
      ),
      DemoSensorSite(
        id: 'ngoi-thia-nghia-lo',
        name: 'Điểm đo Nghĩa Lộ',
        river: 'Suối Ngòi Thia',
        place: 'Khu vực Nghĩa Lộ · Yên Bái cũ',
        position: LatLng(21.596, 104.509),
        initialWaterLevelCm: 18,
      ),
    ],
  ),
  DemoRegion(
    id: 'huong-bo',
    name: 'Sông Hương – sông Bồ',
    administrativeArea: 'Thành phố Huế · Thừa Thiên Huế cũ',
    center: LatLng(16.48, 107.54),
    zoom: 10,
    sensors: [
      DemoSensorSite(
        id: 'huong-kim-long',
        name: 'Điểm đo Kim Long',
        river: 'Sông Hương',
        place: 'Khu vực Kim Long · Huế',
        position: LatLng(16.462, 107.554),
        initialWaterLevelCm: 20,
      ),
      DemoSensorSite(
        id: 'bo-phu-oc',
        name: 'Điểm đo Phú Ốc',
        river: 'Sông Bồ',
        place: 'Khu vực Phú Ốc · Quảng Điền',
        position: LatLng(16.585, 107.495),
        initialWaterLevelCm: 22,
      ),
      DemoSensorSite(
        id: 'huong-tra',
        name: 'Điểm đo Hương Trà',
        river: 'Sông Hương',
        place: 'Khu vực Hương Trà',
        position: LatLng(16.447, 107.434),
        initialWaterLevelCm: 18,
      ),
    ],
  ),
  DemoRegion(
    id: 'vu-gia-thu-bon',
    name: 'Vu Gia – Thu Bồn',
    administrativeArea: 'Thành phố Đà Nẵng · Quảng Nam cũ',
    center: LatLng(15.77, 108.02),
    zoom: 9,
    sensors: [
      DemoSensorSite(
        id: 'vu-gia-thanh-my',
        name: 'Điểm đo Thành Mỹ',
        river: 'Sông Vu Gia',
        place: 'Khu vực Thành Mỹ · Nam Giang cũ',
        position: LatLng(15.78, 107.82),
        initialWaterLevelCm: 20,
      ),
      DemoSensorSite(
        id: 'vu-gia-ai-nghia',
        name: 'Điểm đo Ái Nghĩa',
        river: 'Sông Vu Gia',
        place: 'Khu vực Ái Nghĩa · Đại Lộc',
        position: LatLng(15.88, 108.11),
        initialWaterLevelCm: 22,
      ),
      DemoSensorSite(
        id: 'thu-bon-nong-son',
        name: 'Điểm đo Nông Sơn',
        river: 'Sông Thu Bồn',
        place: 'Khu vực Nông Sơn',
        position: LatLng(15.76, 108.00),
        initialWaterLevelCm: 18,
      ),
      DemoSensorSite(
        id: 'thu-bon-hoi-an',
        name: 'Điểm đo Hội An',
        river: 'Sông Thu Bồn',
        place: 'Khu vực Hội An',
        position: LatLng(15.88, 108.34),
        initialWaterLevelCm: 24,
      ),
    ],
  ),
];

DemoRegion demoRegionById(String? id) => demoRegions.firstWhere(
  (region) => region.id == id,
  orElse: () => demoRegions.first,
);

int riskRank(String level) => switch (level) {
  'NORMAL' => 0,
  'WATCH' => 1,
  'WARNING' => 2,
  'EMERGENCY' => 3,
  _ => -1,
};

String riskForDemoLevel(double level) {
  if (level >= demoEmergencyCm) return 'EMERGENCY';
  if (level >= demoWarningCm) return 'WARNING';
  if (level >= demoWatchCm) return 'WATCH';
  return 'NORMAL';
}

double thresholdForRisk(String risk) => switch (risk) {
  'WATCH' => demoWatchCm,
  'WARNING' => demoWarningCm,
  'EMERGENCY' => demoEmergencyCm,
  _ => 0,
};

class DemoSensorReading {
  DemoSensorReading(this.site)
    : waterLevelCm = site.initialWaterLevelCm,
      updatedAt = DateTime.now();

  final DemoSensorSite site;
  double waterLevelCm;
  double riseRateCmMin = 0;
  String riskLevel = 'NORMAL';
  DateTime updatedAt;
  String? _candidateRisk;
  int _candidateSamples = 0;
  int _clearSamples = 0;

  /// Returns the new severity only when an escalation is confirmed.
  String? sample({required bool waterRising}) {
    final oldRisk = riskLevel;
    waterLevelCm = (waterLevelCm + (waterRising ? 0.5 : -0.5))
        .clamp(site.initialWaterLevelCm, 82.0)
        .toDouble();
    riseRateCmMin = waterRising
        ? demoSimulatedRisePerMinuteCm
        : -demoSimulatedRisePerMinuteCm;
    updatedAt = DateTime.now();

    final targetRisk = riskForDemoLevel(waterLevelCm);
    if (riskRank(targetRisk) > riskRank(riskLevel)) {
      _clearSamples = 0;
      if (_candidateRisk == targetRisk) {
        _candidateSamples++;
      } else {
        _candidateRisk = targetRisk;
        _candidateSamples = 1;
      }
      if (_candidateSamples >= demoConfirmSamples) {
        riskLevel = targetRisk;
        _candidateRisk = null;
        _candidateSamples = 0;
      }
    } else {
      _candidateRisk = null;
      _candidateSamples = 0;
      if (riskRank(targetRisk) < riskRank(riskLevel) && riskLevel != 'NORMAL') {
        final clearBelow = thresholdForRisk(riskLevel) - demoHysteresisCm;
        if (waterLevelCm < clearBelow) {
          _clearSamples++;
          if (_clearSamples >= demoClearSamples) {
            riskLevel = targetRisk;
            _clearSamples = 0;
          }
        } else {
          _clearSamples = 0;
        }
      } else {
        _clearSamples = 0;
      }
    }

    return riskRank(riskLevel) > riskRank(oldRisk) ? riskLevel : null;
  }

  void reset() {
    waterLevelCm = site.initialWaterLevelCm;
    riseRateCmMin = 0;
    riskLevel = 'NORMAL';
    updatedAt = DateTime.now();
    _candidateRisk = null;
    _candidateSamples = 0;
    _clearSamples = 0;
  }
}
