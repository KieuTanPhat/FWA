const NS = 'http://www.w3.org/2000/svg';
const REGIONS = [
  { id: 'thao-chay', name: 'Sông Thao – sông Chảy', area: 'Lào Cai · khu vực Yên Bái cũ', stationId: 'sim-01', sensor: 'Cảm biến Yên Bái' },
  { id: 'huong-bo', name: 'Sông Hương – sông Bồ', area: 'Thành phố Huế · Thừa Thiên Huế cũ', stationId: 'sim-02', sensor: 'Cảm biến Kim Long' },
  { id: 'vu-gia-thu-bon', name: 'Vu Gia – Thu Bồn', area: 'Đà Nẵng · Quảng Nam cũ', stationId: 'sim-03', sensor: 'Cảm biến Hội An' },
];
const COMPONENTS = {
  esp: { x: 440, y: 115, w: 285, h: 475 },
  ultrasonic: { x: 55, y: 100, w: 285, h: 145 },
  r_led: { x: 806, y: 164, w: 64, h: 25 },
  led_alert: { x: 915, y: 140, w: 132, h: 78 },
  buzzer: { x: 925, y: 302, w: 136, h: 100 },
  rain_gauge: { x: 890, y: 482, w: 220, h: 88 },
  temp_sensor: { x: 55, y: 485, w: 255, h: 88 },
  r_temp: { x: 346, y: 514, w: 65, h: 24 },
};
const WIRE_COLORS = { black: '#424d55', red: '#dc5252', green: '#40a576', blue: '#5085c3', orange: '#e8873d', purple: '#9664ae', cyan: '#53a9bd', yellow: '#d4b642' };
const state = { region: REGIONS[0], station: null, control: null, socket: null, busy: false, toastTimer: null };

const $ = selector => document.querySelector(selector);
const createSvg = (tag, attrs = {}, parent) => {
  const node = document.createElementNS(NS, tag);
  for (const [key, value] of Object.entries(attrs)) node.setAttribute(key, String(value));
  if (parent) parent.append(node);
  return node;
};
const svgText = (parent, x, y, value, className = '') => {
  const node = createSvg('text', { x, y, class: className }, parent);
  node.textContent = value;
  return node;
};
const componentAnchor = (part, pin) => {
  const p = COMPONENTS[part];
  if (!p) return null;
  const board = {
    'GND.1': [p.x, p.y + 68], '5V': [p.x, p.y + 102], '16': [p.x, p.y + 160], '17': [p.x, p.y + 195],
    '27': [p.x + p.w, p.y + 107], 'GND.2': [p.x + p.w, p.y + 145], '14': [p.x + p.w, p.y + 183], '25': [p.x + p.w, p.y + 221],
    '3V3': [p.x, p.y + 285], '26': [p.x, p.y + 325],
  };
  if (part === 'esp') return board[pin] ?? null;
  const map = {
    ultrasonic: { GND: [p.x + p.w, p.y + 101], VCC: [p.x + p.w, p.y + 76], ECHO: [p.x + p.w, p.y + 51], TRIG: [p.x + p.w, p.y + 26] },
    r_led: { '1': [p.x, p.y + 12], '2': [p.x + p.w, p.y + 12] },
    led_alert: { A: [p.x, p.y + 25], C: [p.x, p.y + 58] },
    buzzer: { '2': [p.x, p.y + 29], '1': [p.x, p.y + 70] },
    rain_gauge: { '2.1': [p.x, p.y + 29], '1.1': [p.x, p.y + 61] },
    temp_sensor: { VCC: [p.x + p.w, p.y + 20], DQ: [p.x + p.w, p.y + 43], GND: [p.x + p.w, p.y + 67] },
    r_temp: { '1': [p.x, p.y + 12], '2': [p.x + p.w, p.y + 12] },
  };
  return map[part]?.[pin] ?? null;
};

function drawDiagram(diagram) {
  const root = $('#diagram');
  root.replaceChildren();
  createSvg('rect', { x: 0, y: 0, width: 1160, height: 700, fill: 'transparent' }, root);
  const wireLayer = createSvg('g', { 'aria-hidden': 'true' }, root);
  for (const [from, to, color] of diagram.connections ?? []) {
    const [fromPart, fromPin] = from.split(':');
    const [toPart, toPin] = to.split(':');
    const a = componentAnchor(fromPart, fromPin), b = componentAnchor(toPart, toPin);
    if (!a || !b) continue;
    const middle = (a[0] + b[0]) / 2;
    const path = createSvg('path', { d: `M ${a[0]} ${a[1]} C ${middle} ${a[1]}, ${middle} ${b[1]}, ${b[0]} ${b[1]}`, class: `schematic-wire ${color}`, 'data-from': from, 'data-to': to, 'stroke': WIRE_COLORS[color] ?? '#76858d' }, wireLayer);
    path.setAttribute('stroke', WIRE_COLORS[color] ?? '#76858d');
  }
  for (const part of diagram.parts ?? []) drawPart(root, part);
  const missing = Object.keys(COMPONENTS).filter(id => !(diagram.parts ?? []).some(part => part.id === id));
  if (missing.length) throw new Error(`Sơ đồ thiếu linh kiện: ${missing.join(', ')}`);
}

