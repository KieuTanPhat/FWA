# Backend

Sau khi chạy `pwsh -File infra/setup.ps1` và `docker compose up -d`, chạy:

```powershell
cd backend
npm install
npm run migrate
npm run dev
```

API chỉ đọc: `/healthz`, `/api/v1/stations`, `/api/v1/stations/:id/latest`, `/api/v1/stations/:id/telemetry?limit=50`, `/api/v1/alerts?station_id=sim-01&limit=50`. WebSocket tại `/api/v1/stream`. `received_at` dùng giờ server; `device_ts` có thể null. API chưa có xác thực; phải bổ sung xác thực và kiểm soát truy cập trước khi đưa dữ liệu trạm thật lên Internet.

## Render demo

`render.yaml` tắt MQTT và bật `DEMO_ONLY`. Khi khởi động, service nạp lại bộ dữ liệu mô phỏng idempotent cho `sim-01`: 100 số đo cách nhau 5 phút và 5 sự kiện gồm các cấp rủi ro, lỗi cảm biến và phục hồi. Trạm được đánh dấu OFFLINE có chủ đích vì đây là lịch sử mẫu, không phải luồng đo trực tiếp từ phần cứng. API Render dùng HTTPS và chỉ cung cấp dữ liệu mô phỏng công khai.

