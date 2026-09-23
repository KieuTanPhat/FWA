# Chạy demo phòng lab

Các lệnh bên dưới chạy trong thư mục gốc repository. Cần Docker Desktop, Node.js, Flutter SDK và Android SDK. Không mở cổng demo ra Internet.

1. Tạo `.env` từ `.env.example`, thay toàn bộ mật khẩu mẫu và tạo file `infra/mosquitto/passwd` bằng `mosquitto_passwd`. Giữ file này ngoài Git.
2. Chạy `docker compose up -d postgres mosquitto`.
3. Chạy migration theo hướng dẫn `backend/README.md`, sau đó khởi động backend.
4. Chạy simulator cho `sim-01`; kiểm tra `GET /healthz` và `/api/v1/stations`.
5. Chạy Flutter với `--dart-define=API_BASE_URL=http://<IP-LAN>:3000`. Android emulator dùng `http://10.0.2.2:3000`; điện thoại thật dùng IP LAN của máy chạy backend.

Nếu không có linh kiện, dùng simulator và chỉ trình bày số đo là **MÔ PHỎNG**. Ngắt broker để chứng minh app báo dữ liệu cũ; chỉ firmware trên thiết bị thật mới chứng minh được còi/đèn vẫn hoạt động tại chỗ.