function drawPart(root, part) {
  const p = COMPONENTS[part.id];
  if (!p) return;
  const g = createSvg('g', { id: `part-${part.id}`, 'data-part': part.id, role: 'group', 'aria-label': part.id }, root);
  if (part.id === 'esp') {
    createSvg('rect', { x: p.x, y: p.y, width: p.w, height: p.h, class: 'board-body' }, g);
    createSvg('rect', { x: p.x + 87, y: p.y + 34, width: 110, height: 57, class: 'board-shield', rx: 6 }, g);
    svgText(g, p.x + 142, p.y + 58, 'ESP32', 'board-title').setAttribute('text-anchor', 'middle');
    svgText(g, p.x + 142, p.y + 76, 'DEVKIT C · V4', 'board-subtitle').setAttribute('text-anchor', 'middle');
    createSvg('rect', { x: p.x + 113, y: p.y + 425, width: 58, height: 26, fill: '#bccbd0', rx: 3 }, g);
    svgText(g, p.x + 142, p.y + 490, 'FWA · FLOOD WATCH', 'board-title').setAttribute('text-anchor', 'middle');
    svgText(g, p.x + 142, p.y + 508, 'GPIO · SENSOR CONTROLLER', 'board-subtitle').setAttribute('text-anchor', 'middle');
    for (const pin of ['GND.1', '5V', '16', '17', '3V3', '26']) drawPin(g, componentAnchor('esp', pin), pin, 'left');
    for (const pin of ['27', 'GND.2', '14', '25']) drawPin(g, componentAnchor('esp', pin), pin, 'right');
    return;
  }
  if (part.id === 'ultrasonic') {
    svgText(g, p.x, p.y - 11, 'HC-SR04 · SIÊU ÂM', 'component-title');
    createSvg('rect', { x: p.x, y: p.y, width: p.w, height: p.h, class: 'sensor-board' }, g);
    for (const x of [p.x + 72, p.x + 207]) {
      createSvg('circle', { cx: x, cy: p.y + 53, r: 34, class: 'transducer' }, g);
      createSvg('circle', { cx: x, cy: p.y + 53, r: 24, class: 'transducer-core' }, g);
    }
    createSvg('rect', { x: p.x + 5, y: p.y + 93, width: p.w - 10, height: 32, class: 'readout-box' }, g);
    svgText(g, p.x + p.w / 2, p.y + 114, 'H --.- cm · d --.- cm', 'readout-text').setAttribute('id', 'water-readout');
    for (const [pin, y] of [['TRIG', 26], ['ECHO', 51], ['VCC', 76], ['GND', 101]]) svgText(g, p.x + p.w + 5, p.y + y + 4, pin, 'svg-label');
    return;
  }
  if (part.id === 'r_led' || part.id === 'r_temp') {
    const resistance = part.attrs?.value ?? (part.id === 'r_led' ? '330' : '4700');
    svgText(g, p.x - 4, p.y - 8, `R ${resistance}Ω`, 'svg-label');
    createSvg('line', { x1: p.x - 24, y1: p.y + 12, x2: p.x, y2: p.y + 12, stroke: '#e8873d', 'stroke-width': 4 }, g);
    createSvg('rect', { x: p.x, y: p.y + 2, width: p.w, height: 20, class: 'resistor-body' }, g);
    for (const dx of [15, 29, 43]) createSvg('line', { x1: p.x + dx, y1: p.y + 2, x2: p.x + dx, y2: p.y + 22, class: 'resistor-band' }, g);
    createSvg('line', { x1: p.x + p.w, y1: p.y + 12, x2: p.x + p.w + 24, y2: p.y + 12, stroke: '#e8873d', 'stroke-width': 4 }, g);
    return;
  }
  if (part.id === 'led_alert') {
    svgText(g, p.x, p.y - 10, part.attrs?.label ?? 'LED CẢNH BÁO', 'component-title');
    createSvg('circle', { cx: p.x + 42, cy: p.y + 39, r: 33, class: 'led-glow', id: 'led-glow' }, g);
    createSvg('path', { d: `M ${p.x + 42} ${p.y + 12} L ${p.x + 61} ${p.y + 32} L ${p.x + 57} ${p.y + 59} L ${p.x + 27} ${p.y + 59} L ${p.x + 23} ${p.y + 32} Z`, class: 'led-body' }, g);
    createSvg('line', { x1: p.x + 34, y1: p.y + 58, x2: p.x + 34, y2: p.y + 70, stroke: '#687982', 'stroke-width': 3 }, g);
    createSvg('line', { x1: p.x + 51, y1: p.y + 58, x2: p.x + 51, y2: p.y + 70, stroke: '#687982', 'stroke-width': 3 }, g);
    return;
  }
  if (part.id === 'buzzer') {
    createSvg('circle', { cx: p.x + 48, cy: p.y + 48, r: 44, class: 'buzzer-ring', id: 'buzzer-ring' }, g);
    createSvg('circle', { cx: p.x + 48, cy: p.y + 48, r: 36, class: 'buzzer-body' }, g);
    createSvg('circle', { cx: p.x + 48, cy: p.y + 48, r: 12, fill: '#0c1921' }, g);
    svgText(g, p.x + 97, p.y + 43, 'CÒI', 'component-title');
    svgText(g, p.x + 97, p.y + 60, 'GPIO 14', 'component-subtitle');
    return;
  }
  if (part.id === 'rain_gauge') {
    const label = part.attrs?.label ?? 'GẦU LẬT MƯA';
    svgText(g, p.x, p.y - 10, label, 'component-title');
    createSvg('rect', { x: p.x, y: p.y, width: p.w, height: p.h, class: 'sensor-board' }, g);
    createSvg('rect', { x: p.x + 16, y: p.y + 15, width: 67, height: 48, class: 'button-body', id: 'rain-button-body', rx: 9 }, g);
    createSvg('circle', { cx: p.x + 50, cy: p.y + 39, r: 13, class: 'button-core' }, g);
    svgText(g, p.x + 97, p.y + 35, 'GPIO 25', 'component-title');
    svgText(g, p.x + 97, p.y + 54, '--.- mm tích lũy', 'component-subtitle').setAttribute('id', 'rain-readout');
    g.style.cursor = 'pointer';
    g.addEventListener('click', () => sendPatch({ rain_tip: true }).catch(showError));
    return;
  }
  if (part.id === 'temp_sensor') {
    svgText(g, p.x, p.y - 10, 'DS18B20 · NHIỆT ĐỘ', 'component-title');
    createSvg('rect', { x: p.x, y: p.y, width: p.w, height: p.h, class: 'sensor-board' }, g);
    createSvg('rect', { x: p.x + 20, y: p.y + 19, width: 47, height: 50, class: 'ds18-body' }, g);
    createSvg('circle', { cx: p.x + 44, cy: p.y + 19, r: 10, class: 'ds18-tip' }, g);
    svgText(g, p.x + 82, p.y + 35, '--.- °C', 'component-title').setAttribute('id', 'temp-readout');
    svgText(g, p.x + 82, p.y + 53, 'GPIO 26 · 1-Wire', 'component-subtitle');
  }
}

