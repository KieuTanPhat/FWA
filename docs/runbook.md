# Runbook demo FWA

Repository có hai sản phẩm: **trạm IoT ESP32 là lõi cảnh báo**, ứng dụng **Flutter Android chỉ theo dõi và trình diễn**. Backend/MQTT là đường chuyển dữ liệu. Mọi ngưỡng trong `firmware/include/demo_config.h` là **DEMO ONLY**.

## 1. Chuẩn bị một lần

Cần Node.js 24, Flutter 3.41.x, Android SDK, Python/PlatformIO và Docker Desktop đã chạy Linux engine. Máy backend và ESP32/điện thoại thật phải cùng LAN demo riêng. Không mở cổng MQTT/API ra Internet. Giữ `.env`, `infra/mosquitto/passwd` và `firmware/include/secrets.h` ngoài Git.

Từ thư mục gốc repository:

```powershell
pwsh -File infra/setup.ps1
docker compose up -d postgres mosquitto
cd backend
npm ci
npm run migrate
npm run dev
```

Script setup tạo credential ngẫu nhiên cho backend, simulator và `station-01`, với ACL chỉ cho từng trạm ghi topic của mình. Chạy lại script không đổi credentials đã có. `GET http://127.0.0.1:3000/healthz` phải trả `{"status":"ok"}`. Backend cần lắng nghe LAN cho điện thoại; PostgreSQL chỉ bind loopback trên máy chạy Docker.

Nếu Docker engine chưa chạy, sửa Docker Desktop rồi chạy lại script; script kiểm tra engine **trước khi** tạo file `.env` mới. Không dùng tài khoản/mật khẩu mẫu trong `.env.example`.

## 2. Chạy chuỗi mô phỏng

Mở terminal khác ở gốc repository:

```powershell
cd simulator
npm ci
npm run demo -- --scenario full --interval-ms 5000
```

Trạm `sim-01` có nhãn **MÔ PHỎNG** cố định. Kịch bản gồm NORMAL → WATCH → WARNING → EMERGENCY → lỗi cảm biến → phục hồi; backend nhận telemetry/alert và gửi application ACK. `npm run integration` kiểm tra chống trùng, sai thứ tự, nguồn dữ liệu, WebSocket và ACK khi broker/backend/database đang chạy. Dữ liệu simulator không chứng minh hoạt động của cảm biến hoặc còi/đèn.

## 3. Chạy trạm ESP32 thật

1. Lắp A02YYUW SEN0311, đèn/còi qua driver và nguồn đúng theo [hướng dẫn firmware](../firmware/README.md). Ghi [biên bản hiệu chuẩn](calibration-template.md) trước khi đo/đổi ngưỡng.
2. Sao chép `firmware/include/secrets.example.h` thành `firmware/include/secrets.h`, điền Wi-Fi và broker IP LAN. Credential `station-01` lấy từ `.env` **trên máy của nhóm**, không chép mật khẩu vào tài liệu.
3. Ở `firmware/`: chạy `python -m platformio test -e native`, `python -m platformio run -e esp32dev`.
4. Chip mới: chạy `python -m platformio run -e esp32dev -t uploadfs` **một lần**. Lệnh này xóa outbox cũ; không chạy lại khi còn alert chưa ACK.
5. Chạy `python -m platformio run -e esp32dev -t upload` và theo dõi `python -m platformio device monitor -b 115200`.

Trạm phải chuyển cấp và kích hoạt đầu ra cục bộ trước khi gửi MQTT. Rút Wi-Fi/broker để chứng minh vòng cảnh báo tại trạm vẫn hoạt động. Khi kết nối phục hồi, alert trong LittleFS chỉ được xóa sau ACK của backend. Rút sensor phải hiện lỗi riêng; app không được hiện NORMAL là hiện trạng. Không trình bày các kiểm tra này như đã đạt khi chưa có ESP32/sensor và biên bản thực đo.

## 4. Chạy Flutter Android

```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run --debug --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

`10.0.2.2` dùng cho Android emulator. Điện thoại thật dùng `http://<IP-LAN-MÁY-BACKEND>:3000`; tránh `localhost` vì đó là điện thoại. Để tạo APK cài thử: `flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:3000`; file tại `mobile/build/app/outputs/flutter-apk/app-debug.apk`. URL này là mặc định; có thể mở nút cài đặt trên app để đổi và lưu URL LAN của backend. Bản release yêu cầu HTTPS và khóa ký riêng; bản debug chỉ dùng LAN demo.

Ứng dụng có Tổng quan, Lịch sử, Sự kiện và Kết nối. Chọn `station-01` để xem dữ liệu vật lý hoặc `sim-01` để demo mô phỏng. Khi dữ liệu cũ quá 15 giây/API lỗi, app hiển thị **Không xác định** và tách lần ghi nhận cuối khỏi hiện trạng.

## 5. Kịch bản trình bày 5–7 phút

1. Chỉ trạm và nhãn THIẾT BỊ THẬT/MÔ PHỎNG, thời gian nhận, chất lượng nước.
2. Tăng nước trên jig; đối chiếu với thước và ngưỡng trong biên bản hiệu chuẩn.
3. Chờ xác nhận nhiều mẫu; chứng minh còi/đèn tại chỗ và alert trong app.
4. `docker compose stop mosquitto`; tiếp tục thay đổi mực nước, quan sát còi/đèn. App sau timeout hiện dữ liệu cũ/không xác định.
5. `docker compose start mosquitto`; quan sát outbox gửi lại, alert không nhân đôi.
6. Xem lịch sử, lý do sự kiện, trạng thái kết nối và giới hạn của prototype.

Nếu thiếu phần cứng, chuyển sang `sim-01` và nói rõ đây là mô phỏng. Không dùng kịch bản mô phỏng để tuyên bố kiểm chứng phần cứng hoặc độ chính xác ngoài thực địa.

## 6. Cổng kiểm tra trước demo

| Mục | Bằng chứng cần có |
|---|---|
| Parser/logic ESP32 | Native test pass, ESP32 build pass, đo bench/hình ảnh của trạm thật |
| Luồng dữ liệu | Migration sạch, simulator → broker → DB → REST/WebSocket → app |
| Cảnh báo offline | Video rút mạng với còi/đèn thật, outbox gửi lại sau phục hồi |
| App | `flutter analyze`, `flutter test`, APK debug cài/chạy trên emulator hoặc điện thoại |
| Bảo mật demo | ACL broker, credential ngoài Git, LAN riêng, app không chứa MQTT password |

Chỉ đánh dấu mục phần cứng “đạt” sau khi có linh kiện, ảnh/video và biên bản đo. Với prototype chưa kiểm chứng thực địa, không công bố là hệ thống cảnh báo an toàn cho cộng đồng.
