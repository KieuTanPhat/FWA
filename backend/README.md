# Backend

Sau khi chạy `pwsh -File infra/setup.ps1` và `docker compose up -d`, chạy:

```powershell
cd backend
npm install
npm run migrate
npm run dev
```

Web điều khiển IoT ở `http://localhost:3000/iot`. Nó vẽ từ `public/diagram.json`, đọc mẫu đã lưu, cho sửa cấu hình demo và đồng bộ bằng WebSocket `/api/v1/stream`.

API gồm `/healthz`, `/api/v1/stations`, `/api/v1/stations/:id/latest`, `/api/v1/stations/:id/telemetry?limit=50`, `/api/v1/alerts?station_id=sim-01&limit=50`, `GET /api/v1/demo/stations/:id/control` và `PATCH /api/v1/demo/stations/:id/control`. Các tuyến điều khiển chỉ hoạt động khi `DEMO_ONLY=true` và chỉ chấp nhận ba station ID mô phỏng. `received_at` dùng giờ server; `device_ts` có thể null. API demo không có xác thực nên ai có đường dẫn đều điều khiển được ba kịch bản giả lập; không bật các route này cho trạm thật.

## Render demo

`render.yaml` tắt MQTT và bật `DEMO_ONLY`. Migration đăng ký ba vùng/cảm biến và cấu hình điều khiển; service ghi số đo mô phỏng mỗi 5 giây, lưu lịch sử tối đa 7 ngày, lưu sự kiện đổi cấp và phát WebSocket. Tốc độ nhập theo cm/phút được quy đổi theo chu kỳ 5 giây; ngưỡng tốc độ mặc định 5/10/15 cm/phút có thể chỉnh từ web. Bộ dữ liệu mẫu cũ cho `sim-01` được giữ làm lịch sử ban đầu. API Render chỉ cung cấp dữ liệu mô phỏng công khai.