function drawPin(parent, point, name, side) {
  if (!point) return;
  createSvg('circle', { cx: point[0], cy: point[1], r: 5, class: 'pin-dot' }, parent);
  svgText(parent, point[0] + (side === 'left' ? 12 : -12), point[1] + 4, name, 'pin-name').setAttribute('text-anchor', side === 'left' ? 'start' : 'end');
}

async function api(path, options = {}) {
  const response = await fetch(path, { headers: { 'Content-Type': 'application/json' }, ...options });
  const payload = await response.json().catch(() => null);
  if (!response.ok) throw new Error(payload?.message ?? `API ${response.status}`);
  return payload;
}

function riskName(value) {
  return ({ NORMAL: 'BÌNH THƯỜNG', WATCH: 'THEO DÕI', WARNING: 'CẢNH BÁO', EMERGENCY: 'KHẨN CẤP' })[value] ?? 'CHƯA CÓ DỮ LIỆU';
}
function formatTime(value) {
  if (!value) return '--';
  const date = new Date(value);
  return Number.isNaN(date.valueOf()) ? '--' : new Intl.DateTimeFormat('vi-VN', { hour: '2-digit', minute: '2-digit', second: '2-digit' }).format(date);
}
function stationRisk(station) {
  return station?.effective_risk_level ?? station?.risk_level ?? 'NORMAL';
}

