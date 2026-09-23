# Backend

Sau khi chạy `pwsh -File infra/setup.ps1` và `docker compose up -d`, chạy:

```powershell
cd backend
npm install
npm run migrate
npm run dev
```

API chỉ đọc: `/healthz`, `/api/v1/stations`, `/api/v1/stations/:id/latest`, `/api/v1/stations/:id/telemetry?limit=50`, `/api/v1/alerts?station_id=sim-01&limit=50`. WebSocket tại `/api/v1/stream`. `received_at` dùng giờ server; `device_ts` có thể null. Không triển khai API này trên Internet nếu chưa bổ sung TLS và xác thực.

