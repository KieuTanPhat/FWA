export type Step = {
  waterLevelCm: number | null;
  risk: 'NORMAL' | 'WATCH' | 'WARNING' | 'EMERGENCY' | null;
  reason?: string;
};

const normal: Step[] = [
  { waterLevelCm: 18, risk: 'NORMAL' },
  { waterLevelCm: 19, risk: 'NORMAL' },
  { waterLevelCm: 20, risk: 'NORMAL' },
];
const rise: Step[] = [
  { waterLevelCm: 20, risk: 'NORMAL' },
  { waterLevelCm: 29, risk: 'NORMAL' },
  { waterLevelCm: 34, risk: 'WATCH', reason: 'DEMO_WATER_THRESHOLD' },
  { waterLevelCm: 40, risk: 'WATCH' },
  { waterLevelCm: 54, risk: 'WARNING', reason: 'DEMO_WATER_THRESHOLD' },
  { waterLevelCm: 60, risk: 'WARNING' },
  { waterLevelCm: 74, risk: 'EMERGENCY', reason: 'DEMO_WATER_THRESHOLD' },
];
const fault: Step[] = [
  { waterLevelCm: 20, risk: 'NORMAL' },
  { waterLevelCm: null, risk: null, reason: 'DEMO_SENSOR_TIMEOUT' },
  { waterLevelCm: null, risk: null },
  { waterLevelCm: 19, risk: 'NORMAL', reason: 'DEMO_SENSOR_RECOVERED' },
];

export const scenarios: Record<string, Step[]> = {
  normal,
  rise,
  fault,
  full: [...normal, ...rise.slice(1), ...fault.slice(1)],
};
