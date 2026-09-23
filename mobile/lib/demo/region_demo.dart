import 'package:latlong2/latlong.dart';

const defaultDemoRegionId = 'thao-chay';
const demoWatchCm = 30.0;
const demoWarningCm = 50.0;
const demoEmergencyCm = 70.0;
const demoHysteresisCm = 5.0;
const demoConfirmSamples = 3;
const demoClearSamples = 4;

class DemoSensorSite {
  const DemoSensorSite({
    required this.id,
    required this.stationId,
    required this.name,
    required this.river,
    required this.place,
    required this.position,
    required this.initialWaterLevelCm,
  });

  final String id;
  final String stationId;
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
        id: 'sim-01',
        stationId: 'sim-01',
        name: 'Cảm biến Yên Bái',
        river: 'Sông Thao',
        place: 'Khu vực thành phố Yên Bái cũ',
        position: LatLng(21.7168, 104.8986),
        initialWaterLevelCm: 20,
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
        id: 'sim-02',
        stationId: 'sim-02',
        name: 'Cảm biến Kim Long',
        river: 'Sông Hương',
        place: 'Khu vực Kim Long · Huế',
        position: LatLng(16.462, 107.554),
        initialWaterLevelCm: 20,
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
        id: 'sim-03',
        stationId: 'sim-03',
        name: 'Cảm biến Hội An',
        river: 'Sông Thu Bồn',
        place: 'Khu vực Hội An',
        position: LatLng(15.88, 108.34),
        initialWaterLevelCm: 24,
      ),
    ],
  ),
];

DemoRegion? findDemoRegion(String? id) {
  for (final region in demoRegions) {
    if (region.id == id) return region;
  }
  return null;
}

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