async function refreshAll() {
  if (!state.region) return;
  const [stations, control, logs] = await Promise.all([
    api('/api/v1/stations'),
    api(`/api/v1/demo/stations/${state.region.stationId}/control`),
    api(`/api/v1/stations/${state.region.stationId}/telemetry?limit=30`),
  ]);
  const station = stations.find(value => value.id === state.region.stationId);
  if (!station) throw new Error('API chưa có cảm biến cho vùng đã chọn. Chạy migration mới rồi khởi động lại backend.');
  state.station = station;
  state.control = control;
  renderReadings(station, control);
  renderLog(logs);
}

function renderReadings(station, control) {
  const level = station.water_level_cm;
  const risk = stationRisk(station);
  $('#water-value').textContent = Number.isFinite(Number(level)) ? Number(level).toFixed(1) : '--.-';
  $('#rain-value').textContent = Number.isFinite(Number(station.rain_tick_count)) ? `${(Number(station.rain_tick_count) * Number(station.rain_mm_per_tick ?? 0.2)).toFixed(1)} mm` : '--.- mm';
  $('#temperature-value').textContent = Number.isFinite(Number(station.temperature_c)) ? `${Number(station.temperature_c).toFixed(1)} °C` : '--.- °C';
  $('#watch-value').textContent = `${Number(control.watch_cm).toFixed(1)} cm`;
  $('#warning-value').textContent = `${Number(control.warning_cm).toFixed(1)} cm`;
  $('#emergency-value').textContent = `${Number(control.emergency_cm).toFixed(1)} cm`;
  $('#risk-badge').textContent = riskName(risk);
  $('#risk-badge').className = `risk-badge ${String(risk).toLowerCase()}`;
  $('#last-updated').textContent = `Mẫu ${formatTime(station.received_at)} · ${station.link_state === 'ONLINE' ? 'trạm trực tuyến' : 'chờ kết nối'}`;
  $('#sensor-name').textContent = state.region.sensor;
  $('#station-location').textContent = station.location ?? state.region.area;
  $('#region-subtitle').textContent = state.region.area;
  const form = $('#control-form');
  for (const name of ['water_level_cm', 'rise_rate_cm_min', 'rain_rate_mm_hour', 'temperature_c', 'watch_cm', 'warning_cm', 'emergency_cm', 'watch_rate_cm_min', 'warning_rate_cm_min', 'emergency_rate_cm_min']) {
    const input = form.elements.namedItem(name);
    if (input && document.activeElement !== input) input.value = control[name];
  }
  form.elements.namedItem('water_level_cm').min = control.baseline_water_cm;
  const water = Number(level ?? control.water_level_cm).toFixed(1);
  const distance = Number(station.distance_cm ?? (200 - Number(level))).toFixed(1);
  const rain = (Number(station.rain_tick_count ?? 0) * Number(station.rain_mm_per_tick ?? 0.2)).toFixed(1);
  const temp = Number(station.temperature_c ?? control.temperature_c).toFixed(1);
  $('#water-readout').textContent = `H ${water} cm · d ${distance} cm`;
  $('#rain-readout').textContent = `${rain} mm tích lũy`;
  $('#temp-readout').textContent = `${temp} °C`;
  const active = risk === 'WARNING' || risk === 'EMERGENCY';
  $('#led-glow').classList.toggle('alert', risk !== 'NORMAL');
  $('#led-indicator').className = `device-dot ${risk === 'EMERGENCY' ? 'emergency' : risk === 'WARNING' || risk === 'WATCH' ? 'warning' : 'normal'}`;
  $('#buzzer-indicator').className = `device-dot ${active ? 'emergency' : 'normal'}`;
  $('#buzzer-ring').classList.toggle('active', active);
  $('#rain-button-body').classList.toggle('rain-active', Number(station.rain_tick_count ?? 0) > 0);
  $('#control-message').textContent = control.running ? `Tự động ${control.direction === 'RISING' ? 'dâng' : control.direction === 'FALLING' ? 'hạ' : 'tạm dừng'} · ${Number(control.rise_rate_cm_min).toFixed(1)} cm/phút mô phỏng` : 'Đang tạm dừng';
}

