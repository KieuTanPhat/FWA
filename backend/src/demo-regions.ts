export const demoRegions = [
  {
    id: 'thao-chay',
    name: 'Sông Thao – sông Chảy',
    stationId: 'sim-01',
    sensorName: 'Cảm biến Yên Bái',
    river: 'Sông Thao',
  },
  {
    id: 'huong-bo',
    name: 'Sông Hương – sông Bồ',
    stationId: 'sim-02',
    sensorName: 'Cảm biến Kim Long',
    river: 'Sông Hương',
  },
  {
    id: 'vu-gia-thu-bon',
    name: 'Vu Gia – Thu Bồn',
    stationId: 'sim-03',
    sensorName: 'Cảm biến Hội An',
    river: 'Sông Thu Bồn',
  },
] as const;

export function isDemoStation(stationId: string) {
  return demoRegions.some(region => region.stationId === stationId);
}