function renderLog(rows) {
  const body = $('#log-rows');
  body.replaceChildren();
  if (!rows.length) {
    const row = document.createElement('tr'), cell = document.createElement('td');
    cell.colSpan = 6; cell.className = 'empty'; cell.textContent = 'Chưa có bản ghi.'; row.append(cell); body.append(row); return;
  }
  for (const sample of rows) {
    const row = document.createElement('tr');
    const risk = sample.risk_level ?? 'UNKNOWN';
    const values = [
      formatTime(sample.received_at),
      sample.water_level_cm == null ? '--' : `${Number(sample.water_level_cm).toFixed(1)} cm`,
      sample.distance_cm == null ? '--' : `${Number(sample.distance_cm).toFixed(1)} cm`,
      sample.rain_tick_count == null ? '--' : `${(Number(sample.rain_tick_count) * Number(sample.rain_mm_per_tick ?? .2)).toFixed(1)} mm`,
      sample.temperature_c == null ? '--' : `${Number(sample.temperature_c).toFixed(1)} °C`,
      riskName(risk),
    ];
    values.forEach((value, index) => {
      const cell = document.createElement('td'); cell.textContent = value;
      if (index === 4) cell.className = `risk-text ${risk}`;
      row.append(cell);
    });
    body.append(row);
  }
}

async function sendPatch(body) {
  if (state.busy) return;
  state.busy = true;
  setButtonsDisabled(true);
  try {
    state.control = await api(`/api/v1/demo/stations/${state.region.stationId}/control`, { method: 'PATCH', body: JSON.stringify(body) });
    await refreshAll();
    toast('Đã lưu. Web và app đang dùng chung số liệu.');
  } finally {
    state.busy = false;
    setButtonsDisabled(false);
  }
}

function setButtonsDisabled(value) {
  document.querySelectorAll('button').forEach(button => { button.disabled = value; });
}
function toast(message) {
  const node = $('#toast'); node.textContent = message; node.classList.add('visible');
  clearTimeout(state.toastTimer); state.toastTimer = setTimeout(() => node.classList.remove('visible'), 2600);
}
function showError(error) {
  const message = error instanceof Error ? error.message : String(error);
  $('#control-message').textContent = message;
  $('#control-message').classList.add('error');
  toast(message);
}

function connectStream() {
  const scheme = location.protocol === 'https:' ? 'wss:' : 'ws:';
  const socket = new WebSocket(`${scheme}//${location.host}/api/v1/stream`);
  state.socket = socket;
  socket.addEventListener('open', () => {
    $('#connection').className = 'connection online'; $('#connection span').textContent = 'Đồng bộ trực tiếp';
  });
  socket.addEventListener('close', () => {
    $('#connection').className = 'connection offline'; $('#connection span').textContent = 'Đang kết nối lại';
    setTimeout(connectStream, 1800);
  });
  socket.addEventListener('error', () => socket.close());
  socket.addEventListener('message', event => {
    try {
      const message = JSON.parse(event.data);
      if (message.data?.station_id === state.region.stationId && ['station.telemetry', 'station.alert', 'station.control', 'station.status'].includes(message.event)) {
        refreshAll().catch(showError);
      }
    } catch (_) { /* Ignore malformed stream frames. */ }
  });
}

async function init() {
  const select = $('#region-select');
  for (const region of REGIONS) {
    const option = document.createElement('option'); option.value = region.id; option.textContent = region.name; select.append(option);
  }
  select.addEventListener('change', () => {
    state.region = REGIONS.find(region => region.id === select.value) ?? REGIONS[0];
    refreshAll().catch(showError);
  });
  $('#control-form').addEventListener('submit', async event => {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    const body = {};
    for (const name of ['water_level_cm', 'rise_rate_cm_min', 'rain_rate_mm_hour', 'temperature_c', 'watch_cm', 'warning_cm', 'emergency_cm', 'watch_rate_cm_min', 'warning_rate_cm_min', 'emergency_rate_cm_min']) {
      body[name] = Number(form.get(name));
    }
    $('#control-message').classList.remove('error');
    try { await sendPatch(body); } catch (error) { showError(error); }
  });
  $('#start-rising').addEventListener('click', () => sendPatch({ direction: 'RISING', running: true }).catch(showError));
  $('#start-falling').addEventListener('click', () => sendPatch({ direction: 'FALLING', running: true }).catch(showError));
  $('#pause').addEventListener('click', () => sendPatch({ running: false }).catch(showError));
  $('#rain-tip').addEventListener('click', () => sendPatch({ rain_tip: true }).catch(showError));
  $('#reset').addEventListener('click', () => sendPatch({ reset: true }).catch(showError));
  $('#refresh-log').addEventListener('click', () => refreshAll().catch(showError));
  try {
    const diagram = await api('/iot/diagram.json'); drawDiagram(diagram);
    await refreshAll();
  } catch (error) { showError(error); }
  connectStream();
  setInterval(() => refreshAll().catch(() => {}), 15_000);
}

document.addEventListener('DOMContentLoaded', init);
